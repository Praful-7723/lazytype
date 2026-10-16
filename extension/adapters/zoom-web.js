/**
 * Zoom Web Client Adapter
 */
window.ZoomWebAdapter = {
  id: 'zoom-web',
  name: 'Zoom Web',

  match() {
    return window.location.hostname.endsWith('zoom.us') && (
      window.location.pathname.includes('/wc/') ||
      window.location.pathname.includes('/j/') ||
      document.querySelector('.meeting-app, #wc-content, #wc-footer') !== null
    );
  },

  findChatButton() {
    return document.querySelector(
      'button[aria-label*="open the chat panel" i], ' +
      'button[aria-label*="chat" i], ' +
      'button.footer-button__chat, ' +
      'button[data-tooltip*="Chat" i], ' +
      'button.chat-icon'
    );
  },

  findChatInput() {
    return document.querySelector(
      'textarea.chat-box__chat-textarea, ' +
      'textarea[placeholder*="chat" i], ' +
      'textarea[placeholder*="Type message" i], ' +
      'textarea[aria-label*="chat" i], ' +
      'div[contenteditable="true"][role="textbox"], ' +
      '.chat-rtf-box div[contenteditable="true"]'
    );
  },

  findSendButton() {
    return document.querySelector(
      'button[aria-label*="send" i], ' +
      'button.chat-box__chat-send-button, ' +
      'button[type="submit"].chat-send-btn'
    );
  },

  getState() {
    const isMeetingActive = !!document.querySelector('#wc-footer, .footer, button[aria-label*="Leave" i]');
    const input = this.findChatInput();
    const isChatOpen = !!(input && input.offsetParent !== null);

    return {
      adapter: this.id,
      meetingDetected: isMeetingActive,
      chatAvailable: isMeetingActive,
      chatOpen: isChatOpen,
      canSendMessage: true,
      canMute: true,
      canControlCamera: true
    };
  },

  async openChat() {
    let input = this.findChatInput();
    if (input && input.offsetParent !== null) {
      return true;
    }

    const chatBtn = this.findChatButton();
    if (!chatBtn) throw new Error('CHAT_BUTTON_NOT_FOUND');

    window.LazyTypeInjector.safeClick(chatBtn);

    for (let i = 0; i < 15; i++) {
      await new Promise(r => setTimeout(r, 100));
      input = this.findChatInput();
      if (input && input.offsetParent !== null) return true;
    }
    return true;
  },

  async sendMessage(text) {
    await this.openChat();
    const input = this.findChatInput();
    if (!input) throw new Error('INPUT_NOT_FOUND');

    window.LazyTypeInjector.insertText(input, text);
    await new Promise(r => setTimeout(r, 60));

    const sendBtn = this.findSendButton();
    if (sendBtn && !sendBtn.disabled) {
      window.LazyTypeInjector.safeClick(sendBtn);
    } else {
      window.LazyTypeInjector.dispatchEnter(input);
    }

    return { success: true, message: 'Message sent in Zoom Web ✓' };
  },

  async insertText(text) {
    await this.openChat();
    const input = this.findChatInput();
    if (!input) throw new Error('INPUT_NOT_FOUND');
    window.LazyTypeInjector.insertText(input, text);
    return { success: true, message: 'Text inserted in Zoom Web' };
  },

  async toggleMute() {
    const muteBtn = document.querySelector('button[aria-label*="mute" i], button.footer-button__audio');
    if (!muteBtn) throw new Error('MUTE_BUTTON_NOT_FOUND');
    window.LazyTypeInjector.safeClick(muteBtn);
    return { success: true, message: 'Audio toggled' };
  },

  async toggleCamera() {
    const camBtn = document.querySelector('button[aria-label*="video" i], button.footer-button__video');
    if (!camBtn) throw new Error('CAMERA_BUTTON_NOT_FOUND');
    window.LazyTypeInjector.safeClick(camBtn);
    return { success: true, message: 'Video toggled' };
  }
};
