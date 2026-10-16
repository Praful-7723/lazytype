/**
 * Universal Web Chat & Input Adapter
 * Automatically detects and interacts with chatboxes, message inputs,
 * and send buttons on ANY website (streaming, chat, social, forums, video calls).
 */

window.GenericWebAdapter = {
  id: 'generic-web',
  name: 'Universal Web Chat',

  match() {
    return true; // Universal fallback matching every website
  },

  /**
   * Search for all potential text inputs across standard DOM and open Shadow DOMs.
   */
  getAllPotentialInputs() {
    const candidates = [];

    function searchRoot(root) {
      if (!root) return;
      try {
        const elements = root.querySelectorAll(
          'textarea, ' +
          'input[type="text"], ' +
          'input[type="search"], ' +
          'input:not([type]), ' +
          'div[contenteditable="true"], ' +
          'span[contenteditable="true"], ' +
          '[role="textbox"]'
        );

        elements.forEach(el => candidates.push(el));

        // Search open shadow roots
        const allElements = root.querySelectorAll('*');
        allElements.forEach(el => {
          if (el.shadowRoot) {
            searchRoot(el.shadowRoot);
          }
        });
      } catch (e) {}
    }

    searchRoot(document);
    return candidates;
  },

  /**
   * Score and locate the best chat input element on the page.
   */
  findActiveInput() {
    // 1. If user already clicked or focused an input, that's 100% the intended target!
    const active = document.activeElement;
    if (active && (
      active.tagName === 'TEXTAREA' ||
      (active.tagName === 'INPUT' && active.type !== 'password' && active.type !== 'hidden') ||
      active.isContentEditable ||
      active.getAttribute('role') === 'textbox'
    )) {
      return active;
    }

    const candidates = this.getAllPotentialInputs();
    if (!candidates.length) return null;

    let bestElement = null;
    let highestScore = -1000;

    const chatKeywords = /(message|chat|say something|type|write|comment|everyone|send|stream|ask|discuss|reply)/i;
    const excludeKeywords = /(password|card|cvv|email|phone|search-site|nav|filter|login)/i;

    candidates.forEach(el => {
      // Must be visible
      const rect = el.getBoundingClientRect();
      const isVisible = (el.offsetParent !== null || rect.width > 0 && rect.height > 0) &&
                        window.getComputedStyle(el).visibility !== 'hidden';

      if (!isVisible) return;

      let score = 0;

      // Base visibility & sizing
      if (rect.width > 60 && rect.height > 20) score += 40;

      // Position heuristic: Chat inputs are almost always in the lower 60% of the viewport or sidebar
      const viewportHeight = window.innerHeight;
      if (rect.top > viewportHeight * 0.4) {
        score += 30;
      }

      // Check placeholder
      const placeholder = (el.placeholder || el.getAttribute('placeholder') || '').toLowerCase();
      if (placeholder) {
        if (chatKeywords.test(placeholder)) score += 120;
        if (excludeKeywords.test(placeholder)) score -= 100;
      }

      // Check aria-label / title
      const label = (el.getAttribute('aria-label') || el.title || '').toLowerCase();
      if (label) {
        if (chatKeywords.test(label)) score += 90;
        if (excludeKeywords.test(label)) score -= 80;
      }

      // Check class, id, name, data-testid
      const meta = `${el.className || ''} ${el.id || ''} ${el.name || ''} ${el.getAttribute('data-testid') || ''}`.toLowerCase();
      if (chatKeywords.test(meta)) score += 60;
      if (excludeKeywords.test(meta)) score -= 60;

      // Specific types
      if (el.tagName === 'TEXTAREA' || el.isContentEditable) {
        score += 30;
      }

      // Avoid search-only inputs if other options exist
      if (el.type === 'search') score -= 20;

      if (score > highestScore) {
        highestScore = score;
        bestElement = el;
      }
    });

    return bestElement || candidates[0] || null;
  },

  /**
   * Find the associated Send / Submit button near the chat input.
   */
  findSendButton(input) {
    if (!input) return null;

    // Search scopes in order of proximity: parent, parent's parent, container/form
    const scopes = [
      input.parentElement,
      input.parentElement ? input.parentElement.parentElement : null,
      input.closest('form, div[class*="input"], div[class*="chat"], div[class*="composer"], div[class*="footer"], footer, aside')
    ].filter(Boolean);

    const sendKeywords = /(send|submit|chat-send|paper-plane|airplane|publish|post)/i;

    for (const scope of scopes) {
      const buttons = Array.from(scope.querySelectorAll('button, [role="button"], input[type="submit"]'));
      
      for (const btn of buttons) {
        // Exclude emoji or attachment buttons
        const btnLabel = `${btn.innerText || ''} ${btn.getAttribute('aria-label') || ''} ${btn.title || ''} ${btn.className || ''}`.toLowerCase();
        if (/emoji|sticker|gift|attach|file|image|photo/i.test(btnLabel)) {
          continue;
        }

        // Explicit send signals
        if (sendKeywords.test(btnLabel) || btn.type === 'submit') {
          return btn;
        }

        // SVG icon buttons (like paper plane or arrow) commonly used on streaming sites
        const hasSvg = btn.querySelector('svg');
        if (hasSvg && btn.offsetParent !== null) {
          // If it's a visible button with an SVG in the chat bar, it's almost certainly the send button!
          return btn;
        }
      }
    }

    return null;
  },

  getState() {
    const input = this.findActiveInput();
    const sendBtn = this.findSendButton(input);

    return {
      adapter: this.id,
      meetingDetected: false,
      chatAvailable: !!input,
      chatOpen: !!input,
      canSendMessage: !!input,
      canMute: false,
      canControlCamera: false,
      hasSendButton: !!sendBtn
    };
  },

  async openChat() {
    const input = this.findActiveInput();
    if (input) {
      input.focus();
      return true;
    }
    return false;
  },

  async sendMessage(text) {
    const input = this.findActiveInput();
    if (!input) {
      throw new Error('CHAT_INPUT_NOT_FOUND');
    }

    // 1. Focus input
    input.focus();

    // 2. Insert text via React/Vue synthetic-safe injector
    window.LazyTypeInjector.insertText(input, text);
    
    // 3. Small pause for framework reactivity
    await new Promise(r => setTimeout(r, 60));

    // 4. Try finding and clicking the associated Send button
    const sendBtn = this.findSendButton(input);
    let buttonClicked = false;
    if (sendBtn && !sendBtn.disabled && window.getComputedStyle(sendBtn).display !== 'none') {
      window.LazyTypeInjector.safeClick(sendBtn);
      buttonClicked = true;
      await new Promise(r => setTimeout(r, 60));
    }

    // 5. Also dispatch full Enter key sequence (handles sites that submit on Enter)
    window.LazyTypeInjector.dispatchEnter(input);

    // 6. Form submit fallback if in a <form>
    if (input.form && typeof input.form.requestSubmit === 'function') {
      try {
        input.form.requestSubmit();
      } catch (e) {}
    }

    return {
      success: true,
      message: buttonClicked
        ? 'Message sent via chat button ✓'
        : 'Message sent via Enter key ✓'
    };
  },

  async insertText(text) {
    const input = this.findActiveInput();
    if (!input) throw new Error('CHAT_INPUT_NOT_FOUND');
    window.LazyTypeInjector.insertText(input, text);
    return { success: true, message: 'Text inserted into active field' };
  },

  async toggleMute() {
    throw new Error('NOT_SUPPORTED_IN_GENERIC_MODE');
  },

  async toggleCamera() {
    throw new Error('NOT_SUPPORTED_IN_GENERIC_MODE');
  }
};
