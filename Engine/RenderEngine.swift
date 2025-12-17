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
        let vertexFunction = library.makeFunction(name: "vertexPassthrough")
        
        // Color Grading Pipeline
        if let fragmentFunction = library.makeFunction(name: "colorGradingFragment") {
            colorGradingPipeline = createPipeline(vertex: vertexFunction, fragment: fragmentFunction)
        }
        
        // Vignette Pipeline
        if let fragmentFunction = library.makeFunction(name: "vignetteFragment") {
            vignettePipeline = createPipeline(vertex: vertexFunction, fragment: fragmentFunction)
        }
        
        // Grain Pipeline
        if let fragmentFunction = library.makeFunction(name: "grainFragment") {
            grainPipeline = createPipeline(vertex: vertexFunction, fragment: fragmentFunction)
        }
        
        // Bloom Pipeline
        if let fragmentFunction = library.makeFunction(name: "bloomFragment") {
            bloomPipeline = createPipeline(vertex: vertexFunction, fragment: fragmentFunction)
        }
        
        // Halation Pipeline
        if let fragmentFunction = library.makeFunction(name: "halationFragment") {
            halationPipeline = createPipeline(vertex: vertexFunction, fragment: fragmentFunction)
        }
        
        // Instant Frame Pipeline
        if let fragmentFunction = library.makeFunction(name: "instantFrameFragment") {
            instantFramePipeline = createPipeline(vertex: vertexFunction, fragment: fragmentFunction)
        }
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
}
