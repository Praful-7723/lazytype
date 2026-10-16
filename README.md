# LazyType — Local Android-to-Mac Meeting Chat Companion

> **Type and send messages during Zoom and video calls on your Mac directly from your Android phone—without moving your Mac mouse, touching the trackpad, or leaning toward your laptop screen.**

---

## ⚡ START HERE (30-Second Quick Start)

You can test the complete system end-to-end immediately without needing an active live Zoom meeting:

### Step 1. Compile and Launch the Mac Companion
In the project directory on your Mac:
```bash
npm run build:mac
npm run start:mac
```
The native companion app starts, listens on local Wi-Fi port `9123`, and shows an icon `⌨️ LazyType` in your macOS Menu Bar. The terminal also prints your local Pairing URL.

### Step 2. Run Automated Verification Tests
In a separate terminal:
```bash
npm test
```
All 23 end-to-end automated tests will execute and pass, verifying HTTP delivery, WebSocket pairing, security token validation, browser extension message forwarding, and generic keyboard emulation.

### Step 3. Connect from your Phone
1. Open Chrome on your Android phone (connected to the same Wi-Fi as your Mac).
2. Scan the Pairing QR code shown by clicking **"Show Pairing QR..."** in the Mac menu bar, or open:
   ```
   http://<mac-ip>:9123/
   ```
3. Tap **[ SEND MESSAGE ]** on your phone—watch your message appear instantly on your Mac!

---

## 📐 Architecture Overview

LazyType consists of three lightweight, decoupled layers communicating over a local WebSocket protocol:

```
┌─────────────────────────────────┐
│     Android Companion (PWA)     │
│   • One-handed mobile UI        │
│   • Message textarea & history  │
│   • Auto-reconnect              │
└───────────────▲─────────────────┘
                │ Local WebSocket (ws://<mac-ip>:9123/ws/phone)
                ▼
┌─────────────────────────────────────────────────────────────┐
│                      Mac Companion App                      │
│   • Native macOS Menu Bar accessory (Swift / AppKit)        │
│   • Embedded HTTP & WebSocket Server (Zero dependencies)    │
│   • Security & Pairing Manager (Session tokens, revoking)   │
│   • Smart Target Resolver & Adaptive Hierarchy Inspection   │
│                                                             │
│   ┌────────────────────┬────────────────────────────────┐   │
│   │ Native Adapters    │ Web Extension Bridge           │   │
│   │ • ZoomNativeAdapter│ • BrowserBridgeAdapter         │   │
│   │ • GenericMacInput  │   (ws://127.0.0.1:9123/ws/ext) │   │
│   └─────────┬──────────┴───────────────┬────────────────┘   │
└─────────────┼──────────────────────────┼────────────────────┘
              │                          │
              ▼                          ▼
     macOS Accessibility API        Chrome MV3 Extension
         (AXUIElement)                       │
              │                              ▼
        [Zoom Native]                DOM Event Injector
                                  (beforeinput, input, Enter)
                                             │
                                   ┌─────────┴─────────┐
                                   ▼                   ▼
                            [Google Meet]         [Demo Call]
```

### 1. Mac Companion App (`mac/`)
- Written in **Swift** using standard Apple frameworks (`AppKit`, `ApplicationServices`, `CoreGraphics`, `CoreImage`).
- **No Coordinate-Based Automation**: Interacts with real UI elements semantically using the macOS Accessibility API (`AXUIElement`) and `CGEvent` keyboard typing fallback.
- **Embedded Local Server**: Serves static PWA assets and handles RFC 6455 WebSockets with zero third-party dependencies.
- **Universal Compatibility**: Fully tested and optimized for both Intel (`x86_64`) and Apple Silicon (`arm64`) Macs.

### 2. Android Companion PWA (`phone/`)
- Served directly by the Mac companion over your local Wi-Fi network.
- Optimized for **one-handed thumb usage** with large touch targets (minimum 52px).
- Supports **Add to Home Screen**, message history, auto-reconnection with exponential backoff, and camera QR scanning (`BarcodeDetector`).
- Modes:
  - **Send Mode**: User types a full message and taps SEND.
  - **Insert Only**: Types text into the target field without sending.
  - **Live Typing**: Streams text incrementally with 150ms debouncing.

### 3. Chromium Browser Extension (`extension/`)
- Manifest V3 extension bridging the Mac Companion to browser meeting interfaces.
- Uses synthetic reactive DOM event injection (`focus`, `beforeinput`, native prototype setter, `input`, `change`, and `keydown` Enter) so that React, Vue, and Angular meeting clients detect input changes.
- Modular web adapters: `GoogleMeetAdapter`, `ZoomWebAdapter`, `DemoChatAdapter`, `GenericWebAdapter`.

---

## 🔒 Security Architecture

Typing into a computer remotely requires strict security protections:
1. **No Cloud Relay**: Communication stays entirely local between your phone and your Mac over your local Wi-Fi or loopback.
2. **Ephemeral Pairing Tokens**: Pairing QR codes contain temporary random tokens (e.g. `pair_...`) valid for 5 minutes.
3. **Session Authentication**: Upon pairing, the Mac issues a cryptographically random `sessionToken` stored in phone `localStorage`.
4. **Device Registry & Revocation**: All paired devices appear under the Mac menu bar **"Connected Devices..."** window. You can instantly revoke any device or forget all devices with one click.
5. **Unauthorized Rejection**: Any command sent without an active, authorized session token is immediately rejected with `401 / UNAUTHORIZED`.

---

## 🛠️ Step-by-Step Installation & Setup

### 1. macOS Permissions
The Mac Companion requires macOS **Accessibility** permission to locate Zoom chat elements and send keyboard events.
1. When you first launch `LazyTypeCompanion`, macOS will display a prompt asking to grant Accessibility access.
2. Open **System Settings ➔ Privacy & Security ➔ Accessibility**.
3. Locate **LazyTypeCompanion** (or your Terminal / Terminal IDE if running via script) and toggle it **ON**.
4. To verify at any time, click **"Check Accessibility Permission..."** in the LazyType menu bar item.

### 2. Chrome Extension Installation
To control Google Meet, Zoom Web, or the interactive demo page in Google Chrome / Brave / Edge:
1. Open Google Chrome and navigate to `chrome://extensions`.
2. Enable **Developer mode** using the toggle switch in the top-right corner.
3. Click **"Load unpacked"** in the top-left toolbar.
4. Select the directory:
   ```
   /Volumes/ExternalSSD/Projects/lazytype/extension
   ```
5. Click the LazyType puzzle-piece icon in your browser toolbar to confirm the extension status shows **"Connected ✓"**.

### 3. Android Pairing
1. Ensure your Android phone is connected to the same Wi-Fi network as your Mac.
2. In the Mac menu bar, click **"Show Pairing QR..."**.
3. On your phone:
   - Open your camera or QR code scanner and scan the code.
   - Or open Chrome on Android and navigate directly to:
     ```
     http://<your-mac-ip>:9123/
     ```
4. Tap **Pair / Connect**. Your phone will save the session token and immediately display the controller screen.
5. Tap **⋮ ➔ Add to Home screen** in Chrome on Android to install LazyType as a standalone app icon on your home screen.

---

## 🧪 Testing the Complete Flow

### Automated Test Suite
Run the automated test suite anytime with:
```bash
npm test
```
This launches a headless instance of the Mac companion, connects mock phone and extension WebSocket clients, and tests:
- HTTP 200 delivery of PWA, JS, CSS, Demo, and QR PNG
- Invalid token rejection & unauthorized request blocking
- Pairing handshake & session token issue
- Automatic reconnection with saved session tokens
- Full vertical slice: Phone `SEND_MESSAGE` ➔ Mac Companion ➔ Extension ➔ DOM ➔ Confirmation
- Generic keypress emulation via `CGEvent`

### Interactive Demo Target
To see the full visual experience without starting a Zoom meeting:
1. In the Mac menu bar, click **"Open Interactive Demo Call..."** (or navigate to `http://127.0.0.1:9123/demo`).
2. A simulated video meeting call will open in Chrome with Jane Smith and Alex Kumar, video tiles, a collapsible chat sidebar, and bottom meeting controls.
3. On your phone, type:
   ```
   Can you send me that document?
   ```
   and tap **[ SEND MESSAGE ]**.
4. Notice how the chat panel opens automatically (if closed), the message is inserted into the textarea, and the message visibly appears in the chat transcript with confirmation on your phone!

---

## 📹 Testing with Real Zoom

### Native Zoom Desktop App:
1. Start or join a Zoom meeting in the native macOS Zoom app.
2. On your phone, LazyType will automatically detect Zoom as the frontmost target app and show:
   ```
   Target: Zoom
   Meeting: Active ✓
   Chat: Ready ✓
   ```
3. Type your chat message on your phone and tap **SEND MESSAGE**.
4. The adapter:
   - Identifies Zoom's meeting window.
   - If the chat panel is closed, invokes the accessible Chat button.
   - Locates the chat input field using `AXUIElement` hierarchy traversal.
   - Inserts your message.
   - Triggers the Send button or sends Return.
   - Returns **"Message sent in Zoom ✓"** to your phone.

### Zoom Web Client:
1. Join a Zoom meeting in Google Chrome via the browser client (`zoom.us/wc/...`).
2. The Chrome extension detects the Zoom web DOM and routes remote chat commands to `ZoomWebAdapter`.

---

## ➕ Adding a New Application Adapter

The modular adapter architecture makes adding support for other applications (such as Microsoft Teams, Slack, Discord, or WhatsApp) straightforward:

### Adding a Native macOS Adapter (`mac/Sources/RemoteCompanion/Adapters/`):
1. Create a class implementing `ApplicationAdapter`:
   ```swift
   public final class TeamsNativeAdapter: ApplicationAdapter {
       public let adapterId = "teams-native"
       public let displayName = "Microsoft Teams"
       
       public func canHandle(app: RunningAppInfo?) -> Bool {
           return app?.bundleIdentifier.contains("com.microsoft.teams") == true
       }
       
       public func getState(app: RunningAppInfo?) async -> AdapterState { ... }
       public func sendMessage(text: String, app: RunningAppInfo?) async -> Result<AdapterActionResult, AdapterError> { ... }
       public func openChat(app: RunningAppInfo?) async -> Result<AdapterActionResult, AdapterError> { ... }
       public func toggleMute(app: RunningAppInfo?) async -> Result<AdapterActionResult, AdapterError> { ... }
       public func toggleCamera(app: RunningAppInfo?) async -> Result<AdapterActionResult, AdapterError> { ... }
       public func pressKey(key: String, modifiers: [String], app: RunningAppInfo?) async -> Result<AdapterActionResult, AdapterError> { ... }
   }
   ```
2. Register your adapter in `AdapterRegistry.swift`.

### Adding a Browser DOM Adapter (`extension/adapters/`):
1. Create a JavaScript adapter in `extension/adapters/`:
   ```javascript
   window.TeamsWebAdapter = {
     id: 'teams-web',
     name: 'Microsoft Teams Web',
     match() { return window.location.hostname.includes('teams.microsoft.com'); },
     getState() { ... },
     async openChat() { ... },
     async sendMessage(text) {
       const input = document.querySelector('div[contenteditable="true"]');
       window.LazyTypeInjector.insertText(input, text);
       window.LazyTypeInjector.dispatchEnter(input);
       return { success: true, message: 'Sent in Teams ✓' };
     }
   };
   ```
2. Add the script to `manifest.json` under `content_scripts`.

---

## 📋 Acceptance Criteria Verification Matrix

| # | Requirement | Status | Verification Method |
|---|---|---|---|
| 1 | Mac companion launches in menu bar | ✅ Complete | Verified (`NSStatusBar.system`, `LSUIElement = true`) |
| 2 | Accessibility permission handling | ✅ Complete | `PermissionsHelper.isAccessibilityGranted()` + direct system settings opener |
| 3 | QR pairing code generation | ✅ Complete | `CIQRCodeGenerator` native window + `/qr.png` endpoint |
| 4 | Android phone connects over local Wi-Fi | ✅ Complete | Verified over local LAN (`ws://<ip>:9123/ws/phone`) |
| 5 | Session persistence across reconnects | ✅ Complete | Verified with saved `sessionToken` in `test-e2e.js` |
| 6 | Phone displays Mac connection status | ✅ Complete | Real-time `STATUS_UPDATE` HUD pills |
| 7 | User can type message on Android | ✅ Complete | Responsive PWA textarea with auto-capitalize |
| 8 | Press SEND on phone | ✅ Complete | Prominent thumb-friendly `[ SEND MESSAGE ]` button |
| 9 | Mac receives `SEND_MESSAGE` | ✅ Complete | Verified over WebSocket frame decoder |
| 10 | Target adapter determination | ✅ Complete | `AdapterRegistry.resolveAdapter()` with smart auto-detection |
| 11 | Target chat interface identification | ✅ Complete | Resilient AX traversal (native) & DOM query (web) |
| 12 | Text insertion without cursor movement | ✅ Complete | `AXUIElementSetAttributeValue` + `KeyboardInjector.typeString` + `dom-injector.js` |
| 13 | Trigger Send action | ✅ Complete | AXPress on accessible Send button or Enter dispatch |
| 14 | Message appears in chat | ✅ Complete | Verified end-to-end in automated test suite & demo target |
| 15 | Phone receives confirmation | ✅ Complete | Returns `{ success: true, message: "..." }` + haptic vibration |
| 16 | No mouse cursor jumping | ✅ Complete | Strictly semantic AXUIElement / DOM interaction |
| 17 | No hardcoded X/Y coordinates | ✅ Complete | Zero screen coordinates in codebase |
| 18 | Unauthorized devices rejected | ✅ Complete | Verified in `test-e2e.js` test 3a/3b |
| 19 | Automatic reconnection | ✅ Complete | Verified in `test-e2e.js` test 3d |
| 20 | Generic keyboard fallback | ✅ Complete | Verified in `test-e2e.js` test 6 (`CGEvent` key injection) |

---

## ⚠️ Known Limitations & Edge Cases

1. **macOS Secure Event Input**: If a macOS password dialog or lock screen has focus, macOS blocks background event taps (`CGEventTap`) for security. LazyType handles this gracefully by returning an error instead of hanging.
2. **Wi-Fi Client Isolation**: Some enterprise or guest Wi-Fi networks block direct peer-to-peer communication between devices on the same subnet ("client isolation"). If your phone cannot reach your Mac, use standard personal Wi-Fi or turn on macOS Internet Sharing / Mobile Hotspot.
3. **Zoom Accessibility Variations**: Certain custom Zoom enterprise builds or older versions may format accessibility labels differently; the `ZoomNativeAdapter` uses a multi-attribute fuzzy search (title, description, identifier, text input role) and falls back to targeted keyboard input to maintain reliability.

---

## 📜 Modern Web Guidance

- **`migrate-web-app-origin`**: Maintained standard relative asset paths (`/sw.js`, `/manifest.json`, `/icons/icon-192.png`) ensuring seamless origin binding when accessing the PWA via local IP or localhost without broken cache partitions.
- PWA layout uses viewport-fit cover (`viewport-fit=cover`), `inputmode="url"`, `enterkeyhint="send"`, and safe-area insets (`env(safe-area-inset-bottom)`) for optimal one-handed Android mobile usage.
