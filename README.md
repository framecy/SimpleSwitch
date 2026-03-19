# SimpleSwitch

SimpleSwitch 是一款轻量级、极致丝滑的 macOS 智能输入法切换工具。它能够根据您当前的输入焦点，自动感知并切换输入法状态，让您的键盘永远处于最适合的工作状态。

## ✨ 功能特性

- **智能焦点感应**：当鼠标点击非文本输入区域时，自动将输入法切换为英文，避免在使用如 VSCode (Vim 模式)、Figma 等工具或系统快捷键时发生按键冲突和误触。
- **极致无感切换**：采用底层 AX (Accessibility) 接口进行事件节流防抖，并且在输入法切换期间实施底层的毫秒级强制呼吸期，100% 避免了 macOS 系统下常见的“输入法切换严重掉帧”和“大写锁定连按粘连”等跨进程死锁问题。
- **极简桌面 HUD**：每次输入法状态发生变化时，在当前鼠标激活的屏幕右上角以干净利落的深色半透明 HUD 给予提示（简/EN），不抢夺系统焦点、绝不阻塞 WindowServer 渲染。
- **状态栏管理**：常驻于系统顶部菜单栏（Menu Bar），支持一键开启/关闭自动切换功能，同时显示当前输入法状态。
- **开机自启动**：一键设置随 macOS 登录自动启动，无需额外配置守护进程。

## 🛠️ 环境与支持要求

- **操作系统**：macOS 13.0 或以上版本
- **硬件支持**：完美支持搭载 Apple Silicon (M1/M2/M3/M4) 芯片的 Mac 设备，兼容 Intel 架构。
- **权限要求**：**必须**在“系统设置 -> 隐私与安全性 -> 辅助功能”中允许本应用控制您的电脑，才能正常实现输入框焦点监听。

## 🚀 安装与部署

如果您想自行编译该项目，请在终端 (Terminal) 中执行以下步骤：

1. **获取源码并进入目录**：
   ```bash
   git clone https://github.com/您的用户名/SimpleSwitch.git
   cd SimpleSwitch
   ```

2. **安装工程生成工具** (需提前安装 Homebrew)：
   ```bash
   brew install xcodegen
   ```

3. **生成 Xcode 项目结构**：
   ```bash
   xcodegen generate
   ```

4. **一键编译、安装并运行**：
   执行以下命令，程序会自动编译、将其移动至 `应用程序` 文件夹，并立刻启动：
   ```bash
   # 编译到零时目录，防止 iCloud 扩展属性导致构建失败
   xcodebuild -scheme SmartInputSwitcher CONFIGURATION_BUILD_DIR="/tmp/SimpleSwitchBuild" build
   
   # 杀掉旧进程并覆盖安装新版本
   killall SmartInputSwitcher || true
   rm -rf /Applications/SmartInputSwitcher.app
   cp -R /tmp/SimpleSwitchBuild/SmartInputSwitcher.app /Applications/
   
   # 打开应用
   open /Applications/SmartInputSwitcher.app
   ```
   > 💡 **提示**：如果您习惯使用图形界面，在第 3 步后直接双击打开 `SmartInputSwitcher.xcodeproj`，然后在 Xcode 中点击顶部的 `Run` (运行) 按钮即可。

## 📖 使用说明

1. 启动 `SimpleSwitch` 后，它会出现在系统右上角的状态栏。
2. 第一次运行会弹窗提示请求“辅助功能”权限，授权后方可生效。
3. 授权后重启应用。
4. 点击状态栏图标，可以随时勾选开启或关闭“自动切换到英文”功能。
5. 畅快体验无论鼠标点到哪里，打字、快捷键如丝般顺滑的操作手感！

## 👨‍💻 技术实现细节

本项目使用了以下核心技术与框架：
- **Accessibility API (`AXObserver`)**：用于全系统级别细粒度地监控用户交互焦点的偏移。
- **Text Input Source Services (`TIS`)**：无缝且静默地操作系统底层的键盘输入源。
- **Grand Central Dispatch (`GCD`) 深度调优**：将昂贵的 IPC (跨进程通信) 查询解绑至后台队列，并引入强制的 1.0秒 IPC 查询休眠期，完美规避原生中文输入引擎 (SCIM) 启动时的锁竞争卡顿！
- **ServiceManagement**：实现系统级的 Launch at Login，安全可靠。

## 📄 许可证

本项目开源，您可以自由修改、编译及分发。
