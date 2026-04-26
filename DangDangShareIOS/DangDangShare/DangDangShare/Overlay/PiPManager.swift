import AVFoundation
import AVKit
import UIKit

@MainActor
class PiPManager: NSObject {
    static let shared = PiPManager()
    
    private var pipController: AVPictureInPictureController?
    private var displayLayer: AVSampleBufferDisplayLayer?
    private var pixelBufferPool: CVPixelBufferPool?
    private var displayLink: CADisplayLink?
    private var radarView: RadarOverlayView?
    private var isPiPActive = false
    private var silentPlayer: AVAudioPlayer?
    private var frameCount: Int64 = 0
    private var lastGameData: String = ""
    private var mapImage: UIImage?
    private var isLocked: Bool = false
    
    private let originalMapSize: CGFloat = 340
    private var pipSize: CGSize = CGSize(width: 340, height: 340)
    
    override init() { super.init() }
    
    func setup() {
        loadMapImage()
        setupAudioSession()
        setupPixelBufferPool()
        setupDisplayLayer()
        setupPiPController()
        setupAppLifecycleObservers()
        startSilentAudio()
    }
    
    private func loadMapImage() {
        if let path = Bundle.main.path(forResource: "map", ofType: "png"),
           let img = UIImage(contentsOfFile: path) {
            mapImage = img
        } else if let url = Bundle.main.url(forResource: "map", withExtension: "png"),
                  let data = try? Data(contentsOf: url),
                  let img = UIImage(data: data) {
            mapImage = img
        } else {
            let b = Bundle.main
            for ext in ["png", "jpg"] {
                for bundleURL in [b.resourceURL, b.bundleURL] {
                    if let url = bundleURL?.appendingPathComponent("map.\(ext)") {
                        if let data = try? Data(contentsOf: url), let img = UIImage(data: data) {
                            mapImage = img; return
                        }
                    }
                }
            }
        }
    }
    
    private func setupAudioSession() {
        let s = AVAudioSession.sharedInstance()
        do {
            try s.setCategory(.playback, mode: .default, options: .mixWithOthers)
            try s.setActive(true)
        } catch {}
    }
    
    private func startSilentAudio() {
        guard silentPlayer == nil else { return }
        let sr: Double = 44100
        let ns = Int(sr)
        var d = Data()
        let ds = ns * 2
        d.append(contentsOf: [0x52,0x49,0x46,0x46])
        d.append(contentsOf: withUnsafeBytes(of: UInt32(36+ds).littleEndian){Array($0)})
        d.append(contentsOf: [0x57,0x41,0x56,0x45])
        d.append(contentsOf: [0x66,0x6D,0x74,0x20])
        d.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian){Array($0)})
        d.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian){Array($0)})
        d.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian){Array($0)})
        d.append(contentsOf: withUnsafeBytes(of: UInt32(44100).littleEndian){Array($0)})
        d.append(contentsOf: withUnsafeBytes(of: UInt32(88200).littleEndian){Array($0)})
        d.append(contentsOf: withUnsafeBytes(of: UInt16(2).littleEndian){Array($0)})
        d.append(contentsOf: withUnsafeBytes(of: UInt16(16).littleEndian){Array($0)})
        d.append(contentsOf: [0x64,0x61,0x74,0x61])
        d.append(contentsOf: withUnsafeBytes(of: UInt32(ds).littleEndian){Array($0)})
        for _ in 0..<ns { d.append(contentsOf: withUnsafeBytes(of: Int16(0).littleEndian){Array($0)}) }
        do {
            silentPlayer = try AVAudioPlayer(data: d)
            silentPlayer?.numberOfLoops = -1
            silentPlayer?.volume = 0.0
            silentPlayer?.play()
        } catch {}
    }
    
    private func stopSilentAudio() { silentPlayer?.stop(); silentPlayer = nil }
    
    private func setupPixelBufferPool() {
        let w = Int(pipSize.width)
        let h = Int(pipSize.height)
        let pa: [String:Any] = [kCVPixelBufferPoolMinimumBufferCountKey as String: 3]
        let ba: [String:Any] = [
            kCVPixelBufferWidthKey as String: w,
            kCVPixelBufferHeightKey as String: h,
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:] as [String:Any]
        ]
        CVPixelBufferPoolCreate(kCFAllocatorDefault, pa as CFDictionary, ba as CFDictionary, &pixelBufferPool)
    }
    
    private func setupDisplayLayer() {
        displayLayer = AVSampleBufferDisplayLayer()
        displayLayer?.frame = CGRect(origin: .zero, size: pipSize)
        displayLayer?.videoGravity = .resizeAspect
        if #available(iOS 17.0, *) {
            displayLayer?.preventsCapture = false
        }
    }
    
    private func setupPiPController() {
        guard let dl = displayLayer else { return }
        guard AVPictureInPictureController.isPictureInPictureSupported() else { return }
        let cs = AVPictureInPictureController.ContentSource(sampleBufferDisplayLayer: dl, playbackDelegate: self)
        pipController = AVPictureInPictureController(contentSource: cs)
        pipController?.delegate = self
        pipController?.canStartPictureInPictureAutomaticallyFromInline = true
    }
    
    private func setupAppLifecycleObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(appDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
    }
    
    @objc private func appDidEnterBackground() {
        if radarView != nil { startPiP() }
    }
    @objc private func appWillEnterForeground() {
        if isPiPActive { stopPiP() }
    }
    
    func updateRadarView(_ v: RadarOverlayView?) { radarView = v }
    func updateGameData(_ d: String) { lastGameData = d }
    func setLocked(_ locked: Bool) { isLocked = locked }
    func getLocked() -> Bool { return isLocked }
    
    func startPiP() {
        guard let pc = pipController, !isPiPActive else { return }
        startSilentAudio()
        sendInitialFrame()
        displayLink = CADisplayLink(target: self, selector: #selector(renderFrame))
        displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 60)
        displayLink?.add(to: .main, forMode: .common)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if pc.isPictureInPicturePossible { pc.startPictureInPicture() }
        }
    }
    
    func stopPiP() {
        displayLink?.invalidate(); displayLink = nil
        if isPiPActive { pipController?.stopPictureInPicture() }
        stopSilentAudio()
    }
    
    private func sendInitialFrame() {
        guard let pool = pixelBufferPool, let layer = displayLayer else { return }
        var pb: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pb)
        guard let buf = pb else { return }
        renderRadarToBuffer(buf)
        guard let sb = createSampleBuffer(from: buf) else { return }
        layer.enqueue(sb)
    }
    
    @objc private func renderFrame() {
        guard let pool = pixelBufferPool, let layer = displayLayer else { return }
        if layer.status == .failed { layer.flush(); sendInitialFrame(); return }
        var pb: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pb)
        guard let buf = pb else { return }
        renderRadarToBuffer(buf)
        guard let sb = createSampleBuffer(from: buf) else { return }
        layer.enqueue(sb)
    }
    
    private func renderRadarToBuffer(_ buffer: CVPixelBuffer) {
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let ctx = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: CVPixelBufferGetWidth(buffer),
            height: CVPixelBufferGetHeight(buffer),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else { return }
        
        UIGraphicsPushContext(ctx)
        defer { UIGraphicsPopContext() }
        
        let w = CGFloat(CVPixelBufferGetWidth(buffer))
        let h = CGFloat(CVPixelBufferGetHeight(buffer))
        ctx.clear(CGRect(x: 0, y: 0, width: w, height: h))
        
        if let mapImg = mapImage {
            ctx.interpolationQuality = .high
            mapImg.draw(in: CGRect(x: 0, y: 0, width: w, height: h))
        } else {
            ctx.setFillColor(UIColor(white: 0.05, alpha: 0.95).cgColor)
            ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        }
        
        let scaleX = w / originalMapSize
        let scaleY = h / originalMapSize
        
        if !lastGameData.isEmpty {
            let parts = lastGameData.components(separatedBy: "---")
            if parts.count >= 1, !parts[0].isEmpty {
                drawHeroesOnCtx(ctx, heroPart: parts[0], scaleX: scaleX, scaleY: scaleY, canvasW: w, canvasH: h)
            }
            if parts.count >= 2, !parts[1].isEmpty {
                drawMonstersOnCtx(ctx, monsterPart: parts[1], scaleX: scaleX, scaleY: scaleY)
            }
        }
    }
    
    private func drawHeroesOnCtx(_ ctx: CGContext, heroPart: String, scaleX: CGFloat, scaleY: CGFloat, canvasW: CGFloat, canvasH: CGFloat) {
        let heroStrings = heroPart.components(separatedBy: "==")
        for heroStr in heroStrings {
            guard let hero = HeroData.parse(heroStr) else { continue }
            let size = 40.0 * scaleX
            let drawX = CGFloat(hero.x) * scaleX
            let drawY = CGFloat(hero.y) * scaleY
            
            let borderColor = hero.team == 1
                ? UIColor(red: 0.15, green: 0.55, blue: 0.95, alpha: 1)
                : UIColor.red
            
            ctx.setFillColor(borderColor.withAlphaComponent(0.6).cgColor)
            ctx.addEllipse(in: CGRect(x: drawX + 2, y: drawY + 2, width: size - 4, height: size - 4))
            ctx.fillPath()
            
            ctx.setStrokeColor(borderColor.cgColor)
            ctx.setLineWidth(max(1.5, 2.5 * scaleX))
            ctx.addEllipse(in: CGRect(x: drawX, y: drawY, width: size, height: size))
            ctx.strokePath()
            
            if hero.level > 0 {
                let fontSize = max(6, 8 * scaleX)
                let text = "Lv.\(hero.level)" as NSString
                let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: fontSize), .foregroundColor: UIColor.white]
                let textSize = text.size(withAttributes: attrs)
                let bgW = textSize.width + 3
                let bgH = textSize.height + 2
                let bgX = drawX + size - bgW / 2 - 1
                let bgY = drawY + bgH / 2 + 1
                let bgColor = hero.team == 1 ? UIColor(red: 0.29, green: 0.62, blue: 1, alpha: 0.9) : UIColor(red: 1, green: 0.27, blue: 0.23, alpha: 0.9)
                ctx.setFillColor(bgColor.cgColor)
                ctx.addRect(CGRect(x: bgX - bgW / 2, y: bgY - bgH / 2, width: bgW, height: bgH))
                ctx.fillPath()
                text.draw(at: CGPoint(x: bgX - textSize.width / 2, y: bgY - textSize.height / 2), withAttributes: attrs)
            }
            
            let hpY = drawY + size
            let maxHPWidth = size
            let hpWidth = CGFloat(hero.hp) / 100.0 * maxHPWidth
            let strokeW = max(1.5, 3 * scaleX)
            ctx.setStrokeColor(UIColor.white.withAlphaComponent(0.6).cgColor)
            ctx.setLineWidth(strokeW)
            ctx.move(to: CGPoint(x: drawX, y: hpY))
            ctx.addLine(to: CGPoint(x: drawX + maxHPWidth, y: hpY))
            ctx.strokePath()
            let hpColor = hero.team == 1 ? UIColor(red: 0.09, green: 0.72, blue: 0.47, alpha: 1) : UIColor.red
            ctx.setStrokeColor(hpColor.cgColor)
            ctx.move(to: CGPoint(x: drawX, y: hpY))
            ctx.addLine(to: CGPoint(x: drawX + hpWidth, y: hpY))
            ctx.strokePath()
        }
    }
    
    private func drawMonstersOnCtx(_ ctx: CGContext, monsterPart: String, scaleX: CGFloat, scaleY: CGFloat) {
        let monsterStrings = monsterPart.components(separatedBy: "==")
        let monsterColor = UIColor(red: 1, green: 0.72, blue: 0, alpha: 1)
        
        var cdMap: [String: Int] = [:]
        var monsters: [MonsterData] = []
        for str in monsterStrings {
            if let m = MonsterData.parse(str) {
                monsters.append(m)
                cdMap[m.id] = m.cd
            }
        }
        
        let cd1660221 = cdMap["1660221"]
        let cd166009 = cdMap["166009"]
        let cd166022 = cdMap["166022"]
        
        for m in monsters {
            if m.x == 108 && m.y == 104 { continue }
            
            var hideCountdown = false
            if let cd = cd1660221, cd > 0 && cd <= 180 {
                if ["166009", "166018", "166012", "166022"].contains(m.id) { hideCountdown = true }
            } else if let cd = cd166009, cd > 0 && cd <= 210 {
                if m.id == "166018" { hideCountdown = true }
            }
            if let cd = cd166022, cd > 0 && cd <= 210 {
                if m.id == "166012" { hideCountdown = true }
            }
            
            let drawX = CGFloat(m.x) * scaleX
            let drawY = CGFloat(m.y) * scaleY
            
            if hideCountdown || m.isFullCD || m.cd == 0 {
                let r = max(2.5, 3.5 * scaleX)
                ctx.setFillColor(monsterColor.cgColor)
                ctx.addEllipse(in: CGRect(x: drawX - r, y: drawY - r, width: r * 2, height: r * 2))
                ctx.fillPath()
                ctx.setStrokeColor(UIColor.white.cgColor)
                ctx.setLineWidth(max(1, 1.2 * scaleX))
                ctx.addEllipse(in: CGRect(x: drawX - r, y: drawY - r, width: r * 2, height: r * 2))
                ctx.strokePath()
            } else if m.cd > 0 && m.cd <= 240 {
                let fontSize = max(7, 9 * scaleX)
                let cdText = "\(m.cd)" as NSString
                let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: fontSize), .foregroundColor: monsterColor]
                let textSize = cdText.size(withAttributes: attrs)
                let padding = 2 * scaleX
                let bgX = drawX - textSize.width / 2 - padding
                let bgY = drawY - textSize.height / 2 - padding
                ctx.setFillColor(UIColor(white: 0, alpha: 0.7).cgColor)
                ctx.addRect(CGRect(x: bgX, y: bgY, width: textSize.width + padding * 2, height: textSize.height + padding * 2))
                ctx.fillPath()
                cdText.draw(at: CGPoint(x: drawX - textSize.width / 2, y: drawY - textSize.height / 2), withAttributes: attrs)
            }
        }
    }
    
    private func createSampleBuffer(from pb: CVPixelBuffer) -> CMSampleBuffer? {
        var fd: CMVideoFormatDescription?
        CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: pb, formatDescriptionOut: &fd)
        guard let f = fd else { return nil }
        var timing = CMSampleTimingInfo(duration: CMTime(value: 1, timescale: 60), presentationTimeStamp: CMTime(value: frameCount, timescale: 60), decodeTimeStamp: .invalid)
        frameCount += 1
        var sb: CMSampleBuffer?
        let r = CMSampleBufferCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: pb, dataReady: true, makeDataReadyCallback: nil, refcon: nil, formatDescription: f, sampleTiming: &timing, sampleBufferOut: &sb)
        guard r == 0 else { return nil }
        return sb
    }
    
    var isPiPSupported: Bool { AVPictureInPictureController.isPictureInPictureSupported() }
}

extension PiPManager: AVPictureInPictureControllerDelegate {
    nonisolated func pictureInPictureControllerDidStartPictureInPicture(_ c: AVPictureInPictureController) {
        Task { @MainActor in isPiPActive = true }
    }
    nonisolated func pictureInPictureControllerDidStopPictureInPicture(_ c: AVPictureInPictureController) {
        Task { @MainActor in isPiPActive = false }
    }
    nonisolated func pictureInPictureController(_ c: AVPictureInPictureController, failedToStartPictureInPictureWithError e: Error) {
        Task { @MainActor in isPiPActive = false }
    }
    nonisolated func pictureInPictureController(_ c: AVPictureInPictureController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler h: @escaping @Sendable (Bool) -> Void) {
        h(true)
    }
}

extension PiPManager: AVPictureInPictureSampleBufferPlaybackDelegate {
    nonisolated func pictureInPictureControllerTimeRangeForPlayback(_ c: AVPictureInPictureController) -> CMTimeRange {
        return CMTimeRange(start: .zero, duration: CMTime(value: 1, timescale: 1))
    }
    
    nonisolated func pictureInPictureControllerIsPlaybackPaused(_ c: AVPictureInPictureController) -> Bool {
        return false
    }
    
    nonisolated func pictureInPictureController(_ c: AVPictureInPictureController, didTransitionToRenderSize newRenderSize: CMVideoDimensions) {
    }
    
    nonisolated func pictureInPictureController(_ c: AVPictureInPictureController, setPlaying playing: Bool) {
    }
    
    nonisolated func pictureInPictureController(_ c: AVPictureInPictureController, skipByInterval skipInterval: CMTime) async {
    }
}
