import SwiftUI

@MainActor
class AppState: ObservableObject {
    static let shared = AppState()
    
    @Published var isConnected: Bool = false
    @Published var isConnecting: Bool = false
    @Published var toastMessage: String = ""
    @Published var showToast: Bool = false
    
    var onServerConnected: (() -> Void)?
    var onServerDisconnected: ((String) -> Void)?
    var onServerError: ((String) -> Void)?
    var onHomeDataReceived: ((String) -> Void)?
    var onGameDataReceived: ((String) -> Void)?
    var onPingUpdate: ((Double) -> Void)?
    
    private var wsClient: RadarWebSocketClient?
    private var toastTimer: Timer?
    
    private init() {}
    
    func connectToServer(host: String, port: Int) {
        if wsClient != nil {
            wsClient?.disconnect()
        }
        
        wsClient = RadarWebSocketClient(host: host, port: port)
        
        wsClient?.onConnected = { [weak self] in
            guard let self = self else { return }
            self.isConnected = true
            self.isConnecting = false
            self.onServerConnected?()
        }
        
        wsClient?.onDisconnected = { [weak self] reason in
            guard let self = self else { return }
            self.isConnected = false
            self.isConnecting = false
            self.onServerDisconnected?(reason)
        }
        
        wsClient?.onError = { [weak self] error in
            guard let self = self else { return }
            self.isConnected = false
            self.isConnecting = false
            self.onServerError?(error)
        }
        
        wsClient?.onHomeData = { [weak self] str in
            guard let self = self else { return }
            self.onHomeDataReceived?(str)
        }
        
        wsClient?.onGameData = { [weak self] data in
            guard let self = self else { return }
            self.onGameDataReceived?(data)
        }
        
        wsClient?.onHeartbeatAck = { [weak self] ping in
            guard let self = self else { return }
            self.onPingUpdate?(ping)
        }
        
        isConnecting = true
        wsClient?.connect()
    }
    
    func disconnectServer() {
        wsClient?.disconnect()
        isConnected = false
        isConnecting = false
        onServerDisconnected?("用户断开")
    }
    
    func joinRoom(_ roomId: String) {
        wsClient?.setRoomId(roomId)
    }
    
    func leaveRoom() {
        wsClient?.setRoomId(nil)
    }
    
    func showToast(_ message: String) {
        toastMessage = message
        withAnimation { showToast = true }
        toastTimer?.invalidate()
        toastTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            withAnimation { self?.showToast = false }
        }
    }
}
