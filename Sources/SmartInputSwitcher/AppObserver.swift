import Cocoa

class AppObserver {
    static let shared = AppObserver()
    
    var onAppActivated: ((String, String?) -> Void)?
    var isEnabled: Bool = true {
        didSet {
            // 如果刚刚开启，顺便对当前最前台的应用执行一次策略
            if isEnabled {
                if let activeApp = NSWorkspace.shared.frontmostApplication,
                   let bundleId = activeApp.bundleIdentifier {
                    onAppActivated?(bundleId, activeApp.localizedName)
                }
            }
        }
    }
    
    func start() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appDidActivate(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        
        // 初始应用
        if let activeApp = NSWorkspace.shared.frontmostApplication,
           let bundleId = activeApp.bundleIdentifier {
            onAppActivated?(bundleId, activeApp.localizedName)
        }
    }
    
    @objc private func appDidActivate(_ notification: Notification) {
        guard isEnabled else { return }
        
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let bundleIdentifier = app.bundleIdentifier else {
            return
        }
        
        onAppActivated?(bundleIdentifier, app.localizedName)
    }
}
