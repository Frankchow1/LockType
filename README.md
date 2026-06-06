# LockType

一个极简的 macOS 菜单栏小工具，**强制锁定指定输入法**，防止系统在切换 App 时自动恢复成你不想要的输入法。

<p align="center">
  <img src="Resources/AppIcon.svg" width="120" alt="LockType icon"/>
</p>

## ✨ 特性

- 🔒 **强制锁定**：选定输入法后，任何切换行为（快捷键、菜单、切 App）都会立刻被切回
- 🪶 **极轻量**：二进制 ~116 KB，运行内存通常 < 20 MB（对比同类产品 ~50 MB）
- 📋 **状态栏常驻**：纯菜单栏 App，无 Dock 图标、无主窗口
- ⚙️ **零依赖**：纯 Swift + AppKit + Carbon TIS API，不引入任何第三方库
- 🚀 **支持开机自启**：基于 `SMAppService` (macOS 13+)
- 🎯 **行为正确**：监听系统输入法变化通知 + App 激活通知，去抖处理避免抖动
- 🛡️ **双保险防漏纠正**：事件驱动为主 + 定时巡检兜底，并额外监听唤醒 / 解锁 / 切 Space，分布式通知被系统丢弃时也能拉回

## 📦 安装

### 方式 A：下载已构建的 .dmg（推荐）

1. 去 [Releases](../../releases) 页面下载最新的 `LockType.dmg`
2. 双击挂载，把 `LockType.app` 拖到 `/Applications`
3. **首次运行**：右键 `LockType.app` → **打开** → **仍要打开**（因为没花 $99 买 Apple 开发者证书）
4. 看到菜单栏出现锁图标 = 安装成功

### 方式 B：自己构建

```bash
git clone https://github.com/<your-username>/LockType.git
cd LockType
./build.sh
open build/LockType.dmg
```

## 🎮 使用

1. 点击菜单栏的 🔓 图标
2. **选择输入法** → 选你想锁定的那个（如"简体拼音"）
3. 选完即自动启用锁定，图标变成 🔒
4. 之后无论你按什么快捷键、切到什么 App，输入法都会被强制保持
5. 想解锁：再次点击图标，取消"启用锁定"

### 菜单结构

```
🔒  ← 菜单栏图标
 ├─ 🔒 已锁定: 简体拼音       (状态显示)
 ├─ ─────────────
 ├─ 选择输入法 ▸             (列出所有可用输入法)
 ├─ ─────────────
 ├─ ☑ 启用锁定    (⌘L)
 ├─ ☐ 开机自启
 ├─ ─────────────
 └─ 退出 LockType   (⌘Q)
```

## 🛠 构建要求

- macOS 14.0+（Sonoma 起）
- Xcode Command Line Tools（**不需要完整 Xcode**）：
  ```bash
  xcode-select --install
  ```

### 已知问题：CLT 的 SwiftBridging 模块重复

如果 `./build.sh` 报 `redefinition of module 'SwiftBridging'`，是 CLT 自身 modulemap 重复定义的 bug。临时解决：

```bash
sudo mv /Library/Developer/CommandLineTools/usr/include/swift/module.modulemap \
        /Library/Developer/CommandLineTools/usr/include/swift/module.modulemap.bak
```

下次 CLT 升级可能要再做一次。或者装完整 Xcode 也行。

## 🗂 项目结构

```
LockType/
├── Sources/LockType/
│   ├── main.swift               # 入口
│   ├── AppDelegate.swift        # NSApplicationDelegate
│   ├── InputSourceManager.swift # TIS API 封装
│   ├── LockEngine.swift         # 锁定引擎 + 通知监听
│   └── StatusBarController.swift# 状态栏菜单 UI
├── Resources/
│   ├── Info.plist               # LSUIElement=true（无 Dock 图标）
│   └── AppIcon.svg              # 应用图标源文件
├── scripts/
│   └── svg2png.swift            # SVG → 透明 PNG（用于生成 .icns）
├── Package.swift                # SPM manifest（实际用 swiftc 直接编译）
└── build.sh                     # 编译 + 打包 .app + .dmg
```

## 🧪 技术细节

- **输入法 API**：用 Carbon 的 `TextInputSources`（`TISCopyCurrentKeyboardInputSource` / `TISSelectInputSource`）
- **监听机制（事件为主、巡检兜底）**：
  - `kTISNotifySelectedKeyboardInputSourceChanged` 分布式通知 —— 任何 App 切换输入法都能感知
  - `NSWorkspace.didActivateApplicationNotification` —— macOS 切 App 时会按 App 恢复输入法，激活后立即强制 + 350 ms 再补一次（防 App 延迟设回自己的输入法）
  - `didWake` / `com.apple.screenIsUnlocked` / `activeSpaceDidChange` / `sessionDidBecomeActive` —— 唤醒、解锁、切 Space、用户切换后系统易重置输入法，且此刻通知最不可靠，统一再强制一次
  - **巡检定时器**：每 1.5 s（带 tolerance，几乎不耗电）无条件复查一次，兜住分布式通知被系统合并 / 丢弃的最坏情况
- **去抖 + 回读重试**：自己 `select()` 时设 `suppressUntil`（500 ms）屏蔽回弹通知避免循环；切换后 150 ms 回读确认，没生效再补一刀
- **目标失效保护**：被锁定的输入法若被用户在系统设置里删除，自动解除锁定而非空转
- **持久化**：`UserDefaults`（`LockType.targetID` / `LockType.enabled`）
- **图标圆角**：用 WebKit 离屏渲染 SVG → 透明 PNG（`qlmanage` 不支持透明背景）

## ❓ FAQ

**Q：为什么打开时显示"已损坏"或"无法验证开发者"？**
A：因为没花钱买 Apple 开发者证书。右键 → 打开 → 仍要打开即可，只需要一次。或者：
```bash
xattr -dr com.apple.quarantine /Applications/LockType.app
```

**Q：图标在菜单栏长什么样？**
A：菜单栏图标用的是系统 SF Symbol（`lock.fill` / `lock.open`），单色，自适应 macOS 浅色/深色模式。.icns 里的彩色图标在 Finder/Dock/启动台可见。

**Q：会上传我的输入数据吗？**
A：不会。只读取"当前输入法 ID"和"切换输入法"，没有任何网络代码。源码很短，自己看就知道。

**Q：能锁定到具体某个 App 用特定输入法吗？**
A：不能。这是有意设计 —— 本工具就是为了"全局只用一个输入法"这个简单需求。

## 📄 License

MIT —— 见 [LICENSE](LICENSE)
