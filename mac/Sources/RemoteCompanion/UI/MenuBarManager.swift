import Foundation
import AppKit

public final class MenuBarManager: NSObject, @unchecked Sendable {
    public static let shared = MenuBarManager()
    
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var popoverController: MenuBarPopoverViewController!
    private var updateTimer: Timer?
    
    private override init() {
        super.init()
    }
    
    private func createStatusItemIcon() -> NSImage {
        let size = NSSize(width: 22, height: 20)
        let candidatePaths = [
            Bundle.main.path(forResource: "menu_mascot_44", ofType: "png"),
            Bundle.main.resourcePath.map { "\($0)/menu_mascot_44.png" },
            Bundle.main.path(forResource: "mascot_cutout", ofType: "png"),
            Bundle.main.resourcePath.map { "\($0)/mascot_cutout.png" },
            "/Volumes/ExternalSSD/Projects/lazytype/mac/Resources/menu_mascot_44.png",
            "/Volumes/ExternalSSD/Projects/lazytype/mac/Resources/mascot_cutout.png"
        ].compactMap { $0 }
        
        for p in candidatePaths {
            if FileManager.default.fileExists(atPath: p), let diskImg = NSImage(contentsOfFile: p) {
                let img = NSImage(size: size)
                img.lockFocus()
                diskImg.draw(in: NSRect(origin: .zero, size: size), from: .zero, operation: .sourceOver, fraction: 1.0)
                img.unlockFocus()
                img.isTemplate = false
                return img
            }
        }
        
        let img = NSImage(size: size, flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            ctx.saveGState()
            NSColor(red: 0.95, green: 0.20, blue: 0.20, alpha: 1.0).setFill()
            let headRect = CGRect(x: 2.0, y: 2.0, width: 18.0, height: 16.0)
            let headPath = CGPath(roundedRect: headRect, cornerWidth: 5.0, cornerHeight: 5.0, transform: nil)
            ctx.addPath(headPath)
            ctx.fillPath()
            ctx.restoreGState()
            return true
        }
        img.isTemplate = false
        return img
    }
    
    public func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = createStatusItemIcon()
            button.imagePosition = .imageLeft
            button.title = " LazyType"
            button.toolTip = "LazyType - Liquid Glass Mac Companion"
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
        popoverController = MenuBarPopoverViewController()
        popover = NSPopover()
        popover.contentSize = NSSize(width: 340, height: 440)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = popoverController
        
        // Periodic HUD update timer
        updateTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.refreshStatus()
        }
        refreshStatus()
    }
    
    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            refreshStatus()
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
    
    public func closePopover() {
        if popover.isShown {
            popover.performClose(nil)
        }
    }
    
    @objc public func refreshStatus() {
        popoverController?.refreshData()
    }
}

// MARK: - Core Bento & Interactive Animation Views

public class FlippedView: NSView {
    public override var isFlipped: Bool { true }
}

public final class ImageHelper {
    public static func loadCosmicCloudsImage() -> NSImage? {
        let candidatePaths = [
            Bundle.main.path(forResource: "cosmic_clouds_banner", ofType: "png"),
            Bundle.main.resourcePath.map { "\($0)/cosmic_clouds_banner.png" },
            Bundle.main.resourcePath.map { "\($0)/phone/public/assets/cosmic_clouds_banner.png" },
            "/Volumes/ExternalSSD/Projects/lazytype/mac/Resources/cosmic_clouds_banner.png",
            "/Volumes/ExternalSSD/Projects/lazytype/phone/public/assets/cosmic_clouds_banner.png"
        ].compactMap { $0 }
        
        for p in candidatePaths {
            if FileManager.default.fileExists(atPath: p), let img = NSImage(contentsOfFile: p) {
                return img
            }
        }
        return nil
    }
}

public final class ArtisticBannerLevelCard: FlippedView {
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        setupStyling()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        setupStyling()
    }
    
    private func setupStyling() {
        let radius = bounds.height / 2.0
        layer?.cornerRadius = min(radius, 24)
        layer?.cornerCurve = .continuous
        layer?.masksToBounds = true
        layer?.backgroundColor = NSColor(red: 0.05, green: 0.06, blue: 0.09, alpha: 1.0).cgColor
        layer?.borderWidth = 1.0
        layer?.borderColor = NSColor(white: 1.0, alpha: 0.22).cgColor
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.25
        layer?.shadowRadius = 12
        layer?.shadowOffset = CGSize(width: 0, height: -3)
        
        // 1. Artistic Starry Cosmic Clouds Background
        let bgImageView = NSImageView(frame: NSRect(x: 0, y: 0, width: bounds.width, height: bounds.height))
        bgImageView.imageScaling = .scaleAxesIndependently
        bgImageView.autoresizingMask = [.width, .height]
        bgImageView.image = ImageHelper.loadCosmicCloudsImage()
        addSubview(bgImageView)
        
        // 2. Soft obsidian wash to ensure text contrast
        let washView = FlippedView(frame: NSRect(x: 0, y: 0, width: bounds.width, height: bounds.height))
        washView.wantsLayer = true
        washView.layer?.backgroundColor = NSColor(red: 0.05, green: 0.06, blue: 0.09, alpha: 0.20).cgColor
        washView.autoresizingMask = [.width, .height]
        addSubview(washView)
    }
}

public final class ObsidianHeroTargetCard: FlippedView {
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        setupStyling()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        setupStyling()
    }
    
    private func setupStyling() {
        layer?.cornerRadius = 24
        layer?.cornerCurve = .continuous
        layer?.masksToBounds = true
        layer?.backgroundColor = NSColor(red: 0.05, green: 0.06, blue: 0.09, alpha: 1.0).cgColor
        layer?.borderWidth = 1.0
        layer?.borderColor = NSColor(white: 1.0, alpha: 0.22).cgColor
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.28
        layer?.shadowRadius = 14
        layer?.shadowOffset = CGSize(width: 0, height: -3)
        
        // 1. Artistic Starry Cosmic Cloudscape Banner Background (Crisp, perfectly proportioned!)
        let bgImageView = NSImageView(frame: NSRect(x: 0, y: 0, width: bounds.width, height: bounds.height))
        bgImageView.imageScaling = .scaleAxesIndependently
        bgImageView.autoresizingMask = [.width, .height]
        bgImageView.image = ImageHelper.loadCosmicCloudsImage()
        addSubview(bgImageView)
        
        // 2. Translucent obsidian glass wash for perfect typographic contrast
        let washView = FlippedView(frame: NSRect(x: 0, y: 0, width: bounds.width, height: bounds.height))
        washView.wantsLayer = true
        washView.layer?.backgroundColor = NSColor(red: 0.05, green: 0.06, blue: 0.09, alpha: 0.28).cgColor
        washView.autoresizingMask = [.width, .height]
        addSubview(washView)
        
        // 3. Specular top highlight sheen
        let sheen = CAGradientLayer()
        sheen.colors = [
            NSColor(white: 1.0, alpha: 0.28).cgColor,
            NSColor(white: 1.0, alpha: 0.04).cgColor,
            NSColor.clear.cgColor
        ]
        sheen.startPoint = CGPoint(x: 0.5, y: 0.0)
        sheen.endPoint = CGPoint(x: 0.5, y: 0.5)
        sheen.frame = NSRect(x: 0, y: 0, width: bounds.width, height: bounds.height * 0.5)
        sheen.cornerRadius = 24
        sheen.cornerCurve = .continuous
        layer?.addSublayer(sheen)
    }
}

public final class InteractiveBentoCard: NSControl {
    public var onClick: (() -> Void)?
    private var trackingArea: NSTrackingArea?
    private var arrowView: NSImageView?
    
    public override var isFlipped: Bool { true }
    
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        setupStyling()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        setupStyling()
    }
    
    private func setupStyling() {
        layer?.cornerRadius = 20
        layer?.cornerCurve = .continuous
        layer?.backgroundColor = NSColor.white.cgColor
        layer?.borderWidth = 1.0
        layer?.borderColor = NSColor(white: 0.0, alpha: 0.08).cgColor
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.04
        layer?.shadowRadius = 8
        layer?.shadowOffset = CGSize(width: 0, height: -2)
    }
    
    public func setArrowView(_ arrow: NSImageView) {
        self.arrowView = arrow
    }
    
    public override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea!)
    }
    
    public override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }
    
    public override func mouseEntered(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.20
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animator().layer?.transform = CATransform3DMakeScale(1.025, 1.025, 1.0)
            animator().layer?.shadowOpacity = 0.12
            animator().layer?.shadowRadius = 14
            animator().layer?.borderColor = NSColor(white: 0.0, alpha: 0.20).cgColor
            arrowView?.animator().layer?.transform = CATransform3DMakeTranslation(2, -2, 0)
        }
    }
    
    public override func mouseExited(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.20
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animator().layer?.transform = CATransform3DIdentity
            animator().layer?.shadowOpacity = 0.04
            animator().layer?.shadowRadius = 8
            animator().layer?.borderColor = NSColor(white: 0.0, alpha: 0.08).cgColor
            arrowView?.animator().layer?.transform = CATransform3DIdentity
        }
    }
    
    public override func mouseUp(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        if bounds.contains(loc) {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.08
                animator().layer?.transform = CATransform3DMakeScale(0.97, 0.97, 1.0)
            }, completionHandler: {
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0.12
                    self.animator().layer?.transform = CATransform3DIdentity
                }
                self.onClick?()
            })
        }
    }
}

public final class InteractiveObsidianButton: NSControl {
    public var onClick: (() -> Void)?
    private var trackingArea: NSTrackingArea?
    private var chevronView: NSImageView?
    private var sheenLayer: CAGradientLayer?
    
    public override var isFlipped: Bool { true }
    
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        setupStyling()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        setupStyling()
    }
    
    private func setupStyling() {
        let radius = bounds.height / 2.0
        layer?.cornerRadius = radius
        layer?.cornerCurve = .continuous
        layer?.masksToBounds = true
        
        // Translucent Optical Liquid Glass - reflects and refracts the background beneath it!
        layer?.backgroundColor = NSColor(red: 0.06, green: 0.08, blue: 0.14, alpha: 0.38).cgColor
        layer?.borderWidth = 1.3
        layer?.borderColor = NSColor(white: 1.0, alpha: 0.65).cgColor
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.35
        layer?.shadowRadius = 12
        layer?.shadowOffset = CGSize(width: 0, height: -2)
        
        // Top curved specular glass reflection glare arc
        let sheen = CAGradientLayer()
        sheen.colors = [
            NSColor(white: 1.0, alpha: 0.55).cgColor,
            NSColor(white: 1.0, alpha: 0.12).cgColor,
            NSColor.clear.cgColor
        ]
        sheen.startPoint = CGPoint(x: 0.5, y: 0.0)
        sheen.endPoint = CGPoint(x: 0.5, y: 0.55)
        sheen.frame = bounds
        sheen.cornerRadius = radius
        sheen.cornerCurve = .continuous
        layer?.addSublayer(sheen)
        sheenLayer = sheen
    }
    
    public override func layout() {
        super.layout()
        let radius = bounds.height / 2.0
        layer?.cornerRadius = radius
        sheenLayer?.frame = bounds
        sheenLayer?.cornerRadius = radius
    }
    
    public func setChevronView(_ chevron: NSImageView) {
        self.chevronView = chevron
    }
    
    public override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea!)
    }
    
    public override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }
    
    public override func mouseEntered(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.20
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animator().layer?.transform = CATransform3DMakeScale(1.025, 1.025, 1.0)
            animator().layer?.backgroundColor = NSColor(red: 0.10, green: 0.14, blue: 0.22, alpha: 0.52).cgColor
            animator().layer?.borderColor = NSColor(white: 1.0, alpha: 0.90).cgColor
            animator().layer?.shadowOpacity = 0.55
            animator().layer?.shadowRadius = 16
            chevronView?.animator().layer?.transform = CATransform3DMakeTranslation(4, 0, 0)
        }
    }
    
    public override func mouseExited(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.20
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animator().layer?.transform = CATransform3DIdentity
            animator().layer?.backgroundColor = NSColor(red: 0.06, green: 0.08, blue: 0.14, alpha: 0.38).cgColor
            animator().layer?.borderColor = NSColor(white: 1.0, alpha: 0.65).cgColor
            animator().layer?.shadowOpacity = 0.35
            animator().layer?.shadowRadius = 12
            chevronView?.animator().layer?.transform = CATransform3DIdentity
        }
    }
    
    public override func mouseUp(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        if bounds.contains(loc) {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.08
                animator().layer?.transform = CATransform3DMakeScale(0.96, 0.96, 1.0)
            }, completionHandler: {
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0.12
                    self.animator().layer?.transform = CATransform3DIdentity
                }
                self.onClick?()
            })
        }
    }
}

public final class InteractiveBrandPillButton: NSControl {
    public var onClick: (() -> Void)?
    private var trackingArea: NSTrackingArea?
    private var logoImageView: NSImageView!
    
    public override var isFlipped: Bool { true }
    
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        setupStyling()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        setupStyling()
    }
    
    private func setupStyling() {
        layer?.cornerRadius = 12
        layer?.cornerCurve = .continuous
        layer?.backgroundColor = NSColor(white: 0.94, alpha: 0.95).cgColor
        layer?.borderWidth = 1.0
        layer?.borderColor = NSColor(white: 0.0, alpha: 0.08).cgColor
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.04
        layer?.shadowRadius = 4
        layer?.shadowOffset = CGSize(width: 0, height: -1)
        toolTip = "LazyType Companion • Click for Setup & Extension Guide"
        
        let pad: CGFloat = 4
        let iconSize = bounds.width - (pad * 2)
        logoImageView = NSImageView(frame: NSRect(x: pad, y: pad, width: iconSize, height: iconSize))
        logoImageView.image = VectorIcons.mascot(size: NSSize(width: iconSize, height: iconSize))
        addSubview(logoImageView)
    }
    
    public override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea!)
    }
    
    public override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }
    
    public override func mouseEntered(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.18
            animator().layer?.backgroundColor = NSColor(white: 0.90, alpha: 1.0).cgColor
            animator().layer?.borderColor = NSColor(white: 0.0, alpha: 0.18).cgColor
            animator().layer?.transform = CATransform3DMakeScale(1.03, 1.03, 1.0)
        }
    }
    
    public override func mouseExited(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.18
            animator().layer?.backgroundColor = NSColor(white: 0.94, alpha: 0.95).cgColor
            animator().layer?.borderColor = NSColor(white: 0.0, alpha: 0.08).cgColor
            animator().layer?.transform = CATransform3DIdentity
        }
    }
    
    public override func mouseUp(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        if bounds.contains(loc) {
            onClick?()
        }
    }
}

public final class InteractiveServerBadgeButton: NSControl {
    public var onClick: (() -> Void)?
    private var trackingArea: NSTrackingArea?
    private var titleField: NSTextField!
    private var copyIcon: NSImageView!
    
    public override var isFlipped: Bool { true }
    
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        setupStyling()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        setupStyling()
    }
    
    private func setupStyling() {
        layer?.cornerRadius = bounds.height / 2
        layer?.cornerCurve = .continuous
        layer?.backgroundColor = NSColor(white: 0.94, alpha: 0.95).cgColor
        layer?.borderWidth = 1.0
        layer?.borderColor = NSColor(white: 0.0, alpha: 0.08).cgColor
        toolTip = "Click to copy companion URL"
        
        titleField = NSTextField(labelWithString: "")
        titleField.font = NSFont.monospacedSystemFont(ofSize: 10.5, weight: .bold)
        titleField.textColor = NSColor.black
        titleField.frame = NSRect(x: 10, y: (bounds.height - 16) / 2, width: bounds.width - 32, height: 16)
        addSubview(titleField)
        
        copyIcon = NSImageView(frame: NSRect(x: bounds.width - 24, y: (bounds.height - 12) / 2, width: 12, height: 12))
        copyIcon.image = VectorIcons.copy(size: NSSize(width: 12, height: 12), color: NSColor(white: 0.3, alpha: 1.0))
        addSubview(copyIcon)
    }
    
    public func setTitle(_ title: String) {
        titleField.stringValue = title
    }
    
    public override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea!)
    }
    
    public override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }
    
    public override func mouseEntered(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.18
            animator().layer?.backgroundColor = NSColor(white: 0.90, alpha: 1.0).cgColor
            animator().layer?.borderColor = NSColor(white: 0.0, alpha: 0.18).cgColor
            animator().layer?.transform = CATransform3DMakeScale(1.03, 1.03, 1.0)
        }
    }
    
    public override func mouseExited(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.18
            animator().layer?.backgroundColor = NSColor(white: 0.94, alpha: 0.95).cgColor
            animator().layer?.borderColor = NSColor(white: 0.0, alpha: 0.08).cgColor
            animator().layer?.transform = CATransform3DIdentity
        }
    }
    
    public override func mouseUp(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        if bounds.contains(loc) {
            onClick?()
        }
    }
}

public final class InteractiveQuitButton: NSControl {
    public var onClick: (() -> Void)?
    private var trackingArea: NSTrackingArea?
    private var label: NSTextField!
    
    public override var isFlipped: Bool { true }
    
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        setupStyling()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        setupStyling()
    }
    
    private func setupStyling() {
        layer?.cornerRadius = 11
        layer?.cornerCurve = .continuous
        layer?.backgroundColor = NSColor.white.cgColor
        layer?.borderWidth = 1.0
        layer?.borderColor = NSColor(white: 0.0, alpha: 0.10).cgColor
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.03
        layer?.shadowRadius = 4
        layer?.shadowOffset = CGSize(width: 0, height: -1)
        
        label = NSTextField(labelWithString: "Quit")
        label.font = NSFont.systemFont(ofSize: 12, weight: .bold)
        label.textColor = NSColor(white: 0.20, alpha: 1.0)
        label.alignment = .center
        label.frame = NSRect(x: 0, y: 7, width: bounds.width, height: 18)
        addSubview(label)
    }
    
    public override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea!)
    }
    
    public override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }
    
    public override func mouseEntered(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.18
            animator().layer?.backgroundColor = NSColor(red: 0.98, green: 0.94, blue: 0.94, alpha: 1.0).cgColor
            animator().layer?.borderColor = NSColor(red: 0.88, green: 0.25, blue: 0.30, alpha: 0.40).cgColor
            animator().layer?.transform = CATransform3DMakeScale(1.03, 1.03, 1.0)
            label.textColor = NSColor(red: 0.85, green: 0.15, blue: 0.22, alpha: 1.0)
        }
    }
    
    public override func mouseExited(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.18
            animator().layer?.backgroundColor = NSColor.white.cgColor
            animator().layer?.borderColor = NSColor(white: 0.0, alpha: 0.10).cgColor
            animator().layer?.transform = CATransform3DIdentity
            label.textColor = NSColor(white: 0.20, alpha: 1.0)
        }
    }
    
    public override func mouseUp(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        if bounds.contains(loc) {
            onClick?()
        }
    }
}

// MARK: - Luminous Milky Frosted Glass Bento Popover View Controller
public final class MenuBarPopoverViewController: NSViewController {
    
    private var visualEffectView: NSVisualEffectView!
    private var targetTitleLabel: NSTextField!
    private var targetSubLabel: NSTextField!
    private var targetDot: NSView!
    private var phoneStatusLabel: NSTextField!
    private var brandPillBtn: InteractiveBrandPillButton!
    private var serverBadgeBtn: InteractiveServerBadgeButton!
    private var startupToggle: NSButton!
    
    public override func loadView() {
        visualEffectView = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: 340, height: 440))
        visualEffectView.material = .popover
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.appearance = NSAppearance(named: .vibrantLight)
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = 26
        visualEffectView.layer?.cornerCurve = .continuous
        visualEffectView.layer?.masksToBounds = true
        visualEffectView.layer?.borderWidth = 1.2
        visualEffectView.layer?.borderColor = NSColor(white: 1.0, alpha: 0.90).cgColor
        visualEffectView.layer?.backgroundColor = NSColor(white: 0.96, alpha: 0.92).cgColor
        
        self.view = visualEffectView
        setupSubviews()
    }
    
    private func setupSubviews() {
        let container = FlippedView(frame: NSRect(x: 16, y: 14, width: 308, height: 412))
        visualEffectView.addSubview(container)
        
        // --- 1. Top Header Capsule (308 x 66 at y: 0) ---
        let headerCapsule = FlippedView(frame: NSRect(x: 0, y: 0, width: 308, height: 66))
        headerCapsule.wantsLayer = true
        headerCapsule.layer?.cornerRadius = 20
        headerCapsule.layer?.cornerCurve = .continuous
        headerCapsule.layer?.backgroundColor = NSColor.white.cgColor
        headerCapsule.layer?.borderWidth = 1.0
        headerCapsule.layer?.borderColor = NSColor(white: 0.0, alpha: 0.06).cgColor
        headerCapsule.layer?.shadowColor = NSColor.black.cgColor
        headerCapsule.layer?.shadowOpacity = 0.03
        headerCapsule.layer?.shadowRadius = 8
        headerCapsule.layer?.shadowOffset = CGSize(width: 0, height: -2)
        
        // Exact 1:1 Mascot Pill Button (Size 36x36)
        brandPillBtn = InteractiveBrandPillButton(frame: NSRect(x: 14, y: 9, width: 36, height: 36))
        brandPillBtn.onClick = {
            MenuBarManager.shared.closePopover()
            OnboardingWindowController.shared.show()
        }
        headerCapsule.addSubview(brandPillBtn)
        
        // Brand Name OUTSIDE the pill, UNDER the pill!
        let brandTitle = NSTextField(labelWithString: "LazyType")
        brandTitle.font = NSFont.systemFont(ofSize: 11.5, weight: .bold)
        brandTitle.textColor = NSColor.black
        brandTitle.alignment = .center
        brandTitle.frame = NSRect(x: 2, y: 47, width: 60, height: 16)
        headerCapsule.addSubview(brandTitle)
        
        // Interactive Server badge pill button
        let ip = NetworkInterfaceHelper.getLocalIPAddress()
        let port = LocalServer.shared.port
        serverBadgeBtn = InteractiveServerBadgeButton(frame: NSRect(x: 136, y: 10, width: 160, height: 32))
        serverBadgeBtn.setTitle("\(ip):\(port)")
        serverBadgeBtn.onClick = { [weak self] in
            self?.copyServerUrl()
        }
        headerCapsule.addSubview(serverBadgeBtn)
        
        let serverSub = NSTextField(labelWithString: "Companion Server • Copy")
        serverSub.font = NSFont.systemFont(ofSize: 10, weight: .medium)
        serverSub.textColor = NSColor(white: 0.45, alpha: 1.0)
        serverSub.alignment = .center
        serverSub.frame = NSRect(x: 136, y: 47, width: 160, height: 14)
        headerCapsule.addSubview(serverSub)
        
        container.addSubview(headerCapsule)
        
        // --- 2. Hero Target Bento Card (308 x 122 at y: 74) (More black, zero pink!) ---
        let targetCard = ObsidianHeroTargetCard(frame: NSRect(x: 0, y: 74, width: 308, height: 122))
        
        // Top section: White Screen icon + App Name in white + Live status pill
        let screenIcon = NSImageView(frame: NSRect(x: 16, y: 13, width: 20, height: 20))
        screenIcon.image = VectorIcons.screen(size: NSSize(width: 20, height: 20), color: .white)
        targetCard.addSubview(screenIcon)
        
        targetTitleLabel = NSTextField(labelWithString: "Detecting Target...")
        targetTitleLabel.font = NSFont.systemFont(ofSize: 17, weight: .bold)
        targetTitleLabel.textColor = .white
        targetTitleLabel.frame = NSRect(x: 44, y: 11, width: 172, height: 24)
        targetCard.addSubview(targetTitleLabel)
        
        let liveBadge = FlippedView(frame: NSRect(x: 222, y: 12, width: 70, height: 22))
        liveBadge.wantsLayer = true
        liveBadge.layer?.cornerRadius = 11
        liveBadge.layer?.cornerCurve = .continuous
        liveBadge.layer?.backgroundColor = NSColor(white: 1.0, alpha: 0.14).cgColor
        liveBadge.layer?.borderWidth = 1.0
        liveBadge.layer?.borderColor = NSColor(white: 1.0, alpha: 0.24).cgColor
        
        let badgeDot = NSView(frame: NSRect(x: 8, y: 7, width: 6, height: 6))
        badgeDot.wantsLayer = true
        badgeDot.layer?.cornerRadius = 3
        badgeDot.layer?.backgroundColor = NSColor(red: 0.10, green: 0.85, blue: 0.50, alpha: 1.0).cgColor
        liveBadge.addSubview(badgeDot)
        
        let liveLabel = NSTextField(labelWithString: "ACTIVE")
        liveLabel.font = NSFont.systemFont(ofSize: 9, weight: .bold)
        liveLabel.textColor = .white
        liveLabel.frame = NSRect(x: 18, y: 3, width: 48, height: 14)
        liveBadge.addSubview(liveLabel)
        targetCard.addSubview(liveBadge)
        
        // Pure White Inset Card (High contrast black on white, continuous squircle)
        let insetCard = FlippedView(frame: NSRect(x: 7, y: 44, width: 294, height: 70))
        insetCard.wantsLayer = true
        insetCard.layer?.cornerRadius = 17
        insetCard.layer?.cornerCurve = .continuous
        insetCard.layer?.backgroundColor = NSColor.white.cgColor
        insetCard.layer?.borderWidth = 1.0
        insetCard.layer?.borderColor = NSColor(white: 0.0, alpha: 0.06).cgColor
        insetCard.layer?.shadowColor = NSColor.black.cgColor
        insetCard.layer?.shadowOpacity = 0.05
        insetCard.layer?.shadowRadius = 8
        insetCard.layer?.shadowOffset = CGSize(width: 0, height: -2)
        
        targetDot = NSView(frame: NSRect(x: 14, y: 15, width: 8, height: 8))
        targetDot.wantsLayer = true
        targetDot.layer?.cornerRadius = 4
        targetDot.layer?.backgroundColor = NSColor(red: 0.08, green: 0.75, blue: 0.45, alpha: 1.0).cgColor
        insetCard.addSubview(targetDot)
        
        let targetSection = NSTextField(labelWithString: "ACTIVE SCREEN TARGET")
        targetSection.font = NSFont.systemFont(ofSize: 10, weight: .bold)
        targetSection.textColor = NSColor.black
        targetSection.frame = NSRect(x: 28, y: 11, width: 250, height: 16)
        insetCard.addSubview(targetSection)
        
        targetSubLabel = NSTextField(labelWithString: "Characters typed on phone stream live to this app")
        targetSubLabel.font = NSFont.systemFont(ofSize: 11.5, weight: .regular)
        targetSubLabel.textColor = NSColor(red: 0.35, green: 0.38, blue: 0.45, alpha: 1.0)
        targetSubLabel.frame = NSRect(x: 14, y: 31, width: 266, height: 32)
        insetCard.addSubview(targetSubLabel)
        
        targetCard.addSubview(insetCard)
        container.addSubview(targetCard)
        
        // --- 3. Middle 2-Column Bento Cards (308 x 106 at y: 204) ---
        // Left Card: "Pair Phone"
        let qrCard = InteractiveBentoCard(frame: NSRect(x: 0, y: 204, width: 149, height: 106))
        qrCard.onClick = { [weak self] in
            self?.showQRClicked()
        }
        
        // Top row: Pitch black icon badge on left, subtle diagonal arrow on right
        let qrBadge = FlippedView(frame: NSRect(x: 14, y: 12, width: 34, height: 34))
        qrBadge.wantsLayer = true
        qrBadge.layer?.cornerRadius = 11
        qrBadge.layer?.cornerCurve = .continuous
        qrBadge.layer?.backgroundColor = NSColor.black.cgColor
        let qrImg = NSImageView(frame: NSRect(x: 8, y: 8, width: 18, height: 18))
        qrImg.image = VectorIcons.qrCode(size: NSSize(width: 18, height: 18), color: .white)
        qrBadge.addSubview(qrImg)
        qrCard.addSubview(qrBadge)
        
        let qrArrow = NSImageView(frame: NSRect(x: 120, y: 14, width: 14, height: 14))
        qrArrow.image = VectorIcons.arrowUpRight(size: NSSize(width: 14, height: 14), color: NSColor(white: 0.60, alpha: 1.0))
        qrCard.setArrowView(qrArrow)
        qrCard.addSubview(qrArrow)
        
        // Bottom row: Title and clean subtitle
        let qrTitle = NSTextField(labelWithString: "Pair Phone")
        qrTitle.font = NSFont.systemFont(ofSize: 14, weight: .bold)
        qrTitle.textColor = NSColor.black
        qrTitle.frame = NSRect(x: 14, y: 56, width: 120, height: 18)
        qrCard.addSubview(qrTitle)
        
        let qrSub = NSTextField(labelWithString: "Scan QR Code")
        qrSub.font = NSFont.systemFont(ofSize: 11.5, weight: .medium)
        qrSub.textColor = NSColor(white: 0.45, alpha: 1.0)
        qrSub.frame = NSRect(x: 14, y: 78, width: 120, height: 16)
        qrCard.addSubview(qrSub)
        
        container.addSubview(qrCard)
        
        // Right Card: "Connected Devices"
        let devicesCard = InteractiveBentoCard(frame: NSRect(x: 159, y: 204, width: 149, height: 106))
        devicesCard.onClick = { [weak self] in
            self?.showDevicesClicked()
        }
        
        let devBadge = FlippedView(frame: NSRect(x: 14, y: 12, width: 34, height: 34))
        devBadge.wantsLayer = true
        devBadge.layer?.cornerRadius = 11
        devBadge.layer?.cornerCurve = .continuous
        devBadge.layer?.backgroundColor = NSColor.black.cgColor
        let devImg = NSImageView(frame: NSRect(x: 8, y: 8, width: 18, height: 18))
        devImg.image = VectorIcons.smartphone(size: NSSize(width: 18, height: 18), color: .white)
        devBadge.addSubview(devImg)
        devicesCard.addSubview(devBadge)
        
        let devArrow = NSImageView(frame: NSRect(x: 120, y: 14, width: 14, height: 14))
        devArrow.image = VectorIcons.arrowUpRight(size: NSSize(width: 14, height: 14), color: NSColor(white: 0.60, alpha: 1.0))
        devicesCard.setArrowView(devArrow)
        devicesCard.addSubview(devArrow)
        
        let devTitle = NSTextField(labelWithString: "Devices")
        devTitle.font = NSFont.systemFont(ofSize: 14, weight: .bold)
        devTitle.textColor = NSColor.black
        devTitle.frame = NSRect(x: 14, y: 56, width: 120, height: 18)
        devicesCard.addSubview(devTitle)
        
        phoneStatusLabel = NSTextField(labelWithString: "0 Connected")
        phoneStatusLabel.font = NSFont.systemFont(ofSize: 11.5, weight: .medium)
        phoneStatusLabel.textColor = NSColor(white: 0.45, alpha: 1.0)
        phoneStatusLabel.frame = NSRect(x: 14, y: 78, width: 120, height: 16)
        devicesCard.addSubview(phoneStatusLabel)
        
        container.addSubview(devicesCard)
        
        // --- 4. Hero Action Button Floating Directly on Main Level (308 x 48 at y: 318) ---
        let demoBtn = InteractiveObsidianButton(frame: NSRect(x: 0, y: 318, width: 308, height: 48))
        demoBtn.onClick = { [weak self] in
            self?.openDemoClicked()
        }
        
        let iconShadow = NSShadow()
        iconShadow.shadowColor = NSColor(white: 0.0, alpha: 0.95)
        iconShadow.shadowOffset = NSSize(width: 0, height: -1.5)
        iconShadow.shadowBlurRadius = 3.0
        
        let demoIcon = NSImageView(frame: NSRect(x: 18, y: 15, width: 18, height: 18))
        demoIcon.image = VectorIcons.videoMeeting(size: NSSize(width: 18, height: 18), color: .white)
        demoIcon.shadow = iconShadow
        demoBtn.addSubview(demoIcon)
        
        let demoLabel = NSTextField(labelWithString: "Open Interactive Demo Call")
        demoLabel.font = NSFont.systemFont(ofSize: 13.5, weight: .bold)
        demoLabel.textColor = .white
        let labelShadow = NSShadow()
        labelShadow.shadowColor = NSColor(white: 0.0, alpha: 0.95)
        labelShadow.shadowOffset = NSSize(width: 0, height: -1.5)
        labelShadow.shadowBlurRadius = 3.5
        demoLabel.shadow = labelShadow
        demoLabel.frame = NSRect(x: 44, y: 14, width: 228, height: 20)
        demoBtn.addSubview(demoLabel)
        
        let demoChevron = NSImageView(frame: NSRect(x: 278, y: 18, width: 12, height: 12))
        demoChevron.image = VectorIcons.chevronRight(size: NSSize(width: 12, height: 12), color: .white)
        demoChevron.shadow = iconShadow
        demoBtn.setChevronView(demoChevron)
        demoBtn.addSubview(demoChevron)
        
        container.addSubview(demoBtn)
        
        // --- 5. Footer Row: Launch at Startup & Quit (308 x 34 at y: 378) ---
        let footerRow = FlippedView(frame: NSRect(x: 0, y: 378, width: 308, height: 34))
        
        startupToggle = NSButton(checkboxWithTitle: "", target: self, action: #selector(toggleLaunchAtLogin))
        startupToggle.state = LaunchAtLoginHelper.shared.isLaunchAtLoginEnabled ? .on : .off
        startupToggle.frame = NSRect(x: 4, y: 7, width: 22, height: 20)
        footerRow.addSubview(startupToggle)
        
        let startupLabel = NSTextField(labelWithString: "Launch at Startup")
        startupLabel.font = NSFont.systemFont(ofSize: 12.5, weight: .bold)
        startupLabel.textColor = .white
        startupLabel.shadow = labelShadow
        startupLabel.frame = NSRect(x: 28, y: 7, width: 150, height: 18)
        footerRow.addSubview(startupLabel)
        
        let quitBtn = InteractiveQuitButton(frame: NSRect(x: 236, y: 2, width: 72, height: 30))
        quitBtn.onClick = { [weak self] in
            self?.quitClicked()
        }
        footerRow.addSubview(quitBtn)
        
        container.addSubview(footerRow)
    }
    
    public func refreshData() {
        Task { @MainActor in
            let status = await AdapterRegistry.shared.getCurrentStatus()
            
            let target = status.activeApplication
            self.targetTitleLabel?.stringValue = target
            
            if !status.browserExtensionConnected {
                self.targetDot?.layer?.backgroundColor = NSColor(red: 1.0, green: 0.65, blue: 0.15, alpha: 1.0).cgColor
                self.targetSubLabel?.stringValue = "⚠️ Extension disconnected • Click mascot to setup"
            } else if status.chatAvailable || status.meetingDetected {
                self.targetDot?.layer?.backgroundColor = NSColor(red: 0.08, green: 0.75, blue: 0.45, alpha: 1.0).cgColor
                self.targetSubLabel?.stringValue = "Live stream active • Keystrokes type on Mac"
            } else {
                self.targetDot?.layer?.backgroundColor = NSColor(red: 0.55, green: 0.60, blue: 0.68, alpha: 1.0).cgColor
                self.targetSubLabel?.stringValue = "Focus any chat or search field to type"
            }
            
            let devices = DeviceStore.shared.getDevices().filter { !$0.isRevoked }
            if let activeDev = devices.first {
                self.phoneStatusLabel?.stringValue = "\(activeDev.deviceName) Active"
            } else {
                self.phoneStatusLabel?.stringValue = "0 Connected"
            }
            
            let ip = NetworkInterfaceHelper.getLocalIPAddress()
            let port = LocalServer.shared.port
            self.serverBadgeBtn?.setTitle("\(ip):\(port)")
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
        MenuBarManager.shared.closePopover()
        QRWindowController.shared.showQR()
    }
    
    @objc private func showDevicesClicked() {
        MenuBarManager.shared.closePopover()
        DevicesWindowController.shared.showDevices()
    }
    
    @objc private func openDemoClicked() {
        MenuBarManager.shared.closePopover()
        let port = LocalServer.shared.port
        if let url = URL(string: "http://127.0.0.1:\(port)/demo") {
            NSWorkspace.shared.open(url)
        }
    }
    
    @objc private func toggleLaunchAtLogin() {
        let current = LaunchAtLoginHelper.shared.isLaunchAtLoginEnabled
        LaunchAtLoginHelper.shared.setLaunchAtLogin(enabled: !current)
        startupToggle.state = !current ? .on : .off
    }
    
    @objc private func quitClicked() {
        LocalServer.shared.stop()
        NSApp.terminate(nil)
    }
}


