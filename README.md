<div align="center">
  <a href="https://github.com/Praful-7723/lazytype">
    <img width="160" src="./assets/mascot.png" alt="LazyType Mascot" />
  </a>

  <h1>LazyType</h1>
  <p><code>STEALTH TEXT INJECTION · LOCAL PEER-TO-PEER ENCLAVE · ZERO PERMISSION LEAKS</code></p>
  <h3>Type secretly from your phone straight into Zoom, Google Meet &amp; macOS apps.</h3>

  <br />

  <a href="https://github.com/Praful-7723/lazytype/releases/latest"><img src="https://img.shields.io/badge/DOWNLOAD_DMG_(v2.0.0)-FF3838?style=for-the-badge&logo=apple&logoColor=white" alt="Download DMG" /></a>
  <a href="https://github.com/Praful-7723/lazytype/releases/latest"><img src="https://img.shields.io/badge/UNIVERSAL_2_(ARM64_+_X86_64)-20242A?style=for-the-badge&logo=apple&logoColor=white" alt="Universal 2" /></a>
  <a href="#03--installation--onboarding"><img src="https://img.shields.io/badge/CHROME_EXTENSION-4285F4?style=for-the-badge&logo=googlechrome&logoColor=white" alt="Chrome Extension" /></a>
  <a href="#05--security--local-enclave"><img src="https://img.shields.io/badge/LOCAL_FIRST-27485C?style=for-the-badge&logo=cloudflare&logoColor=white" alt="Local First" /></a>
  <a href="https://github.com/Praful-7723/lazytype/blob/main/LICENSE"><img src="https://img.shields.io/badge/LICENSE-MIT-gray?style=for-the-badge" alt="MIT License" /></a>

  <br /><br />

  <!-- Hero Motion Reel Showcase -->
  <a href="https://github.com/Praful-7723/lazytype/releases/download/v2.0.0/lazytype_demo_reel.mp4">
    <img src="./assets/demo_reel.gif" alt="LazyType Stealth Typing Demo" width="360" />
  </a>
  <br /><br />
  <p align="center">
    <a href="https://github.com/Praful-7723/lazytype/releases/download/v2.0.0/lazytype_demo_reel.mp4"><img src="https://img.shields.io/badge/▶_WATCH_FULL_REEL_(60FPS)-FF3838?style=for-the-badge&logo=youtube&logoColor=white" alt="Watch Reel" /></a>
    <a href="https://github.com/Praful-7723/lazytype/releases/download/v2.0.0/lazytype_demo_reel.mp4"><img src="https://img.shields.io/badge/DOWNLOAD_MP4_(60FPS)-20242A?style=for-the-badge&logo=apple&logoColor=white" alt="Download MP4" /></a>
  </p>
  <sub>30s Master Reel · 1080×1920 @ 60fps · Zero Latency Local P2P · Native macOS</sub>
</div>

<br />

## `01 / THE PREMISE`

> **Type, draft, and send messages during Zoom, Google Meet, and video calls on your Mac directly from your phone—without moving your Mac mouse, touching the trackpad, or leaning toward your laptop screen.**

During presentations, remote team calls, or multi-monitor setups, typing on your laptop keyboard breaks eye contact and interrupts your meeting posture. **LazyType** solves this by turning your phone into an invisible, low-latency companion keyboard connected exclusively over local peer-to-peer Wi-Fi.

<table>
  <tr>
    <td width="33%" valign="top">
      <b>✦ The Problem</b><br/><br/>
      Reaching for your physical keyboard or moving your mouse cursor during video calls shifts your camera frame, looks obvious, and breaks conversation flow.
    </td>
    <td width="33%" valign="top">
      <b>✦ The Solution</b><br/><br/>
      Hold your phone comfortably in your hand. Type using your phone's keyboard or voice dictation. Keystrokes stream directly into active chat fields in real time.
    </td>
    <td width="33%" valign="top">
      <b>✦ The Philosophy</b><br/><br/>
      Zero cloud relays, zero third-party telemetry, pure local RFC 6455 WebSockets, and semantic accessibility injection without mouse displacement.
    </td>
  </tr>
</table>

<br />

### `HOW IT WORKS IN PRACTICE`

<table>
  <tr>
    <td width="33%" align="center" valign="top">
      <a href="./assets/demo_reclined_dev.jpg">
        <img src="./assets/demo_reclined_dev.jpg" alt="Stay Reclined in Video Calls" width="100%" />
      </a>
      <br/><br/>
      <b>01 · Stay In Frame</b>
      <p align="left"><small>Lean back comfortably in your chair with your feet up. Your laptop webcam stays locked on you while you casually hold your smartphone below frame level.</small></p>
    </td>
    <td width="33%" align="center" valign="top">
      <a href="./assets/demo_meeting_stream.jpg">
        <img src="./assets/demo_meeting_stream.jpg" alt="Real-Time Mobile-to-Mac Ingress" width="100%" />
      </a>
      <br/><br/>
      <b>02 · Real-Time Chat Ingress</b>
      <p align="left"><small>Type silently on your phone or use mobile voice dictation. Keystrokes flow seamlessly across local Wi-Fi straight into Zoom, Google Meet, or Slack chats.</small></p>
    </td>
    <td width="33%" align="center" valign="top">
      <a href="./assets/demo_reel.gif">
        <img src="./assets/demo_reel.gif" alt="Stealth Ingress Animation" width="100%" />
      </a>
      <br/><br/>
      <b>03 · Zero-Latency Motion</b>
      <p align="left"><small>Local RFC 6455 WebSockets and native macOS accessibility events ensure keystrokes land instantly with zero cloud lag.</small></p>
    </td>
  </tr>
</table>

<br />

## `02 / SYSTEM ARCHITECTURE`

LazyType is engineered into three lightweight, decoupled layers that communicate over zero-latency local WebSockets:

```
┌─────────────────────────────────────────────────────────────┐
│                 Mobile Phone Companion (PWA)                │
│    • Touch-optimized dark glass interface                   │
│    • Send Mode, Insert Only, and Live Streaming             │
│    • Ephemeral QR pairing with local session handshake      │
└──────────────────────────────▲──────────────────────────────┘
                               │ Local LAN WebSocket (ws://<mac-ip>:9123)
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                     macOS Companion App                     │
│    • Native AppKit Menu Bar daemon (Swift 5.10)             │
│    • Embedded zero-dependency HTTP & RFC 6455 daemon        │
│    • Cryptographic pairing & one-click device revocation    │
│    • Smart target resolver & semantic AXUIElement injector  │
│                                                             │
│    ┌───────────────────────────┬────────────────────────┐   │
│    │  Native AppKit Adapters   │  Chromium WS Bridge    │   │
│    │  • Zoom Desktop Adapter   │  • Google Meet Adapter │   │
│    │  • Generic CGEvent Tap    │  • Teams & Zoom Web    │   │
│    └─────────────┬─────────────┴───────────┬────────────┘   │
└──────────────────┼─────────────────────────┼────────────────┘
                   │                         │
                   ▼                         ▼
         macOS Accessibility         Chromium MV3 Extension
         (`AXUIElement` API)          (Reactive DOM Bridge)
                   │                         │
                   ▼                         ▼
           [Native Zoom App]         [Google Meet & Tabs]
```

### `System layers`

| Layer | Component | Materials | What it does |
|:---|:---|:---|:---|
| **Mac Companion** | Native Menu Bar App (`mac/`) | Swift 5.10, AppKit, CoreGraphics | Serves local PWA, handles RFC 6455 WebSockets on port `9123`, and injects semantic keystrokes |
| **Phone Companion** | Mobile Web App (`phone/`) | HTML5, CSS3, ES6 JavaScript | Standalone PWA served from Mac, with thumb-friendly controls and haptic feedback |
| **Browser Bridge** | Chromium MV3 Extension (`extension/`) | Manifest V3, Content Scripts | Injects reactive DOM events (`beforeinput`, `input`, Enter) into Google Meet and web calls |

<br />

## `03 / INSTALLATION & ONBOARDING`

<table>
  <tr>
    <td width="50%" valign="top">
      <h3>Option A · Direct Native DMG</h3>
      <p>Download the pre-compiled Universal 2 installer with one-click drag-and-drop setup:</p>
      <p>
        <a href="https://github.com/Praful-7723/lazytype/releases/latest"><img src="https://img.shields.io/badge/DOWNLOAD-LazyType--2.0.0.dmg-FF3838?style=for-the-badge&logo=apple&logoColor=white" alt="Download DMG" /></a>
      </p>
      <p><b>Supports:</b> Apple Silicon (M1 / M2 / M3 / M4) and Intel (<code>x86_64</code>) Macs natively.</p>
    </td>
    <td width="50%" valign="top">
      <h3>Option B · Build from Source</h3>
      <p>Compile the Universal 2 binary directly with the included build toolchain:</p>
      <pre><code>git clone https://github.com/Praful-7723/lazytype.git
cd lazytype
npm install
./scripts/build-mac.sh
./scripts/package-app.sh</code></pre>
    </td>
  </tr>
</table>

> [!NOTE]
> **First Launch on macOS (Gatekeeper Unidentified Developer):**  
> Because LazyType is free and open-source (distributed without a paid $99/year Apple Developer account), macOS Gatekeeper displays an *"Unidentified Developer"* alert on first download.  
> **How to open in 2 clicks:**
> 1. Open **System Settings ➔ Privacy & Security**.
> 2. Scroll down to **Security** and click **"Open Anyway"** next to *LazyType*.
> 3. Click **"Open"** when prompted.  
> *(Or run `xattr -cr /Applications/LazyType.app` in Terminal).*

### `30-Second Quickstart`

1. **Install:** Double-click `LazyType-2.0.0.dmg` and drag `LazyType` into `/Applications`.
2. **First Launch:** Open `LazyType.app` from your Applications folder. (If prompted by Gatekeeper, click *"Open Anyway"* in System Settings > Privacy & Security).
3. **Onboarding Guide:** The setup guide opens automatically:
   - **macOS Accessibility:** Click *Open System Settings* and toggle LazyType **ON**.
   - **Chrome Extension:** Click *Download Extension (.zip)*, extract the folder, and drag it into `chrome://extensions` (with *Developer mode* enabled).
4. **Scan & Type:** Click the menu bar mascot, tap **Pair Phone**, scan the QR code with your phone camera, and start typing immediately!

<br />

## `04 / COMPONENT DIRECTORY`

| Path | Purpose | Highlights |
|:---|:---|:---|
| [`mac/`](mac/) | Native macOS Companion | Menu bar status accessory, embedded WebSocket/HTTP server, device revocation |
| [`phone/`](phone/) | Phone Companion Web App | Zero-install PWA, dark glass UI, Send/Insert/Live typing modes |
| [`extension/`](extension/) | Manifest V3 Extension | Bridges Google Meet, Teams, and browser tabs with reactive DOM injection |
| [`scripts/build-mac.sh`](scripts/build-mac.sh) | Universal 2 Compiler | Dual-slice compilation (`arm64` + `x86_64`) fused via `lipo` |
| [`scripts/create-dmg.sh`](scripts/create-dmg.sh) | Direct DMG Builder | Generates clean Apple disk image with native Applications folder link |
| [`scripts/test-e2e.js`](scripts/test-e2e.js) | Automated Test Suite | Comprehensive 23-point verification covering handshake, auth, and DOM |

<br />

## `05 / SECURITY & LOCAL ENCLAVE`

Remote typing requires strict local security guarantees. LazyType operates under a zero-cloud enclave architecture:

<table>
  <tr>
    <td width="33%" valign="top">
      <b>01 · Pure Local Network</b><br/><br/>
      100% of communication stays on your local Wi-Fi or mobile hotspot. Zero external telemetry, zero analytics, and zero cloud servers.
    </td>
    <td width="33%" valign="top">
      <b>02 · Ephemeral Pairing</b><br/><br/>
      QR pairing codes use single-use cryptographic tokens with strict 5-minute expirations. Unknown devices cannot connect.
    </td>
    <td width="33%" valign="top">
      <b>03 · Instant Revocation</b><br/><br/>
      Inspect all active connected devices directly from the Mac menu bar and revoke credentials with a single click.
    </td>
  </tr>
</table>

<br />

## `06 / AUTOMATED VERIFICATION`

The full automated end-to-end test suite validates all layers across WebSocket, HTTP, security handshake, and DOM injection:

```bash
npm test
```

```
============================================================
   LazyType End-to-End Automated Verification Suite
============================================================
✓ [1/23] HTTP Server listening on port 9123
✓ [2/23] Static PWA index.html served
✓ [3/23] Static PWA app.js served
✓ [4/23] Dynamic QR code PNG generated and delivered
✓ [5/23] Unauthorized phone WebSocket rejected
✓ [6/23] Pairing token validation accepted
✓ [7/23] Session token issued and stored
✓ [8/23] Reconnection with valid session authenticated
✓ [9/23] Chrome Extension bridge WebSocket accepted
✓ [10/23] Bridge reports extension connection status
✓ [11/23] System status reflects connected extension
✓ [12/23] Mobile client receives status updates
✓ [13/23] SEND_MESSAGE routed from phone to extension
✓ [14/23] DOM input injection triggered in active tab
✓ [15/23] Enter key dispatch executed
✓ [16/23] Confirmation acknowledgement returned to phone
✓ [17/23] Phone receives SUCCESS confirmation
✓ [18/23] Generic keyboard fallback dispatches via CGEvent
✓ [19/23] Invalid command payloads rejected gracefully
✓ [20/23] Client disconnect updates server status
✓ [21/23] Re-pairing after disconnect succeeds
✓ [22/23] Revocation removes device credentials immediately
✓ [23/23] Revoked device cannot reconnect
============================================================
   ALL 23 TESTS PASSED (100% SUCCESS RATE)
============================================================
```

<br />

## `07 / RELEASES & DISTRIBUTION`

| Release | Architecture | Binary Type | Download |
|:---|:---|:---|:---|
| **v2.0.0** (Latest) | Apple Silicon (`arm64`) + Intel (`x86_64`) | Universal 2 (`lipo`) | [**LazyType-2.0.0.dmg**](https://github.com/Praful-7723/lazytype/releases/latest) |
| **v1.0.0** | Apple Silicon (`arm64`) + Intel (`x86_64`) | Universal 2 (`lipo`) | [LazyType-1.0.0.dmg](https://github.com/Praful-7723/lazytype/releases/tag/v1.0.0) |

<br />

<div align="center">
  <p>
    <a href="https://github.com/Praful-7723/lazytype"><img src="https://img.shields.io/badge/STAR_ON_GITHUB-20242A?style=for-the-badge&logo=github&logoColor=white" alt="Star on GitHub" /></a>
    <a href="https://github.com/Praful-7723/lazytype/issues"><img src="https://img.shields.io/badge/SUBMIT_ISSUE-3D677B?style=for-the-badge&logo=github&logoColor=white" alt="Submit Issue" /></a>
    <a href="mailto:praful.edx@gmail.com"><img src="https://img.shields.io/badge/CONTACT-B58D45?style=for-the-badge&logo=gmail&logoColor=white" alt="Contact" /></a>
  </p>
  <sub>Observe carefully · Build deliberately · Ship with care</sub>
</div>