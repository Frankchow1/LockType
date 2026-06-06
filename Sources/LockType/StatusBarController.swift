import AppKit
import ServiceManagement

final class StatusBarController: NSObject, NSMenuDelegate {

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let engine = LockEngine()

    override init() {
        super.init()
        engine.onStateChange = { [weak self] in self?.refreshIcon() }
        engine.start()

        configureButton()
        let menu = NSMenu()
        menu.delegate = self          // 打开时再懒加载输入法列表
        statusItem.menu = menu
        refreshIcon()
        // 启动时如果已启用且有目标，立刻强制一次
        engine.enforceNow()
    }

    // MARK: - 图标

    private func configureButton() {
        guard let btn = statusItem.button else { return }
        btn.imagePosition = .imageOnly
    }

    private func refreshIcon() {
        guard let btn = statusItem.button else { return }
        let symbol = (engine.enabled && engine.targetID != nil) ? "lock.fill" : "lock.open"
        let cfg = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        btn.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "LockType")?
            .withSymbolConfiguration(cfg)
    }

    // MARK: - 菜单（打开时构建，关闭时清空，省内存）

    func menuWillOpen(_ menu: NSMenu) {
        menu.removeAllItems()
        buildMenu(into: menu)
    }

    func menuDidClose(_ menu: NSMenu) {
        // 延迟清理避免和点击冲突
        DispatchQueue.main.async { menu.removeAllItems() }
    }

    private func buildMenu(into menu: NSMenu) {
        // 状态行
        let statusText: String
        if let id = engine.targetID,
           let name = InputSourceManager.listSelectable().first(where: { $0.id == id })?.name {
            statusText = engine.enabled ? "🔒 已锁定: \(name)" : "🔓 未启用: \(name)"
        } else {
            statusText = "未选择输入法"
        }
        let statusItem = NSMenuItem(title: statusText, action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)

        menu.addItem(.separator())

        // 输入法子菜单
        let pickItem = NSMenuItem(title: "选择输入法", action: nil, keyEquivalent: "")
        let pickMenu = NSMenu()
        let sources = InputSourceManager.listSelectable()
        let currentTarget = engine.targetID
        for src in sources {
            let item = NSMenuItem(title: src.name,
                                  action: #selector(pickSource(_:)),
                                  keyEquivalent: "")
            item.target = self
            item.representedObject = src.id
            if src.id == currentTarget { item.state = .on }
            pickMenu.addItem(item)
        }
        pickItem.submenu = pickMenu
        menu.addItem(pickItem)

        menu.addItem(.separator())

        // 启用锁定开关
        let toggle = NSMenuItem(title: "启用锁定",
                                action: #selector(toggleLock),
                                keyEquivalent: "l")
        toggle.target = self
        toggle.state = engine.enabled ? .on : .off
        toggle.isEnabled = engine.targetID != nil
        menu.addItem(toggle)

        // 开机自启
        let autoStart = NSMenuItem(title: "开机自启",
                                   action: #selector(toggleAutoStart),
                                   keyEquivalent: "")
        autoStart.target = self
        autoStart.state = LoginItem.isEnabled ? .on : .off
        menu.addItem(autoStart)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "退出 LockType",
                              action: #selector(quitApp),
                              keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    // MARK: - 动作

    @objc private func pickSource(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        engine.targetID = id
        engine.enabled = true   // 选了就启用
        engine.enforceNow()
        refreshIcon()
    }

    @objc private func toggleLock() {
        engine.enabled.toggle()
        refreshIcon()
    }

    @objc private func toggleAutoStart() {
        LoginItem.isEnabled.toggle()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}

/// 用 SMAppService 管理“开机自启”（macOS 13+）
enum LoginItem {
    static var isEnabled: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                NSLog("LoginItem toggle failed: \(error)")
            }
        }
    }
}
