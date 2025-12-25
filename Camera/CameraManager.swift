// CameraManager.swift
// Film Camera - Camera Session and Photo Capture Manager
// ★★★ FIXED: Added import Combine for @Published ★★★

import AVFoundation
import UIKit
import Photos
import Metal
import MetalKit  // ★★★ REQUIRED for MTKTextureLoader ★★★
import Combine  // ★★★ REQUIRED for @Published ★★★

// MARK: - Permission Status Enum

enum CameraPermissionStatus {
    case notDetermined
    case authorized
    case denied
    case restricted
}

// MARK: - Camera Manager

class CameraManager: NSObject, ObservableObject {
    
    // MARK: - Published Properties

    @Published var isSessionRunning = false
    @Published var currentPosition: AVCaptureDevice.Position = .back
    @Published var currentZoomFactor: CGFloat = 1.0
    @Published var isCapturing = false
    @Published var lastCapturedImage: UIImage?
    @Published var flashMode: AVCaptureDevice.FlashMode = .off
    @Published var exposureCompensation: Float = 0.0

    // Video recording state
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0

    // Permission and error handling
    @Published var permissionStatus: CameraPermissionStatus = .notDetermined
    @Published var isInterrupted = false
    @Published var error: Error?

    // MARK: - Session

    let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "camera.session.queue", qos: .userInitiated)
    private let videoDataQueue = DispatchQueue(label: "camera.video.data", qos: .userInteractive)
    private let audioDataQueue = DispatchQueue(label: "camera.audio.data", qos: .userInteractive)

    // MARK: - Capture

    private var photoOutput: AVCapturePhotoOutput?
    private var videoDataOutput: AVCaptureVideoDataOutput?
    private var audioDataOutput: AVCaptureAudioDataOutput?
    private var audioDeviceInput: AVCaptureDeviceInput?
    private var videoDeviceInput: AVCaptureDeviceInput?
    private var inProgressPhotoCaptures: [Int64: PhotoCaptureProcessor] = [:]

    // MARK: - Video Recording

    private var videoRecorder: VideoRecorder?
    private var recordingPreset: FilterPreset?

    // MARK: - Filter Rendering

    private let filterRenderer = FilterRenderer()
    private var currentPreset: FilterPreset?
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        setupNotifications()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Permission Handling
    
    func checkPermissionStatus() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        DispatchQueue.main.async { [weak self] in
            switch status {
            case .notDetermined:
                self?.permissionStatus = .notDetermined
            case .authorized:
                self?.permissionStatus = .authorized
                self?.setupSession()
            case .denied:
                self?.permissionStatus = .denied
            case .restricted:
                self?.permissionStatus = .restricted
            @unknown default:
                self?.permissionStatus = .denied
            }
        }
    }
    
    func requestPermission() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async {
                if granted {
                    self?.permissionStatus = .authorized
                    self?.setupSession()
                } else {
                    self?.permissionStatus = .denied
                }
            }
        }
    }
    
    // MARK: - Session Interruption Notifications
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sessionWasInterrupted),
            name: .AVCaptureSessionWasInterrupted,
            object: session
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sessionInterruptionEnded),
            name: .AVCaptureSessionInterruptionEnded,
            object: session
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sessionRuntimeError),
            name: .AVCaptureSessionRuntimeError,
            object: session
        )
    }
    
    @objc private func sessionWasInterrupted(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            self?.isInterrupted = true
            
            if let reason = notification.userInfo?[AVCaptureSessionInterruptionReasonKey] as? Int,
               let interruptionReason = AVCaptureSession.InterruptionReason(rawValue: reason) {
                print("⚠️ CameraManager: Session interrupted - \(interruptionReason)")
            }
        }
    }
    
    @objc private func sessionInterruptionEnded(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            self?.isInterrupted = false
            self?.error = nil
            print("✅ CameraManager: Session interruption ended")
        }
    }
    
    @objc private func sessionRuntimeError(_ notification: Notification) {
        guard let errorValue = notification.userInfo?[AVCaptureSessionErrorKey] as? NSError else { return }
        
        DispatchQueue.main.async { [weak self] in
            self?.error = errorValue
            print("❌ CameraManager: Runtime error - \(errorValue.localizedDescription)")
        }
        
        // Try to restart session
        sessionQueue.async { [weak self] in
            self?.session.startRunning()
        }
    }
    
    // MARK: - Session Setup
    
    private func setupSession() {
        sessionQueue.async { [weak self] in
            self?.configureSession()
        }
    }
    
    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .high // Changed from .photo for video support

        // Add video input
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice) else {
            print("❌ CameraManager: Failed to create video input")
            session.commitConfiguration()
            return
        }

        if session.canAddInput(videoInput) {
            session.addInput(videoInput)
            videoDeviceInput = videoInput
        }

        // Add audio input for video recording
        if let audioDevice = AVCaptureDevice.default(for: .audio),
           let audioInput = try? AVCaptureDeviceInput(device: audioDevice) {
            if session.canAddInput(audioInput) {
                session.addInput(audioInput)
                audioDeviceInput = audioInput
            }
        }

        // Add photo output
        let photoOutput = AVCapturePhotoOutput()
        photoOutput.maxPhotoQualityPrioritization = .quality

        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            self.photoOutput = photoOutput
        }

        // Add video data output for recording
        let videoDataOutput = AVCaptureVideoDataOutput()
        videoDataOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        videoDataOutput.setSampleBufferDelegate(self, queue: videoDataQueue)

        if session.canAddOutput(videoDataOutput) {
            session.addOutput(videoDataOutput)
            self.videoDataOutput = videoDataOutput
        }

        // Add audio data output for recording
        let audioDataOutput = AVCaptureAudioDataOutput()
        audioDataOutput.setSampleBufferDelegate(self, queue: audioDataQueue)

        if session.canAddOutput(audioDataOutput) {
            session.addOutput(audioDataOutput)
            self.audioDataOutput = audioDataOutput
        }

        session.commitConfiguration()

        // Initialize video recorder
        videoRecorder = VideoRecorder()
        videoRecorder?.delegate = self

        // Start session
        session.startRunning()

        DispatchQueue.main.async { [weak self] in
            self?.isSessionRunning = true
        }

        print("✅ CameraManager: Session configured with video/audio outputs and running")
    }
    
    // MARK: - Camera Controls
    
    func switchCamera() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            let newPosition: AVCaptureDevice.Position = self.currentPosition == .back ? .front : .back
            
            guard let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition),
                  let newInput = try? AVCaptureDeviceInput(device: newDevice) else {
                print("❌ CameraManager: Failed to switch camera")
                return
            }
            
            self.session.beginConfiguration()
            
            if let currentInput = self.videoDeviceInput {
                self.session.removeInput(currentInput)
            }
            
            if self.session.canAddInput(newInput) {
                self.session.addInput(newInput)
                self.videoDeviceInput = newInput
            }
            
            self.session.commitConfiguration()
            
            DispatchQueue.main.async {
                self.currentPosition = newPosition
                self.currentZoomFactor = 1.0
            }
            
            print("✅ CameraManager: Switched to \(newPosition == .back ? "back" : "front") camera")
        }
    }
    
    func setZoom(_ factor: CGFloat) {
        guard let device = videoDeviceInput?.device else { return }
        
        let minZoom: CGFloat = 1.0
        let maxZoom = min(device.activeFormat.videoMaxZoomFactor, 10.0)
        let clampedFactor = max(minZoom, min(factor, maxZoom))
        
        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = clampedFactor
            device.unlockForConfiguration()
            
            DispatchQueue.main.async { [weak self] in
                self?.currentZoomFactor = clampedFactor
            }
        } catch {
            print("❌ CameraManager: Failed to set zoom - \(error)")
        }
    }
    
    func setExposureCompensation(_ ev: Float) {
        guard let device = videoDeviceInput?.device else { return }
        
        let minEV = device.minExposureTargetBias
        let maxEV = device.maxExposureTargetBias
        let clampedEV = max(minEV, min(ev, maxEV))
        
        do {
            try device.lockForConfiguration()
            device.setExposureTargetBias(clampedEV) { _ in }
            device.unlockForConfiguration()
            
            DispatchQueue.main.async { [weak self] in
                self?.exposureCompensation = clampedEV
            }
        } catch {
            print("❌ CameraManager: Failed to set exposure - \(error)")
        }
    }
    
    // Focus method with correct signature
    func focus(at point: CGPoint, in view: UIView) {
        guard let device = videoDeviceInput?.device,
              device.isFocusPointOfInterestSupported else { return }
        
        do {
            try device.lockForConfiguration()
            device.focusPointOfInterest = point
            device.focusMode = .autoFocus
            
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = point
                device.exposureMode = .autoExpose
            }
            
            device.unlockForConfiguration()
        } catch {
            print("❌ CameraManager: Failed to focus - \(error)")
        }
    }
    
    // Toggle Flash
    func toggleFlash() {
        switch flashMode {
        case .off:
            flashMode = .on
        case .on:
            flashMode = .auto
        case .auto:
            flashMode = .off
        @unknown default:
            flashMode = .off
        }
        print("🔦 CameraManager: Flash mode set to \(flashMode)")
    }
    
    // MARK: - Photo Capture with FULL Quality Pipeline

    /// Capture photo and return only filtered result (legacy method)
    func capturePhoto(preset: FilterPreset, completion: @escaping (UIImage?) -> Void) {
        capturePhotoWithOriginal(preset: preset) { _, filtered in
            completion(filtered)
        }
    }

    /// Capture photo and return both original and filtered images (for gallery saving)
    func capturePhotoWithOriginal(preset: FilterPreset, completion: @escaping (UIImage?, UIImage?) -> Void) {
        guard let photoOutput = photoOutput else {
            print("❌ CameraManager: Photo output not available")
            completion(nil, nil)
            return
        }

        DispatchQueue.main.async { [weak self] in
            self?.isCapturing = true
        }

        // Store current preset for capture processing
        currentPreset = preset

        // Configure photo settings
        var photoSettings = AVCapturePhotoSettings()

        // Use HEIF if available, otherwise JPEG
        if photoOutput.availablePhotoCodecTypes.contains(.hevc) {
            photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
        }

        photoSettings.flashMode = flashMode

        let uniqueID = photoSettings.uniqueID

        // Create processor for this capture
        let processor = PhotoCaptureProcessor(
            preset: preset,
            filterRenderer: filterRenderer,
            completion: { [weak self] original, filtered in
                DispatchQueue.main.async {
                    self?.isCapturing = false
                    self?.lastCapturedImage = filtered

                    // Clean up processor using captured uniqueID (not processor reference)
                    self?.inProgressPhotoCaptures.removeValue(forKey: uniqueID)

                    completion(original, filtered)
                }
            }
        )

        // Store processor
        inProgressPhotoCaptures[uniqueID] = processor

        // Capture photo
        photoOutput.capturePhoto(with: photoSettings, delegate: processor)

        print("📸 CameraManager: Capturing photo with preset '\(preset.label)'")
    }
    
    // MARK: - Save to Photo Library
    
    func saveToPhotoLibrary(_ image: UIImage, completion: @escaping (Bool, Error?) -> Void) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized else {
                DispatchQueue.main.async {
                    completion(false, NSError(domain: "CameraManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Photo library access denied"]))
                }
                return
            }
            
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            } completionHandler: { success, error in
                DispatchQueue.main.async {
                    if success {
                        print("✅ CameraManager: Photo saved to library")
                    } else {
                        print("❌ CameraManager: Failed to save photo - \(error?.localizedDescription ?? "Unknown")")
                    }
                    completion(success, error)
                }
            }
        }
    }
    
    // MARK: - Session Control
    
    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self = self, !self.session.isRunning else { return }
            self.session.startRunning()
            
            DispatchQueue.main.async {
                self.isSessionRunning = true
            }
        }
    }
    
    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self, self.session.isRunning else { return }
            self.session.stopRunning()

            DispatchQueue.main.async {
                self.isSessionRunning = false
            }
        }
    }

    // MARK: - Video Recording

    /// Start video recording with the specified filter preset
    func startVideoRecording(preset: FilterPreset) {
        guard !isRecording else {
            print("⚠️ CameraManager: Already recording")
            return
        }

        recordingPreset = preset

        // Get video dimensions from active format
        var videoSize = CGSize(width: 1920, height: 1080)
        if let formatDescription = videoDeviceInput?.device.activeFormat.formatDescription {
            let dimensions = CMVideoFormatDescriptionGetDimensions(formatDescription)
            videoSize = CGSize(width: CGFloat(dimensions.width), height: CGFloat(dimensions.height))
        }

        videoRecorder?.startRecording(preset: preset, size: videoSize)
    }

    /// Stop video recording and save to photo library
    func stopVideoRecording() {
        guard isRecording else { return }
        videoRecorder?.stopRecording()
    }

    /// Get the last recorded video URL
    var lastRecordedVideoURL: URL? {
        return nil // Will be provided via delegate
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate & AVCaptureAudioDataOutputSampleBufferDelegate

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard isRecording else { return }

        if output == videoDataOutput {
            videoRecorder?.processVideoFrame(sampleBuffer)
        } else if output == audioDataOutput {
            videoRecorder?.processAudioSample(sampleBuffer)
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Frame was dropped - could log for debugging
        // This is normal under heavy load
    }
}

// MARK: - VideoRecorderDelegate

extension CameraManager: VideoRecorderDelegate {

    func videoRecorderDidStartRecording(_ recorder: VideoRecorder) {
        DispatchQueue.main.async { [weak self] in
            self?.isRecording = true
            self?.recordingDuration = 0
            print("🎬 CameraManager: Video recording started")
        }
    }

    func videoRecorderDidStopRecording(_ recorder: VideoRecorder, outputURL: URL) {
        DispatchQueue.main.async { [weak self] in
            self?.isRecording = false
            print("🎬 CameraManager: Video recording stopped")

            // Save to photo library
            recorder.saveToPhotoLibrary(url: outputURL) { success, error in
                if success {
                    print("✅ CameraManager: Video saved to library")
                } else if let error = error {
                    print("❌ CameraManager: Failed to save video - \(error.localizedDescription)")
                }
            }
        }
    }

    func videoRecorderDidFail(_ recorder: VideoRecorder, error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.isRecording = false
            self?.error = error
            print("❌ CameraManager: Video recording failed - \(error.localizedDescription)")
        }
    }

    func videoRecorderDurationUpdated(_ recorder: VideoRecorder, duration: TimeInterval) {
        DispatchQueue.main.async { [weak self] in
            self?.recordingDuration = duration
        }
    }
}

// MARK: - Photo Capture Processor (Full Quality Pipeline)

class PhotoCaptureProcessor: NSObject, AVCapturePhotoCaptureDelegate {

    private let preset: FilterPreset
    private let filterRenderer: FilterRenderer
    private let completion: (UIImage?, UIImage?) -> Void // (original, filtered)

    init(preset: FilterPreset, filterRenderer: FilterRenderer, completion: @escaping (UIImage?, UIImage?) -> Void) {
        self.preset = preset
        self.filterRenderer = filterRenderer
        self.completion = completion
        super.init()
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("❌ PhotoCaptureProcessor: Capture error - \(error)")
            completion(nil, nil)
            return
        }

        guard let imageData = photo.fileDataRepresentation(),
              let originalImage = UIImage(data: imageData) else {
            print("❌ PhotoCaptureProcessor: Failed to get image data")
            completion(nil, nil)
            return
        }

        print("📸 PhotoCaptureProcessor: Processing \(Int(originalImage.size.width))×\(Int(originalImage.size.height)) image")

        // Apply FULL quality filter pipeline (13 passes)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let startTime = CFAbsoluteTimeGetCurrent()

            if let filteredImage = self.applyFullQualityFilters(to: originalImage) {
                let elapsed = CFAbsoluteTimeGetCurrent() - startTime
                print("✅ PhotoCaptureProcessor: Full pipeline completed in \(String(format: "%.2f", elapsed))s")
                self.completion(originalImage, filteredImage)
            } else {
                print("⚠️ PhotoCaptureProcessor: Filter failed, returning original")
                self.completion(originalImage, originalImage)
            }
        }
    }
    
    // MARK: - Apply Full Quality Filters (13 passes)
    
    private func applyFullQualityFilters(to image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        
        let device = RenderEngine.shared.device
        let commandQueue = RenderEngine.shared.commandQueue
        
        // Create input texture from CGImage
        // ★ FIX: .SRGB: false để tránh double gamma decode
        // Metal mặc định auto-decode sRGB→Linear, nhưng shader đã có srgbToLinear3()
        let textureLoader = MTKTextureLoader(device: device)
        guard let inputTexture = try? textureLoader.newTexture(cgImage: cgImage, options: [
            .SRGB: false,  // ★ CRITICAL: Giữ nguyên sRGB values, shader sẽ convert
            .textureUsage: NSNumber(value: MTLTextureUsage.shaderRead.rawValue),
            .textureStorageMode: NSNumber(value: MTLStorageMode.shared.rawValue)
        ]) else {
            print("❌ PhotoCaptureProcessor: Failed to create input texture")
            return nil
        }
        
        // Create output texture (same size as input - FULL RESOLUTION)
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: cgImage.width,
            height: cgImage.height,
            mipmapped: false
        )
        textureDescriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
        textureDescriptor.storageMode = .shared
        
        guard let outputTexture = device.makeTexture(descriptor: textureDescriptor) else {
            print("❌ PhotoCaptureProcessor: Failed to create output texture")
            return nil
        }
        
        print("🎨 PhotoCaptureProcessor: Applying FULL 13-pass pipeline at \(cgImage.width)×\(cgImage.height)")
        
        // Use SYNCHRONOUS render with FULL quality
        let success = filterRenderer.renderSync(
            input: inputTexture,
            output: outputTexture,
            preset: preset,
            commandQueue: commandQueue
        )
        
        guard success else {
            print("❌ PhotoCaptureProcessor: Render failed")
            return nil
        }
        
        // Convert output texture back to UIImage
        return textureToImage(outputTexture, orientation: image.imageOrientation)
    }
    
    private func textureToImage(_ texture: MTLTexture, orientation: UIImage.Orientation) -> UIImage? {
        let width = texture.width
        let height = texture.height
        let bytesPerRow = width * 4
        
        var pixelData = [UInt8](repeating: 0, count: width * height * 4)
        
        texture.getBytes(
            &pixelData,
            bytesPerRow: bytesPerRow,
            from: MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0), size: MTLSize(width: width, height: height, depth: 1)),
            mipmapLevel: 0
        )
        
        // Convert BGRA to RGBA
        for i in stride(from: 0, to: pixelData.count, by: 4) {
            let b = pixelData[i]
            let r = pixelData[i + 2]
            pixelData[i] = r
            pixelData[i + 2] = b
        }
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ),
        let cgImage = context.makeImage() else {
            return nil
        }
        
        return UIImage(cgImage: cgImage, scale: 1.0, orientation: orientation)
    }
}
