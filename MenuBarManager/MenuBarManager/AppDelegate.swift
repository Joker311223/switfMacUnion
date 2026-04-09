import AppKit
import Foundation

// MARK: - App Delegate
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var mainStatusItem: NSStatusItem?   // 主状态栏图标（带溢出展开功能）

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 纯菜单栏应用，不在 Dock / 应用切换器中显示
        if AppSettings.shared.hideDockIcon {
            NSApp.setActivationPolicy(.accessory)
        } else {
            NSApp.setActivationPolicy(.regular)
            NSApp.applicationIconImage = AppIconMaker.make()
        }

        // 设置主状态栏图标
        setupMainStatusItem()

        // 设置溢出弹出面板（管理隐藏的图标）
        OverflowMenuController.shared.setup()

        // 监听应用启停，动态更新菜单
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appsChanged),
            name: NSWorkspace.didLaunchApplicationNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appsChanged),
            name: NSWorkspace.didTerminateApplicationNotification,
            object: nil
        )
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    // MARK: - 主状态栏图标（点击 → 弹出快捷操作菜单）
    private func setupMainStatusItem() {
        mainStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let btn = mainStatusItem?.button {
            btn.image = AppIconMaker.makeStatusIcon()
            btn.toolTip = "MenuBarManager"
        }

        rebuildMenu()
    }

    @objc private func appsChanged() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.rebuildMenu()
        }
    }

    // MARK: - 构建状态栏下拉菜单
    private func rebuildMenu() {
        let menu = NSMenu()

        // ── 标题 ─────────────────────────────────────────
        let titleItem = NSMenuItem()
        titleItem.view = makeTitleView()
        menu.addItem(titleItem)
        menu.addItem(.separator())

        // ── 运行中的菜单栏应用列表 ────────────────────────
        let apps = RunningAppsScanner.scan()
        let store = DataStore.shared
        let hiddenIDs = Set(store.items.filter { $0.isHidden }.map { $0.bundleIdentifier })

        let visible = apps.filter { !hiddenIDs.contains($0.bundleIdentifier) }
        let hidden  = apps.filter { hiddenIDs.contains($0.bundleIdentifier) }

        if !hidden.isEmpty {
            let sectionItem = NSMenuItem(title: "已隐藏的应用", action: nil, keyEquivalent: "")
            sectionItem.isEnabled = false
            menu.addItem(sectionItem)

            for app in hidden.prefix(AppSettings.shared.maxVisibleCount) {
                let item = NSMenuItem(title: app.name, action: #selector(activateApp(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = app.bundleIdentifier
                if let icon = app.icon {
                    let resized = resizeIcon(icon, to: NSSize(width: 16, height: 16))
                    item.image = resized
                }
                menu.addItem(item)
            }
            menu.addItem(.separator())
        }

        if apps.isEmpty {
            let emptyItem = NSMenuItem(title: "未检测到菜单栏应用", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
            menu.addItem(.separator())
        } else if !visible.isEmpty {
            let countItem = NSMenuItem(
                title: "运行中：\(visible.count) 个 · 已隐藏：\(hidden.count) 个",
                action: nil, keyEquivalent: ""
            )
            countItem.isEnabled = false
            menu.addItem(countItem)
            menu.addItem(.separator())
        }

        // ── 操作按钮 ─────────────────────────────────────
        let prefsItem = NSMenuItem(title: "偏好设置...", action: #selector(openPreferences), keyEquivalent: ",")
        prefsItem.target = self
        menu.addItem(prefsItem)

        let refreshItem = NSMenuItem(title: "刷新应用列表", action: #selector(appsChanged), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "退出 MenuBarManager", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        mainStatusItem?.menu = menu
    }

    // MARK: - 菜单标题视图
    private func makeTitleView() -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 220, height: 36))

        let iconView = NSImageView(frame: NSRect(x: 12, y: 8, width: 20, height: 20))
        iconView.image = AppIconMaker.makeStatusIcon(size: 18)
        iconView.contentTintColor = NSColor.labelColor
        view.addSubview(iconView)

        let label = NSTextField(labelWithString: "MenuBarManager")
        label.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        label.frame = NSRect(x: 38, y: 10, width: 170, height: 18)
        view.addSubview(label)

        return view
    }

    // MARK: - Actions
    @objc private func openPreferences() {
        PreferencesWindowController.shared.show()
    }

    @objc private func activateApp(_ sender: NSMenuItem) {
        guard let bundleID = sender.representedObject as? String else { return }
        if let app = NSWorkspace.shared.runningApplications
            .first(where: { $0.bundleIdentifier == bundleID }) {
            app.activate(options: .activateIgnoringOtherApps)
        }
    }

    // MARK: - 工具方法
    private func resizeIcon(_ image: NSImage, to size: NSSize) -> NSImage {
        let result = NSImage(size: size)
        result.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: size),
                   from: NSRect(origin: .zero, size: image.size),
                   operation: .sourceOver, fraction: 1)
        result.unlockFocus()
        return result
    }

    func applicationWillTerminate(_ notification: Notification) {
        DataStore.shared.save()
    }
}
