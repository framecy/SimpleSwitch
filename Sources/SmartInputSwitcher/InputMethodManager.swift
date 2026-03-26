import Cocoa
import Carbon

enum AppInputStrategy: Int {
    case globalDefault = 0 // 遵循全局默认（强切英文）
    case forceEnglish = 1
    case forceChinese = 2
    case keepCurrent = 3
}

class InputMethodManager {
    static let shared = InputMethodManager()
    
    private var englishInputSources: [TISInputSource] = []
    private var chineseInputSources: [TISInputSource] = []
    
    var onInputMethodChanged: ((String) -> Void)?
    var currentAppBundleIdentifier: String?
    var currentAppName: String?
    
    var onAppChanged: (() -> Void)?
    
    // ── 性能优化：缓存当前输入法 ID，避免反复调用 TISCopyCurrentKeyboardInputSource() ──
    private var cachedInputSourceID: String?
    private var inputChangeWorkItem: DispatchWorkItem?
    
    init() {
        loadInputSources()
        refreshCachedInputSourceID()
        setupObserver()
    }
    
    func loadInputSources() {
        englishInputSources.removeAll()
        chineseInputSources.removeAll()
        
        let filter = [kTISPropertyInputSourceIsSelectCapable as String: true]
        guard let sourceList = TISCreateInputSourceList(filter as CFDictionary, false)?.takeRetainedValue() as? [TISInputSource] else {
            return
        }
        
        for source in sourceList {
            if let idPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID),
               let id = Unmanaged<CFString>.fromOpaque(idPtr).takeUnretainedValue() as String? {
                
                let lowerId = id.lowercased()
                
                // 判断英文
                if lowerId.contains("com.apple.keylayout.abc") || lowerId.contains("com.apple.keylayout.us") || (lowerId.contains("us") && !lowerId.contains("chinese")) {
                    englishInputSources.append(source)
                }
                
                // 判断中文
                if lowerId.contains("chinese") || lowerId.contains("pinyin") || lowerId.contains("sogou") || lowerId.contains("wubi") || lowerId.contains("baidu") || lowerId.contains("shuangpin") {
                    chineseInputSources.append(source)
                }
            }
        }
    }
    
    // ── 刷新缓存的输入法 ID ──
    private func refreshCachedInputSourceID() {
        guard let currentSource = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
            cachedInputSourceID = nil
            return
        }
        if let idPtr = TISGetInputSourceProperty(currentSource, kTISPropertyInputSourceID),
           let id = Unmanaged<CFString>.fromOpaque(idPtr).takeUnretainedValue() as String? {
            cachedInputSourceID = id
        } else {
            cachedInputSourceID = nil
        }
    }
    
    // ── 基于缓存 ID 的快速判断 ──
    private func isCachedInputChinese() -> Bool {
        guard let id = cachedInputSourceID?.lowercased() else { return false }
        return id.contains("chinese") || id.contains("pinyin") || id.contains("sogou") || id.contains("wubi") || id.contains("baidu") || id.contains("shuangpin")
    }
    
    private func isCachedInputEnglish() -> Bool {
        guard let id = cachedInputSourceID?.lowercased() else { return true }
        return id.contains("com.apple.keylayout.abc") || id.contains("com.apple.keylayout.us") || (id.contains("us") && !id.contains("chinese"))
    }
    
    func switchToEnglish() {
        // 基于缓存快速跳过，无需调用 TIS API
        if isCachedInputEnglish() { return }
        
        if englishInputSources.isEmpty { loadInputSources() }
        for source in englishInputSources {
            if TISSelectInputSource(source) == noErr {
                refreshCachedInputSourceID()
                return
            }
        }
    }
    
    func switchToChinese() {
        // 基于缓存快速跳过
        if isCachedInputChinese() { return }
        
        if chineseInputSources.isEmpty { loadInputSources() }
        for source in chineseInputSources {
            if TISSelectInputSource(source) == noErr {
                refreshCachedInputSourceID()
                return
            }
        }
    }
    
    func applyStrategy(for bundleIdentifier: String, appName: String?) {
        self.currentAppBundleIdentifier = bundleIdentifier
        self.currentAppName = appName
        
        let strategyValue = UserDefaults.standard.integer(forKey: "AppStrategy_\(bundleIdentifier)")
        let strategy = AppInputStrategy(rawValue: strategyValue) ?? .globalDefault
        
        switch strategy {
        case .globalDefault, .forceEnglish:
            switchToEnglish()
        case .forceChinese:
            switchToChinese()
        case .keepCurrent:
            break
        }
        
        DispatchQueue.main.async {
            self.onAppChanged?()
        }
    }
    
    func setStrategy(_ strategy: AppInputStrategy, for bundleIdentifier: String) {
        UserDefaults.standard.set(strategy.rawValue, forKey: "AppStrategy_\(bundleIdentifier)")
        // 立刻应用新策略
        applyStrategy(for: bundleIdentifier, appName: currentAppName)
    }
    
    func getStrategy(for bundleIdentifier: String) -> AppInputStrategy {
        let strategyValue = UserDefaults.standard.integer(forKey: "AppStrategy_\(bundleIdentifier)")
        return AppInputStrategy(rawValue: strategyValue) ?? .globalDefault
    }
    
    // 获取当前输入法的简写名称（简 / EN）
    func getCurrentInputMethodName() -> String {
        // 优先使用缓存判断，无需调用 TIS API
        if let id = cachedInputSourceID?.lowercased() {
            if id.contains("chinese") || id.contains("pinyin") || id.contains("sogou") || id.contains("wubi") || id.contains("baidu") || id.contains("shuangpin") {
                return "简"
            }
            return "EN"
        }
        
        // 降级：缓存为空时才走完整路径
        guard let currentSource = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
            return "EN"
        }
        
        var isChinese = false
        
        if let idPtr = TISGetInputSourceProperty(currentSource, kTISPropertyInputSourceID),
           let id = Unmanaged<CFString>.fromOpaque(idPtr).takeUnretainedValue() as String? {
            cachedInputSourceID = id // 顺便刷新缓存
            let lowerId = id.lowercased()
            if lowerId.contains("chinese") || lowerId.contains("pinyin") || lowerId.contains("sogou") || lowerId.contains("wubi") || lowerId.contains("baidu") || lowerId.contains("shuangpin") {
                isChinese = true
            }
        }
        
        if !isChinese,
           let namePtr = TISGetInputSourceProperty(currentSource, kTISPropertyLocalizedName),
           let name = Unmanaged<CFString>.fromOpaque(namePtr).takeUnretainedValue() as String? {
            if name.contains("拼音") || name.contains("五笔") || name.contains("搜狗") || name.contains("百度") || name.contains("双拼") || name.contains("简体") || name.contains("中文") {
                isChinese = true
            }
        }
        
        return isChinese ? "简" : "EN"
    }
    
    // 监听输入法切换事件
    private func setupObserver() {
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleInputMethodChange),
            name: NSNotification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
            object: nil
        )
    }
    
    @objc private func handleInputMethodChange() {
        // ── 性能优化：debounce 快速连续的输入法变更通知 ──
        inputChangeWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.refreshCachedInputSourceID()
            let name = self.getCurrentInputMethodName()
            self.onInputMethodChanged?(name)
        }
        inputChangeWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: work)
    }
}
