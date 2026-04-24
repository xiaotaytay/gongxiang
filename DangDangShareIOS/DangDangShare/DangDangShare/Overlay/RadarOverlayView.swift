import UIKit

class RadarOverlayView: UIView {
    
    private let originalMapSize: Float = 340
    private let heroSize: Float = 40
    private let heroImageURLBase = "https://game.gtimg.cn/images/yxzj/img201606/heroimg/"
    
    private let colorRedBorder = UIColor.red
    private let colorBlueBorder = UIColor(red: 0.15, green: 0.55, blue: 0.95, alpha: 1)
    private let colorRedHP = UIColor.red
    private let colorBlueHP = UIColor(red: 0.09, green: 0.72, blue: 0.47, alpha: 1)
    private let colorMonster = UIColor(red: 1, green: 0.72, blue: 0, alpha: 1)
    
    var gameDataString: String = ""
    var visible = true
    
    private var globalOffsetX: Float = 0
    private var globalOffsetY: Float = 0
    private var heroOffsetX: Float = 0
    private var heroOffsetY: Float = 0
    private var heroScale: Float = 1.0
    private var monsterOffsetX: Float = 0
    private var monsterOffsetY: Float = 0
    private var monsterScale: Float = 1.0
    private var monsterZoom: Float = 1.0
    private var mapScale: Float = 1.0
    
    private var heroImageCache: [String: UIImage] = [:]
    private var loadingSet: Set<String> = []
    private let maxLoading = 5
    private let maxCacheSize = 20
    private let cacheQueue = DispatchQueue(label: "com.dangdang.share.imagecache", attributes: .concurrent)
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
        loadSettings()
        calculateMapScale()
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    private func loadSettings() {
        let d = UserDefaults.standard
        globalOffsetX = d.object(forKey: "global_offset_x") as? Float ?? 0
        globalOffsetY = d.object(forKey: "global_offset_y") as? Float ?? 0
        heroOffsetX = d.object(forKey: "hero_offset_x") as? Float ?? 0
        heroOffsetY = d.object(forKey: "hero_offset_y") as? Float ?? 0
        heroScale = d.object(forKey: "hero_scale") as? Float ?? 1.0
        monsterOffsetX = d.object(forKey: "monster_offset_x") as? Float ?? 0
        monsterOffsetY = d.object(forKey: "monster_offset_y") as? Float ?? 0
        monsterScale = d.object(forKey: "monster_scale") as? Float ?? 1.0
        monsterZoom = d.object(forKey: "monster_zoom") as? Float ?? 1.0
    }
    
    private func calculateMapScale() {
        let screenWidth = Float(UIScreen.main.bounds.width)
        mapScale = screenWidth * 0.22 / originalMapSize
        if mapScale < 0.01 { mapScale = 1.0 }
        if heroScale < 0.01 { heroScale = mapScale }
        if monsterScale < 0.01 { monsterScale = mapScale }
    }
    
    private func safeDivScale() -> Float {
        return mapScale > 0.01 ? mapScale : 1.0
    }
    
    func updateSettings(globalX: Float, globalY: Float, heroOffsetX hox: Float, heroOffsetY hoy: Float, heroScale hs: Float, monsterOffsetX mox: Float, monsterOffsetY moy: Float, monsterScale ms: Float, monsterZoom mz: Float) {
        globalOffsetX = globalX
        globalOffsetY = globalY
        heroOffsetX = hox
        heroOffsetY = hoy
        heroScale = hs
        monsterOffsetX = mox
        monsterOffsetY = moy
        monsterScale = ms
        monsterZoom = mz
        setNeedsDisplay()
    }
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        guard visible, !gameDataString.isEmpty else { return }
        
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        ctx.clear(rect)
        ctx.interpolationQuality = .high
        
        let parts = gameDataString.components(separatedBy: "---")
        if parts.count >= 1, !parts[0].isEmpty {
            drawHeroes(ctx: ctx, heroPart: parts[0])
        }
        if parts.count >= 2, !parts[1].isEmpty {
            drawMonsters(ctx: ctx, monsterPart: parts[1])
        }
    }
    
    private func heroX(_ gameX: Float) -> Float {
        return gameX * heroScale + globalOffsetX + heroOffsetX
    }
    
    private func heroY(_ gameY: Float) -> Float {
        return gameY * heroScale + globalOffsetY + heroOffsetY
    }
    
    private func monsterX(_ gameX: Float) -> Float {
        return gameX * monsterScale + globalOffsetX + monsterOffsetX
    }
    
    private func monsterY(_ gameY: Float) -> Float {
        return gameY * monsterScale + globalOffsetY + monsterOffsetY
    }
    
    private func drawHeroes(ctx: CGContext, heroPart: String) {
        let heroStrings = heroPart.components(separatedBy: "==")
        for heroStr in heroStrings {
            guard let hero = HeroData.parse(heroStr) else { continue }
            
            let size = heroSize * heroScale
            let drawX = heroX(hero.x)
            let drawY = heroY(hero.y)
            let halfSize = size / 2
            let cx = drawX + halfSize
            let cy = drawY + halfSize
            let radius = halfSize - 1
            
            if let image = getHeroImage(String(hero.id)) {
                let imageRect = CGRect(x: CGFloat(drawX), y: CGFloat(drawY), width: CGFloat(size), height: CGFloat(size))
                ctx.saveGState()
                ctx.addEllipse(in: imageRect.insetBy(dx: CGFloat(1), dy: CGFloat(1)))
                ctx.clip()
                image.draw(in: imageRect)
                ctx.restoreGState()
            } else {
                let teamColor = hero.team == 1 ? colorBlueBorder : colorRedBorder
                ctx.setFillColor(teamColor.withAlphaComponent(0.6).cgColor)
                ctx.addEllipse(in: CGRect(x: CGFloat(drawX + 1), y: CGFloat(drawY + 1), width: CGFloat(size - 2), height: CGFloat(size - 2)))
                ctx.fillPath()
                loadHeroImageAsync(String(hero.id))
            }
            
            let borderColor = hero.team == 1 ? colorBlueBorder : colorRedBorder
            ctx.setStrokeColor(borderColor.cgColor)
            ctx.setLineWidth(CGFloat(max(1.5, 2.5 * heroScale / safeDivScale())))
            ctx.addEllipse(in: CGRect(x: CGFloat(drawX), y: CGFloat(drawY), width: CGFloat(size), height: CGFloat(size)))
            ctx.strokePath()
            
            let smallR = CGFloat(max(3, 6 * heroScale / safeDivScale()))
            let greenCx = drawX + Float(smallR) + 1
            let greenCy = drawY + size - Float(smallR) - 1
            ctx.setFillColor(UIColor.white.cgColor)
            ctx.addEllipse(in: CGRect(x: CGFloat(greenCx - smallR - 1), y: CGFloat(greenCy - smallR - 1), width: (smallR + 1) * 2, height: (smallR + 1) * 2))
            ctx.fillPath()
            ctx.setFillColor(UIColor(red: 0.19, green: 0.82, blue: 0.35, alpha: 1).cgColor)
            ctx.addEllipse(in: CGRect(x: CGFloat(greenCx - smallR), y: CGFloat(greenCy - smallR), width: smallR * 2, height: smallR * 2))
            ctx.fillPath()
            
            let yellowCx = drawX + size - Float(smallR) - 1
            let yellowCy = drawY + size - Float(smallR) - 1
            ctx.setFillColor(UIColor.white.cgColor)
            ctx.addEllipse(in: CGRect(x: CGFloat(yellowCx - smallR - 1), y: CGFloat(yellowCy - smallR - 1), width: (smallR + 1) * 2, height: (smallR + 1) * 2))
            ctx.fillPath()
            ctx.setFillColor(UIColor(red: 1, green: 0.72, blue: 0, alpha: 1).cgColor)
            ctx.addEllipse(in: CGRect(x: CGFloat(yellowCx - smallR), y: CGFloat(yellowCy - smallR), width: smallR * 2, height: smallR * 2))
            ctx.fillPath()
            
            if hero.level > 0 {
                drawLevel(ctx: ctx, x: drawX, y: drawY, size: size, level: hero.level, team: hero.team)
            }
            
            drawCDIndicators(ctx: ctx, greenCx: greenCx, greenCy: greenCy, yellowCx: yellowCx, yellowCy: yellowCy, hero: hero)
            drawHP(ctx: ctx, x: drawX, y: drawY + size, size: size, hp: hero.hp, team: hero.team)
        }
    }
    
    private func drawLevel(ctx: CGContext, x: Float, y: Float, size: Float, level: Int, team: Int) {
        let fontSize = CGFloat(max(6, 8 * heroScale / safeDivScale()))
        let text = "Lv.\(level)" as NSString
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: fontSize),
            .foregroundColor: UIColor.white
        ]
        let textSize = text.size(withAttributes: attrs)
        let padding = CGFloat(1.5 * heroScale / safeDivScale())
        let bgW = textSize.width + padding * 2
        let bgH = textSize.height + padding
        let bgX = CGFloat(x + size) - bgW / 2 - 1
        let bgY = CGFloat(y) + bgH / 2 + 1
        
        let bgColor = team == 1 ? UIColor(red: 0.29, green: 0.62, blue: 1, alpha: 0.9) : UIColor(red: 1, green: 0.27, blue: 0.23, alpha: 0.9)
        ctx.setFillColor(bgColor.cgColor)
        let bgRect = CGRect(x: bgX - bgW / 2, y: bgY - bgH / 2, width: bgW, height: bgH)
        ctx.addRect(bgRect)
        ctx.fillPath()
        
        text.draw(at: CGPoint(x: bgX - textSize.width / 2, y: bgY - textSize.height / 2), withAttributes: attrs)
    }
    
    private func drawCDIndicators(ctx: CGContext, greenCx: Float, greenCy: Float, yellowCx: Float, yellowCy: Float, hero: HeroData) {
        let fontSize = CGFloat(max(5, 6 * heroScale / safeDivScale()))
        let ultText = hero.ultCD > 0 ? "\(Int(ceil(Float(hero.ultCD))))" : "R"
        let skillText = hero.skillCD > 0 ? "\(Int(ceil(Float(hero.skillCD))))" : "S"
        
        let ultAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: fontSize), .foregroundColor: UIColor.white]
        let skillAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: fontSize), .foregroundColor: UIColor.black]
        
        (ultText as NSString).draw(at: CGPoint(x: CGFloat(greenCx) - fontSize / 2, y: CGFloat(greenCy) - fontSize / 2), withAttributes: ultAttrs)
        (skillText as NSString).draw(at: CGPoint(x: CGFloat(yellowCx) - fontSize / 2, y: CGFloat(yellowCy) - fontSize / 2), withAttributes: skillAttrs)
    }
    
    private func drawHP(ctx: CGContext, x: Float, y: Float, size: Float, hp: Int, team: Int) {
        let maxWidth = CGFloat(size)
        let hpWidth = CGFloat(Float(hp) / 100.0) * maxWidth
        let strokeWidth = CGFloat(max(1.5, 3 * heroScale / safeDivScale()))
        
        ctx.setStrokeColor(UIColor.white.withAlphaComponent(0.6).cgColor)
        ctx.setLineWidth(strokeWidth)
        ctx.move(to: CGPoint(x: CGFloat(x), y: CGFloat(y)))
        ctx.addLine(to: CGPoint(x: CGFloat(x) + maxWidth, y: CGFloat(y)))
        ctx.strokePath()
        
        let hpColor = team == 1 ? colorBlueHP : colorRedHP
        ctx.setStrokeColor(hpColor.cgColor)
        ctx.move(to: CGPoint(x: CGFloat(x), y: CGFloat(y)))
        ctx.addLine(to: CGPoint(x: CGFloat(x) + hpWidth, y: CGFloat(y)))
        ctx.strokePath()
    }
    
    private func drawMonsters(ctx: CGContext, monsterPart: String) {
        let monsterStrings = monsterPart.components(separatedBy: "==")
        var monsters: [MonsterData] = []
        var cdMap: [String: Int] = [:]
        
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
            
            let drawX = monsterX(m.x)
            let drawY = monsterY(m.y)
            
            if hideCountdown || m.isFullCD || m.cd == 0 {
                let r = CGFloat(max(2.5, 3.5 * monsterScale / safeDivScale() * monsterZoom))
                ctx.setFillColor(colorMonster.cgColor)
                ctx.addEllipse(in: CGRect(x: CGFloat(drawX) - r, y: CGFloat(drawY) - r, width: r * 2, height: r * 2))
                ctx.fillPath()
                ctx.setStrokeColor(UIColor.white.cgColor)
                ctx.setLineWidth(CGFloat(max(1, 1.2 * monsterScale / safeDivScale() * monsterZoom)))
                ctx.addEllipse(in: CGRect(x: CGFloat(drawX) - r, y: CGFloat(drawY) - r, width: r * 2, height: r * 2))
                ctx.strokePath()
            } else if m.cd > 0 && m.cd <= 240 {
                let fontSize = CGFloat(max(7, 9 * monsterScale / safeDivScale() * monsterZoom))
                let cdText = "\(m.cd)" as NSString
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: fontSize),
                    .foregroundColor: colorMonster
                ]
                let textSize = cdText.size(withAttributes: attrs)
                let padding = CGFloat(2 * monsterScale / safeDivScale() * monsterZoom)
                
                let bgX = CGFloat(drawX) - textSize.width / 2 - padding
                let bgY = CGFloat(drawY) - textSize.height / 2 - padding
                ctx.setFillColor(UIColor(white: 0, alpha: 0.7).cgColor)
                ctx.addRect(CGRect(x: bgX, y: bgY, width: textSize.width + padding * 2, height: textSize.height + padding * 2))
                ctx.fillPath()
                
                cdText.draw(at: CGPoint(x: CGFloat(drawX) - textSize.width / 2, y: CGFloat(drawY) - textSize.height / 2), withAttributes: attrs)
            }
        }
    }
    
    private func getHeroImage(_ heroId: String) -> UIImage? {
        return cacheQueue.sync { heroImageCache[heroId] }
    }
    
    private func loadHeroImageAsync(_ heroId: String) {
        let shouldLoad = cacheQueue.sync { () -> Bool in
            if heroImageCache[heroId] != nil { return false }
            if loadingSet.contains(heroId) { return false }
            if loadingSet.count >= maxLoading { return false }
            loadingSet.insert(heroId)
            return true
        }
        
        guard shouldLoad else { return }
        
        Task { [weak self] in
            guard let self = self else { return }
            defer {
                self.cacheQueue.sync(flags: .barrier) {
                    self.loadingSet.remove(heroId)
                }
            }
            
            guard let url = URL(string: "\(self.heroImageURLBase)\(heroId)/\(heroId).jpg") else { return }
            
            let session = URLSession.shared
            guard let data = try? await session.data(from: url).0,
                  let image = UIImage(data: data) else { return }
            
            let targetSize = CGSize(width: 120, height: 120)
            let renderer = UIGraphicsImageRenderer(size: targetSize)
            let scaled = renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: targetSize))
            }
            
            self.cacheQueue.sync(flags: .barrier) {
                if self.heroImageCache.count >= self.maxCacheSize {
                    if let firstKey = self.heroImageCache.keys.first {
                        self.heroImageCache.removeValue(forKey: firstKey)
                    }
                }
                self.heroImageCache[heroId] = scaled
            }
            
            DispatchQueue.main.async { [weak self] in self?.setNeedsDisplay() }
        }
    }
}
