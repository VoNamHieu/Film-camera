import Foundation
import Metal
import MetalKit

class FilterRenderer {

    private let device: MTLDevice
    private var renderPassDescriptor: MTLRenderPassDescriptor

    // Ping-pong buffers for proper texture management
    private var pingPongTextures: [MTLTexture?] = [nil, nil]
    private var pingPongIndex: Int = 0
    
    // DEBUG: Frame counter for periodic logging
    private var frameCount: Int = 0
    private var lastLogTime: CFAbsoluteTime = 0

    init() {
        self.device = RenderEngine.shared.device
        self.renderPassDescriptor = MTLRenderPassDescriptor()

        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
    }

    // MARK: - Preview Pipeline with Proper Scaling
    
    /// Lightweight preview rendering for live viewfinder
    /// Includes: Scale → ColorGrading → Grain → Bloom(simple) → Vignette → InstantFrame
    func renderPreview(input: MTLTexture, drawable: CAMetalDrawable, preset: FilterPreset, commandQueue: MTLCommandQueue) {
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            print("❌ FilterRenderer: Failed to create command buffer")
            return
        }

        let texturePool = RenderEngine.shared.texturePool
        
        // Use DRAWABLE size for intermediate textures to prevent black borders
        let outputWidth = drawable.texture.width
        let outputHeight = drawable.texture.height

        // Allocate ping-pong buffers at OUTPUT resolution (not input!)
        guard let temp1 = texturePool.renderTargetTexture(width: outputWidth, height: outputHeight, pixelFormat: .bgra8Unorm),
              let temp2 = texturePool.renderTargetTexture(width: outputWidth, height: outputHeight, pixelFormat: .bgra8Unorm) else {
            print("❌ FilterRenderer: Failed to allocate intermediate textures")
            return
        }

        pingPongTextures[0] = temp1
        pingPongTextures[1] = temp2
        pingPongIndex = 0

        var currentInput: MTLTexture = input
        var passCount = 0
        var failedPasses: [String] = []

        // ═══════════════════════════════════════════════════════════════
        // PREVIEW PIPELINE: Scale + 5 passes for good quality with decent performance
        // ═══════════════════════════════════════════════════════════════
        
        // PASS 0: Scale input to drawable size (fixes black border)
        if input.width != outputWidth || input.height != outputHeight {
            if let scaled = scaleTexture(input: input, commandBuffer: commandBuffer) {
                currentInput = scaled
                passCount += 1
            } else {
                failedPasses.append("Scale")
            }
        }

        // PASS 1: Color Grading (includes LUT, curves, selective color)
        if let result = applyColorGrading(input: currentInput, preset: preset, commandBuffer: commandBuffer) {
            currentInput = result
            passCount += 1
        } else {
            failedPasses.append("ColorGrading")
        }

        // PASS 1.5: Black & White Conversion (AFTER color grading for proper channel mixing)
        if preset.bw.enabled {
            if let result = applyBWConvert(input: currentInput, config: preset.bw, commandBuffer: commandBuffer) {
                currentInput = result
                passCount += 1
            } else {
                failedPasses.append("BWConvert")
            }
        }

        // PASS 2: Flash (BEFORE Bloom so flash areas glow)
        if preset.flash.enabled {
            if let result = applyFlash(input: currentInput, config: preset.flash, commandBuffer: commandBuffer) {
                currentInput = result
                passCount += 1
            } else {
                failedPasses.append("Flash")
            }
        }

        // PASS 3: CCD Bloom (Digicam vertical smear - alternative to standard bloom)
        if preset.ccdBloom.enabled {
            if let result = applyCCDBloom(input: currentInput, config: preset.ccdBloom, commandBuffer: commandBuffer) {
                currentInput = result
                passCount += 1
            } else {
                failedPasses.append("CCDBloom")
            }
        }

        // PASS 4: Bloom (single-pass simplified, radius capped at 8)
        if preset.bloom.enabled {
            if let result = applyBloomSimplified(input: currentInput, config: preset.bloom, commandBuffer: commandBuffer) {
                currentInput = result
                passCount += 1
            } else {
                failedPasses.append("Bloom")
            }
        }

        // PASS 4: Vignette
        if preset.vignette.enabled {
            if let result = applyVignette(input: currentInput, config: preset.vignette, commandBuffer: commandBuffer) {
                currentInput = result
                passCount += 1
            } else {
                failedPasses.append("Vignette")
            }
        }

        // PASS 5: Grain (AFTER lighting effects for natural appearance)
        if preset.grain.enabled {
            if let result = applyGrain(input: currentInput, config: preset.grain, commandBuffer: commandBuffer) {
                currentInput = result
                passCount += 1
            } else {
                failedPasses.append("Grain")
            }
        }

        // PASS 6: Light Leak (Procedural light leak effect)
        if preset.lightLeak.enabled {
            if let result = applyLightLeak(input: currentInput, config: preset.lightLeak, commandBuffer: commandBuffer) {
                currentInput = result
                passCount += 1
            } else {
                failedPasses.append("LightLeak")
            }
        }

        // PASS 7: Date Stamp (Procedural 7-segment display)
        if preset.dateStamp.enabled {
            if let result = applyDateStamp(input: currentInput, config: preset.dateStamp, commandBuffer: commandBuffer) {
                currentInput = result
                passCount += 1
            } else {
                failedPasses.append("DateStamp")
            }
        }

        // PASS 8: Overlays (Dust & Scratches - applied to image, not frame)
        if preset.overlays.enabled {
            if let result = applyOverlays(input: currentInput, config: preset.overlays, commandBuffer: commandBuffer) {
                currentInput = result
                passCount += 1
            } else {
                failedPasses.append("Overlays")
            }
        }

        // PASS 9: Instant Frame (for Polaroid/Instax look)
        if preset.instantFrame.enabled {
            if let result = applyInstantFrame(input: currentInput, config: preset.instantFrame, commandBuffer: commandBuffer) {
                currentInput = result
                passCount += 1
            } else {
                failedPasses.append("InstantFrame")
            }
        }

        // ═══════════════════════════════════════════════════════════════
        // DEBUG LOGGING (periodic, not every frame)
        // ═══════════════════════════════════════════════════════════════
        frameCount += 1
        let now = CFAbsoluteTimeGetCurrent()
        if now - lastLogTime >= 5.0 {  // Log every 5 seconds
            if !failedPasses.isEmpty {
                print("⚠️ FilterRenderer: Failed passes in last 5s: \(failedPasses.joined(separator: ", "))")
            }
            #if DEBUG
            print("📊 FilterRenderer Preview: \(frameCount) frames in 5s, preset: \(preset.label)")
            print("   Input: \(input.width)x\(input.height) → Drawable: \(outputWidth)x\(outputHeight)")
            if preset.instantFrame.enabled {
                print("   InstantFrame: enabled, border=\(preset.instantFrame.borderWidth)")
            }
            #endif
            lastLogTime = now
            frameCount = 0
        }

        // FINAL: Blit to drawable (now sizes match, no black borders!)
        blitToOutput(source: currentInput, destination: drawable.texture, commandBuffer: commandBuffer)

        // Recycle textures after GPU completes
        commandBuffer.addCompletedHandler { [weak texturePool] _ in
            texturePool?.recycle(temp1)
            texturePool?.recycle(temp2)
        }

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
    // MARK: - ★★★ FIXED V4: Aspect-Fill Scale with Correct Aspect Ratio ★★★

    /// Scales input texture to match ping-pong buffer size using ASPECT-FILL
    /// This maintains the correct aspect ratio by cropping (not stretching)
    ///
    /// Uses vertexAspectFill shader to calculate UV correction based on:
    ///   inputAspect  = input.width / input.height
    ///   outputAspect = output.width / output.height
    ///
    /// Result: Objects (InstantFrame, Vignette, etc.) maintain correct proportions
    private func scaleTexture(input: MTLTexture, commandBuffer: MTLCommandBuffer) -> MTLTexture? {
        guard let pipeline = RenderEngine.shared.aspectFillScalePipeline,
              let output = getNextOutputTexture() else {
            // Fallback to old pipeline if aspect-fill not available
            return scaleTextureFallback(input: input, commandBuffer: commandBuffer)
        }

        renderPassDescriptor.colorAttachments[0].texture = output
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return nil }

        renderEncoder.setRenderPipelineState(pipeline)
        renderEncoder.setFragmentTexture(input, index: 0)

        // ★★★ NEW: Pass aspect ratio params to vertex shader ★★★
        var aspectParams = AspectScaleParams()
        aspectParams.inputAspect = Float(input.width) / Float(input.height)
        aspectParams.outputAspect = Float(output.width) / Float(output.height)
        renderEncoder.setVertexBytes(&aspectParams, length: MemoryLayout<AspectScaleParams>.stride, index: 0)

        // Fragment shader params: neutral passthrough
        var params = ColorGradingParams()
        params.exposure = 0.0
        params.contrast = 0.0
        params.highlights = 0.0
        params.shadows = 0.0
        params.whites = 0.0
        params.blacks = 0.0
        params.saturation = 0.0
        params.vibrance = 0.0
        params.temperature = 0.0
        params.tint = 0.0
        params.fade = 0.0
        params.clarity = 0.0
        params.shadowsHue = 0.0
        params.shadowsSat = 0.0
        params.highlightsHue = 0.0
        params.highlightsSat = 0.0
        params.splitBalance = 0.0
        params.midtoneProtection = 0.5
        params.selectiveColorCount = 0
        params.lutIntensity = 0.0
        params.useLUT = 0

        renderEncoder.setFragmentBytes(&params, length: MemoryLayout<ColorGradingParams>.stride, index: 0)
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        renderEncoder.endEncoding()

        return output
    }

    // Fallback for when aspectFillScalePipeline is not available
    private func scaleTextureFallback(input: MTLTexture, commandBuffer: MTLCommandBuffer) -> MTLTexture? {
        guard let pipeline = RenderEngine.shared.colorGradingPipeline,
              let output = getNextOutputTexture() else {
            return nil
        }

        renderPassDescriptor.colorAttachments[0].texture = output
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return nil }

        renderEncoder.setRenderPipelineState(pipeline)
        renderEncoder.setFragmentTexture(input, index: 0)

        var params = ColorGradingParams()
        params.exposure = 0.0
        params.contrast = 0.0
        params.highlights = 0.0
        params.shadows = 0.0
        params.whites = 0.0
        params.blacks = 0.0
        params.saturation = 0.0
        params.vibrance = 0.0
        params.temperature = 0.0
        params.tint = 0.0
        params.fade = 0.0
        params.clarity = 0.0
        params.shadowsHue = 0.0
        params.shadowsSat = 0.0
        params.highlightsHue = 0.0
        params.highlightsSat = 0.0
        params.splitBalance = 0.0
        params.midtoneProtection = 0.5
        params.selectiveColorCount = 0
        params.lutIntensity = 0.0
        params.useLUT = 0

        renderEncoder.setFragmentBytes(&params, length: MemoryLayout<ColorGradingParams>.stride, index: 0)
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        renderEncoder.endEncoding()

        return output
    }

    // MARK: - Simplified Bloom (Single Pass, Radius 8)
    
    private func applyBloomSimplified(input: MTLTexture, config: BloomConfig, commandBuffer: MTLCommandBuffer) -> MTLTexture? {
        guard let pipeline = RenderEngine.shared.bloomPipeline,
              let output = getNextOutputTexture() else {
            #if DEBUG
            if RenderEngine.shared.bloomPipeline == nil {
                print("❌ FilterRenderer: bloomPipeline is nil!")
            }
            #endif
            return nil
        }

        renderPassDescriptor.colorAttachments[0].texture = output
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return nil }

        renderEncoder.setRenderPipelineState(pipeline)
        renderEncoder.setFragmentTexture(input, index: 0)

        // OPTIMIZED: Cap radius at 8 for preview
        var params = BloomParams()
        params.intensity = config.intensity
        params.threshold = config.threshold
        params.radius = min(config.radius, 8.0)  // MAX 8 for preview
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
        
        // Use DRAWABLE size for intermediate textures
        let outputWidth = drawable.texture.width
        let outputHeight = drawable.texture.height

        guard let temp1 = texturePool.renderTargetTexture(width: outputWidth, height: outputHeight, pixelFormat: .bgra8Unorm),
              let temp2 = texturePool.renderTargetTexture(width: outputWidth, height: outputHeight, pixelFormat: .bgra8Unorm) else {
            print("FilterRenderer: Failed to allocate intermediate textures")
            return
        }

        pingPongTextures[0] = temp1
        pingPongTextures[1] = temp2
        pingPongIndex = 0

        var currentInput: MTLTexture = input
        
        // Scale input to drawable size first
        if input.width != outputWidth || input.height != outputHeight {
            if let scaled = scaleTexture(input: input, commandBuffer: commandBuffer) {
                currentInput = scaled
            }
        }

        // Execute FULL filter pipeline (13 passes)
        currentInput = executeFullPipeline(input: currentInput, preset: preset, commandBuffer: commandBuffer)

        // FINAL PASS: Blit to drawable (sizes now match)
        blitToOutput(source: currentInput, destination: drawable.texture, commandBuffer: commandBuffer)

        commandBuffer.addCompletedHandler { [weak texturePool] _ in
            texturePool?.recycle(temp1)
            texturePool?.recycle(temp2)
        }

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    // MARK: - ★ NEW: Lightweight Gallery Preview (2 passes only)

    /// Ultra-fast preview for gallery scrolling - only Color Grading + Vignette
    /// Full pipeline (13 passes) is only used when saving
    func renderGalleryPreview(input: MTLTexture, output: MTLTexture, preset: FilterPreset, commandQueue: MTLCommandQueue) -> Bool {
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            print("❌ FilterRenderer: Failed to create command buffer")
            return false
        }

        let texturePool = RenderEngine.shared.texturePool

        guard let temp1 = texturePool.renderTargetTexture(width: input.width, height: input.height, pixelFormat: .bgra8Unorm),
              let temp2 = texturePool.renderTargetTexture(width: input.width, height: input.height, pixelFormat: .bgra8Unorm) else {
            print("❌ FilterRenderer: Failed to allocate preview textures")
            return false
        }

        pingPongTextures[0] = temp1
        pingPongTextures[1] = temp2
        pingPongIndex = 0

        var currentInput = input

        // ═══════════════════════════════════════════════════════════════
        // GALLERY PREVIEW: Only 2 passes for maximum speed
        // ═══════════════════════════════════════════════════════════════

        // PASS 1: Color Grading (includes LUT - the most important!)
        if let result = applyColorGrading(input: currentInput, preset: preset, commandBuffer: commandBuffer) {
            currentInput = result
        }

        // PASS 2: Vignette (lightweight, adds depth)
        if preset.vignette.enabled {
            if let result = applyVignette(input: currentInput, config: preset.vignette, commandBuffer: commandBuffer) {
                currentInput = result
            }
        }

        // Final blit to output
        blitToOutput(source: currentInput, destination: output, commandBuffer: commandBuffer)

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        if let error = commandBuffer.error {
            print("❌ FilterRenderer: Gallery preview GPU error - \(error.localizedDescription)")
            texturePool.recycle(temp1)
            texturePool.recycle(temp2)
            return false
        }

        texturePool.recycle(temp1)
        texturePool.recycle(temp2)

        return true
    }

    // MARK: - Synchronous Render (for photo capture) with Debug

    /// Render to texture SYNCHRONOUSLY with FULL quality pipeline
    func renderSync(input: MTLTexture, output: MTLTexture, preset: FilterPreset, commandQueue: MTLCommandQueue) -> Bool {
        print("🔄 FilterRenderer.renderSync: Starting for preset '\(preset.label)'")
        print("   Input: \(input.width)x\(input.height), Output: \(output.width)x\(output.height)")
        
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            print("❌ FilterRenderer: Failed to create command buffer")
            return false
        }

        let texturePool = RenderEngine.shared.texturePool

        guard let temp1 = texturePool.renderTargetTexture(width: input.width, height: input.height, pixelFormat: .bgra8Unorm),
              let temp2 = texturePool.renderTargetTexture(width: input.width, height: input.height, pixelFormat: .bgra8Unorm) else {
            print("❌ FilterRenderer: Failed to allocate intermediate textures")
            return false
        }

        pingPongTextures[0] = temp1
        pingPongTextures[1] = temp2
        pingPongIndex = 0

        var currentInput = input

        // Execute FULL pipeline for capture (all 13 passes)
        let startTime = CFAbsoluteTimeGetCurrent()
        currentInput = executeFullPipeline(input: currentInput, preset: preset, commandBuffer: commandBuffer)
        print("   Pipeline setup time: \(String(format: "%.3f", CFAbsoluteTimeGetCurrent() - startTime))s")

        // Final blit to output
        blitToOutput(source: currentInput, destination: output, commandBuffer: commandBuffer)

        // CRITICAL: Commit and WAIT for GPU to complete
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
        
        let totalTime = CFAbsoluteTimeGetCurrent() - startTime
        print("✅ FilterRenderer.renderSync: Completed in \(String(format: "%.3f", totalTime))s")
        
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

    // MARK: - Full Pipeline Execution (13 passes for capture) with Debug
    
    private func executeFullPipeline(input: MTLTexture, preset: FilterPreset, commandBuffer: MTLCommandBuffer) -> MTLTexture {
        var currentInput = input
        var passResults: [String] = []

        // PASS 1: Lens Distortion
        if preset.lensDistortion.enabled {
            if let result = applyLensDistortion(input: currentInput, params: preset.lensDistortion, commandBuffer: commandBuffer) {
                currentInput = result
                passResults.append("LensDistortion✓")
            } else {
                passResults.append("LensDistortion✗")
            }
        }

        // PASS 2: Color Grading
        if let result = applyColorGrading(input: currentInput, preset: preset, commandBuffer: commandBuffer) {
            currentInput = result
            passResults.append("ColorGrading✓")
        } else {
            passResults.append("ColorGrading✗")
        }

        // PASS 2.5: Black & White Conversion (AFTER color grading for proper channel mixing)
        if preset.bw.enabled {
            if let result = applyBWConvert(input: currentInput, config: preset.bw, commandBuffer: commandBuffer) {
                currentInput = result
                passResults.append("BWConvert✓")
            } else {
                passResults.append("BWConvert✗")
            }
        }

        // PASS 3: Flash (BEFORE Bloom/Halation so bright flash areas bloom)
        if preset.flash.enabled {
            if let result = applyFlash(input: currentInput, config: preset.flash, commandBuffer: commandBuffer) {
                currentInput = result
                passResults.append("Flash✓")
            } else {
                passResults.append("Flash✗")
            }
        }

        // PASS 4: CCD Bloom (Digicam vertical smear - alternative to standard bloom)
        if preset.ccdBloom.enabled {
            if let result = applyCCDBloom(input: currentInput, config: preset.ccdBloom, commandBuffer: commandBuffer) {
                currentInput = result
                passResults.append("CCDBloom✓")
            } else {
                passResults.append("CCDBloom✗")
            }
        }

        // PASS 5-8: Bloom (Separable - 4 passes) - FULL QUALITY
        if preset.bloom.enabled {
            if let result = applyBloomSeparable(input: currentInput, config: preset.bloom, commandBuffer: commandBuffer) {
                currentInput = result
                passResults.append("Bloom✓")
            } else {
                passResults.append("Bloom✗")
            }
        }

        // PASS 8: Vignette
        if preset.vignette.enabled {
            if let result = applyVignette(input: currentInput, config: preset.vignette, commandBuffer: commandBuffer) {
                currentInput = result
                passResults.append("Vignette✓")
            } else {
                passResults.append("Vignette✗")
            }
        }

        // PASS 9-12: Halation (Separable - 4 passes) - FULL QUALITY
        if preset.halation.enabled {
            if let result = applyHalationSeparable(input: currentInput, config: preset.halation, commandBuffer: commandBuffer) {
                currentInput = result
                passResults.append("Halation✓")
            } else {
                passResults.append("Halation✗")
            }
        }

        // PASS 13: Grain (AFTER lighting effects for natural appearance)
        if preset.grain.enabled {
            if let result = applyGrain(input: currentInput, config: preset.grain, commandBuffer: commandBuffer) {
                currentInput = result
                passResults.append("Grain✓")
            } else {
                passResults.append("Grain✗")
            }
        }

        // PASS 14: Light Leak (Procedural light leak effect)
        if preset.lightLeak.enabled {
            if let result = applyLightLeak(input: currentInput, config: preset.lightLeak, commandBuffer: commandBuffer) {
                currentInput = result
                passResults.append("LightLeak✓")
            } else {
                passResults.append("LightLeak✗")
            }
        }

        // PASS 15: Date Stamp (Procedural 7-segment display)
        if preset.dateStamp.enabled {
            if let result = applyDateStamp(input: currentInput, config: preset.dateStamp, commandBuffer: commandBuffer) {
                currentInput = result
                passResults.append("DateStamp✓")
            } else {
                passResults.append("DateStamp✗")
            }
        }

        // PASS 16: Overlays (Dust & Scratches - applied to image, not frame)
        if preset.overlays.enabled {
            if let result = applyOverlays(input: currentInput, config: preset.overlays, commandBuffer: commandBuffer) {
                currentInput = result
                passResults.append("Overlays✓")
            } else {
                passResults.append("Overlays✗")
            }
        }

        // PASS 17: VHS Effects (scanlines, color bleed, tracking)
        if preset.vhsEffects.enabled {
            if let result = applyVHSEffects(input: currentInput, config: preset.vhsEffects, commandBuffer: commandBuffer) {
                currentInput = result
                passResults.append("VHS✓")
            } else {
                passResults.append("VHS✗")
            }
        }

        // PASS 18: Digicam Effects (digital noise, JPEG artifacts, sharpening)
        if preset.digicamEffects.enabled {
            if let result = applyDigicamEffects(input: currentInput, config: preset.digicamEffects, commandBuffer: commandBuffer) {
                currentInput = result
                passResults.append("Digicam✓")
            } else {
                passResults.append("Digicam✗")
            }
        }

        // PASS 19: Film Strip Effects (borders, perforations)
        if preset.filmStripEffects.enabled {
            if let result = applyFilmStripEffects(input: currentInput, config: preset.filmStripEffects, commandBuffer: commandBuffer) {
                currentInput = result
                passResults.append("FilmStrip✓")
            } else {
                passResults.append("FilmStrip✗")
            }
        }

        // PASS 20: Instant Frame
        if preset.instantFrame.enabled {
            if let result = applyInstantFrame(input: currentInput, config: preset.instantFrame, commandBuffer: commandBuffer) {
                currentInput = result
                passResults.append("InstantFrame✓")
            } else {
                passResults.append("InstantFrame✗")
            }
        }

        #if DEBUG
        print("   Pipeline passes: \(passResults.joined(separator: " → "))")
        #endif

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
              let output = getNextOutputTexture() else {
            #if DEBUG
            if RenderEngine.shared.colorGradingPipeline == nil {
                print("❌ FilterRenderer: colorGradingPipeline is nil! Check shader compilation.")
            }
            #endif
            return nil
        }

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
              let output = getNextOutputTexture() else {
            #if DEBUG
            if RenderEngine.shared.instantFramePipeline == nil {
                print("❌ FilterRenderer: instantFramePipeline is nil!")
            }
            #endif
            return nil
        }

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

    // MARK: - Flash Effect (Disposable Camera)

    private func applyFlash(input: MTLTexture, config: FlashConfig, commandBuffer: MTLCommandBuffer) -> MTLTexture? {
        guard let pipeline = RenderEngine.shared.flashPipeline,
              let output = getNextOutputTexture() else {
            #if DEBUG
            if RenderEngine.shared.flashPipeline == nil {
                print("❌ FilterRenderer: flashPipeline is nil!")
            }
            #endif
            return nil
        }

        renderPassDescriptor.colorAttachments[0].texture = output
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return nil }

        renderEncoder.setRenderPipelineState(pipeline)
        renderEncoder.setFragmentTexture(input, index: 0)

        var params = prepareFlashParams(config)
        renderEncoder.setFragmentBytes(&params, length: MemoryLayout<FlashParams>.stride, index: 0)

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

    private func prepareFlashParams(_ config: FlashConfig) -> FlashParams {
        var params = FlashParams()
        params.enabled = config.enabled ? 1 : 0
        params.intensity = config.intensity
        params.falloff = config.falloff
        params.warmth = config.warmth
        params.shadowLift = config.shadowLift
        params.centerBoost = config.centerBoost
        params.position = SIMD2<Float>(config.position.x, config.position.y)
        params.radius = config.radius
        return params
    }

    // MARK: - Light Leak Effect (Procedural)

    private func applyLightLeak(input: MTLTexture, config: LightLeakConfig, commandBuffer: MTLCommandBuffer) -> MTLTexture? {
        guard let pipeline = RenderEngine.shared.lightLeakPipeline,
              let output = getNextOutputTexture() else {
            #if DEBUG
            if RenderEngine.shared.lightLeakPipeline == nil {
                print("❌ FilterRenderer: lightLeakPipeline is nil!")
            }
            #endif
            return nil
        }

        renderPassDescriptor.colorAttachments[0].texture = output
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return nil }

        renderEncoder.setRenderPipelineState(pipeline)
        renderEncoder.setFragmentTexture(input, index: 0)

        var params = prepareLightLeakParams(config)
        renderEncoder.setFragmentBytes(&params, length: MemoryLayout<LightLeakParams>.stride, index: 0)

        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        renderEncoder.endEncoding()

        return output
    }

    private func prepareLightLeakParams(_ config: LightLeakConfig) -> LightLeakParams {
        var params = LightLeakParams()
        params.enabled = config.enabled ? 1 : 0
        params.leakType = Int32(leakTypeToInt(config.type))
        params.opacity = config.opacity
        params.size = config.size
        params.softness = config.softness
        params.warmth = config.warmth
        params.saturation = config.saturation
        params.hueShift = config.hueShift
        params.blendMode = Int32(config.blendMode.rawValue)
        params.seed = config.seed
        return params
    }

    private func leakTypeToInt(_ type: LightLeakType) -> Int {
        switch type {
        case .cornerTopLeft: return 0
        case .cornerTopRight: return 1
        case .cornerBottomLeft: return 2
        case .cornerBottomRight: return 3
        case .edgeTop: return 4
        case .edgeBottom: return 5
        case .edgeLeft: return 6
        case .edgeRight: return 7
        case .streak: return 8
        case .random: return 9
        }
    }

    // MARK: - Date Stamp Effect (Procedural 7-Segment Display)

    private func applyDateStamp(input: MTLTexture, config: DateStampConfig, commandBuffer: MTLCommandBuffer) -> MTLTexture? {
        guard let pipeline = RenderEngine.shared.dateStampPipeline,
              let output = getNextOutputTexture() else {
            #if DEBUG
            if RenderEngine.shared.dateStampPipeline == nil {
                print("❌ FilterRenderer: dateStampPipeline is nil!")
            }
            #endif
            return nil
        }

        renderPassDescriptor.colorAttachments[0].texture = output
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return nil }

        renderEncoder.setRenderPipelineState(pipeline)
        renderEncoder.setFragmentTexture(input, index: 0)

        var params = prepareDateStampParams(config)
        renderEncoder.setFragmentBytes(&params, length: MemoryLayout<DateStampParams>.stride, index: 0)

        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        renderEncoder.endEncoding()

        return output
    }

    private func prepareDateStampParams(_ config: DateStampConfig) -> DateStampParams {
        var params = DateStampParams()
        params.enabled = config.enabled ? 1 : 0

        // Convert date string to digit array for 7-segment display
        // Format: "12 25 '24" → digits: [1,2,-1,2,5,-1,10,2,4]
        // -1 = space, 10 = quote, 11 = slash, 12 = dot
        let dateString = config.format.format(Date())
        var digits: [Int32] = []
        for char in dateString {
            switch char {
            case "0"..."9":
                digits.append(Int32(char.asciiValue! - 48)) // '0' = 48
            case " ":
                digits.append(-1) // space
            case "'":
                digits.append(10) // quote
            case "/":
                digits.append(11) // slash
            case ".":
                digits.append(12) // dot
            default:
                break
            }
        }

        // Fill digits array (max 10)
        let count = min(digits.count, 10)
        for i in 0..<count {
            setDigit(&params, index: i, value: digits[i])
        }
        params.digitCount = Int32(count)

        // Position
        params.position = Int32(positionToInt(config.position))

        // Color
        let rgb = config.color.rgb
        params.color = SIMD3<Float>(rgb.r, rgb.g, rgb.b)
        params.opacity = config.opacity
        params.scale = config.scale
        params.marginX = config.marginX
        params.marginY = config.marginY

        // Glow effect
        params.glowEnabled = config.glowEnabled ? 1 : 0
        params.glowIntensity = config.glowIntensity

        return params
    }

    private func setDigit(_ params: inout DateStampParams, index: Int, value: Int32) {
        switch index {
        case 0: params.digits.0 = value
        case 1: params.digits.1 = value
        case 2: params.digits.2 = value
        case 3: params.digits.3 = value
        case 4: params.digits.4 = value
        case 5: params.digits.5 = value
        case 6: params.digits.6 = value
        case 7: params.digits.7 = value
        case 8: params.digits.8 = value
        case 9: params.digits.9 = value
        default: break
        }
    }

    private func positionToInt(_ position: DateStampPosition) -> Int {
        switch position {
        case .bottomRight: return 0
        case .bottomLeft: return 1
        case .topRight: return 2
        case .topLeft: return 3
        }
    }

    // MARK: - CCD Bloom Effect (Digicam Vertical Smear)

    private func applyCCDBloom(input: MTLTexture, config: CCDBloomConfig, commandBuffer: MTLCommandBuffer) -> MTLTexture? {
        guard let pipeline = RenderEngine.shared.ccdBloomPipeline,
              let output = getNextOutputTexture() else {
            #if DEBUG
            if RenderEngine.shared.ccdBloomPipeline == nil {
                print("❌ FilterRenderer: ccdBloomPipeline is nil!")
            }
            #endif
            return nil
        }

        renderPassDescriptor.colorAttachments[0].texture = output
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return nil }

        renderEncoder.setRenderPipelineState(pipeline)
        renderEncoder.setFragmentTexture(input, index: 0)

        var params = prepareCCDBloomParams(config, textureWidth: input.width, textureHeight: input.height)
        renderEncoder.setFragmentBytes(&params, length: MemoryLayout<CCDBloomParams>.stride, index: 0)

        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        renderEncoder.endEncoding()

        return output
    }

    private func prepareCCDBloomParams(_ config: CCDBloomConfig, textureWidth: Int, textureHeight: Int) -> CCDBloomParams {
        var params = CCDBloomParams()
        params.enabled = config.enabled ? 1 : 0
        params.intensity = config.intensity
        params.threshold = config.threshold
        params.verticalSmear = config.verticalSmear
        params.smearLength = config.smearLength
        params.smearFalloff = config.smearFalloff
        params.horizontalBloom = config.horizontalBloom
        params.horizontalRadius = config.horizontalRadius
        params.purpleFringing = config.purpleFringing
        params.fringeWidth = config.fringeWidth
        params.warmShift = config.warmShift
        params.imageSize = SIMD2<Float>(Float(textureWidth), Float(textureHeight))
        return params
    }

    // MARK: - Black & White Pipeline

    private func applyBWConvert(input: MTLTexture, config: BWConfig, commandBuffer: MTLCommandBuffer) -> MTLTexture? {
        guard let pipeline = RenderEngine.shared.bwPipeline,
              let output = getNextOutputTexture() else {
            #if DEBUG
            if RenderEngine.shared.bwPipeline == nil {
                print("❌ FilterRenderer: bwPipeline is nil!")
            }
            #endif
            return nil
        }

        renderPassDescriptor.colorAttachments[0].texture = output
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return nil }

        renderEncoder.setRenderPipelineState(pipeline)
        renderEncoder.setFragmentTexture(input, index: 0)

        var params = prepareBWParams(config)
        renderEncoder.setFragmentBytes(&params, length: MemoryLayout<BWParams>.stride, index: 0)

        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        renderEncoder.endEncoding()

        return output
    }

    private func prepareBWParams(_ config: BWConfig) -> BWParams {
        var params = BWParams()
        params.enabled = config.enabled ? 1 : 0

        // Channel Mixing
        params.redWeight = config.redWeight
        params.greenWeight = config.greenWeight
        params.blueWeight = config.blueWeight

        // Contrast & Tone
        params.contrast = config.contrast
        params.brightness = config.brightness
        params.gamma = config.gamma

        // Toning
        switch config.toning {
        case .none:      params.toningMode = 0
        case .sepia:     params.toningMode = 1
        case .selenium:  params.toningMode = 2
        case .cyanotype: params.toningMode = 3
        case .splitTone: params.toningMode = 4
        case .custom:    params.toningMode = 5
        }
        params.toningIntensity = config.toningIntensity
        params.customColor = SIMD3<Float>(config.customColor.r, config.customColor.g, config.customColor.b)

        // Split Tone
        params.shadowHue = config.splitTone.shadowHue
        params.shadowSat = config.splitTone.shadowSat
        params.highlightHue = config.splitTone.highlightHue
        params.highlightSat = config.splitTone.highlightSat
        params.splitBalance = config.splitTone.balance

        // Grain
        params.grainIntensity = config.grainIntensity
        params.grainSize = config.grainSize
        params.grainSeed = UInt32.random(in: 0..<10000) // Random seed for each frame

        return params
    }

    // MARK: - Overlays (Dust & Scratches)

    private func applyOverlays(input: MTLTexture, config: OverlaysConfig, commandBuffer: MTLCommandBuffer) -> MTLTexture? {
        guard let pipeline = RenderEngine.shared.overlaysPipeline,
              let output = getNextOutputTexture() else {
            #if DEBUG
            if RenderEngine.shared.overlaysPipeline == nil {
                print("❌ FilterRenderer: overlaysPipeline is nil!")
            }
            #endif
            return nil
        }

        renderPassDescriptor.colorAttachments[0].texture = output
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return nil }

        renderEncoder.setRenderPipelineState(pipeline)
        renderEncoder.setFragmentTexture(input, index: 0)

        var params = prepareOverlaysParams(config, textureWidth: input.width, textureHeight: input.height)
        renderEncoder.setFragmentBytes(&params, length: MemoryLayout<OverlaysParams>.stride, index: 0)

        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        renderEncoder.endEncoding()

        return output
    }

    private func prepareOverlaysParams(_ config: OverlaysConfig, textureWidth: Int, textureHeight: Int) -> OverlaysParams {
        var params = OverlaysParams()
        params.enabled = config.enabled ? 1 : 0

        // Dust
        params.dustEnabled = config.dust.enabled ? 1 : 0
        params.dustDensity = config.dust.density
        params.dustSize = config.dust.size
        params.dustOpacity = config.dust.opacity
        params.dustVariation = config.dust.variation
        params.dustClumping = config.dust.clumping
        params.dustBlendMode = Int32(config.dust.blendMode.rawValue)

        // Scratches
        params.scratchEnabled = config.scratches.enabled ? 1 : 0
        params.scratchDensity = config.scratches.density
        params.scratchLength = config.scratches.length
        params.scratchWidth = config.scratches.width
        params.scratchOpacity = config.scratches.opacity
        params.scratchAngle = config.scratches.angle
        params.scratchVertical = config.scratches.vertical ? 1 : 0
        params.scratchBlendMode = Int32(config.scratches.blendMode.rawValue)

        // Global
        params.seed = config.animate ? UInt32.random(in: 0..<100000) : config.seed
        params.aspectRatio = Float(textureWidth) / Float(textureHeight)

        return params
    }

    // MARK: - ★★★ VHS Effects ★★★

    private func applyVHSEffects(input: MTLTexture, config: VHSEffectsConfig, commandBuffer: MTLCommandBuffer) -> MTLTexture? {
        guard let pipeline = RenderEngine.shared.vhsEffectsPipeline,
              let output = getNextOutputTexture() else {
            #if DEBUG
            if RenderEngine.shared.vhsEffectsPipeline == nil {
                print("❌ FilterRenderer: vhsEffectsPipeline is nil!")
            }
            #endif
            return nil
        }

        renderPassDescriptor.colorAttachments[0].texture = output
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return nil }

        renderEncoder.setRenderPipelineState(pipeline)
        renderEncoder.setFragmentTexture(input, index: 0)

        var params = prepareVHSEffectsParams(config)
        renderEncoder.setFragmentBytes(&params, length: MemoryLayout<VHSEffectsParams>.stride, index: 0)

        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        renderEncoder.endEncoding()

        return output
    }

    private func prepareVHSEffectsParams(_ config: VHSEffectsConfig) -> VHSEffectsParams {
        var params = VHSEffectsParams()
        params.enabled = config.enabled ? 1 : 0

        // Scanlines
        params.scanlinesEnabled = config.scanlines.enabled ? 1 : 0
        params.scanlinesIntensity = config.scanlines.intensity
        params.scanlinesDensity = config.scanlines.density
        params.scanlinesFlickerSpeed = config.scanlines.flickerSpeed
        params.scanlinesFlickerIntensity = config.scanlines.flickerIntensity

        // Color Bleed
        params.colorBleedEnabled = config.colorBleed.enabled ? 1 : 0
        params.colorBleedIntensity = config.colorBleed.intensity
        params.colorBleedRedShift = config.colorBleed.redShift
        params.colorBleedBlueShift = config.colorBleed.blueShift
        params.colorBleedVertical = config.colorBleed.verticalBleed

        // Tracking
        params.trackingEnabled = config.tracking.enabled ? 1 : 0
        params.trackingIntensity = config.tracking.intensity
        params.trackingSpeed = config.tracking.speed
        params.trackingNoise = config.tracking.noise
        params.trackingWaveHeight = config.tracking.waveHeight

        // Global effects
        params.noiseIntensity = config.noiseIntensity
        params.saturationLoss = config.saturationLoss
        params.sharpnessLoss = config.sharpnessLoss

        // Animation time (current time for flicker/tracking animation)
        params.time = Float(CFAbsoluteTimeGetCurrent().truncatingRemainder(dividingBy: 100.0))

        return params
    }

    // MARK: - ★★★ Digicam Effects ★★★

    private func applyDigicamEffects(input: MTLTexture, config: DigicamEffectsConfig, commandBuffer: MTLCommandBuffer) -> MTLTexture? {
        guard let pipeline = RenderEngine.shared.digicamEffectsPipeline,
              let output = getNextOutputTexture() else {
            #if DEBUG
            if RenderEngine.shared.digicamEffectsPipeline == nil {
                print("❌ FilterRenderer: digicamEffectsPipeline is nil!")
            }
            #endif
            return nil
        }

        renderPassDescriptor.colorAttachments[0].texture = output
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return nil }

        renderEncoder.setRenderPipelineState(pipeline)
        renderEncoder.setFragmentTexture(input, index: 0)

        var params = prepareDigicamEffectsParams(config)
        renderEncoder.setFragmentBytes(&params, length: MemoryLayout<DigicamEffectsParams>.stride, index: 0)

        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        renderEncoder.endEncoding()

        return output
    }

    private func prepareDigicamEffectsParams(_ config: DigicamEffectsConfig) -> DigicamEffectsParams {
        var params = DigicamEffectsParams()
        params.enabled = config.enabled ? 1 : 0

        // Digital noise
        params.digitalNoiseEnabled = config.digitalNoise.enabled ? 1 : 0
        params.digitalNoiseIntensity = config.digitalNoise.intensity
        params.luminanceNoise = config.digitalNoise.luminanceNoise
        params.chrominanceNoise = config.digitalNoise.chrominanceNoise
        params.banding = config.digitalNoise.banding
        params.hotPixels = config.digitalNoise.hotPixels

        // JPEG artifacts
        params.jpegArtifacts = config.jpegArtifacts

        // Camera processing
        params.whiteBalance = config.whiteBalance
        params.autoExposure = config.autoExposure
        params.sharpening = config.sharpening

        // Random seed
        params.seed = UInt32.random(in: 0..<10000)

        return params
    }

    // MARK: - ★★★ Film Strip Effects ★★★

    private func applyFilmStripEffects(input: MTLTexture, config: FilmStripEffectsConfig, commandBuffer: MTLCommandBuffer) -> MTLTexture? {
        guard let pipeline = RenderEngine.shared.filmStripPipeline,
              let output = getNextOutputTexture() else {
            #if DEBUG
            if RenderEngine.shared.filmStripPipeline == nil {
                print("❌ FilterRenderer: filmStripPipeline is nil!")
            }
            #endif
            return nil
        }

        renderPassDescriptor.colorAttachments[0].texture = output
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return nil }

        renderEncoder.setRenderPipelineState(pipeline)
        renderEncoder.setFragmentTexture(input, index: 0)

        var params = prepareFilmStripParams(config)
        renderEncoder.setFragmentBytes(&params, length: MemoryLayout<FilmStripParams>.stride, index: 0)

        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        renderEncoder.endEncoding()

        return output
    }

    private func prepareFilmStripParams(_ config: FilmStripEffectsConfig) -> FilmStripParams {
        var params = FilmStripParams()
        params.enabled = config.enabled ? 1 : 0

        // Perforations
        switch config.perforations {
        case .none: params.perforationStyle = 0
        case .standard35mm: params.perforationStyle = 1
        case .cinema: params.perforationStyle = 2
        case .super8: params.perforationStyle = 3
        }

        // Border
        params.borderColor = SIMD3<Float>(config.borderColor.r, config.borderColor.g, config.borderColor.b)
        params.borderOpacity = config.borderOpacity

        // Frame lines
        params.frameLineWidth = config.frameLineWidth
        params.frameLineOpacity = config.frameLineOpacity

        // Rebate
        params.rebateVisible = config.rebateVisible ? 1 : 0
        params.frameNumber = config.frameNumber ? 1 : 0
        params.kodakStyle = config.kodakStyle ? 1 : 0

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
