import Foundation
import AppKit

public final class DevicesWindowController: NSWindowController {
    public static let shared = DevicesWindowController()
    
    private var visualEffectView: NSVisualEffectView!
    private var stackView: NSStackView!
    private var scrollView: NSScrollView!
    
    public init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 480),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Connected Mobile Devices"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        
        // CRITICAL FOR TRUE TRANSLUCENCY / BEHIND-WINDOW REFRACTION
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.center()
        window.isReleasedWhenClosed = false
        
        super.init(window: window)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        guard let window = self.window else { return }
        
        visualEffectView = NSVisualEffectView(frame: window.contentLayoutRect)
        visualEffectView.material = .popover
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.appearance = NSAppearance(named: .vibrantLight)
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = 26
        visualEffectView.layer?.masksToBounds = true
        visualEffectView.layer?.borderWidth = 1.2
        visualEffectView.layer?.borderColor = NSColor(white: 1.0, alpha: 0.85).cgColor
        visualEffectView.layer?.backgroundColor = NSColor(white: 0.96, alpha: 0.90).cgColor
        window.contentView = visualEffectView
        
        let container = NSView(frame: NSRect(x: 24, y: 20, width: 392, height: 436))
        visualEffectView.addSubview(container)
        
        // Header
        let iconBadge = NSView(frame: NSRect(x: 0, y: 384, width: 44, height: 44))
        iconBadge.wantsLayer = true
        iconBadge.layer?.cornerRadius = 14
        iconBadge.layer?.cornerCurve = .continuous
        iconBadge.layer?.backgroundColor = NSColor.black.cgColor
        iconBadge.layer?.shadowColor = NSColor.black.cgColor
        iconBadge.layer?.shadowOpacity = 0.15
        iconBadge.layer?.shadowRadius = 8
        iconBadge.layer?.shadowOffset = CGSize(width: 0, height: -2)
        
        let mascotImg = NSImageView(frame: NSRect(x: 6, y: 6, width: 32, height: 32))
        mascotImg.image = VectorIcons.mascot(size: NSSize(width: 32, height: 32))
        iconBadge.addSubview(mascotImg)
        container.addSubview(iconBadge)
        
        let titleLabel = NSTextField(labelWithString: "Paired Devices")
        titleLabel.font = NSFont.systemFont(ofSize: 22, weight: .bold)
        titleLabel.textColor = NSColor.black
        titleLabel.frame = NSRect(x: 56, y: 402, width: 300, height: 26)
        container.addSubview(titleLabel)
        
        let subtitleLabel = NSTextField(labelWithString: "Phones authorized to type onto this Mac")
        subtitleLabel.font = NSFont.systemFont(ofSize: 12.5, weight: .medium)
        subtitleLabel.textColor = NSColor(white: 0.45, alpha: 1.0)
        subtitleLabel.frame = NSRect(x: 56, y: 384, width: 320, height: 18)
        container.addSubview(subtitleLabel)
        
        // Devices List ScrollView
        scrollView = NSScrollView(frame: NSRect(x: 0, y: 56, width: 392, height: 308))
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        
        let clipView = NSClipView(frame: scrollView.bounds)
        clipView.drawsBackground = false
        scrollView.contentView = clipView
        
        stackView = NSStackView(frame: NSRect(x: 0, y: 0, width: 392, height: 308))
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 10
        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = stackView
        
        container.addSubview(scrollView)
        
        // Bottom Action Bar
        let forgetBtn = createGlassButton(title: "Disconnect All", isDestructive: true)
        forgetBtn.frame = NSRect(x: 0, y: 8, width: 140, height: 38)
        forgetBtn.target = self
        forgetBtn.action = #selector(forgetAllClicked)
        container.addSubview(forgetBtn)
        
        let doneBtn = InteractiveObsidianButton(frame: NSRect(x: 272, y: 8, width: 120, height: 38))
        doneBtn.onClick = { [weak self] in
            self?.doneClicked()
        }
        
        let doneLabel = NSTextField(labelWithString: "Done")
        doneLabel.font = NSFont.systemFont(ofSize: 13.5, weight: .bold)
        doneLabel.textColor = .white
        doneLabel.alignment = .center
        doneLabel.frame = NSRect(x: 0, y: 9, width: 120, height: 20)
        doneBtn.addSubview(doneLabel)
        container.addSubview(doneBtn)
    }
    
    private func createGlassButton(title: String, isDestructive: Bool) -> NSButton {
        let btn = NSButton(title: title, target: nil, action: nil)
        btn.bezelStyle = .regularSquare
        btn.isBordered = false
        btn.wantsLayer = true
        btn.layer?.cornerRadius = 14
        btn.layer?.cornerCurve = .continuous
        btn.layer?.masksToBounds = true
        
        if isDestructive {
            btn.layer?.backgroundColor = NSColor(white: 0.94, alpha: 0.95).cgColor
            btn.layer?.borderWidth = 1.0
            btn.layer?.borderColor = NSColor(white: 0.0, alpha: 0.08).cgColor
            btn.contentTintColor = NSColor(red: 0.85, green: 0.15, blue: 0.22, alpha: 1.0)
        } else {
            btn.layer?.backgroundColor = NSColor.white.cgColor
            btn.layer?.borderWidth = 1.0
            btn.layer?.borderColor = NSColor(white: 0.0, alpha: 0.08).cgColor
            btn.contentTintColor = NSColor.black
        }
        btn.font = NSFont.systemFont(ofSize: 13, weight: .bold)
        return btn
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
            let emptyCard = NSView(frame: NSRect(x: 0, y: 0, width: 392, height: 130))
            emptyCard.wantsLayer = true
            emptyCard.layer?.cornerRadius = 18
            emptyCard.layer?.cornerCurve = .continuous
            emptyCard.layer?.backgroundColor = NSColor.white.cgColor
            emptyCard.layer?.borderWidth = 1.0
            emptyCard.layer?.borderColor = NSColor(white: 0.0, alpha: 0.08).cgColor
            emptyCard.layer?.shadowColor = NSColor.black.cgColor
            emptyCard.layer?.shadowOpacity = 0.04
            emptyCard.layer?.shadowRadius = 8
            emptyCard.layer?.shadowOffset = CGSize(width: 0, height: -2)
            
            let emptyIcon = NSImageView(frame: NSRect(x: 182, y: 76, width: 28, height: 28))
            emptyIcon.image = VectorIcons.smartphone(size: NSSize(width: 28, height: 28), color: NSColor(white: 0.35, alpha: 1.0))
            emptyCard.addSubview(emptyIcon)
            
            let emptyTitle = NSTextField(labelWithString: "No Devices Paired Yet")
            emptyTitle.font = NSFont.systemFont(ofSize: 14, weight: .bold)
            emptyTitle.textColor = NSColor.black
            emptyTitle.alignment = .center
            emptyTitle.frame = NSRect(x: 20, y: 46, width: 352, height: 20)
            emptyCard.addSubview(emptyTitle)
            
            let emptySub = NSTextField(labelWithString: "Click 'Pair Phone' from the menu bar to pair your phone.")
            emptySub.font = NSFont.systemFont(ofSize: 12, weight: .medium)
            emptySub.textColor = NSColor(white: 0.45, alpha: 1.0)
            emptySub.alignment = .center
            emptySub.frame = NSRect(x: 20, y: 20, width: 352, height: 18)
            emptyCard.addSubview(emptySub)
            
            stackView.addArrangedSubview(emptyCard)
            emptyCard.widthAnchor.constraint(equalToConstant: 392).isActive = true
            emptyCard.heightAnchor.constraint(equalToConstant: 130).isActive = true
            return
        }
        
        for dev in devices {
            let card = NSView(frame: NSRect(x: 0, y: 0, width: 392, height: 68))
            card.wantsLayer = true
            card.layer?.cornerRadius = 16
            card.layer?.cornerCurve = .continuous
            card.layer?.backgroundColor = NSColor.white.cgColor
            card.layer?.borderWidth = 1.0
            card.layer?.borderColor = NSColor(white: 0.0, alpha: 0.08).cgColor
            card.layer?.shadowColor = NSColor.black.cgColor
            card.layer?.shadowOpacity = 0.04
            card.layer?.shadowRadius = 8
            card.layer?.shadowOffset = CGSize(width: 0, height: -2)
            
            // Status Dot
            let dot = NSView(frame: NSRect(x: 16, y: 29, width: 10, height: 10))
            dot.wantsLayer = true
            dot.layer?.cornerRadius = 5
            if dev.isRevoked {
                dot.layer?.backgroundColor = NSColor(red: 0.95, green: 0.35, blue: 0.35, alpha: 1.0).cgColor
            } else {
                dot.layer?.backgroundColor = NSColor(red: 0.10, green: 0.85, blue: 0.50, alpha: 1.0).cgColor
                dot.layer?.shadowColor = NSColor(red: 0.10, green: 0.85, blue: 0.50, alpha: 0.5).cgColor
                dot.layer?.shadowRadius = 4
                dot.layer?.shadowOpacity = 0.8
            }
            card.addSubview(dot)
            
            // Device Name
            let nameLabel = NSTextField(labelWithString: dev.deviceName)
            nameLabel.font = NSFont.systemFont(ofSize: 14, weight: .bold)
            nameLabel.textColor = NSColor.black
            nameLabel.frame = NSRect(x: 36, y: 35, width: 238, height: 20)
            card.addSubview(nameLabel)
            
            // Subtitle
            let subText = dev.isRevoked ? "Access Revoked" : "Wi-Fi Connected • Ready to type"
            let subLabel = NSTextField(labelWithString: subText)
            subLabel.font = NSFont.systemFont(ofSize: 11.5, weight: .medium)
            subLabel.textColor = dev.isRevoked ? NSColor(red: 0.85, green: 0.20, blue: 0.25, alpha: 1.0) : NSColor(white: 0.45, alpha: 1.0)
            subLabel.frame = NSRect(x: 36, y: 15, width: 238, height: 16)
            card.addSubview(subLabel)
            
            if !dev.isRevoked {
                let revokeBtn = createGlassButton(title: "Revoke", isDestructive: true)
                revokeBtn.identifier = NSUserInterfaceItemIdentifier(dev.deviceId)
                revokeBtn.frame = NSRect(x: 288, y: 18, width: 88, height: 32)
                revokeBtn.target = self
                revokeBtn.action = #selector(revokeClicked(_:))
                card.addSubview(revokeBtn)
            }
            
            stackView.addArrangedSubview(card)
            card.widthAnchor.constraint(equalToConstant: 392).isActive = true
            card.heightAnchor.constraint(equalToConstant: 68).isActive = true
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
    
    @objc private func doneClicked() {
        window?.orderOut(nil)
    }
}
