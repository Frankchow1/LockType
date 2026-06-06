import AppKit
import Carbon

/// 一个输入法源的简单数据载体
struct InputSource {
    let id: String          // kTISPropertyInputSourceID, e.g. "com.apple.keylayout.ABC"
    let name: String        // 可读名称
    let tisRef: TISInputSource
}

/// TextInputSources (TIS) API 的简单封装
enum InputSourceManager {

    /// 列出所有“可选”的键盘输入法（过滤掉调色板、墨迹等）
    static func listSelectable() -> [InputSource] {
        // 只要可被选中的键盘类输入源
        let filter: [CFString: Any] = [
            kTISPropertyInputSourceCategory: kTISCategoryKeyboardInputSource as Any,
            kTISPropertyInputSourceIsSelectCapable: true
        ]
        guard let cfList = TISCreateInputSourceList(filter as CFDictionary, false)?
                .takeRetainedValue() as? [TISInputSource] else {
            return []
        }
        return cfList.compactMap { src in
            guard let id = stringProperty(src, kTISPropertyInputSourceID),
                  let name = stringProperty(src, kTISPropertyLocalizedName) else { return nil }
            return InputSource(id: id, name: name, tisRef: src)
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// 当前选中的键盘输入法 ID
    static func currentID() -> String? {
        guard let src = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else { return nil }
        return stringProperty(src, kTISPropertyInputSourceID)
    }

    /// 按 ID 切换到指定输入法。返回是否成功。
    @discardableResult
    static func select(id: String) -> Bool {
        guard let target = listSelectable().first(where: { $0.id == id }) else { return false }
        return TISSelectInputSource(target.tisRef) == noErr
    }

    // MARK: - Helpers

    private static func stringProperty(_ src: TISInputSource, _ key: CFString) -> String? {
        guard let ptr = TISGetInputSourceProperty(src, key) else { return nil }
        return Unmanaged<CFString>.fromOpaque(ptr).takeUnretainedValue() as String
    }
}
