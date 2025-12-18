// FilterRenderer.swift
// Film Camera - Core Filter Rendering Pipeline (Adapter Layer)

import Foundation
import Metal
import MetalKit

class FilterRenderer {

    private let device: MTLDevice
    private var renderPassDescriptor: MTLRenderPassDescriptor

    init() {
        self.device = RenderEngine.shared.device
        self.renderPassDescriptor = MTLRenderPassDescriptor()

        // Configure render pass (single color attachment)
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
    }

    // MARK: - Main Rendering Pipeline

    func render(input: MTLTexture, output: MTLTexture, preset: FilterPreset, commandQueue: MTLCommandQueue) {
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            print("FilterRenderer: Failed to create command buffer")
            return
        }

        // Get texture pool
        let texturePool = RenderEngine.shared.texturePool

        // FIXED: requestTexture -> renderTargetTexture
        guard let temp1 = texturePool.renderTargetTexture(width: input.width, height: input.height, pixelFormat: .bgra8Unorm),
              let temp2 = texturePool.renderTargetTexture(width: input.width, height: input.height, pixelFormat: .bgra8Unorm) else {
            print("FilterRenderer: Failed to allocate intermediate textures")
            return
        }

        var currentInput = input
        var currentOutput = temp1

        // PASS 1: Lens Distortion
        if preset.lensDistortion.enabled {
            if applyLensDistortion(input: currentInput, output: currentOutput,
                                  params: preset.lensDistortion, commandBuffer: commandBuffer) {
                swap(&currentInput, &currentOutput)
            }
        }

        // PASS 2: Color Grading
        if applyColorGrading(input: currentInput, output: currentOutput,
                           preset: preset, commandBuffer: commandBuffer) {
            swap(&currentInput, &currentOutput)
        }

        // PASS 3: Grain
        if preset.grain.enabled {
            if applyGrain(input: currentInput, output: currentOutput,
                        config: preset.grain, commandBuffer: commandBuffer) {
                swap(&currentInput, &currentOutput)
            }
        }

        // PASS 4: Bloom
        if preset.bloom.enabled {
            if applyBloom(input: currentInput, output: currentOutput,
                        config: preset.bloom, commandBuffer: commandBuffer) {
                swap(&currentInput, &currentOutput)
            }
        }

        // PASS 5: Vignette
        if preset.vignette.enabled {
            if applyVignette(input: currentInput, output: currentOutput,
                           config: preset.vignette, commandBuffer: commandBuffer) {
                swap(&currentInput, &currentOutput)
            }
        }

        // PASS 6: Halation
        if preset.halation.enabled {
            if applyHalation(input: currentInput, output: currentOutput,
                           config: preset.halation, commandBuffer: commandBuffer) {
                swap(&currentInput, &currentOutput)
            }
        }

        // PASS 7: Instant Frame
        if preset.instantFrame.enabled {
            if applyInstantFrame(input: currentInput, output: currentOutput,
                               config: preset.instantFrame, commandBuffer: commandBuffer) {
                swap(&currentInput, &currentOutput)
            }
        }

        // FINAL PASS
        blitToOutput(source: currentInput, destination: output, commandBuffer: commandBuffer)

        commandBuffer.commit()

        // FIXED: returnTexture -> recycle
        texturePool.recycle(temp1)
        texturePool.recycle(temp2)
    }

    // MARK: - Individual Filter Passes

    private func applyLensDistortion(input: MTLTexture, output: MTLTexture,
                                     params: LensDistortionConfig, commandBuffer: MTLCommandBuffer) -> Bool {
        // Placeholder implementation
        return false
    }

    private func applyColorGrading(input: MTLTexture, output: MTLTexture,
                                   preset: FilterPreset, commandBuffer: MTLCommandBuffer) -> Bool {
        guard let pipeline = RenderEngine.shared.colorGradingPipeline else { return false }

        renderPassDescriptor.colorAttachments[0].texture = output
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return false }

        renderEncoder.setRenderPipelineState(pipeline)
        renderEncoder.setFragmentTexture(input, index: 0)

        var params = prepareColorGradingParams(preset)
        renderEncoder.setFragmentBytes(&params, length: MemoryLayout<ColorGradingParams>.stride, index: 0)

        if let lutFile = preset.lutFile, let lutTexture = RenderEngine.shared.loadLUT(named: lutFile) {
            renderEncoder.setFragmentTexture(lutTexture, index: 1)
        }

        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        renderEncoder.endEncoding()

        return true
    }

    private func applyGrain(input: MTLTexture, output: MTLTexture,
                           config: GrainConfig, commandBuffer: MTLCommandBuffer) -> Bool {
        guard let pipeline = RenderEngine.shared.grainPipeline else { return false }

        renderPassDescriptor.colorAttachments[0].texture = output
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return false }

        renderEncoder.setRenderPipelineState(pipeline)
        renderEncoder.setFragmentTexture(input, index: 0)

        var params = prepareGrainParams(config)
        renderEncoder.setFragmentBytes(&params, length: MemoryLayout<GrainParams>.stride, index: 0)

        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        renderEncoder.endEncoding()

        return true
    }

    private func applyBloom(input: MTLTexture, output: MTLTexture,
                           config: BloomConfig, commandBuffer: MTLCommandBuffer) -> Bool {
        guard let thresholdPipeline = RenderEngine.shared.bloomThresholdPipeline,
              let hBlurPipeline = RenderEngine.shared.blurHorizontalPipeline,
              let vBlurPipeline = RenderEngine.shared.blurVerticalPipeline,
              let compositePipeline = RenderEngine.shared.bloomCompositePipeline else {
            print("⚠️ FilterRenderer: Bloom 4-pass pipelines not available")
            return false
        }

        let texturePool = RenderEngine.shared.texturePool
        let width = input.width
        let height = input.height

        // Allocate intermediate textures
        guard let bloomThreshold = texturePool.renderTargetTexture(width: width, height: height, pixelFormat: .bgra8Unorm),
              let blurH = texturePool.renderTargetTexture(width: width, height: height, pixelFormat: .bgra8Unorm),
              let blurV = texturePool.renderTargetTexture(width: width, height: height, pixelFormat: .bgra8Unorm) else {
            print("⚠️ FilterRenderer: Failed to allocate bloom intermediate textures")
            return false
        }

        var params = prepareBloomParams(config)
        var radius = config.radius

        // Pass 1: Extract bright pixels
        renderPassDescriptor.colorAttachments[0].texture = bloomThreshold
        if let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) {
            encoder.setRenderPipelineState(thresholdPipeline)
            encoder.setFragmentTexture(input, index: 0)
            encoder.setFragmentBytes(&params, length: MemoryLayout<BloomParams>.stride, index: 0)
            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            encoder.endEncoding()
        }

        // Pass 2: Horizontal blur
        renderPassDescriptor.colorAttachments[0].texture = blurH
        if let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) {
            encoder.setRenderPipelineState(hBlurPipeline)
            encoder.setFragmentTexture(bloomThreshold, index: 0)
            encoder.setFragmentBytes(&radius, length: MemoryLayout<Float>.stride, index: 0)
            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            encoder.endEncoding()
        }

        // Pass 3: Vertical blur
        renderPassDescriptor.colorAttachments[0].texture = blurV
        if let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) {
            encoder.setRenderPipelineState(vBlurPipeline)
            encoder.setFragmentTexture(blurH, index: 0)
            encoder.setFragmentBytes(&radius, length: MemoryLayout<Float>.stride, index: 0)
            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            encoder.endEncoding()
        }

        // Pass 4: Composite bloom with original
        renderPassDescriptor.colorAttachments[0].texture = output
        if let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) {
            encoder.setRenderPipelineState(compositePipeline)
            encoder.setFragmentTexture(input, index: 0)
            encoder.setFragmentTexture(blurV, index: 1)
            encoder.setFragmentBytes(&params, length: MemoryLayout<BloomParams>.stride, index: 0)
            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            encoder.endEncoding()
        }

        // Recycle textures after GPU completes
        commandBuffer.addCompletedHandler { _ in
            texturePool.recycle(bloomThreshold)
            texturePool.recycle(blurH)
            texturePool.recycle(blurV)
        }

        return true
    }

    private func applyVignette(input: MTLTexture, output: MTLTexture,
                              config: VignetteConfig, commandBuffer: MTLCommandBuffer) -> Bool {
        guard let pipeline = RenderEngine.shared.vignettePipeline else { return false }

        renderPassDescriptor.colorAttachments[0].texture = output
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return false }

        renderEncoder.setRenderPipelineState(pipeline)
        renderEncoder.setFragmentTexture(input, index: 0)

        var params = prepareVignetteParams(config)
        renderEncoder.setFragmentBytes(&params, length: MemoryLayout<VignetteParams>.stride, index: 0)

        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        renderEncoder.endEncoding()

        return true
    }

    private func applyHalation(input: MTLTexture, output: MTLTexture,
                              config: HalationConfig, commandBuffer: MTLCommandBuffer) -> Bool {
        guard let thresholdPipeline = RenderEngine.shared.halationThresholdPipeline,
              let hBlurPipeline = RenderEngine.shared.blurHorizontalPipeline,
              let vBlurPipeline = RenderEngine.shared.blurVerticalPipeline,
              let compositePipeline = RenderEngine.shared.halationCompositePipeline else {
            print("⚠️ FilterRenderer: Halation 4-pass pipelines not available")
            return false
        }

        let texturePool = RenderEngine.shared.texturePool
        let width = input.width
        let height = input.height

        // Allocate intermediate textures
        guard let halationThreshold = texturePool.renderTargetTexture(width: width, height: height, pixelFormat: .bgra8Unorm),
              let blurH = texturePool.renderTargetTexture(width: width, height: height, pixelFormat: .bgra8Unorm),
              let blurV = texturePool.renderTargetTexture(width: width, height: height, pixelFormat: .bgra8Unorm) else {
            print("⚠️ FilterRenderer: Failed to allocate halation intermediate textures")
            return false
        }

        var params = prepareHalationParams(config)
        var radius = config.radius

        // Pass 1: Extract bright pixels with red/orange tint
        renderPassDescriptor.colorAttachments[0].texture = halationThreshold
        if let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) {
            encoder.setRenderPipelineState(thresholdPipeline)
            encoder.setFragmentTexture(input, index: 0)
            encoder.setFragmentBytes(&params, length: MemoryLayout<HalationParams>.stride, index: 0)
            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            encoder.endEncoding()
        }

        // Pass 2: Horizontal blur (reuse bloom blur shader)
        renderPassDescriptor.colorAttachments[0].texture = blurH
        if let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) {
            encoder.setRenderPipelineState(hBlurPipeline)
            encoder.setFragmentTexture(halationThreshold, index: 0)
            encoder.setFragmentBytes(&radius, length: MemoryLayout<Float>.stride, index: 0)
            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            encoder.endEncoding()
        }

        // Pass 3: Vertical blur (reuse bloom blur shader)
        renderPassDescriptor.colorAttachments[0].texture = blurV
        if let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) {
            encoder.setRenderPipelineState(vBlurPipeline)
            encoder.setFragmentTexture(blurH, index: 0)
            encoder.setFragmentBytes(&radius, length: MemoryLayout<Float>.stride, index: 0)
            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            encoder.endEncoding()
        }

        // Pass 4: Composite halation with original
        renderPassDescriptor.colorAttachments[0].texture = output
        if let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) {
            encoder.setRenderPipelineState(compositePipeline)
            encoder.setFragmentTexture(input, index: 0)
            encoder.setFragmentTexture(blurV, index: 1)
            encoder.setFragmentBytes(&params, length: MemoryLayout<HalationParams>.stride, index: 0)
            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            encoder.endEncoding()
        }

        // Recycle textures after GPU completes
        commandBuffer.addCompletedHandler { _ in
            texturePool.recycle(halationThreshold)
            texturePool.recycle(blurH)
            texturePool.recycle(blurV)
        }

        return true
    }

    private func applyInstantFrame(input: MTLTexture, output: MTLTexture,
                                  config: InstantFrameConfig, commandBuffer: MTLCommandBuffer) -> Bool {
        guard let pipeline = RenderEngine.shared.instantFramePipeline else { return false }

        renderPassDescriptor.colorAttachments[0].texture = output
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return false }

        renderEncoder.setRenderPipelineState(pipeline)
        renderEncoder.setFragmentTexture(input, index: 0)

        var params = prepareInstantFrameParams(config)
        renderEncoder.setFragmentBytes(&params, length: MemoryLayout<InstantFrameParams>.stride, index: 0)

        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        renderEncoder.endEncoding()

        return true
    }

    private func blitToOutput(source: MTLTexture, destination: MTLTexture, commandBuffer: MTLCommandBuffer) {
        guard let blitEncoder = commandBuffer.makeBlitCommandEncoder() else { return }
        let width = min(source.width, destination.width)
        let height = min(source.height, destination.height)
        blitEncoder.copy(from: source, sourceSlice: 0, sourceLevel: 0, sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0), sourceSize: MTLSize(width: width, height: height, depth: 1), to: destination, destinationSlice: 0, destinationLevel: 0, destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0))
        blitEncoder.endEncoding()
    }

    // MARK: - ADAPTER LOGIC

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
        
        // Selective Color Map
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
        params.radius = config.radius
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
        params.radius = config.radius
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
