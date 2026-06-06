# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-06-06

### Added
- 🛡️ **兜底巡检定时器**：每 1.5 s（带 tolerance，几乎不耗电）无条件复查一次，兜住分布式通知被系统合并 / 丢弃导致「漏纠正」的最坏情况
- 😴 **唤醒 / 解锁 / 切 Space 监听**：新增 `didWake`、`com.apple.screenIsUnlocked`、`activeSpaceDidChange`、`sessionDidBecomeActive`，这些时刻系统易重置输入法且通知最不可靠，统一再强制一次
- 🔁 **回读重试**：`select()` 后 150 ms 回读确认，未生效再补一刀（解决 app 刚激活时 `TISSelectInputSource` 偶发不生效）
- 🖥️ **通用二进制**：构建产物改为 `arm64 + x86_64`，Intel Mac 也能运行

### Changed
- 切 App 时由「激活后强制一次」改为「立即 + 350 ms 再补一次」，防止 app 延迟设回自己的输入法
- 自身切换的屏蔽窗口 300 ms → 500 ms，覆盖分布式通知往返延迟，进一步避免回弹
- 巡检定时器仅在启用锁定时运行，关闭即销毁，不空转

## [1.0.0] - 2026-06-06

### Added
- 🎉 首次发布
- 状态栏菜单：选择输入法、启用/解除锁定、开机自启、退出
- 强制锁定指定输入法，监听系统输入法变化通知 (`kTISNotifySelectedKeyboardInputSourceChanged`)
- 切换 App 时自动重新强制锁定（防止 macOS 按 App 恢复输入法）
- 去抖逻辑（300 ms 屏蔽窗口），避免触发自身通知形成循环
- 开机自启支持（基于 `SMAppService`，macOS 13+）
- 状态持久化（`UserDefaults`）
- 菜单栏图标自适应锁定状态：`lock.fill` / `lock.open`
- 应用图标：自定义 SVG，构建时用 WebKit 渲染成透明 PNG → 多分辨率 `.icns`
- 完整的 macOS .dmg 打包脚本（含 Applications 软链接）
- Ad-hoc 代码签名（自用，无需 Apple 开发者证书）

### Technical
- 纯 Swift + AppKit + Carbon TIS API，无第三方依赖
- 二进制 ~116 KB，运行内存 < 20 MB
- 直接 `swiftc` 编译，绕开 SPM 在 CLT 下的 `PackageDescription` 链接问题
- 最低系统 macOS 14.0
