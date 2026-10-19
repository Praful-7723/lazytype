import Foundation

public final class BrowserBridgeAdapter: ApplicationAdapter, @unchecked Sendable {
    public let adapterId = "browser-bridge"
    public let displayName = "Browser Video Call (Extension)"
    
    // Reference to local server extension sender
    public var sendCommandToExtension: ((_ cmd: ExtensionCommandRequest, _ completion: @escaping @Sendable (CommandResultResponse) -> Void) -> Void)?
    
    // Cached extension state
    public var lastReportedState: IncomingMessage?
    public var isExtensionConnected: Bool = false
    
    public init() {}
    
    public func canHandle(app: RunningAppInfo?) -> Bool {
        if let app = app, app.isBrowser { return true }
        return isExtensionConnected && (lastReportedState?.meetingDetected == true)
    }
    
    public func getState(app: RunningAppInfo?) async -> AdapterState {
        let isMeeting = lastReportedState?.meetingDetected ?? false
        let isChatOpen = lastReportedState?.chatOpen ?? false
        let isChatAvailable = lastReportedState?.chatAvailable ?? isMeeting
        let currentSubAdapter = lastReportedState?.adapter ?? "Browser Tab"
        let targetName = lastReportedState?.targetName ?? (isMeeting ? "Video Call Chat" : "Web Input")
        
        return AdapterState(
            adapterId: currentSubAdapter,
            activeApplication: isExtensionConnected ? targetName : "Browser (Extension Disconnected)",
            meetingDetected: isMeeting,
            chatAvailable: isExtensionConnected && isChatAvailable,
            chatOpen: isExtensionConnected && isChatOpen,
            canSendMessage: isExtensionConnected && isChatAvailable,
            canMute: lastReportedState?.canMute ?? false,
            canControlCamera: lastReportedState?.canControlCamera ?? false
        )
    }
    
    private func executeViaExtension(action: String, target: String? = nil, text: String? = nil, key: String? = nil, modifiers: [String]? = nil) async -> Result<AdapterActionResult, AdapterError> {
        guard isExtensionConnected, let sender = sendCommandToExtension else {
            return .failure(.custom("Browser extension is not connected to Mac Companion"))
        }
        
        let requestId = "ext_req_" + UUID().uuidString
        let request = ExtensionCommandRequest(
            requestId: requestId,
            action: action,
            target: target,
            text: text,
            key: key,
            modifiers: modifiers
        )
        
        return await withCheckedContinuation { continuation in
            sender(request) { response in
                if response.success {
                    continuation.resume(returning: .success(AdapterActionResult(
                        success: true,
                        adapterId: response.target ?? self.adapterId,
                        action: action,
                        message: response.message ?? "Action completed in browser ✓"
                    )))
                } else {
                    let errCode = response.errorCode ?? "BROWSER_ACTION_FAILED"
                    let msg = response.message ?? errCode
                    continuation.resume(returning: .failure(.custom(msg)))
                }
            }
        }
    }
    
    public func sendMessage(text: String, app: RunningAppInfo?) async -> Result<AdapterActionResult, AdapterError> {
        return await executeViaExtension(action: "SEND_MESSAGE", text: text)
    }
    
    public func insertText(text: String, app: RunningAppInfo?) async -> Result<AdapterActionResult, AdapterError> {
        return await executeViaExtension(action: "INSERT_TEXT", text: text)
    }
    
    public func openChat(app: RunningAppInfo?) async -> Result<AdapterActionResult, AdapterError> {
        return await executeViaExtension(action: "OPEN_CHAT")
    }
    
    public func toggleMute(app: RunningAppInfo?) async -> Result<AdapterActionResult, AdapterError> {
        return await executeViaExtension(action: "TOGGLE_MUTE")
    }
    
    public func toggleCamera(app: RunningAppInfo?) async -> Result<AdapterActionResult, AdapterError> {
        return await executeViaExtension(action: "TOGGLE_CAMERA")
    }
    
    public func pressKey(key: String, modifiers: [String], app: RunningAppInfo?) async -> Result<AdapterActionResult, AdapterError> {
        return await executeViaExtension(action: "PRESS_KEY", key: key, modifiers: modifiers)
    }
}
