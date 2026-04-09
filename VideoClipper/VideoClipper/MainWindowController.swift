import AppKit
import AVFoundation
import AVKit

// MARK: - 主窗口控制器

final class MainWindowController: NSWindowController, NSWindowDelegate {

    // MARK: - 模型

    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var asset: AVAsset?
    private var videoURL: URL?
    private var duration: CMTime = .zero
    private var timeObserverToken: Any?
    private var segments: [ClipSegment] = []
    private var selectedSegment: ClipSegment?

    // MARK: - UI

    private var playerView: VideoPlayerView!
    private var timelineView: TimelineView!
    private var controlBar: NSView!
    private var segmentListView: NSScrollView!
    private var segmentTable: NSTableView!
    private var sidebarView: NSView!

    // 控制栏按钮
    private var playPauseButton: NSButton!
    private var currentTimeLabel: NSTextField!
    private var durationLabel: NSTextField!
    private var speedButton: NSButton!
    private var volumeSlider: NSSlider!
    private var openButton: NSButton!
    private var exportButton: NSButton!
    private var addSegmentButton: NSButton!
    private var deleteSegmentButton: NSButton!
    private var clearSegmentsButton: NSButton!

    // 进度面板
    private var progressPanel: NSPanel?
    private var progressBar: NSProgressIndicator?
    private var progressLabel: NSTextField?
    private var progressPercentLabel: NSTextField?

    // 导出状态
    private var isExporting: Bool = false
    private var currentExporter: VideoExporter?

    // MARK: - 初始化

    init() {
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 1100, height: 740),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "VideoClipper"
        window.titlebarAppearsTransparent = false
        window.minSize = CGSize(width: 800, height: 580)
        window.center()
        window.setFrameAutosaveName("MainWindow")

        super.init(window: window)
        window.delegate = self

        buildUI()
        setupNotifications()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
        }
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - UI 构建

    private func buildUI() {
        guard let contentView = window?.contentView else { return }
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor(white: 0.10, alpha: 1).cgColor

        // === 左侧主区域 ===
        let mainArea = NSView()
        mainArea.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(mainArea)

        // 视频播放区
        playerView = VideoPlayerView()
        playerView.translatesAutoresizingMaskIntoConstraints = false
        playerView.registerDrag()
        mainArea.addSubview(playerView)

        // 控制栏
        controlBar = buildControlBar()
        controlBar.translatesAutoresizingMaskIntoConstraints = false
        mainArea.addSubview(controlBar)

        // 时间轴
        timelineView = TimelineView()
        timelineView.translatesAutoresizingMaskIntoConstraints = false
        timelineView.delegate = self
        mainArea.addSubview(timelineView)

        // === 右侧边栏：片段列表 ===
        sidebarView = buildSidebar()
        sidebarView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(sidebarView)

        // 分隔线
        let divider = NSView()
        divider.wantsLayer = true
        divider.layer?.backgroundColor = NSColor(white: 0.20, alpha: 1).cgColor
        divider.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(divider)

        NSLayoutConstraint.activate([
            // 右侧边栏
            sidebarView.topAnchor.constraint(equalTo: contentView.topAnchor),
            sidebarView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            sidebarView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            sidebarView.widthAnchor.constraint(equalToConstant: 240),

            // 分隔线
            divider.topAnchor.constraint(equalTo: contentView.topAnchor),
            divider.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            divider.trailingAnchor.constraint(equalTo: sidebarView.leadingAnchor),
            divider.widthAnchor.constraint(equalToConstant: 1),

            // 主区域
            mainArea.topAnchor.constraint(equalTo: contentView.topAnchor),
            mainArea.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            mainArea.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            mainArea.trailingAnchor.constraint(equalTo: divider.leadingAnchor),

            // 视频播放区
            playerView.topAnchor.constraint(equalTo: mainArea.topAnchor, constant: 8),
            playerView.leadingAnchor.constraint(equalTo: mainArea.leadingAnchor, constant: 8),
            playerView.trailingAnchor.constraint(equalTo: mainArea.trailingAnchor, constant: -8),
            playerView.bottomAnchor.constraint(equalTo: controlBar.topAnchor, constant: -6),

            // 控制栏
            controlBar.leadingAnchor.constraint(equalTo: mainArea.leadingAnchor, constant: 8),
            controlBar.trailingAnchor.constraint(equalTo: mainArea.trailingAnchor, constant: -8),
            controlBar.bottomAnchor.constraint(equalTo: timelineView.topAnchor, constant: -6),
            controlBar.heightAnchor.constraint(equalToConstant: 46),

            // 时间轴
            timelineView.leadingAnchor.constraint(equalTo: mainArea.leadingAnchor, constant: 8),
            timelineView.trailingAnchor.constraint(equalTo: mainArea.trailingAnchor, constant: -8),
            timelineView.bottomAnchor.constraint(equalTo: mainArea.bottomAnchor, constant: -10),
            timelineView.heightAnchor.constraint(equalToConstant: 110),
        ])
    }

    // MARK: - 控制栏

    private func buildControlBar() -> NSView {
        let bar = NSView()
        bar.wantsLayer = true
        bar.layer?.backgroundColor = NSColor(white: 0.15, alpha: 1).cgColor
        bar.layer?.cornerRadius = 8

        // 播放/暂停
        playPauseButton = NSButton(image: NSImage(systemSymbolName: "play.fill", accessibilityDescription: "播放")!, target: self, action: #selector(togglePlayPause))
        playPauseButton.bezelStyle = .regularSquare
        playPauseButton.isBordered = false
        playPauseButton.contentTintColor = NSColor.white
        playPauseButton.translatesAutoresizingMaskIntoConstraints = false
        bar.addSubview(playPauseButton)

        // 时间标签
        currentTimeLabel = NSTextField(labelWithString: "0:00")
        currentTimeLabel.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        currentTimeLabel.textColor = NSColor(white: 0.85, alpha: 1)
        currentTimeLabel.translatesAutoresizingMaskIntoConstraints = false
        bar.addSubview(currentTimeLabel)

        let slash = NSTextField(labelWithString: "/")
        slash.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        slash.textColor = NSColor(white: 0.5, alpha: 1)
        slash.translatesAutoresizingMaskIntoConstraints = false
        bar.addSubview(slash)

        durationLabel = NSTextField(labelWithString: "0:00")
        durationLabel.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        durationLabel.textColor = NSColor(white: 0.5, alpha: 1)
        durationLabel.translatesAutoresizingMaskIntoConstraints = false
        bar.addSubview(durationLabel)

        // 音量
        let volIcon = NSImageView(image: NSImage(systemSymbolName: "speaker.wave.2.fill", accessibilityDescription: "音量")!)
        volIcon.contentTintColor = NSColor(white: 0.6, alpha: 1)
        volIcon.translatesAutoresizingMaskIntoConstraints = false
        bar.addSubview(volIcon)

        volumeSlider = NSSlider(value: 1.0, minValue: 0.0, maxValue: 1.0, target: self, action: #selector(volumeChanged))
        volumeSlider.translatesAutoresizingMaskIntoConstraints = false
        bar.addSubview(volumeSlider)

        // 速度
        speedButton = NSButton(title: "1×", target: self, action: #selector(cycleSpeed))
        speedButton.bezelStyle = .regularSquare
        speedButton.isBordered = false
        speedButton.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .medium)
        speedButton.contentTintColor = NSColor(white: 0.7, alpha: 1)
        speedButton.translatesAutoresizingMaskIntoConstraints = false
        bar.addSubview(speedButton)

        // 分隔
        let sep = makeSep()
        bar.addSubview(sep)

        // 添加片段按钮
        addSegmentButton = makeIconButton(symbol: "scissors.badge.plus", tip: "添加片段（A）", action: #selector(addSegmentAtCurrentTime))
        bar.addSubview(addSegmentButton)

        // 删除片段
        deleteSegmentButton = makeIconButton(symbol: "trash", tip: "删除选中片段", action: #selector(deleteSelectedSegment))
        bar.addSubview(deleteSegmentButton)

        // 清空
        clearSegmentsButton = makeIconButton(symbol: "xmark.circle", tip: "清空所有片段", action: #selector(clearAllSegments))
        bar.addSubview(clearSegmentsButton)

        let sep2 = makeSep()
        bar.addSubview(sep2)

        // 打开视频
        openButton = makeIconButton(symbol: "folder.badge.plus", tip: "打开视频（⌘O）", action: #selector(openVideo))
        openButton.contentTintColor = NSColor.systemBlue
        bar.addSubview(openButton)

        // 导出
        exportButton = makeIconButton(symbol: "square.and.arrow.up", tip: "导出（⌘E）", action: #selector(showExportPanel))
        exportButton.contentTintColor = NSColor.systemGreen
        bar.addSubview(exportButton)

        // 约束
        NSLayoutConstraint.activate([
            playPauseButton.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            playPauseButton.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: 10),
            playPauseButton.widthAnchor.constraint(equalToConstant: 32),
            playPauseButton.heightAnchor.constraint(equalToConstant: 32),

            currentTimeLabel.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            currentTimeLabel.leadingAnchor.constraint(equalTo: playPauseButton.trailingAnchor, constant: 8),

            slash.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            slash.leadingAnchor.constraint(equalTo: currentTimeLabel.trailingAnchor, constant: 2),

            durationLabel.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            durationLabel.leadingAnchor.constraint(equalTo: slash.trailingAnchor, constant: 2),

            speedButton.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            speedButton.leadingAnchor.constraint(equalTo: durationLabel.trailingAnchor, constant: 12),
            speedButton.widthAnchor.constraint(equalToConstant: 36),

            volIcon.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            volIcon.leadingAnchor.constraint(equalTo: speedButton.trailingAnchor, constant: 10),
            volIcon.widthAnchor.constraint(equalToConstant: 18),

            volumeSlider.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            volumeSlider.leadingAnchor.constraint(equalTo: volIcon.trailingAnchor, constant: 4),
            volumeSlider.widthAnchor.constraint(equalToConstant: 80),

            sep.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            sep.leadingAnchor.constraint(equalTo: volumeSlider.trailingAnchor, constant: 10),
            sep.widthAnchor.constraint(equalToConstant: 1),
            sep.heightAnchor.constraint(equalToConstant: 24),

            addSegmentButton.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            addSegmentButton.leadingAnchor.constraint(equalTo: sep.trailingAnchor, constant: 8),
            addSegmentButton.widthAnchor.constraint(equalToConstant: 32),

            deleteSegmentButton.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            deleteSegmentButton.leadingAnchor.constraint(equalTo: addSegmentButton.trailingAnchor, constant: 4),
            deleteSegmentButton.widthAnchor.constraint(equalToConstant: 32),

            clearSegmentsButton.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            clearSegmentsButton.leadingAnchor.constraint(equalTo: deleteSegmentButton.trailingAnchor, constant: 4),
            clearSegmentsButton.widthAnchor.constraint(equalToConstant: 32),

            sep2.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            sep2.leadingAnchor.constraint(equalTo: clearSegmentsButton.trailingAnchor, constant: 8),
            sep2.widthAnchor.constraint(equalToConstant: 1),
            sep2.heightAnchor.constraint(equalToConstant: 24),

            exportButton.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            exportButton.trailingAnchor.constraint(equalTo: bar.trailingAnchor, constant: -8),
            exportButton.widthAnchor.constraint(equalToConstant: 32),

            openButton.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            openButton.trailingAnchor.constraint(equalTo: exportButton.leadingAnchor, constant: -4),
            openButton.widthAnchor.constraint(equalToConstant: 32),
        ])

        return bar
    }

    // MARK: - 右侧边栏（片段列表）

    private func buildSidebar() -> NSView {
        let sb = NSView()
        sb.wantsLayer = true
        sb.layer?.backgroundColor = NSColor(white: 0.12, alpha: 1).cgColor

        // 标题
        let titleLabel = NSTextField(labelWithString: "裁剪片段")
        titleLabel.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = NSColor(white: 0.85, alpha: 1)

        // 提示（用 wrappingLabel，自动支持多行且高度随内容撑开）
        let hintLabel = NSTextField(wrappingLabelWithString: "在时间轴上拖拽选区，或按 A 键添加片段")
        hintLabel.font = NSFont.systemFont(ofSize: 11)
        hintLabel.textColor = NSColor(white: 0.45, alpha: 1)

        // 用 StackView 包裹标题+提示，保证高度由内容决定
        let headerStack = NSStackView(views: [titleLabel, hintLabel])
        headerStack.orientation = .vertical
        headerStack.alignment = .leading
        headerStack.spacing = 4
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        sb.addSubview(headerStack)

        // 表格
        let tableContainer = NSScrollView()
        tableContainer.translatesAutoresizingMaskIntoConstraints = false
        tableContainer.hasVerticalScroller = true
        tableContainer.borderType = .noBorder

        segmentTable = NSTableView()
        segmentTable.style = .fullWidth
        segmentTable.backgroundColor = NSColor(white: 0.14, alpha: 1)
        segmentTable.gridStyleMask = .solidHorizontalGridLineMask
        segmentTable.gridColor = NSColor(white: 0.2, alpha: 1)
        segmentTable.rowHeight = 52
        segmentTable.allowsEmptySelection = true
        segmentTable.allowsMultipleSelection = false

        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("segment"))
        col.title = ""
        col.isEditable = false
        segmentTable.addTableColumn(col)
        segmentTable.headerView = nil

        segmentTable.dataSource = self
        segmentTable.delegate = self
        segmentTable.action = #selector(segmentTableClicked)
        segmentTable.target = self

        tableContainer.documentView = segmentTable

        segmentListView = tableContainer
        sb.addSubview(tableContainer)

        // 底部工具栏
        let bottomBar = NSView()
        bottomBar.wantsLayer = true
        bottomBar.layer?.backgroundColor = NSColor(white: 0.15, alpha: 1).cgColor
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        sb.addSubview(bottomBar)

        let exportAllBtn = NSButton(title: "导出…", target: self, action: #selector(showExportPanel))
        exportAllBtn.bezelStyle = .rounded
        exportAllBtn.translatesAutoresizingMaskIntoConstraints = false
        exportAllBtn.tag = 9002   // 供 setExportingState 查找
        bottomBar.addSubview(exportAllBtn)

        let segCountLabel = NSTextField(labelWithString: "")
        segCountLabel.font = NSFont.systemFont(ofSize: 11)
        segCountLabel.textColor = NSColor(white: 0.5, alpha: 1)
        segCountLabel.translatesAutoresizingMaskIntoConstraints = false
        segCountLabel.tag = 9001
        bottomBar.addSubview(segCountLabel)

        NSLayoutConstraint.activate([
            headerStack.topAnchor.constraint(equalTo: sb.topAnchor, constant: 14),
            headerStack.leadingAnchor.constraint(equalTo: sb.leadingAnchor, constant: 14),
            headerStack.trailingAnchor.constraint(equalTo: sb.trailingAnchor, constant: -14),

            tableContainer.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 10),
            tableContainer.leadingAnchor.constraint(equalTo: sb.leadingAnchor),
            tableContainer.trailingAnchor.constraint(equalTo: sb.trailingAnchor),
            tableContainer.bottomAnchor.constraint(equalTo: bottomBar.topAnchor),

            bottomBar.leadingAnchor.constraint(equalTo: sb.leadingAnchor),
            bottomBar.trailingAnchor.constraint(equalTo: sb.trailingAnchor),
            bottomBar.bottomAnchor.constraint(equalTo: sb.bottomAnchor),
            bottomBar.heightAnchor.constraint(equalToConstant: 52),

            segCountLabel.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor),
            segCountLabel.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor, constant: 12),

            exportAllBtn.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor),
            exportAllBtn.trailingAnchor.constraint(equalTo: bottomBar.trailingAnchor, constant: -12),
            exportAllBtn.widthAnchor.constraint(equalToConstant: 80),
            exportAllBtn.heightAnchor.constraint(equalToConstant: 30),
        ])

        return sb
    }

    // MARK: - 辅助

    private func makeIconButton(symbol: String, tip: String, action: Selector) -> NSButton {
        let img = NSImage(systemSymbolName: symbol, accessibilityDescription: tip) ?? NSImage()
        let btn = NSButton(image: img, target: self, action: action)
        btn.bezelStyle = .regularSquare
        btn.isBordered = false
        btn.contentTintColor = NSColor(white: 0.75, alpha: 1)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.toolTip = tip
        btn.heightAnchor.constraint(equalToConstant: 30).isActive = true
        return btn
    }

    private func makeSep() -> NSView {
        let sep = NSView()
        sep.wantsLayer = true
        sep.layer?.backgroundColor = NSColor(white: 0.28, alpha: 1).cgColor
        sep.translatesAutoresizingMaskIntoConstraints = false
        return sep
    }

    // MARK: - 通知

    private func setupNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(videoDropped(_:)), name: .videoDropped, object: nil)

        // 键盘快捷键通过 NSApp 的 keyDown 传递，此处用 NSEvent monitor
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            return self?.handleKeyDown(event) ?? event
        }
    }

    @objc private func videoDropped(_ note: Notification) {
        guard let url = note.userInfo?["url"] as? URL else { return }
        loadVideo(url: url)
    }

    private func handleKeyDown(_ event: NSEvent) -> NSEvent? {
        guard window?.isKeyWindow == true else { return event }
        switch event.keyCode {
        case 49: // Space
            togglePlayPause()
            return nil
        case 0: // A
            if !event.modifierFlags.contains(.command) {
                addSegmentAtCurrentTime()
                return nil
            }
        case 51, 117: // Delete / Forward Delete
            deleteSelectedSegment()
            return nil
        case 123: // ←
            stepBackward()
            return nil
        case 124: // →
            stepForward()
            return nil
        default:
            break
        }
        return event
    }

    // MARK: - 视频加载

    @objc func openVideo() {
        let panel = NSOpenPanel()
        panel.title = "选择视频文件"
        panel.allowedContentTypes = [
            .init(filenameExtension: "mp4")!,
            .init(filenameExtension: "mov")!,
            .init(filenameExtension: "m4v")!,
            .init(filenameExtension: "avi")!,
            .init(filenameExtension: "mkv")!,
        ]
        panel.allowsMultipleSelection = false

        guard let window = window else { return }
        panel.beginSheetModal(for: window) { [weak self] response in
            if response == .OK, let url = panel.url {
                self?.loadVideo(url: url)
            }
        }
    }

    private func loadVideo(url: URL) {
        // 清理旧状态
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }
        player?.pause()

        videoURL = url
        asset = AVAsset(url: url)
        playerItem = AVPlayerItem(asset: asset!)
        player = AVPlayer(playerItem: playerItem)
        playerView.player = player

        // 观察时长
        asset?.loadValuesAsynchronously(forKeys: ["duration"]) { [weak self] in
            DispatchQueue.main.async {
                guard let self = self else { return }
                var err: NSError?
                if self.asset?.statusOfValue(forKey: "duration", error: &err) == .loaded {
                    self.duration = self.asset?.duration ?? .zero
                    self.timelineView.duration = self.duration
                    self.durationLabel.stringValue = self.formatTime(CMTimeGetSeconds(self.duration))
                    self.generateThumbnails()
                }
            }
        }

        // 时间观察
        let interval = CMTime(value: 1, timescale: 30)
        timeObserverToken = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            self?.updateCurrentTime(time)
        }

        // 播放结束通知
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(playerDidFinish), name: .AVPlayerItemDidPlayToEndTime, object: playerItem)

        window?.title = "VideoClipper — \(url.lastPathComponent)"
        updatePlayPauseButton()

        // 清空片段
        segments = []
        timelineView.segments = []
        timelineView.selectedSegmentID = nil
        selectedSegment = nil
        segmentTable.reloadData()
        updateSegmentCount()
    }

    @objc private func playerDidFinish() {
        player?.seek(to: .zero)
        updatePlayPauseButton()
    }

    // MARK: - 缩略图

    private func generateThumbnails() {
        guard let asset = asset else { return }
        let dur = CMTimeGetSeconds(duration)
        guard dur > 0 else { return }

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 120, height: 68)

        let count = 20
        var times: [CMTime] = []
        for i in 0...count {
            let t = Double(i) / Double(count) * dur
            times.append(CMTimeMakeWithSeconds(t, preferredTimescale: 600))
        }

        var results: [(CMTime, NSImage)] = []
        let dispatchGroup = DispatchGroup()

        for time in times {
            dispatchGroup.enter()
            generator.generateCGImagesAsynchronously(forTimes: [NSValue(time: time)]) { requestedTime, cgImage, _, _, _ in
                defer { dispatchGroup.leave() }
                if let cgImage = cgImage {
                    let img = NSImage(cgImage: cgImage, size: NSSize(width: 60, height: 34))
                    results.append((requestedTime, img))
                }
            }
        }

        dispatchGroup.notify(queue: .main) { [weak self] in
            self?.timelineView.thumbnails = results.sorted { CMTimeGetSeconds($0.0) < CMTimeGetSeconds($1.0) }
        }
    }

    // MARK: - 播放控制

    @objc func togglePlayPause() {
        guard let player = player else { return }
        if player.rate != 0 {
            player.pause()
        } else {
            // 如果到末尾，从头开始
            if let dur = player.currentItem?.duration,
               player.currentTime() >= dur {
                player.seek(to: .zero)
            }
            player.play()
        }
        updatePlayPauseButton()
    }

    private func updatePlayPauseButton() {
        let isPlaying = (player?.rate ?? 0) != 0
        let symbolName = isPlaying ? "pause.fill" : "play.fill"
        playPauseButton.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
    }

    @objc private func volumeChanged() {
        player?.volume = Float(volumeSlider.floatValue)
    }

    private var speedIndex = 0
    private let speeds: [Float] = [1.0, 1.5, 2.0, 0.5]
    private let speedLabels = ["1×", "1.5×", "2×", "0.5×"]

    @objc private func cycleSpeed() {
        speedIndex = (speedIndex + 1) % speeds.count
        player?.rate = speeds[speedIndex]
        speedButton.title = speedLabels[speedIndex]
    }

    private func stepBackward() {
        let cur = CMTimeGetSeconds(player?.currentTime() ?? .zero)
        let newT = max(0, cur - 1.0 / 30.0)
        player?.seek(to: CMTimeMakeWithSeconds(newT, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
    }

    private func stepForward() {
        let dur = CMTimeGetSeconds(duration)
        let cur = CMTimeGetSeconds(player?.currentTime() ?? .zero)
        let newT = min(dur, cur + 1.0 / 30.0)
        player?.seek(to: CMTimeMakeWithSeconds(newT, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
    }

    private func updateCurrentTime(_ time: CMTime) {
        currentTimeLabel.stringValue = formatTime(CMTimeGetSeconds(time))
        timelineView.currentTime = time
    }

    // MARK: - 片段操作

    @objc func addSegmentAtCurrentTime() {
        guard asset != nil else { return }
        timelineView.addSegmentAtCurrentTime()
    }

    @objc func deleteSelectedSegment() {
        timelineView.removeSelectedSegment()
    }

    @objc func clearAllSegments() {
        let alert = NSAlert()
        alert.messageText = "清空所有片段"
        alert.informativeText = "确定要删除所有裁剪片段吗？"
        alert.addButton(withTitle: "清空")
        alert.addButton(withTitle: "取消")
        alert.alertStyle = .warning
        guard let window = window else { return }
        alert.beginSheetModal(for: window) { [weak self] response in
            if response == .alertFirstButtonReturn {
                self?.timelineView.clearAllSegments()
            }
        }
    }

    @objc private func segmentTableClicked() {
        let row = segmentTable.selectedRow
        guard row >= 0 && row < segments.count else { return }
        let seg = segments[row]
        selectedSegment = seg
        timelineView.selectedSegmentID = seg.id

        // Seek 到片段开始
        let t = CMTimeMakeWithSeconds(seg.startSeconds, preferredTimescale: 600)
        player?.seek(to: t, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    private func updateSegmentCount() {
        let label = sidebarView.viewWithTag(9001) as? NSTextField
        label?.stringValue = "\(segments.count) 个片段"
    }

    // MARK: - 导出

    @objc func showExportPanel() {
        guard !isExporting else { return }   // 导出中禁止重复触发
        guard !segments.isEmpty else {
            let alert = NSAlert()
            alert.messageText = "没有裁剪片段"
            alert.informativeText = "请先在时间轴上选择要裁剪的区间"
            alert.addButton(withTitle: "好的")
            alert.runModal()
            return
        }

        guard let asset = asset else {
            showAlert(title: "未加载视频", message: "请先打开一个视频文件")
            return
        }

        let panel = SaveOptionsPanel(segments: segments, videoDuration: duration)
        panel.onExport = { [weak self] mode, outputDirectory in
            self?.startExport(mode: mode, asset: asset, outputDirectory: outputDirectory)
        }

        guard let window = window else { return }
        let sheet = NSWindow(contentViewController: panel)
        sheet.styleMask = [.titled, .closable]
        sheet.title = ""
        window.beginSheet(sheet, completionHandler: nil)
    }

    private func startExport(mode: SaveMode, asset: AVAsset, outputDirectory: URL) {
        guard let videoURL = videoURL else { return }
        let originalName = videoURL.deletingPathExtension().lastPathComponent

        let exporter = VideoExporter()
        currentExporter = exporter

        setExportingState(true)
        showProgressPanel()

        switch mode {
        case .individual:
            exporter.exportIndividual(
                asset: asset,
                segments: segments,
                outputDirectory: outputDirectory,
                originalFileName: originalName,
                overallProgress: { [weak self] p in self?.updateProgress(p) },
                completion: { [weak self] result in self?.handleExportResult(result, outputDirectory: outputDirectory) }
            )

        case .merged:
            let mergedURL = outputDirectory.appendingPathComponent("\(originalName)_merged.mp4")
            exporter.exportMerged(
                asset: asset,
                segments: segments,
                outputURL: mergedURL,
                progress: { [weak self] p in self?.updateProgress(p) },
                completion: { [weak self] result in
                    switch result {
                    case .success(let url): self?.handleExportResult(.success([url]), outputDirectory: outputDirectory)
                    case .failure(let e): self?.handleExportResult(.failure(e), outputDirectory: outputDirectory)
                    }
                }
            )

        case .both:
            exporter.exportBoth(
                asset: asset,
                segments: segments,
                outputDirectory: outputDirectory,
                originalFileName: originalName,
                overallProgress: { [weak self] p in self?.updateProgress(p) },
                completion: { [weak self] result in self?.handleExportResult(result, outputDirectory: outputDirectory) }
            )
        }
    }

    // MARK: - 取消导出

    @objc private func cancelExport() {
        // 先更新 UI 提示正在取消
        progressLabel?.stringValue = "正在取消…"
        progressBar?.isIndeterminate = true
        progressBar?.startAnimation(nil)
        // 调用 exporter 取消
        currentExporter?.cancel()
        currentExporter = nil
    }

    // MARK: - 导出状态控制

    private func setExportingState(_ exporting: Bool) {
        isExporting = exporting
        exportButton.isEnabled = !exporting
        // 侧边栏导出按钮（tag 9002）
        if let btn = sidebarView.viewWithTag(9002) as? NSButton {
            btn.isEnabled = !exporting
        }
    }

    // MARK: - 进度面板

    private func showProgressPanel() {
        // 构建进度 Sheet 内容
        let contentView = NSView(frame: CGRect(x: 0, y: 0, width: 380, height: 160))
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        // 标题
        let titleLabel = NSTextField(labelWithString: "正在导出…")
        titleLabel.font = NSFont.systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.frame = CGRect(x: 20, y: 118, width: 340, height: 22)
        contentView.addSubview(titleLabel)

        // 进度条
        let bar = NSProgressIndicator()
        bar.style = .bar
        bar.isIndeterminate = false
        bar.doubleValue = 0
        bar.minValue = 0
        bar.maxValue = 1
        bar.frame = CGRect(x: 20, y: 82, width: 340, height: 16)
        bar.startAnimation(nil)
        contentView.addSubview(bar)

        // 状态文字
        let statusLabel = NSTextField(labelWithString: "准备中…")
        statusLabel.font = NSFont.systemFont(ofSize: 12)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.frame = CGRect(x: 20, y: 60, width: 260, height: 18)
        contentView.addSubview(statusLabel)

        // 百分比
        let pctLabel = NSTextField(labelWithString: "0%")
        pctLabel.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .medium)
        pctLabel.textColor = .labelColor
        pctLabel.alignment = .right
        pctLabel.frame = CGRect(x: 290, y: 60, width: 70, height: 18)
        contentView.addSubview(pctLabel)

        // 分隔线
        let sep = NSView(frame: CGRect(x: 0, y: 46, width: 380, height: 1))
        sep.wantsLayer = true
        sep.layer?.backgroundColor = NSColor.separatorColor.cgColor
        contentView.addSubview(sep)

        // 取消按钮
        let cancelBtn = NSButton(title: "取消", target: self, action: #selector(cancelExport))
        cancelBtn.bezelStyle = .rounded
        cancelBtn.frame = CGRect(x: 280, y: 10, width: 80, height: 28)
        contentView.addSubview(cancelBtn)

        // 提示
        let hintLabel = NSTextField(labelWithString: "点击取消可中止导出")
        hintLabel.font = NSFont.systemFont(ofSize: 11)
        hintLabel.textColor = .tertiaryLabelColor
        hintLabel.frame = CGRect(x: 20, y: 16, width: 220, height: 18)
        contentView.addSubview(hintLabel)

        progressBar = bar
        progressLabel = statusLabel
        progressPercentLabel = pctLabel

        let panel = NSPanel(
            contentRect: CGRect(x: 0, y: 0, width: 380, height: 160),
            styleMask: [.titled, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = ""
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isFloatingPanel = false
        panel.contentView = contentView
        progressPanel = panel

        if let window = window {
            window.beginSheet(panel, completionHandler: nil)
        }
    }

    private func updateProgress(_ progress: Double) {
        let clamped = max(0, min(progress, 1))
        progressBar?.doubleValue = clamped
        let pct = Int(clamped * 100)
        progressPercentLabel?.stringValue = "\(pct)%"

        // 细化阶段描述
        let status: String
        switch pct {
        case 0..<5:   status = "准备中…"
        case 5..<50:  status = "正在导出片段…"
        case 50..<95: status = "正在合成视频…"
        default:      status = "即将完成…"
        }
        progressLabel?.stringValue = status
    }

    private func handleExportResult(_ result: Result<[URL], Error>, outputDirectory: URL) {
        // 先关闭进度面板，再恢复按钮状态
        if let panel = progressPanel {
            window?.endSheet(panel)
            progressPanel = nil
            progressBar = nil
            progressLabel = nil
            progressPercentLabel = nil
        }
        setExportingState(false)

        switch result {
        case .success(let urls):
            let alert = NSAlert()
            alert.messageText = "导出成功！"
            alert.informativeText = "共导出 \(urls.count) 个文件\n保存位置：\(outputDirectory.path)"
            alert.addButton(withTitle: "在 Finder 中显示")
            alert.addButton(withTitle: "好的")
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                NSWorkspace.shared.activateFileViewerSelecting(urls)
            }

        case .failure(let error):
            // 用户主动取消：静默关闭，不弹错误提示
            if case VideoExporterError.cancelled = error { return }
            // 其他错误才弹提示
            showAlert(title: "导出失败", message: error.localizedDescription)
        }
    }

    // MARK: - 工具

    private func formatTime(_ seconds: Double) -> String {
        let s = Int(seconds)
        let m = s / 60
        let h = m / 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m % 60, s % 60) }
        return String(format: "%d:%02d", m, s % 60)
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "好的")
        if let window = window {
            alert.beginSheetModal(for: window, completionHandler: nil)
        } else {
            alert.runModal()
        }
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }
        player?.pause()
    }
}

// MARK: - TimelineViewDelegate

extension MainWindowController: TimelineViewDelegate {
    func timelineView(_ view: TimelineView, didUpdateSegments newSegments: [ClipSegment]) {
        segments = newSegments
        segmentTable.reloadData()
        updateSegmentCount()
    }

    func timelineView(_ view: TimelineView, didSeekTo time: CMTime) {
        player?.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    func timelineView(_ view: TimelineView, didSelectSegment segment: ClipSegment?) {
        selectedSegment = segment
        if let seg = segment, let idx = segments.firstIndex(where: { $0.id == seg.id }) {
            segmentTable.selectRowIndexes(IndexSet(integer: idx), byExtendingSelection: false)
        } else {
            segmentTable.deselectAll(nil)
        }
    }
}

// MARK: - NSTableViewDataSource / NSTableViewDelegate

extension MainWindowController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return segments.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let seg = segments[row]
        let cell = SegmentTableCellView(segment: seg, index: row)
        return cell
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 52
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        return true
    }
}

// MARK: - 片段单元格视图

final class SegmentTableCellView: NSView {
    init(segment: ClipSegment, index: Int) {
        super.init(frame: .zero)

        let colors: [NSColor] = [.systemBlue, .systemGreen, .systemYellow, .systemRed, .systemPurple]
        let color = colors[index % colors.count]

        let colorStrip = NSView()
        colorStrip.wantsLayer = true
        colorStrip.layer?.backgroundColor = color.cgColor
        colorStrip.layer?.cornerRadius = 2
        colorStrip.translatesAutoresizingMaskIntoConstraints = false
        addSubview(colorStrip)

        let nameLabel = NSTextField(labelWithString: segment.label.isEmpty ? "片段 \(index + 1)" : segment.label)
        nameLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        nameLabel.textColor = NSColor(white: 0.88, alpha: 1)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(nameLabel)

        let dur = segment.durationSeconds
        let durStr = formatTime(dur)
        let timeStr = "\(formatTime(segment.startSeconds)) → \(formatTime(segment.endSeconds))  [\(durStr)]"
        let timeLabel = NSTextField(labelWithString: timeStr)
        timeLabel.font = NSFont.monospacedSystemFont(ofSize: 10, weight: .regular)
        timeLabel.textColor = NSColor(white: 0.55, alpha: 1)
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(timeLabel)

        NSLayoutConstraint.activate([
            colorStrip.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            colorStrip.centerYAnchor.constraint(equalTo: centerYAnchor),
            colorStrip.widthAnchor.constraint(equalToConstant: 4),
            colorStrip.heightAnchor.constraint(equalToConstant: 36),

            nameLabel.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            nameLabel.leadingAnchor.constraint(equalTo: colorStrip.trailingAnchor, constant: 8),
            nameLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),

            timeLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            timeLabel.leadingAnchor.constraint(equalTo: colorStrip.trailingAnchor, constant: 8),
            timeLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    private func formatTime(_ seconds: Double) -> String {
        let s = Int(seconds)
        let m = s / 60
        let h = m / 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m % 60, s % 60) }
        return String(format: "%d:%02d", m, s % 60)
    }
}
