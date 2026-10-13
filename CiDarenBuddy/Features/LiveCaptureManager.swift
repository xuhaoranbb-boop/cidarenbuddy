import Combine
import CoreMedia
import Foundation
import ScreenCaptureKit
import Vision

final class LiveCaptureManager: NSObject, ObservableObject, SCContentSharingPickerObserver, SCStreamOutput, SCStreamDelegate {
    @Published private(set) var status = "尚未开始"
    @Published private(set) var recognizedLines: [String] = []
    @Published private(set) var processedFrameCount = 0
    @Published private(set) var lastOCRLatencyMilliseconds: Int?

    private var stream: SCStream?
    private let frameQueue = DispatchQueue(label: "app.cidarenbuddy.frames", qos: .userInitiated)
    private let frameLock = NSLock()
    private var isProcessingFrame = false
    func startPicker() {
        if #available(iOS 27.0, *) {
            DispatchQueue.main.async {
                let picker = SCContentSharingPicker.shared
                picker.add(self)
                picker.present()
                self.status = "等待你在系统窗口中选择整个屏幕…"
            }
        } else {
            status = "实时读屏需要 iOS 27 或更新版本。"
        }
    }

    func stop() {
        guard let activeStream = stream else {
            status = "尚未开始"
            return
        }
        Task {
            do {
                try await activeStream.stopCapture()
            } catch {
                DispatchQueue.main.async { self.status = "停止共享时出错：\(error.localizedDescription)" }
            }
            DispatchQueue.main.async {
                self.stream = nil
                self.status = "已停止屏幕共享"
            }
        }
    }

    func contentSharingPicker(_ picker: SCContentSharingPicker, didUpdateWith filter: SCContentFilter, for stream: SCStream?) {
        guard #available(iOS 27.0, *) else { return }
        DispatchQueue.main.async {
            self.status = "正在启动实时识别…"
            Task { await self.startStream(using: filter) }
        }
    }

    func contentSharingPicker(_ picker: SCContentSharingPicker, didCancelFor stream: SCStream?) {
        DispatchQueue.main.async { self.status = "已取消屏幕共享" }
    }

    func contentSharingPickerStartDidFailWithError(_ error: any Error) {
        DispatchQueue.main.async { self.status = "系统屏幕共享启动失败：\(error.localizedDescription)" }
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, sampleBuffer.isValid, let pixelBuffer = sampleBuffer.imageBuffer else { return }

        frameLock.lock()
        guard !isProcessingFrame else {
            frameLock.unlock()
            return
        }
        isProcessingFrame = true
        frameLock.unlock()
        let frameReceivedAt = CFAbsoluteTimeGetCurrent()

        frameQueue.async { [weak self] in
            guard let self else { return }
            defer {
                self.frameLock.lock()
                self.isProcessingFrame = false
                self.frameLock.unlock()
            }
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .fast
            request.recognitionLanguages = ["en-US", "zh-Hans", "zh-Hant"]
            request.usesLanguageCorrection = false
            do {
                try VNImageRequestHandler(cvPixelBuffer: pixelBuffer).perform([request])
                let ocrLatencyMilliseconds = Int((CFAbsoluteTimeGetCurrent() - frameReceivedAt) * 1_000)
                let observations = request.results ?? []
                let pipBadge = observations.first { observation in
                    guard let text = observation.topCandidates(1).first?.string else { return false }
                    return text.contains("词伴") && text.contains("实时翻译")
                }?.boundingBox
                let pipCard = pipBadge?.insetBy(dx: -0.24, dy: -0.20)
                let lines = observations
                    .filter { observation in
                        guard let pipCard else { return true }
                        return !observation.boundingBox.intersects(pipCard)
                    }
                    .sorted {
                        if abs($0.boundingBox.midY - $1.boundingBox.midY) > 0.012 {
                            return $0.boundingBox.midY > $1.boundingBox.midY
                        }
                        return $0.boundingBox.minX < $1.boundingBox.minX
                    }
                    .compactMap { $0.topCandidates(1).first?.string }
                    .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                DispatchQueue.main.async {
                    if self.recognizedLines != lines { self.recognizedLines = lines }
                    self.processedFrameCount += 1
                    self.lastOCRLatencyMilliseconds = ocrLatencyMilliseconds
                    self.status = "实时共享中 · OCR \(ocrLatencyMilliseconds) ms · \(lines.count) 行"
                }
            } catch {
                DispatchQueue.main.async { self.status = "文字识别出错：\(error.localizedDescription)" }
            }
        }
    }

    func stream(_ stream: SCStream, didStopWithError error: any Error) {
        DispatchQueue.main.async {
            self.stream = nil
            self.status = "屏幕共享已结束：\(error.localizedDescription)"
        }
    }

    @available(iOS 27.0, *)
    private func startStream(using filter: SCContentFilter) async {
        if let stream { try? await stream.stopCapture() }

        let configuration = SCStreamConfiguration()
        configuration.width = 900
        configuration.height = 1950
        configuration.capturesAudio = false

        let newStream = SCStream(filter: filter, configuration: configuration, delegate: self)
        do {
            try newStream.addStreamOutput(self, type: .screen, sampleHandlerQueue: frameQueue)
            stream = newStream
            try await newStream.startCapture()
            DispatchQueue.main.async { self.status = "实时共享中 · 切到微信词达人即可识别" }
        } catch {
            stream = nil
            DispatchQueue.main.async { self.status = "无法启动屏幕识别：\(error.localizedDescription)" }
        }
    }
}
