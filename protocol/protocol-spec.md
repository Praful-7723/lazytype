# Remote Companion / LazyType Protocol Specification

Version: 1.0.0
Transport: Local WebSocket (ws://<mac-ip>:<port>/ws/phone and ws://127.0.0.1:<port>/ws/extension)
Payload Encoding: JSON UTF-8

## Overview

Remote Companion coordinates three parties:
1. **Phone Companion (PWA)**: Mobile remote control. Connects via WebSocket over local Wi-Fi to `/ws/phone`.
2. **Mac Companion App**: Local host, accessibility controller, adapter manager. Serves PWA & handles WebSocket.
3. **Browser Extension (MV3)**: Connects via WebSocket to `/ws/extension` on loopback. Executes DOM commands on browser tabs (Zoom Web, Meet, Demo Chat).

---

## 1. Authentication & Pairing Flow

### 1.1 Pairing Initiation
When pairing is initiated on the Mac:
- Mac companion generates a short-lived random pairing token (e.g. `pair_<16_hex_chars>`) valid for 5 minutes.
- Mac companion displays a QR code encoding a URL:
  `http://<mac-ip>:<port>/?token=pair_<token>`
- The phone can either scan this QR code or navigate directly to the URL.

### 1.2 Handshake (WebSocket)
Phone opens WebSocket connection:
`ws://<mac-ip>:<port>/ws/phone`

Immediately sends a `PAIR` or `AUTH` message:

```json
{
  "type": "PAIR",
  "requestId": "req-pair-1",
  "token": "pair_3f81e092...",
  "deviceId": "dev_d92f7c...",
  "deviceName": "Pixel 8 Pro"
}
```

Mac verifies:
- If `token` matches the active pairing token:
  - Generates persistent `sessionToken`.
  - Saves device to approved device registry (`DeviceStore`).
  - Responds:
    ```json
    {
      "type": "PAIR_RESULT",
      "requestId": "req-pair-1",
      "success": true,
      "sessionToken": "sess_91b72a...",
      "macName": "Praful's MacBook Air",
      "message": "Device paired and authorized"
    }
    ```
- If pairing token is invalid or expired:
  - Responds:
    ```json
    {
      "type": "PAIR_RESULT",
      "requestId": "req-pair-1",
      "success": false,
      "errorCode": "INVALID_TOKEN",
      "message": "Pairing token is invalid or has expired"
    }
    ```
  - Closes connection.

### 1.3 Reconnection
For previously paired devices:
```json
{
  "type": "AUTH",
  "requestId": "req-auth-1",
  "sessionToken": "sess_91b72a...",
  "deviceId": "dev_d92f7c...",
  "deviceName": "Pixel 8 Pro"
}
```
If approved:
```json
{
  "type": "AUTH_RESULT",
  "requestId": "req-auth-1",
  "success": true,
  "macName": "Praful's MacBook Air",
  "message": "Authorized"
}
```

---

## 2. Status & State Updates

### 2.1 Polling or Requesting Status
Phone sends:
```json
{
  "type": "GET_STATUS",
  "requestId": "req-status-1"
}
```

Mac responds:
```json
{
  "type": "STATUS_UPDATE",
  "requestId": "req-status-1",
  "macName": "Praful's MacBook Air",
  "activeApplication": "Zoom",
  "adapter": "zoom-native",
  "meetingDetected": true,
  "chatAvailable": true,
  "chatOpen": true,
  "canSendMessage": true,
  "canMute": true,
  "canControlCamera": true,
  "browserExtensionConnected": true
}
```

### 2.2 Unsolicited Status Broadcasts
Whenever the active app changes or browser meeting status updates, Mac broadcasts `STATUS_UPDATE` to all authorized connected phones with `requestId: null`.

---

## 3. Remote Commands

### 3.1 Send Message (Primary Command)
```json
{
  "type": "SEND_MESSAGE",
  "requestId": "msg-1234",
  "target": "auto",
  "text": "Can you send me that document?"
}
```
- `target`: `"auto"` (default), `"zoom-native"`, `"zoom-web"`, `"google-meet"`, `"demo-chat"`, or `"generic"`.

Response on success:
```json
{
  "type": "COMMAND_RESULT",
  "requestId": "msg-1234",
  "action": "SEND_MESSAGE",
  "success": true,
  "target": "zoom-native",
  "message": "Message sent ✓"
}
```

Response on failure:
```json
{
  "type": "COMMAND_RESULT",
  "requestId": "msg-1234",
  "action": "SEND_MESSAGE",
  "success": false,
  "target": "zoom-native",
  "errorCode": "INPUT_NOT_FOUND",
  "message": "Zoom chat input field could not be located"
}
```

### 3.2 Insert Text Only (No Send)
```json
{
  "type": "INSERT_TEXT",
  "requestId": "insert-5678",
  "target": "auto",
  "text": "Drafting notes for later..."
}
```

### 3.3 Open Chat
```json
{
  "type": "OPEN_CHAT",
  "requestId": "chat-9012",
  "target": "auto"
}
```

### 3.4 Meeting Audio / Video Controls
```json
{
  "type": "TOGGLE_MUTE",
  "requestId": "mute-3456"
}
```
```json
{
  "type": "TOGGLE_CAMERA",
  "requestId": "cam-7890"
}
```

### 3.5 Keyboard Emulation (Generic Mode)
```json
{
  "type": "PRESS_KEY",
  "requestId": "key-1122",
  "key": "Enter",
  "modifiers": []
}
```
Supported `key` values:
- `"Enter"`, `"Backspace"`, `"Tab"`, `"Escape"`, `"Space"`, `"ArrowUp"`, `"ArrowDown"`, `"ArrowLeft"`, `"ArrowRight"`, `"Paste"`

Modifiers:
- Array of `"cmd"`, `"shift"`, `"alt"`, `"ctrl"`

---

## 4. Mac ↔ Browser Extension Protocol

Extension connects to `ws://127.0.0.1:<port>/ws/extension`.

### 4.1 Registration
Extension sends:
```json
{
  "type": "EXT_REGISTER",
  "version": "1.0.0"
}
```

### 4.2 Tab State Notification
Extension sends whenever active tab or meeting state changes:
```json
{
  "type": "EXT_TAB_STATE",
  "tabId": 42,
  "url": "https://meet.google.com/abc-defg-hij",
  "adapter": "google-meet",
  "meetingDetected": true,
  "chatOpen": false
}
```

### 4.3 Command Execution Request (Mac -> Extension)
```json
{
  "type": "EXECUTE_COMMAND",
  "requestId": "ext-cmd-1",
  "action": "SEND_MESSAGE",
  "text": "Hello team",
  "adapter": "google-meet"
}
```

### 4.4 Command Execution Result (Extension -> Mac)
```json
{
  "type": "COMMAND_RESULT",
  "requestId": "ext-cmd-1",
  "success": true,
  "adapter": "google-meet",
  "action": "SEND_MESSAGE",
  "message": "Message sent in Google Meet"
}
```

---

## 5. Error Codes

| Error Code | Description |
|---|---|
| `UNAUTHORIZED` | Request sent without valid session token |
| `INVALID_TOKEN` | Pairing token incorrect or expired |
| `APP_NOT_RUNNING` | Target application (e.g. Zoom) is not running |
| `MEETING_NOT_ACTIVE` | Target app running, but no active call/meeting detected |
| `CHAT_NOT_FOUND` | Chat button/panel could not be located |
| `INPUT_NOT_FOUND` | Message input textarea or contenteditable element missing |
| `SEND_BUTTON_NOT_FOUND` | Send button could not be located and Enter failed |
| `PERMISSION_REQUIRED` | macOS Accessibility permission has not been granted |
| `EXTENSION_NOT_CONNECTED` | Browser tab active, but Chrome extension not running |
| `TIMEOUT` | Action took longer than 5000ms |
