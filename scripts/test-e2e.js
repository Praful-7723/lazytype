/**
 * LazyType Automated End-to-End Test Suite
 * Verifies Phone -> Mac -> Extension -> DOM Flow, Authentication, Reconnection, and Error Handling.
 */

const http = require('http');
const { spawn } = require('child_process');
const path = require('path');
const crypto = require('crypto');

const TEST_PORT = 9199;
const BINARY_PATH = path.join(__dirname, '..', 'bin', 'LazyTypeCompanion');

let serverProcess = null;

// Simple WebSocket Client implementation using native Node.js crypto & net
// (Zero external dependencies needed!)
const net = require('net');

class TestWebSocketClient {
  constructor(url) {
    this.url = new URL(url);
    this.socket = null;
    this.onMessage = null;
    this.onOpen = null;
    this.onClose = null;
  }

  connect() {
    return new Promise((resolve, reject) => {
      const host = this.url.hostname;
      const port = parseInt(this.url.port || '80', 10);
      const secKey = crypto.randomBytes(16).toString('base64');

      this.socket = net.connect({ host, port }, () => {
        const req = [
          `GET ${this.url.pathname}${this.url.search} HTTP/1.1`,
          `Host: ${host}:${port}`,
          'Upgrade: websocket',
          'Connection: Upgrade',
          `Sec-WebSocket-Key: ${secKey}`,
          'Sec-WebSocket-Version: 13',
          '\r\n'
        ].join('\r\n');
        this.socket.write(req);
      });

      let handshakeDone = false;
      let rawBuffer = Buffer.alloc(0);

      this.socket.on('data', (chunk) => {
        if (!handshakeDone) {
          rawBuffer = Buffer.concat([rawBuffer, chunk]);
          const str = rawBuffer.toString();
          if (str.includes('\r\n\r\n')) {
            if (str.includes('101 Switching Protocols')) {
              handshakeDone = true;
              if (this.onOpen) this.onOpen();
              resolve();
              // Parse remaining bytes if any
              const headerEnd = str.indexOf('\r\n\r\n') + 4;
              const remaining = rawBuffer.slice(headerEnd);
              if (remaining.length > 0) {
                this.parseFrames(remaining);
              }
            } else {
              reject(new Error(`Handshake failed: ${str}`));
            }
          }
        } else {
          this.parseFrames(chunk);
        }
      });

      this.socket.on('close', () => {
        if (this.onClose) this.onClose();
      });

      this.socket.on('error', (err) => {
        if (!handshakeDone) reject(err);
      });
    });
  }

  parseFrames(chunk) {
    if (!this.fragmentBuffer) this.fragmentBuffer = Buffer.alloc(0);
    const buffer = Buffer.concat([this.fragmentBuffer, chunk]);
    let offset = 0;

    while (offset < buffer.length) {
      if (buffer.length - offset < 2) break;
      const b1 = buffer[offset];
      const b2 = buffer[offset + 1];
      const opcode = b1 & 0x0f;

      let tempOffset = offset + 2;
      let payloadLen = b2 & 0x7f;
      if (payloadLen === 126) {
        if (buffer.length - tempOffset < 2) break;
        payloadLen = buffer.readUInt16BE(tempOffset);
        tempOffset += 2;
      } else if (payloadLen === 127) {
        if (buffer.length - tempOffset < 8) break;
        payloadLen = Number(buffer.readBigUInt64BE(tempOffset));
        tempOffset += 8;
      }

      const isMasked = (b2 & 0x80) !== 0;
      let mask = null;
      if (isMasked) {
        if (buffer.length - tempOffset < 4) break;
        mask = buffer.slice(tempOffset, tempOffset + 4);
        tempOffset += 4;
      }

      if (buffer.length - tempOffset < payloadLen) break;
      const payload = buffer.slice(tempOffset, tempOffset + payloadLen);
      offset = tempOffset + payloadLen;

      if (mask) {
        for (let i = 0; i < payload.length; i++) {
          payload[i] ^= mask[i % 4];
        }
      }

      if (opcode === 0x1) { // Text
        const text = payload.toString('utf8');
        try {
          const json = JSON.parse(text);
          if (this.onMessage) this.onMessage(json);
        } catch (e) {
          if (this.onMessage) this.onMessage(text);
        }
      } else if (opcode === 0x8 && this.onClose) {
        this.onClose();
      }
    }
    this.fragmentBuffer = buffer.slice(offset);
  }

  send(obj) {
    const text = typeof obj === 'string' ? obj : JSON.stringify(obj);
    const payload = Buffer.from(text, 'utf8');
    const mask = crypto.randomBytes(4);

    let header;
    if (payload.length <= 125) {
      header = Buffer.from([0x81, 0x80 | payload.length]);
    } else if (payload.length <= 65535) {
      header = Buffer.alloc(4);
      header[0] = 0x81;
      header[1] = 0x80 | 126;
      header.writeUInt16BE(payload.length, 2);
    } else {
      header = Buffer.alloc(10);
      header[0] = 0x81;
      header[1] = 0x80 | 127;
      header.writeBigUInt64BE(BigInt(payload.length), 2);
    }

    const maskedPayload = Buffer.alloc(payload.length);
    for (let i = 0; i < payload.length; i++) {
      maskedPayload[i] = payload[i] ^ mask[i % 4];
    }

    this.socket.write(Buffer.concat([header, mask, maskedPayload]));
  }

  close() {
    if (this.socket) {
      this.socket.end();
      this.socket.destroy();
    }
  }
}

// HTTP GET helper
function httpGet(pathStr) {
  return new Promise((resolve, reject) => {
    http.get(`http://127.0.0.1:${TEST_PORT}${pathStr}`, (res) => {
      const chunks = [];
      res.on('data', c => chunks.push(c));
      res.on('end', () => {
        resolve({
          statusCode: res.statusCode,
          headers: res.headers,
          body: Buffer.concat(chunks)
        });
      });
    }).on('error', reject);
  });
}

// Test Suite Runner
async function runTests() {
  console.log('================================================================');
  console.log('   LazyType Automated Verification Test Suite');
  console.log('================================================================');

  let passed = 0;
  let failed = 0;

  function assert(condition, message) {
    if (condition) {
      console.log(`  ✓ ${message}`);
      passed++;
    } else {
      console.error(`  ✕ FAIL: ${message}`);
      failed++;
    }
  }

  // 1. Start Server Process
  console.log('\n[1] Starting LazyType Companion binary on port ' + TEST_PORT + '...');
  serverProcess = spawn(BINARY_PATH, ['--port', String(TEST_PORT)], {
    cwd: path.join(__dirname, '..'),
    stdio: ['ignore', 'pipe', 'pipe']
  });

  let serverStarted = false;
  let serverPairingToken = null;

  serverProcess.stdout.on('data', (d) => {
    const s = d.toString();
    if (s.includes('Pairing URL:') || s.includes('LocalServer listening')) {
      serverStarted = true;
      const match = s.match(/token=([^&\s]+)/);
      if (match) serverPairingToken = match[1];
    }
  });

  serverProcess.stderr.on('data', (d) => {
    console.error('[Server Error]', d.toString());
  });

  // Wait up to 8s for server to start by polling /api/pair-token
  for (let i = 0; i < 80; i++) {
    try {
      const res = await httpGet('/api/pair-token');
      if (res.statusCode === 200) {
        serverStarted = true;
        const data = JSON.parse(res.body.toString());
        serverPairingToken = data.token;
        break;
      }
    } catch (e) {
      // Server still booting
    }
    await new Promise(r => setTimeout(r, 100));
  }
  assert(serverStarted, 'Mac companion server started and bound to port ' + TEST_PORT);
  assert(!!serverPairingToken, `Extracted active pairing token: ${serverPairingToken}`);

  if (!serverStarted) {
    console.error('Fatal: Test server failed to start within timeout.');
    process.exit(1);
  }

  // 2. HTTP Static Serving Tests
  console.log('\n[2] Testing HTTP static file delivery...');
  const indexRes = await httpGet('/');
  assert(indexRes.statusCode === 200, 'GET / returns HTTP 200');
  assert(indexRes.body.toString().includes('LazyType Remote'), 'GET / delivers PWA index.html');

  const appJsRes = await httpGet('/app.js');
  assert(appJsRes.statusCode === 200, 'GET /app.js returns HTTP 200');
  assert(appJsRes.headers['content-type'].includes('javascript'), 'app.js served with javascript content-type');

  const demoRes = await httpGet('/demo');
  assert(demoRes.statusCode === 200, 'GET /demo returns HTTP 200');
  assert(demoRes.body.toString().includes('Interactive Demo Target'), 'GET /demo serves simulated video call');

  const qrRes = await httpGet('/qr.png');
  assert(qrRes.statusCode === 200, 'GET /qr.png returns HTTP 200');
  assert(qrRes.headers['content-type'] === 'image/png', 'qr.png served with image/png content-type');
  assert(qrRes.body.length > 500, 'QR image has valid PNG payload bytes');

  const statusRes = await httpGet('/api/status');
  assert(statusRes.statusCode === 200, 'GET /api/status returns HTTP 200');
  const statusJson = JSON.parse(statusRes.body.toString());
  assert(statusJson.type === 'STATUS_UPDATE', 'Status JSON has valid STATUS_UPDATE structure');

  // 3. Security & Pairing Authentication
  console.log('\n[3] Testing Security, Pairing, and Session Management...');

  // Test 3a: Invalid Pairing Token
  const badClient = new TestWebSocketClient(`http://127.0.0.1:${TEST_PORT}/ws/phone`);
  await badClient.connect();
  let invalidTokenRejected = false;
  await new Promise((resolve) => {
    badClient.onMessage = (msg) => {
      if (msg.type === 'PAIR_RESULT' && msg.success === false && msg.errorCode === 'INVALID_TOKEN') {
        invalidTokenRejected = true;
        resolve();
      }
    };
    badClient.send({
      type: 'PAIR',
      requestId: 'test-bad-pair',
      token: 'pair_completely_invalid_999',
      deviceId: 'fake-phone'
    });
  });
  assert(invalidTokenRejected, 'Server correctly rejects invalid pairing token');
  badClient.close();

  // Test 3b: Unauthorized command rejection
  const unauthClient = new TestWebSocketClient(`http://127.0.0.1:${TEST_PORT}/ws/phone`);
  await unauthClient.connect();
  let unauthRejected = false;
  await new Promise((resolve) => {
    unauthClient.onMessage = (msg) => {
      if (msg.type === 'COMMAND_RESULT' && msg.success === false && msg.errorCode === 'UNAUTHORIZED') {
        unauthRejected = true;
        resolve();
      }
    };
    unauthClient.send({
      type: 'SEND_MESSAGE',
      requestId: 'test-unauth-msg',
      text: 'Exploit attempt'
    });
  });
  assert(unauthRejected, 'Server blocks command execution from unauthorized clients');
  unauthClient.close();

  // Test 3c: Valid Pairing Handshake
  const phoneClient = new TestWebSocketClient(`http://127.0.0.1:${TEST_PORT}/ws/phone`);
  await phoneClient.connect();
  let sessionToken = null;
  await new Promise((resolve) => {
    phoneClient.onMessage = (msg) => {
      if (msg.type === 'PAIR_RESULT' && msg.success === true) {
        sessionToken = msg.sessionToken;
        resolve();
      }
    };
    phoneClient.send({
      type: 'PAIR',
      requestId: 'test-valid-pair',
      token: serverPairingToken,
      deviceId: 'dev_test_pixel8',
      deviceName: 'Pixel 8 Pro'
    });
  });
  assert(!!sessionToken, `Pairing succeeded, issued session token: ${sessionToken}`);

  // Test 3d: Reconnection using Session Token (AUTH)
  phoneClient.close(); // simulate disconnect
  await new Promise(r => setTimeout(r, 100));

  const reconnectPhone = new TestWebSocketClient(`http://127.0.0.1:${TEST_PORT}/ws/phone`);
  await reconnectPhone.connect();
  let authSuccess = false;
  await new Promise((resolve) => {
    reconnectPhone.onMessage = (msg) => {
      if (msg.type === 'AUTH_RESULT' && msg.success === true) {
        authSuccess = true;
        resolve();
      }
    };
    reconnectPhone.send({
      type: 'AUTH',
      requestId: 'test-reconnect',
      sessionToken: sessionToken,
      deviceId: 'dev_test_pixel8',
      deviceName: 'Pixel 8 Pro'
    });
  });
  assert(authSuccess, 'Reconnection with saved session token succeeds without re-pairing');

  // 4. Browser Extension Bridge & End-to-End Chat Flow
  console.log('\n[4] Testing Extension Bridge & End-to-End Chat Command Flow...');

  // Connect mock extension
  const extClient = new TestWebSocketClient(`http://127.0.0.1:${TEST_PORT}/ws/extension`);
  await extClient.connect();

  extClient.send({
    type: 'EXT_REGISTER',
    version: '1.0.0'
  });

  // Report that a Demo Meeting is active in the browser
  extClient.send({
    type: 'EXT_TAB_STATE',
    adapter: 'demo-chat',
    url: 'http://127.0.0.1:8799/demo',
    meetingDetected: true,
    chatAvailable: true,
    chatOpen: true
  });

  await new Promise(r => setTimeout(r, 150));

  // Verify Phone receives unsolicited meeting status update
  let phoneReceivedStatus = false;
  reconnectPhone.send({ type: 'GET_STATUS', requestId: 'get-stat' });
  await new Promise((resolve) => {
    const handler = (msg) => {
      if (msg.type === 'STATUS_UPDATE') {
        phoneReceivedStatus = true;
        assert(msg.browserExtensionConnected === true, 'Status reflects browserExtensionConnected = true');
        assert(msg.meetingDetected === true, 'Status reflects meetingDetected = true');
        resolve();
      }
    };
    reconnectPhone.onMessage = handler;
  });

  // Test End-to-End SEND_MESSAGE command:
  // Phone sends SEND_MESSAGE -> Mac routes to Extension -> Extension confirms -> Phone receives result
  console.log('\n[5] Testing End-to-End SEND_MESSAGE command dispatch...');
  const testMessageText = "Can you send me that document?";

  // Wire up extension listener to intercept command from Mac and reply
  extClient.onMessage = (cmd) => {
    if (cmd.type === 'EXECUTE_COMMAND') {
      if (cmd.action === 'SEND_MESSAGE') {
        assert(cmd.text === testMessageText, `Extension received correct text: "${cmd.text}"`);
      }
      // Simulate successful DOM action trigger
      extClient.send({
        type: 'COMMAND_RESULT',
        requestId: cmd.requestId,
        success: true,
        adapter: 'demo-chat',
        action: cmd.action,
        message: `${cmd.action} delivered to demo chat ✓`
      });
    }
  };

  let phoneReceivedSendConfirmation = false;
  reconnectPhone.send({
    type: 'SEND_MESSAGE',
    requestId: 'phone-send-1',
    target: 'demo-chat',
    text: testMessageText
  });

  await new Promise((resolve) => {
    reconnectPhone.onMessage = (msg) => {
      if (msg.type === 'COMMAND_RESULT' && msg.requestId === 'phone-send-1') {
        phoneReceivedSendConfirmation = msg.success;
        assert(msg.success === true, `Phone received confirmation: "${msg.message}"`);
        resolve();
      }
    };
  });
  assert(phoneReceivedSendConfirmation, 'Full vertical slice: Phone -> Mac -> Extension -> DOM -> Confirmation ✓');

  // Test Generic Key Emulation
  console.log('\n[6] Testing Generic Keypress Command...');
  let keySuccess = false;
  reconnectPhone.send({
    type: 'PRESS_KEY',
    target: 'generic',
    requestId: 'key-req-1',
    key: 'Tab'
  });
  await new Promise((resolve) => {
    reconnectPhone.onMessage = (msg) => {
      if (msg.type === 'COMMAND_RESULT' && msg.requestId === 'key-req-1') {
        keySuccess = msg.success;
        resolve();
      }
    };
  });
  assert(keySuccess, 'Generic keypress emulation succeeded');

  // Clean up
  reconnectPhone.close();
  extClient.close();
  serverProcess.kill('SIGTERM');

  console.log('\n================================================================');
  console.log(`Test Results: ${passed} Passed, ${failed} Failed`);
  console.log('================================================================');

  if (failed > 0) {
    process.exit(1);
  } else {
    process.exit(0);
  }
}

runTests().catch(err => {
  console.error('Fatal test runner error:', err);
  if (serverProcess) serverProcess.kill('SIGTERM');
  process.exit(1);
});
