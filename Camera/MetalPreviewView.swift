// MetalPreviewView.swift
// Film Camera - Metal-based Camera Preview with Real-time Filtering
// ★★★ OPTIMIZED: 1080p preview + 4-pass pipeline for 60fps ★★★

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
                    orientationNeedsUpdate = true
                }
            }
        }

        // ★★★ FIX: Keep weak reference to cameraManager for frame forwarding ★★★
        weak var cameraManager: CameraManager?

        private var currentPixelBuffer: CVPixelBuffer?
        private var currentSampleBuffer: CMSampleBuffer?
        private var textureCache: CVMetalTextureCache?
        private let filterRenderer: FilterRenderer
        private var videoOutputAdded = false

        // Orientation tracking
        private var orientationNeedsUpdate = true
        private var lastConfiguredOrientation: CGFloat = 90

        // Frame timing for debugging
        private var lastFrameTime: CFAbsoluteTime = 0
        private var frameCount: Int = 0
        private var droppedFrameCount: Int = 0

        init(preset: FilterPreset) {
            self.currentPreset = preset
            self.filterRenderer = FilterRenderer()
            super.init()

            // ★★★ FIX: Validate texture cache creation ★★★
            var cache: CVMetalTextureCache?
            let status = CVMetalTextureCacheCreate(nil, nil, RenderEngine.shared.device, nil, &cache)
            if status == kCVReturnSuccess {
                textureCache = cache
                print("✅ MetalPreviewView: Texture cache created")
            } else {
                print("❌ MetalPreviewView: Failed to create texture cache, status: \(status)")
            }

            // Observe orientation changes
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
            // ★★★ FIX: Store reference for frame forwarding ★★★
            self.cameraManager = cameraManager

            let existingOutputs = cameraManager.session.outputs.compactMap { $0 as? AVCaptureVideoDataOutput }

            if !existingOutputs.isEmpty {
                if let existingOutput = existingOutputs.first {
                    // ★★★ FIX: Take over delegate but forward frames when recording ★★★
                    existingOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "video.preview", qos: .userInteractive))

                    if let connection = existingOutput.connection(with: .video) {
                        configureVideoOrientation(connection)
                    }

                    videoOutputAdded = true
                    print("✅ MetalPreviewView: Using existing video output")
                }
                return
            }

            // Create new video output if none exists
            let videoOutput = AVCaptureVideoDataOutput()
            videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "video.preview", qos: .userInteractive))

            // Request BGRA format for optimal Metal performance
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
                print("✅ MetalPreviewView: Created new video output")
            }
            cameraManager.session.commitConfiguration()
        }
        
        private func configureVideoOrientation(_ connection: AVCaptureConnection) {
            if connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
                lastConfiguredOrientation = 90
            }
            
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = isFrontCamera
            }
            
            orientationNeedsUpdate = false
        }

        // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

        func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
            if orientationNeedsUpdate {
                configureVideoOrientation(connection)
            }

            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            currentPixelBuffer = pixelBuffer

            // ★★★ FIX: Forward frames to CameraManager for video recording ★★★
            if let manager = cameraManager, manager.isRecording {
                manager.handleVideoFrame(sampleBuffer)
            }
        }

        func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
            droppedFrameCount += 1
            #if DEBUG
            if droppedFrameCount % 10 == 0 {
                print("⚠️ MetalPreviewView: Dropped \(droppedFrameCount) frames total")
            }
            #endif
        }

        // MARK: - MTKViewDelegate

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            print("🎬 MetalPreviewView: Drawable size changed to \(size)")
            orientationNeedsUpdate = true
        }

        func draw(in view: MTKView) {
            guard let pixelBuffer = currentPixelBuffer,
                  let drawable = view.currentDrawable,
                  let textureCache = textureCache else {
                return
            }

            // Create texture from pixel buffer (already 1080p from AVCaptureSession)
            guard let inputTexture = createTexture(from: pixelBuffer, cache: textureCache) else {
                return
            }

            // ★★★ Use optimized preview pipeline (Option B: 4 passes) ★★★
            // Skips: Lens Distortion, Halation (4 passes), Instant Frame
            // Uses: ColorGrading, Grain, Bloom (simplified), Vignette
            filterRenderer.renderPreview(
                input: inputTexture,
                drawable: drawable,
                preset: currentPreset,
                commandQueue: RenderEngine.shared.commandQueue
            )
            
            #if DEBUG
            trackFrameRate()
            #endif
        }
        
        // MARK: - Texture Creation
        
        private func createTexture(from pixelBuffer: CVPixelBuffer, cache: CVMetalTextureCache) -> MTLTexture? {
            var cvTexture: CVMetalTexture?
            let width = CVPixelBufferGetWidth(pixelBuffer)
            let height = CVPixelBufferGetHeight(pixelBuffer)

            let status = CVMetalTextureCacheCreateTextureFromImage(
                nil,
                cache,
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
                  let texture = CVMetalTextureGetTexture(cvTexture) else {
                return nil
            }
            
            return texture
        }
        
        private func trackFrameRate() {
            frameCount += 1
            let now = CFAbsoluteTimeGetCurrent()
            if now - lastFrameTime >= 2.0 {  // Log every 2 seconds
                let fps = Double(frameCount) / (now - lastFrameTime)
                if fps < 55 {
                    print("⚠️ MetalPreviewView: FPS: \(Int(fps)) (target: 60)")
                } else {
                    print("✅ MetalPreviewView: FPS: \(Int(fps))")
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
