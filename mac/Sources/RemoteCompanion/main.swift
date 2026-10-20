import Foundation
import AppKit

// MARK: - Application Delegate
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        setbuf(stdout, nil)
        AppLogger.shared.log("LazyType Mac Remote Companion started")
        
        // Parse custom port if provided
        var port: UInt16 = 9123
        let args = CommandLine.arguments
        if let idx = args.firstIndex(of: "--port"), idx + 1 < args.count, let customPort = UInt16(args[idx + 1]) {
            port = customPort
        }
        
        do {
            try LocalServer.shared.start(port: port)
        } catch {
            AppLogger.shared.error("Failed to start local server on port \(port): \(error)")
        }
        
        // Check accessibility
        if !PermissionsHelper.isAccessibilityGranted() {
            AppLogger.shared.log("Notice: Accessibility permission not yet granted.")
        } else {
            AppLogger.shared.log("Accessibility permission is active ✓")
        }
        
        // Setup menu bar item
        MenuBarManager.shared.setup()
        
        // Show onboarding automatically if incomplete, permissions missing, or extension not connected
        let hasCompleted = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding_v2")
        let isAccessibilityGranted = PermissionsHelper.isAccessibilityGranted()
        let isExtensionConnected = AdapterRegistry.shared.browserBridgeAdapter.isExtensionConnected
        
        if !hasCompleted || !isAccessibilityGranted || !isExtensionConnected {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                OnboardingWindowController.shared.show()
            }
        }
        
        // Print pairing info to console for easy developer access
        let pairUrl = PairingManager.shared.getPairingURL(port: Int(port))
        print("----------------------------------------------------------------")
        print("  ⌨️  LazyType Mac Companion Active")
        print("  Local IP: \(NetworkInterfaceHelper.getLocalIPAddress())")
        print("  Pairing URL: \(pairUrl)")
        print("  Interactive Demo: http://127.0.0.1:\(port)/demo")
        print("----------------------------------------------------------------")
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        AppLogger.shared.log("Reopen triggered from Finder/Dock. Showing Onboarding guide...")
        OnboardingWindowController.shared.show()
        return true
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        AppLogger.shared.log("LazyType Mac Companion shutting down")
        LocalServer.shared.stop()
    }
}

// MARK: - Application Entry Point
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory) // Menu bar accessory app

// Signal handling for clean exit
signal(SIGINT) { _ in
    LocalServer.shared.stop()
    exit(0)
}
signal(SIGTERM) { _ in
    LocalServer.shared.stop()
    exit(0)
}

app.run()
