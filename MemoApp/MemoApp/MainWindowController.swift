import AppKit
import Foundation

// MARK: - 主窗口控制器
final class MainWindowController: NSWindowController, NSToolbarDelegate {

    static weak var current: MainWindowController?

    private let idAlwaysOnTop = NSToolbarItem.Identifier("alwaysOnTop")
    private let idSaveStatus  = NSToolbarItem.Identifier("saveStatus")
    private let idWordCount   = NSToolbarItem.Identifier("wordCount")
    private let idNewMemo     = NSToolbarItem.Identifier("newMemo")
    private let idPreferences = NSToolbarItem.Identifier("preferences")
    private let idExport      = NSToolbarItem.Identifier("export")

    let pinButton       = NSButton()
    let saveStatusDot   = NSView()
    let saveStatusLabel = NSTextField()
    let wordCountLabel  = NSTextField()

    private(set) var isPinned = false {
        didSet { applyPin() }
    }

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .unifiedTitleAndToolbar],
            backing: .buffered,
            defer: false
        )
        window.title   = "备忘录"
        window.minSize = NSSize(width: 700, height: 450)
        window.center()
        window.setFrameAutosaveName("MemoMainWindow")
        window.appearance = nil

        self.init(window: window)
        MainWindowController.current = self

        let toolbar = NSToolbar(identifier: "MainToolbar")
        toolbar.delegate                = self
        toolbar.displayMode             = .iconOnly
        toolbar.allowsUserCustomization = false
        toolbar.showsBaselineSeparator  = true
        window.toolbar = toolbar

        window.contentViewController = RootSplitViewController()

        NotificationCenter.default.addObserver(self, selector: #selector(onSaveStatusChanged(_:)),
            name: .saveStatusChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onSettingsChanged),
            name: .settingsChanged, object: nil)
    }

    func showAndFocus() {
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - 置顶
    private func applyPin() {
        window?.level = isPinned ? .floating : .normal
        let name = isPinned ? "pin.fill" : "pin"
        pinButton.image            = NSImage(systemSymbolName: name, accessibilityDescription: nil)
        pinButton.contentTintColor = isPinned ? .controlAccentColor : .secondaryLabelColor
        pinButton.toolTip          = isPinned ? "取消置顶" : "置顶窗口"
    }

    @objc private func togglePin() { isPinned.toggle() }

    // MARK: - 保存状态
    func updateSaveStatus(saved: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let color: NSColor = saved ? .systemGreen : .systemRed
            self.saveStatusDot.layer?.backgroundColor = color.cgColor
            self.saveStatusLabel.stringValue          = saved ? "已保存" : "未保存"
            self.saveStatusLabel.textColor            = color
        }
    }

    @objc private func onSaveStatusChanged(_ note: Notification) {
        updateSaveStatus(saved: note.userInfo?["saved"] as? Bool ?? true)
    }

    // MARK: - 字数
    func updateWordCount(_ text: String) {
        let words = text.split { $0.isWhitespace }.count
        wordCountLabel.stringValue = AppSettings.shared.showWordCount
            ? "\(text.count) 字 · \(words) 词"
            : ""
    }

    @objc private func onSettingsChanged() {
        if !AppSettings.shared.showWordCount { wordCountLabel.stringValue = "" }
    }

    // MARK: - Actions
    @objc func openPreferences() { PreferencesWindowController.shared.show() }

    @objc private func exportCurrent() {
        guard let root = window?.contentViewController as? RootSplitViewController,
              let memo = root.mainVC.currentMemo else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes  = [.init(filenameExtension: "md")!]
        panel.nameFieldStringValue = memo.displayTitle + ".md"
        if panel.runModal() == .OK, let url = panel.url {
            try? memo.content.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    @objc private func newMemoToolbar() {
        guard let root = window?.contentViewController as? RootSplitViewController else { return }
        var store = DataStore.shared
        root.mainVC.createNewMemo(store: &store)
        DataStore.shared = store
        root.sidebarVC.reload(memos: DataStore.shared.memos)
        if let first = DataStore.shared.memos.first {
            root.sidebarVC.selectMemo(first)
            root.mainVC.load(memo: first)
        }
    }

    // MARK: - NSToolbarDelegate
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [idSaveStatus, .flexibleSpace, idWordCount, .flexibleSpace,
         idNewMemo, idExport, idPreferences, idAlwaysOnTop]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar) + [.space]
    }

    func toolbar(_ toolbar: NSToolbar,
                 itemForItemIdentifier id: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {

        func iconBtn(_ sf: String, tooltip: String, action: Selector) -> NSButton {
            let b = NSButton()
            b.image            = NSImage(systemSymbolName: sf, accessibilityDescription: tooltip)
            b.bezelStyle       = .texturedRounded
            b.isBordered       = true
            b.toolTip          = tooltip
            b.target           = self
            b.action           = action
            b.widthAnchor.constraint(equalToConstant: 32).isActive  = true
            b.heightAnchor.constraint(equalToConstant: 28).isActive = true
            return b
        }

        let item = NSToolbarItem(itemIdentifier: id)

        switch id {

        // ── 置顶 ──────────────────────────────────
        case idAlwaysOnTop:
            pinButton.image            = NSImage(systemSymbolName: "pin", accessibilityDescription: "置顶")
            pinButton.bezelStyle       = .texturedRounded
            pinButton.isBordered       = true
            pinButton.contentTintColor = .secondaryLabelColor
            pinButton.target           = self
            pinButton.action           = #selector(togglePin)
            pinButton.toolTip          = "置顶窗口"
            pinButton.widthAnchor.constraint(equalToConstant: 32).isActive  = true
            pinButton.heightAnchor.constraint(equalToConstant: 28).isActive = true
            item.view    = pinButton
            item.label   = "置顶"
            item.toolTip = "置顶窗口"

        // ── 保存状态 ──────────────────────────────
        case idSaveStatus:
            // 外层固定尺寸容器（toolbar item 需要固定大小才能正确居中）
            let wrapper = NSView()
            wrapper.translatesAutoresizingMaskIntoConstraints = false
            wrapper.widthAnchor.constraint(equalToConstant: 80).isActive  = true
            wrapper.heightAnchor.constraint(equalToConstant: 32).isActive = true

            // 圆点
            saveStatusDot.wantsLayer          = true
            saveStatusDot.layer?.cornerRadius = 4
            saveStatusDot.layer?.backgroundColor = NSColor.systemGreen.cgColor
            saveStatusDot.translatesAutoresizingMaskIntoConstraints = false
            wrapper.addSubview(saveStatusDot)

            // 文字
            saveStatusLabel.isEditable      = false
            saveStatusLabel.isBordered      = false
            saveStatusLabel.backgroundColor = .clear
            saveStatusLabel.stringValue     = "已保存"
            saveStatusLabel.textColor       = .systemGreen
            saveStatusLabel.font            = .systemFont(ofSize: 11, weight: .medium)
            saveStatusLabel.translatesAutoresizingMaskIntoConstraints = false
            wrapper.addSubview(saveStatusLabel)

            NSLayoutConstraint.activate([
                // 圆点垂直居中，靠左
                saveStatusDot.widthAnchor.constraint(equalToConstant: 8),
                saveStatusDot.heightAnchor.constraint(equalToConstant: 8),
                saveStatusDot.centerYAnchor.constraint(equalTo: wrapper.centerYAnchor),
                saveStatusDot.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 8),
                // 文字紧跟圆点，垂直居中
                saveStatusLabel.centerYAnchor.constraint(equalTo: wrapper.centerYAnchor),
                saveStatusLabel.leadingAnchor.constraint(equalTo: saveStatusDot.trailingAnchor, constant: 5),
                saveStatusLabel.trailingAnchor.constraint(lessThanOrEqualTo: wrapper.trailingAnchor, constant: -4),
            ])

            item.view    = wrapper
            item.label   = "状态"
            item.toolTip = "保存状态（⌘S 手动保存）"

        // ── 字数统计 ──────────────────────────────
        case idWordCount:
            wordCountLabel.isEditable      = false
            wordCountLabel.isBordered      = false
            wordCountLabel.backgroundColor = .clear
            wordCountLabel.stringValue     = ""
            wordCountLabel.textColor       = NSColor(red: 0.45, green: 0.82, blue: 0.55, alpha: 1.0) // 淡绿色
            wordCountLabel.font            = .systemFont(ofSize: 11)
            wordCountLabel.alignment       = .center
            wordCountLabel.widthAnchor.constraint(equalToConstant: 130).isActive = true
            item.view    = wordCountLabel
            item.label   = "字数"
            item.toolTip = "字数统计"

        // ── 新建 ──────────────────────────────────
        case idNewMemo:
            item.view    = iconBtn("square.and.pencil", tooltip: "新建备忘录 (⌘N)", action: #selector(newMemoToolbar))
            item.label   = "新建"
            item.toolTip = "新建备忘录"

        // ── 导出 ──────────────────────────────────
        case idExport:
            item.view    = iconBtn("square.and.arrow.up", tooltip: "导出当前备忘录", action: #selector(exportCurrent))
            item.label   = "导出"
            item.toolTip = "导出当前备忘录"

        // ── 偏好设置 ──────────────────────────────
        case idPreferences:
            item.view    = iconBtn("gearshape", tooltip: "偏好设置 (⌘,)", action: #selector(openPreferences))
            item.label   = "设置"
            item.toolTip = "偏好设置"

        default:
            return nil
        }
        return item
    }
}

// MARK: - 根分割视图控制器
final class RootSplitViewController: NSSplitViewController {

    let sidebarVC = SidebarViewController()
    let mainVC    = MainViewController()

    override func viewDidLoad() {
        super.viewDidLoad()
        splitView.isVertical   = true
        splitView.dividerStyle = .thin
        splitView.autosaveName = "RootSplit"

        let sideItem = NSSplitViewItem(viewController: sidebarVC)
        sideItem.minimumThickness          = 200
        sideItem.maximumThickness          = 300
        sideItem.preferredThicknessFraction = 0.22
        addSplitViewItem(sideItem)

        let mainItem = NSSplitViewItem(viewController: mainVC)
        mainItem.minimumThickness = 450
        addSplitViewItem(mainItem)

        wireCalls()

        let memos = DataStore.shared.memos
        sidebarVC.reload(memos: memos)
        if let first = memos.first {
            sidebarVC.selectMemo(first)
            mainVC.load(memo: first)
        }
    }

    private func wireCalls() {
        sidebarVC.onSelect = { [weak self] memo in self?.mainVC.load(memo: memo) }

        sidebarVC.onNew = { [weak self] in
            guard let self else { return }
            var store = DataStore.shared
            self.mainVC.createNewMemo(store: &store)
            DataStore.shared = store
            self.sidebarVC.reload(memos: DataStore.shared.memos)
            if let first = DataStore.shared.memos.first {
                self.sidebarVC.selectMemo(first)
                self.mainVC.load(memo: first)
            }
        }

        sidebarVC.onDelete = { [weak self] memo in
            guard let self else { return }
            self.mainVC.confirmDelete(memo) {
                DataStore.shared.remove(memo)
                self.sidebarVC.reload(memos: DataStore.shared.memos)
                if let first = DataStore.shared.memos.first {
                    self.sidebarVC.selectMemo(first)
                    self.mainVC.load(memo: first)
                } else {
                    self.mainVC.clearEditor()
                }
            }
        }

        mainVC.onContentChange = { [weak self] memo in
            DataStore.shared.update(memo)
            self?.sidebarVC.reload(memos: DataStore.shared.memos)
            self?.sidebarVC.selectMemo(memo)
        }
    }

    func openMostRecent() {
        let memos = DataStore.shared.memos
        if let first = memos.first {
            sidebarVC.selectMemo(first)
            mainVC.load(memo: first)
        } else {
            var store = DataStore.shared
            mainVC.createNewMemo(store: &store)
            DataStore.shared = store
            sidebarVC.reload(memos: DataStore.shared.memos)
            if let first = DataStore.shared.memos.first {
                sidebarVC.selectMemo(first)
                mainVC.load(memo: first)
            }
        }
        view.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - 数据中心
struct DataStore {
    static var shared = DataStore()

    private(set) var memos: [Memo] = {
        var list = MemoStore.shared.load()
        list.sort { $0.updatedAt > $1.updatedAt }
        return list
    }()

    mutating func add(_ memo: Memo) {
        memos.insert(memo, at: 0)
        save()
    }

    mutating func update(_ memo: Memo) {
        if let idx = memos.firstIndex(where: { $0.id == memo.id }) {
            memos[idx] = memo
            memos.sort { $0.updatedAt > $1.updatedAt }
        }
        save()
    }

    mutating func remove(_ memo: Memo) {
        memos.removeAll { $0.id == memo.id }
        save()
    }

    private func save() { MemoStore.shared.save(memos) }
}

// MARK: - 主区视图控制器（编辑 ｜ 预览）
final class MainViewController: NSViewController {

    var onContentChange: ((Memo) -> Void)?
    private(set) var currentMemo: Memo?
    private var saveTimer: Timer?
    private var isDirty = false

    private let splitVC   = NSSplitViewController()
    private let editorVC  = EditorViewController()
    private let previewVC = PreviewViewController()

    override func loadView() { view = NSView() }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupSplit()

        // ⌘S 手动保存
        NotificationCenter.default.addObserver(self, selector: #selector(manualSave),
            name: .manualSave, object: nil)
    }

    private func setupSplit() {
        addChild(splitVC)
        splitVC.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(splitVC.view)
        NSLayoutConstraint.activate([
            splitVC.view.topAnchor.constraint(equalTo: view.topAnchor),
            splitVC.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            splitVC.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            splitVC.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        splitVC.splitView.isVertical   = true
        splitVC.splitView.dividerStyle = .thin
        splitVC.splitView.autosaveName = "EditorPreviewSplit"

        let edItem = NSSplitViewItem(viewController: editorVC)
        edItem.minimumThickness = 220
        splitVC.addSplitViewItem(edItem)

        let pvItem = NSSplitViewItem(viewController: previewVC)
        pvItem.minimumThickness = 220
        splitVC.addSplitViewItem(pvItem)

        editorVC.onTextChange = { [weak self] text in
            guard let self, var memo = self.currentMemo else { return }
            memo.content   = text
            memo.updatedAt = Date()
            self.currentMemo = memo
            self.previewVC.render(text)
            self.setDirty(true)

            // 字数更新
            MainWindowController.current?.updateWordCount(text)

            // 防抖自动保存
            let delay = AppSettings.shared.autoSaveEnabled ? AppSettings.shared.autoSaveDelay : 999
            self.saveTimer?.invalidate()
            self.saveTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
                self?.autoSave()
            }
        }
    }

    private func setDirty(_ dirty: Bool) {
        isDirty = dirty
        NotificationCenter.default.post(name: .saveStatusChanged, object: nil,
            userInfo: ["saved": !dirty])
        MainWindowController.current?.updateSaveStatus(saved: !dirty)
    }

    private func autoSave() {
        guard let memo = currentMemo else { return }
        onContentChange?(memo)
        setDirty(false)
    }

    @objc func manualSave() {
        saveTimer?.invalidate()
        autoSave()
    }

    func load(memo: Memo) {
        saveTimer?.invalidate()
        currentMemo = memo
        editorVC.setText(memo.content)
        previewVC.render(memo.content)
        setDirty(false)
        MainWindowController.current?.updateWordCount(memo.content)
        view.window?.title = memo.displayTitle.isEmpty ? "备忘录" : memo.displayTitle
    }

    func clearEditor() {
        currentMemo = nil
        editorVC.setText("")
        previewVC.render("")
        setDirty(false)
        MainWindowController.current?.updateWordCount("")
        view.window?.title = "备忘录"
    }

    func createNewMemo(store: inout DataStore) {
        let memo = Memo(content: "")
        store.add(memo)
        currentMemo = memo
        editorVC.setText("")
        previewVC.render("")
        setDirty(false)
        DispatchQueue.main.async { [weak self] in self?.editorVC.focus() }
    }

    func confirmDelete(_ memo: Memo, completion: @escaping () -> Void) {
        guard AppSettings.shared.confirmDelete else { completion(); return }
        let alert = NSAlert()
        alert.messageText     = "删除备忘录"
        alert.informativeText = "确定要删除「\(memo.displayTitle)」吗？"
        alert.addButton(withTitle: "删除")
        alert.addButton(withTitle: "取消")
        alert.alertStyle = .warning
        guard let window = view.window else { return }
        alert.beginSheetModal(for: window) { resp in
            if resp == .alertFirstButtonReturn { completion() }
        }
    }
}

// MARK: - 编辑器视图控制器
final class EditorViewController: NSViewController {

    var onTextChange: ((String) -> Void)?

    private let scrollView = NSScrollView()
    private let textView   = MemoTextView()

    override func loadView() { view = NSView() }
    override func viewDidLoad() { super.viewDidLoad(); buildUI() }

    private func buildUI() {
        let s   = AppSettings.shared
        let font = editorFont(s)
        let bg  = NSColor.textBackgroundColor

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller   = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers    = true
        scrollView.borderType            = .noBorder
        scrollView.backgroundColor       = bg
        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        textView.minSize              = .zero
        textView.maxSize              = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable   = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask        = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

        textView.isEditable   = true
        textView.isSelectable = true
        textView.isRichText   = false
        textView.allowsUndo   = true
        textView.usesFindPanel = true

        let ps = paragraphStyle(s)
        textView.font                  = font
        textView.textColor             = .labelColor
        textView.backgroundColor       = bg
        textView.defaultParagraphStyle = ps
        textView.typingAttributes      = [.font: font, .foregroundColor: NSColor.labelColor, .paragraphStyle: ps]
        textView.textContainerInset    = NSSize(width: 28, height: 24)

        // 根据设置控制拼写
        textView.isContinuousSpellCheckingEnabled    = s.spellCheck
        textView.isGrammarCheckingEnabled            = s.spellCheck
        textView.isAutomaticQuoteSubstitutionEnabled  = false
        textView.isAutomaticDashSubstitutionEnabled   = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.smartInsertDeleteEnabled             = false
        textView.isAutomaticTextCompletionEnabled     = false
        textView.isAutomaticLinkDetectionEnabled      = false

        scrollView.documentView = textView
        textView.onTextChange   = { [weak self] text in self?.onTextChange?(text) }

        // 监听设置变化，刷新样式
        NotificationCenter.default.addObserver(self, selector: #selector(applySettings),
            name: .settingsChanged, object: nil)
    }

    @objc private func applySettings() {
        let s  = AppSettings.shared
        let f  = editorFont(s)
        let ps = paragraphStyle(s)
        textView.font            = f
        textView.defaultParagraphStyle = ps
        textView.typingAttributes = [.font: f, .foregroundColor: NSColor.labelColor, .paragraphStyle: ps]
        textView.isContinuousSpellCheckingEnabled = s.spellCheck
        // 刷新现有文字
        if let storage = textView.textStorage, storage.length > 0 {
            storage.addAttributes([.font: f, .paragraphStyle: ps], range: NSRange(location: 0, length: storage.length))
        }
    }

    private func editorFont(_ s: AppSettings) -> NSFont {
        let size = CGFloat(s.editorFontSize)
        switch s.editorFontFamily {
        case "system": return .systemFont(ofSize: size)
        case "serif":  return NSFont(name: "Georgia", size: size) ?? .systemFont(ofSize: size)
        default:       return .monospacedSystemFont(ofSize: size, weight: .regular)
        }
    }

    private func paragraphStyle(_ s: AppSettings) -> NSMutableParagraphStyle {
        let ps = NSMutableParagraphStyle()
        ps.lineSpacing      = CGFloat(s.editorLineSpacing)
        ps.paragraphSpacing = 2
        return ps
    }

    func setText(_ text: String) {
        let s  = AppSettings.shared
        let f  = editorFont(s)
        let ps = paragraphStyle(s)
        textView.string           = text
        textView.typingAttributes = [.font: f, .foregroundColor: NSColor.labelColor, .paragraphStyle: ps]
        if let storage = textView.textStorage, storage.length > 0 {
            storage.addAttributes([.font: f, .foregroundColor: NSColor.labelColor, .paragraphStyle: ps],
                                  range: NSRange(location: 0, length: storage.length))
        }
        textView.scrollToBeginningOfDocument(nil)
    }

    func focus() { view.window?.makeFirstResponder(textView) }
}

// MARK: - 自定义 TextView（⌘S + 图片粘贴/拖拽支持）
final class MemoTextView: NSTextView {
    var onTextChange: ((String) -> Void)?

    override func didChangeText() {
        super.didChangeText()
        onTextChange?(string)
    }

    override func insertTab(_ sender: Any?) {
        insertText("    ", replacementRange: selectedRange())
    }

    // ⌘S → 发出 manualSave 通知；⌘K → 插入超链接
    override func keyDown(with event: NSEvent) {
        let cmd = event.modifierFlags.contains(.command)
        switch (cmd, event.characters) {
        case (true, "s"):
            NotificationCenter.default.post(name: .manualSave, object: nil)
        case (true, "k"):
            insertLinkDialog()
        default:
            super.keyDown(with: event)
        }
    }

    // ── ⌘K：弹出超链接输入面板 ────────────────────────────
    private func insertLinkDialog() {
        // 记录当前选中的文本作为链接文字预填
        let selRange  = selectedRange()
        let selText   = (string as NSString).substring(with: selRange)

        // ── 构造 Alert 面板 ──
        let alert = NSAlert()
        alert.messageText    = "插入超链接"
        alert.addButton(withTitle: "插入")
        alert.addButton(withTitle: "取消")

        // 容器 View（两行输入框）
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 76))

        // 链接地址（上方）
        let urlField = NSTextField(frame: NSRect(x: 0, y: 40, width: 320, height: 28))
        urlField.placeholderString = "https://"
        urlField.stringValue       = ""
        urlField.bezelStyle        = .roundedBezel

        // 链接文字（下方）
        let textField = NSTextField(frame: NSRect(x: 0, y: 4, width: 320, height: 28))
        textField.placeholderString = "链接文字（留空则使用地址）"
        textField.stringValue       = selText
        textField.bezelStyle        = .roundedBezel

        container.addSubview(urlField)
        container.addSubview(textField)
        alert.accessoryView = container

        // 让 URL 框默认获得焦点
        alert.window.initialFirstResponder = urlField

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let url      = urlField.stringValue.trimmingCharacters(in: .whitespaces)
        let linkText = textField.stringValue.trimmingCharacters(in: .whitespaces)

        guard !url.isEmpty else { return }

        let displayText = linkText.isEmpty ? url : linkText
        let markdown    = "[\(displayText)](\(url))"

        // 替换选区（或在光标处插入）
        insertText(markdown, replacementRange: selRange)
    }

    // ── 粘贴：图片存为本地文件后插入路径，纯文字直接粘贴 ──────
    override func paste(_ sender: Any?) {
        let pb = NSPasteboard.general

        // 1. 系统截图/图片数据：直接用原始 TIFF/PNG 字节写文件，不经过 NSImage 中间层
        if let tiffData = pb.data(forType: .tiff),
           let srcRep   = NSBitmapImageRep(data: tiffData),
           let pngData  = srcRep.representation(using: .png, properties: [:]) {
            saveAndInsertImage(pngData: pngData, name: "screenshot")
            return
        }
        if let pngData = pb.data(forType: .png) {
            saveAndInsertImage(pngData: pngData, name: "image")
            return
        }
        // 2. 文件 URL（从访达复制的图片文件）：直接读文件字节，不创建 NSImage
        if let urls = pb.readObjects(forClasses: [NSURL.self],
                                     options: [.urlReadingFileURLsOnly: true]) as? [URL],
           let url = urls.first,
           ["png","jpg","jpeg","gif","webp","tiff","tif","bmp","heic"].contains(
                url.pathExtension.lowercased()) {
            // 图片文件：如果是 PNG 直接用，否则转 PNG
            let imgName = url.deletingPathExtension().lastPathComponent
            if let img = NSImage(contentsOf: url),
               let tiff = img.tiffRepresentation,
               let rep  = NSBitmapImageRep(data: tiff),
               let png  = rep.representation(using: .png, properties: [:]) {
                saveAndInsertImage(pngData: png, name: imgName)
            }
            return
        }
        // 3. 纯文本
        if let text = pb.string(forType: .string) {
            insertText(text, replacementRange: selectedRange())
            return
        }
        if let text = pb.string(forType: .init("public.utf8-plain-text")) {
            insertText(text, replacementRange: selectedRange())
        }
    }

    // ── 拖拽：接受文字和图片/图片文件 ────────────────────
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        let pb = sender.draggingPasteboard
        // 支持文字、图片、图片文件
        let imageTypes: [NSPasteboard.PasteboardType] = [.tiff, .png, .init("public.jpeg"),
                                                          .init("com.adobe.pdf"),
                                                          .init("public.file-url")]
        if pb.availableType(from: [.string] + imageTypes) != nil {
            return .copy
        }
        return []
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pb = sender.draggingPasteboard
        let imgExts = ["png","jpg","jpeg","gif","webp","tiff","tif","bmp","heic"]

        // 图片文件拖入
        if let urls = pb.readObjects(forClasses: [NSURL.self],
                                     options: [.urlReadingFileURLsOnly: true]) as? [URL],
           let url = urls.first,
           imgExts.contains(url.pathExtension.lowercased()) {
            let imgName = url.deletingPathExtension().lastPathComponent
            if let img = NSImage(contentsOf: url),
               let tiff = img.tiffRepresentation,
               let rep  = NSBitmapImageRep(data: tiff),
               let png  = rep.representation(using: .png, properties: [:]) {
                saveAndInsertImage(pngData: png, name: imgName)
            }
            return true
        }
        // TIFF 数据（截图拖入）
        if let tiffData = pb.data(forType: .tiff),
           let rep  = NSBitmapImageRep(data: tiffData),
           let png  = rep.representation(using: .png, properties: [:]) {
            saveAndInsertImage(pngData: png, name: "image")
            return true
        }
        // PNG 数据
        if let pngData = pb.data(forType: .png) {
            saveAndInsertImage(pngData: pngData, name: "image")
            return true
        }
        // 文字
        if let text = pb.string(forType: .string) {
            insertText(text, replacementRange: selectedRange())
            return true
        }
        return false
    }

    // ── 核心：PNG data → 写入 images/ → 插入 Markdown 路径 ──────
    private func saveAndInsertImage(pngData: Data, name: String) {
        let imagesDir = AppSettings.shared.effectiveSaveURL
            .appendingPathComponent("images", isDirectory: true)
        try? FileManager.default.createDirectory(at: imagesDir,
                                                  withIntermediateDirectories: true)

        let stamp    = Int(Date().timeIntervalSince1970 * 1000)
        let safeName = name.replacingOccurrences(of: "[^a-zA-Z0-9_-]",
                                                  with: "_",
                                                  options: .regularExpression)
        let fileURL  = imagesDir.appendingPathComponent("\(safeName)_\(stamp).png")

        do {
            try pngData.write(to: fileURL, options: .atomic)
            let mdStr = "![\(name)](\(fileURL.path))\n"
            insertText(mdStr, replacementRange: selectedRange())
        } catch {
            insertText("![\(name)](image_save_failed)\n", replacementRange: selectedRange())
        }
    }
}

// MARK: - NSImage 缩放扩展
private extension NSImage {
    func resized(to newSize: NSSize) -> NSImage? {
        let img = NSImage(size: newSize)
        img.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        draw(in: NSRect(origin: .zero, size: newSize),
             from: NSRect(origin: .zero, size: size),
             operation: .copy, fraction: 1.0)
        img.unlockFocus()
        return img
    }
}

// MARK: - 预览视图控制器
final class PreviewViewController: NSViewController {

    private let scrollView  = NSScrollView()
    private let textView    = NSTextView()
    private var renderTimer: Timer?

    override func loadView() { view = NSView() }
    override func viewDidLoad() { super.viewDidLoad(); buildUI() }

    private func buildUI() {
        let bg = previewBg()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers  = true
        scrollView.borderType          = .noBorder
        scrollView.backgroundColor     = bg
        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        textView.isEditable              = false
        textView.isSelectable            = true
        textView.isRichText              = true
        textView.backgroundColor         = bg
        textView.drawsBackground         = true
        textView.textContainerInset      = NSSize(width: 28, height: 24)
        textView.isVerticallyResizable   = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask        = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        scrollView.documentView = textView
    }

    private func previewBg() -> NSColor {
        if NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
            return NSColor(white: 0.10, alpha: 1)
        }
        return NSColor(white: 0.96, alpha: 1)
    }

    func render(_ markdown: String) {
        renderTimer?.invalidate()
        renderTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: false) { [weak self] _ in
            guard let self else { return }
            let dark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let bg   = self.previewBg()
            self.scrollView.backgroundColor = bg
            self.textView.backgroundColor   = bg
            let attr = MarkdownRenderer.render(markdown, darkMode: dark)
            self.textView.textStorage?.setAttributedString(attr)
            self.textView.scrollToBeginningOfDocument(nil)
        }
    }
}
