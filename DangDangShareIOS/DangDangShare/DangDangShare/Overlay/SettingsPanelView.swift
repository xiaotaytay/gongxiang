import UIKit

class SettingsPanelView: UIView {
    var onClose: (() -> Void)?
    var onSettingsChanged: ((Float, Float, Float, Float, Float, Float, Float, Float, Float) -> Void)?
    
    private var sliders: [String: UISlider] = [:]
    private var labels: [String: UILabel] = [:]
    private let defaults = UserDefaults.standard
    private var debounceTimer: Timer?
    private let debounceInterval: TimeInterval = 0.08
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    private func setupUI() {
        backgroundColor = UIColor(white: 0.1, alpha: 0.92)
        layer.cornerRadius = 14
        layer.borderWidth = 0.5
        layer.borderColor = UIColor.white.withAlphaComponent(0.18).cgColor
        clipsToBounds = true
        
        let scrollView = UIScrollView()
        scrollView.showsVerticalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)
        
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 3
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            stack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 8),
            stack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 10),
            stack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -10),
            stack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -8),
            stack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -20)
        ])
        
        addSection(stack, title: "整体偏移", items: [
            ("global_offset_x", "水平偏移", -1000, 1000, defaults.object(forKey: "global_offset_x") as? Float ?? 0),
            ("global_offset_y", "垂直偏移", -1000, 1000, defaults.object(forKey: "global_offset_y") as? Float ?? 0)
        ])
        
        addDivider(stack)
        
        addSection(stack, title: "英雄缩放", items: [
            ("hero_offset_x", "水平偏移", -1000, 1000, defaults.object(forKey: "hero_offset_x") as? Float ?? 0),
            ("hero_offset_y", "垂直偏移", -1000, 1000, defaults.object(forKey: "hero_offset_y") as? Float ?? 0),
            ("hero_scale", "缩放比例", 0, 300, (defaults.object(forKey: "hero_scale") as? Float ?? 1.0) * 100)
        ])
        
        addDivider(stack)
        
        addSection(stack, title: "野怪缩放", items: [
            ("monster_offset_x", "水平偏移", -1000, 1000, defaults.object(forKey: "monster_offset_x") as? Float ?? 0),
            ("monster_offset_y", "垂直偏移", -1000, 1000, defaults.object(forKey: "monster_offset_y") as? Float ?? 0),
            ("monster_scale", "缩放比例", 0, 300, (defaults.object(forKey: "monster_scale") as? Float ?? 1.0) * 100),
            ("monster_zoom", "放大倍数", 0, 50, (defaults.object(forKey: "monster_zoom") as? Float ?? 1.0) * 10)
        ])
        
        addDivider(stack)
        
        let lockBtn = UIButton(type: .system)
        lockBtn.setTitle("🔒 锁定画中画窗口", for: .normal)
        lockBtn.setTitleColor(UIColor.white.withAlphaComponent(0.7), for: .normal)
        lockBtn.titleLabel?.font = .systemFont(ofSize: 11)
        lockBtn.addTarget(self, action: #selector(lockTapped), for: .touchUpInside)
        stack.addArrangedSubview(lockBtn)
        
        addDivider(stack)
        
        let authorLabel = UILabel()
        authorLabel.text = "作者：当当  QQ：1978781085"
        authorLabel.textColor = UIColor.white.withAlphaComponent(0.35)
        authorLabel.font = .systemFont(ofSize: 10)
        authorLabel.textAlignment = .center
        stack.addArrangedSubview(authorLabel)
        
        let closeBtn = UIButton(type: .system)
        closeBtn.setTitle("关闭", for: .normal)
        closeBtn.setTitleColor(UIColor.white.withAlphaComponent(0.6), for: .normal)
        closeBtn.titleLabel?.font = .systemFont(ofSize: 12)
        closeBtn.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        stack.addArrangedSubview(closeBtn)
    }
    
    private func addSection(_ stack: UIStackView, title: String, items: [(String, String, Float, Float, Float)]) {
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.textColor = .white
        titleLabel.font = .boldSystemFont(ofSize: 12)
        stack.addArrangedSubview(titleLabel)
        
        for (key, label, minVal, maxVal, value) in items {
            let row = createSliderRow(key: key, label: label, minVal: minVal, maxVal: maxVal, value: value)
            stack.addArrangedSubview(row)
        }
    }
    
    private func createSliderRow(key: String, label: String, minVal: Float, maxVal: Float, value: Float) -> UIView {
        let row = UIStackView()
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 4
        
        let lbl = UILabel()
        lbl.text = label
        lbl.textColor = UIColor.white.withAlphaComponent(0.7)
        lbl.font = .systemFont(ofSize: 10)
        lbl.widthAnchor.constraint(equalToConstant: 52).isActive = true
        row.addArrangedSubview(lbl)
        
        let slider = UISlider()
        slider.minimumValue = minVal
        slider.maximumValue = maxVal
        slider.value = value
        slider.minimumTrackTintColor = UIColor(red: 0.04, green: 0.52, blue: 1, alpha: 1)
        slider.maximumTrackTintColor = UIColor.white.withAlphaComponent(0.12)
        slider.addTarget(self, action: #selector(sliderChanged(_:)), for: .valueChanged)
        sliders[key] = slider
        row.addArrangedSubview(slider)
        
        let valLabel = UILabel()
        valLabel.text = formatValue(key: key, value: value)
        valLabel.textColor = UIColor.white.withAlphaComponent(0.5)
        valLabel.font = .systemFont(ofSize: 9)
        valLabel.widthAnchor.constraint(equalToConstant: 42).isActive = true
        valLabel.textAlignment = .right
        labels[key] = valLabel
        row.addArrangedSubview(valLabel)
        
        return row
    }
    
    private func addDivider(_ stack: UIStackView) {
        let divider = UIView()
        divider.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        divider.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
        stack.addArrangedSubview(divider)
    }
    
    private func formatValue(key: String, value: Float) -> String {
        if key.contains("scale") {
            return String(format: "%.2f", value / 100)
        } else if key.contains("zoom") {
            return String(format: "%.1fx", value / 10)
        } else {
            return "\(Int(value))"
        }
    }
    
    @objc private func sliderChanged(_ slider: UISlider) {
        for (key, slider) in sliders {
            labels[key]?.text = formatValue(key: key, value: slider.value)
        }
        
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: debounceInterval, repeats: false) { [weak self] _ in
            self?.applySettings()
        }
    }
    
    private func applySettings() {
        let globalX = sliders["global_offset_x"]?.value ?? 0
        let globalY = sliders["global_offset_y"]?.value ?? 0
        let hox = sliders["hero_offset_x"]?.value ?? 0
        let hoy = sliders["hero_offset_y"]?.value ?? 0
        let hs = (sliders["hero_scale"]?.value ?? 100) / 100
        let mox = sliders["monster_offset_x"]?.value ?? 0
        let moy = sliders["monster_offset_y"]?.value ?? 0
        let ms = (sliders["monster_scale"]?.value ?? 100) / 100
        let mz = (sliders["monster_zoom"]?.value ?? 10) / 10
        
        defaults.set(globalX, forKey: "global_offset_x")
        defaults.set(globalY, forKey: "global_offset_y")
        defaults.set(hox, forKey: "hero_offset_x")
        defaults.set(hoy, forKey: "hero_offset_y")
        defaults.set(hs, forKey: "hero_scale")
        defaults.set(mox, forKey: "monster_offset_x")
        defaults.set(moy, forKey: "monster_offset_y")
        defaults.set(ms, forKey: "monster_scale")
        defaults.set(mz, forKey: "monster_zoom")
        
        onSettingsChanged?(globalX, globalY, hox, hoy, hs, mox, moy, ms, mz)
    }
    
    @objc private func closeTapped() {
        onClose?()
    }
    
    @objc private func lockTapped(_ btn: UIButton) {
        let locked = !PiPManager.shared.getLocked()
        PiPManager.shared.setLocked(locked)
        btn.setTitle(locked ? "🔓 解锁画中画窗口" : "🔒 锁定画中画窗口", for: .normal)
    }
    
    override func sizeToFit() {
        super.sizeToFit()
        let targetSize = systemLayoutSizeFitting(
            CGSize(width: 260, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        frame.size.height = min(targetSize.height, UIScreen.main.bounds.height * 0.7)
    }
}
