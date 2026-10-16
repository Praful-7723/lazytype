/**
 * Microsoft Teams Web Adapter
 */
window.TeamsWebAdapter = {
  id: 'teams-web',
  name: 'Microsoft Teams',

  match() {
    const host = window.location.hostname;
    return (host.includes('teams.microsoft.com') || host.includes('teams.live.com')) &&
           (document.querySelector('#app, .app-layout, div[data-tid="calling-screen"]') !== null || host.includes('teams'));
  },

  findChatButton() {
    return document.querySelector(
      'button#chat-button, ' +
      'button[data-tid="chat-button"], ' +
      'button[data-tid="side-panel-button-chat"], ' +
      'button[aria-label*="chat" i], ' +
      'button[title*="Chat" i]'
    );
  },

  findChatInput() {
    return document.querySelector(
      'div[data-tid="ckeditor"], ' +
      'div[data-tid="chat-input-text-area"] div[contenteditable="true"], ' +
      'div.cke_editable, ' +
      'div[role="textbox"][aria-label*="Type a message" i], ' +
      'div[role="textbox"][aria-label*="chat" i], ' +
      'textarea[data-tid="chat-input-control"], ' +
      'div.ts-edit-box div[contenteditable="true"]'
    );
  },

  findSendButton() {
    return document.querySelector(
      'button[data-tid="chat-send-message-button"], ' +
      'button[aria-label*="Send" i], ' +
      'button[title*="Send" i], ' +
      'button.ts-sym.icons-send'
    );
  },

  getState() {
    const isMeetingActive = !!document.querySelector(
      'div[data-tid="calling-screen"], ' +
      'button#hangup-button, ' +
      'button[data-tid="hangup-button"], ' +
      'button[aria-label*="Leave" i]'
    );
    const input = this.findChatInput();
    const isChatOpen = !!(input && input.offsetParent !== null);

    return {
      adapter: this.id,
      meetingDetected: isMeetingActive,
      chatAvailable: true,
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
      // In Teams, chat might already be visible or panel toggleable
      return false;
    }

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
    await new Promise(r => setTimeout(r, 80));

    const sendBtn = this.findSendButton();
    if (sendBtn && !sendBtn.disabled) {
      window.LazyTypeInjector.safeClick(sendBtn);
    } else {
      window.LazyTypeInjector.dispatchEnter(input);
    }

    return { success: true, message: 'Message sent in Microsoft Teams ✓' };
  },

  async insertText(text) {
    await this.openChat();
    const input = this.findChatInput();
    if (!input) throw new Error('INPUT_NOT_FOUND');
    window.LazyTypeInjector.insertText(input, text);
    return { success: true, message: 'Text inserted in Microsoft Teams' };
  },

  async toggleMute() {
    const muteBtn = document.querySelector(
      'button#microphone-button, ' +
      'button[data-tid="toggle-mute"], ' +
      'button[aria-label*="mute" i]'
    );
    if (!muteBtn) throw new Error('MUTE_BUTTON_NOT_FOUND');
    window.LazyTypeInjector.safeClick(muteBtn);
    return { success: true, message: 'Teams audio mute toggled' };
  },

  async toggleCamera() {
    const camBtn = document.querySelector(
      'button#video-button, ' +
      'button[data-tid="toggle-video"], ' +
      'button[aria-label*="camera" i]'
    );
    if (!camBtn) throw new Error('CAMERA_BUTTON_NOT_FOUND');
    window.LazyTypeInjector.safeClick(camBtn);
    return { success: true, message: 'Teams video toggled' };
  }
};
