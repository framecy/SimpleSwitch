import Cocoa
import ApplicationServices

class FocusObserver {
    static let shared = FocusObserver()
    
    private var axObserver: AXObserver?
    private var activeAppPid: pid_t?
    
    var onFocusLost: (() -> Void)?
    
    func start() {
        let workspace = NSWorkspace.shared
        
        // 监听应用激活
        workspace.notificationCenter.addObserver(self, selector: #selector(appDidActivate(_:)), name: NSWorkspace.didActivateApplicationNotification, object: nil)
        
        // 监听应用失去激活
        workspace.notificationCenter.addObserver(self, selector: #selector(appDidDeactivate(_:)), name: NSWorkspace.didDeactivateApplicationNotification, object: nil)
        
        // 初始化监听当前激活的 app
        if let activeApp = workspace.frontmostApplication {
            observeApp(pid: activeApp.processIdentifier)
        }
    }
    
    @objc private func appDidActivate(_ notification: Notification) {
        if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
            observeApp(pid: app.processIdentifier)
        }
    }
    
    @objc private func appDidDeactivate(_ notification: Notification) {
        stopObserving()
        // 当一个应用失去焦点时（被其他应用覆盖/切换），安排切回英文
        scheduleFocusLost()
    }
    
    private func observeApp(pid: pid_t) {
        stopObserving()
        
        activeAppPid = pid
        let appElement = AXUIElementCreateApplication(pid)
        
        var newObserver: AXObserver?
        let observerError = AXObserverCreate(pid, observerCallback, &newObserver)
        guard observerError == .success, let axObserver = newObserver else {
            return
        }
        
        self.axObserver = axObserver
        
        // 监听 UI 元素焦点变化
        AXObserverAddNotification(axObserver, appElement, kAXFocusedUIElementChangedNotification as CFString, Unmanaged.passUnretained(self).toOpaque())
        // 监听窗口焦点变化
        AXObserverAddNotification(axObserver, appElement, kAXFocusedWindowChangedNotification as CFString, Unmanaged.passUnretained(self).toOpaque())
        
        CFRunLoopAddSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(axObserver), .defaultMode)
        
        // 初始检查
        checkCurrentFocus(appElement: appElement)
    }
    
    private func stopObserving() {
        if let axObserver = axObserver {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(axObserver), .defaultMode)
            self.axObserver = nil
        }
        activeAppPid = nil
    }
    
    var isPaused = false
    private var axDebounceWorkItem: DispatchWorkItem?
    
    func pauseObserving(for duration: TimeInterval) {
        isPaused = true
        cancelFocusLost() // 最关键的一步：如果在收到通知前 0.1s 焦点已经流失引发了排队强制切回英文的任务，必须在这里强杀掉它！
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            self?.isPaused = false
        }
    }
    
    func handleFocusChange(element: AXUIElement, notification: CFString) {
        if isPaused { return }
        
        // 极高频事件防抖：只查询最后一次的焦点元素，避免高频打字时 IPC 阻塞
        axDebounceWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.checkCurrentFocus(element: element)
        }
        axDebounceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: workItem)
    }
    
    private var focusLostWorkItem: DispatchWorkItem?
    
    private func scheduleFocusLost() {
        DispatchQueue.main.async {
            self.focusLostWorkItem?.cancel()
            
            let workItem = DispatchWorkItem { [weak self] in
                self?.onFocusLost?()
            }
            self.focusLostWorkItem = workItem
            // 延迟 0.3 秒触发，防止系统级 HUD 短暂抢夺焦点导致误切
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
        }
    }
    
    private func cancelFocusLost() {
        DispatchQueue.main.async {
            self.focusLostWorkItem?.cancel()
            self.focusLostWorkItem = nil
        }
    }
    
    private func checkCurrentFocus(appElement: AXUIElement) {
        if isPaused { return }
        
        var focusedElementWrapper: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedElementWrapper)
        
        if error == .success, let focusedElement = focusedElementWrapper {
            checkCurrentFocus(element: focusedElement as! AXUIElement)
        } else {
            scheduleFocusLost()
        }
    }
    
    private func checkCurrentFocus(element: AXUIElement) {
        if isPaused { return }
        
        var roleWrapper: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleWrapper)
        
        if error == .success, let role = roleWrapper as? String {
            // 可接收输入的控件常见 Role
            let textRoles = ["AXTextField", "AXTextArea", "AXComboBox", "AXSearchField"]
            
            if textRoles.contains(role) {
                // 当前在输入框中，取消潜在的失去焦点操作
                cancelFocusLost()
            } else {
                // 焦点不在输入框里，安排切回英文
                scheduleFocusLost()
            }
        } else {
            scheduleFocusLost()
        }
    }
}

func observerCallback(observer: AXObserver, element: AXUIElement, notification: CFString, refcon: UnsafeMutableRawPointer?) {
    guard let refcon = refcon else { return }
    let focusObserver = Unmanaged<FocusObserver>.fromOpaque(refcon).takeUnretainedValue()
    focusObserver.handleFocusChange(element: element, notification: notification)
}
