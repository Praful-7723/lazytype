import Foundation

public final class AppLogger: @unchecked Sendable {
    public static let shared = AppLogger()
    
    public var isDebugEnabled: Bool = true
    public var logMessageContent: Bool = false
    
    private let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "HH:mm:ss.SSS"
        return df
    }()
    
    private let lock = NSLock()
    
    private init() {}
    
    public func log(_ message: String, tag: String = "INFO") {
        guard isDebugEnabled || tag == "ERROR" else { return }
        lock.lock()
        defer { lock.unlock() }
        let time = dateFormatter.string(from: Date())
        print("[\(time)] [\(tag)] \(message)")
    }
    
    public func info(_ message: String) {
        log(message, tag: "INFO")
    }
    
    public func debug(_ message: String) {
        log(message, tag: "DEBUG")
    }
    
    public func error(_ message: String) {
        log(message, tag: "ERROR")
    }
    
    public func audit(phone: String, action: String, target: String, success: Bool, text: String = "") {
        let preview: String
        if logMessageContent && !text.isEmpty {
            preview = " \"\(text.prefix(40))\""
        } else if !text.isEmpty {
            preview = " (\(text.count) chars)"
        } else {
            preview = ""
        }
        log("[\(phone)] -> [\(target)] \(action)\(preview) => \(success ? "SUCCESS ✓" : "FAILED ✕")", tag: "AUDIT")
    }
}
