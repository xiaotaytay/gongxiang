import UIKit

class OverlayManager {
    static let shared = OverlayManager()
    
    var overlayWindow: UIWindow?
    var radarView: RadarOverlayView?
    private var isInBackground = false
    
    private init() {}
    
    @MainActor
    func showOverlay() {
        guard overlayWindow == nil else { return }
        
        let windowScene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first
        guard let ws = windowScene else { return }
        
        let passthroughWindow = PassthroughWindow(windowScene: ws)
        passthroughWindow.frame = ws.screen.bounds
        passthroughWindow.windowLevel = .statusBar + 1
        passthroughWindow.backgroundColor = .clear
        passthroughWindow.isHidden = false
        self.overlayWindow = passthroughWindow
        
        let container = PassthroughView(frame: ws.screen.bounds)
        container.backgroundColor = .clear
        container.isUserInteractionEnabled = true
        passthroughWindow.rootViewController = PassthroughViewController()
        passthroughWindow.rootViewController?.view = container
        passthroughWindow.rootViewController?.view.backgroundColor = .clear
        
        let radar = RadarOverlayView(frame: ws.screen.bounds)
        radar.isUserInteractionEnabled = false
        container.addSubview(radar)
        radarView = radar
        
        PiPManager.shared.updateRadarView(radar)
        PiPManager.shared.setup()
        PiPManager.shared.startPiP()
    }
    
    @MainActor
    func hideOverlay() {
        radarView?.removeFromSuperview()
        overlayWindow?.isHidden = true
        overlayWindow = nil
        radarView = nil
        isInBackground = false
        PiPManager.shared.updateRadarView(nil)
        PiPManager.shared.stopPiP()
    }
    
    @MainActor
    func enterBackground() {
        guard overlayWindow != nil else { return }
        isInBackground = true
        radarView?.isHidden = true
        overlayWindow?.isHidden = true
    }
    
    @MainActor
    func enterForeground() {
        guard overlayWindow != nil else { return }
        isInBackground = false
        radarView?.isHidden = false
        overlayWindow?.isHidden = false
        overlayWindow?.makeKey()
    }
    
    @MainActor
    func updateGameData(_ data: String) {
        radarView?.gameDataString = data
        radarView?.setNeedsDisplay()
        PiPManager.shared.updateGameData(data)
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
            if subview.point(inside: converted, with: event) {
                return subview.hitTest(converted, with: event)
            }
        }
        return nil
    }
}
