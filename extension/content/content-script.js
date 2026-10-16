/**
 * LazyType Chrome Extension - Content Script
 */

(function () {
  const ADAPTERS = [
    window.DemoChatAdapter,
    window.GoogleMeetAdapter,
    window.ZoomWebAdapter,
    window.TeamsWebAdapter,
    window.SlackWebAdapter,
    window.GenericWebAdapter
  ].filter(Boolean);

  function getActiveAdapter() {
    for (const adapter of ADAPTERS) {
      try {
        if (adapter && typeof adapter.match === 'function' && adapter.match()) {
          return adapter;
        }
      } catch (err) {
        console.warn('[LazyType] Adapter match error:', err);
      }
    }
    return window.GenericWebAdapter;
  }

  // Handle incoming commands from background service worker
  chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
    (async () => {
      const adapter = getActiveAdapter();
      const requestId = request.requestId;

      try {
        switch (request.action) {
          case 'GET_STATE': {
            const state = adapter.getState();
            sendResponse({ success: true, requestId, ...state, url: window.location.href });
            break;
          }

          case 'SEND_MESSAGE': {
            const result = await adapter.sendMessage(request.text || '');
            sendResponse({ success: true, requestId, adapter: adapter.id, ...result });
            break;
          }

          case 'INSERT_TEXT': {
            const result = await adapter.insertText(request.text || '');
            sendResponse({ success: true, requestId, adapter: adapter.id, ...result });
            break;
          }

          case 'OPEN_CHAT': {
            const result = await adapter.openChat();
            sendResponse({ success: true, requestId, adapter: adapter.id, result });
            break;
          }

          case 'TOGGLE_MUTE': {
            const result = await adapter.toggleMute();
            sendResponse({ success: true, requestId, adapter: adapter.id, ...result });
            break;
          }

          case 'TOGGLE_CAMERA': {
            const result = await adapter.toggleCamera();
            sendResponse({ success: true, requestId, adapter: adapter.id, ...result });
            break;
          }

          case 'PRESS_KEY': {
            const target = adapter.findActiveInput ? adapter.findActiveInput() : document.activeElement;
            window.LazyTypeInjector.dispatchKey(target, request.key, request.modifiers);
            sendResponse({ success: true, requestId, adapter: adapter.id, message: `Key ${request.key} dispatched` });
            break;
          }

          default:
            sendResponse({
              success: false,
              requestId,
              errorCode: 'UNKNOWN_ACTION',
              message: `Unknown action: ${request.action}`
            });
        }
      } catch (err) {
        console.error('[LazyType] Command execution error:', err);
        sendResponse({
          success: false,
          requestId,
          adapter: adapter.id,
          errorCode: err.message || 'EXECUTION_FAILED',
          message: err.message || 'Failed to execute command in page'
        });
      }
    })();

    return true; // Keep message channel open for async response
  });

  // Report initial state on page load
  try {
    const adapter = getActiveAdapter();
    const state = adapter.getState();
    chrome.runtime.sendMessage({
      type: 'EXT_TAB_STATE',
      url: window.location.href,
      ...state
    }).catch(() => {});
  } catch (e) {
    // Service worker might be sleeping initially
  }
})();
