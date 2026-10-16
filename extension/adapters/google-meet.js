/**
 * Google Meet Web Adapter
 */
window.GoogleMeetAdapter = {
  id: 'google-meet',
  name: 'Google Meet',

  match() {
    return window.location.hostname === 'meet.google.com' && window.location.pathname.length > 1;
  },

  findChatButton() {
    return document.querySelector(
      'button[aria-label*="Chat with everyone" i], ' +
      'button[aria-label*="chat" i], ' +
      'button[data-tooltip*="Chat" i], ' +
      'button[jsname*="A5il2e"]'
    );
  },

  findChatInput() {
    return document.querySelector(
      'textarea[aria-label*="Send a message" i], ' +
      'textarea[name="chatTextInput"], ' +
      'textarea[placeholder*="Send a message" i], ' +
      'div[contenteditable="true"][aria-label*="Send a message" i]'
    );
  },

  findSendButton() {
    return document.querySelector(
      'button[aria-label*="Send a message" i], ' +
      'button[jsname="25q18b"], ' +
      'button[data-tooltip*="Send" i]'
    );
  },

  getState() {
    const isMeetingActive = !!document.querySelector('button[aria-label*="Leave call" i], div[data-meeting-code]');
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
      return true; // Already open
    }

    const chatBtn = this.findChatButton();
    if (!chatBtn) {
      throw new Error('CHAT_BUTTON_NOT_FOUND');
    }

    window.LazyTypeInjector.safeClick(chatBtn);
    
    // Wait for animation / DOM update
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

    return { success: true, message: 'Message sent in Google Meet ✓' };
  },

  async insertText(text) {
    await this.openChat();
    const input = this.findChatInput();
    if (!input) throw new Error('INPUT_NOT_FOUND');
    window.LazyTypeInjector.insertText(input, text);
    return { success: true, message: 'Text inserted in Google Meet' };
  },

  async toggleMute() {
    const muteBtn = document.querySelector('button[aria-label*="microphone" i], button[data-is-muted]');
    if (!muteBtn) throw new Error('MUTE_BUTTON_NOT_FOUND');
    window.LazyTypeInjector.safeClick(muteBtn);
    return { success: true, message: 'Microphone toggled' };
  },

  async toggleCamera() {
    const camBtn = document.querySelector('button[aria-label*="camera" i], button[data-is-camera-off]');
    if (!camBtn) throw new Error('CAMERA_BUTTON_NOT_FOUND');
    window.LazyTypeInjector.safeClick(camBtn);
    return { success: true, message: 'Camera toggled' };
  }
};
