import Cocoa
import Carbon

class InputMethodManager {
    static let shared = InputMethodManager()
    
    private var englishInputSources: [TISInputSource] = []
    var onInputMethodChanged: ((String) -> Void)?
    
    init() {
        loadEnglishInputSources()
        setupObserver()
    }
    
    func loadEnglishInputSources() {
        englishInputSources.removeAll()
        
        let filter = [kTISPropertyInputSourceIsSelectCapable as String: true]
        guard let sourceList = TISCreateInputSourceList(filter as CFDictionary, false)?.takeRetainedValue() as? [TISInputSource] else {
            return
        }
        
        for source in sourceList {
            if let idPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID),
               let id = Unmanaged<CFString>.fromOpaque(idPtr).takeUnretainedValue() as String? {
                
                if id.contains("com.apple.keylayout.ABC") || id.contains("com.apple.keylayout.US") || (id.contains("US") && !id.contains("Chinese")) {
                    englishInputSources.append(source)
                }
            }
        }
    }
    
    func switchToEnglish() {
        if englishInputSources.isEmpty {
            loadEnglishInputSources()
        }
        
        for source in englishInputSources {
            if TISSelectInputSource(source) == noErr {
                return
            }
        }
        
        if let firstEnglish = englishInputSources.first {
            TISSelectInputSource(firstEnglish)
        }
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
        // macOS 原生输入法切换时，立刻暂停焦点监听，并且取消任何已经在队列中的强制切英文任务，防止与大写锁定 HUD 抢夺焦点时引发连点失败。
        DispatchQueue.main.async {
            FocusObserver.shared.pauseObserving(for: 1.0)
        }
        
        // 延迟 0.1 秒再查询并刷新 UI，让出系统底层的渲染和初始化时间，避免死锁卡顿。
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            let name = self.getCurrentInputMethodName()
            self.onInputMethodChanged?(name)
        }
    }
}
