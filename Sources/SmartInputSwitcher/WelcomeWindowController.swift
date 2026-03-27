import Cocoa
import ServiceManagement

class WelcomeWindowController: NSWindowController {
    
    private var stackView: NSStackView!
    private var currentPage = 0
    
    init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 320),
                              styleMask: [.titled, .fullSizeContentView],
                              backing: .buffered,
                              defer: false)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.backgroundColor = NSColor.windowBackgroundColor
        
        super.init(window: window)
        window.center()
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        guard let window = window, let contentView = window.contentView else { return }
        
        // 视觉效果背景
        let visualEffect = NSVisualEffectView(frame: contentView.bounds)
        visualEffect.autoresizingMask = [.width, .height]
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.material = .underWindowBackground
        contentView.addSubview(visualEffect)
        
        stackView = NSStackView(frame: contentView.bounds.insetBy(dx: 40, dy: 40))
        stackView.autoresizingMask = [.width, .height]
        stackView.orientation = .vertical
        stackView.spacing = 20
        stackView.alignment = .centerX
        stackView.distribution = .gravityAreas
        
        contentView.addSubview(stackView)
        
        showPage(0)
    }
    
    private func showPage(_ index: Int) {
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        switch index {
        case 0:
            let title = createLabel("欢迎使用 SimpleSwitch", size: 24, weight: .bold)
            let desc = createLabel("极致顺滑的 macOS 智能输入法切换工具。\n自动感知应用状态，让输入不再断档。", size: 14)
            desc.alignment = .center
            
            let btn = createButton("开始设置", action: #selector(nextPage))
            
            stackView.addArrangedSubview(title)
            stackView.addArrangedSubview(desc)
            stackView.setCustomSpacing(40, after: desc)
            stackView.addArrangedSubview(btn)
            
        case 1:
            let title = createLabel("开机自启动", size: 20, weight: .semibold)
            let desc = createLabel("建议开启此项，确保应用时刻为您守护切换状态。", size: 13)
            
            let statusLabel = createLabel(SMAppService.mainApp.status == .enabled ? "当前状态：已开启" : "当前状态：未开启", size: 12)
            statusLabel.textColor = .secondaryLabelColor
            
            let btn = createButton("一键开启自启", action: #selector(toggleLaunchAtLogin))
            let nextBtn = createButton("下一步", action: #selector(nextPage))
            nextBtn.bezelStyle = .recessed
            
            stackView.addArrangedSubview(title)
            stackView.addArrangedSubview(desc)
            stackView.addArrangedSubview(statusLabel)
            stackView.addArrangedSubview(btn)
            stackView.addArrangedSubview(nextBtn)
            
        case 2:
            let title = createLabel("权限检查", size: 20, weight: .semibold)
            let desc = createLabel("虽然目前核心功能无需权限，但开启“辅助功能”\n权限能让应用在复杂窗口中的感应更精准。", size: 13)
            desc.alignment = .center
            
            let isTrusted = AXIsProcessTrusted()
            let statusLabel = createLabel(isTrusted ? "✅ 已获得辅助功能权限" : "⚠️ 尚未获取权限", size: 12)
            
            let btn = createButton("打开系统设置", action: #selector(openPermissions))
            let finishBtn = createButton("完成并进入菜单栏", action: #selector(finish))
            finishBtn.keyEquivalent = "\r" // Enter key
            
            stackView.addArrangedSubview(title)
            stackView.addArrangedSubview(desc)
            stackView.addArrangedSubview(statusLabel)
            stackView.addArrangedSubview(btn)
            stackView.setCustomSpacing(30, after: btn)
            stackView.addArrangedSubview(finishBtn)
            
        default:
            break
        }
    }
    
    private func createLabel(_ text: String, size: CGFloat, weight: NSFont.Weight = .regular) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: size, weight: weight)
        label.isEditable = false
        label.isSelectable = false
        label.alignment = .center
        return label
    }
    
    private func createButton(_ title: String, action: Selector) -> NSButton {
        let btn = NSButton(title: title, target: self, action: action)
        btn.bezelStyle = .rounded
        btn.controlSize = .large
        return btn
    }
    
    @objc private func nextPage() {
        currentPage += 1
        showPage(currentPage)
    }
    
    @objc private func toggleLaunchAtLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
            showPage(1) // 刷新状态
        } catch {
            let alert = NSAlert()
            alert.messageText = "设置失败"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }
    
    @objc private func openPermissions() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
    
    @objc private func finish() {
        UserDefaults.standard.set(true, forKey: "HasSeenWelcomePagev2")
        window?.close()
    }
}
