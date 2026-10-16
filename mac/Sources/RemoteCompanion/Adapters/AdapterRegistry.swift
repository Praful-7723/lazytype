import Foundation

public final class AdapterRegistry: @unchecked Sendable {
    public static let shared = AdapterRegistry()
    
    public let zoomNativeAdapter = ZoomNativeAdapter()
    public let browserBridgeAdapter = BrowserBridgeAdapter()
    public let genericAdapter = GenericMacInputAdapter()
    
    private init() {}
    
    public func resolveAdapter(targetHint: String?) -> ApplicationAdapter {
        let frontApp = AppDetector.getFrontmostApp()
        
        switch (targetHint ?? "auto").lowercased() {
        case "zoom-native", "zoom":
            return zoomNativeAdapter
        case "zoom-web", "google-meet", "teams-web", "teams", "slack-web", "slack", "demo-chat", "browser-bridge", "browser":
            return browserBridgeAdapter
        case "generic":
            return genericAdapter
        default:
            // "auto" mode:
            // 1. If Zoom is frontmost or running with active meeting, prefer Zoom
            if zoomNativeAdapter.canHandle(app: frontApp) {
                return zoomNativeAdapter
            }
            // 2. If Chrome/Browser is active or extension has meeting, use browser
            if browserBridgeAdapter.canHandle(app: frontApp) {
                return browserBridgeAdapter
            }
            // 3. Fallback
            return genericAdapter
        }
    }
    
    public func getCurrentStatus() async -> StatusResponse {
        let frontApp = AppDetector.getFrontmostApp()
        let adapter = resolveAdapter(targetHint: "auto")
        let state = await adapter.getState(app: frontApp)
        
        return StatusResponse(
            requestId: nil,
            macName: NetworkInterfaceHelper.getMacComputerName(),
            activeApplication: state.activeApplication,
            adapter: state.adapterId,
            meetingDetected: state.meetingDetected,
            chatAvailable: state.chatAvailable,
            chatOpen: state.chatOpen,
            canSendMessage: state.canSendMessage,
            canMute: state.canMute,
            canControlCamera: state.canControlCamera,
            isMuted: state.isMuted,
            browserExtensionConnected: browserBridgeAdapter.isExtensionConnected
        )
    }
}
