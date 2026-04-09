import Foundation
import AVFoundation

// MARK: - 裁剪区间模型

struct ClipSegment: Identifiable, Equatable {
    let id: UUID
    var startTime: CMTime
    var endTime: CMTime
    var label: String

    init(startTime: CMTime, endTime: CMTime, label: String = "") {
        self.id = UUID()
        self.startTime = startTime
        self.endTime = endTime
        self.label = label
    }

    var duration: CMTime {
        CMTimeSubtract(endTime, startTime)
    }

    var durationSeconds: Double {
        CMTimeGetSeconds(duration)
    }

    var startSeconds: Double {
        CMTimeGetSeconds(startTime)
    }

    var endSeconds: Double {
        CMTimeGetSeconds(endTime)
    }

    var timeRange: CMTimeRange {
        CMTimeRangeMake(start: startTime, duration: duration)
    }

    var displayName: String {
        if !label.isEmpty { return label }
        return "片段 \(formatTime(startSeconds)) - \(formatTime(endSeconds))"
    }

    private func formatTime(_ seconds: Double) -> String {
        let s = Int(seconds)
        let m = s / 60
        let h = m / 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m % 60, s % 60)
        }
        return String(format: "%d:%02d", m, s % 60)
    }
}

// MARK: - 保存模式

enum SaveMode {
    case individual     // 将各片段单独保存
    case merged         // 将所有片段拼接为一个视频保存
    case both           // 两者都保存
}
