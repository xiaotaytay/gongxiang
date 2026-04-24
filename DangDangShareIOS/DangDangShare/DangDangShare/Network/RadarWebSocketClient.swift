import Foundation

enum ConnectionState {
    case disconnected
    case connecting
    case connected
}

@MainActor
class RadarWebSocketClient: NSObject, URLSessionWebSocketDelegate {
    var onConnected: (() -> Void)?
    var onDisconnected: ((String) -> Void)?
    var onError: ((String) -> Void)?
    var onHomeData: ((String) -> Void)?
    var onGameData: ((String) -> Void)?
    var onHeartbeatAck: ((TimeInterval) -> Void)?
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var serverHost: String
    private var serverPort: Int
    private var roomId: String?
    private var viewerId: String
    private var subscribed = false
    private var intentionalClose = false
    private var reconnectAttempts = 0
    private var state: ConnectionState = .disconnected
    private var heartbeatTimer: Timer?
    private var roomRefreshTimer: Timer?
    private var reconnectTimer: Timer?
    private var lastHeartbeatTime: TimeInterval = 0
    
    private var currentGameData: String?
    private var heroStateMap: [Int32: HeroState] = [:]
    
    private struct HeroState {
        var raw: String
        var fields: [String]
        var x: Float
        var y: Float
        var index: Int
    }
    
    init(host: String, port: Int) {
        self.serverHost = host
        self.serverPort = port
        self.viewerId = "ios_\(String(UInt64(Date().timeIntervalSince1970 * 1000), radix: 16))_\(Int.random(in: 0...9999))"
        super.init()
    }
    
    var isConnected: Bool { state == .connected }
    var isConnecting: Bool { state == .connecting }
    
    func connect() {
        guard state == .disconnected else { return }
        state = .connecting
        intentionalClose = false
        reconnectAttempts = 0
        
        let url = URL(string: "ws://\(serverHost):\(serverPort)/ws2")!
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = ProtocolConstants.connectTimeout
        config.waitsForConnectivity = true
        urlSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        webSocketTask = urlSession?.webSocketTask(with: url)
        webSocketTask?.resume()
    }
    
    func disconnect() {
        intentionalClose = true
        state = .disconnected
        stopTimers()
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil
        subscribed = false
        currentGameData = nil
        heroStateMap = [:]
    }
    
    func setRoomId(_ roomId: String?) {
        self.roomId = roomId
        self.subscribed = false
        self.heroStateMap = [:]
        if state == .connected, let roomId = roomId, !roomId.isEmpty {
            subscribeToRoom()
        }
    }
    
    private func subscribeToRoom() {
        guard let roomId = roomId, !roomId.isEmpty, !subscribed else { return }
        subscribed = true
        let frame = BinaryFrame.createViewerRegister(clientId: viewerId, targetClientId: roomId)
        sendFrame(frame)
    }
    
    private func requestRoomList() {
        sendFrame(BinaryFrame.createGetHome())
    }
    
    private func sendFrame(_ frame: BinaryFrame) {
        guard let task = webSocketTask, state == .connected else { return }
        let data = frame.encode()
        task.send(.data(data)) { [weak self] error in
            if let error = error {
                Task { @MainActor in
                    self?.handleDisconnect("发送失败: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func startHeartbeat() {
        stopHeartbeat()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: ProtocolConstants.heartbeatIntervalMs, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                if self.state == .connected {
                    self.lastHeartbeatTime = Date().timeIntervalSince1970 * 1000
                    self.sendFrame(BinaryFrame.createHeartbeat())
                }
            }
        }
    }
    
    private func stopHeartbeat() { heartbeatTimer?.invalidate(); heartbeatTimer = nil }
    private func stopRoomRefresh() { roomRefreshTimer?.invalidate(); roomRefreshTimer = nil }
    private func stopTimers() { stopHeartbeat(); stopRoomRefresh(); reconnectTimer?.invalidate(); reconnectTimer = nil }
    
    private func startRoomRefresh() {
        stopRoomRefresh()
        roomRefreshTimer = Timer.scheduledTimer(withTimeInterval: ProtocolConstants.roomRefreshIntervalMs, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                if self.state == .connected { self.requestRoomList() }
            }
        }
    }
    
    nonisolated func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        Task { @MainActor in
            self.state = .connected
            self.reconnectAttempts = 0
            self.onConnected?()
            self.requestRoomList()
            self.startHeartbeat()
            self.startRoomRefresh()
            if let roomId = self.roomId, !roomId.isEmpty {
                self.subscribeToRoom()
            }
            self.receiveMessages()
        }
    }
    
    nonisolated func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        Task { @MainActor in
            self.handleDisconnect("连接关闭")
        }
    }
    
    private func receiveMessages() {
        guard let task = webSocketTask else { return }
        task.receive { [weak self] result in
            guard let self = self else { return }
            Task { @MainActor in
                switch result {
                case .success(let message):
                    switch message {
                    case .data(let data):
                        self.processData(data)
                    case .string:
                        break
                    @unknown default:
                        break
                    }
                    if self.state == .connected {
                        self.receiveMessages()
                    }
                case .failure(let error):
                    if !self.intentionalClose {
                        self.handleDisconnect("接收失败: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    private func processData(_ data: Data) {
        guard let frame = BinaryFrame.decode(data) else { return }
        Task { @MainActor in
            switch frame.type {
            case ProtocolConstants.typeHomeData:
                if let str = frame.roomListStr { self.onHomeData?(str) }
            case ProtocolConstants.typeGameDataResponse:
                if (frame.flag & ProtocolConstants.flagIncremental) != 0 {
                    if let deltas = frame.deltaEntities { self.handleDeltaData(deltas) }
                } else {
                    if let payload = frame.gameDataPayload { self.handleFullGameData(payload) }
                }
            case ProtocolConstants.typeHeartbeatAck:
                if self.lastHeartbeatTime > 0 {
                    let ping = Date().timeIntervalSince1970 * 1000 - self.lastHeartbeatTime
                    self.lastHeartbeatTime = 0
                    self.onHeartbeatAck?(ping)
                }
            default:
                break
            }
        }
    }
    
    private func handleFullGameData(_ payload: String) {
        guard !payload.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        currentGameData = payload
        heroStateMap = buildHeroStateMap(payload)
        onGameData?(payload)
    }
    
    private func handleDeltaData(_ deltas: [DeltaEntity]) {
        guard !heroStateMap.isEmpty, let current = currentGameData else { return }
        for delta in deltas {
            guard var hero = heroStateMap[delta.id] else { continue }
            hero.x += Float(delta.dx) / 10.0
            hero.y += Float(delta.dy) / 10.0
            hero.fields[5] = "\(hero.x)"
            hero.fields[6] = "\(hero.y)"
            hero.raw = hero.fields.joined(separator: ",")
            heroStateMap[delta.id] = hero
        }
        currentGameData = reconstructPayload()
        if let data = currentGameData { onGameData?(data) }
    }
    
    private func buildHeroStateMap(_ payload: String) -> [Int32: HeroState] {
        var map: [Int32: HeroState] = [:]
        let parts = payload.split(separator: "---", maxSplits: 1)
        guard parts.count >= 1 else { return map }
        let heroes = parts[0].split(separator: "==")
        for (i, heroStr) in heroes.enumerated() {
            let fields = heroStr.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
            guard fields.count >= 7, let heroId = Int32(fields[0]) else { continue }
            let x = Float(fields[5]) ?? 0
            let y = Float(fields[6]) ?? 0
            map[heroId] = HeroState(raw: String(heroStr), fields: fields, x: x, y: y, index: i)
        }
        return map
    }
    
    private func reconstructPayload() -> String {
        guard let current = currentGameData else { return "" }
        let parts = current.split(separator: "---", maxSplits: 1)
        guard parts.count >= 1 else { return current }
        
        var maxIndex = 0
        for (_, hero) in heroStateMap { if hero.index > maxIndex { maxIndex = hero.index } }
        
        var heroParts: [String] = []
        for i in 0...maxIndex {
            let match = heroStateMap.values.first(where: { $0.index == i })
            heroParts.append(match?.raw ?? "")
        }
        
        var result = heroParts.joined(separator: "==")
        if parts.count > 1 { result += "---" + parts[1] }
        return result
    }
    
    private func handleDisconnect(_ reason: String) {
        guard state != .disconnected else { return }
        stopTimers()
        state = .disconnected
        subscribed = false
        if !intentionalClose {
            onDisconnected?(reason)
            scheduleReconnect()
        } else {
            onDisconnected?("用户断开")
        }
    }
    
    private func scheduleReconnect() {
        guard !intentionalClose else { return }
        if reconnectAttempts >= ProtocolConstants.maxReconnectAttempts {
            onError?("已达到最大重连次数，请手动重连")
            return
        }
        reconnectAttempts += 1
        let delay = min(2.0 * Double(reconnectAttempts), 15.0)
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.state = .disconnected
                self.connect()
            }
        }
    }
    
    static func isValidIP(_ ip: String) -> Bool {
        let trimmed = ip.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        let ipRegex = "^\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}(:\\d+)?$"
        if trimmed.range(of: ipRegex, options: .regularExpression) != nil {
            let hostPart = trimmed.components(separatedBy: ":")[0]
            let octets = hostPart.split(separator: ".").compactMap { Int($0) }
            return octets.count == 4 && octets.allSatisfy { $0 >= 0 && $0 <= 255 }
        }
        let domainRegex = "^[a-zA-Z0-9]([a-zA-Z0-9\\-]*[a-zA-Z0-9])?(\\.[a-zA-Z0-9]([a-zA-Z0-9\\-]*[a-zA-Z0-9])?)*$"
        return trimmed.range(of: domainRegex, options: .regularExpression) != nil
    }
}
