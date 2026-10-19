import Foundation
import CoreGraphics
import Carbon.HIToolbox

public struct KeyboardInjector {
    
    // Virtual keycodes
    public static let kVK_Return: CGKeyCode = 0x24
    public static let kVK_Tab: CGKeyCode = 0x30
    public static let kVK_Space: CGKeyCode = 0x31
    public static let kVK_Delete: CGKeyCode = 0x33 // Backspace
    public static let kVK_Escape: CGKeyCode = 0x35
    public static let kVK_Command: CGKeyCode = 0x37
    public static let kVK_Shift: CGKeyCode = 0x38
    public static let kVK_Option: CGKeyCode = 0x3A
    public static let kVK_Control: CGKeyCode = 0x3B
    public static let kVK_LeftArrow: CGKeyCode = 0x7B
    public static let kVK_RightArrow: CGKeyCode = 0x7C
    public static let kVK_DownArrow: CGKeyCode = 0x7D
    public static let kVK_UpArrow: CGKeyCode = 0x7E
    public static let kVK_ANSI_A: CGKeyCode = 0x00
    public static let kVK_ANSI_V: CGKeyCode = 0x09
    
    public static func postKey(keyCode: CGKeyCode, flags: CGEventFlags = []) {
        let source = CGEventSource(stateID: .combinedSessionState)
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
            return
        }
        keyDown.flags = flags
        keyUp.flags = flags
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
    
    public static func postReturn() {
        postKey(keyCode: kVK_Return)
    }
    
    public static func postBackspace(count: Int = 1) {
        for _ in 0..<count {
            postKey(keyCode: kVK_Delete)
            usleep(2500)
        }
    }
    
    public static func postKeyByName(_ name: String, modifiers: [String] = []) {
        var flags: CGEventFlags = []
        for mod in modifiers {
            switch mod.lowercased() {
            case "cmd", "command": flags.insert(.maskCommand)
            case "shift": flags.insert(.maskShift)
            case "alt", "option": flags.insert(.maskAlternate)
            case "ctrl", "control": flags.insert(.maskControl)
            default: break
            }
        }
        
        switch name.lowercased() {
        case "enter", "return":
            postKey(keyCode: kVK_Return, flags: flags)
        case "backspace", "delete":
            postKey(keyCode: kVK_Delete, flags: flags)
        case "tab":
            postKey(keyCode: kVK_Tab, flags: flags)
        case "escape", "esc":
            postKey(keyCode: kVK_Escape, flags: flags)
        case "space":
            postKey(keyCode: kVK_Space, flags: flags)
        case "arrowup", "up":
            postKey(keyCode: kVK_UpArrow, flags: flags)
        case "arrowdown", "down":
            postKey(keyCode: kVK_DownArrow, flags: flags)
        case "arrowleft", "left":
            postKey(keyCode: kVK_LeftArrow, flags: flags)
        case "arrowright", "right":
            postKey(keyCode: kVK_RightArrow, flags: flags)
        case "paste":
            postKey(keyCode: kVK_ANSI_V, flags: [.maskCommand])
        default:
            // Type single character
            if let char = name.utf16.first {
                postUnicodeCharacter(UniChar(char))
            }
        }
    }
    
    public static func postUnicodeCharacter(_ char: UniChar) {
        let source = CGEventSource(stateID: .combinedSessionState)
        var utf16Char = char
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else {
            return
        }
        keyDown.keyboardSetUnicodeString(stringLength: 1, unicodeString: &utf16Char)
        keyUp.keyboardSetUnicodeString(stringLength: 1, unicodeString: &utf16Char)
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
    
    public static func typeString(_ string: String) {
        let source = CGEventSource(stateID: .combinedSessionState)
        let utf16 = Array(string.utf16)
        
        // Split into chunks of max 20 chars for reliable CGEvent delivery
        let chunkSize = 20
        for i in stride(from: 0, to: utf16.count, by: chunkSize) {
            let end = min(i + chunkSize, utf16.count)
            var chunk = Array(utf16[i..<end])
            
            guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
                  let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else {
                continue
            }
            keyDown.keyboardSetUnicodeString(stringLength: chunk.count, unicodeString: &chunk)
            keyUp.keyboardSetUnicodeString(stringLength: chunk.count, unicodeString: &chunk)
            keyDown.post(tap: .cghidEventTap)
            keyUp.post(tap: .cghidEventTap)
            usleep(5000) // 5ms pause between chunks
        }
    }
    
    public static func sendZoomMuteShortcut() {
        // Cmd + Shift + A
        postKey(keyCode: kVK_ANSI_A, flags: [.maskCommand, .maskShift])
    }
    
    public static func sendZoomVideoShortcut() {
        // Cmd + Shift + V
        postKey(keyCode: kVK_ANSI_V, flags: [.maskCommand, .maskShift])
    }
}
