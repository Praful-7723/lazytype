import Foundation
import CommonCrypto
import Darwin

public final class LocalServer: @unchecked Sendable {
    public static let shared = LocalServer()
    
    public var port: UInt16 = 9123
    private var listenSocket: Int32 = -1
    private var listenSource: DispatchSourceRead?
    private let serverQueue = DispatchQueue(label: "com.lazytype.localserver", attributes: .concurrent)
    
    // Connected clients
    private var phoneClients: [Int32: PhoneClientConnection] = [:]
    private var extensionClient: ExtensionClientConnection?
    private let clientLock = NSLock()
    
    // Base directory for static files
    public var staticRootPath: String = ""
    public var demoHtmlPath: String = ""
    public var onboardingHtmlPath: String = ""
    
    private init() {
        findDefaultPaths()
        setupAdapterLink()
    }
    
    private func findDefaultPaths() {
        let cwd = FileManager.default.currentDirectoryPath
        let resPath = Bundle.main.resourcePath
        
        var possiblePublics: [String] = []
        if let res = resPath {
            possiblePublics.append(res + "/phone/public")
            possiblePublics.append(res + "/public")
        }
        possiblePublics.append(contentsOf: [
            cwd + "/phone/public",
            cwd + "/public",
            "/Volumes/ExternalSSD/Projects/lazytype/phone/public"
        ])
        
        for p in possiblePublics {
            if FileManager.default.fileExists(atPath: p + "/index.html") {
                staticRootPath = p
                break
            }
        }
        
        var possibleDemos: [String] = []
        if let res = resPath {
            possibleDemos.append(res + "/demo/demo.html")
            possibleDemos.append(res + "/demo.html")
        }
        possibleDemos.append(contentsOf: [
            cwd + "/demo/demo.html",
            cwd + "/demo.html",
            "/Volumes/ExternalSSD/Projects/lazytype/demo/demo.html"
        ])
        
        for d in possibleDemos {
            if FileManager.default.fileExists(atPath: d) {
                demoHtmlPath = d
                break
            }
        }
        
        var possibleGuides: [String] = []
        if let res = resPath {
            possibleGuides.append(res + "/START_HERE_Onboarding_Guide.html")
            possibleGuides.append(res + "/Onboarding_Guide.html")
        }
        possibleGuides.append(contentsOf: [
            cwd + "/dist/START_HERE_Onboarding_Guide.html",
            cwd + "/dist/Onboarding_Guide.html",
            cwd + "/mac/Resources/Onboarding_Guide.html",
            "/Volumes/ExternalSSD/Projects/lazytype/dist/START_HERE_Onboarding_Guide.html",
            "/Volumes/ExternalSSD/Projects/lazytype/dist/Onboarding_Guide.html",
            "/Volumes/ExternalSSD/Projects/lazytype/mac/Resources/Onboarding_Guide.html"
        ])
        
        for g in possibleGuides {
            if FileManager.default.fileExists(atPath: g) {
                onboardingHtmlPath = g
                break
            }
        }
    }
    
    private func setupAdapterLink() {
        AdapterRegistry.shared.browserBridgeAdapter.sendCommandToExtension = { [weak self] cmd, completion in
            guard let self = self else { return }
            self.sendToExtension(cmd: cmd, completion: completion)
        }
    }
    
    public func start(port: UInt16 = 8765) throws {
        self.port = port
        
        listenSocket = socket(AF_INET, SOCK_STREAM, 0)
        guard listenSocket >= 0 else {
            throw NSError(domain: "LocalServer", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create socket"])
        }
        
        var opt: Int32 = 1
        setsockopt(listenSocket, SOL_SOCKET, SO_REUSEADDR, &opt, socklen_t(MemoryLayout<Int32>.size))
        
        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr.s_addr = INADDR_ANY.bigEndian
        
        let bindResult = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(listenSocket, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        
        guard bindResult == 0 else {
            close(listenSocket)
            listenSocket = -1
            throw NSError(domain: "LocalServer", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to bind to port \(port)"])
        }
        
        guard listen(listenSocket, 20) == 0 else {
            close(listenSocket)
            listenSocket = -1
            throw NSError(domain: "LocalServer", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to listen"])
        }
        
        let source = DispatchSource.makeReadSource(fileDescriptor: listenSocket, queue: serverQueue)
        source.setEventHandler { [weak self] in
            self?.acceptConnections()
        }
        source.resume()
        listenSource = source
        
        AppLogger.shared.log("LocalServer listening on port \(port) (IP: \(NetworkInterfaceHelper.getLocalIPAddress()))")
    }
    
    public func stop() {
        listenSource?.cancel()
        listenSource = nil
        if listenSocket >= 0 {
            close(listenSocket)
            listenSocket = -1
        }
        
        clientLock.lock()
        for client in phoneClients.values {
            client.close()
        }
        phoneClients.removeAll()
        extensionClient?.close()
        extensionClient = nil
        clientLock.unlock()
    }
    
    private func acceptConnections() {
        var clientAddr = sockaddr_in()
        var addrLen = socklen_t(MemoryLayout<sockaddr_in>.size)
        
        let clientFd = withUnsafeMutablePointer(to: &clientAddr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                accept(listenSocket, $0, &addrLen)
            }
        }
        guard clientFd >= 0 else { return }
        
        serverQueue.async { [weak self] in
            self?.handleInitialRequest(fd: clientFd)
        }
    }
    
    // MARK: - HTTP & WebSocket Dispatch
    private func handleInitialRequest(fd: Int32) {
        var buffer = [UInt8](repeating: 0, count: 4096)
        let bytesRead = read(fd, &buffer, buffer.count)
        guard bytesRead > 0 else {
            close(fd)
            return
        }
        
        let requestData = Data(buffer[0..<bytesRead])
        guard let requestString = String(data: requestData, encoding: .utf8) else {
            close(fd)
            return
        }
        
        let lines = requestString.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else {
            close(fd)
            return
        }
        let parts = requestLine.components(separatedBy: " ")
        guard parts.count >= 2 else {
            close(fd)
            return
        }
        
        let method = parts[0]
        let rawPath = parts[1]
        let path = rawPath.components(separatedBy: "?").first ?? rawPath
        
        // Parse headers
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            if line.isEmpty { break }
            let pair = line.split(separator: ":", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespaces) }
            if pair.count == 2 {
                headers[pair[0].lowercased()] = pair[1]
            }
        }
        
        // Check for WebSocket upgrade
        let isUpgrade = (headers["upgrade"]?.lowercased() == "websocket")
        if isUpgrade, let secKey = headers["sec-websocket-key"] {
            handleWebSocketUpgrade(fd: fd, path: path, secKey: secKey, query: rawPath)
            return
        }
        
        // Standard HTTP request
        if method == "GET" {
            handleHttpGet(fd: fd, path: path, rawQuery: rawPath)
        } else {
            sendHttpResponse(fd: fd, status: 405, statusText: "Method Not Allowed", body: Data())
        }
    }
    
    // MARK: - HTTP Handler
    private func handleHttpGet(fd: Int32, path: String, rawQuery: String) {
        if path == "/demo" || path == "/demo.html" {
            serveFile(fd: fd, filePath: demoHtmlPath, defaultContentType: "text/html; charset=utf-8")
            return
        }
        
        if path == "/guide" || path == "/onboarding" || path == "/guide.html" || path == "/start" {
            serveFile(fd: fd, filePath: onboardingHtmlPath, defaultContentType: "text/html; charset=utf-8")
            return
        }
        
        if path == "/qr.png" {
            let pairUrl = PairingManager.shared.getPairingURL(port: Int(self.port))
            if let png = QRGenerator.generateQRCodePNG(from: pairUrl) {
                sendHttpResponse(fd: fd, status: 200, statusText: "OK", contentType: "image/png", body: png)
            } else {
                sendHttpResponse(fd: fd, status: 500, statusText: "QR Error", body: Data("QR generation failed".utf8))
            }
            return
        }
        
        if path == "/api/status" {
            Task {
                let status = await AdapterRegistry.shared.getCurrentStatus()
                if let data = try? JSONEncoder().encode(status) {
                    self.sendHttpResponse(fd: fd, status: 200, statusText: "OK", contentType: "application/json", body: data)
                }
            }
            return
        }
        
        if path == "/api/pair-token" {
            let token = PairingManager.shared.getActivePairingToken()
            let pairUrl = PairingManager.shared.getPairingURL(port: Int(self.port))
            let json = "{\"token\":\"\(token)\",\"url\":\"\(pairUrl)\"}"
            sendHttpResponse(fd: fd, status: 200, statusText: "OK", contentType: "application/json", body: Data(json.utf8))
            return
        }
        
        // Static PWA Files
        var relPath = path
        if relPath == "/" || relPath.isEmpty {
            relPath = "/index.html"
        }
        let fullPath = staticRootPath + relPath
        let contentType = mimeTypeForPath(relPath)
        serveFile(fd: fd, filePath: fullPath, defaultContentType: contentType)
    }
    
    private func serveFile(fd: Int32, filePath: String, defaultContentType: String) {
        guard FileManager.default.fileExists(atPath: filePath),
              let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)) else {
            sendHttpResponse(fd: fd, status: 404, statusText: "Not Found", body: Data("404 Not Found".utf8))
            return
        }
        sendHttpResponse(fd: fd, status: 200, statusText: "OK", contentType: defaultContentType, body: data)
    }
    
    private func sendHttpResponse(fd: Int32, status: Int, statusText: String, contentType: String = "text/plain", body: Data) {
        var header = "HTTP/1.1 \(status) \(statusText)\r\n"
        header += "Content-Type: \(contentType)\r\n"
        header += "Content-Length: \(body.count)\r\n"
        header += "Access-Control-Allow-Origin: *\r\n"
        header += "Connection: close\r\n\r\n"
        
        var responseData = Data(header.utf8)
        responseData.append(body)
        _ = responseData.withUnsafeBytes { buffer in
            write(fd, buffer.baseAddress, buffer.count)
        }
        close(fd)
    }
    
    private func mimeTypeForPath(_ path: String) -> String {
        if path.hasSuffix(".html") { return "text/html; charset=utf-8" }
        if path.hasSuffix(".js") { return "application/javascript; charset=utf-8" }
        if path.hasSuffix(".css") { return "text/css; charset=utf-8" }
        if path.hasSuffix(".json") { return "application/json" }
        if path.hasSuffix(".png") { return "image/png" }
        if path.hasSuffix(".svg") { return "image/svg+xml" }
        if path.hasSuffix(".wasm") { return "application/wasm" }
        if path.hasSuffix(".riv") { return "application/octet-stream" }
        return "application/octet-stream"
    }
    
    // MARK: - WebSocket Handshake & Routing
    private func handleWebSocketUpgrade(fd: Int32, path: String, secKey: String, query: String) {
        let accept = computeWebSocketAccept(key: secKey)
        let response = "HTTP/1.1 101 Switching Protocols\r\n" +
                       "Upgrade: websocket\r\n" +
                       "Connection: Upgrade\r\n" +
                       "Sec-WebSocket-Accept: \(accept)\r\n\r\n"
        
        _ = response.withCString { ptr in
            write(fd, ptr, strlen(ptr))
        }
        
        if path.contains("/ws/extension") {
            let extConn = ExtensionClientConnection(fd: fd)
            clientLock.lock()
            extensionClient?.close()
            extensionClient = extConn
            AdapterRegistry.shared.browserBridgeAdapter.isExtensionConnected = true
            clientLock.unlock()
            
            AppLogger.shared.log("Chrome Extension connected via WebSocket")
            extConn.startReading { [weak self] message in
                self?.handleExtensionMessage(message)
            } onDisconnect: { [weak self] in
                self?.clientLock.lock()
                self?.extensionClient = nil
                AdapterRegistry.shared.browserBridgeAdapter.isExtensionConnected = false
                self?.clientLock.unlock()
                AppLogger.shared.log("Chrome Extension disconnected")
            }
        } else {
            // Phone client
            let phoneConn = PhoneClientConnection(fd: fd)
            clientLock.lock()
            phoneClients[fd] = phoneConn
            clientLock.unlock()
            
            AppLogger.shared.log("Phone client connected (fd: \(fd))")
            phoneConn.startReading { [weak self] message in
                self?.handlePhoneMessage(client: phoneConn, msg: message)
            } onDisconnect: { [weak self] in
                self?.clientLock.lock()
                self?.phoneClients.removeValue(forKey: fd)
                self?.clientLock.unlock()
                AppLogger.shared.log("Phone client disconnected (fd: \(fd))")
            }
        }
    }
    
    private func computeWebSocketAccept(key: String) -> String {
        let magic = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
        let full = key + magic
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        if let data = full.data(using: .utf8) {
            data.withUnsafeBytes { buffer in
                _ = CC_SHA1(buffer.baseAddress, CC_LONG(buffer.count), &hash)
            }
        }
        return Data(hash).base64EncodedString()
    }
    
    // MARK: - Phone Protocol Handling
    private func handlePhoneMessage(client: PhoneClientConnection, msg: IncomingMessage) {
        AppLogger.shared.debug("Received phone message: \(msg.type)")
        
        switch msg.type {
        case "PAIR":
            guard let token = msg.token, let deviceId = msg.deviceId else {
                client.sendJSON(PairResultResponse(requestId: msg.requestId, success: false, errorCode: "MISSING_FIELDS", message: "Token and DeviceId required"))
                return
            }
            if PairingManager.shared.validatePairingToken(token) {
                let sessionToken = PairingManager.shared.createSessionToken()
                let devName = msg.deviceName ?? "Mobile Phone"
                DeviceStore.shared.addOrUpdateDevice(deviceId: deviceId, deviceName: devName, sessionToken: sessionToken)
                client.isAuthorized = true
                client.deviceId = deviceId
                client.deviceName = devName
                client.sendJSON(PairResultResponse(
                    requestId: msg.requestId,
                    success: true,
                    sessionToken: sessionToken,
                    macName: NetworkInterfaceHelper.getMacComputerName(),
                    message: "Paired successfully"
                ))
            } else {
                client.sendJSON(PairResultResponse(
                    requestId: msg.requestId,
                    success: false,
                    errorCode: "INVALID_TOKEN",
                    message: "Pairing token is invalid or expired"
                ))
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) {
                    client.close()
                }
            }
            
        case "AUTH":
            guard let devId = msg.deviceId, let sess = msg.sessionToken else {
                client.sendJSON(AuthResultResponse(requestId: msg.requestId, success: false, errorCode: "UNAUTHORIZED", message: "Missing auth details"))
                return
            }
            if DeviceStore.shared.isValidSession(deviceId: devId, sessionToken: sess) {
                client.isAuthorized = true
                client.deviceId = devId
                client.deviceName = msg.deviceName ?? "Mobile Phone"
                client.sendJSON(AuthResultResponse(
                    requestId: msg.requestId,
                    success: true,
                    macName: NetworkInterfaceHelper.getMacComputerName(),
                    message: "Authorized"
                ))
            } else {
                client.sendJSON(AuthResultResponse(
                    requestId: msg.requestId,
                    success: false,
                    errorCode: "UNAUTHORIZED",
                    message: "Session is invalid or revoked"
                ))
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) {
                    client.close()
                }
            }
            
        case "GET_STATUS":
            guard client.isAuthorized else {
                sendUnauthorized(client: client, reqId: msg.requestId)
                return
            }
            Task {
                let status = await AdapterRegistry.shared.getCurrentStatus()
                // Stamp request id
                let resp = StatusResponse(
                    requestId: msg.requestId,
                    macName: status.macName,
                    activeApplication: status.activeApplication,
                    adapter: status.adapter,
                    meetingDetected: status.meetingDetected,
                    chatAvailable: status.chatAvailable,
                    chatOpen: status.chatOpen,
                    canSendMessage: status.canSendMessage,
                    canMute: status.canMute,
                    canControlCamera: status.canControlCamera,
                    isMuted: status.isMuted,
                    browserExtensionConnected: status.browserExtensionConnected
                )
                client.sendJSON(resp)
            }
            
        case "LIVE_INPUT":
            guard client.isAuthorized else { return }
            let text = msg.text ?? ""
            Task {
                let adapter = AdapterRegistry.shared.resolveAdapter(targetHint: msg.target)
                let frontApp = AppDetector.getFrontmostApp()
                _ = await adapter.insertText(text: text, app: frontApp)
            }

        case "SEND_MESSAGE":
            guard client.isAuthorized else {
                sendUnauthorized(client: client, reqId: msg.requestId)
                return
            }
            let text = msg.text ?? ""
            Task {
                let adapter = AdapterRegistry.shared.resolveAdapter(targetHint: msg.target)
                let frontApp = AppDetector.getFrontmostApp()
                var result = await adapter.sendMessage(text: text, app: frontApp)
                
                // Only fall back to generic keyboard if target was explicitly specified as "generic"
                if case .failure = result, msg.target == "generic" {
                    AppLogger.shared.info("Explicit generic target requested, attempting generic keyboard fallback")
                    let fallbackResult = await AdapterRegistry.shared.genericAdapter.sendMessage(text: text, app: frontApp)
                    if case .success = fallbackResult {
                        result = fallbackResult
                    }
                }

                switch result {
                case .success(let act):
                    client.sendJSON(CommandResultResponse(
                        requestId: msg.requestId,
                        success: true,
                        target: act.adapterId,
                        action: "SEND_MESSAGE",
                        message: act.message
                    ))
                case .failure(let err):
                    client.sendJSON(CommandResultResponse(
                        requestId: msg.requestId,
                        success: false,
                        target: adapter.adapterId,
                        action: "SEND_MESSAGE",
                        errorCode: err.code,
                        message: err.localizedDescription
                    ))
                }
            }
            
        case "INSERT_TEXT":
            guard client.isAuthorized else {
                sendUnauthorized(client: client, reqId: msg.requestId)
                return
            }
            let text = msg.text ?? ""
            Task {
                let adapter = AdapterRegistry.shared.resolveAdapter(targetHint: msg.target)
                let frontApp = AppDetector.getFrontmostApp()
                var result = await adapter.insertText(text: text, app: frontApp)
                
                if case .failure = result, (msg.target == nil || msg.target == "auto"), adapter.adapterId != "generic" {
                    let fallbackResult = await AdapterRegistry.shared.genericAdapter.insertText(text: text, app: frontApp)
                    if case .success = fallbackResult {
                        result = fallbackResult
                    }
                }

                switch result {
                case .success(let act):
                    client.sendJSON(CommandResultResponse(requestId: msg.requestId, success: true, target: act.adapterId, action: "INSERT_TEXT", message: act.message))
                case .failure(let err):
                    client.sendJSON(CommandResultResponse(requestId: msg.requestId, success: false, target: adapter.adapterId, action: "INSERT_TEXT", errorCode: err.code, message: err.localizedDescription))
                }
            }
            
        case "OPEN_CHAT":
            guard client.isAuthorized else {
                sendUnauthorized(client: client, reqId: msg.requestId)
                return
            }
            Task {
                let adapter = AdapterRegistry.shared.resolveAdapter(targetHint: msg.target)
                let frontApp = AppDetector.getFrontmostApp()
                let result = await adapter.openChat(app: frontApp)
                switch result {
                case .success(let act):
                    client.sendJSON(CommandResultResponse(requestId: msg.requestId, success: true, target: act.adapterId, action: "OPEN_CHAT", message: act.message))
                case .failure(let err):
                    client.sendJSON(CommandResultResponse(requestId: msg.requestId, success: false, target: adapter.adapterId, action: "OPEN_CHAT", errorCode: err.code, message: err.localizedDescription))
                }
            }
            
        case "TOGGLE_MUTE":
            guard client.isAuthorized else {
                sendUnauthorized(client: client, reqId: msg.requestId)
                return
            }
            Task {
                let adapter = AdapterRegistry.shared.resolveAdapter(targetHint: msg.target)
                let frontApp = AppDetector.getFrontmostApp()
                let result = await adapter.toggleMute(app: frontApp)
                switch result {
                case .success(let act):
                    client.sendJSON(CommandResultResponse(requestId: msg.requestId, success: true, target: act.adapterId, action: "TOGGLE_MUTE", message: act.message))
                case .failure(let err):
                    client.sendJSON(CommandResultResponse(requestId: msg.requestId, success: false, target: adapter.adapterId, action: "TOGGLE_MUTE", errorCode: err.code, message: err.localizedDescription))
                }
            }
            
        case "TOGGLE_CAMERA":
            guard client.isAuthorized else {
                sendUnauthorized(client: client, reqId: msg.requestId)
                return
            }
            Task {
                let adapter = AdapterRegistry.shared.resolveAdapter(targetHint: msg.target)
                let frontApp = AppDetector.getFrontmostApp()
                let result = await adapter.toggleCamera(app: frontApp)
                switch result {
                case .success(let act):
                    client.sendJSON(CommandResultResponse(requestId: msg.requestId, success: true, target: act.adapterId, action: "TOGGLE_CAMERA", message: act.message))
                case .failure(let err):
                    client.sendJSON(CommandResultResponse(requestId: msg.requestId, success: false, target: adapter.adapterId, action: "TOGGLE_CAMERA", errorCode: err.code, message: err.localizedDescription))
                }
            }
            
        case "PRESS_KEY":
            guard client.isAuthorized else {
                sendUnauthorized(client: client, reqId: msg.requestId)
                return
            }
            let key = msg.key ?? "Enter"
            let mods = msg.modifiers ?? []
            Task {
                let adapter = AdapterRegistry.shared.resolveAdapter(targetHint: msg.target)
                let frontApp = AppDetector.getFrontmostApp()
                let result = await adapter.pressKey(key: key, modifiers: mods, app: frontApp)
                switch result {
                case .success(let act):
                    client.sendJSON(CommandResultResponse(requestId: msg.requestId, success: true, target: act.adapterId, action: "PRESS_KEY", message: act.message))
                case .failure(let err):
                    client.sendJSON(CommandResultResponse(requestId: msg.requestId, success: false, target: adapter.adapterId, action: "PRESS_KEY", errorCode: err.code, message: err.localizedDescription))
                }
            }
            
        default:
            client.sendJSON(CommandResultResponse(
                requestId: msg.requestId,
                success: false,
                errorCode: "UNKNOWN_COMMAND",
                message: "Command '\(msg.type)' is not recognized"
            ))
        }
    }
    
    private func sendUnauthorized(client: PhoneClientConnection, reqId: String?) {
        client.sendJSON(CommandResultResponse(
            requestId: reqId,
            success: false,
            errorCode: "UNAUTHORIZED",
            message: "Device not authorized. Please pair first."
        ))
    }
    
    // MARK: - Extension Protocol Handling
    private func handleExtensionMessage(_ msg: IncomingMessage) {
        if msg.type == "EXT_TAB_STATE" {
            AdapterRegistry.shared.browserBridgeAdapter.lastReportedState = msg
            // Broadcast status update to connected phones
            broadcastStatusToPhones()
        } else if msg.type == "COMMAND_RESULT" {
            // Forwarded to pending continuation
            if let reqId = msg.requestId {
                extensionPendingRequestsLock.lock()
                let completion = extensionPendingRequests.removeValue(forKey: reqId)
                extensionPendingRequestsLock.unlock()
                
                if let completion = completion {
                    completion(CommandResultResponse(
                        requestId: reqId,
                        success: msg.success ?? false,
                        target: msg.adapter,
                        action: msg.type,
                        errorCode: msg.errorCode,
                        message: msg.message
                    ))
                }
            }
        }
    }
    
    private var extensionPendingRequests: [String: (CommandResultResponse) -> Void] = [:]
    private let extensionPendingRequestsLock = NSLock()
    
    private func sendToExtension(cmd: ExtensionCommandRequest, completion: @escaping @Sendable (CommandResultResponse) -> Void) {
        clientLock.lock()
        guard let ext = extensionClient else {
            clientLock.unlock()
            completion(CommandResultResponse(requestId: cmd.requestId, success: false, errorCode: "EXTENSION_DISCONNECTED", message: "Chrome extension is not connected"))
            return
        }
        clientLock.unlock()
        
        extensionPendingRequestsLock.lock()
        extensionPendingRequests[cmd.requestId] = completion
        extensionPendingRequestsLock.unlock()
        
        ext.sendJSON(cmd)
        
        // 5s timeout
        DispatchQueue.global().asyncAfter(deadline: .now() + 5.0) { [weak self] in
            guard let self = self else { return }
            self.extensionPendingRequestsLock.lock()
            let timedOut = self.extensionPendingRequests.removeValue(forKey: cmd.requestId)
            self.extensionPendingRequestsLock.unlock()
            
            if let cb = timedOut {
                cb(CommandResultResponse(requestId: cmd.requestId, success: false, errorCode: "TIMEOUT", message: "Extension command timed out"))
            }
        }
    }
    
    public func broadcastStatusToPhones() {
        clientLock.lock()
        let clients = Array(phoneClients.values.filter { $0.isAuthorized })
        clientLock.unlock()
        
        guard !clients.isEmpty else { return }
        
        Task {
            let status = await AdapterRegistry.shared.getCurrentStatus()
            for client in clients {
                client.sendJSON(status)
            }
        }
    }
}

// MARK: - Phone Connection Class
public final class PhoneClientConnection: @unchecked Sendable {
    public let fd: Int32
    public var isAuthorized: Bool = false
    public var deviceId: String = ""
    public var deviceName: String = ""
    private var isClosed = false
    private let lock = NSLock()
    
    public init(fd: Int32) {
        self.fd = fd
    }
    
    public func startReading(onMessage: @escaping (IncomingMessage) -> Void, onDisconnect: @escaping () -> Void) {
        DispatchQueue.global().async { [weak self] in
            guard let self = self else { return }
            while !self.isClosed {
                guard let data = self.readWebSocketFrame() else {
                    break
                }
                if let msg = try? JSONDecoder().decode(IncomingMessage.self, from: data) {
                    onMessage(msg)
                }
            }
            self.close()
            onDisconnect()
        }
    }
    
    public func sendJSON<T: Encodable>(_ object: T) {
        guard let data = try? JSONEncoder().encode(object),
              let string = String(data: data, encoding: .utf8) else {
            return
        }
        sendTextFrame(string)
    }
    
    public func sendTextFrame(_ text: String) {
        lock.lock()
        defer { lock.unlock() }
        guard !isClosed else { return }
        
        let payload = Array(text.utf8)
        var frame = [UInt8]()
        frame.append(0x81) // FIN + text opcode
        
        if payload.count <= 125 {
            frame.append(UInt8(payload.count))
        } else if payload.count <= 65535 {
            frame.append(126)
            let len = UInt16(payload.count)
            frame.append(UInt8((len >> 8) & 0xff))
            frame.append(UInt8(len & 0xff))
        } else {
            frame.append(127)
            let len = UInt64(payload.count)
            for i in stride(from: 56, through: 0, by: -8) {
                frame.append(UInt8((len >> i) & 0xff))
            }
        }
        
        frame.append(contentsOf: payload)
        _ = frame.withUnsafeBytes { buffer in
            write(fd, buffer.baseAddress, buffer.count)
        }
    }
    
    private func readExact(count: Int) -> [UInt8]? {
        var buffer = [UInt8](repeating: 0, count: count)
        var readSoFar = 0
        while readSoFar < count {
            let res = read(fd, &buffer[readSoFar], count - readSoFar)
            if res <= 0 { return nil }
            readSoFar += res
        }
        return buffer
    }
    
    private func readWebSocketFrame() -> Data? {
        guard let b1 = readExact(count: 2) else { return nil }
        let opcode = b1[0] & 0x0f
        if opcode == 0x8 { // Connection close
            return nil
        }
        
        let isMasked = (b1[1] & 0x80) != 0
        var payloadLen = Int(b1[1] & 0x7f)
        
        if payloadLen == 126 {
            guard let lenBytes = readExact(count: 2) else { return nil }
            payloadLen = Int(UInt16(lenBytes[0]) << 8 | UInt16(lenBytes[1]))
        } else if payloadLen == 127 {
            guard let lenBytes = readExact(count: 8) else { return nil }
            var len: UInt64 = 0
            for b in lenBytes { len = (len << 8) | UInt64(b) }
            payloadLen = Int(len)
        }
        
        var maskKey = [UInt8]()
        if isMasked {
            guard let key = readExact(count: 4) else { return nil }
            maskKey = key
        }
        
        guard let payloadBytes = readExact(count: payloadLen) else { return nil }
        var unmasked = payloadBytes
        if isMasked {
            for i in 0..<payloadLen {
                unmasked[i] ^= maskKey[i % 4]
            }
        }
        
        return Data(unmasked)
    }
    
    public func close() {
        lock.lock()
        defer { lock.unlock() }
        if !isClosed {
            isClosed = true
            Darwin.close(fd)
        }
    }
}

// MARK: - Extension Connection Class
public final class ExtensionClientConnection: @unchecked Sendable {
    public let fd: Int32
    private var isClosed = false
    private let lock = NSLock()
    
    public init(fd: Int32) {
        self.fd = fd
    }
    
    public func startReading(onMessage: @escaping (IncomingMessage) -> Void, onDisconnect: @escaping () -> Void) {
        DispatchQueue.global().async { [weak self] in
            guard let self = self else { return }
            while !self.isClosed {
                guard let data = self.readWebSocketFrame() else {
                    break
                }
                if let msg = try? JSONDecoder().decode(IncomingMessage.self, from: data) {
                    onMessage(msg)
                }
            }
            self.close()
            onDisconnect()
        }
    }
    
    public func sendJSON<T: Encodable>(_ object: T) {
        guard let data = try? JSONEncoder().encode(object),
              let string = String(data: data, encoding: .utf8) else {
            return
        }
        sendTextFrame(string)
    }
    
    public func sendTextFrame(_ text: String) {
        lock.lock()
        defer { lock.unlock() }
        guard !isClosed else { return }
        
        let payload = Array(text.utf8)
        var frame = [UInt8]()
        frame.append(0x81) // FIN + text opcode
        
        if payload.count <= 125 {
            frame.append(UInt8(payload.count))
        } else if payload.count <= 65535 {
            frame.append(126)
            let len = UInt16(payload.count)
            frame.append(UInt8((len >> 8) & 0xff))
            frame.append(UInt8(len & 0xff))
        } else {
            frame.append(127)
            let len = UInt64(payload.count)
            for i in stride(from: 56, through: 0, by: -8) {
                frame.append(UInt8((len >> i) & 0xff))
            }
        }
        
        frame.append(contentsOf: payload)
        _ = frame.withUnsafeBytes { buffer in
            write(fd, buffer.baseAddress, buffer.count)
        }
    }
    
    private func readExact(count: Int) -> [UInt8]? {
        var buffer = [UInt8](repeating: 0, count: count)
        var readSoFar = 0
        while readSoFar < count {
            let res = read(fd, &buffer[readSoFar], count - readSoFar)
            if res <= 0 { return nil }
            readSoFar += res
        }
        return buffer
    }
    
    private func readWebSocketFrame() -> Data? {
        guard let b1 = readExact(count: 2) else { return nil }
        let opcode = b1[0] & 0x0f
        if opcode == 0x8 { return nil }
        
        let isMasked = (b1[1] & 0x80) != 0
        var payloadLen = Int(b1[1] & 0x7f)
        
        if payloadLen == 126 {
            guard let lenBytes = readExact(count: 2) else { return nil }
            payloadLen = Int(UInt16(lenBytes[0]) << 8 | UInt16(lenBytes[1]))
        } else if payloadLen == 127 {
            guard let lenBytes = readExact(count: 8) else { return nil }
            var len: UInt64 = 0
            for b in lenBytes { len = (len << 8) | UInt64(b) }
            payloadLen = Int(len)
        }
        
        var maskKey = [UInt8]()
        if isMasked {
            guard let key = readExact(count: 4) else { return nil }
            maskKey = key
        }
        
        guard let payloadBytes = readExact(count: payloadLen) else { return nil }
        var unmasked = payloadBytes
        if isMasked {
            for i in 0..<payloadLen {
                unmasked[i] ^= maskKey[i % 4]
            }
        }
        
        return Data(unmasked)
    }
    
    public func close() {
        lock.lock()
        defer { lock.unlock() }
        if !isClosed {
            isClosed = true
            Darwin.close(fd)
        }
    }
}
