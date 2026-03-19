import Cocoa
import ServiceManagement

import Cocoa
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var isEnabled = true
    var hudController: HUDWindowController?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "keyboard.badge.waveform", accessibilityDescription: "Smart Input Switcher")
            updateStatusBarButtonTitle()
        }
        
        hudController = HUDWindowController()
        
        // 监听输入法状态变更（更新状态栏文字与弹窗）
        InputMethodManager.shared.onInputMethodChanged = { [weak self] name in
            self?.updateStatusBarButtonTitle()
            self?.hudController?.showHUD(with: name)
        }
        
        // 当活动应用变更，或者策略变更时，刷新系统菜单
        InputMethodManager.shared.onAppChanged = { [weak self] in
            self?.setupMenu()
        }
        
        // 绑定系统激活事件
        AppObserver.shared.onAppActivated = { [weak self] bundleId, appName in
            guard let self = self else { return }
            
            if self.isEnabled {
                InputMethodManager.shared.applyStrategy(for: bundleId, appName: appName)
            } else {
                // 就算未开启总开关，也要更新状态存储，以便菜单能够渲染当前 App
                InputMethodManager.shared.currentAppBundleIdentifier = bundleId
                InputMethodManager.shared.currentAppName = appName
                self.setupMenu()
            }
        }
        
        AppObserver.shared.start()
        setupMenu()
    }
    
    func updateStatusBarButtonTitle() {
        if let button = statusItem.button {
            let name = InputMethodManager.shared.getCurrentInputMethodName()
            button.title = " \(name)"
        }
    }
    
    func setupMenu() {
        let menu = NSMenu()
        
        // 动态生成部分
        if let appName = InputMethodManager.shared.currentAppName,
           let bundleId = InputMethodManager.shared.currentAppBundleIdentifier {
            
            let titleItem = NSMenuItem(title: "[+] 当前前台应用: \(appName)", action: nil, keyEquivalent: "")
            titleItem.isEnabled = false
            menu.addItem(titleItem)
            
            let strategy = InputMethodManager.shared.getStrategy(for: bundleId)
            
            let s0 = NSMenuItem(title: "    默认 (切回英文)", action: #selector(setStrategy(_:)), keyEquivalent: "")
            s0.tag = AppInputStrategy.globalDefault.rawValue
            s0.state = strategy == .globalDefault ? .on : .off
            menu.addItem(s0)
            
            let s1 = NSMenuItem(title: "    强制为英文", action: #selector(setStrategy(_:)), keyEquivalent: "")
            s1.tag = AppInputStrategy.forceEnglish.rawValue
            s1.state = strategy == .forceEnglish ? .on : .off
            menu.addItem(s1)
            
            let s2 = NSMenuItem(title: "    强制为中文", action: #selector(setStrategy(_:)), keyEquivalent: "")
            s2.tag = AppInputStrategy.forceChinese.rawValue
            s2.state = strategy == .forceChinese ? .on : .off
            menu.addItem(s2)
            
            let s3 = NSMenuItem(title: "    保持原状态", action: #selector(setStrategy(_:)), keyEquivalent: "")
            s3.tag = AppInputStrategy.keepCurrent.rawValue
            s3.state = strategy == .keepCurrent ? .on : .off
            menu.addItem(s3)
            
            menu.addItem(NSMenuItem.separator())
        }
        
        let enableItem = NSMenuItem(title: isEnabled ? "✓ 开启 App 自动切换" : "  开启 App 自动切换", action: #selector(toggleAutoSwitch(_:)), keyEquivalent: "")
        menu.addItem(enableItem)
        
        let loginStatus = SMAppService.mainApp.status == .enabled
        let loginItem = NSMenuItem(title: loginStatus ? "✓ 开机自启动" : "  开机自启动", action: #selector(toggleLaunchAtLogin(_:)), keyEquivalent: "")
        menu.addItem(loginItem)
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q"))
        
        statusItem.menu = menu
    }
    
    @objc func setStrategy(_ sender: NSMenuItem) {
        guard let bundleId = InputMethodManager.shared.currentAppBundleIdentifier else { return }
        if let newStrategy = AppInputStrategy(rawValue: sender.tag) {
            InputMethodManager.shared.setStrategy(newStrategy, for: bundleId)
            setupMenu()
        }
    }
    
    @objc func toggleAutoSwitch(_ sender: NSMenuItem) {
        isEnabled.toggle()
        AppObserver.shared.isEnabled = isEnabled
        setupMenu()
    }
    
    @objc func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
            setupMenu()
        } catch {
            print("Failed to toggle Launch at Login: \(error)")
        }
    }
    
    @objc func quit() {
        NSApplication.shared.terminate(nil)
    }
}
