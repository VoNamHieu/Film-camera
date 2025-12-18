// MetalPreviewView.swift
// Film Camera - Metal-based Camera Preview with Real-time Filtering (FIXED VERSION)
// Fix: Drawable presentation through FilterRenderer, proper synchronization

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
        
        // ★ Enable auto-resize for rotation handling
        mtkView.autoResizeDrawable = true

        context.coordinator.setupVideoOutput(cameraManager: cameraManager)

        return mtkView
    }

    func updateUIView(_ uiView: MTKView, context: Context) {
        context.coordinator.currentPreset = selectedPreset
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(preset: selectedPreset)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, MTKViewDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {
        var currentPreset: FilterPreset
        private var currentPixelBuffer: CVPixelBuffer?
        private var textureCache: CVMetalTextureCache?
        private let filterRenderer: FilterRenderer
        private var videoOutputAdded = false
        
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
                    videoOutputAdded = true
                }
                return
            }

            let videoOutput = AVCaptureVideoDataOutput()
            videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "video.output", qos: .userInteractive))
            videoOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            
            // Drop late frames to maintain smooth preview
            videoOutput.alwaysDiscardsLateVideoFrames = true

            cameraManager.session.beginConfiguration()
            if cameraManager.session.canAddOutput(videoOutput) {
                cameraManager.session.addOutput(videoOutput)
                videoOutputAdded = true
            }
            cameraManager.session.commitConfiguration()
        }

        // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

        func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            currentPixelBuffer = pixelBuffer
        }
        
        func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
            // Frame dropped - this is expected under heavy load
        }

        // MARK: - MTKViewDelegate

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            // Handle view size changes (rotation, etc.)
            print("🎬 MetalPreviewView: Drawable size changed to \(size)")
        }

        func draw(in view: MTKView) {
            guard let pixelBuffer = currentPixelBuffer,
                  let drawable = view.currentDrawable,
                  let textureCache = textureCache else {
                return
            }

            // Create Metal texture from pixel buffer
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

            // ★ FIX: Use renderToDrawable which handles presentation correctly
            filterRenderer.renderToDrawable(
                input: inputTexture,
                drawable: drawable,
                preset: currentPreset,
                commandQueue: RenderEngine.shared.commandQueue
            )
            
            // ★ FIX: DO NOT call drawable.present() here!
            // FilterRenderer.renderToDrawable() handles it via commandBuffer.present(drawable)
            
            // Debug: Track frame rate
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
