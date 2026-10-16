import Foundation
import AppKit
import CoreImage

public struct QRGenerator {
    public static func generateQRCodeImage(from string: String, size: CGFloat = 240) -> NSImage? {
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
    
    private var qrImageView: NSImageView!
    private var urlField: NSTextField!
    private var copyBtn: NSButton!
    
    public init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 420),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Pair Android Remote Companion"
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
        
        let container = NSView(frame: NSRect(x: 20, y: 20, width: 300, height: 380))
        
        let titleLabel = NSTextField(labelWithString: "Scan QR with your phone")
        titleLabel.frame = NSRect(x: 0, y: 350, width: 300, height: 24)
        titleLabel.font = NSFont.boldSystemFont(ofSize: 15)
        titleLabel.alignment = .center
        container.addSubview(titleLabel)
        
        let descLabel = NSTextField(labelWithString: "Make sure your phone and Mac are connected to the same Wi-Fi network.")
        descLabel.frame = NSRect(x: 10, y: 310, width: 280, height: 32)
        descLabel.font = NSFont.systemFont(ofSize: 11)
        descLabel.textColor = .secondaryLabelColor
        descLabel.alignment = .center
        descLabel.cell?.wraps = true
        container.addSubview(descLabel)
        
        qrImageView = NSImageView(frame: NSRect(x: 40, y: 80, width: 220, height: 220))
        qrImageView.imageScaling = .scaleProportionallyUpOrDown
        container.addSubview(qrImageView)
        
        urlField = NSTextField(labelWithString: "")
        urlField.frame = NSRect(x: 0, y: 46, width: 300, height: 20)
        urlField.font = NSFont.monospacedSystemFont(ofSize: 10, weight: .regular)
        urlField.alignment = .center
        urlField.textColor = .secondaryLabelColor
        container.addSubview(urlField)
        
        copyBtn = NSButton(title: "Copy Pairing URL", target: self, action: #selector(copyUrlClicked))
        copyBtn.frame = NSRect(x: 60, y: 10, width: 180, height: 30)
        copyBtn.bezelStyle = .rounded
        container.addSubview(copyBtn)
        
        contentView.addSubview(container)
    }
    
    public func showQR() {
        let pairUrl = PairingManager.shared.getPairingURL(port: Int(LocalServer.shared.port))
        urlField.stringValue = pairUrl
        qrImageView.image = QRGenerator.generateQRCodeImage(from: pairUrl, size: 220)
        
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func copyUrlClicked() {
        let pairUrl = PairingManager.shared.getPairingURL(port: Int(LocalServer.shared.port))
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(pairUrl, forType: .string)
        copyBtn.title = "Copied ✓"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.copyBtn.title = "Copy Pairing URL"
        }
    }
}
