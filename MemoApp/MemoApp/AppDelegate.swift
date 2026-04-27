import AppKit
import Foundation

// MARK: - App Delegate
final class AppDelegate: NSObject, NSApplicationDelegate {
    
    private var windowController: MainWindowController?
    private var statusItem: NSStatusItem?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 设置为普通应用（有 Dock 图标和菜单栏）
        NSApp.setActivationPolicy(.regular)

        // 设置 Dock 图标
        NSApp.applicationIconImage = AppIconMaker.make()

        // 设置顶部菜单栏
        setupMenu()
        
        // 设置系统状态栏图标（右上角常驻）
        setupStatusBar()
        
        // 创建并显示主窗口
        windowController = MainWindowController()
        windowController?.showAndFocus()

        // 注册全局热键 ⌃⌥Z → 打开最近备忘录
        HotKeyManager.shared.onTrigger = { [weak self] in
            self?.openMostRecent()
        }
        HotKeyManager.shared.register()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false // 关闭窗口不退出，保持后台运行继续监听热键
    }

    // 所有窗口关闭后：切换为 accessory 模式（Dock & 菜单栏消失，状态栏图标保留）
    func applicationDidResignActive(_ notification: Notification) {
        let hasVisible = NSApp.windows.contains { $0.isVisible && !$0.isMiniaturized }
        if !hasVisible {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    // 重新激活时：如果变成了 accessory，恢复 regular
    func applicationWillBecomeActive(_ notification: Notification) {
        if NSApp.activationPolicy() == .accessory {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showApp()
        return true
    }
    
    // MARK: - 顶部菜单栏（Menu Bar）
    private func setupMenu() {
        let menuBar = NSMenu()
        
        // ① App 菜单（显示应用名）
        let appMenuItem = NSMenuItem()
        menuBar.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        appMenu.addItem(NSMenuItem(title: "关于备忘录", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: ""))
        appMenu.addItem(NSMenuItem.separator())
        let prefsItem = NSMenuItem(title: "偏好设置...", action: #selector(openPreferences), keyEquivalent: ",")
        prefsItem.target = self
        appMenu.addItem(prefsItem)
        appMenu.addItem(NSMenuItem.separator())
        let hideItem = NSMenuItem(title: "隐藏备忘录", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(hideItem)
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(NSMenuItem(title: "退出备忘录", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        // ② 文件菜单
        let fileMenuItem = NSMenuItem()
        fileMenuItem.title = "文件"
        menuBar.addItem(fileMenuItem)
        let fileMenu = NSMenu(title: "文件")
        fileMenuItem.submenu = fileMenu
        
        let newItem = NSMenuItem(title: "新建备忘录", action: #selector(newMemo), keyEquivalent: "n")
        newItem.target = self
        fileMenu.addItem(newItem)
        fileMenu.addItem(NSMenuItem.separator())
        let closeItem = NSMenuItem(title: "关闭窗口", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        fileMenu.addItem(closeItem)
        
        // ③ 编辑菜单
        let editMenuItem = NSMenuItem()
        editMenuItem.title = "编辑"
        menuBar.addItem(editMenuItem)
        let editMenu = NSMenu(title: "编辑")
        editMenuItem.submenu = editMenu
        editMenu.addItem(withTitle: "撤销", action: #selector(UndoManager.undo), keyEquivalent: "z")
        editMenu.addItem(withTitle: "重做", action: #selector(UndoManager.redo), keyEquivalent: "Z")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "剪切", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "复制", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenu.addItem(NSMenuItem.separator())
        let findItem = editMenu.addItem(withTitle: "查找", action: #selector(NSTextView.performFindPanelAction(_:)), keyEquivalent: "f")
        findItem.tag = 1 // NSFindPanelAction.showFindPanel
        
        // ④ 视图菜单
        let viewMenuItem = NSMenuItem()
        viewMenuItem.title = "视图"
        menuBar.addItem(viewMenuItem)
        let viewMenu = NSMenu(title: "视图")
        viewMenuItem.submenu = viewMenu
        
        let openRecentItem = NSMenuItem(title: "打开最近备忘录", action: #selector(openMostRecent), keyEquivalent: "z")
        openRecentItem.keyEquivalentModifierMask = [.control, .option]
        openRecentItem.target = self
        viewMenu.addItem(openRecentItem)
        viewMenu.addItem(NSMenuItem.separator())
        
        let toggleFullScreen = NSMenuItem(title: "进入全屏", action: #selector(NSWindow.toggleFullScreen(_:)), keyEquivalent: "f")
        toggleFullScreen.keyEquivalentModifierMask = [.command, .control]
        viewMenu.addItem(toggleFullScreen)
        
        // ⑤ 窗口菜单
        let windowMenuItem = NSMenuItem()
        windowMenuItem.title = "窗口"
        menuBar.addItem(windowMenuItem)
        let windowMenu = NSMenu(title: "窗口")
        windowMenuItem.submenu = windowMenu
        windowMenu.addItem(withTitle: "最小化", action: #selector(NSWindow.miniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "缩放", action: #selector(NSWindow.zoom(_:)), keyEquivalent: "")
        windowMenu.addItem(NSMenuItem.separator())
        let showItem = NSMenuItem(title: "显示备忘录", action: #selector(showApp), keyEquivalent: "")
        showItem.target = self
        windowMenu.addItem(showItem)
        
        NSApp.mainMenu = menuBar
        NSApp.windowsMenu = windowMenu
    }
    
    // MARK: - 系统状态栏（右上角图标）
    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "note.text", accessibilityDescription: "备忘录")
            button.image?.isTemplate = true // 自动适配深色/浅色模式
            button.toolTip = "备忘录"
        }
        
        // 状态栏下拉菜单
        let statusMenu = NSMenu()
        
        let showItem = NSMenuItem(title: "打开备忘录", action: #selector(showApp), keyEquivalent: "")
        showItem.target = self
        statusMenu.addItem(showItem)
        
        let newItem = NSMenuItem(title: "新建备忘录", action: #selector(newMemo), keyEquivalent: "")
        newItem.target = self
        statusMenu.addItem(newItem)
        
        statusMenu.addItem(NSMenuItem.separator())
        
        let recentItem = NSMenuItem(title: "打开最近备忘录 (⌃⌥Z)", action: #selector(openMostRecent), keyEquivalent: "")
        recentItem.target = self
        statusMenu.addItem(recentItem)
        
        statusMenu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
        statusMenu.addItem(quitItem)
        
        statusItem?.menu = statusMenu
    }
    
    // MARK: - Actions
    
    @objc private func showApp() {
        // 从 accessory 模式唤醒时先恢复 regular，再显示窗口
        if NSApp.activationPolicy() == .accessory {
            NSApp.setActivationPolicy(.regular)
        }
        windowController?.showAndFocus()
    }

    @objc func openPreferences() {
        PreferencesWindowController.shared.show()
    }
    
    @objc private func newMemo() {
        windowController?.showAndFocus()
        if let root = windowController?.window?.contentViewController as? RootSplitViewController {
            var store = DataStore.shared
            root.mainVC.createNewMemo(store: &store)
            DataStore.shared = store
            root.sidebarVC.reload(memos: DataStore.shared.memos)
            if let first = DataStore.shared.memos.first {
                root.sidebarVC.selectMemo(first)
                root.mainVC.load(memo: first)
            }
        }
    }
    
    @objc private func openMostRecent() {
        windowController?.showAndFocus()
        if let root = windowController?.window?.contentViewController as? RootSplitViewController {
            root.openMostRecent()
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        HotKeyManager.shared.teardown()
        // 应用退出前强制保存当前正在编辑的内容
        if let root = windowController?.window?.contentViewController as? RootSplitViewController {
            root.mainVC.flushDraftOnClose()
        }
    }
}
