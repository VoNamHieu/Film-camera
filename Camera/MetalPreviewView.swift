// MetalPreviewView.swift
// Film Camera - Metal-based Camera Preview with Real-time Filtering
// ★ FIX: Added proper video orientation handling

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
        // ★ Update camera position for mirror handling
        context.coordinator.isFrontCamera = cameraManager.currentPosition == .front
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(preset: selectedPreset)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, MTKViewDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {
        var currentPreset: FilterPreset
        var isFrontCamera: Bool = false
        
        private var currentPixelBuffer: CVPixelBuffer?
        private var textureCache: CVMetalTextureCache?
        private let filterRenderer: FilterRenderer
        private var videoOutputAdded = false
        
        // ★ FIX: Track video orientation
        private var videoOrientation: CGImagePropertyOrientation = .up
        
        // Frame timing for debugging
        private var lastFrameTime: CFAbsoluteTime = 0
        private var frameCount: Int = 0

        init(preset: FilterPreset) {
            self.currentPreset = preset
            self.filterRenderer = FilterRenderer()
            super.init()

            CVMetalTextureCacheCreate(nil, nil, RenderEngine.shared.device, nil, &textureCache)
        }

        func setupVideoOutput(cameraManager: CameraManager) {
            let existingOutputs = cameraManager.session.outputs.compactMap { $0 as? AVCaptureVideoDataOutput }

            if !existingOutputs.isEmpty {
                if let existingOutput = existingOutputs.first {
                    existingOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "video.output", qos: .userInteractive))
                    
                    // ★ FIX: Set video orientation on connection
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
                
                // ★ FIX: Configure orientation AFTER adding output
                if let connection = videoOutput.connection(with: .video) {
                    configureVideoOrientation(connection)
                }
                
                videoOutputAdded = true
            }
            cameraManager.session.commitConfiguration()
        }
        
        // ★ FIX: Configure video orientation for portrait mode
        private func configureVideoOrientation(_ connection: AVCaptureConnection) {
            // Set video orientation to portrait
            if connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90  // Portrait orientation
            }
            
            // Handle mirroring for front camera
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = isFrontCamera
            }
        }

        // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

        func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
            // ★ FIX: Update orientation on each frame (handles rotation changes)
            configureVideoOrientation(connection)
            
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            currentPixelBuffer = pixelBuffer
        }
        
        func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
            // Frame dropped - expected under heavy load
        }

        // MARK: - MTKViewDelegate

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            print("🎬 MetalPreviewView: Drawable size changed to \(size)")
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
                if fps < 30 {
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
