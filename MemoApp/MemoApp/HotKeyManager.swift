import AppKit
import Carbon.HIToolbox

// MARK: - 全局热键管理器
// fn+z 在 macOS 中 fn 键无法直接作为修饰键，
// 实际注册为 Control+Option+Z（等效常用快捷键），
// 同时提供菜单栏快捷键入口。
// 注意：真正的 fn 键需要 IOKit 级别拦截，系统限制较多。
// 这里注册 ⌃⌥Z（Control+Option+Z）作为全局热键。

final class HotKeyManager {
    
    static let shared = HotKeyManager()
    
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    var onTrigger: (() -> Void)?
    
    private init() {}
    
    func register() {
        // 注册 Control+Option+Z 为全局热键
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(0x4D454D4F) // 'MEMO'
        hotKeyID.id = 1
        
        var eventType = EventTypeSpec()
        eventType.eventClass = OSType(kEventClassKeyboard)
        eventType.eventKind = OSType(kEventHotKeyPressed)
        
        // 安装事件处理器
        InstallEventHandler(
            GetApplicationEventTarget(),
            { (nextHandler, event, userData) -> OSStatus in
                guard let userData = userData else { return OSStatus(eventNotHandledErr) }
                let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                
                var hotKeyID = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                
                if hotKeyID.id == 1 {
                    DispatchQueue.main.async {
                        manager.onTrigger?()
                    }
                }
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
        
        // Control + Option + Z
        // kVK_ANSI_Z = 6
        let modifiers: UInt32 = UInt32(controlKey | optionKey)
        RegisterEventHotKey(
            UInt32(kVK_ANSI_Z),
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }
    
    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
    }
    
    deinit {
        unregister()
    }
}
