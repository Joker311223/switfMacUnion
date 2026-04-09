import AppKit
import AVFoundation
import CoreGraphics

// MARK: - 时间轴视图委托

protocol TimelineViewDelegate: AnyObject {
    func timelineView(_ view: TimelineView, didUpdateSegments segments: [ClipSegment])
    func timelineView(_ view: TimelineView, didSeekTo time: CMTime)
    func timelineView(_ view: TimelineView, didSelectSegment segment: ClipSegment?)
}

// MARK: - 时间轴视图

final class TimelineView: NSView {

    // MARK: - 公开属性

    weak var delegate: TimelineViewDelegate?

    var duration: CMTime = .zero {
        didSet { needsDisplay = true }
    }

    var currentTime: CMTime = .zero {
        didSet { needsDisplay = true }
    }

    var segments: [ClipSegment] = [] {
        didSet {
            needsDisplay = true
            delegate?.timelineView(self, didUpdateSegments: segments)
        }
    }

    var selectedSegmentID: UUID? {
        didSet { needsDisplay = true }
    }

    // 缩略图（视频帧）
    var thumbnails: [(CMTime, NSImage)] = [] {
        didSet { needsDisplay = true }
    }

    // MARK: - 私有状态

    private let trackHeight: CGFloat = 56
    private let rulerHeight: CGFloat = 24
    private let segmentBarY: CGFloat = 30  // 片段条距顶
    private let segmentBarH: CGFloat = 26  // 片段条高度

    private enum DragMode {
        case none
        case seekScrub
        case segmentStart(UUID)
        case segmentEnd(UUID)
        case segmentMove(UUID, startOffset: Double) // startOffset = drag start 对应的 segment.startSeconds
        case newSegment(startSeconds: Double)
    }

    private var dragMode: DragMode = .none
    private var newSegmentStartSeconds: Double = 0
    private var newSegmentEndSeconds: Double = 0
    private var isCreatingNewSegment = false

    // MARK: - 颜色定义

    private let trackBg = NSColor(white: 0.12, alpha: 1)
    private let rulerBg = NSColor(white: 0.18, alpha: 1)
    private let tickColor = NSColor(white: 0.45, alpha: 1)
    private let playheadColor = NSColor(red: 1, green: 0.3, blue: 0.3, alpha: 1)
    private let segmentColors: [NSColor] = [
        NSColor(red: 0.20, green: 0.65, blue: 1.00, alpha: 0.85),
        NSColor(red: 0.25, green: 0.85, blue: 0.55, alpha: 0.85),
        NSColor(red: 1.00, green: 0.75, blue: 0.20, alpha: 0.85),
        NSColor(red: 1.00, green: 0.45, blue: 0.45, alpha: 0.85),
        NSColor(red: 0.80, green: 0.45, blue: 1.00, alpha: 0.85),
    ]
    private let handleColor = NSColor.white
    private let newSegmentColor = NSColor(red: 1.0, green: 0.6, blue: 0.1, alpha: 0.5)

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
        layer?.backgroundColor = trackBg.cgColor
        layer?.cornerRadius = 6
    }

    // MARK: - 坐标转换

    private var totalDuration: Double {
        let d = CMTimeGetSeconds(duration)
        return d > 0 ? d : 1
    }

    private func xForTime(_ seconds: Double) -> CGFloat {
        return CGFloat(seconds / totalDuration) * bounds.width
    }

    private func timeForX(_ x: CGFloat) -> Double {
        let clamped = max(0, min(x, bounds.width))
        return Double(clamped / bounds.width) * totalDuration
    }

    // MARK: - 绘制

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        drawBackground(ctx)
        drawThumbnails(ctx)
        drawRuler(ctx)
        drawSegments(ctx)
        drawNewSegmentPreview(ctx)
        drawPlayhead(ctx)
    }

    private func drawBackground(_ ctx: CGContext) {
        trackBg.setFill()
        ctx.fill(bounds)
    }

    private func drawThumbnails(_ ctx: CGContext) {
        guard !thumbnails.isEmpty else { return }
        let thumbRect = CGRect(x: 0, y: rulerHeight, width: bounds.width, height: bounds.height - rulerHeight)
        for (time, image) in thumbnails {
            let t = CMTimeGetSeconds(time)
            let x = xForTime(t) - 30
            if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                let rect = CGRect(x: x, y: thumbRect.minY + 2, width: 60, height: thumbRect.height - 4)
                ctx.draw(cgImage, in: rect)
            }
        }
    }

    private func drawRuler(_ ctx: CGContext) {
        let rulerRect = CGRect(x: 0, y: 0, width: bounds.width, height: rulerHeight)
        rulerBg.setFill()
        ctx.fill(rulerRect)

        // 刻度
        let step = niceStep(totalDuration: totalDuration, width: Double(bounds.width))
        var t: Double = 0
        while t <= totalDuration {
            let x = xForTime(t)
            tickColor.setStroke()
            ctx.setLineWidth(1)
            ctx.beginPath()
            ctx.move(to: CGPoint(x: x, y: 0))
            ctx.addLine(to: CGPoint(x: x, y: rulerHeight * 0.6))
            ctx.strokePath()

            // 时间标签
            let label = formatTime(t)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: 9, weight: .regular),
                .foregroundColor: NSColor(white: 0.65, alpha: 1)
            ]
            let str = NSAttributedString(string: label, attributes: attrs)
            str.draw(at: CGPoint(x: x + 2, y: 4))

            t += step
        }
    }

    private func drawSegments(_ ctx: CGContext) {
        let barY = rulerHeight + CGFloat(segmentBarY) - rulerHeight
        // 实际片段条区域
        let segY: CGFloat = rulerHeight + 4
        let segH: CGFloat = bounds.height - rulerHeight - 8

        for (i, seg) in segments.enumerated() {
            let color = segmentColors[i % segmentColors.count]
            let x = xForTime(seg.startSeconds)
            let w = max(xForTime(seg.endSeconds) - x, 4)
            let rect = CGRect(x: x, y: segY, width: w, height: segH)

            // 选中高亮
            let isSelected = seg.id == selectedSegmentID
            if isSelected {
                NSColor.white.withAlphaComponent(0.15).setFill()
                ctx.fill(rect.insetBy(dx: -2, dy: -2))
            }

            // 片段主体
            color.setFill()
            let segPath = CGPath(
                roundedRect: rect,
                cornerWidth: 3,
                cornerHeight: 3,
                transform: nil
            )
            ctx.addPath(segPath)
            ctx.fillPath()

            // 边框
            ctx.addPath(segPath)
            ctx.setStrokeColor(isSelected ? NSColor.white.cgColor : color.withAlphaComponent(1).cgColor)
            ctx.setLineWidth(isSelected ? 1.5 : 0.5)
            ctx.strokePath()

            // 拖拽把手
            drawHandle(ctx, x: x, midY: segY + segH / 2, color: handleColor)
            drawHandle(ctx, x: x + w, midY: segY + segH / 2, color: handleColor)

            // 标签
            if w > 40 {
                let label = seg.displayName
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 10, weight: .medium),
                    .foregroundColor: NSColor.white
                ]
                let str = NSAttributedString(string: label, attributes: attrs)
                let strW = str.size().width
                if strW < w - 16 {
                    str.draw(at: CGPoint(x: x + (w - strW) / 2, y: segY + (segH - 12) / 2))
                }
            }
        }

        _ = barY // suppress warning
    }

    private func drawHandle(_ ctx: CGContext, x: CGFloat, midY: CGFloat, color: NSColor) {
        let hw: CGFloat = 4
        let hh: CGFloat = 16
        let rect = CGRect(x: x - hw / 2, y: midY - hh / 2, width: hw, height: hh)
        color.withAlphaComponent(0.8).setFill()
        let path = CGPath(roundedRect: rect, cornerWidth: 2, cornerHeight: 2, transform: nil)
        ctx.addPath(path)
        ctx.fillPath()
    }

    private func drawNewSegmentPreview(_ ctx: CGContext) {
        guard isCreatingNewSegment else { return }
        let s = min(newSegmentStartSeconds, newSegmentEndSeconds)
        let e = max(newSegmentStartSeconds, newSegmentEndSeconds)
        let x = xForTime(s)
        let w = xForTime(e) - x
        guard w > 2 else { return }

        let segY: CGFloat = rulerHeight + 4
        let segH: CGFloat = bounds.height - rulerHeight - 8
        let rect = CGRect(x: x, y: segY, width: w, height: segH)
        newSegmentColor.setFill()
        ctx.fill(rect)

        // 虚线边框
        ctx.setStrokeColor(NSColor.orange.cgColor)
        ctx.setLineWidth(1.5)
        ctx.setLineDash(phase: 0, lengths: [4, 3])
        ctx.stroke(rect)
        ctx.setLineDash(phase: 0, lengths: [])
    }

    private func drawPlayhead(_ ctx: CGContext) {
        let x = xForTime(CMTimeGetSeconds(currentTime))
        playheadColor.setStroke()
        ctx.setLineWidth(2)
        ctx.beginPath()
        ctx.move(to: CGPoint(x: x, y: 0))
        ctx.addLine(to: CGPoint(x: x, y: bounds.height))
        ctx.strokePath()

        // 三角形头
        playheadColor.setFill()
        let triSize: CGFloat = 7
        ctx.beginPath()
        ctx.move(to: CGPoint(x: x - triSize, y: bounds.height - 2))
        ctx.addLine(to: CGPoint(x: x + triSize, y: bounds.height - 2))
        ctx.addLine(to: CGPoint(x: x, y: bounds.height - 2 - triSize * 1.3))
        ctx.closePath()
        ctx.fillPath()
    }

    // MARK: - 鼠标事件

    override func mouseDown(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        let t = timeForX(loc.x)

        // 检查是否点击了某个片段的把手或主体
        if let (segID, hitPart) = hitTest(at: loc) {
            selectedSegmentID = segID
            delegate?.timelineView(self, didSelectSegment: segments.first(where: { $0.id == segID }))
            switch hitPart {
            case .startHandle:
                dragMode = .segmentStart(segID)
            case .endHandle:
                dragMode = .segmentEnd(segID)
            case .body:
                let seg = segments.first(where: { $0.id == segID })!
                dragMode = .segmentMove(segID, startOffset: t - seg.startSeconds)
            }
            return
        }

        // 标尺区域 → scrub
        if loc.y < rulerHeight {
            dragMode = .seekScrub
            seek(to: t)
            return
        }

        // 空白区域 → 开始新建片段
        if event.clickCount == 2 {
            // 双击：seek
            dragMode = .seekScrub
            seek(to: t)
        } else {
            isCreatingNewSegment = true
            newSegmentStartSeconds = t
            newSegmentEndSeconds = t
            dragMode = .newSegment(startSeconds: t)
            needsDisplay = true
        }
    }

    override func mouseDragged(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        let t = timeForX(loc.x)

        switch dragMode {
        case .seekScrub:
            seek(to: t)

        case .segmentStart(let id):
            updateSegment(id: id) { seg in
                let newStart = min(t, seg.endSeconds - 0.1)
                seg.startTime = CMTimeMakeWithSeconds(max(0, newStart), preferredTimescale: 600)
            }

        case .segmentEnd(let id):
            updateSegment(id: id) { seg in
                let newEnd = max(t, seg.startSeconds + 0.1)
                seg.endTime = CMTimeMakeWithSeconds(min(newEnd, totalDuration), preferredTimescale: 600)
            }

        case .segmentMove(let id, let startOffset):
            updateSegment(id: id) { seg in
                let dur = seg.durationSeconds
                var newStart = t - startOffset
                newStart = max(0, min(newStart, totalDuration - dur))
                seg.startTime = CMTimeMakeWithSeconds(newStart, preferredTimescale: 600)
                seg.endTime = CMTimeMakeWithSeconds(newStart + dur, preferredTimescale: 600)
            }

        case .newSegment:
            newSegmentEndSeconds = max(0, min(t, totalDuration))
            needsDisplay = true

        case .none:
            break
        }
    }

    override func mouseUp(with event: NSEvent) {
        if case .newSegment = dragMode {
            let s = min(newSegmentStartSeconds, newSegmentEndSeconds)
            let e = max(newSegmentStartSeconds, newSegmentEndSeconds)
            if e - s > 0.1 {
                let seg = ClipSegment(
                    startTime: CMTimeMakeWithSeconds(s, preferredTimescale: 600),
                    endTime: CMTimeMakeWithSeconds(e, preferredTimescale: 600),
                    label: "片段 \(segments.count + 1)"
                )
                segments.append(seg)
                selectedSegmentID = seg.id
                delegate?.timelineView(self, didSelectSegment: seg)
            }
            isCreatingNewSegment = false
            needsDisplay = true
        }
        dragMode = .none
    }

    // MARK: - 辅助方法

    private enum HitPart { case startHandle, endHandle, body }

    private func hitTest(at point: CGPoint) -> (UUID, HitPart)? {
        let segY: CGFloat = rulerHeight + 4
        let segH: CGFloat = bounds.height - rulerHeight - 8
        guard point.y >= segY && point.y <= segY + segH else { return nil }

        for seg in segments.reversed() {
            let x = xForTime(seg.startSeconds)
            let w = xForTime(seg.endSeconds) - x
            let handleW: CGFloat = 10

            if abs(point.x - x) < handleW {
                return (seg.id, .startHandle)
            }
            if abs(point.x - (x + w)) < handleW {
                return (seg.id, .endHandle)
            }
            if point.x > x && point.x < x + w {
                return (seg.id, .body)
            }
        }
        return nil
    }

    private func updateSegment(id: UUID, transform: (inout ClipSegment) -> Void) {
        guard let idx = segments.firstIndex(where: { $0.id == id }) else { return }
        transform(&segments[idx])
        needsDisplay = true
        delegate?.timelineView(self, didUpdateSegments: segments)
    }

    private func seek(to seconds: Double) {
        let t = CMTimeMakeWithSeconds(max(0, min(seconds, totalDuration)), preferredTimescale: 600)
        currentTime = t
        delegate?.timelineView(self, didSeekTo: t)
    }

    private func niceStep(totalDuration: Double, width: Double) -> Double {
        let steps: [Double] = [0.5, 1, 2, 5, 10, 15, 30, 60, 120, 300, 600]
        let targetCount = width / 80
        let rawStep = totalDuration / targetCount
        return steps.first(where: { $0 >= rawStep }) ?? steps.last!
    }

    private func formatTime(_ seconds: Double) -> String {
        let s = Int(seconds)
        let m = s / 60
        let h = m / 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m % 60, s % 60)
        }
        if m > 0 {
            return String(format: "%d:%02d", m, s % 60)
        }
        return String(format: "%.1fs", seconds)
    }

    // MARK: - 公开操作

    func removeSelectedSegment() {
        guard let id = selectedSegmentID else { return }
        segments.removeAll { $0.id == id }
        selectedSegmentID = nil
        delegate?.timelineView(self, didSelectSegment: nil)
    }

    func addSegmentAtCurrentTime() {
        let cur = CMTimeGetSeconds(currentTime)
        let end = min(cur + 5, totalDuration)
        guard end > cur + 0.1 else { return }
        let seg = ClipSegment(
            startTime: CMTimeMakeWithSeconds(cur, preferredTimescale: 600),
            endTime: CMTimeMakeWithSeconds(end, preferredTimescale: 600),
            label: "片段 \(segments.count + 1)"
        )
        segments.append(seg)
        selectedSegmentID = seg.id
        delegate?.timelineView(self, didSelectSegment: seg)
    }

    func clearAllSegments() {
        segments = []
        selectedSegmentID = nil
        delegate?.timelineView(self, didSelectSegment: nil)
    }
}
