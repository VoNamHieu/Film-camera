// CameraManager.swift
// Film Camera - Production Ready Camera Management

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
    
    // MARK: - Session
    
    let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.filmcamera.session", qos: .userInitiated)
    private var isConfigured = false
    
    // MARK: - Capture
    
    private var videoDeviceInput: AVCaptureDeviceInput?
    private let photoOutput = AVCapturePhotoOutput()
    private var inProgressPhotoCaptures = [Int64: PhotoCaptureProcessor]()
    
    // MARK: - Error Types
    
    enum CameraError: Error, LocalizedError {
        case cameraUnavailable
        case cannotAddInput
        case cannotAddOutput
        case configurationFailed
        
        var errorDescription: String? {
            switch self {
            case .cameraUnavailable: return "Camera is not available on this device"
            case .cannotAddInput: return "Cannot add camera input"
            case .cannotAddOutput: return "Cannot add photo output"
            case .configurationFailed: return "Camera configuration failed"
            }
        }
    }
    
    // MARK: - Initialization
    
    override init() {
        super.init()
    }
    
    deinit {
        stopSession()
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
                // Truy cập vào activeFormat của thiết bị đầu vào (videoDeviceInput)
                if let device = self.videoDeviceInput?.device {
                    photoOutput.maxPhotoDimensions = device.activeFormat.supportedMaxPhotoDimensions.last ?? .init(width: 0, height: 0)
                }
            } else {
                photoOutput.isHighResolutionCaptureEnabled = true
            }
            photoOutput.maxPhotoQualityPrioritization = .quality
            
            // Enable Live Photo if available
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
        
        // Start running
        startSession()
    }
    
    private func bestVideoDevice(for position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        // Try to get the best available camera
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
                    // Rollback
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
    
    // MARK: - Photo Capture
    
    func capturePhoto(preset: FilterPreset? = nil, completion: @escaping (UIImage?) -> Void) {
        sessionQueue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            // Configure settings
            var settings = AVCapturePhotoSettings()

            // Use HEVC if available
            if self.photoOutput.availablePhotoCodecTypes.contains(.hevc) {
                settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
            }

            // Flash
            if self.videoDeviceInput?.device.isFlashAvailable == true {
                settings.flashMode = self.flashMode
            }

            // Quality
            settings.isHighResolutionPhotoEnabled = true
            settings.photoQualityPrioritization = .quality

            // Create processor with preset for filtering
            let processor = PhotoCaptureProcessor(preset: preset, completion: completion)
            self.inProgressPhotoCaptures[settings.uniqueID] = processor

            self.photoOutput.capturePhoto(with: settings, delegate: processor)
        }
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

    init(preset: FilterPreset? = nil, completion: @escaping (UIImage?) -> Void) {
        self.preset = preset
        self.completion = completion
        super.init()
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
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

        // Apply filter if preset is provided
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
