import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBar: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 强制纯菜单栏（防止万一有窗口）
        NSApp.setActivationPolicy(.accessory)
        statusBar = StatusBarController()
    }
}
