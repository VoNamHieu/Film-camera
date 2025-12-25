//
//  VideoRecorder.swift
//  Film Camera
//
//  Video recording with real-time filter application
//  Uses optimized 2-pass pipeline for 30fps performance
//

import AVFoundation
import Metal
import CoreMedia
import Photos

// MARK: - Video Recorder Delegate

protocol VideoRecorderDelegate: AnyObject {
    func videoRecorderDidStartRecording(_ recorder: VideoRecorder)
    func videoRecorderDidStopRecording(_ recorder: VideoRecorder, outputURL: URL)
    func videoRecorderDidFail(_ recorder: VideoRecorder, error: Error)
    func videoRecorderDurationUpdated(_ recorder: VideoRecorder, duration: TimeInterval)
}

// MARK: - Video Recorder

final class VideoRecorder {

    // MARK: - Properties

    weak var delegate: VideoRecorderDelegate?

    private(set) var isRecording = false
    private(set) var recordingDuration: TimeInterval = 0

    // AVAssetWriter components
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?

    // Recording state
    private var recordingURL: URL?
    private var startTime: CMTime?
    private var currentPreset: FilterPreset?

    // Pixel buffer pool for filtered frames
    private var pixelBufferPool: CVPixelBufferPool?
    private var poolWidth: Int = 0
    private var poolHeight: Int = 0

    // Metal resources
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let filterRenderer: FilterRenderer
    private var metalTextureCache: CVMetalTextureCache?

    // Thread safety
    private let recordingQueue = DispatchQueue(label: "com.filmcamera.video.recording", qos: .userInitiated)
    private let writingQueue = DispatchQueue(label: "com.filmcamera.video.writing", qos: .userInitiated)

    // Timer for duration updates
    private var durationTimer: Timer?

    // MARK: - Configuration

    struct VideoSettings {
        var width: Int = 1920
        var height: Int = 1080
        var frameRate: Int = 30
        var bitRate: Int = 10_000_000 // 10 Mbps
        var codec: AVVideoCodecType = .h264
    }

    struct AudioSettings {
        var sampleRate: Double = 44100
        var channels: Int = 1
        var bitRate: Int = 128_000 // 128 kbps
    }

    private var videoSettings = VideoSettings()
    private var audioSettings = AudioSettings()

    // MARK: - Initialization

    init?() {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue() else {
            print("❌ VideoRecorder: Failed to create Metal device")
            return nil
        }

        self.device = device
        self.commandQueue = commandQueue
        self.filterRenderer = FilterRenderer()

        // Create Metal texture cache
        var textureCache: CVMetalTextureCache?
        let status = CVMetalTextureCacheCreate(nil, nil, device, nil, &textureCache)
        guard status == kCVReturnSuccess, let cache = textureCache else {
            print("❌ VideoRecorder: Failed to create texture cache")
            return nil
        }
        self.metalTextureCache = cache

        print("✅ VideoRecorder: Initialized")
    }

    deinit {
        stopRecording()
    }

    // MARK: - Public Methods

    /// Start recording video with the specified filter preset
    func startRecording(preset: FilterPreset, size: CGSize? = nil) {
        guard !isRecording else {
            print("⚠️ VideoRecorder: Already recording")
            return
        }

        recordingQueue.async { [weak self] in
            self?.setupAndStartRecording(preset: preset, size: size)
        }
    }

    /// Stop recording and finalize the video file
    func stopRecording() {
        guard isRecording else { return }

        recordingQueue.async { [weak self] in
            self?.finalizeRecording()
        }
    }

    /// Process a video frame from camera output
    func processVideoFrame(_ sampleBuffer: CMSampleBuffer) {
        guard isRecording,
              let videoInput = videoInput,
              videoInput.isReadyForMoreMediaData else {
            return
        }

        writingQueue.async { [weak self] in
            self?.writeVideoFrame(sampleBuffer)
        }
    }

    /// Process an audio sample from camera output
    func processAudioSample(_ sampleBuffer: CMSampleBuffer) {
        guard isRecording,
              let audioInput = audioInput,
              audioInput.isReadyForMoreMediaData else {
            return
        }

        writingQueue.async { [weak self] in
            self?.writeAudioSample(sampleBuffer)
        }
    }

    // MARK: - Private Setup

    private func setupAndStartRecording(preset: FilterPreset, size: CGSize?) {
        currentPreset = preset

        // Update video size if provided
        if let size = size {
            videoSettings.width = Int(size.width)
            videoSettings.height = Int(size.height)
        }

        // Create output URL
        let fileName = "video_\(Date().timeIntervalSince1970).mp4"
        let tempDir = FileManager.default.temporaryDirectory
        let outputURL = tempDir.appendingPathComponent(fileName)
        recordingURL = outputURL

        // Remove existing file
        try? FileManager.default.removeItem(at: outputURL)

        do {
            // Create asset writer
            let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)

            // Setup video input
            let videoOutputSettings: [String: Any] = [
                AVVideoCodecKey: videoSettings.codec,
                AVVideoWidthKey: videoSettings.width,
                AVVideoHeightKey: videoSettings.height,
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: videoSettings.bitRate,
                    AVVideoExpectedSourceFrameRateKey: videoSettings.frameRate,
                    AVVideoMaxKeyFrameIntervalKey: videoSettings.frameRate,
                    AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
                ]
            ]

            let videoInput = AVAssetWriterInput(
                mediaType: .video,
                outputSettings: videoOutputSettings
            )
            videoInput.expectsMediaDataInRealTime = true

            // Create pixel buffer adaptor for filtered frames
            let sourcePixelBufferAttributes: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: videoSettings.width,
                kCVPixelBufferHeightKey as String: videoSettings.height,
                kCVPixelBufferMetalCompatibilityKey as String: true
            ]

            let adaptor = AVAssetWriterInputPixelBufferAdaptor(
                assetWriterInput: videoInput,
                sourcePixelBufferAttributes: sourcePixelBufferAttributes
            )

            if writer.canAdd(videoInput) {
                writer.add(videoInput)
            }

            // Setup audio input
            let audioOutputSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: audioSettings.sampleRate,
                AVNumberOfChannelsKey: audioSettings.channels,
                AVEncoderBitRateKey: audioSettings.bitRate
            ]

            let audioInput = AVAssetWriterInput(
                mediaType: .audio,
                outputSettings: audioOutputSettings
            )
            audioInput.expectsMediaDataInRealTime = true

            if writer.canAdd(audioInput) {
                writer.add(audioInput)
            }

            // Store references
            self.assetWriter = writer
            self.videoInput = videoInput
            self.audioInput = audioInput
            self.pixelBufferAdaptor = adaptor

            // Setup pixel buffer pool
            setupPixelBufferPool()

            // Start writing
            writer.startWriting()

            isRecording = true
            startTime = nil
            recordingDuration = 0

            // Start duration timer on main thread
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.startDurationTimer()
                self.delegate?.videoRecorderDidStartRecording(self)
            }

            print("✅ VideoRecorder: Started recording at \(videoSettings.width)×\(videoSettings.height)")

        } catch {
            print("❌ VideoRecorder: Failed to setup - \(error)")
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.delegate?.videoRecorderDidFail(self, error: error)
            }
        }
    }

    private func setupPixelBufferPool() {
        // Only recreate if size changed
        guard poolWidth != videoSettings.width || poolHeight != videoSettings.height else { return }

        poolWidth = videoSettings.width
        poolHeight = videoSettings.height

        let poolAttributes: [String: Any] = [
            kCVPixelBufferPoolMinimumBufferCountKey as String: 3
        ]

        let pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: poolWidth,
            kCVPixelBufferHeightKey as String: poolHeight,
            kCVPixelBufferMetalCompatibilityKey as String: true,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ]

        var pool: CVPixelBufferPool?
        CVPixelBufferPoolCreate(
            nil,
            poolAttributes as CFDictionary,
            pixelBufferAttributes as CFDictionary,
            &pool
        )
        pixelBufferPool = pool

        print("📦 VideoRecorder: Created pixel buffer pool \(poolWidth)×\(poolHeight)")
    }

    // MARK: - Frame Writing

    private func writeVideoFrame(_ sampleBuffer: CMSampleBuffer) {
        guard let writer = assetWriter,
              writer.status == .writing,
              let videoInput = videoInput,
              let adaptor = pixelBufferAdaptor,
              let preset = currentPreset else {
            return
        }

        let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

        // Start session on first frame
        if startTime == nil {
            startTime = presentationTime
            writer.startSession(atSourceTime: presentationTime)
            print("🎬 VideoRecorder: Session started at \(presentationTime.seconds)s")
        }

        // Get pixel buffer from sample
        guard let sourcePixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        // Apply filter and get output pixel buffer
        guard let filteredPixelBuffer = applyFilter(to: sourcePixelBuffer, preset: preset) else {
            // If filter fails, skip frame
            return
        }

        // Append to writer
        if videoInput.isReadyForMoreMediaData {
            adaptor.append(filteredPixelBuffer, withPresentationTime: presentationTime)
        }
    }

    private func writeAudioSample(_ sampleBuffer: CMSampleBuffer) {
        guard let writer = assetWriter,
              writer.status == .writing,
              let audioInput = audioInput,
              startTime != nil else {
            return
        }

        if audioInput.isReadyForMoreMediaData {
            audioInput.append(sampleBuffer)
        }
    }

    // MARK: - Filter Application

    private func applyFilter(to pixelBuffer: CVPixelBuffer, preset: FilterPreset) -> CVPixelBuffer? {
        guard let textureCache = metalTextureCache else {
            return nil
        }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        // ★★★ FIX: Update pool if frame dimensions changed (e.g., portrait vs landscape) ★★★
        if width != poolWidth || height != poolHeight {
            print("⚠️ VideoRecorder: Frame size changed from \(poolWidth)×\(poolHeight) to \(width)×\(height), updating pool")
            videoSettings.width = width
            videoSettings.height = height
            setupPixelBufferPool()
        }

        guard let pool = pixelBufferPool else {
            return nil
        }

        // Create input texture from source pixel buffer
        var inputTextureRef: CVMetalTexture?
        let inputStatus = CVMetalTextureCacheCreateTextureFromImage(
            nil,
            textureCache,
            pixelBuffer,
            nil,
            .bgra8Unorm,
            width,
            height,
            0,
            &inputTextureRef
        )

        guard inputStatus == kCVReturnSuccess,
              let inputTexture = inputTextureRef,
              let metalInputTexture = CVMetalTextureGetTexture(inputTexture) else {
            return nil
        }

        // Get output pixel buffer from pool
        var outputPixelBuffer: CVPixelBuffer?
        let poolStatus = CVPixelBufferPoolCreatePixelBuffer(nil, pool, &outputPixelBuffer)

        guard poolStatus == kCVReturnSuccess,
              let outputBuffer = outputPixelBuffer else {
            return nil
        }

        // ★★★ FIX: Use actual frame dimensions for output texture ★★★
        var outputTextureRef: CVMetalTexture?
        let outputStatus = CVMetalTextureCacheCreateTextureFromImage(
            nil,
            textureCache,
            outputBuffer,
            nil,
            .bgra8Unorm,
            width,
            height,
            0,
            &outputTextureRef
        )

        guard outputStatus == kCVReturnSuccess,
              let outputTexture = outputTextureRef,
              let metalOutputTexture = CVMetalTextureGetTexture(outputTexture) else {
            return nil
        }

        // Apply filter using optimized gallery preview pipeline (2 passes: ColorGrading + Vignette)
        // This is the fastest pipeline suitable for real-time video recording
        let success = filterRenderer.renderGalleryPreview(
            input: metalInputTexture,
            output: metalOutputTexture,
            preset: preset,
            commandQueue: commandQueue
        )

        return success ? outputBuffer : nil
    }

    // MARK: - Finalization

    private func finalizeRecording() {
        guard let writer = assetWriter,
              let outputURL = recordingURL else {
            return
        }

        isRecording = false

        // Stop duration timer
        DispatchQueue.main.async { [weak self] in
            self?.stopDurationTimer()
        }

        // Mark inputs as finished
        videoInput?.markAsFinished()
        audioInput?.markAsFinished()

        // Finish writing
        writer.finishWriting { [weak self] in
            guard let self = self else { return }

            if writer.status == .completed {
                print("✅ VideoRecorder: Recording saved to \(outputURL.lastPathComponent)")
                print("📊 VideoRecorder: Duration: \(String(format: "%.1f", self.recordingDuration))s")

                DispatchQueue.main.async {
                    self.delegate?.videoRecorderDidStopRecording(self, outputURL: outputURL)
                }
            } else if let error = writer.error {
                print("❌ VideoRecorder: Failed to finish - \(error)")
                DispatchQueue.main.async {
                    self.delegate?.videoRecorderDidFail(self, error: error)
                }
            }

            // Cleanup
            self.cleanup()
        }
    }

    private func cleanup() {
        assetWriter = nil
        videoInput = nil
        audioInput = nil
        pixelBufferAdaptor = nil
        startTime = nil
        currentPreset = nil
    }

    // MARK: - Duration Timer

    private func startDurationTimer() {
        durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, self.isRecording else { return }

            self.recordingDuration += 0.1
            self.delegate?.videoRecorderDurationUpdated(self, duration: self.recordingDuration)
        }
    }

    private func stopDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = nil
    }

    // MARK: - Export to Photo Library

    func saveToPhotoLibrary(url: URL, completion: @escaping (Bool, Error?) -> Void) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                completion(false, NSError(domain: "VideoRecorder", code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Photo library access denied"]))
                return
            }

            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            } completionHandler: { success, error in
                DispatchQueue.main.async {
                    if success {
                        print("✅ VideoRecorder: Video saved to library")
                        // Clean up temp file
                        try? FileManager.default.removeItem(at: url)
                    } else {
                        print("❌ VideoRecorder: Failed to save - \(error?.localizedDescription ?? "Unknown")")
                    }
                    completion(success, error)
                }
            }
        }
    }
}

