import Foundation
import AppKit

public final class LaunchAtLoginHelper: @unchecked Sendable {
    public static let shared = LaunchAtLoginHelper()
    
    private let plistLabel = "com.lazytype.companion"
    private var plistURL: URL {
        let libraryDir = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
        let launchAgentsDir = libraryDir.appendingPathComponent("LaunchAgents")
        try? FileManager.default.createDirectory(at: launchAgentsDir, withIntermediateDirectories: true)
        return launchAgentsDir.appendingPathComponent("\(plistLabel).plist")
    }
    
    private init() {}
    
    public var isLaunchAtLoginEnabled: Bool {
        return FileManager.default.fileExists(atPath: plistURL.path)
    }
    
    public func setLaunchAtLogin(enabled: Bool) {
        if enabled {
            enableLaunchAtLogin()
        } else {
            disableLaunchAtLogin()
        }
    }
    
    private func enableLaunchAtLogin() {
        // Find path to LazyType application executable
        var execPath = Bundle.main.executablePath ?? ""
        if execPath.isEmpty || !FileManager.default.fileExists(atPath: execPath) {
            execPath = "/Volumes/ExternalSSD/Projects/lazytype/dist/LazyType.app/Contents/MacOS/LazyType"
        }
        
        let plistContent: [String: Any] = [
            "Label": plistLabel,
            "ProgramArguments": [execPath],
            "RunAtLoad": true,
            "KeepAlive": false,
            "ProcessType": "Interactive"
        ]
        
        if let data = try? PropertyListSerialization.data(fromPropertyList: plistContent, format: .xml, options: 0) {
            try? data.write(to: plistURL)
            AppLogger.shared.log("Launch at login enabled: \(plistURL.path)")
        }
    }
    
    private func disableLaunchAtLogin() {
        try? FileManager.default.removeItem(at: plistURL)
        AppLogger.shared.log("Launch at login disabled")
    }
}
