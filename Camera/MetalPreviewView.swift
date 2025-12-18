// MetalPreviewView.swift
// Film Camera - Metal-based Camera Preview with Real-time Filtering

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

        init(preset: FilterPreset) {
            self.currentPreset = preset
            self.filterRenderer = FilterRenderer()
            super.init()

            CVMetalTextureCacheCreate(nil, nil, RenderEngine.shared.device, nil, &textureCache)
        }

        func setupVideoOutput(cameraManager: CameraManager) {
            // Check if video output already exists
            let existingOutputs = cameraManager.session.outputs.compactMap { $0 as? AVCaptureVideoDataOutput }

            if !existingOutputs.isEmpty {
                // Use existing output
                if let existingOutput = existingOutputs.first {
                    existingOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "video.output"))
                    videoOutputAdded = true
                }
                return
            }

            // Create new video output
            let videoOutput = AVCaptureVideoDataOutput()
            videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "video.output"))
            videoOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]

            // Add to session
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

        // MARK: - MTKViewDelegate

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            // Handle view size changes if needed
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

            // Apply filters and render to drawable
            filterRenderer.render(
                input: inputTexture,
                output: drawable.texture,
                preset: currentPreset,
                commandQueue: RenderEngine.shared.commandQueue
            )

            // Present drawable
            drawable.present()
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
