import SwiftUI

struct MainView: View {
    @StateObject private var appState = AppState.shared
    
    @State private var serverIP: String = ""
    @State private var roomID: String = ""
    @State private var serverStatus: String = "未连接"
    @State private var statusColor: Color = .red
    @State private var pingText: String = ""
    @State private var roomList: [String] = []
    @State private var currentRoom: String = ""
    @State private var isConnecting: Bool = false
    @State private var showDebugPanel: Bool = false
    @State private var lastGameData: String = ""
    
    @AppStorage("server_ip") private var savedIP: String = ""
    @AppStorage("room_id") private var savedRoom: String = ""
    
    @AppStorage("global_offset_x") private var globalOffsetX: Double = 0
    @AppStorage("global_offset_y") private var globalOffsetY: Double = 0
    @AppStorage("hero_offset_x") private var heroOffsetX: Double = 0
    @AppStorage("hero_offset_y") private var heroOffsetY: Double = 0
    @AppStorage("hero_scale") private var heroScale: Double = 1.0
    @AppStorage("monster_offset_x") private var monsterOffsetX: Double = 0
    @AppStorage("monster_offset_y") private var monsterOffsetY: Double = 0
    @AppStorage("monster_scale") private var monsterScale: Double = 1.0
    @AppStorage("monster_zoom") private var monsterZoom: Double = 1.0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.clear.ignoresSafeArea()
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 10) {
                        headerSection
                        serverSection
                        roomSection
                        roomListSection
                        
                        if !currentRoom.isEmpty {
                            debugPanelSection
                            radarPreviewSection
                        }
                        
                        footerSection
                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
                    .frame(minHeight: geometry.size.height)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            serverIP = savedIP
            roomID = savedRoom
        }
        .overlay(
            Group {
                if appState.showToast {
                    ToastView(message: appState.toastMessage)
                        .transition(.opacity)
                }
            }, alignment: .top
        )
    }
    
    private var headerSection: some View {
        VStack(spacing: 2) {
            Text("当当共享")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            Text("游戏雷达共享工具")
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.45))
        }
        .padding(.bottom, 4)
    }
    
    private var footerSection: some View {
        VStack(spacing: 1) {
            Text("作者：当当")
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.35))
            Text("作者QQ：519390463")
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.35))
        }
        .padding(.top, 10)
    }
    
    private var serverSection: some View {
        GlassCard {
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Circle().fill(statusColor).frame(width: 6, height: 6)
                    Text(serverStatus).font(.system(size: 11, weight: .medium)).foregroundColor(.white)
                    Spacer()
                    if !pingText.isEmpty {
                        Text(pingText).font(.system(size: 9))
                            .foregroundColor(pingColor)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.black.opacity(0.25)).cornerRadius(4)
                    }
                }
                
                HStack(spacing: 6) {
                    TextField("服务器IP", text: $serverIP)
                        .textFieldStyle(ClearTextFieldStyle())
                        .autocapitalization(.none).disableAutocorrection(true)
                        .keyboardType(.numbersAndPunctuation)
                    
                    Button(action: connectToServer) {
                        Text(isConnecting ? "..." : "连接")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(isConnecting ? Color.gray : Color.blue).cornerRadius(6)
                    }.disabled(isConnecting || appState.isConnected)
                    
                    Button(action: disconnectServer) {
                        Text("断")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8).padding(.vertical, 6)
                            .background(Color.red.opacity(0.8)).cornerRadius(6)
                    }.disabled(!appState.isConnected)
                }
            }
        }
    }
    
    private var roomSection: some View {
        GlassCard {
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    TextField("房间号", text: $roomID)
                        .textFieldStyle(ClearTextFieldStyle())
                        .autocapitalization(.none).disableAutocorrection(true)
                    
                    Button(action: connectToRoom) {
                        Text("进入")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Color.green.opacity(0.9)).cornerRadius(6)
                    }.disabled(!appState.isConnected)
                    
                    Button(action: disconnectRoom) {
                        Text("退")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8).padding(.vertical, 6)
                            .background(Color.orange.opacity(0.8)).cornerRadius(6)
                    }.disabled(currentRoom.isEmpty)
                }
                
                if !currentRoom.isEmpty {
                    HStack {
                        Text("房间: \(currentRoom)").font(.system(size: 10)).foregroundColor(.cyan)
                        Spacer()
                    }
                }
            }
        }
    }
    
    private var roomListSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 4) {
                Text("在线房间")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.65))
                
                if roomList.isEmpty {
                    Text("暂时没人开启共享")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.3))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                } else {
                    ForEach(roomList, id: \.self) { room in
                        Button(action: { joinRoom(room) }) {
                            HStack {
                                Text(room).font(.system(size: 12)).foregroundColor(room == currentRoom ? .white : .white.opacity(0.7))
                                Spacer()
                                if room == currentRoom {
                                    Image(systemName: "checkmark.circle.fill").foregroundColor(.green).font(.system(size: 11))
                                }
                            }
                            .padding(.horizontal, 8).padding(.vertical, 6)
                            .background(RoundedRectangle(cornerRadius: 6).fill(room == currentRoom ? Color.blue.opacity(0.15) : Color.white.opacity(0.03)))
                            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(room == currentRoom ? Color.blue.opacity(0.3) : Color.white.opacity(0.05), lineWidth: 0.5))
                        }
                    }
                }
            }
        }
    }
    
    private var debugPanelSection: some View {
        GlassCard {
            VStack(spacing: 8) {
                HStack {
                    Text("调试设置")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                    Button(action: { withAnimation(.easeInOut(duration: 0.2)) { showDebugPanel.toggle() } }) {
                        Image(systemName: showDebugPanel ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.45))
                    }
                }
                
                if showDebugPanel {
                    VStack(spacing: 6) {
                        debugSliderGroup(title: "整体", items: [
                        ("X", $globalOffsetX, -500, 500),
                        ("Y", $globalOffsetY, -500, 500)
                        ])
                        
                        Divider().background(Color.white.opacity(0.06))
                        
                        debugSliderGroup(title: "英雄", items: [
                        ("X", $heroOffsetX, -500, 500),
                        ("Y", $heroOffsetY, -500, 500),
                        ("缩", $heroScale, 0.1, 3.0)
                        ])
                        
                        Divider().background(Color.white.opacity(0.06))
                        
                        debugSliderGroup(title: "野怪", items: [
                        ("X", $monsterOffsetX, -500, 500),
                        ("Y", $monsterOffsetY, -500, 500),
                        ("缩", $monsterScale, 0.1, 3.0),
                        ("放", $monsterZoom, 0.5, 5.0)
                        ])
                        
                        Divider().background(Color.white.opacity(0.06))
                        
                        Button(action: resetDebugSettings) {
                            Text("重置")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.6))
                                .padding(.horizontal, 12).padding(.vertical, 4)
                                .background(Color.white.opacity(0.06)).cornerRadius(5)
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }
    
    private func debugSliderGroup(title: String, items: [(String, Binding<Double>, Double, Double)]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 9, weight: .medium)).foregroundColor(.white.opacity(0.4))
            
            ForEach(items.indices, id: \.self) { index in
                let item = items[index]
                HStack(spacing: 4) {
                    Text(item.0).font(.system(size: 8)).foregroundColor(.white.opacity(0.5)).frame(width: 20, alignment: .leading)
                    Slider(value: item.1, in: item.2...item.3).accentColor(.blue)
                    Text(String(format: item.0.contains("缩") || item.0.contains("放") ? "%.1f" : "%.0f", item.1.wrappedValue))
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4)).frame(width: 28, alignment: .trailing)
                }
                .onChange(of: item.1) { _ in applyDebugSettings() }
            }
        }
    }
    
    private var radarPreviewSection: some View {
        GlassCard {
            VStack(spacing: 4) {
                HStack {
                    Text("雷达预览").font(.system(size: 11, weight: .semibold)).foregroundColor(.white.opacity(0.7))
                    Spacer()
                    Circle().fill(Color.green).frame(width: 5, height: 5).opacity(lastGameData.isEmpty ? 0.3 : 1)
                    Text(!lastGameData.isEmpty ? "实时" : "等待").font(.system(size: 8)).foregroundColor(!lastGameData.isEmpty ? Color.green : .white.opacity(0.3))
                }
                
                RadarPreviewView(gameData: lastGameData)
                    .frame(height: 160)
                    .background(Color.black.opacity(0.4)).clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5))
            }
        }
    }
    
    private func resetDebugSettings() {
        globalOffsetX = 0; globalOffsetY = 0
        heroOffsetX = 0; heroOffsetY = 0; heroScale = 1.0
        monsterOffsetX = 0; monsterOffsetY = 0; monsterScale = 1.0; monsterZoom = 1.0
        applyDebugSettings()
        appState.showToast("已重置")
    }
    
    private func applyDebugSettings() {
        Task { @MainActor in
            OverlayManager.shared.updateSettings(
                globalX: Float(globalOffsetX), globalY: Float(globalOffsetY),
                heroOffsetX: Float(heroOffsetX), heroOffsetY: Float(heroOffsetY), heroScale: Float(heroScale),
                monsterOffsetX: Float(monsterOffsetX), monsterOffsetY: Float(monsterOffsetY),
                monsterScale: Float(monsterScale), monsterZoom: Float(monsterZoom)
            )
        }
    }
    
    private var pingColor: Color {
        if pingText.contains("优") { return .green }
        if pingText.contains("良") { return .orange }
        return .red
    }
    
    private func connectToServer() {
        if isConnecting { appState.showToast("连接中..."); return }
        if appState.isConnected { appState.showToast("已连接"); return }
        let ip = serverIP.trimmingCharacters(in: .whitespaces)
        guard !ip.isEmpty else { appState.showToast("请输入IP"); return }
        guard RadarWebSocketClient.isValidIP(ip) else { appState.showToast("IP格式错误"); return }
        savedIP = ip; isConnecting = true; serverStatus = "连接中..."; statusColor = .yellow
        
        appState.onServerConnected = { isConnecting = false; serverStatus = "已连接"; statusColor = .green; appState.showToast("已连接") }
        appState.onServerDisconnected = { reason in isConnecting = false; serverStatus = "已断开"; statusColor = .red; if reason != "用户断开" { appState.showToast("断开") } }
        appState.onServerError = { error in isConnecting = false; serverStatus = "失败"; statusColor = .red; appState.showToast(error) }
        appState.onHomeDataReceived = { listStr in let rooms = listStr.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }; roomList = rooms }
        appState.onGameDataReceived = { data in lastGameData = data; Task { @MainActor in OverlayManager.shared.updateGameData(data) } }
        appState.onPingUpdate = { pingMs in pingText = pingMs < 50 ? "\(Int(pingMs))ms优" : (pingMs < 150 ? "\(Int(pingMs))ms良" : "\(Int(pingMs))ms差") }
        appState.connectToServer(host: ip, port: ProtocolConstants.defaultWSPort)
    }
    
    private func disconnectServer() {
        appState.disconnectServer(); serverStatus = "未连接"; statusColor = .red
        pingText = ""; roomList = []; currentRoom = ""; lastGameData = ""
        Task { @MainActor in OverlayManager.shared.hideOverlay() }
        appState.showToast("已断开")
    }
    
    private func connectToRoom() {
        let room = roomID.trimmingCharacters(in: .whitespaces)
        guard !room.isEmpty else { appState.showToast("请输入房间"); return }
        guard room.count <= 32 else { appState.showToast("房间号太长"); return }
        guard appState.isConnected else { appState.showToast(appState.isConnecting ? "连接中..." : "请先连接服务器"); return }
        savedRoom = room; currentRoom = room; appState.joinRoom(room); appState.showToast("进入:\(room)")
        applyDebugSettings()
        Task { @MainActor in OverlayManager.shared.showOverlay() }
    }
    
    private func disconnectRoom() {
        currentRoom = ""; savedRoom = ""; roomID = ""; lastGameData = ""
        appState.leaveRoom()
        Task { @MainActor in OverlayManager.shared.updateGameData(""); OverlayManager.shared.hideOverlay() }
        appState.showToast("已退出")
    }
    
    private func joinRoom(_ room: String) { roomID = room; connectToRoom() }
}

struct ToastView: View {
    let message: String
    var body: some View {
        Text(message)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 14).padding(.vertical, 6)
            .background(Capsule().fill(Color.black.opacity(0.7)).shadow(color: .black.opacity(0.2), radius: 6, y: 2))
            .padding(.top, 40)
    }
}

struct GlassCard<Content: View>: View {
    let content: () -> Content
    init(@ViewBuilder content: @escaping () -> Content) { self.content = content }
    var body: some View {
        content()
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
                    )
            )
    }
}

struct ClearTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration.font(.system(size: 12))
            .padding(.horizontal, 8).padding(.vertical, 6)
            .background(Color.white.opacity(0.07)).cornerRadius(6)
            .foregroundColor(.white)
    }
}

struct RadarPreviewView: UIViewRepresentable {
    let gameData: String
    func makeUIView(context: Context) -> RadarPreviewUIView { let v = RadarPreviewUIView(); v.backgroundColor = .clear; return v }
    func updateUIView(_ uiView: RadarPreviewUIView, context: Context) { uiView.gameDataString = gameData; uiView.setNeedsDisplay() }
}

class RadarPreviewUIView: UIView {
    var gameDataString: String = ""
    private let originalMapSize: CGFloat = 340
    private var mapImage: UIImage?
    override init(frame: CGRect) { super.init(frame: frame); loadMapImage() }
    required init?(coder: NSCoder) { fatalError() }
    private func loadMapImage() { if let path = Bundle.main.path(forResource: "map", ofType: "png"), let img = UIImage(contentsOfFile: path) { mapImage = img } }
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let w = rect.width, h = rect.height, sx = w / originalMapSize, sy = h / originalMapSize
        ctx.saveGState(); ctx.translateBy(x: 0, y: h); ctx.scaleBy(x: 1, y: -1)
        if let mapImg = mapImage { mapImg.draw(in: CGRect(x: 0, y: 0, width: w, height: h)) } else { ctx.setFillColor(UIColor(white: 0.08, alpha: 1).cgColor); ctx.fill(CGRect(x: 0, y: 0, width: w, height: h)) }
        if !gameDataString.isEmpty {
            let parts = gameDataString.components(separatedBy: "---")
            if parts.count >= 1, !parts[0].isEmpty { drawHeroes(ctx, parts[0], sx, sy) }
            if parts.count >= 2, !parts[1].isEmpty { drawMonsters(ctx, parts[1], sx, sy) }
        }
        ctx.restoreGState()
    }
    private func drawHeroes(_ ctx: CGContext, _ part: String, _ sx: CGFloat, _ sy: CGFloat) {
        for str in part.components(separatedBy: "==") {
            guard let h = HeroData.parse(str) else { continue }
            let s: CGFloat = 24 * sx, x = CGFloat(h.x) * sx - s/2, y = CGFloat(h.y) * sy - s/2
            let c = h.team == 1 ? UIColor.systemBlue : UIColor.red
            ctx.setFillColor(c.withAlphaComponent(0.5).cgColor); ctx.addEllipse(in: CGRect(x: x+1, y: y+1, width: s-2, height: s-2)); ctx.fillPath()
            ctx.setStrokeColor(c.cgColor); ctx.setLineWidth(1.2); ctx.addEllipse(in: CGRect(x: x, y: y, width: s, height: s)); ctx.strokePath()
        }
    }
    private func drawMonsters(_ ctx: CGContext, _ part: String, _ sx: CGFloat, _ sy: CGFloat) {
        for str in part.components(separatedBy: "==") {
            guard let m = MonsterData.parse(str) else { continue }
            if m.x == 108 && m.y == 104 { continue }
            let r: CGFloat = 3 * sx, x = CGFloat(m.x) * sx, y = CGFloat(m.y) * sy
            ctx.setFillColor(UIColor.orange.cgColor); ctx.addEllipse(in: CGRect(x: x-r, y: y-r, width: r*2, height: r*2)); ctx.fillPath()
            ctx.setStrokeColor(UIColor.white.withAlphaComponent(0.6).cgColor); ctx.setLineWidth(0.6); ctx.addEllipse(in: CGRect(x: x-r, y: y-r, width: r*2, height: r*2)); ctx.strokePath()
        }
    }
}
