import AppKit
import Carbon.HIToolbox

// MARK: - 全局热键管理器
// 从 AppSettings 读取 keyCode / modifiers，支持运行时动态修改。

final class HotKeyManager {

    static let shared = HotKeyManager()

    private var hotKeyRef:    EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    var onTrigger: (() -> Void)?

    private init() {}

    // ── 注册（使用 AppSettings 中当前值）────────────────
    func register() {
        unregister()   // 先注销旧的

        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(0x4D454D4F) // 'MEMO'
        hotKeyID.id = 1

        // 仅在首次注册时安装事件处理器（避免重复 Install）
        if eventHandler == nil {
            var eventType = EventTypeSpec()
            eventType.eventClass = OSType(kEventClassKeyboard)
            eventType.eventKind  = OSType(kEventHotKeyPressed)

            InstallEventHandler(
                GetApplicationEventTarget(),
                { (_, event, userData) -> OSStatus in
                    guard let userData = userData else { return OSStatus(eventNotHandledErr) }
                    let mgr = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                    var hkID = EventHotKeyID()
                    GetEventParameter(event,
                                      EventParamName(kEventParamDirectObject),
                                      EventParamType(typeEventHotKeyID),
                                      nil,
                                      MemoryLayout<EventHotKeyID>.size,
                                      nil,
                                      &hkID)
                    if hkID.id == 1 {
                        DispatchQueue.main.async { mgr.onTrigger?() }
                    }
                    return noErr
                },
                1,
                &eventType,
                Unmanaged.passUnretained(self).toOpaque(),
                &eventHandler
            )
        }

        // 从 AppSettings 读取当前配置
        let keyCode  = UInt32(AppSettings.shared.hotKeyCode)
        let mods     = UInt32(AppSettings.shared.hotKeyModifiers)

        RegisterEventHotKey(keyCode, mods, hotKeyID,
                            GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    // ── 注销热键（保留事件处理器）───────────────────────
    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
    }

    // ── 完全清除（退出时调用）────────────────────────────
    func teardown() {
        unregister()
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
    }

    deinit { teardown() }
}

// MARK: - Carbon 修饰键 ↔ NSEvent.ModifierFlags 互转

extension HotKeyManager {

    /// NSEvent.ModifierFlags → Carbon modifiers (UInt32)
    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> Int {
        var c: Int = 0
        if flags.contains(.control) { c |= controlKey }
        if flags.contains(.option)  { c |= optionKey  }
        if flags.contains(.command) { c |= cmdKey     }
        if flags.contains(.shift)   { c |= shiftKey   }
        return c
    }

    /// Carbon modifiers → 可读字符串（如 "⌃⌥"）
    static func modifierString(from carbonMods: Int) -> String {
        var s = ""
        if carbonMods & controlKey != 0 { s += "⌃" }
        if carbonMods & optionKey  != 0 { s += "⌥" }
        if carbonMods & shiftKey   != 0 { s += "⇧" }
        if carbonMods & cmdKey     != 0 { s += "⌘" }
        return s
    }

    /// Carbon keyCode → 可读字符（尽量显示符号，退而求其次显示字母）
    static func keyString(from keyCode: Int) -> String {
        // 常用功能键映射
        let map: [Int: String] = [
            kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4",
            kVK_F5: "F5", kVK_F6: "F6", kVK_F7: "F7", kVK_F8: "F8",
            kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
            kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥",
            kVK_Delete: "⌫", kVK_Escape: "⎋",
            kVK_UpArrow: "↑", kVK_DownArrow: "↓",
            kVK_LeftArrow: "←", kVK_RightArrow: "→",
            // ANSI 字母
            kVK_ANSI_A: "A", kVK_ANSI_B: "B", kVK_ANSI_C: "C", kVK_ANSI_D: "D",
            kVK_ANSI_E: "E", kVK_ANSI_F: "F", kVK_ANSI_G: "G", kVK_ANSI_H: "H",
            kVK_ANSI_I: "I", kVK_ANSI_J: "J", kVK_ANSI_K: "K", kVK_ANSI_L: "L",
            kVK_ANSI_M: "M", kVK_ANSI_N: "N", kVK_ANSI_O: "O", kVK_ANSI_P: "P",
            kVK_ANSI_Q: "Q", kVK_ANSI_R: "R", kVK_ANSI_S: "S", kVK_ANSI_T: "T",
            kVK_ANSI_U: "U", kVK_ANSI_V: "V", kVK_ANSI_W: "W", kVK_ANSI_X: "X",
            kVK_ANSI_Y: "Y", kVK_ANSI_Z: "Z",
            kVK_ANSI_0: "0", kVK_ANSI_1: "1", kVK_ANSI_2: "2", kVK_ANSI_3: "3",
            kVK_ANSI_4: "4", kVK_ANSI_5: "5", kVK_ANSI_6: "6", kVK_ANSI_7: "7",
            kVK_ANSI_8: "8", kVK_ANSI_9: "9",
        ]
        return map[keyCode] ?? "?"
    }

    /// 当前设置的完整显示字符串（如 "⌃⌥Z"）
    static func currentShortcutString() -> String {
        let mods = AppSettings.shared.hotKeyModifiers
        let code = AppSettings.shared.hotKeyCode
        return modifierString(from: mods) + keyString(from: code)
    }
}
