import AppKit
import AVFoundation
import AVKit

// MARK: - 视频播放视图

final class VideoPlayerView: NSView {

    // MARK: - 属性

    private let playerLayer = AVPlayerLayer()
    var player: AVPlayer? {
        get { playerLayer.player }
        set { playerLayer.player = newValue }
    }

    // 是否正在播放
    var isPlaying: Bool {
        guard let player = player else { return false }
        return player.rate != 0
    }

    // MARK: - 初始化

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        layer?.cornerRadius = 6

        playerLayer.videoGravity = .resizeAspect
        playerLayer.backgroundColor = NSColor.black.cgColor
        layer?.addSublayer(playerLayer)
    }

    // MARK: - 布局

    override func layout() {
        super.layout()
        playerLayer.frame = bounds
    }

    // MARK: - 空状态占位

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // 仅在无视频时显示占位提示
        guard player == nil || player?.currentItem == nil else { return }

        let text = "拖拽视频文件到此处\n或点击「打开视频」"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 18, weight: .light),
            .foregroundColor: NSColor(white: 0.45, alpha: 1),
            .paragraphStyle: {
                let ps = NSMutableParagraphStyle()
                ps.alignment = .center
                ps.lineSpacing = 6
                return ps
            }()
        ]
        let str = NSAttributedString(string: text, attributes: attrs)
        let strSize = str.size()
        let strRect = CGRect(
            x: (bounds.width - strSize.width) / 2,
            y: (bounds.height - strSize.height) / 2,
            width: strSize.width,
            height: strSize.height
        )
        str.draw(in: strRect)

        // 图标
        let iconStr = NSAttributedString(string: "🎬", attributes: [
            .font: NSFont.systemFont(ofSize: 56)
        ])
        let iconSize = iconStr.size()
        iconStr.draw(at: CGPoint(
            x: (bounds.width - iconSize.width) / 2,
            y: strRect.maxY + 12
        ))
    }

    // MARK: - 拖拽支持

    override func awakeFromNib() {
        super.awakeFromNib()
        registerForDraggedTypes([.fileURL])
    }

    func registerDrag() {
        registerForDraggedTypes([.fileURL])
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if let url = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self])?.first as? URL,
           isVideoFile(url) {
            layer?.borderColor = NSColor.systemBlue.cgColor
            layer?.borderWidth = 2
            return .copy
        }
        return []
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        layer?.borderColor = nil
        layer?.borderWidth = 0
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        layer?.borderColor = nil
        layer?.borderWidth = 0
        if let url = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self])?.first as? URL,
           isVideoFile(url) {
            NotificationCenter.default.post(
                name: .videoDropped,
                object: nil,
                userInfo: ["url": url]
            )
            return true
        }
        return false
    }

    private func isVideoFile(_ url: URL) -> Bool {
        let videoExtensions = ["mp4", "mov", "m4v", "avi", "mkv", "wmv", "flv", "webm", "mpeg", "mpg"]
        return videoExtensions.contains(url.pathExtension.lowercased())
    }
}

// MARK: - Notification 扩展

extension Notification.Name {
    static let videoDropped = Notification.Name("VideoDropped")
}
