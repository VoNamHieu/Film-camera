// Models.swift
// Film Camera - Professional Model (Merged with WebGL Engine)

import Foundation
import SwiftUI

// MARK: - Filter Category

enum FilterCategory: String, CaseIterable, Codable {
    case professional, slide, consumer, cinema, blackAndWhite, instant, disposable, food, night, creative
}

// MARK: - Core Adjustments

struct ColorAdjustments: Codable {
    var exposure: Float
    var contrast: Float
    var highlights: Float
    var shadows: Float
    var whites: Float
    var blacks: Float
    var saturation: Float
    var vibrance: Float
    var temperature: Float
    var tint: Float
    var fade: Float
    var clarity: Float

    init(exposure: Float = 0, contrast: Float = 0, highlights: Float = 0, shadows: Float = 0,
         whites: Float = 0, blacks: Float = 0, saturation: Float = 0, vibrance: Float = 0,
         temperature: Float = 0, tint: Float = 0, fade: Float = 0, clarity: Float = 0) {
        self.exposure = exposure; self.contrast = contrast; self.highlights = highlights
        self.shadows = shadows; self.whites = whites; self.blacks = blacks
        self.saturation = saturation; self.vibrance = vibrance; self.temperature = temperature
        self.tint = tint; self.fade = fade; self.clarity = clarity
    }
}

// MARK: - Selective Color (Cập nhật theo WebGL Engine)
// Quan trọng: Logic này thay thế logic cũ để hỗ trợ chỉnh Hue Shift và Luminance từng kênh
struct SelectiveColorAdjustment: Codable, Hashable {
    var hue: Float        // Màu mục tiêu (Normalized 0.0 - 1.0 hoặc Degree tùy quy ước, nên dùng 0-1 cho Metal)
    var range: Float      // Phạm vi ảnh hưởng
    var sat: Float        // Tăng giảm Saturation
    var lum: Float        // Tăng giảm Luminance
    var hueShift: Float   // Dịch chuyển Hue

    init(hue: Float, range: Float = 0.4, sat: Float = 0, lum: Float = 0, hueShift: Float = 0) {
        self.hue = hue
        self.range = range
        self.sat = sat
        self.lum = lum
        self.hueShift = hueShift
    }
}

// MARK: - Lens Distortion (Mới từ WebGL - Disposable Camera)
struct LensDistortionConfig: Codable {
    var enabled: Bool
    var k1: Float         // Barrel distortion (Méo lồi/lõm)
    var k2: Float         // Edge distortion (Méo rìa)
    var caStrength: Float // Chromatic Aberration (Lệch màu RGB)
    var scale: Float      // Zoom crop để cắt phần đen

    init(enabled: Bool = false, k1: Float = 0, k2: Float = 0, caStrength: Float = 0, scale: Float = 1.0) {
        self.enabled = enabled
        self.k1 = k1; self.k2 = k2; self.caStrength = caStrength; self.scale = scale
    }
}

// MARK: - Split Tone
struct SplitToneConfig: Codable {
    var shadowsHue: Float, shadowsSat: Float, highlightsHue: Float, highlightsSat: Float
    var balance: Float, midtoneProtection: Float

    init(shadowsHue: Float = 0, shadowsSat: Float = 0, highlightsHue: Float = 0,
         highlightsSat: Float = 0, balance: Float = 0.5, midtoneProtection: Float = 0.3) {
        self.shadowsHue = shadowsHue; self.shadowsSat = shadowsSat
        self.highlightsHue = highlightsHue; self.highlightsSat = highlightsSat
        self.balance = balance; self.midtoneProtection = midtoneProtection
    }
}

// MARK: - RGB Curves (Giữ nguyên - Rất mạnh cho Film Simulation)
struct RGBCurvePoint: Codable {
    var input: Float, output: Float
    init(input: Float, output: Float) { self.input = input; self.output = output }
}

struct RGBCurves: Codable {
    var red: [RGBCurvePoint], green: [RGBCurvePoint], blue: [RGBCurvePoint]
    init(red: [RGBCurvePoint] = [], green: [RGBCurvePoint] = [], blue: [RGBCurvePoint] = []) {
        self.red = red; self.green = green; self.blue = blue
    }
}

// MARK: - Grain (Complex System - Giữ nguyên)
// RenderEngine sẽ chịu trách nhiệm "làm phẳng" (flatten) struct này khi gửi xuống Shader đơn giản
struct GrainChannel: Codable {
    var intensity: Float, size: Float, seed: Int, softness: Float
    init(intensity: Float = 0.1, size: Float = 1.0, seed: Int = 1000, softness: Float = 0.5) {
        self.intensity = intensity; self.size = size; self.seed = seed; self.softness = softness
    }
}

struct GrainChannels: Codable {
    var red: GrainChannel, green: GrainChannel, blue: GrainChannel
    init(red: GrainChannel = GrainChannel(), green: GrainChannel = GrainChannel(), blue: GrainChannel = GrainChannel()) {
        self.red = red; self.green = green; self.blue = blue
    }
}

struct GrainTexture: Codable {
    var type: String, octaves: Int, persistence: Float, lacunarity: Float, baseFrequency: Float
    init(type: String = "perlin", octaves: Int = 2, persistence: Float = 0.5, lacunarity: Float = 1.8, baseFrequency: Float = 1.0) {
        self.type = type; self.octaves = octaves; self.persistence = persistence
        self.lacunarity = lacunarity; self.baseFrequency = baseFrequency
    }
}

struct GrainDensityPoint: Codable {
    var luma: Float, multiplier: Float
    init(luma: Float, multiplier: Float) { self.luma = luma; self.multiplier = multiplier }
}

struct ChromaticShift: Codable {
    var x: Float, y: Float
    init(x: Float = 0, y: Float = 0) { self.x = x; self.y = y }
}

struct GrainChromatic: Codable {
    var enabled: Bool, redShift: ChromaticShift, greenShift: ChromaticShift, blueShift: ChromaticShift
    init(enabled: Bool = false, redShift: ChromaticShift = ChromaticShift(),
         greenShift: ChromaticShift = ChromaticShift(), blueShift: ChromaticShift = ChromaticShift()) {
        self.enabled = enabled; self.redShift = redShift; self.greenShift = greenShift; self.blueShift = blueShift
    }
}

struct GrainClumping: Codable {
    var enabled: Bool, strength: Float, threshold: Float, clusterSize: Float
    init(enabled: Bool = false, strength: Float = 0.2, threshold: Float = 0.25, clusterSize: Float = 1.2) {
        self.enabled = enabled; self.strength = strength; self.threshold = threshold; self.clusterSize = clusterSize
    }
}

struct GrainTemporal: Codable {
    var enabled: Bool, refreshRate: Int, seedIncrement: Int, coherence: Float
    init(enabled: Bool = true, refreshRate: Int = 1, seedIncrement: Int = 7919, coherence: Float = 0.25) {
        self.enabled = enabled; self.refreshRate = refreshRate; self.seedIncrement = seedIncrement; self.coherence = coherence
    }
}

struct GrainColorJitter: Codable {
    var enabled: Bool, strength: Float, perPixel: Bool, blueStrength: Float, seed: Int
    init(enabled: Bool = false, strength: Float = 0.002, perPixel: Bool = true, blueStrength: Float = 1.1, seed: Int = 100) {
        self.enabled = enabled; self.strength = strength; self.perPixel = perPixel; self.blueStrength = blueStrength; self.seed = seed
    }
}

struct GrainConfig: Codable {
    var enabled: Bool, globalIntensity: Float, channels: GrainChannels, texture: GrainTexture
    var densityCurve: [GrainDensityPoint], chromatic: GrainChromatic, clumping: GrainClumping
    var temporal: GrainTemporal, colorJitter: GrainColorJitter

    init(enabled: Bool = true, globalIntensity: Float = 0.15, channels: GrainChannels = GrainChannels(),
         texture: GrainTexture = GrainTexture(), densityCurve: [GrainDensityPoint] = [],
         chromatic: GrainChromatic = GrainChromatic(), clumping: GrainClumping = GrainClumping(),
         temporal: GrainTemporal = GrainTemporal(), colorJitter: GrainColorJitter = GrainColorJitter()) {
        self.enabled = enabled; self.globalIntensity = globalIntensity; self.channels = channels
        self.texture = texture; self.densityCurve = densityCurve; self.chromatic = chromatic
        self.clumping = clumping; self.temporal = temporal; self.colorJitter = colorJitter
    }
}

// MARK: - Bloom (Giữ nguyên)
struct ColorTint: Codable {
    var r: Float, g: Float, b: Float
    init(r: Float = 1.0, g: Float = 1.0, b: Float = 1.0) { self.r = r; self.g = g; self.b = b }
}

struct BloomConfig: Codable {
    var enabled: Bool, intensity: Float, threshold: Float, radius: Float, softness: Float, colorTint: ColorTint
    init(enabled: Bool = true, intensity: Float = 0.05, threshold: Float = 0.75, radius: Float = 12,
         softness: Float = 0.75, colorTint: ColorTint = ColorTint()) {
        self.enabled = enabled; self.intensity = intensity; self.threshold = threshold
        self.radius = radius; self.softness = softness; self.colorTint = colorTint
    }
}

// MARK: - Vignette (Giữ nguyên)
struct VignetteConfig: Codable {
    var enabled: Bool, intensity: Float, roundness: Float, feather: Float, midpoint: Float
    init(enabled: Bool = true, intensity: Float = 0.15, roundness: Float = 0.8, feather: Float = 0.6, midpoint: Float = 0.5) {
        self.enabled = enabled; self.intensity = intensity; self.roundness = roundness
        self.feather = feather; self.midpoint = midpoint
    }
}

// MARK: - Halation (Complex System - Giữ nguyên)
struct HalationColor: Codable {
    var r: Float, g: Float, b: Float
    init(r: Float = 1.0, g: Float = 0.3, b: Float = 0.15) { self.r = r; self.g = g; self.b = b }
}

struct HalationGradient: Codable {
    var enabled: Bool, inner: HalationColor, outer: HalationColor
    init(enabled: Bool = false, inner: HalationColor = HalationColor(r: 1.0, g: 0.4, b: 0.2),
         outer: HalationColor = HalationColor(r: 1.0, g: 0.2, b: 0.1)) {
        self.enabled = enabled; self.inner = inner; self.outer = outer
    }
}

struct HalationConfig: Codable {
    var enabled: Bool, color: HalationColor, intensity: Float, threshold: Float
    var radius: Float, softness: Float, colorGradient: HalationGradient

    init(enabled: Bool = false, color: HalationColor = HalationColor(), intensity: Float = 0.4,
         threshold: Float = 0.65, radius: Float = 28, softness: Float = 0.85,
         colorGradient: HalationGradient = HalationGradient()) {
        self.enabled = enabled; self.color = color; self.intensity = intensity
        self.threshold = threshold; self.radius = radius; self.softness = softness; self.colorGradient = colorGradient
    }
}

// MARK: - Instant Film (Complex System - Giữ nguyên)
struct ChemicalFade: Codable {
    var enabled: Bool, edgeFade: Float, cornerDarkening: Float, unevenDevelopment: Float
    init(enabled: Bool = true, edgeFade: Float = 0.12, cornerDarkening: Float = 0.08, unevenDevelopment: Float = 0.05) {
        self.enabled = enabled; self.edgeFade = edgeFade; self.cornerDarkening = cornerDarkening; self.unevenDevelopment = unevenDevelopment
    }
}

struct BorderWidth: Codable {
    var top: Float, left: Float, right: Float, bottom: Float
    init(top: Float = 0.06, left: Float = 0.05, right: Float = 0.05, bottom: Float = 0.18) {
        self.top = top; self.left = left; self.right = right; self.bottom = bottom
    }
}

struct BorderColor: Codable {
    var r: Float, g: Float, b: Float
    init(r: Float = 0.98, g: Float = 0.97, b: Float = 0.96) { self.r = r; self.g = g; self.b = b }
}

struct FrameShadow: Codable {
    var enabled: Bool, blur: Float, opacity: Float, offsetY: Float
    init(enabled: Bool = true, blur: Float = 15, opacity: Float = 0.25, offsetY: Float = 8) {
        self.enabled = enabled; self.blur = blur; self.opacity = opacity; self.offsetY = offsetY
    }
}

struct InstantFrameConfig: Codable {
    var enabled: Bool, type: String, borderColor: BorderColor, borderWidth: BorderWidth, texture: String, shadow: FrameShadow
    init(enabled: Bool = true, type: String = "polaroid_600", borderColor: BorderColor = BorderColor(),
         borderWidth: BorderWidth = BorderWidth(), texture: String = "matte", shadow: FrameShadow = FrameShadow()) {
        self.enabled = enabled; self.type = type; self.borderColor = borderColor
        self.borderWidth = borderWidth; self.texture = texture; self.shadow = shadow
    }
}

// MARK: - Skin Tone & Tone Mapping (Giữ nguyên)
struct SkinToneProtection: Codable {
    var enabled: Bool, hueCenter: Float, hueRange: Float, satProtection: Float, warmthBoost: Float
    init(enabled: Bool = false, hueCenter: Float = 25, hueRange: Float = 30, satProtection: Float = 0.4, warmthBoost: Float = 0.03) {
        self.enabled = enabled; self.hueCenter = hueCenter; self.hueRange = hueRange
        self.satProtection = satProtection; self.warmthBoost = warmthBoost
    }
}

struct ToneMapping: Codable {
    var enabled: Bool, method: String, whitePoint: Float, shoulderStrength: Float, linearStrength: Float, toeStrength: Float
    init(enabled: Bool = false, method: String = "filmic", whitePoint: Float = 1.0,
         shoulderStrength: Float = 0.2, linearStrength: Float = 0.3, toeStrength: Float = 0.2) {
        self.enabled = enabled; self.method = method; self.whitePoint = whitePoint
        self.shoulderStrength = shoulderStrength; self.linearStrength = linearStrength; self.toeStrength = toeStrength
    }
}

struct FilmStock: Codable {
    var manufacturer: String, name: String, type: String, speed: Int, year: Int, characteristics: [String]
    init(manufacturer: String = "", name: String = "", type: String = "", speed: Int = 400, year: Int = 2000, characteristics: [String] = []) {
        self.manufacturer = manufacturer; self.name = name; self.type = type
        self.speed = speed; self.year = year; self.characteristics = characteristics
    }
}

// MARK: - FILTER PRESET (Root Object)

struct FilterPreset: Codable, Identifiable {
    let id: String, label: String, category: FilterCategory

    // Core Params
    var lutId: String?, lutFile: String?, lutIntensity: Float, colorSpace: String
    var colorAdjustments: ColorAdjustments
    var splitTone: SplitToneConfig
    var selectiveColor: [SelectiveColorAdjustment] // Updated WebGL Logic
    var lensDistortion: LensDistortionConfig       // Added WebGL Logic
    var rgbCurves: RGBCurves

    // Effects
    var grain: GrainConfig // Complex
    var bloom: BloomConfig
    var vignette: VignetteConfig
    var halation: HalationConfig // Complex
    var instantFrame: InstantFrameConfig // Complex

    // Advanced
    var skinToneProtection: SkinToneProtection
    var toneMapping: ToneMapping
    var filmStock: FilmStock

    init(id: String, label: String, category: FilterCategory,
         lutId: String? = nil, lutFile: String? = nil, lutIntensity: Float = 1.0, colorSpace: String = "srgb",
         colorAdjustments: ColorAdjustments = ColorAdjustments(), splitTone: SplitToneConfig = SplitToneConfig(),
         selectiveColor: [SelectiveColorAdjustment] = [], lensDistortion: LensDistortionConfig = LensDistortionConfig(),
         rgbCurves: RGBCurves = RGBCurves(),
         grain: GrainConfig = GrainConfig(), bloom: BloomConfig = BloomConfig(),
         vignette: VignetteConfig = VignetteConfig(), halation: HalationConfig = HalationConfig(),
         instantFrame: InstantFrameConfig = InstantFrameConfig(),
         skinToneProtection: SkinToneProtection = SkinToneProtection(),
         toneMapping: ToneMapping = ToneMapping(), filmStock: FilmStock = FilmStock()) {

        self.id = id; self.label = label; self.category = category
        self.lutId = lutId; self.lutFile = lutFile; self.lutIntensity = lutIntensity; self.colorSpace = colorSpace
        self.colorAdjustments = colorAdjustments; self.splitTone = splitTone
        self.selectiveColor = selectiveColor; self.lensDistortion = lensDistortion
        self.rgbCurves = rgbCurves
        self.grain = grain; self.bloom = bloom; self.vignette = vignette; self.halation = halation
        self.instantFrame = instantFrame
        self.skinToneProtection = skinToneProtection
        self.toneMapping = toneMapping; self.filmStock = filmStock
    }
}
