import AppKit
import AVFoundation

// MARK: - 保存选项面板

final class SaveOptionsPanel: NSViewController {

    // MARK: - 回调

    var onExport: ((SaveMode, URL) -> Void)?
    var onCancel: (() -> Void)?

    // MARK: - 数据

    private let segments: [ClipSegment]
    private let videoDuration: CMTime

    // MARK: - UI 控件

    private let titleLabel = NSTextField(labelWithString: "导出选项")
    private let segmentsLabel = NSTextField(labelWithString: "")
    private let radioIndividual = NSButton(radioButtonWithTitle: "分别保存各片段", target: nil, action: nil)
    private let radioMerged = NSButton(radioButtonWithTitle: "拼接为单个视频", target: nil, action: nil)
    private let radioBoth = NSButton(radioButtonWithTitle: "两者都保存", target: nil, action: nil)
    private let exportButton = NSButton(title: "导出…", target: nil, action: nil)
    private let cancelButton = NSButton(title: "取消", target: nil, action: nil)
    private let segmentListBox = NSScrollView()
    private let segmentTable = NSTableView()

    // MARK: - 初始化

    init(segments: [ClipSegment], videoDuration: CMTime) {
        self.segments = segments
        self.videoDuration = videoDuration
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - 视图构建

    override func loadView() {
        let v = NSView(frame: CGRect(x: 0, y: 0, width: 460, height: 480))
        v.wantsLayer = true
        v.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        self.view = v

        buildUI()
    }

    private func buildUI() {
        let v = view

        // 标题
        titleLabel.font = NSFont.systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.alignment = .center
        v.addSubview(titleLabel)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        // 片段摘要
        let totalDur = segments.reduce(0.0) { $0 + $1.durationSeconds }
        segmentsLabel.stringValue = "已选 \(segments.count) 个片段，总时长 \(formatDuration(totalDur))"
        segmentsLabel.font = NSFont.systemFont(ofSize: 12)
        segmentsLabel.textColor = .secondaryLabelColor
        segmentsLabel.alignment = .center
        v.addSubview(segmentsLabel)
        segmentsLabel.translatesAutoresizingMaskIntoConstraints = false

        // 分隔线
        let sep1 = makeSeparator()
        v.addSubview(sep1)

        // 片段列表
        setupSegmentTable()
        v.addSubview(segmentListBox)
        segmentListBox.translatesAutoresizingMaskIntoConstraints = false

        // 模式标题
        let modeLabel = NSTextField(labelWithString: "保存方式")
        modeLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        modeLabel.textColor = .labelColor
        v.addSubview(modeLabel)
        modeLabel.translatesAutoresizingMaskIntoConstraints = false

        // 单选按钮组
        [radioIndividual, radioMerged, radioBoth].forEach {
            $0.target = self
            $0.action = #selector(radioChanged)
            $0.font = NSFont.systemFont(ofSize: 13)
            v.addSubview($0)
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        radioIndividual.state = .on

        // 描述标签
        let descLabel = NSTextField(wrappingLabelWithString: "「分别保存」会为每个片段生成独立文件；「拼接」会按顺序合并所有片段为一个视频。")
        descLabel.font = NSFont.systemFont(ofSize: 11)
        descLabel.textColor = .secondaryLabelColor
        v.addSubview(descLabel)
        descLabel.translatesAutoresizingMaskIntoConstraints = false

        let sep2 = makeSeparator()
        v.addSubview(sep2)

        // 按钮
        exportButton.bezelStyle = .rounded
        exportButton.keyEquivalent = "\r"
        exportButton.target = self
        exportButton.action = #selector(doExport)
        v.addSubview(exportButton)
        exportButton.translatesAutoresizingMaskIntoConstraints = false

        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1B}"
        cancelButton.target = self
        cancelButton.action = #selector(doCancel)
        v.addSubview(cancelButton)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false

        // 约束
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: v.topAnchor, constant: 20),
            titleLabel.centerXAnchor.constraint(equalTo: v.centerXAnchor),

            segmentsLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            segmentsLabel.centerXAnchor.constraint(equalTo: v.centerXAnchor),

            sep1.topAnchor.constraint(equalTo: segmentsLabel.bottomAnchor, constant: 12),
            sep1.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 16),
            sep1.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -16),
            sep1.heightAnchor.constraint(equalToConstant: 1),

            segmentListBox.topAnchor.constraint(equalTo: sep1.bottomAnchor, constant: 10),
            segmentListBox.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 16),
            segmentListBox.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -16),
            segmentListBox.heightAnchor.constraint(equalToConstant: 130),

            modeLabel.topAnchor.constraint(equalTo: segmentListBox.bottomAnchor, constant: 14),
            modeLabel.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 20),

            radioIndividual.topAnchor.constraint(equalTo: modeLabel.bottomAnchor, constant: 8),
            radioIndividual.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 28),

            radioMerged.topAnchor.constraint(equalTo: radioIndividual.bottomAnchor, constant: 6),
            radioMerged.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 28),

            radioBoth.topAnchor.constraint(equalTo: radioMerged.bottomAnchor, constant: 6),
            radioBoth.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 28),

            descLabel.topAnchor.constraint(equalTo: radioBoth.bottomAnchor, constant: 10),
            descLabel.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 20),
            descLabel.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -20),

            sep2.topAnchor.constraint(equalTo: descLabel.bottomAnchor, constant: 14),
            sep2.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 16),
            sep2.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -16),
            sep2.heightAnchor.constraint(equalToConstant: 1),

            cancelButton.bottomAnchor.constraint(equalTo: v.bottomAnchor, constant: -16),
            cancelButton.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 16),
            cancelButton.widthAnchor.constraint(equalToConstant: 80),

            exportButton.bottomAnchor.constraint(equalTo: v.bottomAnchor, constant: -16),
            exportButton.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -16),
            exportButton.widthAnchor.constraint(equalToConstant: 100),
        ])
    }

    private func makeSeparator() -> NSView {
        let sep = NSView()
        sep.wantsLayer = true
        sep.layer?.backgroundColor = NSColor.separatorColor.cgColor
        sep.translatesAutoresizingMaskIntoConstraints = false
        return sep
    }

    private func setupSegmentTable() {
        segmentTable.style = .fullWidth
        segmentTable.headerView = nil
        segmentTable.rowHeight = 24
        segmentTable.gridStyleMask = .solidHorizontalGridLineMask
        segmentTable.gridColor = NSColor.separatorColor

        let col1 = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        col1.title = "名称"
        col1.width = 120
        let col2 = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("start"))
        col2.title = "开始"
        col2.width = 80
        let col3 = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("end"))
        col3.title = "结束"
        col3.width = 80
        let col4 = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("dur"))
        col4.title = "时长"
        col4.width = 80
        segmentTable.addTableColumn(col1)
        segmentTable.addTableColumn(col2)
        segmentTable.addTableColumn(col3)
        segmentTable.addTableColumn(col4)

        segmentTable.dataSource = self
        segmentTable.delegate = self

        segmentListBox.documentView = segmentTable
        segmentListBox.hasVerticalScroller = true
        segmentListBox.borderType = .bezelBorder
    }

    // MARK: - 动作

    @objc private func radioChanged() {
        // 单选互斥由系统处理（同父视图的 radio button 自动互斥需要 NSMatrix，
        // 此处手动互斥）
        if radioIndividual.state == .on {
            radioMerged.state = .off
            radioBoth.state = .off
        } else if radioMerged.state == .on {
            radioIndividual.state = .off
            radioBoth.state = .off
        } else if radioBoth.state == .on {
            radioIndividual.state = .off
            radioMerged.state = .off
        }
    }

    // 关闭 sheet 的统一入口（兼容 beginSheet 和 presentAsSheet 两种方式）
    private func closeSheet() {
        if let sheetWindow = view.window, let parent = sheetWindow.sheetParent {
            parent.endSheet(sheetWindow)
        } else {
            dismiss(nil)
        }
    }

    @objc private func doExport() {
        // 确定保存模式
        let mode: SaveMode
        if radioMerged.state == .on {
            mode = .merged
        } else if radioBoth.state == .on {
            mode = .both
        } else {
            mode = .individual
        }

        // 选择保存目录
        let openPanel = NSOpenPanel()
        openPanel.title = "选择保存文件夹"
        openPanel.message = "导出的视频文件将保存到该目录"
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.canCreateDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.prompt = "选择"

        guard let window = view.window else { return }
        openPanel.beginSheetModal(for: window) { [weak self] response in
            guard let self = self, response == .OK, let url = openPanel.url else { return }
            self.closeSheet()
            self.onExport?(mode, url)
        }
    }

    @objc private func doCancel() {
        closeSheet()
        onCancel?()
    }

    // MARK: - 工具

    private func formatDuration(_ seconds: Double) -> String {
        let s = Int(seconds)
        let m = s / 60
        let h = m / 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m % 60, s % 60) }
        return String(format: "%d:%02d", m, s % 60)
    }
}

// MARK: - TableView 数据源 / 委托

extension SaveOptionsPanel: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        segments.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let seg = segments[row]
        let cell = NSTextField(labelWithString: "")
        cell.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)

        switch tableColumn?.identifier.rawValue {
        case "name":
            cell.stringValue = seg.label.isEmpty ? "片段 \(row + 1)" : seg.label
        case "start":
            cell.stringValue = formatDuration(seg.startSeconds)
        case "end":
            cell.stringValue = formatDuration(seg.endSeconds)
        case "dur":
            cell.stringValue = formatDuration(seg.durationSeconds)
        default:
            break
        }
        return cell
    }
}
