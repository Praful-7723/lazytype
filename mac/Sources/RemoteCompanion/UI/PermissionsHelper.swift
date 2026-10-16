import Foundation
import AppKit
import ApplicationServices

public struct PermissionsHelper {
    public static func isAccessibilityGranted() -> Bool {
        return AXIsProcessTrusted()
    }
    
    public static func openAccessibilitySettings() {
        // macOS Sonoma / Ventura / Monterey URL scheme
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
    
    public static func promptForAccessibilityIfNeeded() {
        if !isAccessibilityGranted() {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
        }
    }
}
