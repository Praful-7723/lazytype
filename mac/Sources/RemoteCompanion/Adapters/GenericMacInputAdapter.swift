import Foundation
import AppKit

public final class GenericMacInputAdapter: ApplicationAdapter, @unchecked Sendable {
    public let adapterId = "generic"
    public let displayName = "Generic Keyboard Mode"
    
    public init() {}
    
    public func canHandle(app: RunningAppInfo?) -> Bool {
        return true // Fallback matches all
    }
    
    public func getState(app: RunningAppInfo?) async -> AdapterState {
        let appName = app?.localizedName ?? "Active Application"
        return AdapterState(
            adapterId: adapterId,
            activeApplication: appName,
            meetingDetected: false,
            chatAvailable: true,
            chatOpen: true,
            canSendMessage: true,
            canMute: false,
            canControlCamera: false
        )
    }
    
    public func sendMessage(text: String, app: RunningAppInfo?) async -> Result<AdapterActionResult, AdapterError> {
        // Types text directly into frontmost app and sends Return
        KeyboardInjector.typeString(text)
        try? await Task.sleep(nanoseconds: 50_000_000)
        KeyboardInjector.postReturn()
        
        AppLogger.shared.audit(phone: "Phone", action: "SEND_MESSAGE", target: "Generic", success: true, text: text)
        return .success(AdapterActionResult(success: true, adapterId: adapterId, action: "SEND_MESSAGE", message: "Typed text and pressed Enter ✓"))
    }
    
    public func insertText(text: String, app: RunningAppInfo?) async -> Result<AdapterActionResult, AdapterError> {
        KeyboardInjector.typeString(text)
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
