// CameraManager.swift
// Film Camera - Camera Session and Photo Capture Manager
// ★★★ COMPLETE: All required properties and methods ★★★

import AVFoundation
import UIKit
import Photos
import Metal

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
    
    // ★★★ NEW: Permission and error handling ★★★
    @Published var permissionStatus: CameraPermissionStatus = .notDetermined
    @Published var isInterrupted = false
    @Published var error: Error?
    
    // MARK: - Session
    
    let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "camera.session.queue", qos: .userInitiated)
    
    // MARK: - Capture
    
    private var photoOutput: AVCapturePhotoOutput?
    private var videoDeviceInput: AVCaptureDeviceInput?
    private var inProgressPhotoCaptures: [Int64: PhotoCaptureProcessor] = [:]
    
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
    
    // MARK: - ★★★ Permission Handling ★★★
    
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
    
    // MARK: - ★★★ Session Interruption Notifications ★★★
    
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
        session.sessionPreset = .photo
        
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
        
        // Add photo output
        let photoOutput = AVCapturePhotoOutput()
        photoOutput.isHighResolutionCaptureEnabled = true
        photoOutput.maxPhotoQualityPrioritization = .quality
        
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            self.photoOutput = photoOutput
        }
        
        session.commitConfiguration()
        
        // Start session
        session.startRunning()
        
        DispatchQueue.main.async { [weak self] in
            self?.isSessionRunning = true
        }
        
        print("✅ CameraManager: Session configured and running")
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
    
    // ★★★ FIXED: focus method with correct signature ★★★
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
    
    // ★★★ NEW: Toggle Flash ★★★
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
    
    // MARK: - ★★★ Photo Capture with FULL Quality Pipeline ★★★
    
    func capturePhoto(preset: FilterPreset, completion: @escaping (UIImage?) -> Void) {
        guard let photoOutput = photoOutput else {
            print("❌ CameraManager: Photo output not available")
            completion(nil)
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
        
        photoSettings.isHighResolutionPhotoEnabled = true
        photoSettings.flashMode = flashMode
        
        // Create processor for this capture
        let processor = PhotoCaptureProcessor(
            preset: preset,
            filterRenderer: filterRenderer,
            completion: { [weak self] image in
                DispatchQueue.main.async {
                    self?.isCapturing = false
                    self?.lastCapturedImage = image
                    
                    // Clean up processor
                    if let uniqueID = self?.inProgressPhotoCaptures.first(where: { $0.value === processor })?.key {
                        self?.inProgressPhotoCaptures.removeValue(forKey: uniqueID)
                    }
                    
                    completion(image)
                }
            }
        )
        
        // Store processor with unique ID
        let uniqueID = photoSettings.uniqueID
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
}

// MARK: - ★★★ Photo Capture Processor (Full Quality Pipeline) ★★★

class PhotoCaptureProcessor: NSObject, AVCapturePhotoCaptureDelegate {
    
    private let preset: FilterPreset
    private let filterRenderer: FilterRenderer
    private let completion: (UIImage?) -> Void
    
    init(preset: FilterPreset, filterRenderer: FilterRenderer, completion: @escaping (UIImage?) -> Void) {
        self.preset = preset
        self.filterRenderer = filterRenderer
        self.completion = completion
        super.init()
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("❌ PhotoCaptureProcessor: Capture error - \(error)")
            completion(nil)
            return
        }
        
        guard let imageData = photo.fileDataRepresentation(),
              let originalImage = UIImage(data: imageData) else {
            print("❌ PhotoCaptureProcessor: Failed to get image data")
            completion(nil)
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
                self.completion(filteredImage)
            } else {
                print("⚠️ PhotoCaptureProcessor: Filter failed, returning original")
                self.completion(originalImage)
            }
        }
    }
    
    // MARK: - ★★★ Apply Full Quality Filters (13 passes) ★★★
    
    private func applyFullQualityFilters(to image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        
        let device = RenderEngine.shared.device
        let commandQueue = RenderEngine.shared.commandQueue
        
        // Create input texture from CGImage
        let textureLoader = MTKTextureLoader(device: device)
        guard let inputTexture = try? textureLoader.newTexture(cgImage: cgImage, options: [
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
        
        // ★★★ Use SYNCHRONOUS render with FULL quality ★★★
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
