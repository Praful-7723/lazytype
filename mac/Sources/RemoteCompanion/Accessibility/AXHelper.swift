import Foundation
import ApplicationServices
import AppKit

public struct AXElementInfo {
    public let role: String?
    public let subrole: String?
    public let title: String?
    public let desc: String?
    public let identifier: String?
    public let value: String?
}

public struct AXHelper {
    
    public static func isProcessTrusted() -> Bool {
        return AXIsProcessTrusted()
    }
    
    public static func requestAccessibilityPermissionPrompt() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
    
    public static func getApplicationElement(pid: pid_t) -> AXUIElement {
        return AXUIElementCreateApplication(pid)
    }
    
    public static func getStringAttribute(_ element: AXUIElement, attribute: CFString) -> String? {
        var valueRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &valueRef)
        guard result == .success, let value = valueRef else { return nil }
        if CFGetTypeID(value) == CFStringGetTypeID() {
            return (value as! String)
        }
        return nil
    }
    
    public static func getChildren(_ element: AXUIElement) -> [AXUIElement] {
        var valueRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &valueRef)
        guard result == .success, let array = valueRef as? [AXUIElement] else { return [] }
        return array
    }
    
    public static func getWindows(_ appElement: AXUIElement) -> [AXUIElement] {
        var valueRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &valueRef)
        guard result == .success, let array = valueRef as? [AXUIElement] else { return [] }
        return array
    }
    
    public static func inspectElement(_ element: AXUIElement) -> AXElementInfo {
        let role = getStringAttribute(element, attribute: kAXRoleAttribute as CFString)
        let subrole = getStringAttribute(element, attribute: kAXSubroleAttribute as CFString)
        let title = getStringAttribute(element, attribute: kAXTitleAttribute as CFString)
        let desc = getStringAttribute(element, attribute: kAXDescriptionAttribute as CFString)
        let id = getStringAttribute(element, attribute: kAXIdentifierAttribute as CFString)
        let val = getStringAttribute(element, attribute: kAXValueAttribute as CFString)
        return AXElementInfo(role: role, subrole: subrole, title: title, desc: desc, identifier: id, value: val)
    }
    
    public static func performPress(_ element: AXUIElement) -> Bool {
        let result = AXUIElementPerformAction(element, kAXPressAction as CFString)
        return result == .success
    }
    
    public static func setStringValue(_ element: AXUIElement, text: String) -> Bool {
        let result = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, text as CFTypeRef)
        return result == .success
    }
    
    public static func setFocused(_ element: AXUIElement) -> Bool {
        let result = AXUIElementSetAttributeValue(element, kAXFocusedAttribute as CFString, true as CFTypeRef)
        return result == .success
    }
    
    /**
     * Resilient recursive search matching element by role and text patterns across
     * title, description, identifier, or label.
     */
    public static func findElement(
        in root: AXUIElement,
        maxDepth: Int = 10,
        maxNodes: Int = 400,
        predicate: (AXElementInfo, AXUIElement) -> Bool
    ) -> AXUIElement? {
        var visitedCount = 0
        
        func search(node: AXUIElement, currentDepth: Int) -> AXUIElement? {
            if currentDepth > maxDepth || visitedCount >= maxNodes { return nil }
            visitedCount += 1
            
            let info = inspectElement(node)
            if predicate(info, node) {
                return node
            }
            
            let children = getChildren(node)
            for child in children {
                if let found = search(node: child, currentDepth: currentDepth + 1) {
                    return found
                }
            }
            return nil
        }
        
        return search(node: root, currentDepth: 0)
    }
    
    /**
     * Search for button containing keywords (e.g. "chat", "send", "mute")
     */
    public static func findButton(in root: AXUIElement, matching keywords: [String]) -> AXUIElement? {
        let lowered = keywords.map { $0.lowercased() }
        return findElement(in: root) { info, _ in
            guard let role = info.role, role == (kAXButtonRole as String) else { return false }
            let allText = [info.title, info.desc, info.identifier]
                .compactMap { $0?.lowercased() }
                .joined(separator: " ")
            return lowered.contains { allText.contains($0) }
        }
    }
    
    /**
     * Search for editable text area or text field
     */
    public static func findTextInput(in root: AXUIElement, hintKeywords: [String] = []) -> AXUIElement? {
        let loweredHints = hintKeywords.map { $0.lowercased() }
        return findElement(in: root) { info, _ in
            guard let role = info.role else { return false }
            let isTextRole = role == (kAXTextAreaRole as String) || role == (kAXTextFieldRole as String)
            if !isTextRole { return false }
            
            if loweredHints.isEmpty { return true }
            
            let allText = [info.title, info.desc, info.identifier]
                .compactMap { $0?.lowercased() }
                .joined(separator: " ")
            return loweredHints.contains { allText.contains($0) } || allText.isEmpty // accept generic text area in chat panel
        }
    }
}
