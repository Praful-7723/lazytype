import Foundation
import AppKit

public struct RunningAppInfo {
    public let pid: pid_t
    public let bundleIdentifier: String
    public let localizedName: String
    public let isActive: Bool
    
    public var isZoom: Bool {
        return bundleIdentifier.lowercased().contains("zoom")
    }
    
    public var isBrowser: Bool {
        let b = bundleIdentifier.lowercased()
        return b.contains("chrome") || b.contains("safari") || b.contains("brave") || b.contains("edge") || b.contains("arc")
    }
}

public struct AppDetector {
    
    public static func getFrontmostApp() -> RunningAppInfo? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        return RunningAppInfo(
            pid: app.processIdentifier,
            bundleIdentifier: app.bundleIdentifier ?? "",
            localizedName: app.localizedName ?? "Unknown App",
            isActive: true
        )
    }
    
    public static func findApp(bundleIdSubstrings: [String]) -> RunningAppInfo? {
        let apps = NSWorkspace.shared.runningApplications
        for app in apps {
            guard let bid = app.bundleIdentifier?.lowercased() else { continue }
            if bundleIdSubstrings.contains(where: { bid.contains($0.lowercased()) }) {
                return RunningAppInfo(
                    pid: app.processIdentifier,
                    bundleIdentifier: app.bundleIdentifier ?? "",
                    localizedName: app.localizedName ?? "App",
                    isActive: app.isActive
                )
            }
        }
        return nil
    }
    
    public static func findZoomApp() -> RunningAppInfo? {
        return findApp(bundleIdSubstrings: ["us.zoom.xos", "us.zoom.ringcentral", "zoom"])
    }
}
