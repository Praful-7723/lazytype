import Foundation
import AppKit

public struct VectorIcons {
    
    /// Cute LazyType Cat Mascot with perky ears, cozy paws & keyboard
    public static func mascot(size: NSSize = NSSize(width: 24, height: 24), color: NSColor = .white) -> NSImage {
        let candidatePaths = [
            Bundle.main.path(forResource: "mascot_cutout", ofType: "png"),
            Bundle.main.resourcePath.map { "\($0)/mascot_cutout.png" },
            Bundle.main.path(forResource: "mascot", ofType: "png"),
            Bundle.main.resourcePath.map { "\($0)/mascot.png" },
            Bundle.main.resourcePath.map { "\($0)/phone/public/assets/mascot_cutout.png" },
            "/Volumes/ExternalSSD/Projects/lazytype/mac/Resources/mascot_cutout.png",
            "/Volumes/ExternalSSD/Projects/lazytype/mac/Resources/mascot.png",
            "/Volumes/ExternalSSD/Projects/lazytype/phone/public/assets/mascot_cutout.png"
        ].compactMap { $0 }
        
        for p in candidatePaths {
            if FileManager.default.fileExists(atPath: p), let diskImg = NSImage(contentsOfFile: p) {
                let img = NSImage(size: size)
                img.lockFocus()
                diskImg.draw(in: NSRect(origin: .zero, size: size), from: .zero, operation: .sourceOver, fraction: 1.0)
                img.unlockFocus()
                return img
            }
        }
        
        // Clean vector fallback
        return NSImage(size: size, flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            let w = rect.width
            let h = rect.height
            
            ctx.saveGState()
            color.setFill()
            
            // Perky cat ears
            let leftEar = CGMutablePath()
            leftEar.move(to: CGPoint(x: w * 0.22, y: h * 0.55))
            leftEar.addLine(to: CGPoint(x: w * 0.35, y: h * 0.90))
            leftEar.addLine(to: CGPoint(x: w * 0.48, y: h * 0.70))
            leftEar.closeSubpath()
            ctx.addPath(leftEar)
            ctx.fillPath()
            
            let rightEar = CGMutablePath()
            rightEar.move(to: CGPoint(x: w * 0.78, y: h * 0.55))
            rightEar.addLine(to: CGPoint(x: w * 0.65, y: h * 0.90))
            rightEar.addLine(to: CGPoint(x: w * 0.52, y: h * 0.70))
            rightEar.closeSubpath()
            ctx.addPath(rightEar)
            ctx.fillPath()
            
            // Cat head
            let headRect = CGRect(x: w * 0.18, y: h * 0.24, width: w * 0.64, height: h * 0.54)
            let headPath = CGPath(roundedRect: headRect, cornerWidth: w * 0.26, cornerHeight: w * 0.24, transform: nil)
            ctx.addPath(headPath)
            ctx.fillPath()
            
            // Mini keyboard under paws
            let kbRect = CGRect(x: w * 0.20, y: h * 0.08, width: w * 0.60, height: h * 0.20)
            let kbPath = CGPath(roundedRect: kbRect, cornerWidth: 3.0, cornerHeight: 3.0, transform: nil)
            ctx.addPath(kbPath)
            ctx.fillPath()
            
            ctx.restoreGState()
            return true
        }
    }
    
    /// Replaced lightning with cute mascot everywhere
    public static func lightning(size: NSSize = NSSize(width: 24, height: 24), color: NSColor = .white) -> NSImage {
        return mascot(size: size, color: color)
    }
    
    /// Smartphone vector icon with screen and home indicator
    public static func smartphone(size: NSSize = NSSize(width: 24, height: 24), color: NSColor = .black) -> NSImage {
        return NSImage(size: size, flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            let w = rect.width
            let h = rect.height
            
            ctx.saveGState()
            color.setStroke()
            ctx.setLineWidth(1.6)
            
            // Outer phone body
            let bodyRect = CGRect(x: w * 0.22, y: h * 0.08, width: w * 0.56, height: h * 0.84)
            let bodyPath = CGPath(roundedRect: bodyRect, cornerWidth: w * 0.12, cornerHeight: w * 0.12, transform: nil)
            ctx.addPath(bodyPath)
            ctx.strokePath()
            
            // Screen speaker/camera notch
            color.setFill()
            let notchRect = CGRect(x: w * 0.42, y: h * 0.82, width: w * 0.16, height: 2.0)
            let notchPath = CGPath(roundedRect: notchRect, cornerWidth: 1.0, cornerHeight: 1.0, transform: nil)
            ctx.addPath(notchPath)
            ctx.fillPath()
            
            // Home indicator
            let homeRect = CGRect(x: w * 0.40, y: h * 0.14, width: w * 0.20, height: 2.0)
            let homePath = CGPath(roundedRect: homeRect, cornerWidth: 1.0, cornerHeight: 1.0, transform: nil)
            ctx.addPath(homePath)
            ctx.fillPath()
            
            ctx.restoreGState()
            return true
        }
    }
    
    /// Clean vector QR Code icon
    public static func qrCode(size: NSSize = NSSize(width: 24, height: 24), color: NSColor = .black) -> NSImage {
        return NSImage(size: size, flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            let w = rect.width
            let h = rect.height
            
            ctx.saveGState()
            color.setStroke()
            ctx.setLineWidth(1.8)
            
            // 3 outer corner squares
            func drawCorner(x: CGFloat, y: CGFloat, s: CGFloat) {
                let r = CGRect(x: x, y: y, width: s, height: s)
                let p = CGPath(roundedRect: r, cornerWidth: 2.5, cornerHeight: 2.5, transform: nil)
                ctx.addPath(p)
                ctx.strokePath()
                
                // inner dot
                let dotRect = CGRect(x: x + s * 0.28, y: y + s * 0.28, width: s * 0.44, height: s * 0.44)
                let dotPath = CGPath(roundedRect: dotRect, cornerWidth: 1.2, cornerHeight: 1.2, transform: nil)
                color.setFill()
                ctx.addPath(dotPath)
                ctx.fillPath()
            }
            
            let s = w * 0.38
            drawCorner(x: w * 0.08, y: h * 0.54, s: s) // top-left
            drawCorner(x: w * 0.54, y: h * 0.54, s: s) // top-right
            drawCorner(x: w * 0.08, y: h * 0.08, s: s) // bottom-left
            
            // bottom-right data matrix dots
            color.setFill()
            let d1 = CGRect(x: w * 0.56, y: h * 0.32, width: w * 0.15, height: h * 0.15)
            let d2 = CGRect(x: w * 0.76, y: h * 0.32, width: w * 0.15, height: h * 0.15)
            let d3 = CGRect(x: w * 0.56, y: h * 0.12, width: w * 0.15, height: h * 0.15)
            let d4 = CGRect(x: w * 0.76, y: h * 0.12, width: w * 0.15, height: h * 0.15)
            for r in [d1, d2, d3, d4] {
                let p = CGPath(roundedRect: r, cornerWidth: 1.2, cornerHeight: 1.2, transform: nil)
                ctx.addPath(p)
                ctx.fillPath()
            }
            
            ctx.restoreGState()
            return true
        }
    }
    
    /// Video meeting / demo camera icon
    public static func videoMeeting(size: NSSize = NSSize(width: 24, height: 24), color: NSColor = .white) -> NSImage {
        return NSImage(size: size, flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            let w = rect.width
            let h = rect.height
            
            ctx.saveGState()
            color.setFill()
            
            // Camera body
            let bodyRect = CGRect(x: w * 0.10, y: h * 0.22, width: w * 0.54, height: h * 0.56)
            let bodyPath = CGPath(roundedRect: bodyRect, cornerWidth: 4.0, cornerHeight: 4.0, transform: nil)
            ctx.addPath(bodyPath)
            ctx.fillPath()
            
            // Camera lens triangle
            let lensPath = CGMutablePath()
            lensPath.move(to: CGPoint(x: w * 0.68, y: h * 0.40))
            lensPath.addLine(to: CGPoint(x: w * 0.90, y: h * 0.26))
            lensPath.addLine(to: CGPoint(x: w * 0.90, y: h * 0.74))
            lensPath.addLine(to: CGPoint(x: w * 0.68, y: h * 0.60))
            lensPath.closeSubpath()
            ctx.addPath(lensPath)
            ctx.fillPath()
            
            ctx.restoreGState()
            return true
        }
    }
    
    /// Right chevron arrow
    public static func chevronRight(size: NSSize = NSSize(width: 14, height: 14), color: NSColor = .white) -> NSImage {
        return NSImage(size: size, flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            let w = rect.width
            let h = rect.height
            
            ctx.saveGState()
            color.setStroke()
            ctx.setLineWidth(2.2)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            
            let path = CGMutablePath()
            path.move(to: CGPoint(x: w * 0.28, y: h * 0.15))
            path.addLine(to: CGPoint(x: w * 0.72, y: h * 0.50))
            path.addLine(to: CGPoint(x: w * 0.28, y: h * 0.85))
            
            ctx.addPath(path)
            ctx.strokePath()
            ctx.restoreGState()
            return true
        }
    }
    
    /// Copy to clipboard icon
    public static func copy(size: NSSize = NSSize(width: 16, height: 16), color: NSColor = .black) -> NSImage {
        return NSImage(size: size, flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            let w = rect.width
            let h = rect.height
            
            ctx.saveGState()
            color.setStroke()
            ctx.setLineWidth(1.5)
            
            // Back sheet
            let back = CGRect(x: w * 0.28, y: h * 0.28, width: w * 0.58, height: h * 0.62)
            ctx.addPath(CGPath(roundedRect: back, cornerWidth: 2.5, cornerHeight: 2.5, transform: nil))
            ctx.strokePath()
            
            // Front sheet
            color.setFill()
            ctx.setFillColor(NSColor.white.cgColor)
            let front = CGRect(x: w * 0.14, y: h * 0.10, width: w * 0.58, height: h * 0.62)
            let frontPath = CGPath(roundedRect: front, cornerWidth: 2.5, cornerHeight: 2.5, transform: nil)
            ctx.addPath(frontPath)
            ctx.fillPath()
            ctx.addPath(frontPath)
            ctx.strokePath()
            
            ctx.restoreGState()
            return true
        }
    }
    
    /// Checkmark icon
    public static func check(size: NSSize = NSSize(width: 16, height: 16), color: NSColor = .white) -> NSImage {
        return NSImage(size: size, flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            let w = rect.width
            let h = rect.height
            
            ctx.saveGState()
            color.setStroke()
            ctx.setLineWidth(2.2)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            
            let path = CGMutablePath()
            path.move(to: CGPoint(x: w * 0.18, y: h * 0.50))
            path.addLine(to: CGPoint(x: w * 0.42, y: h * 0.22))
            path.addLine(to: CGPoint(x: w * 0.82, y: h * 0.78))
            
            ctx.addPath(path)
            ctx.strokePath()
            ctx.restoreGState()
            return true
        }
    }
    
    /// Multi-device / screen icon
    public static func screen(size: NSSize = NSSize(width: 24, height: 24), color: NSColor = .black) -> NSImage {
        return NSImage(size: size, flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            let w = rect.width
            let h = rect.height
            
            ctx.saveGState()
            color.setStroke()
            ctx.setLineWidth(1.6)
            
            // Monitor screen
            let screenRect = CGRect(x: w * 0.10, y: h * 0.28, width: w * 0.80, height: h * 0.60)
            let path = CGPath(roundedRect: screenRect, cornerWidth: 3.5, cornerHeight: 3.5, transform: nil)
            ctx.addPath(path)
            ctx.strokePath()
            
            // Stand
            let standPath = CGMutablePath()
            standPath.move(to: CGPoint(x: w * 0.50, y: h * 0.28))
            standPath.addLine(to: CGPoint(x: w * 0.50, y: h * 0.12))
            standPath.move(to: CGPoint(x: w * 0.32, y: h * 0.12))
            standPath.addLine(to: CGPoint(x: w * 0.68, y: h * 0.12))
            ctx.addPath(standPath)
            ctx.strokePath()
            
            ctx.restoreGState()
            return true
        }
    }
    
    /// External link / diagonal arrow
    public static func arrowUpRight(size: NSSize = NSSize(width: 14, height: 14), color: NSColor = .white) -> NSImage {
        return NSImage(size: size, flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            let w = rect.width
            let h = rect.height
            
            ctx.saveGState()
            color.setStroke()
            ctx.setLineWidth(1.8)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            
            let path = CGMutablePath()
            path.move(to: CGPoint(x: w * 0.25, y: h * 0.25))
            path.addLine(to: CGPoint(x: w * 0.75, y: h * 0.75))
            path.move(to: CGPoint(x: w * 0.38, y: h * 0.75))
            path.addLine(to: CGPoint(x: w * 0.75, y: h * 0.75))
            path.addLine(to: CGPoint(x: w * 0.75, y: h * 0.38))
            
            ctx.addPath(path)
            ctx.strokePath()
            ctx.restoreGState()
            return true
        }
    }
    
    /// Power / quit icon
    public static func power(size: NSSize = NSSize(width: 14, height: 14), color: NSColor = .systemRed) -> NSImage {
        return NSImage(size: size, flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            let w = rect.width
            let h = rect.height
            
            ctx.saveGState()
            color.setStroke()
            ctx.setLineWidth(1.6)
            ctx.setLineCap(.round)
            
            // Arc
            ctx.addArc(center: CGPoint(x: w * 0.5, y: h * 0.45), radius: w * 0.35, startAngle: 0.8, endAngle: 2.34, clockwise: true)
            ctx.strokePath()
            
            // Vertical line
            let line = CGMutablePath()
            line.move(to: CGPoint(x: w * 0.5, y: h * 0.45))
            line.addLine(to: CGPoint(x: w * 0.5, y: h * 0.85))
            ctx.addPath(line)
            ctx.strokePath()
            
            ctx.restoreGState()
            return true
        }
    }
    
    /// Trash / revoke icon
    public static func trash(size: NSSize = NSSize(width: 14, height: 14), color: NSColor = .systemRed) -> NSImage {
        return NSImage(size: size, flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            let w = rect.width
            let h = rect.height
            
            ctx.saveGState()
            color.setStroke()
            ctx.setLineWidth(1.4)
            ctx.setLineCap(.round)
            
            // Can
            let canRect = CGRect(x: w * 0.25, y: h * 0.12, width: w * 0.50, height: h * 0.60)
            ctx.addPath(CGPath(roundedRect: canRect, cornerWidth: 2, cornerHeight: 2, transform: nil))
            ctx.strokePath()
            
            // Lid
            let lid = CGMutablePath()
            lid.move(to: CGPoint(x: w * 0.18, y: h * 0.72))
            lid.addLine(to: CGPoint(x: w * 0.82, y: h * 0.72))
            lid.move(to: CGPoint(x: w * 0.38, y: h * 0.72))
            lid.addLine(to: CGPoint(x: w * 0.38, y: h * 0.85))
            lid.addLine(to: CGPoint(x: w * 0.62, y: h * 0.85))
            lid.addLine(to: CGPoint(x: w * 0.62, y: h * 0.72))
            ctx.addPath(lid)
            ctx.strokePath()
            
            ctx.restoreGState()
            return true
        }
    }
}

