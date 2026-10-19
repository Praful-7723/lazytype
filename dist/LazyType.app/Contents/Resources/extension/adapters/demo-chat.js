/**
 * Demo Meeting Web Adapter
 */
window.DemoChatAdapter = {
  id: 'demo-chat',
  name: 'Demo Meeting Chat',

  match() {
    return !!(
      document.body?.dataset?.app === 'demo-chat' ||
      document.getElementById('demo-chat-input') ||
      window.location.pathname.includes('/demo')
    );
  },

  getState() {
    const isMeetingActive = true;
    const chatPanel = document.getElementById('chat-panel');
    const isChatOpen = chatPanel ? !chatPanel.classList.contains('closed') : false;
    const inputEl = document.getElementById('demo-chat-input');
    const chatAvailable = !!inputEl;

    return {
      adapter: this.id,
      meetingDetected: isMeetingActive,
      chatAvailable: chatAvailable,
      chatOpen: isChatOpen,
      canSendMessage: true,
      canMute: true,
      canControlCamera: true
    };
  },

  async openChat() {
    const chatPanel = document.getElementById('chat-panel');
    const toggleBtn = document.getElementById('chat-toggle-btn');
    if (chatPanel && chatPanel.classList.contains('closed') && toggleBtn) {
      window.LazyTypeInjector.safeClick(toggleBtn);
      await new Promise(r => setTimeout(r, 100));
    }
    return true;
  },

  async sendMessage(text) {
    await this.openChat();
    const input = document.getElementById('demo-chat-input');
    if (!input) throw new Error('INPUT_NOT_FOUND');

    window.LazyTypeInjector.insertText(input, text);
    await new Promise(r => setTimeout(r, 50));

    const sendBtn = document.getElementById('demo-send-btn');
    if (sendBtn) {
      window.LazyTypeInjector.safeClick(sendBtn);
    } else {
      window.LazyTypeInjector.dispatchEnter(input);
    }
    return { success: true, message: 'Message sent in Demo Meeting ✓' };
  },

  async insertText(text) {
    await this.openChat();
    const input = document.getElementById('demo-chat-input');
    if (!input) throw new Error('INPUT_NOT_FOUND');
    window.LazyTypeInjector.insertText(input, text);
    return { success: true, message: 'Text inserted in Demo Meeting' };
  },

  async toggleMute() {
    const muteBtn = document.getElementById('mute-btn');
    if (!muteBtn) throw new Error('MUTE_BUTTON_NOT_FOUND');
    window.LazyTypeInjector.safeClick(muteBtn);
    return { success: true, message: 'Mute toggled' };
  },

  async toggleCamera() {
    const camBtn = document.getElementById('camera-btn');
    if (!camBtn) throw new Error('CAMERA_BUTTON_NOT_FOUND');
    window.LazyTypeInjector.safeClick(camBtn);
    return { success: true, message: 'Camera toggled' };
  }
};
