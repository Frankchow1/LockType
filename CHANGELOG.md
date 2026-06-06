# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
