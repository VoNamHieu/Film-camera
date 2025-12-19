// MetalPreviewView.swift
// Film Camera - Metal-based Camera Preview with Real-time Filtering
// ★★★ FIXED: Video orientation only updates when changed, not every frame ★★★

import SwiftUI
import MetalKit
import AVFoundation

struct MetalPreviewView: UIViewRepresentable {
    @ObservedObject var cameraManager: CameraManager
    @Binding var selectedPreset: FilterPreset

    func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.device = RenderEngine.shared.device
        mtkView.delegate = context.coordinator
        mtkView.framebufferOnly = false
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.preferredFramesPerSecond = 60
        mtkView.enableSetNeedsDisplay = false
        mtkView.isPaused = false
        mtkView.autoResizeDrawable = true

        context.coordinator.setupVideoOutput(cameraManager: cameraManager)

        return mtkView
    }

    func updateUIView(_ uiView: MTKView, context: Context) {
        context.coordinator.currentPreset = selectedPreset
        context.coordinator.isFrontCamera = cameraManager.currentPosition == .front
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(preset: selectedPreset)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, MTKViewDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {
        var currentPreset: FilterPreset
        var isFrontCamera: Bool = false {
            didSet {
                if oldValue != isFrontCamera {
                    orientationNeedsUpdate = true  // ★ Only update when changed
                }
            }
        }
        
        private var currentPixelBuffer: CVPixelBuffer?
        private var textureCache: CVMetalTextureCache?
        private let filterRenderer: FilterRenderer
        private var videoOutputAdded = false
        
        // ★★★ FIX: Track orientation state to avoid per-frame updates ★★★
        private var orientationNeedsUpdate = true
        private var lastConfiguredOrientation: CGFloat = 90
        
        // Frame timing for debugging
        private var lastFrameTime: CFAbsoluteTime = 0
        private var frameCount: Int = 0

        init(preset: FilterPreset) {
            self.currentPreset = preset
            self.filterRenderer = FilterRenderer()
            super.init()

            CVMetalTextureCacheCreate(nil, nil, RenderEngine.shared.device, nil, &textureCache)
            
            // ★ Observe orientation changes
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(orientationDidChange),
                name: UIDevice.orientationDidChangeNotification,
                object: nil
            )
        }
        
        deinit {
            NotificationCenter.default.removeObserver(self)
        }
        
        @objc private func orientationDidChange() {
            orientationNeedsUpdate = true
        }

        func setupVideoOutput(cameraManager: CameraManager) {
            let existingOutputs = cameraManager.session.outputs.compactMap { $0 as? AVCaptureVideoDataOutput }

            if !existingOutputs.isEmpty {
                if let existingOutput = existingOutputs.first {
                    existingOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "video.output", qos: .userInteractive))
                    
                    if let connection = existingOutput.connection(with: .video) {
                        configureVideoOrientation(connection)
                    }
                    
                    videoOutputAdded = true
                }
                return
            }

            let videoOutput = AVCaptureVideoDataOutput()
            videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "video.output", qos: .userInteractive))
            videoOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            videoOutput.alwaysDiscardsLateVideoFrames = true

            cameraManager.session.beginConfiguration()
            if cameraManager.session.canAddOutput(videoOutput) {
                cameraManager.session.addOutput(videoOutput)
                
                if let connection = videoOutput.connection(with: .video) {
                    configureVideoOrientation(connection)
                }
                
                videoOutputAdded = true
            }
            cameraManager.session.commitConfiguration()
        }
        
        // ★★★ FIXED: Only configure when needed ★★★
        private func configureVideoOrientation(_ connection: AVCaptureConnection) {
            // Set video orientation to portrait
            if connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
                lastConfiguredOrientation = 90
            }
            
            // Handle mirroring for front camera
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = isFrontCamera
            }
            
            orientationNeedsUpdate = false
        }

        // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

        func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
            // ★★★ FIX: Only update orientation when needed, not every frame ★★★
            if orientationNeedsUpdate {
                configureVideoOrientation(connection)
            }
            
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            currentPixelBuffer = pixelBuffer
        }
        
        func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
            // Frame dropped - expected under heavy load
            #if DEBUG
            print("⚠️ MetalPreviewView: Frame dropped")
            #endif
        }

        // MARK: - MTKViewDelegate

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            print("🎬 MetalPreviewView: Drawable size changed to \(size)")
            orientationNeedsUpdate = true  // ★ May need reconfig after resize
        }

        func draw(in view: MTKView) {
            guard let pixelBuffer = currentPixelBuffer,
                  let drawable = view.currentDrawable,
                  let textureCache = textureCache else {
                return
            }

            var cvTexture: CVMetalTexture?
            let width = CVPixelBufferGetWidth(pixelBuffer)
            let height = CVPixelBufferGetHeight(pixelBuffer)

            let status = CVMetalTextureCacheCreateTextureFromImage(
                nil,
                textureCache,
                pixelBuffer,
                nil,
                .bgra8Unorm,
                width,
                height,
                0,
                &cvTexture
            )

            guard status == kCVReturnSuccess,
                  let cvTexture = cvTexture,
                  let inputTexture = CVMetalTextureGetTexture(cvTexture) else {
                return
            }

            filterRenderer.renderToDrawable(
                input: inputTexture,
                drawable: drawable,
                preset: currentPreset,
                commandQueue: RenderEngine.shared.commandQueue
            )
            
            #if DEBUG
            trackFrameRate()
            #endif
        }
        
        private func trackFrameRate() {
            frameCount += 1
            let now = CFAbsoluteTimeGetCurrent()
            if now - lastFrameTime >= 1.0 {
                let fps = Double(frameCount) / (now - lastFrameTime)
                if fps < 25 {
                    print("⚠️ MetalPreviewView: Low FPS: \(Int(fps))")
                }
                frameCount = 0
                lastFrameTime = now
            }
        }
    }
}

// MARK: - Preview

#Preview {
    MetalPreviewView(
        cameraManager: CameraManager(),
        selectedPreset: .constant(FilterPreset(
            id: "preview",
            label: "Preview",
            category: .professional
        ))
    )
    .ignoresSafeArea()
}
