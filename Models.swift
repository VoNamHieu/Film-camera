// Models.swift
// Film Camera - Professional Model (Merged with WebGL Engine)
// ★ FIX: All structs now conform to Equatable for SwiftUI onChange support

import Foundation
import SwiftUI

// MARK: - Filter Category

enum FilterCategory: String, CaseIterable, Codable, Equatable {
    case professional, slide, consumer, cinema, blackAndWhite, instant, disposable, food, night, creative
}

// MARK: - Core Adjustments

struct ColorAdjustments: Codable, Equatable {
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

// MARK: - Selective Color
struct SelectiveColorAdjustment: Codable, Hashable, Equatable {
    var hue: Float
    var range: Float
    var sat: Float
    var lum: Float
    var hueShift: Float

    init(hue: Float, range: Float = 0.4, sat: Float = 0, lum: Float = 0, hueShift: Float = 0) {
        self.hue = hue
        self.range = range
        self.sat = sat
        self.lum = lum
        self.hueShift = hueShift
    }
}

// MARK: - Lens Distortion
struct LensDistortionConfig: Codable, Equatable {
    var enabled: Bool
    var k1: Float
    var k2: Float
    var caStrength: Float
    var scale: Float

    init(enabled: Bool = false, k1: Float = 0, k2: Float = 0, caStrength: Float = 0, scale: Float = 1.0) {
        self.enabled = enabled
        self.k1 = k1; self.k2 = k2; self.caStrength = caStrength; self.scale = scale
    }
}

// MARK: - Split Tone
struct SplitToneConfig: Codable, Equatable {
    var shadowsHue: Float, shadowsSat: Float, highlightsHue: Float, highlightsSat: Float
    var balance: Float, midtoneProtection: Float

    init(shadowsHue: Float = 0, shadowsSat: Float = 0, highlightsHue: Float = 0,
         highlightsSat: Float = 0, balance: Float = 0.5, midtoneProtection: Float = 0.3) {
        self.shadowsHue = shadowsHue; self.shadowsSat = shadowsSat
        self.highlightsHue = highlightsHue; self.highlightsSat = highlightsSat
        self.balance = balance; self.midtoneProtection = midtoneProtection
    }
}

// MARK: - RGB Curves
struct RGBCurvePoint: Codable, Equatable {
    var input: Float, output: Float
    init(input: Float, output: Float) { self.input = input; self.output = output }
}

struct RGBCurves: Codable, Equatable {
    var red: [RGBCurvePoint], green: [RGBCurvePoint], blue: [RGBCurvePoint]
    init(red: [RGBCurvePoint] = [], green: [RGBCurvePoint] = [], blue: [RGBCurvePoint] = []) {
        self.red = red; self.green = green; self.blue = blue
    }
}

// MARK: - Grain
struct GrainChannel: Codable, Equatable {
    var intensity: Float, size: Float, seed: Int, softness: Float
    init(intensity: Float = 0.1, size: Float = 1.0, seed: Int = 1000, softness: Float = 0.5) {
        self.intensity = intensity; self.size = size; self.seed = seed; self.softness = softness
    }
}

struct GrainChannels: Codable, Equatable {
    var red: GrainChannel, green: GrainChannel, blue: GrainChannel
    init(red: GrainChannel = GrainChannel(), green: GrainChannel = GrainChannel(), blue: GrainChannel = GrainChannel()) {
        self.red = red; self.green = green; self.blue = blue
    }
}

struct GrainTexture: Codable, Equatable {
    var type: String, octaves: Int, persistence: Float, lacunarity: Float, baseFrequency: Float
    init(type: String = "perlin", octaves: Int = 2, persistence: Float = 0.5, lacunarity: Float = 1.8, baseFrequency: Float = 1.0) {
        self.type = type; self.octaves = octaves; self.persistence = persistence
        self.lacunarity = lacunarity; self.baseFrequency = baseFrequency
    }
}

struct GrainDensityPoint: Codable, Equatable {
    var luma: Float, multiplier: Float
    init(luma: Float, multiplier: Float) { self.luma = luma; self.multiplier = multiplier }
}

struct ChromaticShift: Codable, Equatable {
    var x: Float, y: Float
    init(x: Float = 0, y: Float = 0) { self.x = x; self.y = y }
}

struct GrainChromatic: Codable, Equatable {
    var enabled: Bool, redShift: ChromaticShift, greenShift: ChromaticShift, blueShift: ChromaticShift
    init(enabled: Bool = false, redShift: ChromaticShift = ChromaticShift(),
         greenShift: ChromaticShift = ChromaticShift(), blueShift: ChromaticShift = ChromaticShift()) {
        self.enabled = enabled; self.redShift = redShift; self.greenShift = greenShift; self.blueShift = blueShift
    }
}

struct GrainClumping: Codable, Equatable {
    var enabled: Bool, strength: Float, threshold: Float, clusterSize: Float
    init(enabled: Bool = false, strength: Float = 0.2, threshold: Float = 0.25, clusterSize: Float = 1.2) {
        self.enabled = enabled; self.strength = strength; self.threshold = threshold; self.clusterSize = clusterSize
    }
}

struct GrainTemporal: Codable, Equatable {
    var enabled: Bool, refreshRate: Int, seedIncrement: Int, coherence: Float
    init(enabled: Bool = true, refreshRate: Int = 1, seedIncrement: Int = 7919, coherence: Float = 0.25) {
        self.enabled = enabled; self.refreshRate = refreshRate; self.seedIncrement = seedIncrement; self.coherence = coherence
    }
}

struct GrainColorJitter: Codable, Equatable {
    var enabled: Bool, strength: Float, perPixel: Bool, blueStrength: Float, seed: Int
    init(enabled: Bool = false, strength: Float = 0.002, perPixel: Bool = true, blueStrength: Float = 1.1, seed: Int = 100) {
        self.enabled = enabled; self.strength = strength; self.perPixel = perPixel; self.blueStrength = blueStrength; self.seed = seed
    }
}

struct GrainConfig: Codable, Equatable {
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

// MARK: - Bloom
struct ColorTint: Codable, Equatable {
    var r: Float, g: Float, b: Float
    init(r: Float = 1.0, g: Float = 1.0, b: Float = 1.0) { self.r = r; self.g = g; self.b = b }
}

struct BloomConfig: Codable, Equatable {
    var enabled: Bool, intensity: Float, threshold: Float, radius: Float, softness: Float, colorTint: ColorTint
    init(enabled: Bool = true, intensity: Float = 0.05, threshold: Float = 0.75, radius: Float = 12,
         softness: Float = 0.75, colorTint: ColorTint = ColorTint()) {
        self.enabled = enabled; self.intensity = intensity; self.threshold = threshold
        self.radius = radius; self.softness = softness; self.colorTint = colorTint
    }
}

// MARK: - Vignette
struct VignetteConfig: Codable, Equatable {
    var enabled: Bool, intensity: Float, roundness: Float, feather: Float, midpoint: Float
    init(enabled: Bool = true, intensity: Float = 0.15, roundness: Float = 0.8, feather: Float = 0.6, midpoint: Float = 0.5) {
        self.enabled = enabled; self.intensity = intensity; self.roundness = roundness
        self.feather = feather; self.midpoint = midpoint
    }
}

// MARK: - Halation
struct HalationColor: Codable, Equatable {
    var r: Float, g: Float, b: Float
    init(r: Float = 1.0, g: Float = 0.3, b: Float = 0.15) { self.r = r; self.g = g; self.b = b }
}

struct HalationGradient: Codable, Equatable {
    var enabled: Bool, inner: HalationColor, outer: HalationColor
    init(enabled: Bool = false, inner: HalationColor = HalationColor(r: 1.0, g: 0.4, b: 0.2),
         outer: HalationColor = HalationColor(r: 1.0, g: 0.2, b: 0.1)) {
        self.enabled = enabled; self.inner = inner; self.outer = outer
    }
}

struct HalationConfig: Codable, Equatable {
    var enabled: Bool, color: HalationColor, intensity: Float, threshold: Float
    var radius: Float, softness: Float, colorGradient: HalationGradient

    init(enabled: Bool = false, color: HalationColor = HalationColor(), intensity: Float = 0.4,
         threshold: Float = 0.65, radius: Float = 28, softness: Float = 0.85,
         colorGradient: HalationGradient = HalationGradient()) {
        self.enabled = enabled; self.color = color; self.intensity = intensity
        self.threshold = threshold; self.radius = radius; self.softness = softness; self.colorGradient = colorGradient
    }
}

// MARK: - Instant Film
struct ChemicalFade: Codable, Equatable {
    var enabled: Bool, edgeFade: Float, cornerDarkening: Float, unevenDevelopment: Float
    init(enabled: Bool = true, edgeFade: Float = 0.12, cornerDarkening: Float = 0.08, unevenDevelopment: Float = 0.05) {
        self.enabled = enabled; self.edgeFade = edgeFade; self.cornerDarkening = cornerDarkening; self.unevenDevelopment = unevenDevelopment
    }
}

struct BorderWidth: Codable, Equatable {
    var top: Float, left: Float, right: Float, bottom: Float
    init(top: Float = 0.06, left: Float = 0.05, right: Float = 0.05, bottom: Float = 0.18) {
        self.top = top; self.left = left; self.right = right; self.bottom = bottom
    }
}

struct BorderColor: Codable, Equatable {
    var r: Float, g: Float, b: Float
    init(r: Float = 0.98, g: Float = 0.97, b: Float = 0.96) { self.r = r; self.g = g; self.b = b }
}

struct FrameShadow: Codable, Equatable {
    var enabled: Bool, blur: Float, opacity: Float, offsetY: Float
    init(enabled: Bool = true, blur: Float = 15, opacity: Float = 0.25, offsetY: Float = 8) {
        self.enabled = enabled; self.blur = blur; self.opacity = opacity; self.offsetY = offsetY
    }
}

struct InstantFrameConfig: Codable, Equatable {
    var enabled: Bool, type: String, borderColor: BorderColor, borderWidth: BorderWidth, texture: String, shadow: FrameShadow
    init(enabled: Bool = false, type: String = "polaroid_600", borderColor: BorderColor = BorderColor(),
         borderWidth: BorderWidth = BorderWidth(), texture: String = "matte", shadow: FrameShadow = FrameShadow()) {
        self.enabled = enabled; self.type = type; self.borderColor = borderColor
        self.borderWidth = borderWidth; self.texture = texture; self.shadow = shadow
    }
}

// MARK: - Skin Tone & Tone Mapping
struct SkinToneProtection: Codable, Equatable {
    var enabled: Bool, hueCenter: Float, hueRange: Float, satProtection: Float, warmthBoost: Float
    init(enabled: Bool = false, hueCenter: Float = 25, hueRange: Float = 30, satProtection: Float = 0.4, warmthBoost: Float = 0.03) {
        self.enabled = enabled; self.hueCenter = hueCenter; self.hueRange = hueRange
        self.satProtection = satProtection; self.warmthBoost = warmthBoost
    }
}

struct ToneMapping: Codable, Equatable {
    var enabled: Bool, method: String, whitePoint: Float, shoulderStrength: Float, linearStrength: Float, toeStrength: Float
    init(enabled: Bool = false, method: String = "filmic", whitePoint: Float = 1.0,
         shoulderStrength: Float = 0.2, linearStrength: Float = 0.3, toeStrength: Float = 0.2) {
        self.enabled = enabled; self.method = method; self.whitePoint = whitePoint
        self.shoulderStrength = shoulderStrength; self.linearStrength = linearStrength; self.toeStrength = toeStrength
    }
}

// MARK: - Flash Effect (Disposable Camera)
struct FlashPosition: Codable, Equatable {
    var x: Float, y: Float
    init(x: Float = 0.5, y: Float = 0.35) { self.x = x; self.y = y }
}

struct FlashConfig: Codable, Equatable {
    var enabled: Bool
    var intensity: Float           // Overall flash strength (0.0-1.0)
    var falloff: Float             // Radial falloff rate (1.5-3.0, higher = faster falloff)
    var warmth: Float              // Warm tint amount (0.0-0.3)
    var shadowLift: Float          // Lifts shadows in flash area (0.0-0.5)
    var centerBoost: Float         // Extra brightness at flash center (0.0-0.5)
    var position: FlashPosition    // Flash origin position (normalized 0-1)
    var radius: Float              // Flash radius as fraction of screen (0.3-1.0)

    init(enabled: Bool = false,
         intensity: Float = 0.6,
         falloff: Float = 2.0,
         warmth: Float = 0.08,
         shadowLift: Float = 0.15,
         centerBoost: Float = 0.2,
         position: FlashPosition = FlashPosition(),
         radius: Float = 0.7) {
        self.enabled = enabled
        self.intensity = intensity
        self.falloff = falloff
        self.warmth = warmth
        self.shadowLift = shadowLift
        self.centerBoost = centerBoost
        self.position = position
        self.radius = radius
    }

    // MARK: - Static Presets

    /// Harsh flash - typical disposable camera
    static let harsh = FlashConfig(
        enabled: true,
        intensity: 0.7,
        falloff: 2.5,
        warmth: 0.05,
        shadowLift: 0.1,
        centerBoost: 0.25,
        position: FlashPosition(x: 0.5, y: 0.3),
        radius: 0.6
    )

    /// Soft flash - diffused/bounced
    static let soft = FlashConfig(
        enabled: true,
        intensity: 0.45,
        falloff: 1.5,
        warmth: 0.12,
        shadowLift: 0.25,
        centerBoost: 0.1,
        position: FlashPosition(x: 0.5, y: 0.4),
        radius: 0.85
    )

    /// Warm flash - tungsten bulb look
    static let warm = FlashConfig(
        enabled: true,
        intensity: 0.55,
        falloff: 1.8,
        warmth: 0.22,
        shadowLift: 0.18,
        centerBoost: 0.15,
        position: FlashPosition(x: 0.5, y: 0.35),
        radius: 0.75
    )

    /// Party/club flash - strong center, fast falloff
    static let party = FlashConfig(
        enabled: true,
        intensity: 0.8,
        falloff: 2.8,
        warmth: 0.03,
        shadowLift: 0.05,
        centerBoost: 0.3,
        position: FlashPosition(x: 0.5, y: 0.25),
        radius: 0.5
    )
}

struct FilmStock: Codable, Equatable {
    var manufacturer: String, name: String, type: String, speed: Int, year: Int, characteristics: [String]
    init(manufacturer: String = "", name: String = "", type: String = "", speed: Int = 400, year: Int = 2000, characteristics: [String] = []) {
        self.manufacturer = manufacturer; self.name = name; self.type = type
        self.speed = speed; self.year = year; self.characteristics = characteristics
    }
}

// MARK: - FILTER PRESET (Root Object)

struct FilterPreset: Codable, Identifiable, Equatable {
    let id: String, label: String, category: FilterCategory

    var lutId: String?, lutFile: String?, lutIntensity: Float, colorSpace: String
    var colorAdjustments: ColorAdjustments
    var splitTone: SplitToneConfig
    var selectiveColor: [SelectiveColorAdjustment]
    var lensDistortion: LensDistortionConfig
    var rgbCurves: RGBCurves

    var grain: GrainConfig
    var bloom: BloomConfig
    var vignette: VignetteConfig
    var halation: HalationConfig
    var instantFrame: InstantFrameConfig
    var flash: FlashConfig

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
         instantFrame: InstantFrameConfig = InstantFrameConfig(), flash: FlashConfig = FlashConfig(),
         skinToneProtection: SkinToneProtection = SkinToneProtection(),
         toneMapping: ToneMapping = ToneMapping(), filmStock: FilmStock = FilmStock()) {

        self.id = id; self.label = label; self.category = category
        self.lutId = lutId; self.lutFile = lutFile; self.lutIntensity = lutIntensity; self.colorSpace = colorSpace
        self.colorAdjustments = colorAdjustments; self.splitTone = splitTone
        self.selectiveColor = selectiveColor; self.lensDistortion = lensDistortion
        self.rgbCurves = rgbCurves
        self.grain = grain; self.bloom = bloom; self.vignette = vignette; self.halation = halation
        self.instantFrame = instantFrame; self.flash = flash
        self.skinToneProtection = skinToneProtection
        self.toneMapping = toneMapping; self.filmStock = filmStock
    }
}
