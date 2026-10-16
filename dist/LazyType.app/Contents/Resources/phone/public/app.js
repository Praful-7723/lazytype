/**
 * LazyType Phone Companion PWA Application
 * Frictionless Instant Pairing & One-Handed Controller
 */

(function () {
  'use strict';

  // Safe LocalStorage Helpers (never crash on private browsing or restricted WebViews)
  function safeGetStorage(key, defaultVal = '') {
    try {
      const v = localStorage.getItem(key);
      return v !== null ? v : defaultVal;
    } catch (e) {
      return defaultVal;
    }
  }

  function safeSetStorage(key, val) {
    try {
      localStorage.setItem(key, val);
    } catch (e) {}
  }

  function safeRemoveStorage(key) {
    try {
      localStorage.removeItem(key);
    } catch (e) {}
  }

  // Application State
  const state = {
    socket: null,
    isConnected: false,
    isReconnecting: false,
    reconnectTimer: null,
    reconnectDelay: 1000,
    host: window.location.hostname || '127.0.0.1',
    port: window.location.port || '9123',
    token: '',
    sessionToken: safeGetStorage('lazytype_session_token', ''),
    deviceId: getOrCreateDeviceId(),
    deviceName: getDeviceName(),
    macName: 'MacBook',
    activeMode: 'send', // 'send' | 'insert' | 'live'
    target: 'auto',
    pendingRequests: new Map(),
    messageHistory: (() => {
      try {
        return JSON.parse(safeGetStorage('lazytype_history', '[]'));
      } catch (e) {
        return [];
      }
    })(),
    liveDebounceTimer: null,
    isListening: false,
    speechRecognizer: null
  };

  // DOM Elements - Pairing Screen
  const screenPairing = document.getElementById('screen-pairing');
  const screenController = document.getElementById('screen-controller');
  const connectTitle = document.getElementById('connect-title');
  const connectStatus = document.getElementById('connect-status');
  const btnToggleManual = document.getElementById('btn-toggle-manual');
  const manualSettingsForm = document.getElementById('manual-settings-form');
  const inputHost = document.getElementById('input-host');
  const inputPort = document.getElementById('input-port');
  const inputToken = document.getElementById('input-token');
  const btnManualConnect = document.getElementById('btn-manual-connect');

  // DOM Elements - Controller Screen
  const statusDot = document.getElementById('status-dot');
  const macNameEl = document.getElementById('mac-name');
  const connectionStateEl = document.getElementById('connection-state');
  const btnDisconnect = document.getElementById('btn-disconnect');
  const targetSelect = document.getElementById('target-select');
  const badgeMeeting = document.getElementById('badge-meeting');
  const badgeChat = document.getElementById('badge-chat');

  const tabSend = document.getElementById('tab-send');
  const tabInsert = document.getElementById('tab-insert');
  const tabLive = document.getElementById('tab-live');
  const messageInput = document.getElementById('message-input');
  const btnVoiceDictate = document.getElementById('btn-voice-dictate');
  const btnClearText = document.getElementById('btn-clear-text');
  const btnSendMessage = document.getElementById('btn-send-message');
  const sendButtonLabel = document.getElementById('send-button-label');

  const btnMute = document.getElementById('btn-mute');
  const btnCamera = document.getElementById('btn-camera');
  const btnOpenChat = document.getElementById('btn-open-chat');
  const btnPaste = document.getElementById('btn-paste');
  const quickMuteLabel = document.getElementById('quick-mute-label');
  const quickCamLabel = document.getElementById('quick-cam-label');

  const historyList = document.getElementById('history-list');
  const btnClearHistory = document.getElementById('btn-clear-history');
  const toast = document.getElementById('toast');
  const toastMessage = document.getElementById('toast-message');

  // App Initialization
  init();

  function init() {
    registerServiceWorker();
    renderHistory();
    setupEventListeners();
    autoConnectFlow();
  }

  function registerServiceWorker() {
    if ('serviceWorker' in navigator && window.location.protocol.startsWith('http')) {
      navigator.serviceWorker.register('/sw.js').catch(err => {
        console.warn('[PWA] Service worker register failed (ignoring for local dev):', err);
      });
    }
  }

  function getOrCreateDeviceId() {
    let id = safeGetStorage('lazytype_device_id', '');
    if (!id) {
      id = 'phone_' + Math.random().toString(36).substring(2, 10);
      safeSetStorage('lazytype_device_id', id);
    }
    return id;
  }

  function getDeviceName() {
    const ua = navigator.userAgent;
    if (ua.includes('Pixel')) return 'Google Pixel';
    if (ua.includes('Samsung') || ua.includes('SM-')) return 'Samsung Galaxy';
    if (ua.includes('Android')) return 'Android Phone';
    if (ua.includes('iPhone')) return 'iPhone';
    return 'Mobile Companion';
  }

  // Screen Transitions
  function showScreen(name) {
    if (name === 'controller') {
      screenPairing.classList.remove('active');
      screenPairing.classList.add('hidden');
      screenController.classList.remove('hidden');
      screenController.classList.add('active');
      setTimeout(() => {
        if (messageInput) messageInput.focus();
      }, 150);
    } else {
      screenController.classList.remove('active');
      screenController.classList.add('hidden');
      screenPairing.classList.remove('hidden');
      screenPairing.classList.add('active');
    }
  }

  // Setup UI Event Listeners
  function setupEventListeners() {
    // Mode tabs
    [tabSend, tabInsert, tabLive].forEach(tab => {
      if (!tab) return;
      tab.addEventListener('click', () => {
        [tabSend, tabInsert, tabLive].forEach(t => t.classList.remove('active'));
        tab.classList.add('active');
        state.activeMode = tab.dataset.mode;

        if (state.activeMode === 'send') {
          sendButtonLabel.textContent = 'SEND MESSAGE';
        } else if (state.activeMode === 'insert') {
          sendButtonLabel.textContent = 'INSERT ONLY';
        } else if (state.activeMode === 'live') {
          sendButtonLabel.textContent = 'LIVE STREAMING';
        }
      });
    });

    // Target selector
    if (targetSelect) {
      targetSelect.addEventListener('change', (e) => {
        state.target = e.target.value;
        sendWsMessage({ type: 'SET_TARGET', target: state.target });
      });
    }

    // Send button
    if (btnSendMessage) {
      btnSendMessage.addEventListener('click', handleSendAction);
    }

    // Textarea enter key to send in 'send' mode
    if (messageInput) {
      messageInput.addEventListener('keydown', (e) => {
        if (e.key === 'Enter' && !e.shiftKey && state.activeMode === 'send') {
          e.preventDefault();
          handleSendAction();
        }
      });

      // Textarea input watcher
      messageInput.addEventListener('input', () => {
        if (btnClearText) {
          btnClearText.classList.toggle('hidden', !messageInput.value.trim());
        }

        if (state.activeMode === 'live') {
          clearTimeout(state.liveDebounceTimer);
          state.liveDebounceTimer = setTimeout(() => {
            sendWsMessage({
              type: 'INSERT_TEXT',
              target: state.target,
              text: messageInput.value
            });
          }, 150);
        }
      });
    }

    // Clear text button
    if (btnClearText) {
      btnClearText.addEventListener('click', () => {
        messageInput.value = '';
        btnClearText.classList.add('hidden');
        messageInput.focus();
      });
    }

    // Quick canned reply chips
    document.querySelectorAll('.quick-reply-chip').forEach(chip => {
      chip.addEventListener('click', () => {
        const text = chip.dataset.text;
        if (text && messageInput) {
          messageInput.value = text;
          if (btnClearText) btnClearText.classList.remove('hidden');
          messageInput.focus();
          vibrate(25);
        }
      });
    });

    // Voice dictation button
    if (btnVoiceDictate) {
      btnVoiceDictate.addEventListener('click', toggleVoiceDictation);
    }

    // Quick meeting controls
    if (btnMute) {
      btnMute.addEventListener('click', () => {
        sendWsCommand('TOGGLE_MUTE', {}, (res) => {
          showToast(res.message || 'Mute toggled', res.success);
        });
      });
    }

    if (btnCamera) {
      btnCamera.addEventListener('click', () => {
        sendWsCommand('TOGGLE_CAMERA', {}, (res) => {
          showToast(res.message || 'Camera toggled', res.success);
        });
      });
    }

    if (btnOpenChat) {
      btnOpenChat.addEventListener('click', () => {
        sendWsCommand('OPEN_CHAT', { target: state.target }, (res) => {
          showToast(res.message || 'Chat panel invoked', res.success);
        });
      });
    }

    if (btnPaste) {
      btnPaste.addEventListener('click', async () => {
        try {
          const clipText = await navigator.clipboard.readText();
          if (clipText) {
            messageInput.value = clipText;
            if (btnClearText) btnClearText.classList.remove('hidden');
            showToast('Clipboard pasted', true);
          } else {
            showToast('Clipboard is empty', false);
          }
        } catch (err) {
          showToast('Clipboard permission needed', false);
        }
      });
    }

    // Emulated key buttons
    document.querySelectorAll('.key-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        const key = btn.dataset.key;
        sendWsCommand('PRESS_KEY', { key }, (res) => {
          vibrate(20);
        });
      });
    });

    // Clear history
    if (btnClearHistory) {
      btnClearHistory.addEventListener('click', () => {
        state.messageHistory = [];
        safeRemoveStorage('lazytype_history');
        renderHistory();
      });
    }

    // Disconnect button
    if (btnDisconnect) {
      btnDisconnect.addEventListener('click', () => {
        disconnect();
        showScreen('pairing');
        if (connectTitle) connectTitle.textContent = 'Disconnected';
        if (connectStatus) connectStatus.textContent = 'Tap Connect to re-establish session';
        if (manualSettingsForm) manualSettingsForm.classList.remove('hidden');
      });
    }

    // Toggle manual settings form
    if (btnToggleManual && manualSettingsForm) {
      btnToggleManual.addEventListener('click', () => {
        manualSettingsForm.classList.toggle('hidden');
      });
    }

    // Manual connect button
    if (btnManualConnect) {
      btnManualConnect.addEventListener('click', async () => {
        const host = inputHost.value.trim() || state.host;
        const port = inputPort.value.trim() || state.port;
        let token = inputToken.value.trim();

        state.host = host;
        state.port = port;

        if (!token) {
          try {
            const res = await fetch(`http://${host}:${port}/api/pair-token`);
            if (res.ok) {
              const data = await res.json();
              if (data && data.token) token = data.token;
            }
          } catch (e) {}
        }

        state.token = token;
        if (connectTitle) connectTitle.textContent = 'Connecting...';
        if (connectStatus) connectStatus.textContent = `Attempting handshake with ${host}:${port}`;
        connectWebSocket();
      });
    }
  }

  // Voice Dictation (Web Speech API)
  function toggleVoiceDictation() {
    const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
    if (!SpeechRecognition) {
      showToast('Voice dictation not supported in this browser', false);
      return;
    }

    if (state.isListening && state.speechRecognizer) {
      try {
        state.speechRecognizer.stop();
      } catch (e) {}
      state.isListening = false;
      if (btnVoiceDictate) btnVoiceDictate.classList.remove('listening');
      return;
    }

    try {
      const recognition = new SpeechRecognition();
      recognition.continuous = false;
      recognition.interimResults = true;
      recognition.lang = navigator.language || 'en-US';

      recognition.onstart = () => {
        state.isListening = true;
        if (btnVoiceDictate) btnVoiceDictate.classList.add('listening');
        vibrate(30);
      };

      recognition.onresult = (event) => {
        let transcript = '';
        for (let i = event.resultIndex; i < event.results.length; i++) {
          transcript += event.results[i][0].transcript;
        }
        if (transcript) {
          const currentText = messageInput.value.trim();
          messageInput.value = currentText ? `${currentText} ${transcript}` : transcript;
          if (btnClearText) btnClearText.classList.remove('hidden');

          if (state.activeMode === 'live') {
            clearTimeout(state.liveDebounceTimer);
            state.liveDebounceTimer = setTimeout(() => {
              sendWsMessage({
                type: 'INSERT_TEXT',
                target: state.target,
                text: messageInput.value
              });
            }, 150);
          }
        }
      };

      recognition.onerror = (event) => {
        state.isListening = false;
        if (btnVoiceDictate) btnVoiceDictate.classList.remove('listening');
        if (event.error !== 'no-speech') {
          showToast(`Voice error: ${event.error}`, false);
        }
      };

      recognition.onend = () => {
        state.isListening = false;
        if (btnVoiceDictate) btnVoiceDictate.classList.remove('listening');
      };

      state.speechRecognizer = recognition;
      recognition.start();
    } catch (err) {
      state.isListening = false;
      if (btnVoiceDictate) btnVoiceDictate.classList.remove('listening');
      showToast('Could not start microphone', false);
    }
  }

  // Send Message Primary Action
  function handleSendAction() {
    const text = messageInput.value.trim();
    if (!text) {
      messageInput.focus();
      return;
    }

    vibrate(40);

    if (state.activeMode === 'send') {
      sendWsCommand('SEND_MESSAGE', { target: state.target, text }, (res) => {
        if (res.success) {
          showToast(res.message || 'Message sent ✓', true);
          addToHistory(text);
          messageInput.value = '';
          if (btnClearText) btnClearText.classList.add('hidden');
        } else {
          showToast(res.message || res.errorCode || 'Failed to send', false);
        }
      });
    } else if (state.activeMode === 'insert') {
      sendWsCommand('INSERT_TEXT', { target: state.target, text }, (res) => {
        if (res.success) {
          showToast('Text inserted ✓', true);
          addToHistory(text);
        } else {
          showToast(res.message || 'Failed to insert text', false);
        }
      });
    }
  }

  // Automatic One-Tap Connection Flow
  async function autoConnectFlow() {
    const params = new URLSearchParams(window.location.search);
    const urlToken = params.get('token');
    const urlHost = params.get('host');
    const urlPort = params.get('port');

    if (urlHost) state.host = urlHost;
    if (urlPort) state.port = urlPort;
    if (urlToken) state.token = urlToken;

    if (inputHost) inputHost.value = state.host;
    if (inputPort) inputPort.value = state.port;
    if (inputToken && urlToken) inputToken.value = urlToken;

    // 1. Resuming previous session
    if (state.sessionToken) {
      if (connectTitle) connectTitle.textContent = 'Resuming Session...';
      if (connectStatus) connectStatus.textContent = 'Reconnecting with saved authentication';
      connectWebSocket();
      return;
    }

    // 2. Token passed via QR code scan or 1-click URL
    if (state.token) {
      if (connectTitle) connectTitle.textContent = 'Pairing with Mac...';
      if (connectStatus) connectStatus.textContent = 'Validating pairing credentials';
      connectWebSocket();
      return;
    }

    // 3. User opened page on local network without query params:
    // Auto-fetch the active pairing token from the local Mac Companion!
    if (connectTitle) connectTitle.textContent = 'Detecting Mac Companion...';
    if (connectStatus) connectStatus.textContent = 'Instant handshake in progress';

    try {
      const res = await fetch('/api/pair-token');
      if (res.ok) {
        const data = await res.json();
        if (data && data.token) {
          state.token = data.token;
          if (inputToken) inputToken.value = data.token;
          if (connectTitle) connectTitle.textContent = 'Pairing with Mac...';
          if (connectStatus) connectStatus.textContent = 'Pairing with local companion bridge';
          connectWebSocket();
          return;
        }
      }
    } catch (err) {
      console.log('[LazyType] Auto pair fetch error:', err);
    }

    // 4. Fallback if automatic discovery couldn't reach API
    if (connectTitle) connectTitle.textContent = 'Connect to Mac';
    if (connectStatus) connectStatus.textContent = 'Please confirm connection details below';
    if (manualSettingsForm) manualSettingsForm.classList.remove('hidden');
  }

  // WebSocket Connection & Session Management
  function connectWebSocket() {
    if (state.socket && (state.socket.readyState === WebSocket.OPEN || state.socket.readyState === WebSocket.CONNECTING)) {
      return;
    }

    const host = state.host || window.location.hostname || '127.0.0.1';
    const port = state.port || window.location.port || '9123';
    const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
    const wsUrl = `${protocol}//${host}:${port}/ws/phone`;

    setConnectionStatus('connecting');

    try {
      const ws = new WebSocket(wsUrl);
      state.socket = ws;

      ws.onopen = () => {
        console.log('[LazyType] WebSocket open to', wsUrl);
        state.reconnectDelay = 1000;

        // Perform Handshake: either PAIR or AUTH
        if (state.token) {
          sendWsMessage({
            type: 'PAIR',
            requestId: 'req_pair_' + Date.now(),
            token: state.token,
            deviceId: state.deviceId,
            deviceName: state.deviceName
          });
        } else if (state.sessionToken) {
          sendWsMessage({
            type: 'AUTH',
            requestId: 'req_auth_' + Date.now(),
            sessionToken: state.sessionToken,
            deviceId: state.deviceId,
            deviceName: state.deviceName
          });
        } else {
          // Attempting to fetch token dynamically
          autoConnectFlow();
        }
      };

      ws.onmessage = (event) => {
        try {
          const msg = JSON.parse(event.data);
          handleIncomingMessage(msg);
        } catch (err) {
          console.error('[LazyType] Error parsing WS message:', err);
        }
      };

      ws.onclose = (event) => {
        console.log('[LazyType] WebSocket closed:', event.code, event.reason);
        setConnectionStatus('disconnected');
        state.socket = null;

        // Auto-reconnect if session token exists
        if (state.sessionToken) {
          scheduleReconnect();
        }
      };

      ws.onerror = (err) => {
        console.warn('[LazyType] WebSocket error:', err);
      };

    } catch (err) {
      console.error('[LazyType] Connection error:', err);
      setConnectionStatus('disconnected');
      scheduleReconnect();
    }
  }

  function scheduleReconnect() {
    clearTimeout(state.reconnectTimer);
    state.isReconnecting = true;
    setConnectionStatus('reconnecting');

    state.reconnectTimer = setTimeout(() => {
      console.log(`[LazyType] Reconnecting after ${state.reconnectDelay}ms...`);
      connectWebSocket();
      state.reconnectDelay = Math.min(state.reconnectDelay * 1.5, 10000);
    }, state.reconnectDelay);
  }

  function disconnect() {
    clearTimeout(state.reconnectTimer);
    if (state.socket) {
      state.socket.close();
      state.socket = null;
    }
    state.sessionToken = '';
    safeRemoveStorage('lazytype_session_token');
    setConnectionStatus('disconnected');
  }

  function setConnectionStatus(status) {
    if (status === 'connected') {
      state.isConnected = true;
      state.isReconnecting = false;
      if (statusDot) statusDot.className = 'status-dot connected';
      if (connectionStateEl) {
        connectionStateEl.textContent = 'Connected ✓';
        connectionStateEl.style.color = 'var(--success)';
      }
      showScreen('controller');
    } else if (status === 'reconnecting') {
      state.isConnected = false;
      if (statusDot) statusDot.className = 'status-dot reconnecting';
      if (connectionStateEl) {
        connectionStateEl.textContent = 'Reconnecting...';
        connectionStateEl.style.color = 'var(--warning)';
      }
    } else {
      state.isConnected = false;
      if (statusDot) statusDot.className = 'status-dot';
      if (connectionStateEl) {
        connectionStateEl.textContent = 'Disconnected';
        connectionStateEl.style.color = 'var(--text-secondary)';
      }
    }
  }

  function handleIncomingMessage(msg) {
    console.log('[LazyType] Incoming:', msg.type, msg);

    // 1. Pairing response
    if (msg.type === 'PAIR_RESULT') {
      if (msg.success) {
        state.sessionToken = msg.sessionToken;
        safeSetStorage('lazytype_session_token', msg.sessionToken);
        state.macName = msg.macName || state.macName;
        if (macNameEl) macNameEl.textContent = state.macName;
        setConnectionStatus('connected');
        showScreen('controller');
        showToast('Connected to ' + state.macName + ' ✓', true);
        vibrate(50);
        sendWsMessage({ type: 'GET_STATUS' });
      } else {
        showToast(msg.message || 'Pairing failed', false);
        if (connectTitle) connectTitle.textContent = 'Pairing Failed';
        if (connectStatus) connectStatus.textContent = msg.message || 'Invalid or expired token';
        if (manualSettingsForm) manualSettingsForm.classList.remove('hidden');
        showScreen('pairing');
      }
      return;
    }

    // 2. Auth response
    if (msg.type === 'AUTH_RESULT') {
      if (msg.success) {
        state.macName = msg.macName || state.macName;
        if (macNameEl) macNameEl.textContent = state.macName;
        setConnectionStatus('connected');
        showScreen('controller');
        sendWsMessage({ type: 'GET_STATUS' });
      } else {
        state.sessionToken = '';
        safeRemoveStorage('lazytype_session_token');
        showToast('Session expired, re-pairing...', false);
        autoConnectFlow();
      }
      return;
    }

    // 3. Status update
    if (msg.type === 'STATUS_UPDATE') {
      updateHudUI(msg);
      return;
    }

    // 4. Command results
    if (msg.type === 'COMMAND_RESULT') {
      const handler = state.pendingRequests.get(msg.requestId);
      if (handler) {
        state.pendingRequests.delete(msg.requestId);
        handler(msg);
      }
      return;
    }
  }

  function updateHudUI(status) {
    if (!status) return;

    // Mac Name
    if (status.macName && macNameEl) {
      state.macName = status.macName;
      macNameEl.textContent = status.macName;
    }

    // Target selector auto-sync
    if (status.adapter && targetSelect && targetSelect.value === 'auto') {
      // Keep auto selected
    }

    // Meeting badge
    if (badgeMeeting) {
      if (status.meetingDetected) {
        badgeMeeting.textContent = 'Active ✓';
        badgeMeeting.className = 'hud-badge active';
      } else {
        badgeMeeting.textContent = 'None';
        badgeMeeting.className = 'hud-badge';
      }
    }

    // Chat badge
    if (badgeChat) {
      if (status.chatOpen) {
        badgeChat.textContent = 'Open ✓';
        badgeChat.className = 'hud-badge active';
      } else if (status.chatAvailable) {
        badgeChat.textContent = 'Ready ✓';
        badgeChat.className = 'hud-badge active';
      } else {
        badgeChat.textContent = 'Closed';
        badgeChat.className = 'hud-badge';
      }
    }

    // Mute label
    if (status.isMuted !== undefined && quickMuteLabel && btnMute) {
      quickMuteLabel.textContent = status.isMuted ? 'Unmute' : 'Mute';
      btnMute.classList.toggle('active', status.isMuted);
    }
  }

  function sendWsMessage(payload) {
    if (state.socket && state.socket.readyState === WebSocket.OPEN) {
      state.socket.send(JSON.stringify(payload));
      return true;
    }
    return false;
  }

  function sendWsCommand(action, params = {}, callback) {
    const requestId = 'req_' + Date.now() + '_' + Math.random().toString(36).substring(2, 6);
    const payload = {
      type: action,
      requestId,
      ...params
    };

    if (callback) {
      state.pendingRequests.set(requestId, callback);
      setTimeout(() => {
        if (state.pendingRequests.has(requestId)) {
          state.pendingRequests.delete(requestId);
          callback({ success: false, errorCode: 'TIMEOUT', message: 'Command timed out' });
        }
      }, 6000);
    }

    const sent = sendWsMessage(payload);
    if (!sent && callback) {
      callback({ success: false, errorCode: 'DISCONNECTED', message: 'Not connected to Mac' });
    }
  }

  // History Management
  function addToHistory(text) {
    if (!text) return;
    state.messageHistory = [text, ...state.messageHistory.filter(t => t !== text)].slice(0, 10);
    safeSetStorage('lazytype_history', JSON.stringify(state.messageHistory));
    renderHistory();
  }

  function renderHistory() {
    if (!historyList) return;
    if (!state.messageHistory.length) {
      historyList.innerHTML = '<div class="history-empty">No recent messages yet</div>';
      return;
    }

    historyList.innerHTML = '';
    state.messageHistory.forEach(item => {
      const el = document.createElement('div');
      el.className = 'history-item';
      el.textContent = item;
      el.addEventListener('click', () => {
        if (messageInput) {
          messageInput.value = item;
          if (btnClearText) btnClearText.classList.remove('hidden');
          messageInput.focus();
          vibrate(20);
        }
      });
      historyList.appendChild(el);
    });
  }

  // Toast Helper
  let toastTimer = null;
  function showToast(msg, isSuccess = true) {
    if (!toast || !toastMessage) return;
    clearTimeout(toastTimer);
    toastMessage.textContent = msg;
    toast.className = `toast ${isSuccess ? 'success' : 'error'}`;
    toast.classList.remove('hidden');

    toastTimer = setTimeout(() => {
      toast.classList.add('hidden');
    }, 2800);
  }

  function vibrate(ms) {
    if ('vibrate' in navigator) {
      try {
        navigator.vibrate(ms);
      } catch (e) {}
    }
  }

})();
