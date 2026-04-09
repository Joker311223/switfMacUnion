import AppKit
import Foundation
import Carbon.HIToolbox

// MARK: - 应用配置（UserDefaults 持久化）
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    // ── 保存路径 ──────────────────────────────────
    /// nil 表示使用默认路径（Application Support/MemoApp）
    @Setting("saveDirectory", default: nil as String?)
    var saveDirectory: String?

    var effectiveSaveURL: URL {
        if let dir = saveDirectory, !dir.isEmpty {
            let url = URL(fileURLWithPath: dir, isDirectory: true)
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            return url
        }
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("MemoApp", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // ── 编辑器样式 ────────────────────────────────
    @Setting("editorFontSize",       default: 14.0)  var editorFontSize: Double
    @Setting("editorFontFamily",     default: "mono") var editorFontFamily: String   // "mono" | "system" | "serif"
    @Setting("editorLineSpacing",    default: 6.0)   var editorLineSpacing: Double
    @Setting("editorLineWidth",      default: 0.0)   var editorLineWidth: Double     // 0 = 不限制
    @Setting("previewFontSize",      default: 14.0)  var previewFontSize: Double
    @Setting("showLineNumbers",      default: false)  var showLineNumbers: Bool
    @Setting("editorTheme",          default: "auto") var editorTheme: String        // "auto" | "light" | "dark"
    @Setting("wordWrap",             default: true)   var wordWrap: Bool

    // ── 自动保存 ──────────────────────────────────
    @Setting("autoSaveEnabled",      default: true)   var autoSaveEnabled: Bool
    @Setting("autoSaveDelay",        default: 0.5)    var autoSaveDelay: Double      // 秒

    // ── 快捷键 ────────────────────────────────────
    @Setting("hotKeyModifiers",      default: 786432) var hotKeyModifiers: Int       // Control+Option
    @Setting("hotKeyCode",           default: 6)      var hotKeyCode: Int            // Z

    // ── 界面偏好 ──────────────────────────────────
    @Setting("sidebarWidth",         default: 220.0)  var sidebarWidth: Double
    @Setting("showPreviewPane",      default: true)   var showPreviewPane: Bool
    @Setting("showWordCount",        default: true)   var showWordCount: Bool
    @Setting("showSaveStatus",       default: true)   var showSaveStatus: Bool
    @Setting("confirmDelete",        default: true)   var confirmDelete: Bool
    @Setting("defaultTitle",         default: "新建备忘录") var defaultTitle: String
    @Setting("spellCheck",           default: false)  var spellCheck: Bool
    @Setting("markdownSyntaxHL",     default: true)   var markdownSyntaxHL: Bool

    // ── 导出 ──────────────────────────────────────
    @Setting("exportDirectory",      default: nil as String?) var exportDirectory: String?

    // ── 预览颜色（存 hex 字符串，nil = 使用默认色）──────────
    @Setting("colorH1",   default: "")  var colorH1:   String   // H1 标题色
    @Setting("colorH2",   default: "")  var colorH2:   String   // H2 标题色
    @Setting("colorH3",   default: "")  var colorH3:   String   // H3 标题色
    @Setting("colorH4",   default: "")  var colorH4:   String   // H4 标题色
    @Setting("colorBody", default: "")  var colorBody: String   // 正文色
    @Setting("colorLink", default: "")  var colorLink: String   // 链接色
    @Setting("colorCode", default: "")  var colorCode: String   // 行内代码色

    private init() {}
}

// MARK: - NSColor <-> Hex 互转工具
extension NSColor {
    /// 转为 "#RRGGBB" 格式（忽略 alpha）
    var hexString: String {
        guard let rgb = usingColorSpace(.sRGB) else { return "" }
        let r = Int(rgb.redComponent   * 255)
        let g = Int(rgb.greenComponent * 255)
        let b = Int(rgb.blueComponent  * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    /// 从 "#RRGGBB" 解析（失败返回 nil）
    static func fromHex(_ hex: String) -> NSColor? {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s = String(s.dropFirst()) }
        guard s.count == 6, let val = UInt32(s, radix: 16) else { return nil }
        let r = CGFloat((val >> 16) & 0xFF) / 255
        let g = CGFloat((val >> 8)  & 0xFF) / 255
        let b = CGFloat( val        & 0xFF) / 255
        return NSColor(red: r, green: g, blue: b, alpha: 1)
    }
}

// MARK: - @Setting 属性包装器
@propertyWrapper
struct Setting<T> {
    let key: String
    let defaultValue: T

    init(_ key: String, default value: T) {
        self.key          = key
        self.defaultValue = value
    }

    var wrappedValue: T {
        get { UserDefaults.standard.object(forKey: key) as? T ?? defaultValue }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}

// MARK: - Optional String 特化
@propertyWrapper
struct SettingOptString {
    let key: String
    var wrappedValue: String? {
        get { UserDefaults.standard.string(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
    init(_ key: String) { self.key = key }
}

// MARK: - 偏好设置窗口控制器
final class PreferencesWindowController: NSWindowController {

    static let shared = PreferencesWindowController()

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 480),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title   = "偏好设置"
        window.minSize = NSSize(width: 560, height: 400)
        window.center()
        window.setFrameAutosaveName("PrefsWindow")
        super.init(window: window)
        window.contentViewController = PreferencesTabViewController()
    }

    required init?(coder: NSCoder) { fatalError() }

    func show() {
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - 偏好设置 Tab 容器
final class PreferencesTabViewController: NSTabViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        tabStyle = .toolbar

        let tabs: [(String, String, NSViewController)] = [
            ("通用",   "gear",            GeneralPrefsVC()),
            ("编辑器", "doc.text",         EditorPrefsVC()),
            ("外观",   "paintbrush",       AppearancePrefsVC()),
            ("快捷键", "keyboard",         HotkeyPrefsVC()),
            ("存储",   "folder",           StoragePrefsVC()),
            ("导出",   "square.and.arrow.up", ExportPrefsVC()),
        ]

        for (title, icon, vc) in tabs {
            let item = NSTabViewItem(viewController: vc)
            item.label = title
            item.image = NSImage(systemSymbolName: icon, accessibilityDescription: title)
            addTabViewItem(item)
        }
    }
}

// MARK: - 通用设置
final class GeneralPrefsVC: PrefsBaseVC {
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "通用"

        let s = AppSettings.shared

        addSection("行为")
        addToggle("启动时显示备忘录", value: true, key: "launchShow") { _ in }
        addToggle("关闭窗口后保持后台运行", value: true, key: "keepBackground") { _ in }
        addToggle("关闭前确认删除", value: s.confirmDelete) { val in
            AppSettings.shared.confirmDelete = val
        }
        addToggle("显示字数统计", value: s.showWordCount) { val in
            AppSettings.shared.showWordCount = val
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
        addToggle("显示保存状态指示", value: s.showSaveStatus) { val in
            AppSettings.shared.showSaveStatus = val
        }

        addSection("新建备忘录")
        addTextField("默认标题", value: s.defaultTitle) { val in
            AppSettings.shared.defaultTitle = val
        }
    }
}

// MARK: - 编辑器设置
final class EditorPrefsVC: PrefsBaseVC {
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "编辑器"

        let s = AppSettings.shared

        addSection("字体")
        addPopup("字体风格", options: ["等宽", "系统默认", "衬线"], selected: ["mono","system","serif"].firstIndex(of: s.editorFontFamily) ?? 0) { idx in
            AppSettings.shared.editorFontFamily = ["mono","system","serif"][idx]
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
        addSlider("字号", value: s.editorFontSize, min: 10, max: 28, step: 1) { val in
            AppSettings.shared.editorFontSize = val
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
        addSlider("行间距", value: s.editorLineSpacing, min: 0, max: 20, step: 1) { val in
            AppSettings.shared.editorLineSpacing = val
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }

        addSection("行为")
        addToggle("自动换行", value: s.wordWrap) { val in
            AppSettings.shared.wordWrap = val
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
        addToggle("拼写检查", value: s.spellCheck) { val in
            AppSettings.shared.spellCheck = val
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
        addToggle("Markdown 语法高亮", value: s.markdownSyntaxHL) { val in
            AppSettings.shared.markdownSyntaxHL = val
        }

        addSection("自动保存")
        addToggle("启用自动保存", value: s.autoSaveEnabled) { val in
            AppSettings.shared.autoSaveEnabled = val
        }
        addSlider("自动保存延迟（秒）", value: s.autoSaveDelay, min: 0.2, max: 5.0, step: 0.1) { val in
            AppSettings.shared.autoSaveDelay = val
        }
    }
}

// MARK: - 外观设置
final class AppearancePrefsVC: PrefsBaseVC {
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "外观"

        let s = AppSettings.shared

        addSection("主题")
        addPopup("外观模式", options: ["跟随系统", "浅色", "深色"],
                 selected: ["auto","light","dark"].firstIndex(of: s.editorTheme) ?? 0) { idx in
            let themes = ["auto", "light", "dark"]
            AppSettings.shared.editorTheme = themes[idx]
            let appearances: [NSAppearance?] = [nil,
                NSAppearance(named: .aqua),
                NSAppearance(named: .darkAqua)]
            NSApp.appearance = appearances[idx]
        }

        addSection("预览")
        addSlider("预览字号", value: s.previewFontSize, min: 10, max: 28, step: 1) { val in
            AppSettings.shared.previewFontSize = val
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
        addToggle("显示预览面板", value: s.showPreviewPane) { val in
            AppSettings.shared.showPreviewPane = val
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }

        addSection("侧边栏")
        addSlider("侧边栏宽度", value: s.sidebarWidth, min: 160, max: 320, step: 10) { val in
            AppSettings.shared.sidebarWidth = val
        }

        // ── 颜色自定义 ────────────────────────────────────────
        addSection("预览颜色（留空则使用默认配色）")
        addLabel("颜色值格式：#RRGGBB，例如 #1A6FBD。留空则随深色/浅色模式自动切换。")

        let dark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let pal  = Palette(dark: dark)

        addColorPicker("H1 标题色", hex: s.colorH1,
                       placeholder: pal.h1.hexString) { hex in
            AppSettings.shared.colorH1 = hex
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
        addColorPicker("H2 标题色", hex: s.colorH2,
                       placeholder: pal.h2.hexString) { hex in
            AppSettings.shared.colorH2 = hex
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
        addColorPicker("H3 标题色", hex: s.colorH3,
                       placeholder: pal.h3.hexString) { hex in
            AppSettings.shared.colorH3 = hex
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
        addColorPicker("H4 标题色", hex: s.colorH4,
                       placeholder: pal.h4.hexString) { hex in
            AppSettings.shared.colorH4 = hex
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
        addColorPicker("正文颜色",  hex: s.colorBody,
                       placeholder: pal.text.hexString) { hex in
            AppSettings.shared.colorBody = hex
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
        addColorPicker("链接颜色",  hex: s.colorLink,
                       placeholder: pal.link.hexString) { hex in
            AppSettings.shared.colorLink = hex
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
        addColorPicker("行内代码色", hex: s.colorCode,
                       placeholder: pal.inlineCode.hexString) { hex in
            AppSettings.shared.colorCode = hex
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
        addButton("重置为默认颜色") {
            AppSettings.shared.colorH1   = ""
            AppSettings.shared.colorH2   = ""
            AppSettings.shared.colorH3   = ""
            AppSettings.shared.colorH4   = ""
            AppSettings.shared.colorBody = ""
            AppSettings.shared.colorLink = ""
            AppSettings.shared.colorCode = ""
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
            // 刷新页面
            self.viewDidLoad()
        }
    }
}

// MARK: - 快捷键设置
final class HotkeyPrefsVC: PrefsBaseVC {

    // 录制状态下的监控器
    private var monitor: Any?
    // 录制按钮引用（用于更新标题）
    private weak var recordButton: NSButton?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "快捷键"
        stopRecording()   // 确保监控器清理

        // ── 全局热键（可录制）────────────────────────────
        addSection("全局快捷键")
        addLabel("点击下方按钮后，按下想要的组合键即可设置。\n需包含 ⌃/⌥/⌘ 中至少一个修饰键。")

        // 当前值
        let currentStr = HotKeyManager.currentShortcutString()

        // 录制按钮
        let btn = NSButton(title: "当前：\(currentStr)　　点击录制...", target: self,
                           action: #selector(toggleRecording(_:)))
        btn.bezelStyle     = .rounded
        btn.setButtonType(.momentaryPushIn)
        btn.font           = .monospacedSystemFont(ofSize: 14, weight: .medium)
        btn.toolTip        = "点击后按下目标组合键"
        callbacks.append(btn)   // 持有引用防止 ARC 回收
        recordButton = btn
        addArrangedButton(btn)

        // 重置默认
        addButton("恢复默认（⌃⌥Z）") { [weak self] in
            AppSettings.shared.hotKeyModifiers = Int(controlKey | optionKey)
            AppSettings.shared.hotKeyCode      = kVK_ANSI_Z
            HotKeyManager.shared.register()
            self?.viewDidLoad()
        }

        // ── 编辑器内置快捷键（只读说明）────────────────────
        addSection("编辑器内置快捷键")
        let rows: [(String, String)] = [
            ("⌘S",   "手动保存"),
            ("⌘N",   "新建备忘录"),
            ("⌘K",   "插入超链接"),
            ("⌘F",   "全文查找"),
            ("⌘Z",   "撤销"),
            ("⇧⌘Z",  "重做"),
            ("⌘W",   "关闭窗口"),
        ]
        for (key, desc) in rows {
            addShortcutRow(key: key, desc: desc)
        }
    }

    // ── 开始/停止录制 ────────────────────────────────────
    @objc private func toggleRecording(_ sender: NSButton) {
        if monitor != nil {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        recordButton?.title = "⏺ 请按下组合键..."
        recordButton?.bezelColor = .systemBlue

        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }

            let mods  = event.modifierFlags.intersection([.control, .option, .command, .shift])
            let code  = Int(event.keyCode)

            // 必须有至少一个修饰键，且不是单独的修饰键
            guard !mods.isEmpty,
                  ![kVK_Control, kVK_Option, kVK_Command, kVK_Shift,
                    kVK_RightControl, kVK_RightOption, kVK_RightCommand, kVK_RightShift
                   ].contains(code) else {
                return nil   // 吞掉，继续等待
            }

            // 保存
            let carbonMods = HotKeyManager.carbonModifiers(from: mods)
            AppSettings.shared.hotKeyModifiers = carbonMods
            AppSettings.shared.hotKeyCode      = code
            HotKeyManager.shared.register()    // 立即生效

            self.stopRecording()
            self.viewDidLoad()                 // 刷新显示
            return nil
        }
    }

    private func stopRecording() {
        if let m = monitor {
            NSEvent.removeMonitor(m)
            monitor = nil
        }
        recordButton?.bezelColor = nil
    }

    // ── 辅助：只读快捷键行 ───────────────────────────────
    private func addShortcutRow(key: String, desc: String) {
        addCustomRow {
            let lbl = NSTextField(labelWithString: desc)
            lbl.font      = .systemFont(ofSize: 13)
            lbl.textColor = .labelColor
            lbl.setContentHuggingPriority(.defaultLow, for: .horizontal)

            let badge = NSTextField(labelWithString: key)
            badge.font            = .monospacedSystemFont(ofSize: 12, weight: .medium)
            badge.textColor       = .secondaryLabelColor
            badge.backgroundColor = .quaternaryLabelColor
            badge.drawsBackground = true
            badge.isBezeled       = false
            badge.alignment       = .center
            badge.setContentHuggingPriority(.required, for: .horizontal)

            // 给 badge 加圆角（用 layer）
            badge.wantsLayer  = true
            badge.layer?.cornerRadius = 4
            return (lbl, badge)
        }
    }
}

// MARK: - PrefsBaseVC 扩展：支持自定义行 & 直接添加控件
extension PrefsBaseVC {
    /// 添加任意 NSButton（不走 ButtonCallback 包装）
    func addArrangedButton(_ btn: NSButton) {
        stackView.addArrangedSubview(btn)
    }

    /// 添加自定义双列行（左侧弹性 label + 右侧固定控件）
    func addCustomRow(_ build: () -> (NSView, NSView)) {
        let (left, right) = build()
        let row = NSStackView()
        row.orientation  = .horizontal
        row.distribution = .fill
        row.alignment    = .centerY
        row.spacing      = 12
        row.addView(left,  in: .leading)
        row.addView(right, in: .trailing)
        stackView.addArrangedSubview(row)
        let wc = row.widthAnchor.constraint(equalTo: stackView.widthAnchor, constant: -48)
        wc.priority = .defaultHigh
        wc.isActive = true
    }
}

// MARK: - 存储设置
final class StoragePrefsVC: PrefsBaseVC {
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "存储"

        let s = AppSettings.shared

        addSection("保存位置")
        let currentPath = s.saveDirectory ?? s.effectiveSaveURL.path
        addLabel("当前路径：\(currentPath)")
        addButton("选择存储目录...") { [weak self] in
            let panel = NSOpenPanel()
            panel.canChooseDirectories = true
            panel.canChooseFiles       = false
            panel.allowsMultipleSelection = false
            panel.prompt = "选择"
            if panel.runModal() == .OK, let url = panel.url {
                AppSettings.shared.saveDirectory = url.path
                NotificationCenter.default.post(name: .settingsChanged, object: nil)
                self?.viewDidLoad() // 刷新
            }
        }
        addButton("恢复默认路径") { [weak self] in
            AppSettings.shared.saveDirectory = nil
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
            self?.viewDidLoad()
        }

        addSection("备份")
        addToggle("启用自动备份", value: false, key: "autoBackup") { _ in }
        addLabel("备份文件保存在存储目录下的 backups/ 文件夹中。")
    }
}

// MARK: - 导出设置
final class ExportPrefsVC: PrefsBaseVC {
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "导出"

        addSection("默认导出格式")
        addPopup("格式", options: ["Markdown (.md)", "纯文本 (.txt)", "HTML (.html)"], selected: 0) { _ in }

        addSection("导出目录")
        let current = AppSettings.shared.exportDirectory ?? NSHomeDirectory() + "/Desktop"
        addLabel("当前：\(current)")
        addButton("选择导出目录...") { [weak self] in
            let panel = NSOpenPanel()
            panel.canChooseDirectories = true
            panel.canChooseFiles = false
            panel.prompt = "选择"
            if panel.runModal() == .OK, let url = panel.url {
                AppSettings.shared.exportDirectory = url.path
                self?.viewDidLoad()
            }
        }

        addSection("批量导出")
        addButton("导出全部备忘录为 Markdown...") {
            ExportHelper.exportAll()
        }
    }
}

// MARK: - 导出帮助
enum ExportHelper {
    static func exportAll() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.prompt = "导出到此文件夹"
        guard panel.runModal() == .OK, let dir = panel.url else { return }

        let memos = DataStore.shared.memos
        var count = 0
        for memo in memos {
            let name = memo.displayTitle
                .replacingOccurrences(of: "/", with: "-")
                .replacingOccurrences(of: ":", with: "-")
            let url = dir.appendingPathComponent("\(name).md")
            try? memo.content.write(to: url, atomically: true, encoding: .utf8)
            count += 1
        }
        let alert = NSAlert()
        alert.messageText = "导出完成"
        alert.informativeText = "共导出 \(count) 条备忘录到 \(dir.path)"
        alert.runModal()
    }
}

// MARK: - 翻转坐标系容器（让 NSScrollView 从顶部开始排列）
private final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

// MARK: - 基础偏好设置视图控制器
class PrefsBaseVC: NSViewController {

    var stackView  = NSStackView()   // internal：供子类/extension 访问
    private var scrollView = NSScrollView()
    private var container  = FlippedView()   // 翻转容器
    var callbacks: [Any] = []

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 540, height: 440))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.subviews.forEach { $0.removeFromSuperview() }
        callbacks.removeAll()

        // ── ScrollView ────────────────────────────────
        scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers  = true
        scrollView.borderType          = .noBorder
        scrollView.drawsBackground     = false
        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        // ── 翻转容器（documentView）──────────────────
        container = FlippedView()
        container.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = container

        // container 宽度=scrollView宽度，高度自适应（>=scrollView高度）
        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            container.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            // 让 container 至少和 scrollView 一样高（防止内容少时浮在中间）
            container.heightAnchor.constraint(greaterThanOrEqualTo: scrollView.contentView.heightAnchor),
        ])

        // ── StackView（放在翻转容器内）───────────────
        stackView = NSStackView()
        stackView.orientation  = .vertical
        stackView.alignment    = .leading
        stackView.spacing      = 10
        stackView.edgeInsets   = NSEdgeInsets(top: 20, left: 24, bottom: 24, right: 24)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: container.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            // 底部至少到 container 底部（内容撑开）
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor),
        ])
    }

    // ── DSL 帮助方法 ──────────────────────────────

    func addSection(_ title: String) {
        let label = NSTextField(labelWithString: title.uppercased())
        label.font      = .systemFont(ofSize: 10, weight: .semibold)
        label.textColor = .secondaryLabelColor
        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.heightAnchor.constraint(equalToConstant: 8).isActive = true
        stackView.addArrangedSubview(spacer)
        stackView.addArrangedSubview(label)
    }

    func addToggle(_ title: String, value: Bool, key: String = "", _ onChange: @escaping (Bool) -> Void) {
        let row = makeRow()
        let lbl = NSTextField(labelWithString: title)
        lbl.font      = .systemFont(ofSize: 13)
        lbl.textColor = .labelColor
        let toggle = NSSwitch()
        toggle.state = value ? .on : .off
        let cb = ToggleCallback(onChange: onChange)
        callbacks.append(cb)
        toggle.target = cb
        toggle.action = #selector(ToggleCallback.changed(_:))
        row.addView(lbl,    in: .leading)
        row.addView(toggle, in: .trailing)
        stackView.addArrangedSubview(row)
        row.widthAnchor.constraint(equalTo: stackView.widthAnchor, constant: -48).isActive = true
    }

    func addSlider(_ title: String, value: Double, min: Double, max: Double, step: Double, _ onChange: @escaping (Double) -> Void) {
        let row = makeRow()
        let lbl = NSTextField(labelWithString: title)
        lbl.font      = .systemFont(ofSize: 13)
        lbl.textColor = .labelColor
        lbl.setContentHuggingPriority(.defaultHigh, for: .horizontal)

        let valLabel = NSTextField(labelWithString: String(format: "%.0f", value))
        valLabel.font      = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        valLabel.textColor = .secondaryLabelColor
        valLabel.widthAnchor.constraint(equalToConstant: 36).isActive = true

        let slider = NSSlider(value: value, minValue: min, maxValue: max, target: nil, action: nil)
        slider.numberOfTickMarks = 0
        let cb = SliderCallback(valueLabel: valLabel, onChange: onChange)
        callbacks.append(cb)
        slider.target = cb
        slider.action = #selector(SliderCallback.changed(_:))

        row.addView(lbl,      in: .leading)
        row.addView(slider,   in: .center)
        row.addView(valLabel, in: .trailing)
        stackView.addArrangedSubview(row)
        row.widthAnchor.constraint(equalTo: stackView.widthAnchor, constant: -48).isActive = true
    }

    func addPopup(_ title: String, options: [String], selected: Int, _ onChange: @escaping (Int) -> Void) {
        let row = makeRow()
        let lbl = NSTextField(labelWithString: title)
        lbl.font      = .systemFont(ofSize: 13)
        lbl.textColor = .labelColor
        let popup = NSPopUpButton(frame: .zero, pullsDown: false)
        popup.addItems(withTitles: options)
        popup.selectItem(at: selected)
        let cb = PopupCallback(onChange: onChange)
        callbacks.append(cb)
        popup.target = cb
        popup.action = #selector(PopupCallback.changed(_:))
        row.addView(lbl,   in: .leading)
        row.addView(popup, in: .trailing)
        stackView.addArrangedSubview(row)
        row.widthAnchor.constraint(equalTo: stackView.widthAnchor, constant: -48).isActive = true
    }

    func addTextField(_ title: String, value: String, _ onChange: @escaping (String) -> Void) {
        let row = makeRow()
        let lbl = NSTextField(labelWithString: title)
        lbl.font      = .systemFont(ofSize: 13)
        lbl.textColor = .labelColor
        let field = NSTextField(string: value)
        field.font           = .systemFont(ofSize: 13)
        field.bezelStyle     = .roundedBezel
        field.controlSize    = .small
        field.widthAnchor.constraint(equalToConstant: 200).isActive = true
        let cb = TextFieldCallback(onChange: onChange)
        callbacks.append(cb)
        field.delegate = cb
        row.addView(lbl,   in: .leading)
        row.addView(field, in: .trailing)
        stackView.addArrangedSubview(row)
        row.widthAnchor.constraint(equalTo: stackView.widthAnchor, constant: -48).isActive = true
    }

    func addLabel(_ text: String) {
        let lbl = NSTextField(wrappingLabelWithString: text)
        lbl.font          = .systemFont(ofSize: 12)
        lbl.textColor     = .secondaryLabelColor
        lbl.lineBreakMode = .byWordWrapping
        stackView.addArrangedSubview(lbl)
        lbl.widthAnchor.constraint(equalTo: stackView.widthAnchor, constant: -48).isActive = true
    }

    func addButton(_ title: String, _ action: @escaping () -> Void) {
        let btn = NSButton(title: title, target: nil, action: nil)
        btn.bezelStyle = .rounded
        let cb = ButtonCallback(action: action)
        callbacks.append(cb)
        btn.target = cb
        btn.action = #selector(ButtonCallback.tapped)
        stackView.addArrangedSubview(btn)
    }

    /// 颜色选择行：左边标签 + 右边 hex 文本框 + 颜色井（NSColorWell）
    func addColorPicker(_ title: String, hex: String, placeholder: String,
                        _ onChange: @escaping (String) -> Void) {
        let row = makeRow()
        row.distribution = .fill   // 让标签自动填满剩余空间

        let lbl = NSTextField(labelWithString: title)
        lbl.font      = .systemFont(ofSize: 13)
        lbl.textColor = .labelColor
        // 标签可压缩，不强制撑宽
        lbl.setContentHuggingPriority(.defaultLow,  for: .horizontal)
        lbl.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        // Hex 文本框（固定宽度，不参与拉伸）
        let field = NSTextField(string: hex)
        field.font              = .monospacedSystemFont(ofSize: 12, weight: .regular)
        field.placeholderString = placeholder
        field.bezelStyle        = .roundedBezel
        field.controlSize       = .small
        field.setContentHuggingPriority(.required, for: .horizontal)
        field.setContentCompressionResistancePriority(.required, for: .horizontal)
        field.widthAnchor.constraint(equalToConstant: 90).isActive = true

        // 颜色井（固定尺寸）
        let well = NSColorWell(style: .minimal)
        well.color = NSColor.fromHex(hex) ?? NSColor.fromHex(placeholder) ?? .labelColor
        well.translatesAutoresizingMaskIntoConstraints = false
        well.setContentHuggingPriority(.required, for: .horizontal)
        well.setContentCompressionResistancePriority(.required, for: .horizontal)
        well.widthAnchor.constraint(equalToConstant: 32).isActive  = true
        well.heightAnchor.constraint(equalToConstant: 24).isActive = true

        let cb = ColorPickerCallback(well: well, field: field, onChange: onChange)
        callbacks.append(cb)
        well.target  = cb
        well.action  = #selector(ColorPickerCallback.wellChanged(_:))
        field.delegate = cb

        row.addView(lbl,   in: .leading)
        row.addView(field, in: .trailing)
        row.addView(well,  in: .trailing)
        stackView.addArrangedSubview(row)
        // 与其他行保持一致：行宽 = stackView 宽度 - 左右 padding（各 24pt）
        // 优先级设为 defaultHigh（<required），让固定宽度控件优先，标签弹性压缩
        let wc = row.widthAnchor.constraint(equalTo: stackView.widthAnchor, constant: -48)
        wc.priority = .defaultHigh
        wc.isActive = true
    }

    private func makeRow() -> NSStackView {
        let row = NSStackView()
        row.orientation  = .horizontal
        row.distribution = .fillProportionally
        row.alignment    = .centerY
        row.spacing      = 12
        return row
    }
}

// MARK: - 回调包装（防止 closure 泄漏）
final class ToggleCallback: NSObject {
    let onChange: (Bool) -> Void
    init(onChange: @escaping (Bool) -> Void) { self.onChange = onChange }
    @objc func changed(_ sender: NSSwitch) { onChange(sender.state == .on) }
}
final class SliderCallback: NSObject {
    let onChange: (Double) -> Void
    let valueLabel: NSTextField
    init(valueLabel: NSTextField, onChange: @escaping (Double) -> Void) {
        self.valueLabel = valueLabel
        self.onChange   = onChange
    }
    @objc func changed(_ sender: NSSlider) {
        valueLabel.stringValue = String(format: "%.0f", sender.doubleValue)
        onChange(sender.doubleValue)
    }
}
final class PopupCallback: NSObject {
    let onChange: (Int) -> Void
    init(onChange: @escaping (Int) -> Void) { self.onChange = onChange }
    @objc func changed(_ sender: NSPopUpButton) { onChange(sender.indexOfSelectedItem) }
}
final class TextFieldCallback: NSObject, NSTextFieldDelegate {
    let onChange: (String) -> Void
    init(onChange: @escaping (String) -> Void) { self.onChange = onChange }
    func controlTextDidChange(_ obj: Notification) {
        guard let f = obj.object as? NSTextField else { return }
        onChange(f.stringValue)
    }
    func controlTextDidEndEditing(_ obj: Notification) {
        guard let f = obj.object as? NSTextField else { return }
        onChange(f.stringValue)
    }
}
final class ButtonCallback: NSObject {
    let action: () -> Void
    init(action: @escaping () -> Void) { self.action = action }
    @objc func tapped() { action() }
}

/// 颜色井 + Hex 文本框联动回调
final class ColorPickerCallback: NSObject, NSTextFieldDelegate {
    private weak var well:  NSColorWell?
    private weak var field: NSTextField?
    let onChange: (String) -> Void

    init(well: NSColorWell, field: NSTextField, onChange: @escaping (String) -> Void) {
        self.well     = well
        self.field    = field
        self.onChange = onChange
    }

    /// 颜色井改变 → 同步到文本框
    @objc func wellChanged(_ sender: NSColorWell) {
        let hex = sender.color.hexString
        field?.stringValue = hex
        onChange(hex)
    }

    /// 文本框改变 → 同步到颜色井
    func controlTextDidEndEditing(_ obj: Notification) {
        guard let f = obj.object as? NSTextField else { return }
        let hex = f.stringValue.trimmingCharacters(in: .whitespaces)
        if hex.isEmpty {
            onChange("")
        } else if let c = NSColor.fromHex(hex) {
            well?.color = c
            onChange(hex)
        }
    }
}

// MARK: - Notification
extension Notification.Name {
    static let settingsChanged = Notification.Name("MemoAppSettingsChanged")
    static let saveStatusChanged = Notification.Name("MemoAppSaveStatusChanged")
    static let manualSave = Notification.Name("MemoAppManualSave")
}
