import Foundation
import AppKit

private final class LiveTextBuffer: @unchecked Sendable {
    private var text: String = ""
    private let lock = NSLock()
    
    func reset() -> String {
        lock.lock()
        defer { lock.unlock() }
        let prev = text
        text = ""
        return prev
    }
    
    func update(to newText: String) -> (previous: String, current: String) {
        lock.lock()
        defer { lock.unlock() }
        let prev = text
        text = newText
        return (prev, newText)
    }
}

public final class GenericMacInputAdapter: ApplicationAdapter, @unchecked Sendable {
    public let adapterId = "generic"
    public let displayName = "Universal Mac Typing"
    
    private let liveBuffer = LiveTextBuffer()
    
    public init() {}
    
    public func canHandle(app: RunningAppInfo?) -> Bool {
        return true // Fallback matches all
    }
    
    public func getState(app: RunningAppInfo?) async -> AdapterState {
        let appName = app?.localizedName ?? "Active Application"
        var chatAvailable = false
        var targetName = appName
        
        if let app = app {
            let pid = app.pid
            let appElement = AXUIElementCreateApplication(pid)
            var focusedRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedRef) == .success,
               let focused = focusedRef {
                let info = AXHelper.inspectElement(focused as! AXUIElement)
                let role = info.role ?? ""
                if role == (kAXTextFieldRole as String) || role == (kAXTextAreaRole as String) || role.contains("Text") || role.contains("Search") {
                    chatAvailable = true
                    if role.contains("Search") {
                        targetName = "\(appName) Search"
                    } else if let title = info.title, !title.isEmpty {
                        targetName = "\(appName) (\(title))"
                    } else {
                        targetName = "\(appName) Text Field"
                    }
                }
            }
            
            let lowerName = appName.lowercased()
            let lowerBid = app.bundleIdentifier.lowercased()
            if lowerName.contains("notes") || lowerName.contains("textedit") || lowerName.contains("slack") ||
               lowerName.contains("messages") || lowerName.contains("spotlight") || lowerName.contains("terminal") ||
               lowerName.contains("code") || lowerName.contains("xcode") || lowerBid.contains("spotlight") {
                chatAvailable = true
                targetName = appName
            }
        }
        
        return AdapterState(
            adapterId: adapterId,
            activeApplication: targetName,
            meetingDetected: false,
            chatAvailable: chatAvailable,
            chatOpen: chatAvailable,
            canSendMessage: chatAvailable,
            canMute: false,
            canControlCamera: false
        )
    }
    
    public func sendMessage(text: String, app: RunningAppInfo?) async -> Result<AdapterActionResult, AdapterError> {
        let previous = liveBuffer.reset()
        
        if previous != text {
            if !previous.isEmpty && text.hasPrefix(previous) {
                let remainder = String(text.dropFirst(previous.count))
                KeyboardInjector.typeString(remainder)
            } else {
                if !previous.isEmpty {
                    KeyboardInjector.postBackspace(count: previous.count)
                }
                KeyboardInjector.typeString(text)
            }
            try? await Task.sleep(nanoseconds: 30_000_000)
        }
        
        KeyboardInjector.postReturn()
        
        AppLogger.shared.audit(phone: "Phone", action: "SEND_MESSAGE", target: "Generic", success: true, text: text)
        return .success(AdapterActionResult(success: true, adapterId: adapterId, action: "SEND_MESSAGE", message: "Typed text and pressed Enter ✓"))
    }
    
    public func insertText(text: String, app: RunningAppInfo?) async -> Result<AdapterActionResult, AdapterError> {
        let (previous, _) = liveBuffer.update(to: text)
        
        if text.isEmpty {
            if !previous.isEmpty {
                KeyboardInjector.postBackspace(count: previous.count)
            }
            return .success(AdapterActionResult(success: true, adapterId: adapterId, action: "INSERT_TEXT", message: "Cleared"))
        }
        
        if text.hasPrefix(previous) {
            let newChars = String(text.dropFirst(previous.count))
            KeyboardInjector.typeString(newChars)
        } else if previous.hasPrefix(text) {
            let backspaces = previous.count - text.count
            KeyboardInjector.postBackspace(count: backspaces)
        } else {
            KeyboardInjector.postBackspace(count: previous.count)
            KeyboardInjector.typeString(text)
        }
        
        return .success(AdapterActionResult(success: true, adapterId: adapterId, action: "INSERT_TEXT", message: "Text typed"))
    }
    
    public func openChat(app: RunningAppInfo?) async -> Result<AdapterActionResult, AdapterError> {
        return .failure(.unsupportedAction("Open Chat is not supported in Generic mode"))
    }
    
    public func toggleMute(app: RunningAppInfo?) async -> Result<AdapterActionResult, AdapterError> {
        return .failure(.unsupportedAction("Mute is not supported in Generic mode"))
    }
    
    public func toggleCamera(app: RunningAppInfo?) async -> Result<AdapterActionResult, AdapterError> {
        return .failure(.unsupportedAction("Camera is not supported in Generic mode"))
    }
    
    public func pressKey(key: String, modifiers: [String], app: RunningAppInfo?) async -> Result<AdapterActionResult, AdapterError> {
        KeyboardInjector.postKeyByName(key, modifiers: modifiers)
        return .success(AdapterActionResult(success: true, adapterId: adapterId, action: "PRESS_KEY", message: "Key \(key) sent"))
    }
}
