import AppKit
import Carbon

/// 锁定引擎：监听输入法切换 & app 切换，强制切回目标输入法。
///
/// 稳定性策略采用「事件为主、巡检兜底」双保险：
/// - 事件路径（分布式通知 / app 激活 / 唤醒 / 解锁 / 切 Space）秒级响应；
/// - 巡检定时器周期性复查，兜住事件被系统合并或丢弃的最坏情况。
final class LockEngine {

    /// 目标输入法 ID。为 nil 表示未设置目标，自然也不会锁。
    var targetID: String? {
        didSet { Settings.targetID = targetID }
    }

    /// 锁定是否启用
    var enabled: Bool = false {
        didSet {
            Settings.enabled = enabled
            if enabled {
                startSweepTimer()
                enforceNow()
            } else {
                stopSweepTimer()
            }
        }
    }

    /// 状态变化回调（用于刷新菜单 UI）
    var onStateChange: (() -> Void)?

    /// 当自己主动切换输入法时，临时屏蔽监听，避免抖动
    private var suppressUntil: Date = .distantPast

    /// 兜底巡检定时器：事件路径漏掉时由它纠正
    private var sweepTimer: Timer?

    /// 巡检周期（秒）。配合 tolerance，几乎不耗电。
    private let sweepInterval: TimeInterval = 1.5

    /// 自身切换后的屏蔽窗口（秒）。需 ≥ 分布式通知往返延迟，否则回弹通知会漏进来。
    private let suppressWindow: TimeInterval = 0.5

    init() {
        self.targetID = Settings.targetID
        self.enabled = Settings.enabled
    }

    func start() {
        let dnc = DistributedNotificationCenter.default()

        // 1) 输入法变化（系统级分布式通知）
        dnc.addObserver(
            self,
            selector: #selector(inputSourceChanged),
            name: NSNotification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
            object: nil
        )
        // 1b) 屏幕解锁后，系统常把输入法重置，且此刻通知最不可靠
        dnc.addObserver(
            self,
            selector: #selector(reassert),
            name: NSNotification.Name("com.apple.screenIsUnlocked"),
            object: nil
        )

        let wsnc = NSWorkspace.shared.notificationCenter

        // 2) 切 app —— macOS 会按 app 恢复输入法，要再强制一次
        wsnc.addObserver(
            self,
            selector: #selector(appActivated),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        // 3) 睡眠唤醒后重新强制
        wsnc.addObserver(
            self,
            selector: #selector(reassert),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
        // 4) 切 Space / 快速用户切换回到本会话
        wsnc.addObserver(
            self,
            selector: #selector(reassert),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil
        )
        wsnc.addObserver(
            self,
            selector: #selector(reassert),
            name: NSWorkspace.sessionDidBecomeActiveNotification,
            object: nil
        )

        if enabled { startSweepTimer() }
    }

    // MARK: - 兜底巡检

    private func startSweepTimer() {
        guard sweepTimer == nil else { return }
        // 用 Timer + RunLoop.common，保证菜单弹出等 UI 跟踪期间也照常触发
        let timer = Timer(timeInterval: sweepInterval, repeats: true) { [weak self] _ in
            self?.enforceNow()
        }
        timer.tolerance = sweepInterval * 0.3   // 允许系统合并唤醒，降低功耗
        RunLoop.main.add(timer, forMode: .common)
        sweepTimer = timer
    }

    private func stopSweepTimer() {
        sweepTimer?.invalidate()
        sweepTimer = nil
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

        suppressUntil = Date().addingTimeInterval(suppressWindow)
        InputSourceManager.select(id: target)
        onStateChange?()

        // 切换不一定「立刻生效」（尤其 app 刚激活时），回读确认，没成功就补一刀
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self, self.enabled, let target = self.targetID else { return }
            if InputSourceManager.currentID() != target {
                self.suppressUntil = Date().addingTimeInterval(self.suppressWindow)
                InputSourceManager.select(id: target)
            }
        }
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
        // 立即强制一次；新 app 有时会在激活后几十毫秒再设回自己的输入法，故再补一次
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.enforceNow()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.enforceNow()
        }
    }

    /// 唤醒 / 解锁 / 切 Space —— 这些时刻系统易重置输入法，稍延后再强制
    @objc private func reassert() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
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
