// FilmCondition.swift
// Film Camera - Film Condition System
//
// Models physical film condition (age, handling, camera type)
// to generate realistic artifacts like dust, scratches, light leaks

import Foundation

// MARK: - Film Condition Enums

/// Film age/condition state
enum FilmAge: String, Codable, CaseIterable, Equatable {
    case new = "new"              // Fresh film, minimal artifacts
    case aged = "aged"            // Some age, moderate artifacts
    case vintage = "vintage"      // Old film, more artifacts
    case damaged = "damaged"      // Heavily damaged

    var displayName: String {
        switch self {
        case .new: return "New Film"
        case .aged: return "Aged Film"
        case .vintage: return "Vintage"
        case .damaged: return "Damaged"
        }
    }

    /// Multiplier for dust density
    var dustMultiplier: Float {
        switch self {
        case .new: return 0.3
        case .aged: return 1.0
        case .vintage: return 1.8
        case .damaged: return 3.0
        }
    }

    /// Multiplier for scratch density
    var scratchMultiplier: Float {
        switch self {
        case .new: return 0.2
        case .aged: return 1.0
        case .vintage: return 2.0
        case .damaged: return 4.0
        }
    }

    /// Multiplier for light leak probability
    var leakMultiplier: Float {
        switch self {
        case .new: return 0.5
        case .aged: return 1.0
        case .vintage: return 1.5
        case .damaged: return 2.5
        }
    }

    /// Grain intensity boost
    var grainBoost: Float {
        switch self {
        case .new: return 0.0
        case .aged: return 0.05
        case .vintage: return 0.12
        case .damaged: return 0.20
        }
    }
}

/// Camera type that captured the film
enum FilmCameraType: String, Codable, CaseIterable, Equatable {
    case professional = "professional"
    case prosumer = "prosumer"
    case consumer = "consumer"
    case toy = "toy"
    case cinema = "cinema"

    var displayName: String {
        switch self {
        case .professional: return "Professional"
        case .prosumer: return "Prosumer"
        case .consumer: return "Consumer"
        case .toy: return "Toy/Disposable"
        case .cinema: return "Cinema"
        }
    }

    /// Base probability for light leak (0-1)
    var baseLightLeakProbability: Float {
        switch self {
        case .professional: return 0.05
        case .prosumer: return 0.15
        case .consumer: return 0.30
        case .toy: return 0.50
        case .cinema: return 0.08
        }
    }

    /// Typical light leak types for this camera
    var typicalLeakTypes: [LightLeakType] {
        switch self {
        case .professional:
            return [.cornerTopRight]
        case .prosumer:
            return [.cornerTopRight, .cornerTopLeft, .edgeLeft, .edgeRight]
        case .consumer:
            return [.cornerTopRight, .cornerBottomLeft, .edgeLeft, .edgeRight, .streak]
        case .toy:
            return LightLeakType.allCases
        case .cinema:
            return [.edgeTop, .edgeBottom]
        }
    }

    /// Light leak intensity range (min, max)
    var leakIntensityMin: Float {
        switch self {
        case .professional: return 0.02
        case .prosumer: return 0.05
        case .consumer: return 0.10
        case .toy: return 0.15
        case .cinema: return 0.03
        }
    }

    var leakIntensityMax: Float {
        switch self {
        case .professional: return 0.08
        case .prosumer: return 0.15
        case .consumer: return 0.30
        case .toy: return 0.50
        case .cinema: return 0.10
        }
    }

    /// Vignette intensity for this camera type
    var vignetteIntensity: Float {
        switch self {
        case .professional: return 0.08
        case .prosumer: return 0.12
        case .consumer: return 0.18
        case .toy: return 0.28
        case .cinema: return 0.06
        }
    }
}

/// Film stock type (chemical process)
enum FilmStockType: String, Codable, CaseIterable, Equatable {
    case colorNegative = "color_negative"     // C-41 process
    case colorSlide = "color_slide"           // E-6 process
    case bwNegative = "bw_negative"           // B&W
    case cinema = "cinema"                    // ECN-2 process
    case cinemaModified = "cinema_modified"   // Remjet removed (CineStill)
    case instant = "instant"                  // Polaroid/Instax

    var displayName: String {
        switch self {
        case .colorNegative: return "Color Negative (C-41)"
        case .colorSlide: return "Color Slide (E-6)"
        case .bwNegative: return "Black & White"
        case .cinema: return "Cinema (ECN-2)"
        case .cinemaModified: return "Cinema Modified"
        case .instant: return "Instant Film"
        }
    }

    /// Whether this film type produces halation
    var hasHalation: Bool {
        return self == .cinemaModified
    }

    /// Base grain intensity for this film type
    var baseGrainIntensity: Float {
        switch self {
        case .colorNegative: return 0.12
        case .colorSlide: return 0.08
        case .bwNegative: return 0.18
        case .cinema: return 0.06
        case .cinemaModified: return 0.10
        case .instant: return 0.15
        }
    }

    /// Typical warmth for light leaks
    var leakWarmth: Float {
        switch self {
        case .colorNegative: return 0.6
        case .colorSlide: return 0.4
        case .bwNegative: return 0.0
        case .cinema, .cinemaModified: return 0.8
        case .instant: return 0.5
        }
    }

    /// Saturation for light leaks
    var leakSaturation: Float {
        switch self {
        case .colorNegative: return 1.0
        case .colorSlide: return 1.2
        case .bwNegative: return 0.0
        case .cinema, .cinemaModified: return 1.1
        case .instant: return 0.8
        }
    }
}

// MARK: - Film Condition Configuration

/// Complete film condition configuration
/// Generates realistic artifacts based on film age, camera type, and stock
struct FilmConditionConfig: Codable, Equatable {
    var enabled: Bool
    var age: FilmAge
    var cameraType: FilmCameraType
    var stockType: FilmStockType

    // Override multipliers (1.0 = use defaults)
    var dustMultiplierOverride: Float
    var scratchMultiplierOverride: Float
    var leakMultiplierOverride: Float
    var grainMultiplierOverride: Float

    // MARK: - Initializer

    init(enabled: Bool = false,
         age: FilmAge = .new,
         cameraType: FilmCameraType = .prosumer,
         stockType: FilmStockType = .colorNegative,
         dustMultiplierOverride: Float = 1.0,
         scratchMultiplierOverride: Float = 1.0,
         leakMultiplierOverride: Float = 1.0,
         grainMultiplierOverride: Float = 1.0) {
        self.enabled = enabled
        self.age = age
        self.cameraType = cameraType
        self.stockType = stockType
        self.dustMultiplierOverride = dustMultiplierOverride
        self.scratchMultiplierOverride = scratchMultiplierOverride
        self.leakMultiplierOverride = leakMultiplierOverride
        self.grainMultiplierOverride = grainMultiplierOverride
    }

    // MARK: - Computed Properties

    /// Effective dust multiplier
    var effectiveDustMultiplier: Float {
        return age.dustMultiplier * dustMultiplierOverride
    }

    /// Effective scratch multiplier
    var effectiveScratchMultiplier: Float {
        return age.scratchMultiplier * scratchMultiplierOverride
    }

    /// Effective light leak probability
    var effectiveLeakProbability: Float {
        let base = cameraType.baseLightLeakProbability
        return min(1.0, base * age.leakMultiplier * leakMultiplierOverride)
    }

    /// Effective grain intensity
    var effectiveGrainIntensity: Float {
        let base = stockType.baseGrainIntensity
        let aged = base + age.grainBoost
        return aged * grainMultiplierOverride
    }

    /// Should light leak be applied (based on probability)
    func shouldApplyLightLeak(seed: UInt32 = 0) -> Bool {
        let random = Float(((seed &* 1103515245) &+ 12345) % 100) / 100.0
        return random < effectiveLeakProbability
    }

    // MARK: - Generate Configs

    /// Generate DustConfig based on condition
    func generateDustConfig(baseDensity: Float = 0.15) -> DustConfig {
        return DustConfig(
            enabled: enabled && effectiveDustMultiplier > 0,
            density: baseDensity * effectiveDustMultiplier,
            size: 1.0 + (age == .vintage || age == .damaged ? 0.3 : 0),
            opacity: min(0.6, 0.25 * effectiveDustMultiplier),
            variation: 0.5,
            clumping: age == .damaged ? 0.5 : 0.3,
            blendMode: .multiply
        )
    }

    /// Generate ScratchesConfig based on condition
    func generateScratchesConfig(baseDensity: Float = 0.12) -> ScratchesConfig {
        return ScratchesConfig(
            enabled: enabled && effectiveScratchMultiplier > 0,
            density: baseDensity * effectiveScratchMultiplier,
            length: age == .damaged ? 0.7 : 0.5,
            width: 1.0,
            opacity: min(0.5, 0.20 * effectiveScratchMultiplier),
            angle: 0.1,
            vertical: true,
            blendMode: .screen
        )
    }

    /// Generate LightLeakConfig based on condition
    func generateLightLeakConfig(seed: UInt32 = 0) -> LightLeakConfig {
        let types = cameraType.typicalLeakTypes
        let selectedType = types.isEmpty ? .cornerTopRight : types[Int(seed) % types.count]

        let intensityRange = cameraType.leakIntensityMax - cameraType.leakIntensityMin
        let randomFactor = Float(((seed &* 1103515245) &+ 12345) % 100) / 100.0
        let intensity = cameraType.leakIntensityMin + (intensityRange * randomFactor)

        return LightLeakConfig(
            enabled: enabled && shouldApplyLightLeak(seed: seed),
            type: selectedType,
            opacity: intensity * leakMultiplierOverride,
            size: 0.4 + (randomFactor * 0.3),
            softness: 0.5 + (randomFactor * 0.3),
            warmth: stockType.leakWarmth,
            saturation: stockType.leakSaturation,
            hueShift: randomFactor * 0.1,
            blendMode: .screen,
            seed: seed
        )
    }

    /// Generate GrainConfig based on condition
    func generateGrainConfig() -> GrainConfig {
        return GrainConfig(
            enabled: enabled,
            globalIntensity: effectiveGrainIntensity,
            size: stockType == .bwNegative ? 1.2 : 1.0,
            softness: stockType == .colorSlide ? 0.65 : 0.55,
            colorTint: GrainColorTint(r: 1.0, g: 1.0, b: 1.0),
            channels: GrainChannels(
                red: GrainChannel(intensity: 1.0, size: 1.0),
                green: GrainChannel(intensity: stockType == .bwNegative ? 1.0 : 0.95),
                blue: GrainChannel(intensity: stockType == .bwNegative ? 1.0 : 1.05)
            )
        )
    }

    /// Generate complete OverlaysConfig
    func generateOverlaysConfig(seed: UInt32 = 0) -> OverlaysConfig {
        return OverlaysConfig(
            enabled: enabled,
            dust: generateDustConfig(),
            scratches: generateScratchesConfig(),
            seed: seed,
            animate: false
        )
    }

    /// Generate VignetteConfig based on camera type
    func generateVignetteConfig() -> VignetteConfig {
        return VignetteConfig(
            enabled: enabled,
            intensity: cameraType.vignetteIntensity,
            roundness: cameraType == .toy ? 0.65 : 0.80,
            feather: 0.60
        )
    }

    /// Generate HalationConfig (only for cinema_modified)
    func generateHalationConfig() -> HalationConfig {
        guard stockType.hasHalation else {
            return HalationConfig(enabled: false)
        }

        return HalationConfig(
            enabled: enabled,
            intensity: 0.40,
            threshold: 0.75,
            radius: 25,
            softness: 0.80,
            color: HalationColor(r: 1.0, g: 0.20, b: 0.12)
        )
    }

    // MARK: - Static Presets

    /// New, professionally handled film
    static var pristine: FilmConditionConfig {
        return FilmConditionConfig(
            enabled: true,
            age: .new,
            cameraType: .professional,
            stockType: .colorNegative,
            dustMultiplierOverride: 0.3,
            scratchMultiplierOverride: 0.2,
            leakMultiplierOverride: 0.5
        )
    }

    /// Typical consumer film condition
    static var typical: FilmConditionConfig {
        return FilmConditionConfig(
            enabled: true,
            age: .aged,
            cameraType: .consumer,
            stockType: .colorNegative
        )
    }

    /// Disposable camera look
    static var disposable: FilmConditionConfig {
        return FilmConditionConfig(
            enabled: true,
            age: .new,
            cameraType: .toy,
            stockType: .colorNegative,
            leakMultiplierOverride: 1.2
        )
    }

    /// Vintage/thrift store film
    static var vintage: FilmConditionConfig {
        return FilmConditionConfig(
            enabled: true,
            age: .vintage,
            cameraType: .consumer,
            stockType: .colorNegative,
            dustMultiplierOverride: 1.5,
            scratchMultiplierOverride: 1.5
        )
    }

    /// CineStill style (with halation)
    static var cinestill: FilmConditionConfig {
        return FilmConditionConfig(
            enabled: true,
            age: .new,
            cameraType: .prosumer,
            stockType: .cinemaModified,
            leakMultiplierOverride: 1.3
        )
    }

    /// Black and white classic
    static var classicBW: FilmConditionConfig {
        return FilmConditionConfig(
            enabled: true,
            age: .aged,
            cameraType: .prosumer,
            stockType: .bwNegative,
            grainMultiplierOverride: 1.2
        )
    }

    /// Slide film - professional handling
    static var slideFilm: FilmConditionConfig {
        return FilmConditionConfig(
            enabled: true,
            age: .new,
            cameraType: .professional,
            stockType: .colorSlide,
            dustMultiplierOverride: 0.4,
            leakMultiplierOverride: 0.3
        )
    }

    /// Heavily damaged/expired film
    static var expired: FilmConditionConfig {
        return FilmConditionConfig(
            enabled: true,
            age: .damaged,
            cameraType: .consumer,
            stockType: .colorNegative,
            dustMultiplierOverride: 2.0,
            scratchMultiplierOverride: 2.0,
            grainMultiplierOverride: 1.5
        )
    }

    /// Instant film (Polaroid/Instax)
    static var instantFilm: FilmConditionConfig {
        return FilmConditionConfig(
            enabled: true,
            age: .new,
            cameraType: .consumer,
            stockType: .instant,
            dustMultiplierOverride: 0.5,
            scratchMultiplierOverride: 0.3
        )
    }
}

// MARK: - FilterPreset Extension

extension FilterPreset {

    /// Apply film condition to this preset, returning modified configs
    func applyingFilmCondition(_ condition: FilmConditionConfig, seed: UInt32 = 0) -> (
        grain: GrainConfig,
        overlays: OverlaysConfig,
        lightLeak: LightLeakConfig,
        vignette: VignetteConfig,
        halation: HalationConfig
    ) {
        return (
            grain: condition.generateGrainConfig(),
            overlays: condition.generateOverlaysConfig(seed: seed),
            lightLeak: condition.generateLightLeakConfig(seed: seed),
            vignette: condition.generateVignetteConfig(),
            halation: condition.generateHalationConfig()
        )
    }
}

// MARK: - FilmStock Extension

extension FilmStock {

    /// Infer FilmStockType from this FilmStock
    var inferredStockType: FilmStockType {
        let typeLower = type.lowercased()

        if typeLower.contains("slide") || typeLower.contains("e-6") || typeLower.contains("reversal") {
            return .colorSlide
        } else if typeLower.contains("b&w") || typeLower.contains("black") || typeLower.contains("bw") {
            return .bwNegative
        } else if typeLower.contains("cinema") || typeLower.contains("ecn") {
            if typeLower.contains("modified") || name.lowercased().contains("cinestill") {
                return .cinemaModified
            }
            return .cinema
        } else if typeLower.contains("instant") || typeLower.contains("polaroid") || typeLower.contains("instax") {
            return .instant
        }

        return .colorNegative
    }

    /// Create default FilmConditionConfig based on this FilmStock
    func defaultCondition() -> FilmConditionConfig {
        return FilmConditionConfig(
            enabled: true,
            age: .new,
            cameraType: .prosumer,
            stockType: inferredStockType
        )
    }
}
