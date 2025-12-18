// RenderEngine.swift
// Film Camera - Core Metal Rendering Engine

import Foundation
import Metal
import MetalKit

/// Singleton Metal rendering engine
class RenderEngine {
    static let shared = RenderEngine()
    
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    let library: MTLLibrary
    let texturePool: TexturePool
    
    // Pipeline states
    private(set) var colorGradingPipeline: MTLRenderPipelineState?
    private(set) var vignettePipeline: MTLRenderPipelineState?
    private(set) var grainPipeline: MTLRenderPipelineState?
    private(set) var bloomPipeline: MTLRenderPipelineState?
    private(set) var halationPipeline: MTLRenderPipelineState?
    private(set) var instantFramePipeline: MTLRenderPipelineState?
    
    // LUT textures cache
    private var lutCache: [String: MTLTexture] = [:]
    
    private init() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this device")
        }
        self.device = device
        
        guard let commandQueue = device.makeCommandQueue() else {
            fatalError("Could not create command queue")
        }
        self.commandQueue = commandQueue
        
        guard let library = device.makeDefaultLibrary() else {
            fatalError("Could not load Metal library")
        }
        self.library = library
        
        self.texturePool = TexturePool(device: device)
        
        setupPipelines()
    }
    
    // MARK: - Pipeline Setup
    
    private func setupPipelines() {
        print("🎬 RenderEngine: Setting up Metal pipelines...")

        let vertexFunction = library.makeFunction(name: "vertexPassthrough")
        if vertexFunction == nil {
            print("❌ RenderEngine: Failed to load vertexPassthrough function")
        } else {
            print("✅ RenderEngine: Loaded vertexPassthrough")
        }

        // Color Grading Pipeline
        if let fragmentFunction = library.makeFunction(name: "colorGradingFragment") {
            colorGradingPipeline = createPipeline(vertex: vertexFunction, fragment: fragmentFunction)
            print(colorGradingPipeline != nil ? "✅ RenderEngine: colorGradingPipeline created" : "❌ RenderEngine: colorGradingPipeline FAILED")
        } else {
            print("❌ RenderEngine: Failed to load colorGradingFragment shader")
        }

        // Vignette Pipeline
        if let fragmentFunction = library.makeFunction(name: "vignetteFragment") {
            vignettePipeline = createPipeline(vertex: vertexFunction, fragment: fragmentFunction)
            print(vignettePipeline != nil ? "✅ RenderEngine: vignettePipeline created" : "❌ RenderEngine: vignettePipeline FAILED")
        } else {
            print("⚠️ RenderEngine: vignetteFragment shader not found")
        }

        // Grain Pipeline
        if let fragmentFunction = library.makeFunction(name: "grainFragment") {
            grainPipeline = createPipeline(vertex: vertexFunction, fragment: fragmentFunction)
            print(grainPipeline != nil ? "✅ RenderEngine: grainPipeline created" : "❌ RenderEngine: grainPipeline FAILED")
        } else {
            print("⚠️ RenderEngine: grainFragment shader not found")
        }

        // Bloom Pipeline
        if let fragmentFunction = library.makeFunction(name: "bloomFragment") {
            bloomPipeline = createPipeline(vertex: vertexFunction, fragment: fragmentFunction)
            print(bloomPipeline != nil ? "✅ RenderEngine: bloomPipeline created" : "❌ RenderEngine: bloomPipeline FAILED")
        } else {
            print("⚠️ RenderEngine: bloomFragment shader not found")
        }

        // Halation Pipeline
        if let fragmentFunction = library.makeFunction(name: "halationFragment") {
            halationPipeline = createPipeline(vertex: vertexFunction, fragment: fragmentFunction)
            print(halationPipeline != nil ? "✅ RenderEngine: halationPipeline created" : "❌ RenderEngine: halationPipeline FAILED")
        } else {
            print("⚠️ RenderEngine: halationFragment shader not found")
        }

        // Instant Frame Pipeline
        if let fragmentFunction = library.makeFunction(name: "instantFrameFragment") {
            instantFramePipeline = createPipeline(vertex: vertexFunction, fragment: fragmentFunction)
            print(instantFramePipeline != nil ? "✅ RenderEngine: instantFramePipeline created" : "❌ RenderEngine: instantFramePipeline FAILED")
        } else {
            print("⚠️ RenderEngine: instantFrameFragment shader not found")
        }

        print("🎬 RenderEngine: Pipeline setup complete")
    }
    
    private func createPipeline(vertex: MTLFunction?, fragment: MTLFunction?) -> MTLRenderPipelineState? {
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertex
        descriptor.fragmentFunction = fragment
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        do {
            return try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            print("Failed to create pipeline: \(error)")
            return nil
        }
    }
    
    // MARK: - LUT Management
    
    func loadLUT(named filename: String) -> MTLTexture? {
        if let cached = lutCache[filename] {
            return cached
        }
        
        guard let texture = LUTLoader.load(filename: filename, device: device) else {
            return nil
        }
        
        lutCache[filename] = texture
        return texture
    }
    
    func clearLUTCache() {
        lutCache.removeAll()
    }
    
    // MARK: - Rendering
    
    /// Blit (copy) source texture to drawable
    func blit(source: MTLTexture, to drawable: CAMetalDrawable) {
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let blitEncoder = commandBuffer.makeBlitCommandEncoder() else {
            return
        }
        
        let destTexture = drawable.texture
        let copyWidth = min(source.width, destTexture.width)
        let copyHeight = min(source.height, destTexture.height)
        
        blitEncoder.copy(
            from: source,
            sourceSlice: 0,
            sourceLevel: 0,
            sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
            sourceSize: MTLSize(width: copyWidth, height: copyHeight, depth: 1),
            to: destTexture,
            destinationSlice: 0,
            destinationLevel: 0,
            destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0)
        )
        
        blitEncoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
    /// Create a texture from CGImage
    func makeTexture(from cgImage: CGImage) -> MTLTexture? {
        let loader = MTKTextureLoader(device: device)
        return try? loader.newTexture(cgImage: cgImage, options: [
            .SRGB: false,
            .generateMipmaps: false
        ])
    }

    // MARK: - Photo Filtering

    /// Apply filter to UIImage and return filtered UIImage
    func applyFilter(to image: UIImage, preset: FilterPreset) -> UIImage? {
        print("🎨 RenderEngine: Applying filter to captured photo...")

        guard let cgImage = image.cgImage else {
            print("❌ RenderEngine: Failed to get CGImage from UIImage")
            return nil
        }

        // Convert UIImage → MTLTexture
        guard let inputTexture = makeTexture(from: cgImage) else {
            print("❌ RenderEngine: Failed to create input texture")
            return nil
        }

        // Create output texture
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: inputTexture.width,
            height: inputTexture.height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]

        guard let outputTexture = device.makeTexture(descriptor: descriptor) else {
            print("❌ RenderEngine: Failed to create output texture")
            return nil
        }

        // Apply filter using FilterRenderer
        let filterRenderer = FilterRenderer()
        filterRenderer.render(
            input: inputTexture,
            output: outputTexture,
            preset: preset,
            commandQueue: commandQueue
        )

        // Wait for GPU to finish
        commandQueue.insertDebugCaptureBoundary()

        // Convert MTLTexture → CGImage → UIImage
        guard let filteredCGImage = textureToCGImage(texture: outputTexture) else {
            print("❌ RenderEngine: Failed to convert texture to CGImage")
            return nil
        }

        let filteredImage = UIImage(cgImage: filteredCGImage, scale: image.scale, orientation: image.imageOrientation)
        print("✅ RenderEngine: Filter applied successfully")

        return filteredImage
    }

    /// Convert MTLTexture to CGImage
    private func textureToCGImage(texture: MTLTexture) -> CGImage? {
        let width = texture.width
        let height = texture.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8

        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)

        let region = MTLRegion(
            origin: MTLOrigin(x: 0, y: 0, z: 0),
            size: MTLSize(width: width, height: height, depth: 1)
        )

        texture.getBytes(
            &pixelData,
            bytesPerRow: bytesPerRow,
            from: region,
            mipmapLevel: 0
        )

        guard let dataProvider = CGDataProvider(data: Data(pixelData) as CFData) else {
            return nil
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bitsPerPixel: bytesPerPixel * bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo,
            provider: dataProvider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }
}
