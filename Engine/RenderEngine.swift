// RenderEngine.swift
// Film Camera - Core Metal Rendering Engine
// ★★★ FIXED: Better error handling, debug logging, startup validation ★★★

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
    private let lutCacheLock = NSLock()
    
    // Reusable FilterRenderer for photo processing
    private var photoFilterRenderer: FilterRenderer?
    private let filterRendererLock = NSLock()
    
    // Texture loader for thread-safe texture creation
    private var textureLoader: MTKTextureLoader?
    
    // ★★★ NEW: Track initialization status ★★★
    private(set) var isInitialized = false
    private(set) var initializationErrors: [String] = []
    
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
        self.textureLoader = MTKTextureLoader(device: device)
        
        setupPipelines()
        validatePipelines()
    }
    
    // MARK: - Pipeline Setup
    
    private func setupPipelines() {
        print("🎬 RenderEngine: Setting up Metal pipelines...")
        print("   Device: \(device.name)")

        let vertexFunction = library.makeFunction(name: "vertexPassthrough")
        if vertexFunction == nil {
            let error = "Failed to load vertexPassthrough function"
            print("❌ RenderEngine: \(error)")
            initializationErrors.append(error)
        } else {
            print("✅ RenderEngine: Loaded vertexPassthrough")
        }

        // ★★★ List all available functions for debugging ★★★
        #if DEBUG
        print("📋 RenderEngine: Available Metal functions:")
        // Note: Can't enumerate functions directly, but we'll see which ones fail
        #endif

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
            let error = "\(fragmentName) shader not found in Metal library"
            print("⚠️ RenderEngine: \(error)")
            initializationErrors.append(error)
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
            let errorMsg = "Failed to create \(fragmentName) pipeline: \(error.localizedDescription)"
            print("❌ RenderEngine: \(errorMsg)")
            initializationErrors.append(errorMsg)
            return nil
        }
    }
    
    private func createPipelineWithTwoTextures(vertex: MTLFunction?, fragmentName: String) -> MTLRenderPipelineState? {
        return createPipeline(vertex: vertex, fragmentName: fragmentName)
    }
    
    // ★★★ NEW: Validate critical pipelines ★★★
    private func validatePipelines() {
        var criticalMissing: [String] = []
        
        if colorGradingPipeline == nil {
            criticalMissing.append("colorGrading")
        }
        if vignettePipeline == nil {
            criticalMissing.append("vignette")
        }
        if grainPipeline == nil {
            criticalMissing.append("grain")
        }
        if instantFramePipeline == nil {
            criticalMissing.append("instantFrame")
        }
        if bloomPipeline == nil {
            criticalMissing.append("bloom")
        }
        
        if criticalMissing.isEmpty {
            isInitialized = true
            print("✅ RenderEngine: All critical pipelines initialized successfully")
        } else {
            isInitialized = false
            print("❌ RenderEngine: CRITICAL - Missing pipelines: \(criticalMissing.joined(separator: ", "))")
            print("   This will cause rendering failures!")
        }
    }
    
    private func printPipelineStatus() {
        print("═══════════════════════════════════════════════════════════════")
        print("🎬 RenderEngine: Pipeline Status Summary")
        print("═══════════════════════════════════════════════════════════════")
        print("   Core Pipelines:")
        print("      colorGrading:    \(colorGradingPipeline != nil ? "✅" : "❌")")
        print("      vignette:        \(vignettePipeline != nil ? "✅" : "❌")")
        print("      grain:           \(grainPipeline != nil ? "✅" : "❌")")
        print("      instantFrame:    \(instantFramePipeline != nil ? "✅" : "❌")")
        print("      lensDistortion:  \(lensDistortionPipeline != nil ? "✅" : "❌")")
        print("")
        print("   Bloom Pipelines:")
        print("      bloom (legacy):  \(bloomPipeline != nil ? "✅" : "❌")")
        print("      bloomThreshold:  \(bloomThresholdPipeline != nil ? "✅" : "❌")")
        print("      bloomHorizontal: \(bloomHorizontalPipeline != nil ? "✅" : "❌")")
        print("      bloomVertical:   \(bloomVerticalPipeline != nil ? "✅" : "❌")")
        print("      bloomComposite:  \(bloomCompositePipeline != nil ? "✅" : "❌")")
        print("")
        print("   Halation Pipelines:")
        print("      halation (legacy): \(halationPipeline != nil ? "✅" : "❌")")
        print("      halationThreshold: \(halationThresholdPipeline != nil ? "✅" : "❌")")
        print("      halationHorizontal:\(halationHorizontalPipeline != nil ? "✅" : "❌")")
        print("      halationVertical:  \(halationVerticalPipeline != nil ? "✅" : "❌")")
        print("      halationComposite: \(halationCompositePipeline != nil ? "✅" : "❌")")
        print("")
        print("   Tone Mapping:")
        print("      toneMapping:     \(toneMappingPipeline != nil ? "✅" : "❌")")
        print("═══════════════════════════════════════════════════════════════")
        
        if !initializationErrors.isEmpty {
            print("⚠️ Initialization Errors:")
            for error in initializationErrors {
                print("   - \(error)")
            }
        }
    }
    
    // MARK: - LUT Management (Thread-Safe)

    /// All LUT files used by presets - for preloading
    private static let allLUTFiles: [String] = [
        "Kodak_Portra_400_Linear.cube",
        "Kodak_Portra_160_Linear.cube",
        "Fuji_400H_Linear.cube",
        "Kodak_Ultramax_400_linear_inout.cube",
        "Kodak_Gold_200_v2_linear.cube",
        "Kodak_ColorPlus_200_Linear.cube",
        "Fuji_Superia_400_Linear.cube",
        "Fuji_Velvia_100_Linear.cube",
        "provia_100f_33.cube",
        "Fuji_Astia_100F_Linear.cube",
        "Fuji_Eterna_linear.cube",
        "Kodak_Tri-X_400_Linear.cube",
        "Polaroid_600_Linear.cube",
        "Nostalgic_Neg_Linear.cube",
        "classic_chrome_linear.cube"
    ]

    /// ★ NEW: Preload all LUTs on background thread to eliminate UI jank
    /// Call this from app startup (e.g., in App.init or ContentView.onAppear)
    func preloadAllLUTs() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }

            let startTime = CFAbsoluteTimeGetCurrent()
            var loadedCount = 0

            print("🔄 RenderEngine: Preloading \(Self.allLUTFiles.count) LUTs...")

            for lutFile in Self.allLUTFiles {
                if self.loadLUT(named: lutFile) != nil {
                    loadedCount += 1
                }
            }

            let elapsed = CFAbsoluteTimeGetCurrent() - startTime
            print("✅ RenderEngine: Preloaded \(loadedCount)/\(Self.allLUTFiles.count) LUTs in \(String(format: "%.2f", elapsed))s")
        }
    }

    func loadLUT(named filename: String) -> MTLTexture? {
        lutCacheLock.lock()
        defer { lutCacheLock.unlock() }

        if let cached = lutCache[filename] {
            return cached
        }

        guard let texture = LUTLoader.load(filename: filename, device: device) else {
            print("⚠️ RenderEngine: Failed to load LUT: \(filename)")
            return nil
        }

        lutCache[filename] = texture
        print("✅ RenderEngine: LUT loaded and cached: \(filename)")
        return texture
    }

    func clearLUTCache() {
        lutCacheLock.lock()
        lutCache.removeAll()
        lutCacheLock.unlock()
        print("🧹 RenderEngine: LUT cache cleared")
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
    
    /// Create a texture from CGImage (thread-safe)
    func makeTexture(from cgImage: CGImage) -> MTLTexture? {
        guard let loader = textureLoader else {
            print("❌ RenderEngine: TextureLoader not initialized")
            return nil
        }
        
        do {
            let texture = try loader.newTexture(cgImage: cgImage, options: [
                .SRGB: false,
                .generateMipmaps: false,
                .textureUsage: NSNumber(value: MTLTextureUsage.shaderRead.rawValue)
            ])
            return texture
        } catch {
            print("❌ RenderEngine: Failed to create texture from CGImage: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - ★ NEW: Fast Preview for Gallery

    /// Apply filter with lightweight 2-pass pipeline for gallery preview
    /// Only includes: Color Grading (LUT) + Vignette
    /// Use this when scrolling through presets for fast response
    func applyFilterPreview(to image: UIImage, preset: FilterPreset) -> UIImage? {
        guard isInitialized else {
            print("❌ RenderEngine: Not initialized for preview")
            return nil
        }

        guard let cgImage = image.cgImage else {
            print("❌ RenderEngine: Failed to get CGImage for preview")
            return nil
        }

        guard let inputTexture = makeTexture(from: cgImage) else {
            print("❌ RenderEngine: Failed to create preview input texture")
            return nil
        }

        guard let outputTexture = texturePool.readableTexture(
            width: inputTexture.width,
            height: inputTexture.height,
            pixelFormat: .bgra8Unorm
        ) else {
            print("❌ RenderEngine: Failed to create preview output texture")
            return nil
        }

        filterRendererLock.lock()
        if photoFilterRenderer == nil {
            photoFilterRenderer = FilterRenderer()
        }
        let renderer = photoFilterRenderer!
        filterRendererLock.unlock()

        // Use lightweight 2-pass pipeline
        let success = renderer.renderGalleryPreview(
            input: inputTexture,
            output: outputTexture,
            preset: preset,
            commandQueue: commandQueue
        )

        guard success else {
            texturePool.recycle(outputTexture)
            return nil
        }

        guard let filteredCGImage = textureToCGImage(texture: outputTexture) else {
            texturePool.recycle(outputTexture)
            return nil
        }

        texturePool.recycle(outputTexture)

        return UIImage(
            cgImage: filteredCGImage,
            scale: image.scale,
            orientation: image.imageOrientation
        )
    }

    // MARK: - ★★★ FIXED: Photo Filtering with Better Error Handling ★★★

    /// Apply filter to UIImage and return filtered UIImage (FULL 13-pass pipeline)
    /// Thread-safe and includes comprehensive error handling
    func applyFilter(to image: UIImage, preset: FilterPreset) -> UIImage? {
        let startTime = CFAbsoluteTimeGetCurrent()
        print("🎨 RenderEngine.applyFilter: Starting for preset '\(preset.label)'")
        print("   UIImage size: \(Int(image.size.width))x\(Int(image.size.height))")
        
        // ★★★ FIX: Check if engine is properly initialized ★★★
        if !isInitialized {
            print("❌ RenderEngine: Engine not properly initialized! Errors: \(initializationErrors)")
            return nil
        }

        // Step 1: Get CGImage
        guard let cgImage = image.cgImage else {
            print("❌ RenderEngine: Failed to get CGImage from UIImage")
            return nil
        }
        
        print("   CGImage: \(cgImage.width)x\(cgImage.height), bpc: \(cgImage.bitsPerComponent)")

        // Step 2: Create input texture
        guard let inputTexture = makeTexture(from: cgImage) else {
            print("❌ RenderEngine: Failed to create input texture")
            return nil
        }
        
        print("✅ Input texture: \(inputTexture.width)x\(inputTexture.height), format: \(inputTexture.pixelFormat.rawValue)")

        // Step 3: Create output texture (CPU-readable)
        guard let outputTexture = texturePool.readableTexture(
            width: inputTexture.width,
            height: inputTexture.height,
            pixelFormat: .bgra8Unorm
        ) else {
            print("❌ RenderEngine: Failed to create output texture")
            return nil
        }
        
        print("✅ Output texture created")

        // Step 4: Get or create FilterRenderer (thread-safe)
        filterRendererLock.lock()
        if photoFilterRenderer == nil {
            photoFilterRenderer = FilterRenderer()
            print("   Created new FilterRenderer for photo processing")
        }
        let renderer = photoFilterRenderer!
        filterRendererLock.unlock()

        // Step 5: Render with synchronous GPU wait
        print("🔄 Starting renderSync...")
        let success = renderer.renderSync(
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
        
        print("✅ GPU rendering completed")

        // Step 6: Convert texture back to CGImage
        guard let filteredCGImage = textureToCGImage(texture: outputTexture) else {
            print("❌ RenderEngine: Failed to convert texture to CGImage")
            texturePool.recycle(outputTexture)
            return nil
        }
        
        print("✅ Converted to CGImage: \(filteredCGImage.width)x\(filteredCGImage.height)")

        // Step 7: Create UIImage with original orientation
        let filteredImage = UIImage(
            cgImage: filteredCGImage,
            scale: image.scale,
            orientation: image.imageOrientation
        )
        
        // Cleanup
        texturePool.recycle(outputTexture)
        
        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        print("✅ RenderEngine.applyFilter: Completed in \(String(format: "%.3f", elapsed))s")
        print("   Result: \(Int(filteredImage.size.width))x\(Int(filteredImage.size.height))")

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
            print("❌ RenderEngine: Failed to create CGDataProvider")
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
    
    // MARK: - Debug Helpers
    
    #if DEBUG
    func printPoolStatistics() {
        let stats = texturePool.statistics()
        print("📊 TexturePool: available=\(stats.available), inUse=\(stats.inUse)")
    }
    
    func printLUTCacheStatus() {
        lutCacheLock.lock()
        print("📊 LUT Cache: \(lutCache.count) entries")
        for (name, texture) in lutCache {
            print("   - \(name): \(texture.width)x\(texture.height)x\(texture.depth)")
        }
        lutCacheLock.unlock()
    }
    
    func printStatus() {
        print("")
        print("═══════════════════════════════════════════════════════════════")
        print("🔍 RenderEngine Status Report")
        print("═══════════════════════════════════════════════════════════════")
        print("   Initialized: \(isInitialized)")
        print("   Device: \(device.name)")
        printPoolStatistics()
        printLUTCacheStatus()
        print("═══════════════════════════════════════════════════════════════")
        print("")
    }
    #endif
}
