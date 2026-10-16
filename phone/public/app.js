/**
 * LazyType Phone Companion PWA Application
 * Liquid Glass Light Theme • High-Precision One-Handed Controller
 */

(function () {
  'use strict';

  // Safe LocalStorage Helpers
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
    macName: 'MacBook Air',
    target: 'auto',
    pendingRequests: new Map(),
    messageHistory: (() => {
      try {
        return JSON.parse(safeGetStorage('lazytype_history', '[]'));
      } catch (e) {
        return [];
      }
    })(),
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

  const messageInput = document.getElementById('message-input');
  const btnVoiceDictate = document.getElementById('btn-voice-dictate');
  const btnClearText = document.getElementById('btn-clear-text');
  const btnSendMessage = document.getElementById('btn-send-message');

  const btnToggleAux = document.getElementById('btn-toggle-aux');
  const auxControlsDrawer = document.getElementById('aux-controls-drawer');
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
    renderCanvasLogo();
    renderHistory();
    setupEventListeners();
    autoConnectFlow();
  }

  function registerServiceWorker() {
    if ('serviceWorker' in navigator && window.location.protocol.startsWith('http')) {
      navigator.serviceWorker.register('/sw.js').catch(err => {
        console.warn('[PWA] Service worker registration ignored:', err);
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

  // High-DPI Liquid Glass Canvas Brand Logo
  function renderCanvasLogo() {
    const canvas = document.getElementById('canvas-logo');
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    const dpr = window.devicePixelRatio || 1;

    canvas.width = 160 * dpr;
    canvas.height = 160 * dpr;
    ctx.scale(dpr, dpr);

    function draw(time = 0) {
      ctx.clearRect(0, 0, 160, 160);

      const cx = 80;
      const cy = 80;

      // Outer Specular Drop Shadow
      ctx.save();
      ctx.shadowColor = 'rgba(37, 99, 235, 0.28)';
      ctx.shadowBlur = 24;
      ctx.shadowOffsetY = 12;

      // Rounded Glass Keycap Base
      const w = 98;
      const h = 78;
      const r = 26;

      ctx.beginPath();
      ctx.roundRect(cx - w / 2, cy - h / 2, w, h, r);

      const grad = ctx.createLinearGradient(cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2);
      grad.addColorStop(0, 'rgba(255, 255, 255, 0.96)');
      grad.addColorStop(0.5, 'rgba(240, 249, 255, 0.88)');
      grad.addColorStop(1, 'rgba(224, 242, 254, 0.78)');
      ctx.fillStyle = grad;
      ctx.fill();

      // Top Edge Specular Highlight Stroke
      ctx.lineWidth = 2.5;
      const strokeGrad = ctx.createLinearGradient(cx, cy - h / 2, cx, cy + h / 2);
      strokeGrad.addColorStop(0, 'rgba(255, 255, 255, 1)');
      strokeGrad.addColorStop(0.5, 'rgba(186, 230, 254, 0.7)');
      strokeGrad.addColorStop(1, 'rgba(147, 197, 253, 0.3)');
      ctx.strokeStyle = strokeGrad;
      ctx.stroke();
      ctx.restore();

      // Inner Tactile Recess
      ctx.save();
      ctx.beginPath();
      ctx.roundRect(cx - 36, cy - 24, 72, 48, 16);
      ctx.fillStyle = 'rgba(238, 242, 255, 0.9)';
      ctx.fill();
      ctx.lineWidth = 1.2;
      ctx.strokeStyle = 'rgba(255, 255, 255, 0.95)';
      ctx.stroke();
      ctx.restore();

      // Typing Magic Indicator Dots
      const dots = [-20, 0, 20];
      dots.forEach((xOffset, i) => {
        const dotPhase = (time / 320 + i * 0.9) % (Math.PI * 2);
        const scale = 0.75 + Math.sin(dotPhase) * 0.3;

        ctx.save();
        ctx.beginPath();
        ctx.arc(cx + xOffset, cy, 4.5 * scale, 0, Math.PI * 2);
        ctx.fillStyle = i === 1 ? '#0284c7' : '#2563eb';
        ctx.shadowColor = 'rgba(37, 99, 235, 0.55)';
        ctx.shadowBlur = 8;
        ctx.fill();
        ctx.restore();
      });

      requestAnimationFrame(draw);
    }

    requestAnimationFrame(draw);
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

  // Event Listeners
  function setupEventListeners() {
    // Send Message Button
    if (btnSendMessage) {
      btnSendMessage.addEventListener('click', handleSendAction);
    }

    // Textarea enter key to send
    if (messageInput) {
      messageInput.addEventListener('keydown', (e) => {
        if (e.key === 'Enter' && !e.shiftKey) {
          e.preventDefault();
          handleSendAction();
        }
      });

      // Clear button toggle
      messageInput.addEventListener('input', () => {
        if (btnClearText) {
          btnClearText.classList.toggle('hidden', !messageInput.value.trim());
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
    document.querySelectorAll('.liquid-chip').forEach(chip => {
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

    // Toggle Auxiliary Meeting Drawer
    if (btnToggleAux && auxControlsDrawer) {
      btnToggleAux.addEventListener('click', () => {
        auxControlsDrawer.classList.toggle('hidden');
        const chevron = btnToggleAux.querySelector('.chevron-icon');
        if (chevron) {
          chevron.style.transform = auxControlsDrawer.classList.contains('hidden') ? 'rotate(0deg)' : 'rotate(180deg)';
        }
      });
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
          showToast(res.message || 'Chat panel opened', res.success);
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
            showToast('Pasted from clipboard', true);
          } else {
            showToast('Clipboard is empty', false);
          }
        } catch (err) {
          showToast('Clipboard access required', false);
        }
      });
    }

    // Emulated key buttons
    document.querySelectorAll('.key-pill-glass').forEach(btn => {
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

  // Primary Action: SEND MESSAGE
  function handleSendAction() {
    const text = messageInput.value.trim();
    if (!text) {
      messageInput.focus();
      return;
    }

    vibrate(40);

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

    // 1. Existing Session Token
    if (state.sessionToken) {
      if (connectTitle) connectTitle.textContent = 'Resuming Session...';
      if (connectStatus) connectStatus.textContent = 'Reconnecting with saved authentication';
      connectWebSocket();
      return;
    }

    // 2. Token from QR Code or Link
    if (state.token) {
      if (connectTitle) connectTitle.textContent = 'Pairing with Mac...';
      if (connectStatus) connectStatus.textContent = 'Validating pairing credentials';
      connectWebSocket();
      return;
    }

    // 3. Auto-Discovery from Mac Server
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

    // 4. Fallback manual view if unreachable
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
        connectionStateEl.textContent = '• Ready ✓';
        connectionStateEl.style.color = 'var(--success)';
      }
      showScreen('controller');
    } else if (status === 'reconnecting') {
      state.isConnected = false;
      if (statusDot) statusDot.className = 'status-dot reconnecting';
      if (connectionStateEl) {
        connectionStateEl.textContent = '• Reconnecting...';
        connectionStateEl.style.color = 'var(--warning)';
      }
    } else {
      state.isConnected = false;
      if (statusDot) statusDot.className = 'status-dot';
      if (connectionStateEl) {
        connectionStateEl.textContent = '• Disconnected';
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

    if (status.macName && macNameEl) {
      state.macName = status.macName;
      macNameEl.textContent = status.macName;
    }

    if (status.meetingDetected && connectionStateEl) {
      connectionStateEl.textContent = `• ${status.activeApplication || 'Call'} Active ✓`;
    }

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
    state.messageHistory = [text, ...state.messageHistory.filter(t => t !== text)].slice(0, 8);
    safeSetStorage('lazytype_history', JSON.stringify(state.messageHistory));
    renderHistory();
  }

  function renderHistory() {
    if (!historyList) return;
    if (!state.messageHistory.length) {
      historyList.innerHTML = '<div class="history-empty">No recent messages</div>';
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

  // Specular Toast Helper
  let toastTimer = null;
  function showToast(msg, isSuccess = true) {
    if (!toast || !toastMessage) return;
    clearTimeout(toastTimer);
    toastMessage.textContent = msg;
    toast.className = `toast-glass ${isSuccess ? 'success' : 'error'}`;
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
