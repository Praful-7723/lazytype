import Foundation

public struct NetworkInterfaceHelper {
    public static func getLocalIPAddress() -> String {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return "127.0.0.1" }
        guard let firstAddr = ifaddr else { return "127.0.0.1" }
        
        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let flags = Int32(ptr.pointee.ifa_flags)
            let addr = ptr.pointee.ifa_addr.pointee
            
            // Check for IPv4
            if addr.sa_family == UInt8(AF_INET) {
                // Must be up, running, and not loopback
                if (flags & (IFF_UP | IFF_RUNNING | IFF_LOOPBACK)) == (IFF_UP | IFF_RUNNING) {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    if getnameinfo(ptr.pointee.ifa_addr, socklen_t(addr.sa_len), &hostname, socklen_t(hostname.count), nil, socklen_t(0), NI_NUMERICHOST) == 0 {
                        let ip = String(cString: hostname)
                        let ifName = String(cString: ptr.pointee.ifa_name)
                        // Prefer en0 (default Wi-Fi on Mac)
                        if ifName == "en0" {
                            freeifaddrs(ifaddr)
                            return ip
                        }
                        if address == nil {
                            address = ip
                        }
                    }
                }
            }
        }
        freeifaddrs(ifaddr)
        return address ?? "127.0.0.1"
    }
    
    public static func getMacComputerName() -> String {
        return Host.current().localizedName ?? "My Mac"
    }
}
