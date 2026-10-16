import Foundation

public struct AdapterState: Sendable {
    public let adapterId: String
    public let activeApplication: String
    public let meetingDetected: Bool
    public let chatAvailable: Bool
    public let chatOpen: Bool
    public let canSendMessage: Bool
    public let canMute: Bool
    public let canControlCamera: Bool
    public let isMuted: Bool
    
    public init(
        adapterId: String,
        activeApplication: String,
        meetingDetected: Bool,
        chatAvailable: Bool,
        chatOpen: Bool,
        canSendMessage: Bool = true,
        canMute: Bool = false,
        canControlCamera: Bool = false,
        isMuted: Bool = false
    ) {
        self.adapterId = adapterId
        self.activeApplication = activeApplication
        self.meetingDetected = meetingDetected
        self.chatAvailable = chatAvailable
        self.chatOpen = chatOpen
        self.canSendMessage = canSendMessage
        self.canMute = canMute
        self.canControlCamera = canControlCamera
        self.isMuted = isMuted
    }
}

public struct AdapterActionResult: Sendable {
    public let success: Bool
    public let adapterId: String
    public let action: String
    public let message: String
    
    public init(success: Bool, adapterId: String, action: String, message: String) {
        self.success = success
        self.adapterId = adapterId
        self.action = action
        self.message = message
    }
}

public enum AdapterError: Error, Sendable {
    case appNotRunning(String)
    case meetingNotActive
    case chatNotFound
    case inputNotFound
    case sendFailed
    case permissionRequired
    case unsupportedAction(String)
    case custom(String)
    
    public var code: String {
        switch self {
        case .appNotRunning: return "APP_NOT_RUNNING"
        case .meetingNotActive: return "MEETING_NOT_ACTIVE"
        case .chatNotFound: return "CHAT_NOT_FOUND"
        case .inputNotFound: return "INPUT_NOT_FOUND"
        case .sendFailed: return "SEND_BUTTON_NOT_FOUND"
        case .permissionRequired: return "PERMISSION_REQUIRED"
        case .unsupportedAction: return "UNSUPPORTED_ACTION"
        case .custom(let msg): return msg
        }
    }
    
    public var localizedDescription: String {
        switch self {
        case .appNotRunning(let app): return "\(app) is not currently running."
        case .meetingNotActive: return "No active call or meeting was detected."
        case .chatNotFound: return "Chat button or panel could not be located."
        case .inputNotFound: return "Chat message input field could not be located."
        case .sendFailed: return "Could not trigger message send action."
        case .permissionRequired: return "macOS Accessibility permission is required."
        case .unsupportedAction(let act): return "Action '\(act)' is not supported by this adapter."
        case .custom(let msg): return msg
        }
    }
}

public protocol ApplicationAdapter: Sendable {
    var adapterId: String { get }
    var displayName: String { get }
    
    func canHandle(app: RunningAppInfo?) -> Bool
    func getState(app: RunningAppInfo?) async -> AdapterState
    func sendMessage(text: String, app: RunningAppInfo?) async -> Result<AdapterActionResult, AdapterError>
    func insertText(text: String, app: RunningAppInfo?) async -> Result<AdapterActionResult, AdapterError>
    func openChat(app: RunningAppInfo?) async -> Result<AdapterActionResult, AdapterError>
    func toggleMute(app: RunningAppInfo?) async -> Result<AdapterActionResult, AdapterError>
    func toggleCamera(app: RunningAppInfo?) async -> Result<AdapterActionResult, AdapterError>
    func pressKey(key: String, modifiers: [String], app: RunningAppInfo?) async -> Result<AdapterActionResult, AdapterError>
}
