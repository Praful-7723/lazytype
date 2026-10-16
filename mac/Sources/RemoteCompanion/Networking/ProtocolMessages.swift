import Foundation

// MARK: - Incoming from Phone or Extension
public struct IncomingMessage: Codable {
    public let type: String
    public let requestId: String?
    
    // Auth & Pairing
    public let token: String?
    public let sessionToken: String?
    public let deviceId: String?
    public let deviceName: String?
    
    // Commands
    public let target: String?
    public let text: String?
    public let key: String?
    public let modifiers: [String]?
    
    // Extension specific
    public let tabId: Int?
    public let url: String?
    public let adapter: String?
    public let meetingDetected: Bool?
    public let chatOpen: Bool?
    public let chatAvailable: Bool?
    public let canSendMessage: Bool?
    public let canMute: Bool?
    public let canControlCamera: Bool?
    public let success: Bool?
    public let errorCode: String?
    public let message: String?
}

// MARK: - Outgoing Responses to Phone
public struct StatusResponse: Codable {
    public var type: String = "STATUS_UPDATE"
    public let requestId: String?
    public let macName: String
    public let activeApplication: String
    public let adapter: String
    public let meetingDetected: Bool
    public let chatAvailable: Bool
    public let chatOpen: Bool
    public let canSendMessage: Bool
    public let canMute: Bool
    public let canControlCamera: Bool
    public let isMuted: Bool
    public let browserExtensionConnected: Bool
    
    public init(
        requestId: String? = nil,
        macName: String,
        activeApplication: String,
        adapter: String,
        meetingDetected: Bool,
        chatAvailable: Bool,
        chatOpen: Bool,
        canSendMessage: Bool,
        canMute: Bool,
        canControlCamera: Bool,
        isMuted: Bool = false,
        browserExtensionConnected: Bool
    ) {
        self.requestId = requestId
        self.macName = macName
        self.activeApplication = activeApplication
        self.adapter = adapter
        self.meetingDetected = meetingDetected
        self.chatAvailable = chatAvailable
        self.chatOpen = chatOpen
        self.canSendMessage = canSendMessage
        self.canMute = canMute
        self.canControlCamera = canControlCamera
        self.isMuted = isMuted
        self.browserExtensionConnected = browserExtensionConnected
    }
}

public struct CommandResultResponse: Codable {
    public var type: String = "COMMAND_RESULT"
    public let requestId: String?
    public let success: Bool
    public let target: String?
    public let action: String?
    public let errorCode: String?
    public let message: String?
    
    public init(
        requestId: String?,
        success: Bool,
        target: String? = nil,
        action: String? = nil,
        errorCode: String? = nil,
        message: String? = nil
    ) {
        self.requestId = requestId
        self.success = success
        self.target = target
        self.action = action
        self.errorCode = errorCode
        self.message = message
    }
}

public struct PairResultResponse: Codable {
    public var type: String = "PAIR_RESULT"
    public let requestId: String?
    public let success: Bool
    public let sessionToken: String?
    public let macName: String?
    public let errorCode: String?
    public let message: String?
    
    public init(
        requestId: String?,
        success: Bool,
        sessionToken: String? = nil,
        macName: String? = nil,
        errorCode: String? = nil,
        message: String? = nil
    ) {
        self.requestId = requestId
        self.success = success
        self.sessionToken = sessionToken
        self.macName = macName
        self.errorCode = errorCode
        self.message = message
    }
}

public struct AuthResultResponse: Codable {
    public var type: String = "AUTH_RESULT"
    public let requestId: String?
    public let success: Bool
    public let macName: String?
    public let errorCode: String?
    public let message: String?
    
    public init(
        requestId: String?,
        success: Bool,
        macName: String? = nil,
        errorCode: String? = nil,
        message: String? = nil
    ) {
        self.requestId = requestId
        self.success = success
        self.macName = macName
        self.errorCode = errorCode
        self.message = message
    }
}

// MARK: - Outgoing to Extension
public struct ExtensionCommandRequest: Codable {
    public var type: String = "EXECUTE_COMMAND"
    public let requestId: String
    public let action: String
    public let target: String?
    public let text: String?
    public let key: String?
    public let modifiers: [String]?
    
    public init(
        requestId: String,
        action: String,
        target: String? = nil,
        text: String? = nil,
        key: String? = nil,
        modifiers: [String]? = nil
    ) {
        self.requestId = requestId
        self.action = action
        self.target = target
        self.text = text
        self.key = key
        self.modifiers = modifiers
    }
}
