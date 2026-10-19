/**
 * Slack Web Adapter
 */
window.SlackWebAdapter = {
  id: 'slack-web',
  name: 'Slack',

  match() {
    return window.location.hostname.endsWith('slack.com') &&
           (document.querySelector('.p-client_container, #client_header, div[data-qa="message_input"]') !== null || window.location.pathname.includes('/client/'));
  },

  findChatInput() {
    return document.querySelector(
      'div.ql-editor[contenteditable="true"], ' +
      'div[role="textbox"][data-qa="message_input"], ' +
      'div[role="textbox"][aria-label*="Message" i], ' +
      'div[role="textbox"][aria-label*="Send a message" i], ' +
      'div[contenteditable="true"][data-qa="message_input"]'
    );
  },

  findSendButton() {
    return document.querySelector(
      'button[data-qa="texty_send_button"], ' +
      'button[aria-label*="Send message" i], ' +
      'button[data-qa="send_message_button"]'
    );
  },

  getState() {
    const input = this.findChatInput();
    const isChatAvailable = !!input;
    const isChatOpen = !!(input && input.offsetParent !== null);

    return {
      adapter: this.id,
      meetingDetected: false, // Slack text chat
      chatAvailable: isChatAvailable,
      chatOpen: isChatOpen,
      canSendMessage: true,
      canMute: false,
      canControlCamera: false
    };
  },

  async openChat() {
    const input = this.findChatInput();
    if (input) {
      input.focus();
      return true;
    }
    return false;
  },

  async sendMessage(text) {
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

    return { success: true, message: 'Message sent in Slack ✓' };
  },

  async insertText(text) {
    const input = this.findChatInput();
    if (!input) throw new Error('INPUT_NOT_FOUND');
    window.LazyTypeInjector.insertText(input, text);
    return { success: true, message: 'Text inserted in Slack' };
  },

  async toggleMute() {
    // Check for Slack Huddle mute button if in active huddle
    const huddleMuteBtn = document.querySelector(
      'button[data-qa="huddle_mic_toggle"], ' +
      'button[aria-label*="Mute microphone" i], ' +
      'button[aria-label*="Unmute microphone" i]'
    );
    if (huddleMuteBtn) {
      window.LazyTypeInjector.safeClick(huddleMuteBtn);
      return { success: true, message: 'Slack Huddle mic toggled' };
    }
    throw new Error('NO_ACTIVE_HUDDLE');
  },

  async toggleCamera() {
    const huddleVideoBtn = document.querySelector(
      'button[data-qa="huddle_video_toggle"], ' +
      'button[aria-label*="Turn on video" i], ' +
      'button[aria-label*="Turn off video" i]'
    );
    if (huddleVideoBtn) {
      window.LazyTypeInjector.safeClick(huddleVideoBtn);
      return { success: true, message: 'Slack Huddle video toggled' };
    }
    throw new Error('NO_ACTIVE_HUDDLE');
  }
};
