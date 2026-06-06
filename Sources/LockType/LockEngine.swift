import AppKit
import Carbon

/// 锁定引擎：监听输入法切换 & app 切换，强制切回目标输入法
final class LockEngine {

    /// 目标输入法 ID。为 nil 表示未设置目标，自然也不会锁。
    var targetID: String? {
        didSet { Settings.targetID = targetID }
    }

    /// 锁定是否启用
    var enabled: Bool = false {
        didSet {
            Settings.enabled = enabled
            if enabled { enforceNow() }
        }
    }

    /// 状态变化回调（用于刷新菜单 UI）
    var onStateChange: (() -> Void)?

    /// 当自己主动切换输入法时，临时屏蔽监听，避免抖动
    private var suppressUntil: Date = .distantPast

    init() {
        self.targetID = Settings.targetID
        self.enabled = Settings.enabled
    }

    func start() {
        // 1) 监听输入法变化（分布式通知，整个系统级别）
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(inputSourceChanged),
            name: NSNotification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
            object: nil
        )

        // 2) 监听 app 激活 —— macOS 会按 app 恢复输入法，要再强制一次
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appActivated),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }

    /// 立刻强制切换到目标输入法（如果启用且当前不一致）
    func enforceNow() {
        guard enabled, let target = targetID else { return }
        guard let current = InputSourceManager.currentID(), current != target else { return }

        // 检查目标是否还存在；不存在就自动关闭锁定
        guard InputSourceManager.listSelectable().contains(where: { $0.id == target }) else {
            enabled = false
            onStateChange?()
            return
        }

        suppressUntil = Date().addingTimeInterval(0.3) // 屏蔽 300ms 内回弹的通知
        InputSourceManager.select(id: target)
        onStateChange?()
    }

    // MARK: - Notifications

    @objc private func inputSourceChanged() {
        // 由自己触发的切换，跳过
        if Date() < suppressUntil { return }
        // 切到主线程稍后处理，避开系统正在写状态的瞬间
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.enforceNow()
        }
    }

    @objc private func appActivated() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.enforceNow()
        }
    }
}

/// 简易设置存储（UserDefaults）
enum Settings {
    private static let kTargetID = "LockType.targetID"
    private static let kEnabled = "LockType.enabled"

    static var targetID: String? {
        get { UserDefaults.standard.string(forKey: kTargetID) }
        set { UserDefaults.standard.set(newValue, forKey: kTargetID) }
    }

    static var enabled: Bool {
        get { UserDefaults.standard.bool(forKey: kEnabled) }
        set { UserDefaults.standard.set(newValue, forKey: kEnabled) }
    }
}
