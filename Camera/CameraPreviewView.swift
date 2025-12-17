// CameraPreviewView.swift
// Film Camera - Production Ready Camera Preview

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
            
            cameraManager.focus(at: focusPoint)
            showFocusAnimation(at: location, in: previewView)
        }
        
        @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            switch gesture.state {
            case .began:
                initialZoomFactor = gesture.scale
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
        
        let interfaceOrientation = window?.windowScene?.interfaceOrientation ?? .portrait
        
        let rotationAngle: CGFloat
        switch interfaceOrientation {
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
        
        if connection.isVideoRotationAngleSupported(rotationAngle) {
            connection.videoRotationAngle = rotationAngle
        }
    }
}

// MARK: - Preview

#Preview {
    CameraPreviewView(cameraManager: CameraManager())
        .ignoresSafeArea()
}
