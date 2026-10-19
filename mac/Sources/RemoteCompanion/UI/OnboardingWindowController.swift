import Foundation
import AppKit

public final class OnboardingWindowController: NSWindowController {
    public static let shared = OnboardingWindowController()
    
    private var visualEffectView: NSVisualEffectView!
    private var permStatusPill: NSTextField!
    private var permButton: InteractiveObsidianButton!
    private var extStatusDot: NSView!
    private var extStatusLabel: NSTextField!
    private var statusTimer: Timer?
    private var startupCheckbox: NSButton!
    
    public init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 600),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome to LazyType"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.center()
        window.isReleasedWhenClosed = false
        
        super.init(window: window)
        setupUI()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    public func show() {
        refreshState()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        statusTimer?.invalidate()
        statusTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.refreshState()
        }
    }
    
    public override func close() {
        statusTimer?.invalidate()
        statusTimer = nil
        super.close()
    }
    
    private func setupUI() {
        guard let window = self.window else { return }
        
        visualEffectView = NSVisualEffectView(frame: window.contentView!.bounds)
        visualEffectView.material = .popover
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.autoresizingMask = [.width, .height]
        window.contentView = visualEffectView
        
        let container = FlippedView(frame: NSRect(x: 24, y: 24, width: 472, height: 552))
        
        // --- 1. Header: Mascot Squircle + Title + Subtitle ---
        let mascotSquircle = NSView(frame: NSRect(x: 0, y: 0, width: 48, height: 48))
        mascotSquircle.wantsLayer = true
        mascotSquircle.layer?.cornerRadius = 14
        mascotSquircle.layer?.cornerCurve = .continuous
        mascotSquircle.layer?.backgroundColor = NSColor(white: 0.95, alpha: 0.95).cgColor
        mascotSquircle.layer?.borderWidth = 1.0
        mascotSquircle.layer?.borderColor = NSColor(white: 0.0, alpha: 0.08).cgColor
        
        let mascotImg = NSImageView(frame: NSRect(x: 6, y: 6, width: 36, height: 36))
        mascotImg.image = VectorIcons.mascot(size: NSSize(width: 36, height: 36))
        mascotSquircle.addSubview(mascotImg)
        container.addSubview(mascotSquircle)
        
        let titleLabel = NSTextField(labelWithString: "Welcome to LazyType")
        titleLabel.font = NSFont.systemFont(ofSize: 20, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.frame = NSRect(x: 60, y: 2, width: 380, height: 26)
        container.addSubview(titleLabel)
        
        let subtitleLabel = NSTextField(labelWithString: "Remote Companion Setup • Follow these 2 quick steps to start")
        subtitleLabel.font = NSFont.systemFont(ofSize: 12.5, weight: .medium)
        subtitleLabel.textColor = NSColor(white: 0.75, alpha: 1.0)
        subtitleLabel.frame = NSRect(x: 60, y: 28, width: 410, height: 18)
        container.addSubview(subtitleLabel)
        
        // --- 2. Step 1 Card: macOS Accessibility Permission ---
        let step1Card = createCardView(frame: NSRect(x: 0, y: 66, width: 472, height: 120))
        
        let step1Title = NSTextField(labelWithString: "Step 1: macOS Accessibility Permission")
        step1Title.font = NSFont.systemFont(ofSize: 13.5, weight: .bold)
        step1Title.textColor = .white
        step1Title.frame = NSRect(x: 16, y: 14, width: 310, height: 20)
        step1Card.addSubview(step1Title)
        
        permStatusPill = NSTextField(labelWithString: "Checking...")
        permStatusPill.font = NSFont.systemFont(ofSize: 11, weight: .bold)
        permStatusPill.alignment = .center
        permStatusPill.wantsLayer = true
        permStatusPill.layer?.cornerRadius = 8
        permStatusPill.frame = NSRect(x: 340, y: 14, width: 116, height: 22)
        step1Card.addSubview(permStatusPill)
        
        let step1Desc = NSTextField(wrappingLabelWithString: "Required to send keystrokes into active applications and Zoom. Click below to grant permission in System Settings.")
        step1Desc.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        step1Desc.textColor = NSColor(white: 0.70, alpha: 1.0)
        step1Desc.frame = NSRect(x: 16, y: 40, width: 440, height: 34)
        step1Card.addSubview(step1Desc)
        
        permButton = InteractiveObsidianButton(frame: NSRect(x: 16, y: 80, width: 220, height: 30))
        let permLabel = NSTextField(labelWithString: "Open System Settings")
        permLabel.font = NSFont.systemFont(ofSize: 12, weight: .bold)
        permLabel.textColor = .white
        permLabel.alignment = .center
        permLabel.frame = NSRect(x: 0, y: 6, width: 220, height: 18)
        permButton.addSubview(permLabel)
        permButton.onClick = { [weak self] in
            PermissionsHelper.promptForAccessibilityIfNeeded()
            PermissionsHelper.openAccessibilitySettings()
            self?.refreshState()
        }
        step1Card.addSubview(permButton)
        container.addSubview(step1Card)
        
        // --- 3. Step 2 Card: Chrome Extension Setup ---
        let step2Card = createCardView(frame: NSRect(x: 0, y: 198, width: 472, height: 205))
        
        let step2Title = NSTextField(labelWithString: "Step 2: Install Chrome Extension (10 seconds)")
        step2Title.font = NSFont.systemFont(ofSize: 13.5, weight: .bold)
        step2Title.textColor = .white
        step2Title.frame = NSRect(x: 16, y: 14, width: 330, height: 20)
        step2Card.addSubview(step2Title)
        
        // Real-time status dot & label
        extStatusDot = NSView(frame: NSRect(x: 350, y: 19, width: 8, height: 8))
        extStatusDot.wantsLayer = true
        extStatusDot.layer?.cornerRadius = 4
        extStatusDot.layer?.backgroundColor = NSColor.gray.cgColor
        step2Card.addSubview(extStatusDot)
        
        extStatusLabel = NSTextField(labelWithString: "Not Connected")
        extStatusLabel.font = NSFont.systemFont(ofSize: 11, weight: .bold)
        extStatusLabel.textColor = NSColor(white: 0.60, alpha: 1.0)
        extStatusLabel.frame = NSRect(x: 364, y: 14, width: 95, height: 18)
        step2Card.addSubview(extStatusLabel)
        
        let step2Desc = NSTextField(wrappingLabelWithString: "Required to route keystrokes into Google Meet, Zoom Web, Teams, and browser tabs. Click the button below:")
        step2Desc.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        step2Desc.textColor = NSColor(white: 0.70, alpha: 1.0)
        step2Desc.frame = NSRect(x: 16, y: 38, width: 440, height: 32)
        step2Card.addSubview(step2Desc)
        
        let installExtBtn = InteractiveObsidianButton(frame: NSRect(x: 16, y: 76, width: 280, height: 32))
        let extBtnLabel = NSTextField(labelWithString: "1. Open Chrome & Reveal Extension Folder")
        extBtnLabel.font = NSFont.systemFont(ofSize: 12, weight: .bold)
        extBtnLabel.textColor = .white
        extBtnLabel.alignment = .center
        extBtnLabel.frame = NSRect(x: 0, y: 7, width: 280, height: 18)
        installExtBtn.addSubview(extBtnLabel)
        installExtBtn.onClick = { [weak self] in
            self?.openChromeAndRevealExtension()
        }
        step2Card.addSubview(installExtBtn)
        
        let instructionBox = NSView(frame: NSRect(x: 16, y: 118, width: 440, height: 75))
        instructionBox.wantsLayer = true
        instructionBox.layer?.cornerRadius = 10
        instructionBox.layer?.backgroundColor = NSColor(white: 0.08, alpha: 0.6).cgColor
        instructionBox.layer?.borderWidth = 1.0
        instructionBox.layer?.borderColor = NSColor(white: 1.0, alpha: 0.08).cgColor
        
        let instrText = NSTextField(wrappingLabelWithString: "How to drop it in:\n• Step A: In Chrome, turn ON 'Developer mode' (top-right toggle).\n• Step B: Drag the highlighted 'extension' folder directly into Chrome.\nDone! The status dot above will instantly turn green ✓.")
        instrText.font = NSFont.systemFont(ofSize: 11.5, weight: .medium)
        instrText.textColor = NSColor(white: 0.85, alpha: 1.0)
        instrText.frame = NSRect(x: 12, y: 8, width: 416, height: 60)
        instructionBox.addSubview(instrText)
        step2Card.addSubview(instructionBox)
        
        container.addSubview(step2Card)
        
        // --- 4. Step 3 Card: Connect Phone ---
        let step3Card = createCardView(frame: NSRect(x: 0, y: 415, width: 472, height: 85))
        
        let step3Title = NSTextField(labelWithString: "Step 3: Connect Your Phone")
        step3Title.font = NSFont.systemFont(ofSize: 13.5, weight: .bold)
        step3Title.textColor = .white
        step3Title.frame = NSRect(x: 16, y: 14, width: 250, height: 20)
        step3Card.addSubview(step3Title)
        
        let step3Desc = NSTextField(labelWithString: "Scan the QR code with your phone camera on the same Wi-Fi network.")
        step3Desc.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        step3Desc.textColor = NSColor(white: 0.70, alpha: 1.0)
        step3Desc.frame = NSRect(x: 16, y: 38, width: 440, height: 18)
        step3Card.addSubview(step3Desc)
        
        let qrBtn = InteractiveObsidianButton(frame: NSRect(x: 320, y: 12, width: 136, height: 30))
        let qrLabel = NSTextField(labelWithString: "Show QR Code")
        qrLabel.font = NSFont.systemFont(ofSize: 12, weight: .bold)
        qrLabel.textColor = .white
        qrLabel.alignment = .center
        qrLabel.frame = NSRect(x: 0, y: 6, width: 136, height: 18)
        qrBtn.addSubview(qrLabel)
        qrBtn.onClick = {
            QRWindowController.shared.showQR()
        }
        step3Card.addSubview(qrBtn)
        container.addSubview(step3Card)
        
        // --- 5. Footer: Startup Checkbox & Done Button ---
        let footerRow = FlippedView(frame: NSRect(x: 0, y: 512, width: 472, height: 40))
        
        startupCheckbox = NSButton(checkboxWithTitle: "Launch at Startup", target: self, action: #selector(toggleStartup))
        startupCheckbox.state = LaunchAtLoginHelper.shared.isLaunchAtLoginEnabled ? .on : .off
        startupCheckbox.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        startupCheckbox.frame = NSRect(x: 0, y: 8, width: 160, height: 22)
        footerRow.addSubview(startupCheckbox)
        
        let doneBtn = InteractiveObsidianButton(frame: NSRect(x: 322, y: 4, width: 150, height: 34))
        let doneLabel = NSTextField(labelWithString: "Start Using LazyType")
        doneLabel.font = NSFont.systemFont(ofSize: 13, weight: .bold)
        doneLabel.textColor = .white
        doneLabel.alignment = .center
        doneLabel.frame = NSRect(x: 0, y: 8, width: 150, height: 18)
        doneBtn.addSubview(doneLabel)
        doneBtn.onClick = { [weak self] in
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
            self?.close()
        }
        footerRow.addSubview(doneBtn)
        
        container.addSubview(footerRow)
        visualEffectView.addSubview(container)
    }
    
    private func createCardView(frame: NSRect) -> FlippedView {
        let card = FlippedView(frame: frame)
        card.wantsLayer = true
        card.layer?.cornerRadius = 16
        card.layer?.cornerCurve = .continuous
        card.layer?.backgroundColor = NSColor(white: 0.12, alpha: 0.85).cgColor
        card.layer?.borderWidth = 1.0
        card.layer?.borderColor = NSColor(white: 1.0, alpha: 0.10).cgColor
        return card
    }
    
    public func refreshState() {
        let isPermGranted = PermissionsHelper.isAccessibilityGranted()
        if isPermGranted {
            permStatusPill.stringValue = "Granted ✓"
            permStatusPill.textColor = NSColor(red: 0.08, green: 0.78, blue: 0.45, alpha: 1.0)
            permStatusPill.layer?.backgroundColor = NSColor(red: 0.08, green: 0.78, blue: 0.45, alpha: 0.15).cgColor
        } else {
            permStatusPill.stringValue = "Action Required"
            permStatusPill.textColor = NSColor(red: 1.0, green: 0.65, blue: 0.15, alpha: 1.0)
            permStatusPill.layer?.backgroundColor = NSColor(red: 1.0, green: 0.65, blue: 0.15, alpha: 0.15).cgColor
        }
        
        let isExtConnected = AdapterRegistry.shared.browserBridgeAdapter.isExtensionConnected
        if isExtConnected {
            extStatusDot.layer?.backgroundColor = NSColor(red: 0.08, green: 0.78, blue: 0.45, alpha: 1.0).cgColor
            extStatusLabel.stringValue = "Connected ✓"
            extStatusLabel.textColor = NSColor(red: 0.08, green: 0.78, blue: 0.45, alpha: 1.0)
        } else {
            extStatusDot.layer?.backgroundColor = NSColor(white: 0.45, alpha: 1.0).cgColor
            extStatusLabel.stringValue = "Not Connected"
            extStatusLabel.textColor = NSColor(white: 0.55, alpha: 1.0)
        }
    }
    
    private func openChromeAndRevealExtension() {
        // Find extension location inside app bundle or fallback
        let targetExtensionURL: URL
        if let bundleRes = Bundle.main.resourceURL,
           FileManager.default.fileExists(atPath: bundleRes.appendingPathComponent("extension/manifest.json").path) {
            targetExtensionURL = bundleRes.appendingPathComponent("extension")
        } else {
            // Check standard projects or app support
            let directProject = URL(fileURLWithPath: "/Volumes/ExternalSSD/Projects/lazytype/extension")
            if FileManager.default.fileExists(atPath: directProject.path) {
                targetExtensionURL = directProject
            } else {
                targetExtensionURL = Bundle.main.bundleURL
            }
        }
        
        // 1. Reveal in Finder
        NSWorkspace.shared.activateFileViewerSelecting([targetExtensionURL])
        
        // 2. Open Google Chrome to chrome://extensions
        if let chromeApp = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.google.Chrome") {
            let config = NSWorkspace.OpenConfiguration()
            if let extUrl = URL(string: "chrome://extensions") {
                NSWorkspace.shared.open([extUrl], withApplicationAt: chromeApp, configuration: config, completionHandler: nil)
            }
        } else {
            // Fallback default browser
            if let extUrl = URL(string: "chrome://extensions") {
                NSWorkspace.shared.open(extUrl)
            }
        }
    }
    
    @objc private func toggleStartup() {
        let current = LaunchAtLoginHelper.shared.isLaunchAtLoginEnabled
        LaunchAtLoginHelper.shared.setLaunchAtLogin(enabled: !current)
        startupCheckbox.state = !current ? .on : .off
    }
}
