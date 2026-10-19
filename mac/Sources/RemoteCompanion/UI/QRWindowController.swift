import Foundation
import AppKit
import CoreImage

public struct QRGenerator {
    public static func generateQRCodeImage(from string: String, size: CGFloat = 280) -> NSImage? {
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        guard let data = string.data(using: .utf8) else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        
        guard let ciImage = filter.outputImage else { return nil }
        let scale = size / ciImage.extent.width
        let transform = CGAffineTransform(scaleX: scale, y: scale)
        let scaledImage = ciImage.transformed(by: transform)
        
        let rep = NSCIImageRep(ciImage: scaledImage)
        let nsImage = NSImage(size: NSSize(width: size, height: size))
        nsImage.addRepresentation(rep)
        return nsImage
    }
    
    public static func generateQRCodePNG(from string: String) -> Data? {
        guard let image = generateQRCodeImage(from: string, size: 280) else { return nil }
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }
}

public final class QRWindowController: NSWindowController {
    public static let shared = QRWindowController()
    
    private var visualEffectView: NSVisualEffectView!
    private var qrImageView: NSImageView!
    private var qrCardView: NSView!
    private var urlField: NSTextField!
    private var copyBtn: InteractiveObsidianButton!
    
    public init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 500),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "LazyType Companion"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        
        // CRITICAL FOR TRUE TRANSLUCENCY / BEHIND-WINDOW REFRACTION:
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
        guard let window = window else { return }
        
        // Root Luminous Milky Frosted Glass View (Blurs and refracts desktop behind window)
        visualEffectView = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: 360, height: 500))
        visualEffectView.autoresizingMask = [.width, .height]
        visualEffectView.material = .popover
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.appearance = NSAppearance(named: .vibrantLight)
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = 28
        visualEffectView.layer?.cornerCurve = .continuous
        visualEffectView.layer?.masksToBounds = true
        visualEffectView.layer?.borderWidth = 1.2
        visualEffectView.layer?.borderColor = NSColor(white: 1.0, alpha: 0.85).cgColor
        visualEffectView.layer?.backgroundColor = NSColor(white: 0.96, alpha: 0.90).cgColor
        
        window.contentView = visualEffectView
        
        // 1. Status Capsule (Obsidian Black)
        let statusPill = NSView(frame: NSRect(x: 105, y: 442, width: 150, height: 28))
        statusPill.wantsLayer = true
        statusPill.layer?.cornerRadius = 14
        statusPill.layer?.cornerCurve = .continuous
        statusPill.layer?.backgroundColor = NSColor.black.cgColor
        statusPill.layer?.shadowColor = NSColor.black.cgColor
        statusPill.layer?.shadowOpacity = 0.15
        statusPill.layer?.shadowRadius = 8
        statusPill.layer?.shadowOffset = CGSize(width: 0, height: -2)
        
        let statusDot = NSView(frame: NSRect(x: 14, y: 10, width: 8, height: 8))
        statusDot.wantsLayer = true
        statusDot.layer?.cornerRadius = 4
        statusDot.layer?.backgroundColor = NSColor(red: 0.10, green: 0.85, blue: 0.50, alpha: 1.0).cgColor
        statusPill.addSubview(statusDot)
        
        let statusLabel = NSTextField(labelWithString: "READY TO PAIR")
        statusLabel.frame = NSRect(x: 28, y: 5, width: 110, height: 18)
        statusLabel.font = NSFont.systemFont(ofSize: 10, weight: .bold)
        statusLabel.textColor = .white
        statusPill.addSubview(statusLabel)
        visualEffectView.addSubview(statusPill)
        
        // 2. Headline & Subtitle
        let titleLabel = NSTextField(labelWithString: "Scan with Phone")
        titleLabel.frame = NSRect(x: 20, y: 396, width: 320, height: 30)
        titleLabel.font = NSFont.systemFont(ofSize: 22, weight: .bold)
        titleLabel.textColor = NSColor.black
        titleLabel.alignment = .center
        visualEffectView.addSubview(titleLabel)
        
        let descLabel = NSTextField(labelWithString: "Instant live pairing for hands-free meeting chat")
        descLabel.frame = NSRect(x: 20, y: 372, width: 320, height: 20)
        descLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        descLabel.textColor = NSColor(white: 0.45, alpha: 1.0)
        descLabel.alignment = .center
        visualEffectView.addSubview(descLabel)
        
        // 3. Floating Squircle QR Card (Pure white rounded card)
        qrCardView = NSView(frame: NSRect(x: 55, y: 115, width: 250, height: 250))
        qrCardView.wantsLayer = true
        qrCardView.layer?.cornerRadius = 24
        qrCardView.layer?.cornerCurve = .continuous
        qrCardView.layer?.backgroundColor = NSColor.white.cgColor
        qrCardView.layer?.shadowColor = NSColor.black.cgColor
        qrCardView.layer?.shadowOpacity = 0.08
        qrCardView.layer?.shadowRadius = 18
        qrCardView.layer?.shadowOffset = CGSize(width: 0, height: -4)
        qrCardView.layer?.borderWidth = 1.0
        qrCardView.layer?.borderColor = NSColor(white: 0.0, alpha: 0.06).cgColor
        
        qrImageView = NSImageView(frame: NSRect(x: 18, y: 18, width: 214, height: 214))
        qrImageView.imageScaling = .scaleProportionallyUpOrDown
        qrCardView.addSubview(qrImageView)
        
        // Cute Mascot Central QR Badge
        let centerBadge = NSView(frame: NSRect(x: 105, y: 105, width: 40, height: 40))
        centerBadge.wantsLayer = true
        centerBadge.layer?.cornerRadius = 12
        centerBadge.layer?.cornerCurve = .continuous
        centerBadge.layer?.backgroundColor = NSColor.white.cgColor
        centerBadge.layer?.borderWidth = 1.5
        centerBadge.layer?.borderColor = NSColor(white: 0.0, alpha: 0.12).cgColor
        centerBadge.layer?.shadowColor = NSColor.black.cgColor
        centerBadge.layer?.shadowOpacity = 0.12
        centerBadge.layer?.shadowRadius = 6
        centerBadge.layer?.shadowOffset = CGSize(width: 0, height: -2)
        
        let centerMascot = NSImageView(frame: NSRect(x: 4, y: 4, width: 32, height: 32))
        centerMascot.image = VectorIcons.mascot(size: NSSize(width: 32, height: 32))
        centerBadge.addSubview(centerMascot)
        qrCardView.addSubview(centerBadge)
        
        visualEffectView.addSubview(qrCardView)
        
        // 4. Frosted URL Pill
        let urlPill = NSView(frame: NSRect(x: 30, y: 72, width: 300, height: 32))
        urlPill.wantsLayer = true
        urlPill.layer?.cornerRadius = 16
        urlPill.layer?.cornerCurve = .continuous
        urlPill.layer?.backgroundColor = NSColor(white: 0.94, alpha: 0.95).cgColor
        urlPill.layer?.borderWidth = 1.0
        urlPill.layer?.borderColor = NSColor(white: 0.0, alpha: 0.08).cgColor
        
        urlField = NSTextField(labelWithString: "")
        urlField.frame = NSRect(x: 10, y: 6, width: 280, height: 20)
        urlField.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .bold)
        urlField.alignment = .center
        urlField.textColor = NSColor.black
        urlPill.addSubview(urlField)
        visualEffectView.addSubview(urlPill)
        
        // 5. Obsidian Hero Copy Button Floating Directly on Main Level
        let heroBtn = InteractiveObsidianButton(frame: NSRect(x: 45, y: 20, width: 270, height: 44))
        heroBtn.onClick = { [weak self] in
            self?.copyUrlClicked()
        }
        
        let iconShadow = NSShadow()
        iconShadow.shadowColor = NSColor(white: 0.0, alpha: 0.95)
        iconShadow.shadowOffset = NSSize(width: 0, height: -1.5)
        iconShadow.shadowBlurRadius = 3.0
        
        let copyIcon = NSImageView(frame: NSRect(x: 22, y: 14, width: 16, height: 16))
        copyIcon.image = VectorIcons.copy(size: NSSize(width: 16, height: 16), color: .white)
        copyIcon.shadow = iconShadow
        copyIcon.tag = 991
        heroBtn.addSubview(copyIcon)
        
        let copyLabel = NSTextField(labelWithString: "Copy Pairing Link")
        copyLabel.font = NSFont.systemFont(ofSize: 13.5, weight: .bold)
        copyLabel.textColor = .white
        let labelShadow = NSShadow()
        labelShadow.shadowColor = NSColor(white: 0.0, alpha: 0.95)
        labelShadow.shadowOffset = NSSize(width: 0, height: -1.5)
        labelShadow.shadowBlurRadius = 3.5
        copyLabel.shadow = labelShadow
        copyLabel.alignment = .center
        copyLabel.frame = NSRect(x: 44, y: 12, width: 180, height: 20)
        copyLabel.tag = 992
        heroBtn.addSubview(copyLabel)
        
        let copyChevron = NSImageView(frame: NSRect(x: 236, y: 16, width: 12, height: 12))
        copyChevron.image = VectorIcons.chevronRight(size: NSSize(width: 12, height: 12), color: .white)
        copyChevron.shadow = iconShadow
        copyChevron.tag = 993
        heroBtn.setChevronView(copyChevron)
        heroBtn.addSubview(copyChevron)
        
        copyBtn = heroBtn
        visualEffectView.addSubview(copyBtn)
    }
    
    public func showQR() {
        let pairUrl = PairingManager.shared.getPairingURL(port: Int(LocalServer.shared.port))
        urlField.stringValue = pairUrl
        qrImageView.image = QRGenerator.generateQRCodeImage(from: pairUrl, size: 214)
        
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func copyUrlClicked() {
        let pairUrl = PairingManager.shared.getPairingURL(port: Int(LocalServer.shared.port))
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(pairUrl, forType: .string)
        
        if let iconView = copyBtn.viewWithTag(991) as? NSImageView {
            iconView.image = VectorIcons.check(size: NSSize(width: 16, height: 16), color: NSColor(red: 0.10, green: 0.85, blue: 0.50, alpha: 1.0))
        }
        if let labelView = copyBtn.viewWithTag(992) as? NSTextField {
            labelView.stringValue = "Copied to Clipboard"
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { [weak self] in
            guard let self = self else { return }
            if let iconView = self.copyBtn.viewWithTag(991) as? NSImageView {
                iconView.image = VectorIcons.copy(size: NSSize(width: 16, height: 16), color: .white)
            }
            if let labelView = self.copyBtn.viewWithTag(992) as? NSTextField {
                labelView.stringValue = "Copy Pairing Link"
            }
        }
    }
}

