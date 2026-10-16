import Foundation

public struct PairedDevice: Codable, Identifiable {
    public var id: String { deviceId }
    public let deviceId: String
    public let deviceName: String
    public let sessionToken: String
    public let pairedAt: Date
    public var lastSeen: Date
    public var isRevoked: Bool
    
    public init(deviceId: String, deviceName: String, sessionToken: String, pairedAt: Date = Date(), lastSeen: Date = Date(), isRevoked: Bool = false) {
        self.deviceId = deviceId
        self.deviceName = deviceName
        self.sessionToken = sessionToken
        self.pairedAt = pairedAt
        self.lastSeen = lastSeen
        self.isRevoked = isRevoked
    }
}

public final class DeviceStore: @unchecked Sendable {
    public static let shared = DeviceStore()
    
    private let storageKey = "LazyType_PairedDevices"
    private var devices: [String: PairedDevice] = [:]
    private let lock = NSLock()
    
    private init() {
        loadDevices()
    }
    
    public func addOrUpdateDevice(deviceId: String, deviceName: String, sessionToken: String) {
        lock.lock()
        defer { lock.unlock() }
        let device = PairedDevice(
            deviceId: deviceId,
            deviceName: deviceName,
            sessionToken: sessionToken,
            pairedAt: Date(),
            lastSeen: Date(),
            isRevoked: false
        )
        devices[deviceId] = device
        saveDevices()
        AppLogger.shared.log("Device paired and saved: \(deviceName) (\(deviceId))")
    }
    
    public func isValidSession(deviceId: String, sessionToken: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard let device = devices[deviceId] else { return false }
        if device.isRevoked { return false }
        if device.sessionToken == sessionToken {
            devices[deviceId]?.lastSeen = Date()
            saveDevices()
            return true
        }
        return false
    }
    
    public func revokeDevice(deviceId: String) {
        lock.lock()
        defer { lock.unlock() }
        if var device = devices[deviceId] {
            device.isRevoked = true
            devices[deviceId] = device
            saveDevices()
            AppLogger.shared.log("Device revoked: \(device.deviceName) (\(deviceId))")
        }
    }
    
    public func forgetAllDevices() {
        lock.lock()
        defer { lock.unlock() }
        devices.removeAll()
        saveDevices()
        AppLogger.shared.log("All devices forgotten")
    }
    
    public func getDevices() -> [PairedDevice] {
        lock.lock()
        defer { lock.unlock() }
        return Array(devices.values).sorted(by: { $0.lastSeen > $1.lastSeen })
    }
    
    private func saveDevices() {
        if let data = try? JSONEncoder().encode(devices) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
    
    private func loadDevices() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let loaded = try? JSONDecoder().decode([String: PairedDevice].self, from: data) {
            devices = loaded
        }
    }
}
