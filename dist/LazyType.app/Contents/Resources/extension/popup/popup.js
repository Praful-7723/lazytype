/**
 * LazyType Extension Popup Logic
 */

document.addEventListener('DOMContentLoaded', async () => {
  const statusPill = document.getElementById('status-pill');
  const serverUrlInput = document.getElementById('server-url-input');
  const reconnectBtn = document.getElementById('reconnect-btn');
  const detectedAdapterEl = document.getElementById('detected-adapter');
  const meetingStatusEl = document.getElementById('meeting-status');
  const chatStatusEl = document.getElementById('chat-status');

  // Load saved server URL
  const { serverUrl = 'ws://127.0.0.1:9123/ws/extension', connected = false } =
    await chrome.storage.local.get(['serverUrl', 'connected']);

  serverUrlInput.value = serverUrl;
  updateStatusUI(connected);

  // Check active tab state
  await refreshActiveTab();

  reconnectBtn.addEventListener('click', async () => {
    const newUrl = serverUrlInput.value.trim();
    if (newUrl) {
      await chrome.storage.local.set({ serverUrl: newUrl });
      chrome.runtime.sendMessage({ action: 'RECONNECT' }).catch(() => {});
      statusPill.textContent = 'Connecting...';
    }
  });

  async function updateStatusUI(isConnected) {
    if (isConnected) {
      statusPill.textContent = 'Connected ✓';
      statusPill.className = 'status-pill connected';
    } else {
      statusPill.textContent = 'Disconnected';
      statusPill.className = 'status-pill';
    }
  }

  async function refreshActiveTab() {
    try {
      const [activeTab] = await chrome.tabs.query({ active: true, lastFocusedWindow: true });
      if (!activeTab) {
        detectedAdapterEl.textContent = 'No active tab';
        return;
      }

      const response = await chrome.tabs.sendMessage(activeTab.id, { action: 'GET_STATE' });
      if (response && response.adapter) {
        detectedAdapterEl.textContent = response.adapter;
        meetingStatusEl.textContent = response.meetingDetected ? 'Active Meeting ✓' : 'No Meeting';
        meetingStatusEl.style.color = response.meetingDetected ? '#22c55e' : '#94a3b8';
        chatStatusEl.textContent = response.chatOpen ? 'Chat Open' : (response.chatAvailable ? 'Ready' : 'Not found');
      } else {
        detectedAdapterEl.textContent = 'Generic Web Page';
      }
    } catch (err) {
      detectedAdapterEl.textContent = 'Standard Web Page';
    }
  }
});
