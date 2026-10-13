import AVFoundation
import AVKit
import CoreVideo
import SwiftUI
import UIKit

@MainActor
final class TranslationPiPController: NSObject, ObservableObject, AVPictureInPictureControllerDelegate, AVPictureInPictureSampleBufferPlaybackDelegate {
    @Published private(set) var isActive = false
    @Published private(set) var status = "译文小窗未开启"

    let displayLayer = AVSampleBufferDisplayLayer()
    private var pipController: AVPictureInPictureController?
    private let width = 720
    private let height = 420

    override init() {
        super.init()
        displayLayer.videoGravity = .resizeAspect
        displayLayer.backgroundColor = UIColor(red: 0.96, green: 0.96, blue: 0.93, alpha: 1).cgColor
    }

    func start() {
        guard AVPictureInPictureController.isPictureInPictureSupported() else {
            status = "此设备当前不支持画中画"
            return
        }
        if pipController == nil {
            let source = AVPictureInPictureController.ContentSource(
                sampleBufferDisplayLayer: displayLayer,
                playbackDelegate: self
            )
            let controller = AVPictureInPictureController(contentSource: source)
            controller.delegate = self
            controller.requiresLinearPlayback = true
            controller.canStartPictureInPictureAutomaticallyFromInline = true
            pipController = controller
        }

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            status = "画中画音频会话启动失败：\(error.localizedDescription)"
            return
        }

        renderCard(original: "词伴正在实时读屏", translated: "切换到微信词达人开始学习。")
        status = "正在准备译文小窗…"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self, let controller = self.pipController else { return }
            guard controller.isPictureInPicturePossible else {
                self.status = "画中画尚未就绪，请稍后再试"
                return
            }
            controller.startPictureInPicture()
        }
    }

    func stop() {
        pipController?.stopPictureInPicture()
    }

    func update(original: String, translated: String) {
        guard isActive else { return }
        renderCard(original: original, translated: translated)
    }

    func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        isActive = true
        status = "译文小窗已开启"
    }

    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        isActive = false
        status = "译文小窗已关闭"
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        failedToStartPictureInPictureWithError error: any Error
    ) {
        isActive = false
        status = "译文小窗启动失败：\(error.localizedDescription)"
    }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, setPlaying playing: Bool) {}

    func pictureInPictureControllerTimeRangeForPlayback(_ pictureInPictureController: AVPictureInPictureController) -> CMTimeRange {
        CMTimeRange(start: .zero, duration: .positiveInfinity)
    }

    func pictureInPictureControllerIsPlaybackPaused(_ pictureInPictureController: AVPictureInPictureController) -> Bool { false }

    func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        didTransitionToRenderSize newRenderSize: CMVideoDimensions
    ) {}

    func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        skipByInterval interval: CMTime,
        completion: @escaping () -> Void
    ) {
        completion()
    }

    func pictureInPictureControllerShouldProhibitBackgroundAudioPlayback(_ pictureInPictureController: AVPictureInPictureController) -> Bool { true }

    private func renderCard(original: String, translated: String) {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        let image = renderer.image { context in
            let rect = CGRect(x: 0, y: 0, width: width, height: height)
            UIColor(red: 0.96, green: 0.96, blue: 0.93, alpha: 1).setFill()
            context.fill(rect)

            let badge = "词伴 · 实时翻译"
            (badge as NSString).draw(
                in: CGRect(x: 34, y: 28, width: width - 68, height: 38),
                withAttributes: [
                    .font: UIFont.systemFont(ofSize: 24, weight: .semibold),
                    .foregroundColor: UIColor(red: 0.22, green: 0.36, blue: 0.30, alpha: 1)
                ]
            )
            (String(original.prefix(100)) as NSString).draw(
                in: CGRect(x: 34, y: 92, width: width - 68, height: 112),
                withAttributes: [
                    .font: UIFont.systemFont(ofSize: 27, weight: .medium),
                    .foregroundColor: UIColor.darkText
                ]
            )
            (String(translated.prefix(100)) as NSString).draw(
                in: CGRect(x: 34, y: 230, width: width - 68, height: 150),
                withAttributes: [
                    .font: UIFont.systemFont(ofSize: 29, weight: .semibold),
                    .foregroundColor: UIColor(red: 0.22, green: 0.36, blue: 0.30, alpha: 1)
                ]
            )
        }
        guard let cgImage = image.cgImage,
              let pixelBuffer = makePixelBuffer(from: cgImage) else { return }

        var formatDescription: CMVideoFormatDescription?
        guard CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescriptionOut: &formatDescription
        ) == noErr, let formatDescription else { return }

        var timing = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: 2),
            presentationTimeStamp: CMClockGetTime(CMClockGetHostTimeClock()),
            decodeTimeStamp: .invalid
        )
        var sampleBuffer: CMSampleBuffer?
        guard CMSampleBufferCreateReadyWithImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescription: formatDescription,
            sampleTiming: &timing,
            sampleBufferOut: &sampleBuffer
        ) == noErr, let sampleBuffer else { return }

        displayLayer.flush()
        displayLayer.enqueue(sampleBuffer)
    }

    private func makePixelBuffer(from image: CGImage) -> CVPixelBuffer? {
        let attributes: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32ARGB,
            kCVPixelBufferWidthKey: width,
            kCVPixelBufferHeightKey: height
        ]
        var pixelBuffer: CVPixelBuffer?
        guard CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32ARGB,
            attributes as CFDictionary,
            &pixelBuffer
        ) == kCVReturnSuccess,
              let pixelBuffer else { return nil }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer),
              let context = CGContext(
                data: baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
              ) else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return pixelBuffer
    }
}

struct SampleBufferLayerHost: UIViewRepresentable {
    let displayLayer: AVSampleBufferDisplayLayer

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .clear
        view.layer.addSublayer(displayLayer)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        displayLayer.frame = uiView.bounds
    }
}
