import Foundation
import AppKit

public final class MenuBarManager: NSObject, @unchecked Sendable {
    public static let shared = MenuBarManager()
    
    private var statusItem: NSStatusItem!
    private var menu: NSMenu!
    
    private var ipItem: NSMenuItem!
    private var phoneStatusItem: NSMenuItem!
    private var targetItem: NSMenuItem!
    private var permItem: NSMenuItem!
    private var debugItem: NSMenuItem!
    
    private var updateTimer: Timer?
    
    private override init() {
        super.init()
    }
    
    public func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.title = "⌨️ LazyType"
            button.toolTip = "LazyType - Phone Meeting Chat Remote"
        }
        
        menu = NSMenu()
        
        let headerItem = NSMenuItem(title: "LazyType Companion", action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        menu.addItem(headerItem)
        
        let ip = NetworkInterfaceHelper.getLocalIPAddress()
        let port = LocalServer.shared.port
        ipItem = NSMenuItem(title: "Server: http://\(ip):\(port)/", action: #selector(copyServerUrl), keyEquivalent: "")
        ipItem.target = self
        menu.addItem(ipItem)
        
        menu.addItem(NSMenuItem.separator())
        
        phoneStatusItem = NSMenuItem(title: "Phone: Waiting for connection...", action: nil, keyEquivalent: "")
        phoneStatusItem.isEnabled = false
        menu.addItem(phoneStatusItem)
        
        targetItem = NSMenuItem(title: "Target: Detecting...", action: nil, keyEquivalent: "")
        targetItem.isEnabled = false
        menu.addItem(targetItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let qrItem = NSMenuItem(title: "Show Pairing QR...", action: #selector(showQRClicked), keyEquivalent: "p")
        qrItem.target = self
        menu.addItem(qrItem)
        
        let demoItem = NSMenuItem(title: "Open Interactive Demo Call...", action: #selector(openDemoClicked), keyEquivalent: "d")
        demoItem.target = self
        menu.addItem(demoItem)
        
        let devicesItem = NSMenuItem(title: "Connected Devices...", action: #selector(showDevicesClicked), keyEquivalent: "")
        devicesItem.target = self
        menu.addItem(devicesItem)
        
        menu.addItem(NSMenuItem.separator())
        
        permItem = NSMenuItem(title: "Check Accessibility Permission...", action: #selector(checkPermClicked), keyEquivalent: "")
        permItem.target = self
        menu.addItem(permItem)
        
        debugItem = NSMenuItem(title: "Debug Logging: Enabled", action: #selector(toggleDebugClicked), keyEquivalent: "")
        debugItem.target = self
        menu.addItem(debugItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit LazyType", action: #selector(quitClicked), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem.menu = menu
        
        // Periodic HUD update timer
        updateTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.refreshStatus()
        }
        refreshStatus()
    }
    
    @objc public func refreshStatus() {
        Task { @MainActor in
            let status = await AdapterRegistry.shared.getCurrentStatus()
            let isPermGranted = PermissionsHelper.isAccessibilityGranted()
            
            self.targetItem.title = "Target: \(status.activeApplication) (\(status.meetingDetected ? "Meeting Active" : "Idle"))"
            
            if isPermGranted {
                self.permItem.title = "Accessibility: Granted ✓"
            } else {
                self.permItem.title = "⚠️ Grant Accessibility Permission..."
            }
            
            let devices = DeviceStore.shared.getDevices().filter { !$0.isRevoked }
            if let activeDev = devices.first {
                self.phoneStatusItem.title = "Phone: ● \(activeDev.deviceName) authorized"
            } else {
                self.phoneStatusItem.title = "Phone: ○ Waiting for pairing"
            }
        }
    }
    
    @objc private func copyServerUrl() {
        let ip = NetworkInterfaceHelper.getLocalIPAddress()
        let port = LocalServer.shared.port
        let url = "http://\(ip):\(port)/"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url, forType: .string)
    }
    
    @objc private func showQRClicked() {
        QRWindowController.shared.showQR()
    }
    
    @objc private func openDemoClicked() {
        let port = LocalServer.shared.port
        if let url = URL(string: "http://127.0.0.1:\(port)/demo") {
            NSWorkspace.shared.open(url)
        }
    }
    
    @objc private func showDevicesClicked() {
        DevicesWindowController.shared.showDevices()
    }
    
    @objc private func checkPermClicked() {
        if PermissionsHelper.isAccessibilityGranted() {
            let alert = NSAlert()
            alert.messageText = "Accessibility Permission Granted"
            alert.informativeText = "LazyType has macOS Accessibility permission and can interact with Zoom and application windows."
            alert.alertStyle = .informational
            alert.runModal()
        } else {
            PermissionsHelper.promptForAccessibilityIfNeeded()
            PermissionsHelper.openAccessibilitySettings()
        }
    }
    
    @objc private func toggleDebugClicked() {
        AppLogger.shared.isDebugEnabled.toggle()
        debugItem.title = AppLogger.shared.isDebugEnabled ? "Debug Logging: Enabled" : "Debug Logging: Disabled"
    }
    
    @objc private func quitClicked() {
        LocalServer.shared.stop()
        NSApp.terminate(nil)
    }
}
