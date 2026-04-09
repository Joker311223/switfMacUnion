import Foundation
import AVFoundation
import AppKit

// MARK: - 导出进度回调

typealias ExportProgressHandler = (Double) -> Void
typealias ExportCompletionHandler = (Result<[URL], Error>) -> Void

// MARK: - 视频导出错误

enum VideoExporterError: LocalizedError {
    case noSegments
    case invalidAsset
    case exportFailed(String)
    case compositionError(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .noSegments:
            return "没有选择任何裁剪区间"
        case .invalidAsset:
            return "视频文件无效"
        case .exportFailed(let msg):
            return "导出失败：\(msg)"
        case .compositionError(let msg):
            return "合成失败：\(msg)"
        case .cancelled:
            return "已取消导出"
        }
    }
}

// MARK: - 视频导出器（实例类，支持取消）

final class VideoExporter {

    // 当前正在执行的导出会话（用于取消）
    private var currentSession: AVAssetExportSession?
    // 取消标志：用于中断批量导出的递归链
    private var isCancelled = false

    // MARK: - 取消

    func cancel() {
        isCancelled = true
        currentSession?.cancelExport()
    }

    // MARK: - 单段导出

    func exportSegment(
        asset: AVAsset,
        segment: ClipSegment,
        outputURL: URL,
        progress: @escaping ExportProgressHandler,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        guard !isCancelled else {
            completion(.failure(VideoExporterError.cancelled))
            return
        }

        guard let session = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            completion(.failure(VideoExporterError.exportFailed("无法创建导出会话")))
            return
        }

        currentSession = session
        session.outputURL = outputURL
        session.outputFileType = .mp4
        session.timeRange = segment.timeRange
        session.shouldOptimizeForNetworkUse = true

        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak session] timer in
            guard let session = session else { timer.invalidate(); return }
            progress(Double(session.progress))
            if session.status != .exporting { timer.invalidate() }
        }

        session.exportAsynchronously { [weak self] in
            timer.invalidate()
            DispatchQueue.main.async {
                guard let self = self else { return }
                // 无论结果，清空 currentSession 引用
                self.currentSession = nil

                if self.isCancelled || session.status == .cancelled {
                    completion(.failure(VideoExporterError.cancelled))
                    return
                }
                switch session.status {
                case .completed:
                    completion(.success(outputURL))
                case .failed:
                    let msg = session.error?.localizedDescription ?? "未知错误"
                    completion(.failure(VideoExporterError.exportFailed(msg)))
                default:
                    completion(.failure(VideoExporterError.exportFailed("导出状态异常")))
                }
            }
        }
    }

    // MARK: - 多段批量导出（各自独立文件）

    func exportIndividual(
        asset: AVAsset,
        segments: [ClipSegment],
        outputDirectory: URL,
        originalFileName: String,
        overallProgress: @escaping ExportProgressHandler,
        completion: @escaping ExportCompletionHandler
    ) {
        guard !segments.isEmpty else {
            completion(.failure(VideoExporterError.noSegments))
            return
        }

        var resultURLs: [URL] = []
        var currentIndex = 0

        func exportNext() {
            // 检查取消标志
            if isCancelled {
                completion(.failure(VideoExporterError.cancelled))
                return
            }

            guard currentIndex < segments.count else {
                completion(.success(resultURLs))
                return
            }

            let segment = segments[currentIndex]
            let index = currentIndex
            let filename = "\(originalFileName)_clip\(String(format: "%02d", index + 1)).mp4"
            let outputURL = outputDirectory.appendingPathComponent(filename)
            try? FileManager.default.removeItem(at: outputURL)

            exportSegment(
                asset: asset,
                segment: segment,
                outputURL: outputURL,
                progress: { segProg in
                    let overall = (Double(index) + segProg) / Double(segments.count)
                    overallProgress(overall)
                },
                completion: { result in
                    switch result {
                    case .success(let url):
                        resultURLs.append(url)
                        currentIndex += 1
                        exportNext()
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
            )
        }

        exportNext()
    }

    // MARK: - 合并导出（拼接所有片段为单一视频）

    func exportMerged(
        asset: AVAsset,
        segments: [ClipSegment],
        outputURL: URL,
        progress: @escaping ExportProgressHandler,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        guard !segments.isEmpty else {
            completion(.failure(VideoExporterError.noSegments))
            return
        }
        guard !isCancelled else {
            completion(.failure(VideoExporterError.cancelled))
            return
        }

        let composition = AVMutableComposition()

        guard let videoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            completion(.failure(VideoExporterError.compositionError("无法创建视频轨道")))
            return
        }

        var audioTrack: AVMutableCompositionTrack?
        let hasAudio = !asset.tracks(withMediaType: .audio).isEmpty
        if hasAudio {
            audioTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            )
        }

        var insertTime = CMTime.zero

        do {
            for segment in segments {
                let timeRange = segment.timeRange
                if let sourceVideoTrack = asset.tracks(withMediaType: .video).first {
                    try videoTrack.insertTimeRange(timeRange, of: sourceVideoTrack, at: insertTime)
                }
                if let sourceAudioTrack = asset.tracks(withMediaType: .audio).first,
                   let audioTrack = audioTrack {
                    try audioTrack.insertTimeRange(timeRange, of: sourceAudioTrack, at: insertTime)
                }
                insertTime = CMTimeAdd(insertTime, segment.duration)
            }
        } catch {
            completion(.failure(VideoExporterError.compositionError(error.localizedDescription)))
            return
        }

        if let sourceVideoTrack = asset.tracks(withMediaType: .video).first {
            let instruction = AVMutableVideoCompositionInstruction()
            instruction.timeRange = CMTimeRangeMake(start: .zero, duration: composition.duration)
            let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
            layerInstruction.setTransform(sourceVideoTrack.preferredTransform, at: .zero)
            instruction.layerInstructions = [layerInstruction]

            let videoComposition = AVMutableVideoComposition()
            videoComposition.instructions = [instruction]

            let naturalSize = sourceVideoTrack.naturalSize
            let transform = sourceVideoTrack.preferredTransform
            let transformedSize = naturalSize.applying(transform)
            let renderWidth = abs(transformedSize.width)
            let renderHeight = abs(transformedSize.height)
            videoComposition.renderSize = CGSize(
                width: renderWidth > 0 ? renderWidth : naturalSize.width,
                height: renderHeight > 0 ? renderHeight : naturalSize.height
            )
            videoComposition.frameDuration = CMTime(value: 1, timescale: 30)

            exportComposition(
                composition: composition,
                videoComposition: videoComposition,
                outputURL: outputURL,
                progress: progress,
                completion: completion
            )
        } else {
            exportComposition(
                composition: composition,
                videoComposition: nil,
                outputURL: outputURL,
                progress: progress,
                completion: completion
            )
        }
    }

    // MARK: - 内部：导出 Composition

    private func exportComposition(
        composition: AVComposition,
        videoComposition: AVVideoComposition?,
        outputURL: URL,
        progress: @escaping ExportProgressHandler,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        guard !isCancelled else {
            completion(.failure(VideoExporterError.cancelled))
            return
        }

        guard let session = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            completion(.failure(VideoExporterError.exportFailed("无法创建导出会话")))
            return
        }

        currentSession = session
        try? FileManager.default.removeItem(at: outputURL)
        session.outputURL = outputURL
        session.outputFileType = .mp4
        session.shouldOptimizeForNetworkUse = true
        if let vc = videoComposition { session.videoComposition = vc }

        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak session] timer in
            guard let session = session else { timer.invalidate(); return }
            progress(Double(session.progress))
            if session.status != .exporting { timer.invalidate() }
        }

        session.exportAsynchronously { [weak self] in
            timer.invalidate()
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.currentSession = nil

                if self.isCancelled || session.status == .cancelled {
                    completion(.failure(VideoExporterError.cancelled))
                    return
                }
                switch session.status {
                case .completed:
                    completion(.success(outputURL))
                case .failed:
                    let msg = session.error?.localizedDescription ?? "未知错误"
                    completion(.failure(VideoExporterError.exportFailed(msg)))
                default:
                    completion(.failure(VideoExporterError.exportFailed("导出状态异常")))
                }
            }
        }
    }

    // MARK: - Both 模式

    func exportBoth(
        asset: AVAsset,
        segments: [ClipSegment],
        outputDirectory: URL,
        originalFileName: String,
        overallProgress: @escaping ExportProgressHandler,
        completion: @escaping ExportCompletionHandler
    ) {
        guard !segments.isEmpty else {
            completion(.failure(VideoExporterError.noSegments))
            return
        }

        var allURLs: [URL] = []

        exportIndividual(
            asset: asset,
            segments: segments,
            outputDirectory: outputDirectory,
            originalFileName: originalFileName,
            overallProgress: { p in overallProgress(p * 0.5) },
            completion: { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .failure(let error):
                    completion(.failure(error))
                case .success(let urls):
                    allURLs.append(contentsOf: urls)

                    if self.isCancelled {
                        completion(.failure(VideoExporterError.cancelled))
                        return
                    }

                    let mergedFileName = "\(originalFileName)_merged.mp4"
                    let mergedURL = outputDirectory.appendingPathComponent(mergedFileName)

                    self.exportMerged(
                        asset: asset,
                        segments: segments,
                        outputURL: mergedURL,
                        progress: { p in overallProgress(0.5 + p * 0.5) },
                        completion: { result in
                            switch result {
                            case .failure(let error):
                                completion(.failure(error))
                            case .success(let url):
                                allURLs.append(url)
                                completion(.success(allURLs))
                            }
                        }
                    )
                }
            }
        )
    }
}
