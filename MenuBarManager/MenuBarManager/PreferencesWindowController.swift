import AppKit
import Foundation

// MARK: - 偏好设置窗口
final class PreferencesWindowController: NSWindowController {

    static let shared = PreferencesWindowController()

    private var tabView: NSTabView?
    private var generalVC: GeneralPrefsViewController?
    private var appsVC: AppsPrefsViewController?

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 460),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "MenuBarManager 偏好设置"
        window.center()
        window.isReleasedWhenClosed = false
        super.init(window: window)
        setupContent()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupContent() {
        let gvc = GeneralPrefsViewController()
        let avc = AppsPrefsViewController()
        generalVC = gvc
        appsVC = avc

        let tv = NSTabView()
        tv.tabViewType = .topTabsBezelBorder
        tv.translatesAutoresizingMaskIntoConstraints = false

        let genItem = NSTabViewItem(viewController: gvc)
        genItem.label = "通用"
        let appsItem = NSTabViewItem(viewController: avc)
        appsItem.label = "应用管理"
        tv.addTabViewItem(genItem)
        tv.addTabViewItem(appsItem)
        tabView = tv

        guard let contentView = window?.contentView else { return }
        contentView.addSubview(tv)
        NSLayoutConstraint.activate([
            tv.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            tv.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            tv.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            tv.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
        ])
    }

    func show() {
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        // 等 viewDidLoad 完成后再 reload，避免 tableView 为 nil
        DispatchQueue.main.async { [weak self] in
            self?.appsVC?.reload()
        }
    }
}

// MARK: - 通用设置 Tab
final class GeneralPrefsViewController: NSViewController {

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 540, height: 420))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildUI()
    }

    private func buildUI() {
        let settings = AppSettings.shared

        // 标题
        let titleLabel = makeLabel("通用", size: 15, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)

        // ── 最大显示数量 ─────────────────────────────────
        let countLabel = makeLabel("菜单栏最大显示图标数量：", size: 13)
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(countLabel)

        let countStepper = NSStepper()
        countStepper.minValue = 1
        countStepper.maxValue = 20
        countStepper.integerValue = settings.maxVisibleCount
        countStepper.translatesAutoresizingMaskIntoConstraints = false
        countStepper.target = self
        countStepper.action = #selector(countChanged(_:))
        view.addSubview(countStepper)

        let countValueLabel = makeLabel("\(settings.maxVisibleCount)", size: 13)
        countValueLabel.tag = 100
        countValueLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(countValueLabel)

        // ── 溢出指示器开关 ───────────────────────────────
        let overflowCheck = NSButton(checkboxWithTitle: "显示「⋯」溢出展开按钮",
                                     target: self, action: #selector(overflowToggled(_:)))
        overflowCheck.state = settings.showOverflowIndicator ? .on : .off
        overflowCheck.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(overflowCheck)

        let overflowDesc = makeLabel("当菜单栏图标超出显示数量时，折叠到「⋯」按钮下方", size: 11)
        overflowDesc.textColor = NSColor.secondaryLabelColor
        overflowDesc.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(overflowDesc)

        // ── 开机自启 ─────────────────────────────────────
        let loginCheck = NSButton(checkboxWithTitle: "登录时自动启动",
                                  target: self, action: #selector(loginToggled(_:)))
        loginCheck.state = settings.launchAtLogin ? .on : .off
        loginCheck.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(loginCheck)

        // ── Dock 图标 ────────────────────────────────────
        let dockCheck = NSButton(checkboxWithTitle: "在 Dock 中隐藏图标（纯菜单栏模式）",
                                 target: self, action: #selector(dockToggled(_:)))
        dockCheck.state = settings.hideDockIcon ? .on : .off
        dockCheck.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(dockCheck)

        // ── 说明区 ───────────────────────────────────────
        let infoBox = NSBox()
        infoBox.boxType = .custom
        infoBox.fillColor = NSColor(white: 0, alpha: 0.04)
        infoBox.borderColor = NSColor(white: 0, alpha: 0.08)
        infoBox.cornerRadius = 8
        infoBox.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(infoBox)

        let infoText = makeLabel(
            "💡 MenuBarManager 会常驻在菜单栏中。当菜单栏图标被其他内容遮挡时，点击「⋯」可展开所有隐藏图标。\n\n在「应用管理」标签页中，可以手动设置每个 App 图标的显示或隐藏状态。",
            size: 12
        )
        infoText.isEditable = false
        infoText.isBordered = false
        infoText.backgroundColor = .clear
        infoText.maximumNumberOfLines = 5
        infoText.lineBreakMode = .byWordWrapping
        infoText.textColor = NSColor.secondaryLabelColor
        infoText.translatesAutoresizingMaskIntoConstraints = false
        infoBox.addSubview(infoText)

        let topPad: CGFloat = 24
        let left: CGFloat = 24
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: topPad),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: left),

            countLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 24),
            countLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: left),

            countStepper.centerYAnchor.constraint(equalTo: countLabel.centerYAnchor),
            countStepper.leadingAnchor.constraint(equalTo: countLabel.trailingAnchor, constant: 8),

            countValueLabel.centerYAnchor.constraint(equalTo: countLabel.centerYAnchor),
            countValueLabel.leadingAnchor.constraint(equalTo: countStepper.trailingAnchor, constant: 6),

            overflowCheck.topAnchor.constraint(equalTo: countLabel.bottomAnchor, constant: 20),
            overflowCheck.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: left),

            overflowDesc.topAnchor.constraint(equalTo: overflowCheck.bottomAnchor, constant: 4),
            overflowDesc.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: left + 20),

            loginCheck.topAnchor.constraint(equalTo: overflowDesc.bottomAnchor, constant: 16),
            loginCheck.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: left),

            dockCheck.topAnchor.constraint(equalTo: loginCheck.bottomAnchor, constant: 12),
            dockCheck.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: left),

            infoBox.topAnchor.constraint(equalTo: dockCheck.bottomAnchor, constant: 28),
            infoBox.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: left),
            infoBox.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -left),

            infoText.topAnchor.constraint(equalTo: infoBox.topAnchor, constant: 12),
            infoText.leadingAnchor.constraint(equalTo: infoBox.leadingAnchor, constant: 12),
            infoText.trailingAnchor.constraint(equalTo: infoBox.trailingAnchor, constant: -12),
            infoText.bottomAnchor.constraint(equalTo: infoBox.bottomAnchor, constant: -12),
            infoBox.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -24),
        ])
    }

    @objc private func countChanged(_ sender: NSStepper) {
        AppSettings.shared.maxVisibleCount = sender.integerValue
        if let label = view.viewWithTag(100) as? NSTextField {
            label.stringValue = "\(sender.integerValue)"
        }
    }
    @objc private func overflowToggled(_ sender: NSButton) {
        AppSettings.shared.showOverflowIndicator = sender.state == .on
    }
    @objc private func loginToggled(_ sender: NSButton) {
        AppSettings.shared.launchAtLogin = sender.state == .on
    }
    @objc private func dockToggled(_ sender: NSButton) {
        AppSettings.shared.hideDockIcon = sender.state == .on
        let policy: NSApplication.ActivationPolicy = sender.state == .on ? .accessory : .regular
        NSApp.setActivationPolicy(policy)
    }

    private func makeLabel(_ s: String, size: CGFloat, weight: NSFont.Weight = .regular) -> NSTextField {
        let label = NSTextField(labelWithString: s)
        label.font = NSFont.systemFont(ofSize: size, weight: weight)
        return label
    }
}

// MARK: - 应用管理 Tab
final class AppsPrefsViewController: NSViewController {

    private var tableView: NSTableView?
    private var scrollView: NSScrollView?
    private var apps: [ScannedApp] = []
    private var items: [MenuBarItem] = []

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 540, height: 420))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildUI()
        reload()

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(reload),
            name: NSWorkspace.didLaunchApplicationNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(reload),
            name: NSWorkspace.didTerminateApplicationNotification,
            object: nil
        )
    }

    private func buildUI() {
        let tv = NSTableView()
        tv.delegate = self
        tv.dataSource = self
        tv.rowHeight = 44
        tv.intercellSpacing = NSSize(width: 0, height: 0)
        tv.headerView = nil
        tv.selectionHighlightStyle = .none
        tv.usesAlternatingRowBackgroundColors = false

        let iconCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("icon"))
        iconCol.width = 40
        iconCol.minWidth = 40
        iconCol.maxWidth = 40
        tv.addTableColumn(iconCol)

        let nameCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        nameCol.width = 260
        tv.addTableColumn(nameCol)

        let typeCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("type"))
        typeCol.width = 80
        tv.addTableColumn(typeCol)

        let toggleCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("toggle"))
        toggleCol.width = 100
        tv.addTableColumn(toggleCol)

        tableView = tv   // 赋给属性

        let sv = NSScrollView()
        sv.documentView = tv
        sv.hasVerticalScroller = true
        sv.autohidesScrollers = true
        sv.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(sv)
        scrollView = sv  // 赋给属性
        let scrollView = sv  // 局部别名，供约束使用

        // 说明标签
        let hint = NSTextField(labelWithString: "✦ 管理当前正在运行的菜单栏应用。隐藏的图标仍在后台运行，可通过「⋯」展开访问。")
        hint.font = NSFont.systemFont(ofSize: 11)
        hint.textColor = NSColor.secondaryLabelColor
        hint.maximumNumberOfLines = 2
        hint.lineBreakMode = .byWordWrapping
        hint.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hint)

        // 刷新按钮
        let refreshBtn = NSButton(title: "刷新列表", target: self, action: #selector(reload))
        refreshBtn.bezelStyle = .rounded
        refreshBtn.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(refreshBtn)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            scrollView.bottomAnchor.constraint(equalTo: hint.topAnchor, constant: -10),

            hint.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            hint.trailingAnchor.constraint(equalTo: refreshBtn.leadingAnchor, constant: -8),
            hint.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -14),

            refreshBtn.centerYAnchor.constraint(equalTo: hint.centerYAnchor),
            refreshBtn.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            refreshBtn.widthAnchor.constraint(equalToConstant: 80),
        ])
    }

    @objc func reload() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.apps = RunningAppsScanner.scan()
            self.items = DataStore.shared.items
            self.tableView?.reloadData()
        }
    }

    private func isHidden(bundleID: String) -> Bool {
        items.first(where: { $0.bundleIdentifier == bundleID })?.isHidden ?? false
    }
}

extension AppsPrefsViewController: NSTableViewDataSource, NSTableViewDelegate {

    func numberOfRows(in tableView: NSTableView) -> Int { apps.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let app = apps[row]
        let hidden = isHidden(bundleID: app.bundleIdentifier)

        switch tableColumn?.identifier.rawValue {
        case "icon":
            let cell = NSTableCellView()
            let imageView = NSImageView()
            imageView.image = app.icon
            imageView.imageScaling = .scaleProportionallyUpOrDown
            imageView.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(imageView)
            NSLayoutConstraint.activate([
                imageView.centerXAnchor.constraint(equalTo: cell.centerXAnchor),
                imageView.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                imageView.widthAnchor.constraint(equalToConstant: 24),
                imageView.heightAnchor.constraint(equalToConstant: 24),
            ])
            return cell

        case "name":
            let cell = NSTableCellView()
            let label = NSTextField(labelWithString: app.name)
            label.font = NSFont.systemFont(ofSize: 13, weight: .medium)
            label.textColor = hidden ? NSColor.tertiaryLabelColor : NSColor.labelColor
            label.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(label)
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
                label.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                label.trailingAnchor.constraint(lessThanOrEqualTo: cell.trailingAnchor),
            ])
            return cell

        case "type":
            let cell = NSTableCellView()
            let label = NSTextField(labelWithString: app.isAccessory ? "菜单栏" : "普通")
            label.font = NSFont.systemFont(ofSize: 11)
            label.textColor = NSColor.tertiaryLabelColor
            label.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(label)
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: cell.leadingAnchor),
                label.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            ])
            return cell

        case "toggle":
            let cell = NSTableCellView()
            let btn = NSButton(
                title: hidden ? "显示" : "隐藏",
                target: self,
                action: #selector(toggleRow(_:))
            )
            btn.bezelStyle = .rounded
            btn.font = NSFont.systemFont(ofSize: 11)
            btn.tag = row
            btn.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(btn)
            NSLayoutConstraint.activate([
                btn.centerXAnchor.constraint(equalTo: cell.centerXAnchor),
                btn.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                btn.widthAnchor.constraint(equalToConstant: 52),
            ])
            return cell

        default:
            return nil
        }
    }

    @objc private func toggleRow(_ sender: NSButton) {
        let row = sender.tag
        guard row < apps.count else { return }
        let app = apps[row]
        let currentlyHidden = isHidden(bundleID: app.bundleIdentifier)
        let store = DataStore.shared
        if var item = store.items.first(where: { $0.bundleIdentifier == app.bundleIdentifier }) {
            item.isHidden = !currentlyHidden
            store.upsert(item)
        } else {
            var newItem = MenuBarItem(bundleIdentifier: app.bundleIdentifier, appName: app.name)
            newItem.isHidden = !currentlyHidden
            store.upsert(newItem)
        }
        reload()
    }
}
