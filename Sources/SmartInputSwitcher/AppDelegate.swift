import Cocoa
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var isEnabled = true
    var hudController: HUDWindowController?
    var lastManualSwitchTime: Date?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        checkAccessibilityPermissions()
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "keyboard.badge.waveform", accessibilityDescription: "Smart Input Switcher")
            updateStatusBarButtonTitle()
        }
        
        setupMenu()
        
        hudController = HUDWindowController()
        
        // 监听输入法切换
        InputMethodManager.shared.onInputMethodChanged = { [weak self] name in
            self?.lastManualSwitchTime = Date()
            self?.updateStatusBarButtonTitle()
            self?.hudController?.showHUD(with: name)
        }
        
        // 初始化辅助功能监听
        FocusObserver.shared.onFocusLost = { [weak self] in
            guard let self = self, self.isEnabled else { return }
            
            // 如果距离上一次手动切换不到 1秒，忽略这次焦点丢失，防止与系统HUD或快捷键切换冲突打架导致长按大写被触发
            if let lastTime = self.lastManualSwitchTime, Date().timeIntervalSince(lastTime) < 1.0 {
                return
            }
            
            InputMethodManager.shared.switchToEnglish()
        }
        FocusObserver.shared.start()
    }
    
    func updateStatusBarButtonTitle() {
        if let button = statusItem.button {
            let name = InputMethodManager.shared.getCurrentInputMethodName()
            button.title = " \(name)"
        }
    }
    
    func setupMenu() {
        let menu = NSMenu()
        
        let enableItem = NSMenuItem(title: "✓ 自动切换到英文", action: #selector(toggleAutoSwitch), keyEquivalent: "")
        enableItem.tag = 100
        menu.addItem(enableItem)
        
        let loginItem = NSMenuItem(title: "开机自启动", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        loginItem.tag = 200
        if SMAppService.mainApp.status == .enabled {
            loginItem.title = "✓ 开机自启动"
        }
        menu.addItem(loginItem)
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q"))
        
        statusItem.menu = menu
    }
    
    func checkAccessibilityPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        if !accessEnabled {
            let alert = NSAlert()
            alert.messageText = "需要辅助功能权限"
            alert.informativeText = "请在“系统设置 -> 隐私与安全性 -> 辅助功能”中允许 SmartInputSwitcher 执行，以便监听输入焦点。"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "确定")
            alert.runModal()
        }
    }
    
    @objc func toggleAutoSwitch(_ sender: NSMenuItem) {
        isEnabled.toggle()
        if let menu = statusItem.menu, let item = menu.item(withTag: 100) {
            item.title = isEnabled ? "✓ 自动切换到英文" : "  自动切换到英文"
        }
    }
    
    @objc func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
                sender.title = "  开机自启动"
            } else {
                try service.register()
                sender.title = "✓ 开机自启动"
            }
        } catch {
            print("Failed to toggle Launch at Login: \(error)")
        }
    }
    
    @objc func quit() {
        NSApplication.shared.terminate(nil)
    }
}
