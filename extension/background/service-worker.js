/**
 * LazyType Chrome Extension - Background Service Worker
 * Maintains WebSocket bridge to Mac Companion App (ws://127.0.0.1:8765/ws/extension)
 */

const DEFAULT_SERVER_URL = 'ws://127.0.0.1:9123/ws/extension';
let socket = null;
let isConnecting = false;

const CONTENT_SCRIPT_FILES = [
  'content/dom-injector.js',
  'adapters/demo-chat.js',
  'adapters/google-meet.js',
  'adapters/zoom-web.js',
  'adapters/teams-web.js',
  'adapters/slack-web.js',
  'adapters/generic-web.js',
  'content/content-script.js'
];

/**
 * Ensure content script is actively running in the given tab before sending commands.
 * Injects dynamically on-demand if the tab was opened before extension was loaded.
 */
async function ensureTabReady(tabId) {
  if (!tabId) return false;
  try {
    const res = await chrome.tabs.sendMessage(tabId, { action: 'PING' });
    if (res && res.pong) {
      return true;
    }
  } catch (err) {
    // Content script not yet attached
  }

  try {
    console.log(`[LazyType SW] Proactively injecting content scripts into tab ${tabId}...`);
    await chrome.scripting.executeScript({
      target: { tabId, allFrames: true },
      files: CONTENT_SCRIPT_FILES
    });
    // Brief settle time
    await new Promise(r => setTimeout(r, 60));
    return true;
  } catch (injectErr) {
    console.warn(`[LazyType SW] Failed to inject scripts into tab ${tabId}:`, injectErr);
    return false;
  }
}

// Initialize on extension startup / install
chrome.runtime.onInstalled.addListener(async () => {
  console.log('[LazyType SW] Extension installed');
  await chrome.storage.local.set({ serverUrl: DEFAULT_SERVER_URL, connected: false });
  setupAlarm();
  connectWebSocket();

  // Proactively inject into all open web tabs
  try {
    const tabs = await chrome.tabs.query({});
    for (const tab of tabs) {
      if (tab.id && tab.url && !tab.url.startsWith('chrome://') && !tab.url.startsWith('chrome-extension://')) {
        chrome.scripting.executeScript({
          target: { tabId: tab.id, allFrames: true },
          files: CONTENT_SCRIPT_FILES
        }).catch(() => {});
      }
    }
  } catch (e) {
    console.warn('[LazyType SW] Tab bootstrap injection error:', e);
  }
});

chrome.runtime.onStartup.addListener(() => {
  console.log('[LazyType SW] Extension started');
  setupAlarm();
  connectWebSocket();
});

// React immediately to tab switching, URL changes, and window focus
chrome.tabs.onActivated.addListener(() => {
  reportActiveTabState();
});

chrome.tabs.onUpdated.addListener((tabId, changeInfo) => {
  if (changeInfo.status === 'complete' || changeInfo.url) {
    reportActiveTabState();
  }
});

chrome.windows.onFocusChanged.addListener((windowId) => {
  if (windowId !== chrome.windows.WINDOW_ID_NONE) {
    reportActiveTabState();
  }
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

  // Ensure content script is ready in targetTab
  await ensureTabReady(targetTab.id);

  try {
    let response;
    try {
      response = await chrome.tabs.sendMessage(targetTab.id, cmd);
    } catch (sendErr) {
      if (sendErr.message && sendErr.message.includes('Receiving end does not exist')) {
        console.log('[LazyType SW] Retrying after fresh injection...');
        await ensureTabReady(targetTab.id);
        response = await chrome.tabs.sendMessage(targetTab.id, cmd);
      } else {
        throw sendErr;
      }
    }

    // If main frame didn't find chat input, check other frames in the tab!
    if (response && !response.success && response.errorCode === 'CHAT_INPUT_NOT_FOUND') {
      try {
        const frames = await chrome.webNavigation.getAllFrames({ tabId: targetTab.id });
        if (frames && frames.length > 1) {
          for (const frame of frames) {
            if (frame.frameId === 0) continue;
            try {
              const frameResponse = await chrome.tabs.sendMessage(targetTab.id, cmd, { frameId: frame.frameId });
              if (frameResponse && frameResponse.success) {
                response = frameResponse;
                break;
              }
            } catch (fe) {}
          }
        }
      } catch (navErr) {}
    }

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
  // 1. TOP PRIORITY: The tab the user is currently viewing on their screen!
  const [activeTab] = await chrome.tabs.query({ active: true, lastFocusedWindow: true });
  if (activeTab && activeTab.url && !activeTab.url.startsWith('chrome://') && !activeTab.url.startsWith('chrome-extension://')) {
    return activeTab;
  }

  // 2. Active tab across any normal window
  const activeTabs = await chrome.tabs.query({ active: true });
  const validActive = activeTabs.find(t => t.url && !t.url.startsWith('chrome://') && !t.url.startsWith('chrome-extension://'));
  if (validActive) return validActive;

  // 3. Meeting tab if specifically targeted or in background
  const tabs = await chrome.tabs.query({});
  if (!tabs || tabs.length === 0) return null;

  const meetingTabs = tabs.filter(t => {
    const u = t.url || '';
    return u.includes('/demo') || u.includes('meet.google.com') || u.includes('zoom.us') || u.includes('teams.microsoft.com');
  });

  if (meetingTabs.length > 0) {
    const activeMeeting = meetingTabs.find(t => t.active);
    if (activeMeeting) return activeMeeting;
    return meetingTabs[0];
  }

  return tabs.find(t => t.url && !t.url.startsWith('chrome://') && !t.url.startsWith('chrome-extension://')) || tabs[0];
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
    await ensureTabReady(tab.id);
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
