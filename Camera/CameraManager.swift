// CameraManager.swift
// Film Camera - Production Ready Camera Management
// ★★★ FIXED: Memory leak in inProgressPhotoCaptures ★★★
// ★★★ FIXED: Added session interruption handling ★★★
// ★★★ ADDED: getCurrentZoomFactor() for zoom gesture ★★★

import AVFoundation
import UIKit
import Combine

final class CameraManager: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published private(set) var permissionStatus: AVAuthorizationStatus = .notDetermined
    @Published private(set) var isSessionRunning = false
    @Published private(set) var currentPosition: AVCaptureDevice.Position = .back
    @Published var flashMode: AVCaptureDevice.FlashMode = .off
    @Published private(set) var error: CameraError?
    @Published private(set) var isInterrupted = false  // ★ NEW
    
    // MARK: - Session
    
    let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.filmcamera.session", qos: .userInitiated)
    private var isConfigured = false
    
    // MARK: - Capture
    
    private(set) var videoDeviceInput: AVCaptureDeviceInput?  // ★ Changed to internal for zoom access
    private let photoOutput = AVCapturePhotoOutput()
    private var inProgressPhotoCaptures = [Int64: PhotoCaptureProcessor]()
    private let capturesLock = NSLock()  // ★ Thread safety for captures dictionary
    
    // MARK: - Error Types
    
    enum CameraError: Error, LocalizedError {
        case cameraUnavailable
        case cannotAddInput
        case cannotAddOutput
        case configurationFailed
        case sessionInterrupted(reason: AVCaptureSession.InterruptionReason)
        
        var errorDescription: String? {
            switch self {
            case .cameraUnavailable: return "Camera is not available on this device"
            case .cannotAddInput: return "Cannot add camera input"
            case .cannotAddOutput: return "Cannot add photo output"
            case .configurationFailed: return "Camera configuration failed"
            case .sessionInterrupted(let reason):
                switch reason {
                case .videoDeviceNotAvailableInBackground:
                    return "Camera unavailable in background"
                case .audioDeviceInUseByAnotherClient:
                    return "Audio device in use"
                case .videoDeviceInUseByAnotherClient:
                    return "Camera in use by another app"
                case .videoDeviceNotAvailableWithMultipleForegroundApps:
                    return "Camera unavailable in split screen"
                case .videoDeviceNotAvailableDueToSystemPressure:
                    return "System pressure - camera unavailable"
                @unknown default:
                    return "Camera interrupted"
                }
            }
        }
    }
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        setupObservers()  // ★ NEW
    }
    
    deinit {
        removeObservers()
        stopSession()
    }
    
    // MARK: - ★★★ NEW: Session Interruption Handling ★★★
    
    private func setupObservers() {
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
    
    private func removeObservers() {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func sessionWasInterrupted(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVCaptureSessionInterruptionReasonKey] as? Int,
              let reason = AVCaptureSession.InterruptionReason(rawValue: reasonValue) else {
            return
        }
        
        print("⚠️ CameraManager: Session interrupted - \(reason)")
        
        DispatchQueue.main.async {
            self.isInterrupted = true
            self.error = .sessionInterrupted(reason: reason)
        }
    }
    
    @objc private func sessionInterruptionEnded(_ notification: Notification) {
        print("✅ CameraManager: Session interruption ended")
        
        DispatchQueue.main.async {
            self.isInterrupted = false
            self.error = nil
        }
    }
    
    @objc private func sessionRuntimeError(_ notification: Notification) {
        guard let error = notification.userInfo?[AVCaptureSessionErrorKey] as? AVError else {
            return
        }
        
        print("❌ CameraManager: Runtime error - \(error.localizedDescription)")
        
        // Try to restart session if media services were reset
        if error.code == .mediaServicesWereReset {
            sessionQueue.async {
                if self.isSessionRunning {
                    self.session.startRunning()
                    DispatchQueue.main.async {
                        self.isSessionRunning = self.session.isRunning
                    }
                }
            }
        }
    }
    
    // MARK: - Permission Handling
    
    func checkPermissionStatus() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        DispatchQueue.main.async {
            self.permissionStatus = status
        }
        
        if status == .authorized {
            setupSession()
        }
    }
    
    func requestPermission() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async {
                self?.permissionStatus = granted ? .authorized : .denied
            }
            
            if granted {
                self?.setupSession()
            }
        }
    }
    
    // MARK: - Session Setup
    
    private func setupSession() {
        guard !isConfigured else { return }
        
        sessionQueue.async { [weak self] in
            self?.configureSession()
        }
    }
    
    private func configureSession() {
        guard !isConfigured else { return }
        
        session.beginConfiguration()
        session.sessionPreset = .photo
        
        // Add video input
        do {
            guard let videoDevice = bestVideoDevice(for: .back) else {
                DispatchQueue.main.async {
                    self.error = .cameraUnavailable
                }
                session.commitConfiguration()
                return
            }
            
            let videoInput = try AVCaptureDeviceInput(device: videoDevice)
            
            if session.canAddInput(videoInput) {
                session.addInput(videoInput)
                self.videoDeviceInput = videoInput
            } else {
                DispatchQueue.main.async {
                    self.error = .cannotAddInput
                }
                session.commitConfiguration()
                return
            }
        } catch {
            DispatchQueue.main.async {
                self.error = .configurationFailed
            }
            session.commitConfiguration()
            return
        }
        
        // Add photo output
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            
            if #available(iOS 16.0, *) {
                if let device = self.videoDeviceInput?.device {
                    photoOutput.maxPhotoDimensions = device.activeFormat.supportedMaxPhotoDimensions.last ?? .init(width: 0, height: 0)
                }
            } else {
                photoOutput.isHighResolutionCaptureEnabled = true
            }
            photoOutput.maxPhotoQualityPrioritization = .quality
            
            if photoOutput.isLivePhotoCaptureSupported {
                photoOutput.isLivePhotoCaptureEnabled = false
            }
        } else {
            DispatchQueue.main.async {
                self.error = .cannotAddOutput
            }
            session.commitConfiguration()
            return
        }
        
        session.commitConfiguration()
        isConfigured = true
        
        startSession()
    }
    
    private func bestVideoDevice(for position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let deviceTypes: [AVCaptureDevice.DeviceType] = [
            .builtInTripleCamera,
            .builtInDualWideCamera,
            .builtInDualCamera,
            .builtInWideAngleCamera
        ]
        
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes,
            mediaType: .video,
            position: position
        )
        
        return discoverySession.devices.first ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position)
    }
    
    // MARK: - Session Control
    
    private func startSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            if !self.session.isRunning {
                self.session.startRunning()
                
                DispatchQueue.main.async {
                    self.isSessionRunning = self.session.isRunning
                }
            }
        }
    }
    
    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            if self.session.isRunning {
                self.session.stopRunning()
                
                DispatchQueue.main.async {
                    self.isSessionRunning = false
                }
            }
        }
    }
    
    // MARK: - Camera Controls
    
    func switchCamera() {
        sessionQueue.async { [weak self] in
            guard let self = self,
                  let currentInput = self.videoDeviceInput else { return }
            
            let newPosition: AVCaptureDevice.Position = self.currentPosition == .back ? .front : .back
            
            guard let newDevice = self.bestVideoDevice(for: newPosition) else { return }
            
            do {
                let newInput = try AVCaptureDeviceInput(device: newDevice)
                
                self.session.beginConfiguration()
                self.session.removeInput(currentInput)
                
                if self.session.canAddInput(newInput) {
                    self.session.addInput(newInput)
                    self.videoDeviceInput = newInput
                    
                    DispatchQueue.main.async {
                        self.currentPosition = newPosition
                    }
                } else {
                    self.session.addInput(currentInput)
                }
                
                self.session.commitConfiguration()
            } catch {
                print("Error switching camera: \(error.localizedDescription)")
            }
        }
    }
    
    func toggleFlash() {
        DispatchQueue.main.async {
            switch self.flashMode {
            case .off:
                self.flashMode = .on
            case .on:
                self.flashMode = .auto
            case .auto:
                self.flashMode = .off
            @unknown default:
                self.flashMode = .off
            }
        }
    }
    
    // MARK: - ★★★ NEW: Get Current Zoom Factor (for gesture) ★★★
    
    func getCurrentZoomFactor() -> CGFloat {
        guard let device = videoDeviceInput?.device else { return 1.0 }
        return device.videoZoomFactor
    }
    
    // MARK: - Photo Capture
    
    func capturePhoto(preset: FilterPreset? = nil, completion: @escaping (UIImage?) -> Void) {
        sessionQueue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            var settings = AVCapturePhotoSettings()

            if self.photoOutput.availablePhotoCodecTypes.contains(.hevc) {
                settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
            }

            if self.videoDeviceInput?.device.isFlashAvailable == true {
                settings.flashMode = self.flashMode
            }

            settings.isHighResolutionPhotoEnabled = true
            settings.photoQualityPrioritization = .quality

            // ★★★ FIX: Pass cleanup callback to processor ★★★
            let uniqueID = settings.uniqueID
            let processor = PhotoCaptureProcessor(
                preset: preset,
                completion: completion,
                cleanup: { [weak self] in
                    self?.removePhotoCapture(id: uniqueID)
                }
            )
            
            self.addPhotoCapture(id: uniqueID, processor: processor)
            self.photoOutput.capturePhoto(with: settings, delegate: processor)
        }
    }
    
    // ★★★ NEW: Thread-safe capture management ★★★
    
    private func addPhotoCapture(id: Int64, processor: PhotoCaptureProcessor) {
        capturesLock.lock()
        inProgressPhotoCaptures[id] = processor
        capturesLock.unlock()
    }
    
    private func removePhotoCapture(id: Int64) {
        capturesLock.lock()
        inProgressPhotoCaptures.removeValue(forKey: id)
        capturesLock.unlock()
        print("📸 CameraManager: Cleaned up capture processor (remaining: \(inProgressPhotoCaptures.count))")
    }
    
    // MARK: - Focus & Exposure
    
    func focus(at point: CGPoint) {
        sessionQueue.async { [weak self] in
            guard let device = self?.videoDeviceInput?.device else { return }
            
            do {
                try device.lockForConfiguration()
                
                if device.isFocusPointOfInterestSupported && device.isFocusModeSupported(.autoFocus) {
                    device.focusPointOfInterest = point
                    device.focusMode = .autoFocus
                }
                
                if device.isExposurePointOfInterestSupported && device.isExposureModeSupported(.autoExpose) {
                    device.exposurePointOfInterest = point
                    device.exposureMode = .autoExpose
                }
                
                device.unlockForConfiguration()
            } catch {
                print("Could not configure focus: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Zoom
    
    func setZoom(_ factor: CGFloat) {
        sessionQueue.async { [weak self] in
            guard let device = self?.videoDeviceInput?.device else { return }
            
            do {
                try device.lockForConfiguration()
                
                let minZoom: CGFloat = 1.0
                let maxZoom = min(device.activeFormat.videoMaxZoomFactor, 10.0)
                device.videoZoomFactor = max(minZoom, min(factor, maxZoom))
                
                device.unlockForConfiguration()
            } catch {
                print("Could not set zoom: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Photo Capture Processor

private class PhotoCaptureProcessor: NSObject, AVCapturePhotoCaptureDelegate {
    private let preset: FilterPreset?
    private let completion: (UIImage?) -> Void
    private let cleanup: () -> Void  // ★★★ NEW: Cleanup callback ★★★

    init(preset: FilterPreset? = nil, completion: @escaping (UIImage?) -> Void, cleanup: @escaping () -> Void) {
        self.preset = preset
        self.completion = completion
        self.cleanup = cleanup
        super.init()
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        // ★★★ FIX: Always cleanup, even on error ★★★
        defer { cleanup() }
        
        if let error = error {
            print("Error capturing photo: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.completion(nil)
            }
            return
        }

        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            DispatchQueue.main.async {
                self.completion(nil)
            }
            return
        }

        let finalImage: UIImage?
        if let preset = preset {
            print("📸 PhotoCaptureProcessor: Applying filter '\(preset.label)' to captured photo...")
            finalImage = RenderEngine.shared.applyFilter(to: image, preset: preset)
        } else {
            finalImage = image
        }

        DispatchQueue.main.async {
            self.completion(finalImage)
        }
    }
}
