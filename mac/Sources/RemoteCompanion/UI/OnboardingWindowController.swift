import Foundation
import AppKit
import WebKit

public final class OnboardingWindowController: NSWindowController, WKScriptMessageHandler, WKNavigationDelegate {
    public static let shared = OnboardingWindowController()
    
    private var webView: WKWebView!
    private var statusTimer: Timer?
    
    public init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 500),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "LazyType • Setup Guide"
        window.center()
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 560, height: 500)
        window.maxSize = NSSize(width: 560, height: 500)
        
        super.init(window: window)
        setupWebView()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    public func show() {
        loadContent()
        guard let win = self.window else { return }
        win.center()
        win.level = .floating // Float above other windows so user sees it immediately on launch
        win.makeKeyAndOrderFront(nil)
        win.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
        
        startStatusTimer()
    }
    
    public override func close() {
        window?.level = .normal
        statusTimer?.invalidate()
        statusTimer = nil
        super.close()
    }
    
    private func setupWebView() {
        guard let window = self.window else { return }
        
        let config = WKWebViewConfiguration()
        let contentController = WKUserContentController()
        contentController.add(self, name: "onboarding")
        config.userContentController = contentController
        
        webView = WKWebView(frame: window.contentView!.bounds, configuration: config)
        webView.navigationDelegate = self
        webView.autoresizingMask = [.width, .height]
        window.contentView = webView
    }
    
    private func loadContent() {
        var htmlURL: URL?
        
        if let bundleRes = Bundle.main.resourceURL {
            let candidate = bundleRes.appendingPathComponent("Onboarding_Guide.html")
            if FileManager.default.fileExists(atPath: candidate.path) {
                htmlURL = candidate
            }
        }
        
        if htmlURL == nil {
            let devPath = URL(fileURLWithPath: "/Volumes/ExternalSSD/Projects/lazytype/mac/Resources/Onboarding_Guide.html")
            if FileManager.default.fileExists(atPath: devPath.path) {
                htmlURL = devPath
            }
        }
        
        if let url = htmlURL {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
    }
    
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "onboarding",
              let dict = message.body as? [String: Any],
              let action = dict["action"] as? String else { return }
        
        switch action {
        case "openAccessibility":
            PermissionsHelper.promptForAccessibilityIfNeeded()
            PermissionsHelper.openAccessibilitySettings()
            
        case "downloadZip":
            downloadExtensionZipToUserDownloads()
            
        case "revealFolder":
            revealExtensionFolderInFinder()
            
        case "openChrome":
            openChromeExtensionsPage()
            
        case "showQR":
            QRWindowController.shared.showQR()
            
        case "complete":
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding_v2")
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
            self.close()
            
        default:
            break
        }
    }
    
    private func downloadExtensionZipToUserDownloads() {
        var sourceZip: URL?
        
        if let bundleRes = Bundle.main.resourceURL {
            let candidate = bundleRes.appendingPathComponent("LazyType-Chrome-Extension.zip")
            if FileManager.default.fileExists(atPath: candidate.path) {
                sourceZip = candidate
            }
        }
        
        if sourceZip == nil {
            let devPath = URL(fileURLWithPath: "/Volumes/ExternalSSD/Projects/lazytype/mac/Resources/LazyType-Chrome-Extension.zip")
            if FileManager.default.fileExists(atPath: devPath.path) {
                sourceZip = devPath
            }
        }
        
        guard let source = sourceZip else { return }
        
        if let downloadsDir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first {
            let destZip = downloadsDir.appendingPathComponent("LazyType-Chrome-Extension.zip")
            try? FileManager.default.removeItem(at: destZip)
            try? FileManager.default.copyItem(at: source, to: destZip)
            NSWorkspace.shared.activateFileViewerSelecting([destZip.standardizedFileURL])
        }
    }
    
    private func revealExtensionFolderInFinder() {
        var extFolder: URL?
        
        if let bundleRes = Bundle.main.resourceURL {
            let candidate = bundleRes.appendingPathComponent("extension")
            if FileManager.default.fileExists(atPath: candidate.path) {
                extFolder = candidate
            }
        }
        
        if extFolder == nil {
            let devPath = URL(fileURLWithPath: "/Volumes/ExternalSSD/Projects/lazytype/extension")
            if FileManager.default.fileExists(atPath: devPath.path) {
                extFolder = devPath
            }
        }
        
        if let folder = extFolder {
            NSWorkspace.shared.activateFileViewerSelecting([folder.standardizedFileURL])
        }
    }
    
    private func openChromeExtensionsPage() {
        if let chromeApp = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.google.Chrome") {
            let config = NSWorkspace.OpenConfiguration()
            if let extUrl = URL(string: "chrome://extensions") {
                NSWorkspace.shared.open([extUrl], withApplicationAt: chromeApp, configuration: config, completionHandler: nil)
                return
            }
        }
        
        if let extUrl = URL(string: "chrome://extensions") {
            NSWorkspace.shared.open(extUrl)
        }
    }
    
    private func startStatusTimer() {
        statusTimer?.invalidate()
        statusTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let isPerm = PermissionsHelper.isAccessibilityGranted()
            let isExt = AdapterRegistry.shared.browserBridgeAdapter.isExtensionConnected
            
            let js = "if (window.updateSystemStatus) { window.updateSystemStatus({ accessibility: \(isPerm), extensionConnected: \(isExt) }); }"
            self.webView?.evaluateJavaScript(js, completionHandler: nil)
        }
    }
}
