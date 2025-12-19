// RenderEngine.swift
// Film Camera - Core Metal Rendering Engine
// ★★★ FIXED: GPU synchronization in applyFilter() ★★★

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
    
    // Core Pipeline States
    private(set) var colorGradingPipeline: MTLRenderPipelineState?
    private(set) var vignettePipeline: MTLRenderPipelineState?
    private(set) var grainPipeline: MTLRenderPipelineState?
    private(set) var instantFramePipeline: MTLRenderPipelineState?
    private(set) var lensDistortionPipeline: MTLRenderPipelineState?
    
    // Legacy single-pass (for fallback)
    private(set) var bloomPipeline: MTLRenderPipelineState?
    private(set) var halationPipeline: MTLRenderPipelineState?
    
    // Separable Bloom Pipeline (4 passes)
    private(set) var bloomThresholdPipeline: MTLRenderPipelineState?
    private(set) var bloomHorizontalPipeline: MTLRenderPipelineState?
    private(set) var bloomVerticalPipeline: MTLRenderPipelineState?
    private(set) var bloomCompositePipeline: MTLRenderPipelineState?
    
    // Separable Halation Pipeline (4 passes)
    private(set) var halationThresholdPipeline: MTLRenderPipelineState?
    private(set) var halationHorizontalPipeline: MTLRenderPipelineState?
    private(set) var halationVerticalPipeline: MTLRenderPipelineState?
    private(set) var halationCompositePipeline: MTLRenderPipelineState?
    
    // Tone Mapping
    private(set) var toneMappingPipeline: MTLRenderPipelineState?
    
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

        // Core Pipelines
        colorGradingPipeline = createPipeline(vertex: vertexFunction, fragmentName: "colorGradingFragment")
        vignettePipeline = createPipeline(vertex: vertexFunction, fragmentName: "vignetteFragment")
        grainPipeline = createPipeline(vertex: vertexFunction, fragmentName: "grainFragment")
        instantFramePipeline = createPipeline(vertex: vertexFunction, fragmentName: "instantFrameFragment")
        lensDistortionPipeline = createPipeline(vertex: vertexFunction, fragmentName: "lensDistortionFragment")
        
        // Legacy single-pass (fallback)
        bloomPipeline = createPipeline(vertex: vertexFunction, fragmentName: "bloomFragment")
        halationPipeline = createPipeline(vertex: vertexFunction, fragmentName: "halationFragment")
        
        // Separable Bloom Pipeline
        bloomThresholdPipeline = createPipeline(vertex: vertexFunction, fragmentName: "bloomThresholdFragment")
        bloomHorizontalPipeline = createPipeline(vertex: vertexFunction, fragmentName: "bloomHorizontalFragment")
        bloomVerticalPipeline = createPipeline(vertex: vertexFunction, fragmentName: "bloomVerticalFragment")
        bloomCompositePipeline = createPipelineWithTwoTextures(vertex: vertexFunction, fragmentName: "bloomCompositeFragment")
        
        // Separable Halation Pipeline
        halationThresholdPipeline = createPipeline(vertex: vertexFunction, fragmentName: "halationThresholdFragment")
        halationHorizontalPipeline = createPipeline(vertex: vertexFunction, fragmentName: "halationHorizontalFragment")
        halationVerticalPipeline = createPipeline(vertex: vertexFunction, fragmentName: "halationVerticalFragment")
        halationCompositePipeline = createPipelineWithTwoTextures(vertex: vertexFunction, fragmentName: "halationCompositeFragment")
        
        // Tone Mapping
        toneMappingPipeline = createPipeline(vertex: vertexFunction, fragmentName: "toneMappingFragment")

        printPipelineStatus()
    }
    
    private func createPipeline(vertex: MTLFunction?, fragmentName: String) -> MTLRenderPipelineState? {
        guard let fragmentFunction = library.makeFunction(name: fragmentName) else {
            print("⚠️ RenderEngine: \(fragmentName) shader not found")
            return nil
        }
        
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertex
        descriptor.fragmentFunction = fragmentFunction
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        do {
            let pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
            print("✅ RenderEngine: \(fragmentName) pipeline created")
            return pipeline
        } catch {
            print("❌ RenderEngine: Failed to create \(fragmentName) pipeline: \(error)")
            return nil
        }
    }
    
    private func createPipelineWithTwoTextures(vertex: MTLFunction?, fragmentName: String) -> MTLRenderPipelineState? {
        return createPipeline(vertex: vertex, fragmentName: fragmentName)
    }
    
    private func printPipelineStatus() {
        print("🎬 RenderEngine: Pipeline setup complete")
        print("   Core: colorGrading=\(colorGradingPipeline != nil), vignette=\(vignettePipeline != nil), grain=\(grainPipeline != nil)")
        print("   Separable Bloom: threshold=\(bloomThresholdPipeline != nil), h=\(bloomHorizontalPipeline != nil), v=\(bloomVerticalPipeline != nil), composite=\(bloomCompositePipeline != nil)")
        print("   Separable Halation: threshold=\(halationThresholdPipeline != nil), h=\(halationHorizontalPipeline != nil), v=\(halationVerticalPipeline != nil), composite=\(halationCompositePipeline != nil)")
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
    
    // ★★★ FIXED: GPU Synchronization ★★★
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

        // Use readable texture for CPU access
        guard let outputTexture = texturePool.readableTexture(
            width: inputTexture.width,
            height: inputTexture.height,
            pixelFormat: .bgra8Unorm
        ) else {
            print("❌ RenderEngine: Failed to create output texture")
            return nil
        }

        // ★★★ FIX: Use synchronous rendering with proper GPU wait ★★★
        let filterRenderer = FilterRenderer()
        
        // renderSync() returns only after GPU completes
        let success = filterRenderer.renderSync(
            input: inputTexture,
            output: outputTexture,
            preset: preset,
            commandQueue: commandQueue
        )
        
        guard success else {
            print("❌ RenderEngine: Filter rendering failed")
            texturePool.recycle(outputTexture)
            return nil
        }

        // Convert MTLTexture → CGImage → UIImage
        guard let filteredCGImage = textureToCGImage(texture: outputTexture) else {
            print("❌ RenderEngine: Failed to convert texture to CGImage")
            texturePool.recycle(outputTexture)
            return nil
        }

        let filteredImage = UIImage(cgImage: filteredCGImage, scale: image.scale, orientation: image.imageOrientation)
        print("✅ RenderEngine: Filter applied successfully")
        
        // Recycle output texture
        texturePool.recycle(outputTexture)

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
        
        // BGRA → RGBA conversion (Metal uses BGRA, CGImage expects RGBA)
        for i in stride(from: 0, to: pixelData.count, by: 4) {
            let b = pixelData[i]
            pixelData[i] = pixelData[i + 2]  // R
            pixelData[i + 2] = b              // B
        }

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
