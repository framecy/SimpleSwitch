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
    
    init() {
        loadInputSources()
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
    
    func switchToEnglish() {
        if englishInputSources.isEmpty { loadInputSources() }
        for source in englishInputSources {
            if TISSelectInputSource(source) == noErr { return }
        }
    }
    
    func switchToChinese() {
        if chineseInputSources.isEmpty { loadInputSources() }
        for source in chineseInputSources {
            if TISSelectInputSource(source) == noErr { return }
        }
    }
    
    func applyStrategy(for bundleIdentifier: String, appName: String?) {
        self.currentAppBundleIdentifier = bundleIdentifier
        self.currentAppName = appName
        
        let strategyValue = UserDefaults.standard.integer(forKey: "AppStrategy_\(bundleIdentifier)")
        let strategy = AppInputStrategy(rawValue: strategyValue) ?? .globalDefault
        
        // 只有开启了总开关才执行策略跳转（在 AppDelegate 中判断总开关，但为了安全这里也可以先直接跳转。为了解耦，交由 AppDelegate 决定是否调用 applyStrategy 会更好，但目前为了封装，外部只需调用即可）
        
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
        guard let currentSource = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
            return "EN"
        }
        
        var isChinese = false
        
        if let idPtr = TISGetInputSourceProperty(currentSource, kTISPropertyInputSourceID),
           let id = Unmanaged<CFString>.fromOpaque(idPtr).takeUnretainedValue() as String? {
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
        // 延迟 0.1 秒再查询并刷新 UI，让出系统底层的渲染和初始化时间，避免死锁卡顿。
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            let name = self.getCurrentInputMethodName()
            self.onInputMethodChanged?(name)
        }
    }
}
