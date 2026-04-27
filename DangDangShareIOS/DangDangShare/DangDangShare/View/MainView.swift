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
        ZStack {
            backgroundView
            
            ScrollView {
                VStack(spacing: 16) {
                    headerSection
                    serverSection
                    roomSection
                    roomListSection
                    
                    if !currentRoom.isEmpty {
                        debugPanelSection
                        radarPreviewSection
                    }
                    
                    footerSection
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            serverIP = savedIP
            roomID = savedRoom
        }
    }
    
    private var backgroundView: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "0a0a1a"), Color(hex: "1a1a3e")],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            
            if let iconImage = loadAppIcon() {
                Image(uiImage: iconImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .opacity(0.08)
                    .blur(radius: 30)
                    .ignoresSafeArea()
            }
        }
    }
    
    private func loadAppIcon() -> UIImage? {
        if let path = Bundle.main.path(forResource: "111", ofType: "jpg"),
           let image = UIImage(contentsOfFile: path) {
            return image
        }
        return nil
    }
    
    private var headerSection: some View {
        VStack(spacing: 6) {
            Text("当当共享")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(colors: [Color(hex: "0a84ff"), Color(hex: "5ac8fa")],
                                   startPoint: .leading, endPoint: .trailing)
                )
            Text("游戏雷达共享工具")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.4))
        }
        .padding(.bottom, 8)
    }
    
    private var footerSection: some View {
        VStack(spacing: 4) {
            Text("作者：当当")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.5))
            Text("作者QQ：519390463")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(.top, 20)
    }
    
    private var serverSection: some View {
        GlassPanel {
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                    Text("服务器状态: \(serverStatus)")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.8))
                    Spacer()
                    if !pingText.isEmpty {
                        Text(pingText)
                            .font(.system(size: 11))
                            .foregroundColor(pingColor)
                    }
                }
                
                Divider().overlay(Color.white.opacity(0.08))
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("服务器设置")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                    
                    HStack(spacing: 10) {
                        TextField("输入公网IP地址", text: $serverIP)
                            .textFieldStyle(GlassInputStyle())
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .keyboardType(.numbersAndPunctuation)
                        
                        Button(action: connectToServer) {
                            Text(isConnecting ? "连接中..." : "连接服务器")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    LinearGradient(colors: isConnecting
                                                   ? [Color.gray.opacity(0.4), Color.gray.opacity(0.3)]
                                                   : [Color(hex: "0a84ff"), Color(hex: "0070e0")],
                                                   startPoint: .leading, endPoint: .trailing)
                                )
                                .cornerRadius(8)
                        }
                        .disabled(isConnecting || appState.isConnected)
                        
                        Button(action: disconnectServer) {
                            Text("断开")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.red.opacity(0.6))
                                .cornerRadius(8)
                        }
                        .disabled(!appState.isConnected)
                    }
                }
            }
        }
    }
    
    private var roomSection: some View {
        GlassPanel {
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    TextField("输入房间号", text: $roomID)
                        .textFieldStyle(GlassInputStyle())
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    Button(action: connectToRoom) {
                        Text("连接房间")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(hex: "30d158"))
                            .cornerRadius(8)
                    }
                    .disabled(!appState.isConnected)
                    
                    Button(action: disconnectRoom) {
                        Text("退出房间")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.red.opacity(0.7))
                            .cornerRadius(8)
                    }
                    .disabled(currentRoom.isEmpty)
                }
                
                if !currentRoom.isEmpty {
                    HStack {
                        Text("当前房间: \(currentRoom)")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "5ac8fa"))
                        Spacer()
                    }
                }
            }
        }
    }
    
    private var roomListSection: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 8) {
                Text("在线房间")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
                
                if roomList.isEmpty {
                    Text("暂时没人开启共享")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.3))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 12)
                } else {
                    ForEach(roomList, id: \.self) { room in
                        Button(action: { joinRoom(room) }) {
                            HStack {
                                Text(room)
                                    .font(.system(size: 14))
                                    .foregroundColor(room == currentRoom ? .white : .white.opacity(0.7))
                                Spacer()
                                if room == currentRoom {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(Color(hex: "30d158"))
                                        .font(.system(size: 14))
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                room == currentRoom
                                ? Color(hex: "0a84ff").opacity(0.15)
                                : Color.white.opacity(0.04)
                            )
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(room == currentRoom
                                            ? Color(hex: "0a84ff").opacity(0.3)
                                            : Color.white.opacity(0.06), lineWidth: 0.5)
                            )
                        }
                    }
                }
            }
        }
    }
    
    private var debugPanelSection: some View {
        GlassPanel {
            VStack(spacing: 12) {
                HStack {
                    Text("调试设置")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                    Spacer()
                    Button(action: { showDebugPanel.toggle() }) {
                        Image(systemName: showDebugPanel ? "chevron.up" : "chevron.down")
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                
                if showDebugPanel {
                    VStack(spacing: 10) {
                        debugSliderSection(title: "整体偏移", items: [
                        ("水平", $globalOffsetX, -500, 500),
                        ("垂直", $globalOffsetY, -500, 500)
                        ])
                        
                        Divider().overlay(Color.white.opacity(0.08))
                        
                        debugSliderSection(title: "英雄偏移", items: [
                        ("X偏移", $heroOffsetX, -500, 500),
                        ("Y偏移", $heroOffsetY, -500, 500),
                        ("缩放", $heroScale, 0.1, 3.0)
                        ])
                        
                        Divider().overlay(Color.white.opacity(0.08))
                        
                        debugSliderSection(title: "野怪偏移", items: [
                        ("X偏移", $monsterOffsetX, -500, 500),
                        ("Y偏移", $monsterOffsetY, -500, 500),
                        ("缩放", $monsterScale, 0.1, 3.0),
                        ("放大", $monsterZoom, 0.5, 5.0)
                        ])
                        
                        Divider().overlay(Color.white.opacity(0.08))
                        
                        Button(action: resetDebugSettings) {
                            Text("重置默认值")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.6))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(6)
                        }
                    }
                    .transition(.opacity)
                }
            }
        }
    }
    
    private func debugSliderSection(title: String, items: [(String, Binding<Double>, Double, Double)]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
            
            ForEach(items.indices, id: \.self) { index in
                let item = items[index]
                HStack(spacing: 8) {
                    Text(item.0)
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(width: 40, alignment: .leading)
                    
                    Slider(value: item.1, in: item.2...item.3)
                        .accentColor(Color(hex: "0a84ff"))
                    
                    Text(String(format: item.0.contains("缩放") || item.0.contains("放大") ? "%.2f" : "%.0f", item.1.wrappedValue))
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.5))
                        .frame(width: 36, alignment: .trailing)
                }
                .onChange(of: item.1.wrappedValue) { _ in
                    applyDebugSettings()
                }
            }
        }
    }
    
    private var radarPreviewSection: some View {
        GlassPanel {
            VStack(spacing: 8) {
                HStack {
                    Text("雷达预览")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                    Spacer()
                    Text("实时数据")
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: "30d158"))
                }
                
                RadarPreviewView(gameData: lastGameData)
                    .frame(height: 200)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(10)
                
                if lastGameData.isEmpty {
                    Text("等待数据...")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.4))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                }
            }
        }
    }
    
    private func resetDebugSettings() {
        globalOffsetX = 0
        globalOffsetY = 0
        heroOffsetX = 0
        heroOffsetY = 0
        heroScale = 1.0
        monsterOffsetX = 0
        monsterOffsetY = 0
        monsterScale = 1.0
        monsterZoom = 1.0
        applyDebugSettings()
        appState.showToast("已重置为默认值")
    }
    
    private func applyDebugSettings() {
        Task { @MainActor in
            OverlayManager.shared.updateSettings(
                globalX: Float(globalOffsetX),
                globalY: Float(globalOffsetY),
                heroOffsetX: Float(heroOffsetX),
                heroOffsetY: Float(heroOffsetY),
                heroScale: Float(heroScale),
                monsterOffsetX: Float(monsterOffsetX),
                monsterOffsetY: Float(monsterOffsetY),
                monsterScale: Float(monsterScale),
                monsterZoom: Float(monsterZoom)
            )
        }
    }
    
    private var pingColor: Color {
        if pingText.contains("优秀") { return Color(hex: "30d158") }
        if pingText.contains("良好") { return Color(hex: "ff9f0a") }
        return Color.red
    }
    
    private func connectToServer() {
        if isConnecting {
            appState.showToast("正在连接中，请稍候...")
            return
        }
        if appState.isConnected {
            appState.showToast("已连接到服务器，无需重复连接")
            return
        }
        
        let ip = serverIP.trimmingCharacters(in: .whitespaces)
        if ip.isEmpty {
            appState.showToast("请先输入服务器IP地址")
            return
        }
        if !RadarWebSocketClient.isValidIP(ip) {
            appState.showToast("IP地址格式不正确，请检查输入")
            return
        }
        
        savedIP = ip
        isConnecting = true
        serverStatus = "连接中..."
        statusColor = .yellow
        
        appState.onServerConnected = {
            isConnecting = false
            serverStatus = "已连接"
            statusColor = Color(hex: "30d158")
            appState.showToast("已连接到服务器")
        }
        
        appState.onServerDisconnected = { reason in
            isConnecting = false
            serverStatus = "已断开"
            statusColor = .red
            if reason != "用户断开" {
                appState.showToast("连接已断开，将自动重连...")
            }
        }
        
        appState.onServerError = { error in
            isConnecting = false
            serverStatus = "连接失败"
            statusColor = .red
            appState.showToast(error)
        }
        
        appState.onHomeDataReceived = { listStr in
            var rooms: [String] = []
            let parts = listStr.components(separatedBy: ",")
            for p in parts {
                let trimmed = p.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty { rooms.append(trimmed) }
            }
            roomList = rooms
        }
        
        appState.onGameDataReceived = { data in
            lastGameData = data
            Task { @MainActor in
                OverlayManager.shared.updateGameData(data)
            }
        }
        
        appState.onPingUpdate = { pingMs in
            if pingMs < 50 {
                pingText = "延迟: \(Int(pingMs))ms 优秀"
            } else if pingMs < 150 {
                pingText = "延迟: \(Int(pingMs))ms 良好"
            } else {
                pingText = "延迟: \(Int(pingMs))ms 较差"
            }
        }
        
        appState.connectToServer(host: ip, port: ProtocolConstants.defaultWSPort)
    }
    
    private func disconnectServer() {
        appState.disconnectServer()
        serverStatus = "未连接"
        statusColor = .red
        pingText = ""
        roomList = []
        currentRoom = ""
        lastGameData = ""
        Task { @MainActor in
            OverlayManager.shared.hideOverlay()
        }
        appState.showToast("已断开服务器连接")
    }
    
    private func connectToRoom() {
        let room = roomID.trimmingCharacters(in: .whitespaces)
        if room.isEmpty {
            appState.showToast("请输入房间号")
            return
        }
        if room.count > 32 {
            appState.showToast("房间号长度不能超过32个字符")
            return
        }
        
        let validSet = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
        let chineseSet = CharacterSet(charactersIn: "\u{4e00}"..."\u{9fa5}")
        let fullSet = validSet.union(chineseSet)
        if room.unicodeScalars.allSatisfy({ fullSet.contains($0) }) == false {
            appState.showToast("房间号仅支持字母、数字、下划线、中划线和中文")
            return
        }
        
        if !appState.isConnected {
            if appState.isConnecting {
                appState.showToast("服务器正在连接中，请稍候...")
            } else {
                appState.showToast("请先连接服务器")
            }
            return
        }
        
        savedRoom = room
        currentRoom = room
        appState.joinRoom(room)
        appState.showToast("已连接到房间: \(room)")
        
        applyDebugSettings()
        
        Task { @MainActor in
            OverlayManager.shared.showOverlay()
        }
    }
    
    private func disconnectRoom() {
        currentRoom = ""
        savedRoom = ""
        roomID = ""
        lastGameData = ""
        appState.leaveRoom()
        Task { @MainActor in
            OverlayManager.shared.updateGameData("")
            OverlayManager.shared.hideOverlay()
        }
        appState.showToast("已断开房间连接")
    }
    
    private func joinRoom(_ room: String) {
        roomID = room
        connectToRoom()
    }
}

struct RadarPreviewView: UIViewRepresentable {
    let gameData: String
    
    func makeUIView(context: Context) -> RadarPreviewUIView {
        let view = RadarPreviewUIView()
        view.backgroundColor = .clear
        return view
    }
    
    func updateUIView(_ uiView: RadarPreviewUIView, context: Context) {
        uiView.gameDataString = gameData
        uiView.setNeedsDisplay()
    }
}

class RadarPreviewUIView: UIView {
    var gameDataString: String = ""
    private let originalMapSize: CGFloat = 340
    private var mapImage: UIImage?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        loadMapImage()
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    private func loadMapImage() {
        if let path = Bundle.main.path(forResource: "map", ofType: "png"),
           let img = UIImage(contentsOfFile: path) {
            mapImage = img
        }
    }
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        
        let w = rect.width
        let h = rect.height
        let scaleX = w / originalMapSize
        let scaleY = h / originalMapSize
        
        ctx.saveGState()
        ctx.translateBy(x: 0, y: h)
        ctx.scaleBy(x: 1, y: -1)
        
        if let mapImg = mapImage {
            mapImg.draw(in: rect)
        } else {
            ctx.setFillColor(UIColor(white: 0.1, alpha: 1).cgColor)
            ctx.fill(rect)
        }
        
        if !gameDataString.isEmpty {
            let parts = gameDataString.components(separatedBy: "---")
            if parts.count >= 1, !parts[0].isEmpty {
                drawHeroes(ctx: ctx, heroPart: parts[0], scaleX: scaleX, scaleY: scaleY)
            }
            if parts.count >= 2, !parts[1].isEmpty {
                drawMonsters(ctx: ctx, monsterPart: parts[1], scaleX: scaleX, scaleY: scaleY)
            }
        }
        
        ctx.restoreGState()
    }
    
    private func drawHeroes(ctx: CGContext, heroPart: String, scaleX: CGFloat, scaleY: CGFloat) {
        let heroStrings = heroPart.components(separatedBy: "==")
        for heroStr in heroStrings {
            guard let hero = HeroData.parse(heroStr) else { continue }
            let size: CGFloat = 30 * scaleX
            let drawX = CGFloat(hero.x) * scaleX
            let drawY = CGFloat(hero.y) * scaleY
            
            let borderColor = hero.team == 1
                ? UIColor(red: 0.15, green: 0.55, blue: 0.95, alpha: 1)
                : UIColor.red
            
            ctx.setFillColor(borderColor.withAlphaComponent(0.6).cgColor)
            ctx.addEllipse(in: CGRect(x: drawX, y: drawY, width: size, height: size))
            ctx.fillPath()
            
            ctx.setStrokeColor(borderColor.cgColor)
            ctx.setLineWidth(2)
            ctx.addEllipse(in: CGRect(x: drawX, y: drawY, width: size, height: size))
            ctx.strokePath()
        }
    }
    
    private func drawMonsters(ctx: CGContext, monsterPart: String, scaleX: CGFloat, scaleY: CGFloat) {
        let monsterStrings = monsterPart.components(separatedBy: "==")
        let monsterColor = UIColor(red: 1, green: 0.72, blue: 0, alpha: 1)
        
        for str in monsterStrings {
            guard let m = MonsterData.parse(str) else { continue }
            if m.x == 108 && m.y == 104 { continue }
            
            let drawX = CGFloat(m.x) * scaleX
            let drawY = CGFloat(m.y) * scaleY
            let r: CGFloat = 4 * scaleX
            
            ctx.setFillColor(monsterColor.cgColor)
            ctx.addEllipse(in: CGRect(x: drawX - r, y: drawY - r, width: r * 2, height: r * 2))
            ctx.fillPath()
        }
    }
}

struct GlassPanel<Content: View>: View {
    let content: () -> Content
    
    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }
    
    var body: some View {
        content()
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .opacity(0.6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)
                    )
                    .shadow(color: Color.black.opacity(0.3), radius: 8, y: 4)
            )
    }
}

struct GlassInputStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(.ultraThinMaterial)
                    .opacity(0.5)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)
                    )
            )
            .foregroundColor(.white)
            .font(.system(size: 14))
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
