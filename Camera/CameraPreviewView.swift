// CameraPreviewView.swift
// Film Camera - Production Ready Camera Preview
// ★★★ FIXED: focus parameter, getCurrentZoomFactor, iOS 26 deprecation ★★★

import SwiftUI
import AVFoundation

struct CameraPreviewView: UIViewRepresentable {
    @ObservedObject var cameraManager: CameraManager
    
    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.session = cameraManager.session
        
        // Add tap gesture for focus
        let tapGesture = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        view.addGestureRecognizer(tapGesture)
        
        // Add pinch gesture for zoom
        let pinchGesture = UIPinchGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePinch(_:))
        )
        view.addGestureRecognizer(pinchGesture)
        
        return view
    }
    
    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        // Session is already connected via property
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(cameraManager: cameraManager)
    }
    
    // MARK: - Coordinator
    
    class Coordinator: NSObject {
        private let cameraManager: CameraManager
        private var initialZoomFactor: CGFloat = 1.0
        
        init(cameraManager: CameraManager) {
            self.cameraManager = cameraManager
            super.init()
        }
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let previewView = gesture.view as? CameraPreviewUIView else { return }
            
            let location = gesture.location(in: previewView)
            let focusPoint = previewView.videoPreviewLayer.captureDevicePointConverted(fromLayerPoint: location)
            
            // ★★★ FIX: Pass the view parameter to focus method ★★★
            cameraManager.focus(at: focusPoint, in: previewView)
            showFocusAnimation(at: location, in: previewView)
        }
        
        @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            switch gesture.state {
            case .began:
                // ★★★ FIX: Use property instead of method ★★★
                initialZoomFactor = cameraManager.currentZoomFactor
            case .changed:
                let newZoomFactor = initialZoomFactor * gesture.scale
                cameraManager.setZoom(newZoomFactor)
            default:
                break
            }
        }
        
        private func showFocusAnimation(at point: CGPoint, in view: UIView) {
            // Remove existing focus indicators
            view.subviews.filter { $0.tag == 999 }.forEach { $0.removeFromSuperview() }
            
            // Create focus indicator
            let size: CGFloat = 80
            let focusView = UIView(frame: CGRect(x: 0, y: 0, width: size, height: size))
            focusView.center = point
            focusView.tag = 999
            focusView.backgroundColor = .clear
            focusView.layer.borderColor = UIColor.yellow.cgColor
            focusView.layer.borderWidth = 1.5
            focusView.layer.cornerRadius = 4
            focusView.alpha = 0
            focusView.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
            
            view.addSubview(focusView)
            
            // Animate
            UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseOut]) {
                focusView.alpha = 1
                focusView.transform = .identity
            } completion: { _ in
                UIView.animate(withDuration: 0.15, delay: 0.5, options: []) {
                    focusView.alpha = 0
                } completion: { _ in
                    focusView.removeFromSuperview()
                }
            }
        }
    }
}

// MARK: - Camera Preview UIView

final class CameraPreviewUIView: UIView {
    
    // MARK: - Layer Class
    
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }
    
    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
    
    // MARK: - Session
    
    var session: AVCaptureSession? {
        get { videoPreviewLayer.session }
        set { videoPreviewLayer.session = newValue }
    }
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        backgroundColor = .black
        videoPreviewLayer.videoGravity = .resizeAspectFill
    }
    
    // MARK: - Layout
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Update orientation if needed
        if let connection = videoPreviewLayer.connection {
            updateOrientation(for: connection)
        }
    }
    
    private func updateOrientation(for connection: AVCaptureConnection) {
        guard connection.isVideoRotationAngleSupported(0) else { return }
        
        // ★★★ FIX: Use new API for iOS 26+ ★★★
        let rotationAngle: CGFloat
        
        #if compiler(>=6.0)
        // iOS 26+ uses effectiveGeometry
        if #available(iOS 26.0, *) {
            // Use trait collection or scene-based approach
            if let windowScene = window?.windowScene {
                let orientation = windowScene.effectiveGeometry.interfaceOrientation
                switch orientation {
                case .unknown:
                    rotationAngle = 90
                case .portrait:
                    rotationAngle = 90
                case .portraitUpsideDown:
                    rotationAngle = 270
                case .landscapeLeft:
                    rotationAngle = 180
                case .landscapeRight:
                    rotationAngle = 0
                @unknown default:
                    rotationAngle = 90
                }
            } else {
                rotationAngle = 90
            }
        } else {
            // Fallback for older iOS
            rotationAngle = getRotationAngleFromWindowScene()
        }
        #else
        rotationAngle = getRotationAngleFromWindowScene()
        #endif
        
        if connection.isVideoRotationAngleSupported(rotationAngle) {
            connection.videoRotationAngle = rotationAngle
        }
    }
    
    /// Get rotation angle from window scene (works on iOS 16+)
    private func getRotationAngleFromWindowScene() -> CGFloat {
        guard let windowScene = window?.windowScene else { return 90 }
        
        let interfaceOrientation = windowScene.interfaceOrientation

        switch interfaceOrientation {
        case .unknown:
            return 90
        case .portrait:
            return 90
        case .portraitUpsideDown:
            return 270
        case .landscapeLeft:
            return 180
        case .landscapeRight:
            return 0
        @unknown default:
            return 90
        }
    }
}

// MARK: - Preview

#Preview {
    CameraPreviewView(cameraManager: CameraManager())
        .ignoresSafeArea()
}
