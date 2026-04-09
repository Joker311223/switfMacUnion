import AppKit
import Foundation

// MARK: - 侧边栏视图控制器
final class SidebarViewController: NSViewController {

    private(set) var memos: [Memo] = []
    private var selectedMemoId: UUID?

    var onSelect: ((Memo) -> Void)?
    var onNew:    (() -> Void)?
    var onDelete: ((Memo) -> Void)?

    private let tableView  = MemoTableView()
    private let scrollView = NSScrollView()
    private let newBtn     = NSButton()
    private let countLabel = NSTextField()

    // MARK: - Life cycle

    override func loadView() { view = NSView() }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildUI()
    }

    // MARK: - Public API

    func reload(memos: [Memo]) {
        self.memos = memos
        tableView.reloadData()
        countLabel.stringValue = "\(memos.count) 条"
        // 恢复选中
        if let id = selectedMemoId,
           let idx = memos.firstIndex(where: { $0.id == id }) {
            tableView.selectRowIndexes(IndexSet(integer: idx), byExtendingSelection: false)
        }
    }

    func selectMemo(_ memo: Memo) {
        selectedMemoId = memo.id
        if let idx = memos.firstIndex(where: { $0.id == memo.id }) {
            tableView.selectRowIndexes(IndexSet(integer: idx), byExtendingSelection: false)
            tableView.scrollRowToVisible(idx)
        }
    }

    // MARK: - UI 构建

    private func buildUI() {
        view.wantsLayer = true

        // ── 顶部工具条 ─────────────────────────────────
        let toolbar = NSView()
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toolbar)

        // 数量标签
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        countLabel.isEditable         = false
        countLabel.isBordered         = false
        countLabel.backgroundColor    = .clear
        countLabel.font               = .systemFont(ofSize: 11)
        countLabel.textColor          = .tertiaryLabelColor
        countLabel.stringValue        = "0 条"
        toolbar.addSubview(countLabel)

        // 新建按钮
        newBtn.translatesAutoresizingMaskIntoConstraints = false
        newBtn.image                 = NSImage(systemSymbolName: "square.and.pencil",
                                               accessibilityDescription: "新建")
        newBtn.bezelStyle            = .inline
        newBtn.isBordered            = false
        newBtn.contentTintColor      = .controlAccentColor
        newBtn.target                = self
        newBtn.action                = #selector(newTapped)
        newBtn.toolTip               = "新建备忘录 (⌘N)"
        toolbar.addSubview(newBtn)

        // ── 分割线 ─────────────────────────────────────
        let sep = NSBox()
        sep.translatesAutoresizingMaskIntoConstraints = false
        sep.boxType = .separator
        view.addSubview(sep)

        // ── TableView ──────────────────────────────────
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers  = true
        scrollView.borderType          = .noBorder
        scrollView.backgroundColor     = .clear
        view.addSubview(scrollView)

        tableView.headerView           = nil
        tableView.rowHeight            = 66
        tableView.intercellSpacing     = NSSize(width: 0, height: 1)
        tableView.backgroundColor      = .clear
        tableView.allowsMultipleSelection = false
        tableView.dataSource           = self
        tableView.delegate             = self
        tableView.onDeleteKey          = { [weak self] row in
            guard let self, row >= 0, row < self.memos.count else { return }
            self.onDelete?(self.memos[row])
        }

        let col = NSTableColumn(identifier: .init("memo"))
        col.minWidth = 180
        tableView.addTableColumn(col)
        scrollView.documentView = tableView

        // 右键菜单
        let menu = NSMenu()
        let del  = NSMenuItem(title: "删除", action: #selector(deleteClicked), keyEquivalent: "")
        del.target = self
        menu.addItem(del)
        tableView.menu = menu

        // ── 约束 ───────────────────────────────────────
        NSLayoutConstraint.activate([
            toolbar.topAnchor.constraint(equalTo: view.topAnchor),
            toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            toolbar.heightAnchor.constraint(equalToConstant: 36),

            countLabel.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),
            countLabel.leadingAnchor.constraint(equalTo: toolbar.leadingAnchor, constant: 12),

            newBtn.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),
            newBtn.trailingAnchor.constraint(equalTo: toolbar.trailingAnchor, constant: -10),
            newBtn.widthAnchor.constraint(equalToConstant: 22),
            newBtn.heightAnchor.constraint(equalToConstant: 22),

            sep.topAnchor.constraint(equalTo: toolbar.bottomAnchor),
            sep.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sep.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            scrollView.topAnchor.constraint(equalTo: sep.bottomAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    @objc private func newTapped()     { onNew?() }
    @objc private func deleteClicked() {
        let row = tableView.clickedRow >= 0 ? tableView.clickedRow : tableView.selectedRow
        guard row >= 0, row < memos.count else { return }
        onDelete?(memos[row])
    }
}

// MARK: - TableView DataSource & Delegate
extension SidebarViewController: NSTableViewDataSource, NSTableViewDelegate {

    func numberOfRows(in tableView: NSTableView) -> Int { memos.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let id = NSUserInterfaceItemIdentifier("cell")
        var cell = tableView.makeView(withIdentifier: id, owner: nil) as? MemoCellView
        if cell == nil { cell = MemoCellView(); cell?.identifier = id }
        cell?.configure(with: memos[row])
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = tableView.selectedRow
        guard row >= 0, row < memos.count else { return }
        selectedMemoId = memos[row].id
        onSelect?(memos[row])
    }
}

// MARK: - 自定义 TableView（支持 Delete 键）
final class MemoTableView: NSTableView {
    var onDeleteKey: ((Int) -> Void)?

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 51 { // Delete
            onDeleteKey?(selectedRow)
        } else {
            super.keyDown(with: event)
        }
    }
}

// MARK: - 备忘录 Cell
final class MemoCellView: NSTableCellView {

    private let titleLabel   = NSTextField()
    private let previewLabel = NSTextField()
    private let dateLabel    = NSTextField()
    private let bg           = NSBox()

    override init(frame: NSRect) {
        super.init(frame: frame)
        build()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func build() {
        // 背景（悬停/选中时系统自动处理，这里只做圆角容器）
        bg.translatesAutoresizingMaskIntoConstraints = false
        bg.boxType        = .custom
        bg.isTransparent  = false
        bg.borderWidth    = 0
        bg.cornerRadius   = 8
        bg.fillColor      = .clear
        addSubview(bg)

        [titleLabel, previewLabel, dateLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.isEditable      = false
            $0.isBordered      = false
            $0.backgroundColor = .clear
            $0.lineBreakMode   = .byTruncatingTail
            addSubview($0)
        }

        titleLabel.font      = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = .labelColor

        previewLabel.font      = .systemFont(ofSize: 11.5)
        previewLabel.textColor = .secondaryLabelColor

        dateLabel.font      = .systemFont(ofSize: 10.5)
        dateLabel.textColor = .tertiaryLabelColor
        dateLabel.alignment = .right

        NSLayoutConstraint.activate([
            bg.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            bg.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2),
            bg.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            bg.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),

            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            titleLabel.trailingAnchor.constraint(equalTo: dateLabel.leadingAnchor, constant: -6),

            dateLabel.firstBaselineAnchor.constraint(equalTo: titleLabel.firstBaselineAnchor),
            dateLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            dateLabel.widthAnchor.constraint(equalToConstant: 52),

            previewLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 5),
            previewLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            previewLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
        ])
    }

    func configure(with memo: Memo) {
        titleLabel.stringValue   = memo.displayTitle
        previewLabel.stringValue = memo.preview

        let cal = Calendar.current
        let fmt = DateFormatter()
        if cal.isDateInToday(memo.updatedAt) {
            fmt.dateFormat = "HH:mm"
        } else if cal.isDateInYesterday(memo.updatedAt) {
            dateLabel.stringValue = "昨天"; return
        } else if cal.isDate(memo.updatedAt, equalTo: Date(), toGranularity: .year) {
            fmt.dateFormat = "M月d日"
        } else {
            fmt.dateFormat = "yyyy/M/d"
        }
        dateLabel.stringValue = fmt.string(from: memo.updatedAt)
    }
}
