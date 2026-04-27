import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    
    private var windowController: WebWindowController?
    private var statusItem: NSStatusItem?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 设置为 accessory 模式（无 Dock 图标，保持在状态栏）
        NSApp.setActivationPolicy(.accessory)

        // 设置应用图标（Dock & About 面板）
        NSApp.applicationIconImage = AppIconMaker.make()

        // 设置状态栏图标
        setupStatusBar()
        
        // 创建并显示主窗口
        windowController = WebWindowController()
        windowController?.showWindow(nil)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    // MARK: - 状态栏
    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "globe", accessibilityDescription: "WebViewer")
            button.image?.isTemplate = true
            button.toolTip = "WebViewer"
        }
        
        let menu = NSMenu()
        
        let showItem = NSMenuItem(title: "显示窗口", action: #selector(showWindow), keyEquivalent: "")
        showItem.target = self
        menu.addItem(showItem)
        
        let hideItem = NSMenuItem(title: "隐藏窗口", action: #selector(hideWindow), keyEquivalent: "")
        hideItem.target = self
        menu.addItem(hideItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let reloadItem = NSMenuItem(title: "刷新页面", action: #selector(reloadPage), keyEquivalent: "r")
        reloadItem.target = self
        menu.addItem(reloadItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
    }
    
    @objc private func showWindow() {
        windowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func hideWindow() {
        windowController?.window?.orderOut(nil)
    }
    
    @objc private func reloadPage() {
        windowController?.reload()
    }
}
