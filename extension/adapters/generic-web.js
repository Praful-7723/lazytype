/**
 * Generic Web Adapter Fallback
 */
window.GenericWebAdapter = {
  id: 'generic-web',
  name: 'Generic Browser Field',

  match() {
    return true; // Fallback
  },

  findActiveInput() {
    const active = document.activeElement;
    if (active && (active.tagName === 'TEXTAREA' || active.tagName === 'INPUT' || active.isContentEditable)) {
      return active;
    }
    // Search visible inputs
    const inputs = Array.from(document.querySelectorAll('textarea, div[contenteditable="true"], input[type="text"]'));
    return inputs.find(el => el.offsetParent !== null);
  },

  getState() {
    const input = this.findActiveInput();
    return {
      adapter: this.id,
      meetingDetected: false,
      chatAvailable: !!input,
      chatOpen: !!input,
      canSendMessage: !!input,
      canMute: false,
      canControlCamera: false
    };
  },

  async openChat() {
    const input = this.findActiveInput();
    if (input) input.focus();
    return true;
  },

  async sendMessage(text) {
    const input = this.findActiveInput();
    if (!input) throw new Error('INPUT_NOT_FOUND');

    window.LazyTypeInjector.insertText(input, text);
    await new Promise(r => setTimeout(r, 50));
    window.LazyTypeInjector.dispatchEnter(input);

    return { success: true, message: 'Message typed & Enter sent in active browser tab ✓' };
  },

  async insertText(text) {
    const input = this.findActiveInput();
    if (!input) throw new Error('INPUT_NOT_FOUND');
    window.LazyTypeInjector.insertText(input, text);
    return { success: true, message: 'Text inserted into active element' };
  },

  async toggleMute() {
    throw new Error('NOT_SUPPORTED_IN_GENERIC_MODE');
  },

  async toggleCamera() {
    throw new Error('NOT_SUPPORTED_IN_GENERIC_MODE');
  }
};
