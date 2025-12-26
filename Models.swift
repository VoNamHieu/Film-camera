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

// MARK: - Light Leak Effect (Procedural)

/// Light leak type - determines the shape and position of the leak
enum LightLeakType: String, Codable, CaseIterable, Equatable {
    case cornerTopLeft
    case cornerTopRight
    case cornerBottomLeft
    case cornerBottomRight
    case edgeTop
    case edgeBottom
    case edgeLeft
    case edgeRight
    case streak           // Diagonal streak across frame
    case random           // Random position each time
}

/// Blend mode for light leak
enum LightLeakBlendMode: Int, Codable, CaseIterable, Equatable {
    case screen = 0       // Natural, most common
    case add = 1          // Brighter, can blow out
    case overlay = 2      // Higher contrast
    case softLight = 3    // Subtle
}

struct LightLeakConfig: Codable, Equatable {
    var enabled: Bool
    var type: LightLeakType           // Leak position/shape
    var opacity: Float                // Overall opacity (0.0-1.0)
    var size: Float                   // Size of leak area (0.2-1.0)
    var softness: Float               // Edge softness (0.1-1.0)
    var warmth: Float                 // Color warmth (-1.0 cool to 1.0 warm)
    var saturation: Float             // Color saturation (0.0-1.5)
    var hueShift: Float               // Hue rotation (0.0-1.0, wraps)
    var blendMode: LightLeakBlendMode // How leak blends with image
    var seed: UInt32                  // Random seed for variation

    init(enabled: Bool = false,
         type: LightLeakType = .cornerTopRight,
         opacity: Float = 0.4,
         size: Float = 0.5,
         softness: Float = 0.6,
         warmth: Float = 0.5,
         saturation: Float = 1.0,
         hueShift: Float = 0.05,
         blendMode: LightLeakBlendMode = .screen,
         seed: UInt32 = 0) {
        self.enabled = enabled
        self.type = type
        self.opacity = opacity
        self.size = size
        self.softness = softness
        self.warmth = warmth
        self.saturation = saturation
        self.hueShift = hueShift
        self.blendMode = blendMode
        self.seed = seed
    }

    // MARK: - Static Presets

    /// Warm corner leak - classic disposable camera
    static let warmCorner = LightLeakConfig(
        enabled: true,
        type: .cornerTopRight,
        opacity: 0.45,
        size: 0.5,
        softness: 0.65,
        warmth: 0.7,
        saturation: 1.1,
        hueShift: 0.02,
        blendMode: .screen
    )

    /// Cool edge leak - instant camera style
    static let coolEdge = LightLeakConfig(
        enabled: true,
        type: .edgeLeft,
        opacity: 0.35,
        size: 0.4,
        softness: 0.7,
        warmth: -0.5,
        saturation: 0.9,
        hueShift: 0.6,
        blendMode: .screen
    )

    /// Strong diagonal streak - lomography style
    static let streak = LightLeakConfig(
        enabled: true,
        type: .streak,
        opacity: 0.55,
        size: 0.6,
        softness: 0.5,
        warmth: 0.8,
        saturation: 1.3,
        hueShift: 0.0,
        blendMode: .add
    )

    /// Subtle vintage leak
    static let subtle = LightLeakConfig(
        enabled: true,
        type: .cornerBottomLeft,
        opacity: 0.25,
        size: 0.35,
        softness: 0.8,
        warmth: 0.4,
        saturation: 0.8,
        hueShift: 0.05,
        blendMode: .softLight
    )

    /// Magenta/pink leak - creative style
    static let magenta = LightLeakConfig(
        enabled: true,
        type: .edgeRight,
        opacity: 0.4,
        size: 0.45,
        softness: 0.6,
        warmth: 0.0,
        saturation: 1.2,
        hueShift: 0.85,
        blendMode: .screen
    )

    /// Random leak - different each shot
    static let random = LightLeakConfig(
        enabled: true,
        type: .random,
        opacity: 0.4,
        size: 0.5,
        softness: 0.6,
        warmth: 0.5,
        saturation: 1.0,
        hueShift: 0.0,
        blendMode: .screen
    )
}

// MARK: - Date Stamp Effect

/// Date stamp format styles
enum DateStampFormat: String, Codable, CaseIterable, Equatable {
    case short          // '24 12 25
    case full           // 12/25/2024
    case japanese       // 2024.12.25
    case european       // 25.12.2024
    case yearMonth      // '24 12

    func format(_ date: Date) -> String {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        let shortYear = year % 100

        switch self {
        case .short: return String(format: "'%02d %02d %02d", shortYear, month, day)
        case .full: return String(format: "%02d/%02d/%04d", month, day, year)
        case .japanese: return String(format: "%04d.%02d.%02d", year, month, day)
        case .european: return String(format: "%02d.%02d.%04d", day, month, year)
        case .yearMonth: return String(format: "'%02d %02d", shortYear, month)
        }
    }
}

/// Date stamp position on image
enum DateStampPosition: String, Codable, CaseIterable, Equatable {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
}

/// Date stamp color preset
enum DateStampColor: String, Codable, CaseIterable, Equatable {
    case orange     // Classic disposable camera
    case red        // Digicam style
    case yellow     // Vintage
    case green      // Night vision style
    case white      // Clean modern

    var rgb: (r: Float, g: Float, b: Float) {
        switch self {
        case .orange: return (1.0, 0.6, 0.2)
        case .red: return (1.0, 0.3, 0.2)
        case .yellow: return (1.0, 0.85, 0.3)
        case .green: return (0.3, 1.0, 0.3)
        case .white: return (1.0, 1.0, 1.0)
        }
    }
}

struct DateStampConfig: Codable, Equatable {
    var enabled: Bool
    var format: DateStampFormat       // Date format style
    var position: DateStampPosition   // Position on screen
    var color: DateStampColor         // Text color
    var opacity: Float                // Opacity (0.0-1.0)
    var scale: Float                  // Size multiplier (0.5-2.0)
    var marginX: Float                // Horizontal margin (0.02-0.1)
    var marginY: Float                // Vertical margin (0.02-0.1)
    var glowEnabled: Bool             // LED glow effect
    var glowIntensity: Float          // Glow strength (0.0-1.0)

    init(enabled: Bool = false,
         format: DateStampFormat = .short,
         position: DateStampPosition = .bottomRight,
         color: DateStampColor = .orange,
         opacity: Float = 0.85,
         scale: Float = 1.0,
         marginX: Float = 0.04,
         marginY: Float = 0.05,
         glowEnabled: Bool = true,
         glowIntensity: Float = 0.5) {
        self.enabled = enabled
        self.format = format
        self.position = position
        self.color = color
        self.opacity = opacity
        self.scale = scale
        self.marginX = marginX
        self.marginY = marginY
        self.glowEnabled = glowEnabled
        self.glowIntensity = glowIntensity
    }

    // MARK: - Static Presets

    /// Classic disposable camera style (orange LCD)
    static let disposable = DateStampConfig(
        enabled: true,
        format: .short,
        position: .bottomRight,
        color: .orange,
        opacity: 0.85,
        scale: 1.0,
        glowEnabled: true,
        glowIntensity: 0.5
    )

    /// Digital camera style (red LED)
    static let digicam = DateStampConfig(
        enabled: true,
        format: .full,
        position: .bottomRight,
        color: .red,
        opacity: 0.9,
        scale: 0.8,
        glowEnabled: false
    )

    /// Vintage film camera style
    static let vintage = DateStampConfig(
        enabled: true,
        format: .short,
        position: .bottomRight,
        color: .yellow,
        opacity: 0.75,
        scale: 1.1,
        glowEnabled: true,
        glowIntensity: 0.6
    )

    /// Japanese camera style
    static let japanese = DateStampConfig(
        enabled: true,
        format: .japanese,
        position: .bottomRight,
        color: .orange,
        opacity: 0.8,
        scale: 0.9,
        glowEnabled: true,
        glowIntensity: 0.4
    )
}

// MARK: - CCD Bloom Effect (Digicam-specific)

/// CCD Bloom simulates the vertical smear and purple fringing
/// characteristic of early 2000s digital cameras with CCD sensors
struct CCDBloomConfig: Codable, Equatable {
    var enabled: Bool

    // Bloom Settings
    var intensity: Float              // Overall intensity (0.0-1.0)
    var threshold: Float              // Brightness threshold (0.5-1.0)

    // Vertical Smear (CCD charge leak)
    var verticalSmear: Float          // Vertical smear intensity (0.0-1.0)
    var smearLength: Float            // Smear length in relative units (0.0-1.0)
    var smearFalloff: Float           // Falloff curve (1.0=linear, 2.0=quadratic)

    // Horizontal Bloom
    var horizontalBloom: Float        // Horizontal bloom intensity (0.0-0.5)
    var horizontalRadius: Float       // Horizontal blur radius (0.0-1.0)

    // Purple Fringing
    var purpleFringing: Float         // Purple fringe intensity (0.0-0.5)
    var fringeWidth: Float            // Fringe width (0.0-1.0)

    // Color
    var warmShift: Float              // Warm color shift in bloom areas (0.0-0.3)

    init(enabled: Bool = false,
         intensity: Float = 0.5,
         threshold: Float = 0.7,
         verticalSmear: Float = 0.3,
         smearLength: Float = 0.15,
         smearFalloff: Float = 1.5,
         horizontalBloom: Float = 0.15,
         horizontalRadius: Float = 0.05,
         purpleFringing: Float = 0.2,
         fringeWidth: Float = 0.01,
         warmShift: Float = 0.1) {
        self.enabled = enabled
        self.intensity = intensity
        self.threshold = threshold
        self.verticalSmear = verticalSmear
        self.smearLength = smearLength
        self.smearFalloff = smearFalloff
        self.horizontalBloom = horizontalBloom
        self.horizontalRadius = horizontalRadius
        self.purpleFringing = purpleFringing
        self.fringeWidth = fringeWidth
        self.warmShift = warmShift
    }

    // MARK: - Static Presets

    /// Sony Cybershot style (early 2000s) - heavy vertical smear
    static let cybershot = CCDBloomConfig(
        enabled: true,
        intensity: 0.5,
        threshold: 0.65,
        verticalSmear: 0.35,
        smearLength: 0.2,
        smearFalloff: 1.5,
        horizontalBloom: 0.2,
        horizontalRadius: 0.06,
        purpleFringing: 0.25,
        fringeWidth: 0.012,
        warmShift: 0.1
    )

    /// Canon PowerShot style - moderate artifacts
    static let powershot = CCDBloomConfig(
        enabled: true,
        intensity: 0.4,
        threshold: 0.7,
        verticalSmear: 0.25,
        smearLength: 0.12,
        smearFalloff: 1.8,
        horizontalBloom: 0.1,
        horizontalRadius: 0.04,
        purpleFringing: 0.15,
        fringeWidth: 0.008,
        warmShift: 0.08
    )

    /// Extreme/artistic - heavy artifacts for creative effect
    static let extreme = CCDBloomConfig(
        enabled: true,
        intensity: 0.7,
        threshold: 0.55,
        verticalSmear: 0.5,
        smearLength: 0.3,
        smearFalloff: 1.2,
        horizontalBloom: 0.3,
        horizontalRadius: 0.08,
        purpleFringing: 0.4,
        fringeWidth: 0.015,
        warmShift: 0.15
    )

    /// Subtle - modern digicam with minimal artifacts
    static let subtle = CCDBloomConfig(
        enabled: true,
        intensity: 0.25,
        threshold: 0.8,
        verticalSmear: 0.15,
        smearLength: 0.08,
        smearFalloff: 2.0,
        horizontalBloom: 0.05,
        horizontalRadius: 0.02,
        purpleFringing: 0.1,
        fringeWidth: 0.005,
        warmShift: 0.05
    )
}

// MARK: - Black & White Pipeline

/// Toning mode for B&W conversion
enum BWToning: String, Codable, CaseIterable, Equatable {
    case none           // Pure black and white
    case sepia          // Classic warm brown
    case selenium       // Cool blue-black, archival look
    case cyanotype      // Prussian blue, blueprint style
    case splitTone      // Different colors for shadows/highlights
    case custom         // User-defined toning color
}

/// Custom toning color for B&W
struct BWToningColor: Codable, Equatable {
    var r: Float, g: Float, b: Float
    init(r: Float = 0.8, g: Float = 0.7, b: Float = 0.5) { self.r = r; self.g = g; self.b = b }
}

/// Split tone configuration for B&W
struct BWSplitTone: Codable, Equatable {
    var shadowHue: Float        // Shadow color hue (0-1)
    var shadowSat: Float        // Shadow saturation (0-1)
    var highlightHue: Float     // Highlight color hue (0-1)
    var highlightSat: Float     // Highlight saturation (0-1)
    var balance: Float          // Balance shadows/highlights (-1 to 1)

    init(shadowHue: Float = 0.08, shadowSat: Float = 0.15,
         highlightHue: Float = 0.55, highlightSat: Float = 0.1,
         balance: Float = 0.0) {
        self.shadowHue = shadowHue
        self.shadowSat = shadowSat
        self.highlightHue = highlightHue
        self.highlightSat = highlightSat
        self.balance = balance
    }
}

/// Black & White conversion configuration
struct BWConfig: Codable, Equatable {
    var enabled: Bool

    // Channel Mixing (how RGB contributes to luminance)
    var redWeight: Float          // Red channel weight (0.0-2.0, default ~0.3)
    var greenWeight: Float        // Green channel weight (0.0-2.0, default ~0.59)
    var blueWeight: Float         // Blue channel weight (0.0-2.0, default ~0.11)

    // Contrast & Tone
    var contrast: Float           // Contrast adjustment (-1.0 to 1.0)
    var brightness: Float         // Brightness adjustment (-1.0 to 1.0)
    var gamma: Float              // Gamma curve (0.5-2.0, 1.0 = linear)

    // Toning
    var toning: BWToning          // Toning mode
    var toningIntensity: Float    // Toning strength (0.0-1.0)
    var customColor: BWToningColor // Custom toning color (when toning = .custom)
    var splitTone: BWSplitTone    // Split tone settings (when toning = .splitTone)

    // Film grain simulation (B&W specific)
    var grainIntensity: Float     // B&W grain amount (0.0-1.0)
    var grainSize: Float          // Grain size (0.5-2.0)

    init(enabled: Bool = false,
         redWeight: Float = 0.299,
         greenWeight: Float = 0.587,
         blueWeight: Float = 0.114,
         contrast: Float = 0.0,
         brightness: Float = 0.0,
         gamma: Float = 1.0,
         toning: BWToning = .none,
         toningIntensity: Float = 0.5,
         customColor: BWToningColor = BWToningColor(),
         splitTone: BWSplitTone = BWSplitTone(),
         grainIntensity: Float = 0.0,
         grainSize: Float = 1.0) {
        self.enabled = enabled
        self.redWeight = redWeight
        self.greenWeight = greenWeight
        self.blueWeight = blueWeight
        self.contrast = contrast
        self.brightness = brightness
        self.gamma = gamma
        self.toning = toning
        self.toningIntensity = toningIntensity
        self.customColor = customColor
        self.splitTone = splitTone
        self.grainIntensity = grainIntensity
        self.grainSize = grainSize
    }

    // MARK: - Film Stock Presets

    /// Kodak Tri-X 400 - High contrast, punchy blacks
    static let triX = BWConfig(
        enabled: true,
        redWeight: 0.35,
        greenWeight: 0.55,
        blueWeight: 0.10,
        contrast: 0.15,
        brightness: 0.0,
        gamma: 0.95,
        toning: .none,
        grainIntensity: 0.25,
        grainSize: 1.2
    )

    /// Ilford HP5 Plus - Classic, versatile, smooth gradation
    static let hp5Plus = BWConfig(
        enabled: true,
        redWeight: 0.30,
        greenWeight: 0.58,
        blueWeight: 0.12,
        contrast: 0.08,
        brightness: 0.02,
        gamma: 1.0,
        toning: .none,
        grainIntensity: 0.18,
        grainSize: 1.0
    )

    /// Kodak T-Max 400 - Fine grain, modern look
    static let tMax = BWConfig(
        enabled: true,
        redWeight: 0.28,
        greenWeight: 0.62,
        blueWeight: 0.10,
        contrast: 0.10,
        brightness: 0.0,
        gamma: 1.05,
        toning: .none,
        grainIntensity: 0.12,
        grainSize: 0.8
    )

    /// Ilford Delta 100 - Ultra fine grain, smooth tones
    static let delta = BWConfig(
        enabled: true,
        redWeight: 0.27,
        greenWeight: 0.63,
        blueWeight: 0.10,
        contrast: 0.05,
        brightness: 0.0,
        gamma: 1.02,
        toning: .none,
        grainIntensity: 0.08,
        grainSize: 0.6
    )

    /// Vintage Sepia - Classic sepia toned print
    static let vintageSepia = BWConfig(
        enabled: true,
        redWeight: 0.35,
        greenWeight: 0.50,
        blueWeight: 0.15,
        contrast: 0.08,
        brightness: 0.05,
        gamma: 1.0,
        toning: .sepia,
        toningIntensity: 0.6
    )

    /// Selenium Toned - Archival print look
    static let seleniumToned = BWConfig(
        enabled: true,
        redWeight: 0.30,
        greenWeight: 0.59,
        blueWeight: 0.11,
        contrast: 0.12,
        brightness: 0.0,
        gamma: 0.98,
        toning: .selenium,
        toningIntensity: 0.4
    )

    /// Cyanotype - Blueprint style
    static let cyanotype = BWConfig(
        enabled: true,
        redWeight: 0.25,
        greenWeight: 0.55,
        blueWeight: 0.20,
        contrast: 0.15,
        brightness: 0.0,
        gamma: 1.0,
        toning: .cyanotype,
        toningIntensity: 0.7
    )

    /// High Contrast - Dramatic look
    static let highContrast = BWConfig(
        enabled: true,
        redWeight: 0.40,
        greenWeight: 0.50,
        blueWeight: 0.10,
        contrast: 0.35,
        brightness: 0.0,
        gamma: 0.9,
        toning: .none,
        grainIntensity: 0.15,
        grainSize: 1.0
    )

    /// Low Key - Dark, moody
    static let lowKey = BWConfig(
        enabled: true,
        redWeight: 0.30,
        greenWeight: 0.59,
        blueWeight: 0.11,
        contrast: 0.20,
        brightness: -0.15,
        gamma: 0.85,
        toning: .none,
        grainIntensity: 0.20,
        grainSize: 1.1
    )

    /// High Key - Bright, airy
    static let highKey = BWConfig(
        enabled: true,
        redWeight: 0.30,
        greenWeight: 0.59,
        blueWeight: 0.11,
        contrast: -0.10,
        brightness: 0.20,
        gamma: 1.15,
        toning: .none,
        grainIntensity: 0.10,
        grainSize: 0.8
    )
}

// MARK: - Overlays (Dust & Scratches)

/// Blend mode for overlay effects
enum OverlayBlendMode: Int, Codable, CaseIterable, Equatable {
    case multiply = 0     // Darkens - good for dust
    case screen = 1       // Lightens - good for light scratches
    case overlay = 2      // Contrast blend
    case softLight = 3    // Subtle blend
}

/// Dust overlay configuration
struct DustConfig: Codable, Equatable {
    var enabled: Bool
    var density: Float            // Number of dust particles (0.0-1.0)
    var size: Float               // Particle size (0.5-2.0)
    var opacity: Float            // Overall opacity (0.0-1.0)
    var variation: Float          // Size variation (0.0-1.0)
    var clumping: Float           // How much dust clumps together (0.0-1.0)
    var blendMode: OverlayBlendMode

    init(enabled: Bool = false,
         density: Float = 0.3,
         size: Float = 1.0,
         opacity: Float = 0.4,
         variation: Float = 0.5,
         clumping: Float = 0.3,
         blendMode: OverlayBlendMode = .multiply) {
        self.enabled = enabled
        self.density = density
        self.size = size
        self.opacity = opacity
        self.variation = variation
        self.clumping = clumping
        self.blendMode = blendMode
    }
}

/// Scratches overlay configuration
struct ScratchesConfig: Codable, Equatable {
    var enabled: Bool
    var density: Float            // Number of scratches (0.0-1.0)
    var length: Float             // Scratch length (0.0-1.0)
    var width: Float              // Scratch width (0.5-2.0)
    var opacity: Float            // Overall opacity (0.0-1.0)
    var angle: Float              // Primary angle variation (-1.0 to 1.0)
    var vertical: Bool            // Prefer vertical scratches (film transport)
    var blendMode: OverlayBlendMode

    init(enabled: Bool = false,
         density: Float = 0.2,
         length: Float = 0.5,
         width: Float = 1.0,
         opacity: Float = 0.3,
         angle: Float = 0.1,
         vertical: Bool = true,
         blendMode: OverlayBlendMode = .screen) {
        self.enabled = enabled
        self.density = density
        self.length = length
        self.width = width
        self.opacity = opacity
        self.angle = angle
        self.vertical = vertical
        self.blendMode = blendMode
    }
}

/// Combined overlays configuration
struct OverlaysConfig: Codable, Equatable {
    var enabled: Bool
    var dust: DustConfig
    var scratches: ScratchesConfig
    var seed: UInt32              // Random seed for consistency
    var animate: Bool             // Animate overlays (for video)

    init(enabled: Bool = false,
         dust: DustConfig = DustConfig(),
         scratches: ScratchesConfig = ScratchesConfig(),
         seed: UInt32 = 0,
         animate: Bool = false) {
        self.enabled = enabled
        self.dust = dust
        self.scratches = scratches
        self.seed = seed
        self.animate = animate
    }

    // MARK: - Static Presets

    /// Light dust - subtle vintage look
    static let lightDust = OverlaysConfig(
        enabled: true,
        dust: DustConfig(enabled: true, density: 0.2, size: 0.8, opacity: 0.3),
        scratches: ScratchesConfig(enabled: false)
    )

    /// Film scratches - projector wear
    static let filmScratches = OverlaysConfig(
        enabled: true,
        dust: DustConfig(enabled: false),
        scratches: ScratchesConfig(enabled: true, density: 0.25, length: 0.6, width: 0.8, opacity: 0.35, vertical: true)
    )

    /// Aged film - heavy dust and scratches
    static let agedFilm = OverlaysConfig(
        enabled: true,
        dust: DustConfig(enabled: true, density: 0.5, size: 1.2, opacity: 0.5, clumping: 0.5),
        scratches: ScratchesConfig(enabled: true, density: 0.4, length: 0.7, width: 1.0, opacity: 0.4)
    )

    /// Archive footage - moderate wear
    static let archive = OverlaysConfig(
        enabled: true,
        dust: DustConfig(enabled: true, density: 0.35, size: 1.0, opacity: 0.4),
        scratches: ScratchesConfig(enabled: true, density: 0.2, length: 0.5, width: 0.9, opacity: 0.3)
    )

    /// Subtle vintage - minimal imperfections
    static let subtleVintage = OverlaysConfig(
        enabled: true,
        dust: DustConfig(enabled: true, density: 0.15, size: 0.7, opacity: 0.25),
        scratches: ScratchesConfig(enabled: true, density: 0.1, length: 0.3, width: 0.6, opacity: 0.2)
    )

    /// 8mm film - heavy wear pattern
    static let film8mm = OverlaysConfig(
        enabled: true,
        dust: DustConfig(enabled: true, density: 0.6, size: 1.5, opacity: 0.55, clumping: 0.6),
        scratches: ScratchesConfig(enabled: true, density: 0.5, length: 0.8, width: 1.2, opacity: 0.45, vertical: true)
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
    var lightLeak: LightLeakConfig
    var dateStamp: DateStampConfig
    var ccdBloom: CCDBloomConfig
    var bw: BWConfig
    var overlays: OverlaysConfig

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
         lightLeak: LightLeakConfig = LightLeakConfig(), dateStamp: DateStampConfig = DateStampConfig(),
         ccdBloom: CCDBloomConfig = CCDBloomConfig(), bw: BWConfig = BWConfig(),
         overlays: OverlaysConfig = OverlaysConfig(),
         skinToneProtection: SkinToneProtection = SkinToneProtection(),
         toneMapping: ToneMapping = ToneMapping(), filmStock: FilmStock = FilmStock()) {

        self.id = id; self.label = label; self.category = category
        self.lutId = lutId; self.lutFile = lutFile; self.lutIntensity = lutIntensity; self.colorSpace = colorSpace
        self.colorAdjustments = colorAdjustments; self.splitTone = splitTone
        self.selectiveColor = selectiveColor; self.lensDistortion = lensDistortion
        self.rgbCurves = rgbCurves
        self.grain = grain; self.bloom = bloom; self.vignette = vignette; self.halation = halation
        self.instantFrame = instantFrame; self.flash = flash; self.lightLeak = lightLeak; self.dateStamp = dateStamp
        self.ccdBloom = ccdBloom; self.bw = bw; self.overlays = overlays
        self.skinToneProtection = skinToneProtection
        self.toneMapping = toneMapping; self.filmStock = filmStock
    }
}
