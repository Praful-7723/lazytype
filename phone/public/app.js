/**
 * LazyType Phone Companion PWA Application
 */

(function () {
  'use strict';

  // State
  const state = {
    socket: null,
    isConnected: false,
    isReconnecting: false,
    reconnectTimer: null,
    reconnectDelay: 1000,
    host: window.location.hostname || '127.0.0.1',
    port: window.location.port || '9123',
    token: '',
    sessionToken: localStorage.getItem('lazytype_session_token') || '',
    deviceId: getOrCreateDeviceId(),
    deviceName: getDeviceName(),
    macName: 'MacBook',
    activeMode: 'send', // 'send' | 'insert' | 'live'
    target: 'auto',
    pendingRequests: new Map(),
    messageHistory: JSON.parse(localStorage.getItem('lazytype_history') || '[]'),
    liveDebounceTimer: null,
    isListening: false,
    speechRecognizer: null
  };

  // DOM Elements
  const screenPairing = document.getElementById('screen-pairing');
  const screenController = document.getElementById('screen-controller');
  const inputHost = document.getElementById('input-host');
  const inputPort = document.getElementById('input-port');
  const inputToken = document.getElementById('input-token');
  const btnManualConnect = document.getElementById('btn-manual-connect');
  const btnScanQr = document.getElementById('btn-scan-qr');
  const btnCloseScanner = document.getElementById('btn-close-scanner');
  const scannerModal = document.getElementById('scanner-modal');
  const qrVideo = document.getElementById('qr-video');

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

  // Initialize
  init();

  function init() {
    registerServiceWorker();
    renderHistory();
    setupEventListeners();
    checkUrlParamsAndAutoConnect();
  }

  function registerServiceWorker() {
    if ('serviceWorker' in navigator) {
      navigator.serviceWorker.register('/sw.js').catch(err => {
        console.warn('[PWA] Service worker registration failed:', err);
      });
    }
  }

  function getOrCreateDeviceId() {
    let id = localStorage.getItem('lazytype_device_id');
    if (!id) {
      id = 'phone_' + Math.random().toString(36).substring(2, 10);
      localStorage.setItem('lazytype_device_id', id);
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

  function setupEventListeners() {
    // Mode tabs
    [tabSend, tabInsert, tabLive].forEach(tab => {
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

    // Target select
    targetSelect.addEventListener('change', (e) => {
      state.target = e.target.value;
      sendWsMessage({ type: 'SET_TARGET', target: state.target });
    });

    // Send button
    btnSendMessage.addEventListener('click', handleSendAction);

    // Textarea enter to send in 'send' mode
    messageInput.addEventListener('keydown', (e) => {
      if (e.key === 'Enter' && !e.shiftKey && state.activeMode === 'send') {
        e.preventDefault();
        handleSendAction();
      }
    });

    // Textarea input watcher
    messageInput.addEventListener('input', () => {
      btnClearText.classList.toggle('hidden', !messageInput.value.trim());

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

    // Clear text button
    btnClearText.addEventListener('click', () => {
      messageInput.value = '';
      btnClearText.classList.add('hidden');
      messageInput.focus();
    });

    // Quick controls
    btnMute.addEventListener('click', () => {
      sendWsCommand('TOGGLE_MUTE', {}, (res) => {
        showToast(res.message || 'Mute toggled', res.success);
      });
    });

    btnCamera.addEventListener('click', () => {
      sendWsCommand('TOGGLE_CAMERA', {}, (res) => {
        showToast(res.message || 'Camera toggled', res.success);
      });
    });

    btnOpenChat.addEventListener('click', () => {
      sendWsCommand('OPEN_CHAT', { target: state.target }, (res) => {
        showToast(res.message || 'Chat panel invoked', res.success);
      });
    });

    btnPaste.addEventListener('click', async () => {
      try {
        const clipText = await navigator.clipboard.readText();
        if (clipText) {
          messageInput.value = clipText;
          btnClearText.classList.remove('hidden');
          showToast('Clipboard pasted into message', true);
        } else {
          showToast('Clipboard is empty', false);
        }
      } catch (err) {
        showToast('Clipboard permission needed', false);
      }
    });

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
    btnClearHistory.addEventListener('click', () => {
      state.messageHistory = [];
      localStorage.removeItem('lazytype_history');
      renderHistory();
    });

    // Manual pairing form
    btnManualConnect.addEventListener('click', () => {
      const host = inputHost.value.trim() || state.host;
      const port = inputPort.value.trim() || state.port;
      const token = inputToken.value.trim();

      state.host = host;
      state.port = port;
      state.token = token;

      connectWebSocket();
    });

    // Quick replies chips
    document.querySelectorAll('.quick-reply-chip').forEach(chip => {
      chip.addEventListener('click', () => {
        const text = chip.dataset.text;
        if (text) {
          messageInput.value = text;
          btnClearText.classList.remove('hidden');
          messageInput.focus();
          vibrate(25);
        }
      });
    });

    // Voice dictation button
    if (btnVoiceDictate) {
      btnVoiceDictate.addEventListener('click', toggleVoiceDictation);
    }

    // Disconnect button
    btnDisconnect.addEventListener('click', () => {
      disconnect();
      showScreen('pairing');
    });

    // QR Scanner
    btnScanQr.addEventListener('click', startQrScanner);
    btnCloseScanner.addEventListener('click', stopQrScanner);
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
          btnClearText.classList.remove('hidden');

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
        console.warn('[LazyType] Voice recognition error:', event.error);
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
      console.warn('[LazyType] Failed to start voice recognition:', err);
      state.isListening = false;
      if (btnVoiceDictate) btnVoiceDictate.classList.remove('listening');
      showToast('Could not start microphone', false);
    }
  }

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
          btnClearText.classList.add('hidden');
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

  // Check URL params for 1-click QR connection
  function checkUrlParamsAndAutoConnect() {
    const params = new URLSearchParams(window.location.search);
    const urlToken = params.get('token');
    const urlHost = params.get('host');
    const urlPort = params.get('port');

    if (urlHost) state.host = urlHost;
    if (urlPort) state.port = urlPort;
    if (urlToken) state.token = urlToken;

    // Fill form fields
    inputHost.value = state.host;
    inputPort.value = state.port;
    if (urlToken) inputToken.value = urlToken;

    // If we have a token or an existing sessionToken, attempt connection!
    if (urlToken || state.sessionToken) {
      connectWebSocket();
    } else {
      showScreen('pairing');
    }
  }

  function showScreen(name) {
    if (name === 'pairing') {
      screenPairing.classList.add('active');
      screenController.classList.remove('active');
    } else {
      screenPairing.classList.remove('active');
      screenController.classList.add('active');
    }
  }

  // WebSocket Connection
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
          // No credentials
          showScreen('pairing');
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

        // Schedule auto-reconnect if we were previously authorized
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
    localStorage.removeItem('lazytype_session_token');
    setConnectionStatus('disconnected');
  }

  function setConnectionStatus(status) {
    if (status === 'connected') {
      state.isConnected = true;
      state.isReconnecting = false;
      statusDot.className = 'status-dot connected';
      connectionStateEl.textContent = 'Connected ✓';
      connectionStateEl.style.color = 'var(--success)';
      showScreen('controller');
    } else if (status === 'reconnecting') {
      state.isConnected = false;
      statusDot.className = 'status-dot reconnecting';
      connectionStateEl.textContent = 'Reconnecting...';
      connectionStateEl.style.color = 'var(--warning)';
    } else {
      state.isConnected = false;
      statusDot.className = 'status-dot';
      connectionStateEl.textContent = 'Disconnected';
      connectionStateEl.style.color = 'var(--text-secondary)';
    }
  }

  function handleIncomingMessage(msg) {
    console.log('[LazyType] Incoming:', msg.type, msg);

    // 1. Pairing response
    if (msg.type === 'PAIR_RESULT') {
      if (msg.success) {
        state.sessionToken = msg.sessionToken;
        localStorage.setItem('lazytype_session_token', msg.sessionToken);
        state.macName = msg.macName || state.macName;
        macNameEl.textContent = state.macName;
        setConnectionStatus('connected');
        showToast('Paired with ' + state.macName + ' ✓', true);
        // Request initial status
        sendWsMessage({ type: 'GET_STATUS' });
      } else {
        showToast(msg.message || 'Pairing failed', false);
        showScreen('pairing');
      }
      return;
    }

    // 2. Auth response
    if (msg.type === 'AUTH_RESULT') {
      if (msg.success) {
        state.macName = msg.macName || state.macName;
        macNameEl.textContent = state.macName;
        setConnectionStatus('connected');
        sendWsMessage({ type: 'GET_STATUS' });
      } else {
        // Stale session
        state.sessionToken = '';
        localStorage.removeItem('lazytype_session_token');
        showToast('Session expired. Please pair again.', false);
        showScreen('pairing');
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
    }
  }

  function updateHudUI(status) {
    if (status.macName) {
      macNameEl.textContent = status.macName;
    }

    if (status.activeApplication) {
      // Sync target select if set to auto
      if (state.target === 'auto' && status.adapter) {
        const opt = targetSelect.querySelector(`option[value="${status.adapter}"]`);
        if (opt) {
          targetSelect.value = status.adapter;
        }
      }
    }

    // Meeting badge
    if (status.meetingDetected) {
      badgeMeeting.textContent = 'Active ✓';
      badgeMeeting.className = 'hud-badge active';
    } else {
      badgeMeeting.textContent = 'None';
      badgeMeeting.className = 'hud-badge';
    }

    // Chat badge
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

    // Mute label
    if (status.isMuted !== undefined) {
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
      // Timeout after 6s
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
    localStorage.setItem('lazytype_history', JSON.stringify(state.messageHistory));
    renderHistory();
  }

  function renderHistory() {
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
        messageInput.value = item;
        btnClearText.classList.remove('hidden');
        messageInput.focus();
        vibrate(20);
      });
      historyList.appendChild(el);
    });
  }

  // Toast Helper
  let toastTimer = null;
  function showToast(msg, isSuccess = true) {
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
      try { navigator.vibrate(ms); } catch (e) {}
    }
  }

  // Camera QR Code Scanner (HTML5 BarcodeDetector)
  let videoStream = null;
  let scanInterval = null;

  async function startQrScanner() {
    scannerModal.classList.remove('hidden');

    try {
      videoStream = await navigator.mediaDevices.getUserMedia({
        video: { facingMode: 'environment' }
      });
      qrVideo.srcObject = videoStream;
      await qrVideo.play();

      if ('BarcodeDetector' in window) {
        const barcodeDetector = new BarcodeDetector({ formats: ['qr_code'] });
        scanInterval = setInterval(async () => {
          try {
            const barcodes = await barcodeDetector.detect(qrVideo);
            if (barcodes.length > 0) {
              handleScannedValue(barcodes[0].rawValue);
            }
          } catch (e) {}
        }, 200);
      } else {
        // Fallback for browsers without native BarcodeDetector
        console.log('[QR] Native BarcodeDetector not available');
      }
    } catch (err) {
      console.warn('[QR] Camera access error:', err);
      showToast('Camera access denied or unavailable', false);
      stopQrScanner();
    }
  }

  function stopQrScanner() {
    clearInterval(scanInterval);
    if (videoStream) {
      videoStream.getTracks().forEach(t => t.stop());
      videoStream = null;
    }
    scannerModal.classList.add('hidden');
  }

  function handleScannedValue(raw) {
    stopQrScanner();
    vibrate(60);

    try {
      // Check if it's a URL like http://192.168.1.50:8765/?token=pair_xyz
      if (raw.startsWith('http://') || raw.startsWith('https://')) {
        const url = new URL(raw);
        state.host = url.hostname;
        state.port = url.port || '9123';
        state.token = url.searchParams.get('token') || '';

        inputHost.value = state.host;
        inputPort.value = state.port;
        inputToken.value = state.token;

        showToast('QR Code Scanned ✓', true);
        connectWebSocket();
        return;
      }

      // Check if it's a direct token string
      state.token = raw.trim();
      inputToken.value = state.token;
      connectWebSocket();
    } catch (e) {
      showToast('Could not parse scanned QR', false);
    }
  }

})();
