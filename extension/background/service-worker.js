/**
 * LazyType Chrome Extension - Background Service Worker
 * Maintains WebSocket bridge to Mac Companion App (ws://127.0.0.1:8765/ws/extension)
 */

const DEFAULT_SERVER_URL = 'ws://127.0.0.1:9123/ws/extension';
let socket = null;
let isConnecting = false;

// Initialize on extension startup / install
chrome.runtime.onInstalled.addListener(async () => {
  console.log('[LazyType SW] Extension installed');
  await chrome.storage.local.set({ serverUrl: DEFAULT_SERVER_URL, connected: false });
  setupAlarm();
  connectWebSocket();
});

chrome.runtime.onStartup.addListener(() => {
  console.log('[LazyType SW] Extension started');
  setupAlarm();
  connectWebSocket();
});

// Alarm for periodic keep-alive and reconnection checks
function setupAlarm() {
  chrome.alarms.create('lazytype-keepalive', { periodInMinutes: 0.5 });
}

chrome.alarms.onAlarm.addListener((alarm) => {
  if (alarm.name === 'lazytype-keepalive') {
    checkConnection();
  }
});

async function checkConnection() {
  if (!socket || socket.readyState !== WebSocket.OPEN) {
    console.log('[LazyType SW] Keep-alive reconnect check...');
    connectWebSocket();
  } else {
    // Send periodic tab state update
    await reportActiveTabState();
  }
}

async function connectWebSocket() {
  if (isConnecting) return;
  if (socket && (socket.readyState === WebSocket.OPEN || socket.readyState === WebSocket.CONNECTING)) {
    return;
  }

  isConnecting = true;
  const { serverUrl = DEFAULT_SERVER_URL } = await chrome.storage.local.get('serverUrl');

  try {
    socket = new WebSocket(serverUrl);

    socket.onopen = async () => {
      console.log('[LazyType SW] Connected to Mac Companion');
      isConnecting = false;
      await chrome.storage.local.set({ connected: true });
      await chrome.action.setBadgeText({ text: 'ON' });
      await chrome.action.setBadgeBackgroundColor({ color: '#22c55e' });

      // Register with Mac companion
      socket.send(JSON.stringify({
        type: 'EXT_REGISTER',
        version: chrome.runtime.getManifest().version
      }));

      await reportActiveTabState();
    };

    socket.onmessage = async (event) => {
      try {
        const payload = JSON.parse(event.data);
        await handleMacCommand(payload);
      } catch (err) {
        console.error('[LazyType SW] Error processing message:', err);
      }
    };

    socket.onclose = async () => {
      console.log('[LazyType SW] WebSocket closed');
      isConnecting = false;
      socket = null;
      await chrome.storage.local.set({ connected: false });
      await chrome.action.setBadgeText({ text: 'OFF' });
      await chrome.action.setBadgeBackgroundColor({ color: '#ef4444' });
    };

    socket.onerror = (err) => {
      console.warn('[LazyType SW] WebSocket error:', err);
      isConnecting = false;
    };
  } catch (err) {
    console.error('[LazyType SW] Connection setup exception:', err);
    isConnecting = false;
  }
}

// Route command from Mac to target browser tab
async function handleMacCommand(cmd) {
  const requestId = cmd.requestId;

  // Find best target tab (prefer focused window active tab, or meeting tabs)
  const targetTab = await findTargetTab(cmd.target);
  if (!targetTab) {
    if (socket && socket.readyState === WebSocket.OPEN) {
      socket.send(JSON.stringify({
        type: 'COMMAND_RESULT',
        requestId,
        success: false,
        errorCode: 'TARGET_TAB_NOT_FOUND',
        message: 'No active supported meeting or browser tab found'
      }));
    }
    return;
  }

  try {
    const response = await chrome.tabs.sendMessage(targetTab.id, cmd);
    if (socket && socket.readyState === WebSocket.OPEN) {
      socket.send(JSON.stringify({
        type: 'COMMAND_RESULT',
        requestId,
        ...response
      }));
    }
  } catch (err) {
    if (socket && socket.readyState === WebSocket.OPEN) {
      socket.send(JSON.stringify({
        type: 'COMMAND_RESULT',
        requestId,
        success: false,
        errorCode: 'CONTENT_SCRIPT_UNREACHABLE',
        message: err.message || 'Could not communicate with tab content script'
      }));
    }
  }
}

// Find appropriate tab based on criteria
async function findTargetTab(preferredAdapter) {
  // Query all tabs in current window or all windows
  const tabs = await chrome.tabs.query({});
  if (!tabs || tabs.length === 0) return null;

  // 1. Look for matching meeting tabs (Demo Chat, Google Meet, Zoom Web)
  const meetingTabs = tabs.filter(t => {
    const u = t.url || '';
    return u.includes('/demo') || u.includes('meet.google.com') || u.includes('zoom.us/wc');
  });

  if (meetingTabs.length > 0) {
    // If one is active in its window, pick it
    const activeMeeting = meetingTabs.find(t => t.active);
    if (activeMeeting) return activeMeeting;
    return meetingTabs[0];
  }

  // 2. Fall back to the active tab in the currently focused window
  const [activeTab] = await chrome.tabs.query({ active: true, lastFocusedWindow: true });
  if (activeTab) return activeTab;

  return tabs[0];
}

// Query active tab and send its state to Mac companion
async function reportActiveTabState() {
  if (!socket || socket.readyState !== WebSocket.OPEN) return;

  const tab = await findTargetTab();
  if (!tab) {
    socket.send(JSON.stringify({
      type: 'EXT_TAB_STATE',
      active: false,
      meetingDetected: false,
      chatAvailable: false
    }));
    return;
  }

  try {
    const state = await chrome.tabs.sendMessage(tab.id, { action: 'GET_STATE' });
    if (state && socket.readyState === WebSocket.OPEN) {
      socket.send(JSON.stringify({
        type: 'EXT_TAB_STATE',
        tabId: tab.id,
        url: tab.url,
        title: tab.title,
        ...state
      }));
    }
  } catch (err) {
    // Tab might be chrome:// or loading
    socket.send(JSON.stringify({
      type: 'EXT_TAB_STATE',
      tabId: tab.id,
      url: tab.url,
      meetingDetected: false,
      chatAvailable: false
    }));
  }
}

// Forward messages from content script to Mac if needed
chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  (async () => {
    if (message.type === 'EXT_TAB_STATE' && socket && socket.readyState === WebSocket.OPEN) {
      socket.send(JSON.stringify({
        ...message,
        tabId: sender.tab?.id
      }));
      sendResponse({ received: true });
    } else if (message.type === 'GET_STATUS') {
      const { connected = false } = await chrome.storage.local.get('connected');
      sendResponse({ connected });
    }
  })();
  return true;
});
