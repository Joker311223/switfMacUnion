import AppKit
import Foundation

// MARK: - 溢出弹出窗口：展示被折叠的菜单栏图标
// 点击状态栏的「⋯」按钮后弹出，列出所有被隐藏/溢出的应用图标
final class OverflowMenuController: NSObject {

    static let shared = OverflowMenuController()

    private var popover: NSPopover?
    private var statusItem: NSStatusItem?

    private override init() {
        super.init()
    }

    // MARK: - 设置溢出状态栏按钮
    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let btn = statusItem?.button {
            btn.image = AppIconMaker.makeStatusIcon()
            btn.toolTip = "MenuBarManager — 点击展开隐藏图标"
            btn.target = self
            btn.action = #selector(togglePopover(_:))
        }
    }

    @objc private func togglePopover(_ sender: NSButton) {
        if let pop = popover, pop.isShown {
            pop.close()
            return
        }
        showPopover(relativeTo: sender)
    }

    private func showPopover(relativeTo button: NSView) {
        let vc = OverflowViewController()
        let pop = NSPopover()
        pop.contentViewController = vc
        pop.behavior = .transient
        pop.animates = true
        pop.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover = pop
    }
}

// MARK: - 溢出弹出视图控制器
final class OverflowViewController: NSViewController {

    private var scrollView: NSScrollView!
    private var stackView: NSStackView!
    private var apps: [ScannedApp] = []

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 400))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        reload()

        // 监听应用启动/退出，自动刷新
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

    private func setupUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        // ── 标题栏 ──────────────────────────────────
        let titleBar = NSView()
        titleBar.wantsLayer = true
        titleBar.layer?.backgroundColor = NSColor(white: 0, alpha: 0.04).cgColor
        titleBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleBar)

        let titleLabel = NSTextField(labelWithString: "菜单栏图标管理")
        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = NSColor.labelColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleBar.addSubview(titleLabel)

        let manageButton = NSButton(title: "管理 →", target: self, action: #selector(openPreferences))
        manageButton.bezelStyle = .inline
        manageButton.font = NSFont.systemFont(ofSize: 11)
        manageButton.translatesAutoresizingMaskIntoConstraints = false
        titleBar.addSubview(manageButton)

        // ── 滚动列表 ─────────────────────────────────
        stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.spacing = 0
        stackView.alignment = .left
        stackView.distribution = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false

        scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.documentView = stackView
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            titleBar.topAnchor.constraint(equalTo: view.topAnchor),
            titleBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            titleBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            titleBar.heightAnchor.constraint(equalToConstant: 44),

            titleLabel.centerYAnchor.constraint(equalTo: titleBar.centerYAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: titleBar.leadingAnchor, constant: 16),

            manageButton.centerYAnchor.constraint(equalTo: titleBar.centerYAnchor),
            manageButton.trailingAnchor.constraint(equalTo: titleBar.trailingAnchor, constant: -12),

            scrollView.topAnchor.constraint(equalTo: titleBar.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])
    }

    @objc private func reload() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.apps = RunningAppsScanner.scan()
            self.rebuildList()
        }
    }

    private func rebuildList() {
        // 清空旧行
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let store = DataStore.shared
        let hiddenIDs = Set(store.items.filter { $0.isHidden }.map { $0.bundleIdentifier })

        // 分组：隐藏的 & 全部
        let hidden  = apps.filter { hiddenIDs.contains($0.bundleIdentifier) }
        let visible = apps.filter { !hiddenIDs.contains($0.bundleIdentifier) }

        if hidden.isEmpty && visible.isEmpty {
            let empty = NSTextField(labelWithString: "未检测到菜单栏应用")
            empty.textColor = NSColor.secondaryLabelColor
            empty.font = NSFont.systemFont(ofSize: 13)
            empty.translatesAutoresizingMaskIntoConstraints = false
            let wrapper = NSView()
            wrapper.addSubview(empty)
            NSLayoutConstraint.activate([
                empty.centerXAnchor.constraint(equalTo: wrapper.centerXAnchor),
                empty.centerYAnchor.constraint(equalTo: wrapper.centerYAnchor),
                wrapper.heightAnchor.constraint(equalToConstant: 60),
            ])
            stackView.addArrangedSubview(wrapper)
            return
        }

        if !hidden.isEmpty {
            addSectionHeader("已隐藏（共 \(hidden.count) 个）")
            hidden.forEach { addAppRow($0, isHidden: true) }
        }

        if !visible.isEmpty {
            addSectionHeader("菜单栏应用（共 \(visible.count) 个）")
            visible.forEach { addAppRow($0, isHidden: false) }
        }
    }

    private func addSectionHeader(_ title: String) {
        let header = NSTextField(labelWithString: title.uppercased())
        header.font = NSFont.systemFont(ofSize: 10, weight: .semibold)
        header.textColor = NSColor.secondaryLabelColor
        header.translatesAutoresizingMaskIntoConstraints = false

        let wrapper = NSView()
        wrapper.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(header)
        NSLayoutConstraint.activate([
            header.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 16),
            header.centerYAnchor.constraint(equalTo: wrapper.centerYAnchor),
            wrapper.heightAnchor.constraint(equalToConstant: 28),
        ])

        wrapper.wantsLayer = true
        wrapper.layer?.backgroundColor = NSColor(white: 0, alpha: 0.03).cgColor

        stackView.addArrangedSubview(wrapper)
        wrapper.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
    }

    private func addAppRow(_ app: ScannedApp, isHidden: Bool) {
        let row = AppRowView(app: app, isHidden: isHidden)
        row.onToggle = { [weak self] bundleID, hide in
            self?.toggleHide(bundleID: bundleID, hide: hide)
        }
        row.onActivate = { bundleID in
            // 点击应用名 → 激活对应 App
            if let app = NSWorkspace.shared.runningApplications
                .first(where: { $0.bundleIdentifier == bundleID }) {
                app.activate(options: .activateIgnoringOtherApps)
            }
        }
        stackView.addArrangedSubview(row)
        row.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
    }

    private func toggleHide(bundleID: String, hide: Bool) {
        let store = DataStore.shared
        if var item = store.items.first(where: { $0.bundleIdentifier == bundleID }) {
            item.isHidden = hide
            store.upsert(item)
        } else {
            let name = apps.first(where: { $0.bundleIdentifier == bundleID })?.name ?? bundleID
            var newItem = MenuBarItem(bundleIdentifier: bundleID, appName: name)
            newItem.isHidden = hide
            store.upsert(newItem)
        }
        reload()
    }

    @objc private func openPreferences() {
        PreferencesWindowController.shared.show()
    }
}

// MARK: - 单行 App 视图
final class AppRowView: NSView {

    var onToggle: ((String, Bool) -> Void)?
    var onActivate: ((String) -> Void)?

    private let app: ScannedApp
    private let itemHidden: Bool
    private var trackingArea: NSTrackingArea?

    init(app: ScannedApp, isHidden: Bool) {
        self.app = app
        self.itemHidden = isHidden
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        setupUI()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setupUI() {
        wantsLayer = true

        // 图标
        let iconView = NSImageView()
        iconView.image = app.icon
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false

        // App 名称按钮
        let nameBtn = NSButton(title: app.name, target: self, action: #selector(activateApp))
        nameBtn.bezelStyle = .inline
        nameBtn.isBordered = false
        nameBtn.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        nameBtn.contentTintColor = NSColor.labelColor
        nameBtn.alignment = .left
        nameBtn.translatesAutoresizingMaskIntoConstraints = false

        // 类型标签
        let typeLabel = NSTextField(labelWithString: app.isAccessory ? "菜单栏" : "普通")
        typeLabel.font = NSFont.systemFont(ofSize: 10)
        typeLabel.textColor = NSColor.tertiaryLabelColor
        typeLabel.translatesAutoresizingMaskIntoConstraints = false

        // 切换按钮
        let actionTitle = itemHidden ? "显示" : "隐藏"
        let toggleBtn = NSButton(title: actionTitle, target: self, action: #selector(toggleAction))
        toggleBtn.bezelStyle = .rounded
        toggleBtn.font = NSFont.systemFont(ofSize: 11)
        toggleBtn.translatesAutoresizingMaskIntoConstraints = false

        addSubview(iconView)
        addSubview(nameBtn)
        addSubview(typeLabel)
        addSubview(toggleBtn)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 48),

            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),

            nameBtn.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 10),
            nameBtn.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            nameBtn.trailingAnchor.constraint(equalTo: toggleBtn.leadingAnchor, constant: -8),

            typeLabel.leadingAnchor.constraint(equalTo: nameBtn.leadingAnchor),
            typeLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),

            toggleBtn.centerYAnchor.constraint(equalTo: centerYAnchor),
            toggleBtn.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            toggleBtn.widthAnchor.constraint(equalToConstant: 46),
        ])

        // 分隔线
        let sep = NSBox()
        sep.boxType = .separator
        sep.translatesAutoresizingMaskIntoConstraints = false
        addSubview(sep)
        NSLayoutConstraint.activate([
            sep.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 50),
            sep.trailingAnchor.constraint(equalTo: trailingAnchor),
            sep.bottomAnchor.constraint(equalTo: bottomAnchor),
            sep.heightAnchor.constraint(equalToConstant: 1),
        ])
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let old = trackingArea { removeTrackingArea(old) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow],
            owner: self
        )
        addTrackingArea(area)
        trackingArea = area
    }
    override func mouseEntered(with event: NSEvent) {
        layer?.backgroundColor = NSColor(white: 0, alpha: 0.05).cgColor
    }
    override func mouseExited(with event: NSEvent) {
        layer?.backgroundColor = .clear
    }

    @objc private func toggleAction() {
        onToggle?(app.bundleIdentifier, !itemHidden)
    }
    @objc private func activateApp() {
        onActivate?(app.bundleIdentifier)
    }
}
