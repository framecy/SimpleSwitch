# SimpleSwitch

SimpleSwitch 是一款轻量级、极致丝滑的 macOS 智能输入法切换工具。它常驻在菜单栏，根据当前前台应用自动切换输入法，让您的键盘永远处于最合适的状态。

## ✨ 功能特性

- **按应用自动切换**：切换到新应用时，自动将输入法切回英文（默认行为），避免快捷键冲突和误触
- **灵活的应用策略**：支持为每个应用单独配置输入法策略：
  - 🔤 **默认 / 强制英文**：切换到该应用时自动切回英文
  - 🀄 **强制中文**：切换到该应用时自动切回中文（适合微信、备忘录等）
  - ⏸️ **保持原状态**：不做任何切换
- **桌面 HUD 提示**：输入法切换时在屏幕右上角显示简洁的半透明提示（简 / EN）
- **极致性能**：
  - TIS 输入法状态缓存，避免重复系统调用
  - 快速 Cmd+Tab 事件合并，不产生卡顿
  - 菜单懒构建，仅在点击时渲染
- **状态栏管理**：常驻菜单栏，显示当前输入法状态，一键开关
- **开机自启动**：一键设置随 macOS 登录自动启动

## 🛠️ 环境要求

| 项目 | 要求 |
|---|---|
| **操作系统** | macOS 13.0+ |
| **硬件** | Apple Silicon (M1/M2/M3/M4) & Intel |
| **权限** | 无需辅助功能权限 |

## 🚀 安装

### 方式一：DMG 安装（推荐）

下载 `SmartInputSwitcher.dmg`，打开后拖入 Applications 文件夹即可。

### 方式二：源码编译

```bash
# 克隆仓库
git clone https://github.com/your-username/SimpleSwitch.git
cd SimpleSwitch

# 编译 Release 版本
xcodebuild -project SmartInputSwitcher.xcodeproj \
  -scheme SmartInputSwitcher \
  -configuration Release build

# 安装到 Applications
killall SmartInputSwitcher 2>/dev/null || true
cp -R "$(xcodebuild -project SmartInputSwitcher.xcodeproj \
  -scheme SmartInputSwitcher -configuration Release \
  -showBuildSettings 2>/dev/null | grep -m1 'BUILT_PRODUCTS_DIR' | \
  awk '{print $NF}')/SmartInputSwitcher.app" /Applications/

# 启动
open /Applications/SmartInputSwitcher.app
```

> 💡 也可以直接打开 `SmartInputSwitcher.xcodeproj` 在 Xcode 中点击 Run。

## 📖 使用说明

1. 启动后应用出现在菜单栏右上角，显示当前输入法状态（简 / EN）
2. 点击菜单栏图标可以看到当前前台应用名称
3. 为当前应用选择合适的输入法策略
4. 可随时开关"自动切换"总开关

## 👨‍💻 技术架构

```
main.swift              → 应用入口
AppDelegate.swift       → 菜单栏 UI & NSMenuDelegate 懒构建
AppObserver.swift       → NSWorkspace 应用激活监听 (事件去重 + 合并)
InputMethodManager.swift → TIS 输入法操控 (状态缓存 + debounce)
HUDWindowController.swift → 半透明 HUD 弹窗 (动画合并)
```

核心技术栈：
- **Text Input Source Services (TIS)**：底层键盘输入源操控，带 ID 缓存优化
- **NSWorkspace Notification**：轻量级应用切换监听，无需辅助功能权限
- **GCD DispatchWorkItem**：事件防抖与合并，确保快速切换不卡顿
- **ServiceManagement**：系统级 Launch at Login

## 📄 许可证

本项目开源，您可以自由修改、编译及分发。
