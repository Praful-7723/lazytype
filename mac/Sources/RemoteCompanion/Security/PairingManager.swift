import Foundation

public final class PairingManager: @unchecked Sendable {
    public static let shared = PairingManager()
    
    private var currentPairingToken: String?
    private var tokenExpiry: Date?
    private let lock = NSLock()
    
    private init() {
        _ = generateNewPairingToken()
    }
    
    public func generateNewPairingToken() -> String {
        lock.lock()
        defer { lock.unlock() }
        
        let randomBytes = (0..<16).map { _ in UInt8.random(in: 0...255) }
        let token = "pair_" + randomBytes.map { String(format: "%02x", $0) }.joined()
        currentPairingToken = token
        // Valid for 5 minutes
        tokenExpiry = Date().addingTimeInterval(300)
        
        AppLogger.shared.log("Generated new pairing token: \(token) (expires in 5m)")
        return token
    }
    
    public func getActivePairingToken() -> String {
        lock.lock()
        defer { lock.unlock() }
        if let token = currentPairingToken, let expiry = tokenExpiry, expiry > Date() {
            return token
        }
        lock.unlock()
        return generateNewPairingToken()
    }
    
    public func getPairingURL(port: Int = 8765) -> String {
        let ip = NetworkInterfaceHelper.getLocalIPAddress()
        let token = getActivePairingToken()
        return "http://\(ip):\(port)/?token=\(token)&host=\(ip)&port=\(port)"
    }
    
    public func validatePairingToken(_ candidate: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard let token = currentPairingToken, let expiry = tokenExpiry else {
            return false
        }
        if Date() > expiry {
            return false
        }
        return token == candidate
    }
    
    public func createSessionToken() -> String {
        let randomBytes = (0..<24).map { _ in UInt8.random(in: 0...255) }
        return "sess_" + randomBytes.map { String(format: "%02x", $0) }.joined()
    }
}
