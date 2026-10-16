import Foundation
import AppKit

public final class DevicesWindowController: NSWindowController {
    public static let shared = DevicesWindowController()
    
    private var stackView: NSStackView!
    
    public init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 350),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Connected Mobile Devices"
        window.center()
        window.isReleasedWhenClosed = false
        super.init(window: window)
        
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        guard let contentView = window?.contentView else { return }
        
        let scrollView = NSScrollView(frame: NSRect(x: 20, y: 60, width: 360, height: 260))
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .bezelBorder
        
        stackView = NSStackView(frame: NSRect(x: 0, y: 0, width: 340, height: 250))
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 8
        scrollView.documentView = stackView
        contentView.addSubview(scrollView)
        
        let forgetBtn = NSButton(title: "Forget All Devices", target: self, action: #selector(forgetAllClicked))
        forgetBtn.frame = NSRect(x: 20, y: 15, width: 140, height: 30)
        forgetBtn.bezelStyle = .rounded
        contentView.addSubview(forgetBtn)
        
        let refreshBtn = NSButton(title: "Refresh", target: self, action: #selector(refreshDevices))
        refreshBtn.frame = NSRect(x: 280, y: 15, width: 100, height: 30)
        refreshBtn.bezelStyle = .rounded
        contentView.addSubview(refreshBtn)
    }
    
    public func showDevices() {
        refreshDevices()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc public func refreshDevices() {
        for sub in stackView.arrangedSubviews {
            stackView.removeArrangedSubview(sub)
            sub.removeFromSuperview()
        }
        
        let devices = DeviceStore.shared.getDevices()
        if devices.isEmpty {
            let emptyLabel = NSTextField(labelWithString: "No mobile devices paired yet.\nClick 'Show Pairing QR' from the menu bar to pair.")
            emptyLabel.textColor = .secondaryLabelColor
            emptyLabel.font = NSFont.systemFont(ofSize: 12)
            stackView.addArrangedSubview(emptyLabel)
            return
        }
        
        for dev in devices {
            let row = NSView(frame: NSRect(x: 0, y: 0, width: 340, height: 44))
            
            let nameLabel = NSTextField(labelWithString: "\(dev.deviceName) \(dev.isRevoked ? "(Revoked)" : "✓")")
            nameLabel.font = NSFont.boldSystemFont(ofSize: 13)
            nameLabel.frame = NSRect(x: 8, y: 22, width: 220, height: 18)
            row.addSubview(nameLabel)
            
            let idLabel = NSTextField(labelWithString: "ID: \(dev.deviceId)")
            idLabel.font = NSFont.monospacedSystemFont(ofSize: 10, weight: .regular)
            idLabel.textColor = .secondaryLabelColor
            idLabel.frame = NSRect(x: 8, y: 4, width: 220, height: 16)
            row.addSubview(idLabel)
            
            if !dev.isRevoked {
                let revokeBtn = NSButton(title: "Revoke", target: self, action: #selector(revokeClicked(_:)))
                revokeBtn.identifier = NSUserInterfaceItemIdentifier(dev.deviceId)
                revokeBtn.frame = NSRect(x: 240, y: 8, width: 85, height: 26)
                revokeBtn.bezelStyle = .inline
                row.addSubview(revokeBtn)
            }
            
            stackView.addArrangedSubview(row)
        }
    }
    
    @objc private func revokeClicked(_ sender: NSButton) {
        guard let devId = sender.identifier?.rawValue else { return }
        DeviceStore.shared.revokeDevice(deviceId: devId)
        refreshDevices()
    }
    
    @objc private func forgetAllClicked() {
        DeviceStore.shared.forgetAllDevices()
        refreshDevices()
    }
}
