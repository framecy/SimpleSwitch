import Cocoa

class HUDWindowController: NSWindowController {
    
    private let label = NSTextField(labelWithString: "")
    private var hideWorkItem: DispatchWorkItem?
    
    init() {
        // 初始大小和位置随意，showHUD 时会重新计算
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 160, height: 60),
                              styleMask: [.borderless],
                              backing: .buffered,
                              defer: false)
        
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.ignoresMouseEvents = true // 不阻挡鼠标事件
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.alphaValue = 0.0
        
        super.init(window: window)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        guard let window = window else { return }
        
        // 使用普通 View+CALayer 替代 NSVisualEffectView，后者在系统输入法切换时同时开启动画会导致严重的 WindowServer 渲染卡顿
        let containerView = NSView(frame: window.contentView!.bounds)
        containerView.autoresizingMask = [.width, .height]
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.65).cgColor
        containerView.layer?.cornerRadius = 12
        containerView.layer?.masksToBounds = true
        
        label.font = NSFont.systemFont(ofSize: 20, weight: .bold)
        label.textColor = .white
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addSubview(label)
        
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: containerView.centerYAnchor)
        ])
        
        window.contentView?.addSubview(containerView)
    }
    
    // 获取当前鼠标所在的屏幕，作为当前激活的屏幕
    private func getActiveScreen() -> NSScreen {
        let mouseLoc = NSEvent.mouseLocation
        if let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLoc, $0.frame, false) }) {
            return screen
        }
        return NSScreen.main ?? NSScreen.screens.first!
    }
    
    func showHUD(with text: String) {
        label.stringValue = text
        hideWorkItem?.cancel()
        
        // 重新计算并设置窗口位置到当前激活屏幕的右上角
        let screenRect = getActiveScreen().visibleFrame
        let hudWidth: CGFloat = 160
        let hudHeight: CGFloat = 60
        let margin: CGFloat = 20
        let hudRect = NSRect(x: screenRect.maxX - hudWidth - margin,
                             y: screenRect.maxY - hudHeight - margin,
                             width: hudWidth,
                             height: hudHeight)
        window?.setFrame(hudRect, display: true)
        
        // 仅把窗口调到前面即可，不要使用 orderFrontRegardless() 强占，这样容易产生卡顿
        window?.orderFront(nil)
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15 // 将动画缩短，更丝滑
            self.window?.animator().alphaValue = 1.0
        }, completionHandler: {
            // 设置延时隐藏
            let workItem = DispatchWorkItem { [weak self] in
                self?.hideHUD()
            }
            self.hideWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: workItem)
        })
    }
    
    private func hideHUD() {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.5
            self.window?.animator().alphaValue = 0.0
        }, completionHandler: nil)
    }
}
