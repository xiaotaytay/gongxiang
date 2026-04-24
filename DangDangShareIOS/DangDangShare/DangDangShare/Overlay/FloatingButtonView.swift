import UIKit

class FloatingButtonView: UIView {
    var onTap: (() -> Void)?
    
    private var initialCenter: CGPoint = .zero
    private var initialTouch: CGPoint = .zero
    private var isDragging = false
    private var touchStartTime: TimeInterval = 0
    private let dragThreshold: CGFloat = 8
    private let tapThreshold: TimeInterval = 0.3
    
    init() {
        let size: CGFloat = 36
        let x: CGFloat = 8
        let y: CGFloat = 80
        super.init(frame: CGRect(x: x, y: y, width: size, height: size))
        
        backgroundColor = UIColor.white.withAlphaComponent(0.15)
        layer.cornerRadius = size / 2
        layer.borderWidth = 0.5
        layer.borderColor = UIColor.white.withAlphaComponent(0.12).cgColor
        clipsToBounds = true
        
        let imageView = UIImageView(frame: bounds.insetBy(dx: 5, dy: 5))
        imageView.contentMode = .scaleAspectFit
        imageView.alpha = 0.7
        
        if let icon = loadAppIcon() {
            imageView.image = icon
        } else {
            imageView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.5)
            imageView.layer.cornerRadius = (size - 10) / 2
        }
        addSubview(imageView)
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    private func loadAppIcon() -> UIImage? {
        if let path = Bundle.main.path(forResource: "111", ofType: "jpg"),
           let image = UIImage(contentsOfFile: path) {
            return image
        }
        if let url = Bundle.main.url(forResource: "111", withExtension: "jpg"),
           let data = try? Data(contentsOf: url),
           let image = UIImage(data: data) {
            return image
        }
        for bundleURL in [Bundle.main.resourceURL, Bundle.main.bundleURL] {
            if let url = bundleURL?.appendingPathComponent("111.jpg") {
                if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                    return image
                }
            }
        }
        return nil
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        guard let touch = touches.first else { return }
        initialCenter = center
        initialTouch = touch.location(in: superview)
        isDragging = false
        touchStartTime = CACurrentMediaTime()
        
        UIView.animate(withDuration: 0.1) {
            self.alpha = 0.9
            self.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        guard let touch = touches.first else { return }
        let location = touch.location(in: superview)
        let dx = location.x - initialTouch.x
        let dy = location.y - initialTouch.y
        
        if abs(dx) > dragThreshold || abs(dy) > dragThreshold { isDragging = true }
        if isDragging {
            let newCenter = CGPoint(x: initialCenter.x + dx, y: initialCenter.y + dy)
            let safeBounds = UIScreen.main.bounds
            let halfW = bounds.width / 2
            let halfH = bounds.height / 2
            center = CGPoint(
                x: max(halfW, min(safeBounds.width - halfW, newCenter.x)),
                y: max(halfH, min(safeBounds.height - halfH, newCenter.y))
            )
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        
        UIView.animate(withDuration: 0.15) {
            self.alpha = 1.0
            self.transform = .identity
        }
        
        if !isDragging {
            let elapsed = CACurrentMediaTime() - touchStartTime
            if elapsed < tapThreshold {
                onTap?()
            }
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        UIView.animate(withDuration: 0.15) {
            self.alpha = 1.0
            self.transform = .identity
        }
    }
}
