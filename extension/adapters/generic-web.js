/**
 * Universal Web Chat & Input Adapter
 * Automatically detects and interacts with chatboxes, message inputs,
 * and send buttons on ANY website (streaming, chat, social, forums, video calls).
 */

if (!window.GenericWebAdapter) {
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
            'div[contenteditable=""], ' +
            'div[contenteditable="plaintext-only"], ' +
            'span[contenteditable="true"], ' +
            'span[contenteditable=""], ' +
            'p[contenteditable="true"], ' +
            'p[contenteditable=""], ' +
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
     * Search for a button that opens or toggles the chat panel if closed.
     */
    findChatToggleButton() {
      const chatBtnKeywords = /(open chat|show chat|toggle chat|chat panel|open side panel|live chat|chat)/i;
      const excludeBtn = /(close|leave|exit|settings|mute|cam|mic)/i;
      const buttons = document.querySelectorAll('button, [role="button"], a[role="button"]');
      
      for (const btn of buttons) {
        const label = `${btn.innerText || ''} ${btn.getAttribute('aria-label') || ''} ${btn.title || ''} ${btn.className || ''}`.toLowerCase();
        if (chatBtnKeywords.test(label) && !excludeBtn.test(label)) {
          const rect = btn.getBoundingClientRect();
          if (rect.width > 0 && rect.height > 0) {
            return btn;
          }
        }
      }
      return null;
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
        // If it's not a generic top-of-page search bar when a chatbox exists, prioritize it
        const activeMeta = `${active.placeholder || ''} ${active.id || ''} ${active.name || ''}`.toLowerCase();
        if (!/search-site|search_query|top-nav/i.test(activeMeta)) {
          return active;
        }
      }

      const candidates = this.getAllPotentialInputs();
      if (!candidates.length) return null;

      let bestElement = null;
      let highestScore = -1000;

      const chatKeywords = /(message|chat|say something|type|write|comment|everyone|send|stream|ask|discuss|reply|broadcast|talk)/i;
      const excludeKeywords = /(password|card|cvv|email|phone|search-site|nav|filter|login|username|signup)/i;

      candidates.forEach(el => {
        // Must be visible
        const rect = el.getBoundingClientRect();
        const isVisible = (el.offsetParent !== null || (rect.width > 0 && rect.height > 0)) &&
                          window.getComputedStyle(el).visibility !== 'hidden' &&
                          window.getComputedStyle(el).display !== 'none';

        if (!isVisible) return;

        let score = 0;

        // Base visibility & sizing
        if (rect.width > 60 && rect.height > 18) score += 40;

        // Position heuristic: Chat inputs are almost always in the lower 60% of the viewport or in a sidebar
        const viewportHeight = window.innerHeight;
        if (rect.top > viewportHeight * 0.4) {
          score += 35;
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

        // Reward search inputs
        if (/search|query/i.test(placeholder) || el.type === 'search') {
          score += 60;
        }

        if (score > highestScore) {
          highestScore = score;
          bestElement = el;
        }
      });

      // Accept if score is >= 15 (genuine chat, search, or message field)
      if (bestElement && highestScore >= 15) {
        return bestElement;
      }

      return null;
    },

    /**
     * Find the associated Send / Submit button near the chat input.
     */
    findSendButton(input) {
      if (!input) return null;

      // Search scopes in order of proximity: parent, grandparent, great-grandparent, form/container
      const scopes = [
        input.parentElement,
        input.parentElement ? input.parentElement.parentElement : null,
        input.parentElement && input.parentElement.parentElement ? input.parentElement.parentElement.parentElement : null,
        input.closest('form, div[class*="input"], div[class*="chat"], div[class*="composer"], div[class*="footer"], div[class*="bar"], footer, aside, section')
      ].filter(Boolean);

      const sendKeywords = /(send|submit|chat-send|paper-plane|airplane|publish|post|arrow)/i;
      const excludeKeywords = /(emoji|sticker|gift|attach|file|image|photo|coin|token|tip|donate|setting|menu|more|reaction)/i;

      let bestBtn = null;
      let highestScore = -100;

      for (const scope of scopes) {
        const buttons = Array.from(scope.querySelectorAll('button, [role="button"], input[type="submit"]'));
        
        for (const btn of buttons) {
          // Must be visible
          const rect = btn.getBoundingClientRect();
          if (rect.width === 0 && rect.height === 0) continue;
          if (window.getComputedStyle(btn).visibility === 'hidden' || window.getComputedStyle(btn).display === 'none') continue;

          const btnLabel = `${btn.innerText || ''} ${btn.getAttribute('aria-label') || ''} ${btn.title || ''} ${btn.className || ''} ${btn.id || ''} ${btn.getAttribute('data-testid') || ''}`.toLowerCase();
          
          if (excludeKeywords.test(btnLabel)) {
            continue;
          }

          let score = 0;
          if (sendKeywords.test(btnLabel)) score += 100;
          if (btn.type === 'submit') score += 80;

          // Check if button has an SVG icon
          const svg = btn.querySelector('svg');
          if (svg) {
            const svgContent = svg.outerHTML.toLowerCase();
            if (sendKeywords.test(svgContent)) score += 90;
            else score += 50; // Visible SVG icon button in chat composer toolbar
          }

          if (score > highestScore) {
            highestScore = score;
            bestBtn = btn;
          }
        }
        if (bestBtn && highestScore >= 50) return bestBtn;
      }

      return bestBtn;
    },

    getState() {
      const input = this.findActiveInput();
      const sendBtn = this.findSendButton(input);
      let targetName = 'Web Text Field';
      if (input) {
        const hostname = window.location.hostname.toLowerCase();
        const meta = `${input.placeholder || ''} ${input.name || ''} ${input.id || ''} ${input.getAttribute('aria-label') || ''}`.toLowerCase();
        if (hostname.includes('google')) {
          targetName = 'Google Search';
        } else if (hostname.includes('youtube')) {
          targetName = 'YouTube Search';
        } else if (hostname.includes('amazon')) {
          targetName = 'Amazon Search';
        } else if (hostname.includes('wikipedia')) {
          targetName = 'Wikipedia Search';
        } else if (/search|find|query/i.test(meta) || input.type === 'search') {
          targetName = 'Web Search Bar';
        } else if (/chat|message|comment|reply|say/i.test(meta)) {
          targetName = 'Web Chat';
        } else {
          targetName = document.title ? document.title.split(/[-|•]/)[0].trim() : 'Web Input';
        }
      }

      return {
        adapter: this.id,
        targetName,
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
      let input = this.findActiveInput();
      if (input) {
        input.focus();
        return true;
      }

      // Try finding toggle button
      const toggle = this.findChatToggleButton();
      if (toggle) {
        window.LazyTypeInjector.safeClick(toggle);
        await new Promise(r => setTimeout(r, 200));
        input = this.findActiveInput();
        if (input) input.focus();
        return true;
      }

      return false;
    },

    async sendMessage(text) {
      let input = this.findActiveInput();
      if (!input) {
        // Try opening chat panel first if closed
        const toggleBtn = this.findChatToggleButton();
        if (toggleBtn) {
          window.LazyTypeInjector.safeClick(toggleBtn);
          await new Promise(r => setTimeout(r, 250));
          input = this.findActiveInput();
        }
      }

      if (!input) {
        throw new Error('CHAT_INPUT_NOT_FOUND');
      }

      // 1. Focus input
      input.focus();

      // 2. Insert text via React/Vue synthetic-safe injector
      window.LazyTypeInjector.insertText(input, text);
      
      // 3. Pause for framework reactivity (enables send button)
      await new Promise(r => setTimeout(r, 100));

      // 4. Try finding and clicking the associated Send button
      const sendBtn = this.findSendButton(input);
      let buttonClicked = false;
      if (sendBtn && !sendBtn.disabled && window.getComputedStyle(sendBtn).display !== 'none') {
        window.LazyTypeInjector.safeClick(sendBtn);
        buttonClicked = true;
        await new Promise(r => setTimeout(r, 100));
      }

      // 5. Check if input cleared after clicking send button
      const currentValue = input.value !== undefined ? input.value : (input.innerText || input.textContent || '');
      const didClear = !currentValue || currentValue.trim() === '';

      // 6. If not cleared, dispatch full Enter key event
      if (!didClear) {
        window.LazyTypeInjector.dispatchEnter(input);
        await new Promise(r => setTimeout(r, 80));
      }

      // 7. If still not cleared and in a form, trigger form submit
      const currentVal2 = input.value !== undefined ? input.value : (input.innerText || input.textContent || '');
      if (currentVal2 && currentVal2.trim() !== '' && input.form && typeof input.form.requestSubmit === 'function') {
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
}
