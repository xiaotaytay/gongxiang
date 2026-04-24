import UIKit

class OverlayManager {
    static let shared = OverlayManager()
    
    var overlayWindow: UIWindow?
    var radarView: RadarOverlayView?
    var floatingButton: FloatingButtonView?
    var settingsPanel: SettingsPanelView?
    var settingsVisible = false
    
    private var touchPassthroughWindow: PassthroughWindow?
    
    private init() {}
    
    func showOverlay() {
        guard overlayWindow == nil else { return }
        
        guard let windowScene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else { return }
        
        let passthroughWindow = PassthroughWindow(windowScene: windowScene)
        passthroughWindow.frame = UIScreen.main.bounds
        passthroughWindow.windowLevel = .statusBar + 1
        passthroughWindow.backgroundColor = .clear
        passthroughWindow.isHidden = false
        self.touchPassthroughWindow = passthroughWindow
        
        let container = PassthroughView(frame: UIScreen.main.bounds)
        container.backgroundColor = .clear
        passthroughWindow.rootViewController = PassthroughViewController()
        passthroughWindow.rootViewController?.view = container
        passthroughWindow.rootViewController?.view.backgroundColor = .clear
        
        let radar = RadarOverlayView(frame: UIScreen.main.bounds)
        radar.isUserInteractionEnabled = false
        container.addSubview(radar)
        radarView = radar
        
        let floating = FloatingButtonView()
        floating.onTap = { [weak self] in
            self?.toggleSettings()
        }
        container.addSubview(floating)
        floatingButton = floating
        
        overlayWindow = passthroughWindow
        
        PiPManager.shared.updateRadarView(radar)
        PiPManager.shared.setup()
    }
    
    func hideOverlay() {
        radarView?.removeFromSuperview()
        floatingButton?.removeFromSuperview()
        settingsPanel?.removeFromSuperview()
        touchPassthroughWindow?.isHidden = true
        touchPassthroughWindow = nil
        overlayWindow = nil
        radarView = nil
        floatingButton = nil
        settingsPanel = nil
        settingsVisible = false
        
        PiPManager.shared.updateRadarView(nil)
        PiPManager.shared.stopPiP()
    }
    
    func updateGameData(_ data: String) {
        radarView?.gameDataString = data
        radarView?.setNeedsDisplay()
        PiPManager.shared.updateGameData(data)
    }
    
    func toggleSettings() {
        if settingsVisible {
            settingsPanel?.removeFromSuperview()
            settingsPanel = nil
            settingsVisible = false
        } else {
            showSettings()
        }
    }
    
    private func showSettings() {
        guard let container = touchPassthroughWindow?.rootViewController?.view,
              let btn = floatingButton else { return }
        settingsVisible = true
        
        let panel = SettingsPanelView()
        panel.onClose = { [weak self] in
            self?.settingsPanel?.removeFromSuperview()
            self?.settingsPanel = nil
            self?.settingsVisible = false
        }
        panel.onSettingsChanged = { [weak self] globalX, globalY, hox, hoy, hs, mox, moy, ms, mz in
            self?.radarView?.updateSettings(globalX: globalX, globalY: globalY,
                                             heroOffsetX: hox, heroOffsetY: hoy, heroScale: hs,
                                             monsterOffsetX: mox, monsterOffsetY: moy, monsterScale: ms, monsterZoom: mz)
        }
        
        let btnFrame = btn.frame
        let panelWidth: CGFloat = 260
        let screenBounds = UIScreen.main.bounds
        let panelX = min(btnFrame.maxX + 8, screenBounds.width - panelWidth - 8)
        let panelY = max(btnFrame.minY, 40)
        
        panel.frame = CGRect(x: panelX, y: panelY, width: panelWidth, height: 0)
        panel.sizeToFit()
        
        let maxY = screenBounds.height - 40
        if panel.frame.maxY > maxY {
            panel.frame.size.height = maxY - panelY
        }
        
        container.addSubview(panel)
        settingsPanel = panel
    }
}

class PassthroughWindow: UIWindow {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let view = super.hitTest(point, with: event)
        if view === self || view === rootViewController?.view {
            return nil
        }
        return view
    }
}

class PassthroughViewController: UIViewController {
    override var prefersStatusBarHidden: Bool { false }
}

class PassthroughView: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        for subview in subviews.reversed() {
            let converted = convert(point, to: subview)
            if subview.point(inside: converted, with: event), subview.isUserInteractionEnabled {
                return subview.hitTest(converted, with: event)
            }
        }
        return nil
    }
}
