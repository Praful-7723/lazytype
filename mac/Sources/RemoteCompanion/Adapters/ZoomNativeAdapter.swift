import Foundation
import ApplicationServices
import AppKit

public final class ZoomNativeAdapter: ApplicationAdapter, @unchecked Sendable {
    public let adapterId = "zoom-native"
    public let displayName = "Zoom (Native App)"
    
    public init() {}
    
    public func canHandle(app: RunningAppInfo?) -> Bool {
        if let app = app, app.isZoom { return true }
        return AppDetector.findZoomApp() != nil
    }
    
    public func getState(app: RunningAppInfo?) async -> AdapterState {
        guard let zoomApp = app?.isZoom == true ? app : AppDetector.findZoomApp() else {
            return AdapterState(
                adapterId: adapterId,
                activeApplication: "Zoom (Not Running)",
                meetingDetected: false,
                chatAvailable: false,
                chatOpen: false
            )
        }
        
        guard AXHelper.isProcessTrusted() else {
            return AdapterState(
                adapterId: adapterId,
                activeApplication: "Zoom (Permission Required)",
                meetingDetected: false,
                chatAvailable: false,
                chatOpen: false
            )
        }
        
        let appElement = AXHelper.getApplicationElement(pid: zoomApp.pid)
        let windows = AXHelper.getWindows(appElement)
        
        // Find meeting window (usually named "Zoom Meeting", "Zoom Workplace", etc.)
        let meetingWindow = windows.first { win in
            let title = AXHelper.getStringAttribute(win, attribute: kAXTitleAttribute as CFString)?.lowercased() ?? ""
            return title.contains("meeting") || title.contains("zoom") || title.contains("call")
        } ?? windows.first
        
        let isMeetingActive = meetingWindow != nil
        var isChatOpen = false
        var isChatAvailable = isMeetingActive
        
        if let window = meetingWindow {
            // Check if chat input is currently present in hierarchy
            let chatInput = AXHelper.findTextInput(in: window, hintKeywords: ["chat", "message", "type", "text"])
            isChatOpen = (chatInput != nil)
            let chatBtn = AXHelper.findButton(in: window, matching: ["chat"])
            if chatBtn != nil {
                isChatAvailable = true
            }
        }
        
        return AdapterState(
            adapterId: adapterId,
            activeApplication: "Zoom",
            meetingDetected: isMeetingActive,
            chatAvailable: isChatAvailable,
            chatOpen: isChatOpen,
            canSendMessage: isMeetingActive,
            canMute: true,
            canControlCamera: true
        )
    }
    
    public func openChat(app: RunningAppInfo?) async -> Result<AdapterActionResult, AdapterError> {
        guard let zoomApp = app?.isZoom == true ? app : AppDetector.findZoomApp() else {
            return .failure(.appNotRunning("Zoom"))
        }
        guard AXHelper.isProcessTrusted() else {
            return .failure(.permissionRequired)
        }
        
        let appElement = AXHelper.getApplicationElement(pid: zoomApp.pid)
        let windows = AXHelper.getWindows(appElement)
        guard let window = windows.first else {
            return .failure(.meetingNotActive)
        }
        
        // Check if chat input is already visible
        if let _ = AXHelper.findTextInput(in: window, hintKeywords: ["chat", "message"]) {
            return .success(AdapterActionResult(success: true, adapterId: adapterId, action: "OPEN_CHAT", message: "Chat is already open"))
        }
        
        // Find and press Chat button
        guard let chatBtn = AXHelper.findButton(in: window, matching: ["chat"]) else {
            return .failure(.chatNotFound)
        }
        
        let pressed = AXHelper.performPress(chatBtn)
        if !pressed {
            return .failure(.custom("Could not trigger Zoom Chat button"))
        }
        
        // Brief wait for chat panel animation
        try? await Task.sleep(nanoseconds: 200_000_000)
        return .success(AdapterActionResult(success: true, adapterId: adapterId, action: "OPEN_CHAT", message: "Zoom chat panel opened"))
    }
    
    public func sendMessage(text: String, app: RunningAppInfo?) async -> Result<AdapterActionResult, AdapterError> {
        guard let zoomApp = app?.isZoom == true ? app : AppDetector.findZoomApp() else {
            return .failure(.appNotRunning("Zoom"))
        }
        guard AXHelper.isProcessTrusted() else {
            return .failure(.permissionRequired)
        }
        
        // Bring Zoom to front if needed so accessibility elements respond reliably
        if let runningApp = NSRunningApplication(processIdentifier: zoomApp.pid) {
            runningApp.activate(options: [.activateIgnoringOtherApps])
        }
        
        let appElement = AXHelper.getApplicationElement(pid: zoomApp.pid)
        let windows = AXHelper.getWindows(appElement)
        guard let window = windows.first else {
            return .failure(.meetingNotActive)
        }
        
        // 1. Locate chat input, or open chat if closed
        var chatInput = AXHelper.findTextInput(in: window, hintKeywords: ["chat", "message", "type", "to:"])
        if chatInput == nil {
            AppLogger.shared.log("Chat input not visible; attempting to open Zoom chat...")
            if let chatBtn = AXHelper.findButton(in: window, matching: ["chat"]) {
                _ = AXHelper.performPress(chatBtn)
                try? await Task.sleep(nanoseconds: 250_000_000)
                chatInput = AXHelper.findTextInput(in: window, hintKeywords: ["chat", "message", "type"])
            }
        }
        
        guard let targetInput = chatInput ?? AXHelper.findTextInput(in: window) else {
            return .failure(.inputNotFound)
        }
        
        // 2. Insert text via AXSetValue or keyboard injection
        _ = AXHelper.setFocused(targetInput)
        let setSuccess = AXHelper.setStringValue(targetInput, text: text)
        if !setSuccess {
            AppLogger.shared.log("AXSetValue not accepted by Zoom; falling back to direct keyboard typing")
            KeyboardInjector.typeString(text)
        }
        
        try? await Task.sleep(nanoseconds: 80_000_000)
        
        // 3. Trigger Send action: look for Send button, or dispatch Return key
        var sent = false
        if let sendBtn = AXHelper.findButton(in: window, matching: ["send"]) {
            sent = AXHelper.performPress(sendBtn)
        }
        
        if !sent {
            // Send Return key to the focused input
            KeyboardInjector.postReturn()
            sent = true
        }
        
        AppLogger.shared.audit(phone: "Phone", action: "SEND_MESSAGE", target: "Zoom", success: sent, text: text)
        return .success(AdapterActionResult(success: true, adapterId: adapterId, action: "SEND_MESSAGE", message: "Message sent in Zoom ✓"))
    }
    
    public func insertText(text: String, app: RunningAppInfo?) async -> Result<AdapterActionResult, AdapterError> {
        guard let zoomApp = app?.isZoom == true ? app : AppDetector.findZoomApp() else {
            return .failure(.appNotRunning("Zoom"))
        }
        guard AXHelper.isProcessTrusted() else {
            return .failure(.permissionRequired)
        }
        
        let appElement = AXHelper.getApplicationElement(pid: zoomApp.pid)
        let windows = AXHelper.getWindows(appElement)
        guard let window = windows.first else {
            return .failure(.meetingNotActive)
        }
        
        guard let input = AXHelper.findTextInput(in: window, hintKeywords: ["chat", "message"]) ?? AXHelper.findTextInput(in: window) else {
            return .failure(.inputNotFound)
        }
        
        _ = AXHelper.setFocused(input)
        let success = AXHelper.setStringValue(input, text: text)
        if !success {
            KeyboardInjector.typeString(text)
        }
        
        return .success(AdapterActionResult(success: true, adapterId: adapterId, action: "INSERT_TEXT", message: "Text inserted in Zoom"))
    }
    
    public func toggleMute(app: RunningAppInfo?) async -> Result<AdapterActionResult, AdapterError> {
        guard let zoomApp = app?.isZoom == true ? app : AppDetector.findZoomApp() else {
            return .failure(.appNotRunning("Zoom"))
        }
        
        // 1. Try AX button press
        let appElement = AXHelper.getApplicationElement(pid: zoomApp.pid)
        let windows = AXHelper.getWindows(appElement)
        if let window = windows.first, let muteBtn = AXHelper.findButton(in: window, matching: ["mute", "unmute", "audio"]) {
            if AXHelper.performPress(muteBtn) {
                return .success(AdapterActionResult(success: true, adapterId: adapterId, action: "TOGGLE_MUTE", message: "Zoom audio toggled"))
            }
        }
        
        // 2. Fall back to native shortcut Cmd+Shift+A
        if let runningApp = NSRunningApplication(processIdentifier: zoomApp.pid) {
            runningApp.activate(options: [.activateIgnoringOtherApps])
            try? await Task.sleep(nanoseconds: 50_000_000)
            KeyboardInjector.sendZoomMuteShortcut()
            return .success(AdapterActionResult(success: true, adapterId: adapterId, action: "TOGGLE_MUTE", message: "Zoom mute toggled via shortcut"))
        }
        
        return .failure(.custom("Could not toggle Zoom audio"))
    }
    
    public func toggleCamera(app: RunningAppInfo?) async -> Result<AdapterActionResult, AdapterError> {
        guard let zoomApp = app?.isZoom == true ? app : AppDetector.findZoomApp() else {
            return .failure(.appNotRunning("Zoom"))
        }
        
        // 1. Try AX button press
        let appElement = AXHelper.getApplicationElement(pid: zoomApp.pid)
        let windows = AXHelper.getWindows(appElement)
        if let window = windows.first, let camBtn = AXHelper.findButton(in: window, matching: ["start video", "stop video", "video"]) {
            if AXHelper.performPress(camBtn) {
                return .success(AdapterActionResult(success: true, adapterId: adapterId, action: "TOGGLE_CAMERA", message: "Zoom video toggled"))
            }
        }
        
        // 2. Fall back to native shortcut Cmd+Shift+V
        if let runningApp = NSRunningApplication(processIdentifier: zoomApp.pid) {
            runningApp.activate(options: [.activateIgnoringOtherApps])
            try? await Task.sleep(nanoseconds: 50_000_000)
            KeyboardInjector.sendZoomVideoShortcut()
            return .success(AdapterActionResult(success: true, adapterId: adapterId, action: "TOGGLE_CAMERA", message: "Zoom video toggled via shortcut"))
        }
        
        return .failure(.custom("Could not toggle Zoom video"))
    }
    
    public func pressKey(key: String, modifiers: [String], app: RunningAppInfo?) async -> Result<AdapterActionResult, AdapterError> {
        KeyboardInjector.postKeyByName(key, modifiers: modifiers)
        return .success(AdapterActionResult(success: true, adapterId: adapterId, action: "PRESS_KEY", message: "Key \(key) sent"))
    }
}
