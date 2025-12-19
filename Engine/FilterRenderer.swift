// FilterRenderer.swift
// Film Camera - Core Filter Rendering Pipeline
// ★★★ OPTIMIZED: Separate Preview (4 passes) vs Capture (full) pipelines ★★★

import Foundation
import Metal
import MetalKit

class FilterRenderer {

    private let device: MTLDevice
    private var renderPassDescriptor: MTLRenderPassDescriptor

    // Ping-pong buffers for proper texture management
    private var pingPongTextures: [MTLTexture?] = [nil, nil]
    private var pingPongIndex: Int = 0

    init() {
        self.device = RenderEngine.shared.device
        self.renderPassDescriptor = MTLRenderPassDescriptor()

        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
    }

    // MARK: - ★★★ OPTIMIZED: Preview Pipeline (4 passes, 60fps) ★★★
    
    /// Lightweight preview rendering for live viewfinder
    /// Only 4 passes: ColorGrading → Grain → Bloom(simple) → Vignette
    func renderPreview(input: MTLTexture, drawable: CAMetalDrawable, preset: FilterPreset, commandQueue: MTLCommandQueue) {
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            return
        }

        let texturePool = RenderEngine.shared.texturePool

        // Allocate ping-pong buffers at input resolution
        guard let temp1 = texturePool.renderTargetTexture(width: input.width, height: input.height, pixelFormat: .bgra8Unorm),
              let temp2 = texturePool.renderTargetTexture(width: input.width, height: input.height, pixelFormat: .bgra8Unorm) else {
            return
        }

        pingPongTextures[0] = temp1
        pingPongTextures[1] = temp2
        pingPongIndex = 0

        var currentInput = input

        // ═══════════════════════════════════════════════════════════════
        // PREVIEW PIPELINE: Only 4 passes for 60fps performance
        // ═══════════════════════════════════════════════════════════════

        // PASS 1: Color Grading (includes LUT, curves, selective color)
        if let result = applyColorGrading(input: currentInput, preset: preset, commandBuffer: commandBuffer) {
            currentInput = result
        }

        // PASS 2: Grain (lightweight)
        if preset.grain.enabled {
            if let result = applyGrain(input: currentInput, config: preset.grain, commandBuffer: commandBuffer) {
                currentInput = result
            }
        }

        // PASS 3: Bloom (single-pass simplified, radius capped at 8)
        if preset.bloom.enabled {
            if let result = applyBloomSimplified(input: currentInput, config: preset.bloom, commandBuffer: commandBuffer) {
                currentInput = result
            }
        }

        // PASS 4: Vignette
        if preset.vignette.enabled {
            if let result = applyVignette(input: currentInput, config: preset.vignette, commandBuffer: commandBuffer) {
                currentInput = result
            }
        }

        // ═══════════════════════════════════════════════════════════════
        // SKIPPED FOR PREVIEW (applied only during capture):
        // - Lens Distortion
        // - Halation (4 passes)
        // - Separable Bloom (use simplified instead)
        // - Instant Frame
        // ═══════════════════════════════════════════════════════════════

        // FINAL: Blit to drawable
        blitToOutput(source: currentInput, destination: drawable.texture, commandBuffer: commandBuffer)

        // Recycle textures after GPU completes
        commandBuffer.addCompletedHandler { [weak texturePool] _ in
            texturePool?.recycle(temp1)
            texturePool?.recycle(temp2)
        }

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    // MARK: - ★★★ Simplified Bloom (Single Pass, Radius 8) ★★★
    
    private func applyBloomSimplified(input: MTLTexture, config: BloomConfig, commandBuffer: MTLCommandBuffer) -> MTLTexture? {
        guard let pipeline = RenderEngine.shared.bloomPipeline,  // Use legacy single-pass
              let output = getNextOutputTexture() else { return nil }

        renderPassDescriptor.colorAttachments[0].texture = output
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return nil }

        renderEncoder.setRenderPipelineState(pipeline)
        renderEncoder.setFragmentTexture(input, index: 0)

        // ★ OPTIMIZED: Cap radius at 8 for preview, skip every other sample
        var params = BloomParams()
        params.intensity = config.intensity
        params.threshold = config.threshold
        params.radius = min(config.radius, 8.0)  // ★ MAX 8 for preview
        params.softness = config.softness
        params.colorTint = SIMD3<Float>(config.colorTint.r, config.colorTint.g, config.colorTint.b)
        params.enabled = 1

        renderEncoder.setFragmentBytes(&params, length: MemoryLayout<BloomParams>.stride, index: 0)
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        renderEncoder.endEncoding()

        return output
    }

    // MARK: - Full Quality Render (for Capture)
    
    /// Render directly to drawable with proper presentation (async, for preview)
    func renderToDrawable(input: MTLTexture, drawable: CAMetalDrawable, preset: FilterPreset, commandQueue: MTLCommandQueue) {
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            print("FilterRenderer: Failed to create command buffer")
            return
        }

        let texturePool = RenderEngine.shared.texturePool

        guard let temp1 = texturePool.renderTargetTexture(width: input.width, height: input.height, pixelFormat: .bgra8Unorm),
              let temp2 = texturePool.renderTargetTexture(width: input.width, height: input.height, pixelFormat: .bgra8Unorm) else {
            print("FilterRenderer: Failed to allocate intermediate textures")
            return
        }

        pingPongTextures[0] = temp1
        pingPongTextures[1] = temp2
        pingPongIndex = 0

        var currentInput = input

        // Execute FULL filter pipeline (13 passes)
        currentInput = executeFullPipeline(input: currentInput, preset: preset, commandBuffer: commandBuffer)

        // FINAL PASS: Blit to drawable
        blitToOutput(source: currentInput, destination: drawable.texture, commandBuffer: commandBuffer)

        commandBuffer.addCompletedHandler { [weak texturePool] _ in
            texturePool?.recycle(temp1)
            texturePool?.recycle(temp2)
        }

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    // MARK: - ★★★ Synchronous Render (for photo capture) ★★★
    
    /// Render to texture SYNCHRONOUSLY with FULL quality pipeline
    func renderSync(input: MTLTexture, output: MTLTexture, preset: FilterPreset, commandQueue: MTLCommandQueue) -> Bool {
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            print("FilterRenderer: Failed to create command buffer")
            return false
        }

        let texturePool = RenderEngine.shared.texturePool

        guard let temp1 = texturePool.renderTargetTexture(width: input.width, height: input.height, pixelFormat: .bgra8Unorm),
              let temp2 = texturePool.renderTargetTexture(width: input.width, height: input.height, pixelFormat: .bgra8Unorm) else {
            print("FilterRenderer: Failed to allocate intermediate textures")
            return false
        }

        pingPongTextures[0] = temp1
        pingPongTextures[1] = temp2
        pingPongIndex = 0

        var currentInput = input

        // Execute FULL pipeline for capture (all 13 passes)
        currentInput = executeFullPipeline(input: currentInput, preset: preset, commandBuffer: commandBuffer)

        // Final blit to output
        blitToOutput(source: currentInput, destination: output, commandBuffer: commandBuffer)

        // ★★★ CRITICAL: Commit and WAIT for GPU to complete ★★★
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        if let error = commandBuffer.error {
            print("❌ FilterRenderer: GPU error - \(error.localizedDescription)")
            texturePool.recycle(temp1)
            texturePool.recycle(temp2)
            return false
        }

        texturePool.recycle(temp1)
        texturePool.recycle(temp2)
        
        return true
    }
    
    // MARK: - Async Render (legacy)
    
    func render(input: MTLTexture, output: MTLTexture, preset: FilterPreset, commandQueue: MTLCommandQueue) {
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            return
        }

        let texturePool = RenderEngine.shared.texturePool

        guard let temp1 = texturePool.renderTargetTexture(width: input.width, height: input.height, pixelFormat: .bgra8Unorm),
              let temp2 = texturePool.renderTargetTexture(width: input.width, height: input.height, pixelFormat: .bgra8Unorm) else {
            return
        }

        pingPongTextures[0] = temp1
        pingPongTextures[1] = temp2
        pingPongIndex = 0

        var currentInput = input
        currentInput = executeFullPipeline(input: currentInput, preset: preset, commandBuffer: commandBuffer)
        blitToOutput(source: currentInput, destination: output, commandBuffer: commandBuffer)

        commandBuffer.addCompletedHandler { [weak texturePool] _ in
            texturePool?.recycle(temp1)
            texturePool?.recycle(temp2)
        }

        commandBuffer.commit()
    }

    // MARK: - Full Pipeline Execution (13 passes for capture)
    
    private func executeFullPipeline(input: MTLTexture, preset: FilterPreset, commandBuffer: MTLCommandBuffer) -> MTLTexture {
        var currentInput = input

        // PASS 1: Lens Distortion
        if preset.lensDistortion.enabled {
            if let result = applyLensDistortion(input: currentInput, params: preset.lensDistortion, commandBuffer: commandBuffer) {
                currentInput = result
            }
        }

        // PASS 2: Color Grading
        if let result = applyColorGrading(input: currentInput, preset: preset, commandBuffer: commandBuffer) {
            currentInput = result
        }

        // PASS 3: Grain
        if preset.grain.enabled {
            if let result = applyGrain(input: currentInput, config: preset.grain, commandBuffer: commandBuffer) {
                currentInput = result
            }
        }

        // PASS 4-7: Bloom (Separable - 4 passes) - FULL QUALITY
        if preset.bloom.enabled {
            if let result = applyBloomSeparable(input: currentInput, config: preset.bloom, commandBuffer: commandBuffer) {
                currentInput = result
            }
        }

        // PASS 8: Vignette
        if preset.vignette.enabled {
            if let result = applyVignette(input: currentInput, config: preset.vignette, commandBuffer: commandBuffer) {
                currentInput = result
            }
        }

        // PASS 9-12: Halation (Separable - 4 passes) - FULL QUALITY
        if preset.halation.enabled {
            if let result = applyHalationSeparable(input: currentInput, config: preset.halation, commandBuffer: commandBuffer) {
                currentInput = result
            }
        }

        // PASS 13: Instant Frame
        if preset.instantFrame.enabled {
            if let result = applyInstantFrame(input: currentInput, config: preset.instantFrame, commandBuffer: commandBuffer) {
                currentInput = result
            }
        }

        return currentInput
    }

    // MARK: - Ping-Pong Buffer Helper
    
    private func getNextOutputTexture() -> MTLTexture? {
        let output = pingPongTextures[pingPongIndex]
        pingPongIndex = 1 - pingPongIndex
        return output
    }

    // MARK: - Individual Filter Passes

    private func applyLensDistortion(input: MTLTexture, params: LensDistortionConfig, commandBuffer: MTLCommandBuffer) -> MTLTexture? {
        guard let pipeline = RenderEngine.shared.lensDistortionPipeline,
              let output = getNextOutputTexture() else { return nil }

        renderPassDescriptor.colorAttachments[0].texture = output
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return nil }

        renderEncoder.setRenderPipelineState(pipeline)
        renderEncoder.setFragmentTexture(input, index: 0)

        var metalParams = LensDistortionParams(
            enabled: params.enabled ? 1 : 0,
            k1: params.k1,
            k2: params.k2,
            caStrength: params.caStrength,
            scale: params.scale
        )
        renderEncoder.setFragmentBytes(&metalParams, length: MemoryLayout<LensDistortionParams>.stride, index: 0)

        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        renderEncoder.endEncoding()

        return output
    }

    private func applyColorGrading(input: MTLTexture, preset: FilterPreset, commandBuffer: MTLCommandBuffer) -> MTLTexture? {
        guard let pipeline = RenderEngine.shared.colorGradingPipeline,
              let output = getNextOutputTexture() else { return nil }

        renderPassDescriptor.colorAttachments[0].texture = output
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return nil }

        renderEncoder.setRenderPipelineState(pipeline)
        renderEncoder.setFragmentTexture(input, index: 0)

        var params = prepareColorGradingParams(preset)
        
        var lutLoaded = false
        if let lutFile = preset.lutFile, let lutTexture = RenderEngine.shared.loadLUT(named: lutFile) {
            renderEncoder.setFragmentTexture(lutTexture, index: 1)
            lutLoaded = true
        }
        
        params.useLUT = lutLoaded ? 1 : 0
        
        renderEncoder.setFragmentBytes(&params, length: MemoryLayout<ColorGradingParams>.stride, index: 0)
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        renderEncoder.endEncoding()

        return output
    }
    
    private func applyGrain(input: MTLTexture, config: GrainConfig, commandBuffer: MTLCommandBuffer) -> MTLTexture? {
        guard let pipeline = RenderEngine.shared.grainPipeline,
              let output = getNextOutputTexture() else { return nil }

        renderPassDescriptor.colorAttachments[0].texture = output
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return nil }

        renderEncoder.setRenderPipelineState(pipeline)
        renderEncoder.setFragmentTexture(input, index: 0)

        var params = prepareGrainParams(config)
        renderEncoder.setFragmentBytes(&params, length: MemoryLayout<GrainParams>.stride, index: 0)

        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        renderEncoder.endEncoding()

        return output
    }

    // MARK: - Separable Bloom Pipeline (4 passes) - CAPTURE ONLY
    
    private func applyBloomSeparable(input: MTLTexture, config: BloomConfig, commandBuffer: MTLCommandBuffer) -> MTLTexture? {
        let texturePool = RenderEngine.shared.texturePool
        
        guard let thresholdTex = texturePool.renderTargetTexture(width: input.width, height: input.height, pixelFormat: .bgra8Unorm),
              let horizontalTex = texturePool.renderTargetTexture(width: input.width, height: input.height, pixelFormat: .bgra8Unorm),
              let verticalTex = texturePool.renderTargetTexture(width: input.width, height: input.height, pixelFormat: .bgra8Unorm),
              let output = getNextOutputTexture() else { return nil }

        var params = prepareBloomParams(config)

        // Pass 1: Threshold extraction
        if let pipeline = RenderEngine.shared.bloomThresholdPipeline {
            renderPassDescriptor.colorAttachments[0].texture = thresholdTex
            if let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) {
                encoder.setRenderPipelineState(pipeline)
                encoder.setFragmentTexture(input, index: 0)
                encoder.setFragmentBytes(&params, length: MemoryLayout<BloomParams>.stride, index: 0)
                encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
                encoder.endEncoding()
            }
        }

        // Pass 2: Horizontal blur
        if let pipeline = RenderEngine.shared.bloomHorizontalPipeline {
            renderPassDescriptor.colorAttachments[0].texture = horizontalTex
            if let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) {
                encoder.setRenderPipelineState(pipeline)
                encoder.setFragmentTexture(thresholdTex, index: 0)
                encoder.setFragmentBytes(&params, length: MemoryLayout<BloomParams>.stride, index: 0)
                encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
                encoder.endEncoding()
            }
        }

        // Pass 3: Vertical blur
        if let pipeline = RenderEngine.shared.bloomVerticalPipeline {
            renderPassDescriptor.colorAttachments[0].texture = verticalTex
            if let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) {
                encoder.setRenderPipelineState(pipeline)
                encoder.setFragmentTexture(horizontalTex, index: 0)
                encoder.setFragmentBytes(&params, length: MemoryLayout<BloomParams>.stride, index: 0)
                encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
                encoder.endEncoding()
            }
        }

        // Pass 4: Composite
        if let pipeline = RenderEngine.shared.bloomCompositePipeline {
            renderPassDescriptor.colorAttachments[0].texture = output
            if let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) {
                encoder.setRenderPipelineState(pipeline)
                encoder.setFragmentTexture(input, index: 0)
                encoder.setFragmentTexture(verticalTex, index: 1)
                encoder.setFragmentBytes(&params, length: MemoryLayout<BloomParams>.stride, index: 0)
                encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
                encoder.endEncoding()
            }
        }

        commandBuffer.addCompletedHandler { [weak texturePool] _ in
            texturePool?.recycle(thresholdTex)
            texturePool?.recycle(horizontalTex)
            texturePool?.recycle(verticalTex)
        }

        return output
    }

    // MARK: - Separable Halation Pipeline (4 passes) - CAPTURE ONLY
    
    private func applyHalationSeparable(input: MTLTexture, config: HalationConfig, commandBuffer: MTLCommandBuffer) -> MTLTexture? {
        let texturePool = RenderEngine.shared.texturePool
        
        guard let thresholdTex = texturePool.renderTargetTexture(width: input.width, height: input.height, pixelFormat: .bgra8Unorm),
              let horizontalTex = texturePool.renderTargetTexture(width: input.width, height: input.height, pixelFormat: .bgra8Unorm),
              let verticalTex = texturePool.renderTargetTexture(width: input.width, height: input.height, pixelFormat: .bgra8Unorm),
              let output = getNextOutputTexture() else { return nil }

        var params = prepareHalationParams(config)

        // Pass 1: Threshold + red tint
        if let pipeline = RenderEngine.shared.halationThresholdPipeline {
            renderPassDescriptor.colorAttachments[0].texture = thresholdTex
            if let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) {
                encoder.setRenderPipelineState(pipeline)
                encoder.setFragmentTexture(input, index: 0)
                encoder.setFragmentBytes(&params, length: MemoryLayout<HalationParams>.stride, index: 0)
                encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
                encoder.endEncoding()
            }
        }

        // Pass 2: Horizontal blur
        if let pipeline = RenderEngine.shared.halationHorizontalPipeline {
            renderPassDescriptor.colorAttachments[0].texture = horizontalTex
            if let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) {
                encoder.setRenderPipelineState(pipeline)
                encoder.setFragmentTexture(thresholdTex, index: 0)
                encoder.setFragmentBytes(&params, length: MemoryLayout<HalationParams>.stride, index: 0)
                encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
                encoder.endEncoding()
            }
        }

        // Pass 3: Vertical blur
        if let pipeline = RenderEngine.shared.halationVerticalPipeline {
            renderPassDescriptor.colorAttachments[0].texture = verticalTex
            if let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) {
                encoder.setRenderPipelineState(pipeline)
                encoder.setFragmentTexture(horizontalTex, index: 0)
                encoder.setFragmentBytes(&params, length: MemoryLayout<HalationParams>.stride, index: 0)
                encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
                encoder.endEncoding()
            }
        }

        // Pass 4: Composite
        if let pipeline = RenderEngine.shared.halationCompositePipeline {
            renderPassDescriptor.colorAttachments[0].texture = output
            if let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) {
                encoder.setRenderPipelineState(pipeline)
                encoder.setFragmentTexture(input, index: 0)
                encoder.setFragmentTexture(verticalTex, index: 1)
                encoder.setFragmentBytes(&params, length: MemoryLayout<HalationParams>.stride, index: 0)
                encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
                encoder.endEncoding()
            }
        }

        commandBuffer.addCompletedHandler { [weak texturePool] _ in
            texturePool?.recycle(thresholdTex)
            texturePool?.recycle(horizontalTex)
            texturePool?.recycle(verticalTex)
        }

        return output
    }

    private func applyVignette(input: MTLTexture, config: VignetteConfig, commandBuffer: MTLCommandBuffer) -> MTLTexture? {
        guard let pipeline = RenderEngine.shared.vignettePipeline,
              let output = getNextOutputTexture() else { return nil }

        renderPassDescriptor.colorAttachments[0].texture = output
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return nil }

        renderEncoder.setRenderPipelineState(pipeline)
        renderEncoder.setFragmentTexture(input, index: 0)

        var params = prepareVignetteParams(config)
        renderEncoder.setFragmentBytes(&params, length: MemoryLayout<VignetteParams>.stride, index: 0)

        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        renderEncoder.endEncoding()

        return output
    }

    private func applyInstantFrame(input: MTLTexture, config: InstantFrameConfig, commandBuffer: MTLCommandBuffer) -> MTLTexture? {
        guard let pipeline = RenderEngine.shared.instantFramePipeline,
              let output = getNextOutputTexture() else { return nil }

        renderPassDescriptor.colorAttachments[0].texture = output
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return nil }

        renderEncoder.setRenderPipelineState(pipeline)
        renderEncoder.setFragmentTexture(input, index: 0)

        var params = prepareInstantFrameParams(config)
        renderEncoder.setFragmentBytes(&params, length: MemoryLayout<InstantFrameParams>.stride, index: 0)

        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        renderEncoder.endEncoding()

        return output
    }

    private func blitToOutput(source: MTLTexture, destination: MTLTexture, commandBuffer: MTLCommandBuffer) {
        guard let blitEncoder = commandBuffer.makeBlitCommandEncoder() else { return }
        let width = min(source.width, destination.width)
        let height = min(source.height, destination.height)
        blitEncoder.copy(from: source, sourceSlice: 0, sourceLevel: 0, sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0), sourceSize: MTLSize(width: width, height: height, depth: 1), to: destination, destinationSlice: 0, destinationLevel: 0, destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0))
        blitEncoder.endEncoding()
    }

    // MARK: - Parameter Preparation

    private func prepareColorGradingParams(_ preset: FilterPreset) -> ColorGradingParams {
        var params = ColorGradingParams()
        let adj = preset.colorAdjustments
        params.exposure = adj.exposure
        params.contrast = adj.contrast
        params.highlights = adj.highlights
        params.shadows = adj.shadows
        params.whites = adj.whites
        params.blacks = adj.blacks
        params.saturation = adj.saturation
        params.vibrance = adj.vibrance
        params.temperature = adj.temperature
        params.tint = adj.tint
        params.fade = adj.fade
        params.clarity = adj.clarity
        
        let split = preset.splitTone
        params.shadowsHue = split.shadowsHue
        params.shadowsSat = split.shadowsSat
        params.highlightsHue = split.highlightsHue
        params.highlightsSat = split.highlightsSat
        params.splitBalance = split.balance
        params.midtoneProtection = split.midtoneProtection
        
        params.selectiveColorCount = Int32(min(preset.selectiveColor.count, 8))
        for (i, selColor) in preset.selectiveColor.prefix(8).enumerated() {
            let colorData = SelectiveColorData(hue: selColor.hue, range: selColor.range, satAdj: selColor.sat, lumAdj: selColor.lum, hueShift: selColor.hueShift)
            params.setSelectiveColor(at: i, value: colorData)
        }
        
        params.lutIntensity = preset.lutIntensity
        params.useLUT = preset.lutFile != nil ? 1 : 0
        return params
    }

    private func prepareGrainParams(_ config: GrainConfig) -> GrainParams {
        var params = GrainParams()
        params.globalIntensity = config.globalIntensity
        params.size = config.channels.red.size
        params.softness = config.channels.red.softness
        params.enabled = config.enabled ? 1 : 0
        params.channelIntensity = SIMD3<Float>(config.channels.red.intensity, config.channels.green.intensity, config.channels.blue.intensity)
        if config.clumping.enabled {
            params.size *= (1.0 + config.clumping.clusterSize * 0.3)
            params.globalIntensity *= (1.0 - config.clumping.strength * 0.2)
        }
        return params
    }

    private func prepareBloomParams(_ config: BloomConfig) -> BloomParams {
        var params = BloomParams()
        params.intensity = config.intensity
        params.threshold = config.threshold
        params.radius = min(config.radius, 20.0)  // Full quality for capture
        params.softness = config.softness
        params.colorTint = SIMD3<Float>(config.colorTint.r, config.colorTint.g, config.colorTint.b)
        params.enabled = config.enabled ? 1 : 0
        return params
    }

    private func prepareVignetteParams(_ config: VignetteConfig) -> VignetteParams {
        var params = VignetteParams()
        params.intensity = config.intensity
        params.roundness = config.roundness
        params.feather = config.feather
        params.midpoint = config.midpoint
        params.enabled = config.enabled ? 1 : 0
        return params
    }

    private func prepareHalationParams(_ config: HalationConfig) -> HalationParams {
        var params = HalationParams()
        params.intensity = config.intensity
        params.threshold = config.threshold
        params.radius = min(config.radius, 25.0)  // Full quality for capture
        params.softness = config.softness
        params.color = SIMD3<Float>(config.color.r, config.color.g, config.color.b)
        params.enabled = config.enabled ? 1 : 0
        return params
    }

    private func prepareInstantFrameParams(_ config: InstantFrameConfig) -> InstantFrameParams {
        var params = InstantFrameParams()
        params.borderWidths = SIMD4<Float>(config.borderWidth.top, config.borderWidth.left, config.borderWidth.right, config.borderWidth.bottom)
        params.borderColor = SIMD3<Float>(config.borderColor.r, config.borderColor.g, config.borderColor.b)
        params.edgeFade = 0.05
        params.cornerDarkening = 0.08
        params.enabled = config.enabled ? 1 : 0
        return params
    }
}

extension ColorGradingParams {
    mutating func setSelectiveColor(at index: Int, value: SelectiveColorData) {
        switch index {
        case 0: selectiveColors.0 = value
        case 1: selectiveColors.1 = value
        case 2: selectiveColors.2 = value
        case 3: selectiveColors.3 = value
        case 4: selectiveColors.4 = value
        case 5: selectiveColors.5 = value
        case 6: selectiveColors.6 = value
        case 7: selectiveColors.7 = value
        default: break
        }
    }
}
