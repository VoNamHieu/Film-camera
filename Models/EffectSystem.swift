//
//  EffectSystem.swift
//  Film Camera
//
//  Effect System Architecture - Performance-aware effect management
//  Integrates with existing FilterPreset system
//

import Foundation
import SwiftUI

// MARK: - Effect Performance

/// GPU performance weight for each effect type
enum EffectPerformance: Float, Codable {
    case low = 0.1      // Simple operations (toggle, basic color)
    case medium = 0.3   // Moderate GPU (vignette, basic grain)
    case high = 0.6     // Heavy GPU (bloom, halation, complex grain)

    var weight: Float { rawValue }

    var description: String {
        switch self {
        case .low: return "Low Impact"
        case .medium: return "Medium Impact"
        case .high: return "High Impact"
        }
    }
}

// MARK: - Effect Value

/// Represents the value type for an effect parameter
enum EffectValue: Codable, Equatable {
    case toggle(enabled: Bool)
    case slider(value: Float, min: Float, max: Float)
    case compound(values: [String: Float])  // For multi-parameter effects

    // MARK: - Convenience Accessors

    /// Whether this effect is active/enabled
    var isActive: Bool {
        switch self {
        case .toggle(let enabled): return enabled
        case .slider(let value, _, _): return value > 0
        case .compound(let values): return values["enabled"] == 1.0 || (values["intensity"] ?? 0) > 0
        }
    }

    /// Alias for isActive (backward compatibility)
    var isEnabled: Bool { isActive }

    /// Intensity value (0.0 - 1.0)
    var intensity: Float {
        switch self {
        case .toggle(let enabled): return enabled ? 1.0 : 0.0
        case .slider(let value, let min, let max):
            guard max > min else { return 0 }
            return (value - min) / (max - min)
        case .compound(let values):
            return values["intensity"] ?? values["value"] ?? 0
        }
    }

    var floatValue: Float {
        switch self {
        case .toggle(let enabled): return enabled ? 1.0 : 0.0
        case .slider(let value, _, _): return value
        case .compound(let values): return values["intensity"] ?? values["value"] ?? 0
        }
    }

    var normalizedValue: Float { intensity }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case type, enabled, value, min, max, values
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "toggle":
            let enabled = try container.decode(Bool.self, forKey: .enabled)
            self = .toggle(enabled: enabled)
        case "slider":
            let value = try container.decode(Float.self, forKey: .value)
            let min = try container.decode(Float.self, forKey: .min)
            let max = try container.decode(Float.self, forKey: .max)
            self = .slider(value: value, min: min, max: max)
        case "compound":
            let values = try container.decode([String: Float].self, forKey: .values)
            self = .compound(values: values)
        default:
            self = .toggle(enabled: false)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .toggle(let enabled):
            try container.encode("toggle", forKey: .type)
            try container.encode(enabled, forKey: .enabled)
        case .slider(let value, let min, let max):
            try container.encode("slider", forKey: .type)
            try container.encode(value, forKey: .value)
            try container.encode(min, forKey: .min)
            try container.encode(max, forKey: .max)
        case .compound(let values):
            try container.encode("compound", forKey: .type)
            try container.encode(values, forKey: .values)
        }
    }
}

// MARK: - Effect Type

/// All available effect types with metadata
enum EffectType: String, CaseIterable, Codable {
    // Color Effects
    case exposure
    case contrast
    case saturation
    case vibrance
    case temperature
    case tint
    case highlights
    case shadows
    case whites
    case blacks
    case fade
    case clarity

    // Tone Effects
    case splitTone
    case rgbCurves
    case selectiveColor

    // Film Effects
    case grain
    case bloom
    case vignette
    case halation
    case lensDistortion

    // Disposable/Flash Effects
    case flash
    case lightLeak
    case dateStamp
    case ccdBloom

    // Special Effects
    case instantFrame
    case skinToneProtection
    case toneMapping

    // MARK: - Metadata

    var displayName: String {
        switch self {
        case .exposure: return "Exposure"
        case .contrast: return "Contrast"
        case .saturation: return "Saturation"
        case .vibrance: return "Vibrance"
        case .temperature: return "Temperature"
        case .tint: return "Tint"
        case .highlights: return "Highlights"
        case .shadows: return "Shadows"
        case .whites: return "Whites"
        case .blacks: return "Blacks"
        case .fade: return "Fade"
        case .clarity: return "Clarity"
        case .splitTone: return "Split Tone"
        case .rgbCurves: return "RGB Curves"
        case .selectiveColor: return "Selective Color"
        case .grain: return "Film Grain"
        case .bloom: return "Bloom"
        case .vignette: return "Vignette"
        case .halation: return "Halation"
        case .lensDistortion: return "Lens Distortion"
        case .flash: return "Flash"
        case .lightLeak: return "Light Leak"
        case .dateStamp: return "Date Stamp"
        case .ccdBloom: return "CCD Bloom"
        case .instantFrame: return "Instant Frame"
        case .skinToneProtection: return "Skin Tone Protection"
        case .toneMapping: return "Tone Mapping"
        }
    }

    var icon: String {
        switch self {
        case .exposure: return "sun.max"
        case .contrast: return "circle.lefthalf.filled"
        case .saturation: return "drop.fill"
        case .vibrance: return "sparkles"
        case .temperature: return "thermometer"
        case .tint: return "paintpalette"
        case .highlights: return "sun.max.fill"
        case .shadows: return "moon.fill"
        case .whites: return "circle.fill"
        case .blacks: return "circle"
        case .fade: return "aqi.medium"
        case .clarity: return "camera.filters"
        case .splitTone: return "circle.grid.2x2"
        case .rgbCurves: return "chart.xyaxis.line"
        case .selectiveColor: return "eyedropper"
        case .grain: return "circle.hexagongrid"
        case .bloom: return "light.max"
        case .vignette: return "viewfinder"
        case .halation: return "light.beacon.max"
        case .lensDistortion: return "camera.aperture"
        case .flash: return "bolt.fill"
        case .lightLeak: return "sun.haze.fill"
        case .dateStamp: return "calendar.badge.clock"
        case .ccdBloom: return "sparkle"
        case .instantFrame: return "photo.on.rectangle"
        case .skinToneProtection: return "face.smiling"
        case .toneMapping: return "slider.horizontal.3"
        }
    }

    var performance: EffectPerformance {
        switch self {
        // Low impact - simple color operations
        case .exposure, .contrast, .saturation, .vibrance,
             .temperature, .tint, .highlights, .shadows,
             .whites, .blacks, .fade, .dateStamp:
            return .low

        // Medium impact - moderate GPU usage
        case .clarity, .vignette, .splitTone, .lensDistortion,
             .skinToneProtection, .toneMapping, .flash, .lightLeak:
            return .medium

        // High impact - heavy GPU operations
        case .grain, .bloom, .halation, .rgbCurves,
             .selectiveColor, .instantFrame, .ccdBloom:
            return .high
        }
    }

    var defaultValue: EffectValue {
        switch self {
        // Simple sliders
        case .exposure, .contrast, .highlights, .shadows,
             .whites, .blacks, .fade, .clarity, .tint:
            return .slider(value: 0, min: -1.0, max: 1.0)

        case .saturation, .vibrance:
            return .slider(value: 0, min: -1.0, max: 1.0)

        case .temperature:
            return .slider(value: 0, min: -1.0, max: 1.0)

        // Toggle effects
        case .skinToneProtection, .toneMapping, .lensDistortion:
            return .toggle(enabled: false)

        // Compound effects
        case .grain:
            return .compound(values: [
                "enabled": 1.0,
                "intensity": 0.15,
                "size": 1.0,
                "softness": 0.5
            ])

        case .bloom:
            return .compound(values: [
                "enabled": 1.0,
                "intensity": 0.05,
                "threshold": 0.75,
                "radius": 12.0
            ])

        case .vignette:
            return .compound(values: [
                "enabled": 1.0,
                "intensity": 0.15,
                "roundness": 0.8,
                "feather": 0.6
            ])

        case .halation:
            return .compound(values: [
                "enabled": 0.0,
                "intensity": 0.4,
                "threshold": 0.65,
                "radius": 28.0
            ])

        case .splitTone:
            return .compound(values: [
                "shadowsHue": 0,
                "shadowsSat": 0,
                "highlightsHue": 0,
                "highlightsSat": 0,
                "balance": 0.5
            ])

        case .rgbCurves, .selectiveColor:
            return .toggle(enabled: false)

        case .instantFrame:
            return .toggle(enabled: false)

        // New disposable camera effects
        case .flash:
            return .compound(values: [
                "enabled": 0.0,
                "intensity": 0.6,
                "falloff": 0.6,
                "warmth": 0.1,
                "shadowLift": 0.2
            ])

        case .lightLeak:
            return .compound(values: [
                "enabled": 0.0,
                "intensity": 0.3,
                "positionX": 0.8,
                "positionY": 0.2,
                "size": 0.4
            ])

        case .dateStamp:
            return .toggle(enabled: false)

        case .ccdBloom:
            return .compound(values: [
                "enabled": 0.0,
                "intensity": 0.2,
                "threshold": 0.7,
                "spread": 0.5
            ])
        }
    }

    /// Whether this effect supports intensity adjustment
    var hasIntensity: Bool {
        switch self {
        case .grain, .bloom, .vignette, .halation, .flash, .lightLeak, .ccdBloom:
            return true
        default:
            return false
        }
    }

    /// Group this effect belongs to (for UI organization)
    var group: EffectGroup {
        switch self {
        case .exposure, .contrast, .saturation, .vibrance,
             .temperature, .tint, .highlights, .shadows,
             .whites, .blacks, .fade, .clarity:
            return .color
        case .splitTone, .rgbCurves, .selectiveColor:
            return .tone
        case .grain, .bloom, .vignette, .halation, .lensDistortion:
            return .film
        case .flash, .lightLeak, .dateStamp, .ccdBloom:
            return .disposable
        case .instantFrame, .skinToneProtection, .toneMapping:
            return .special
        }
    }
}

// MARK: - Effect Group

enum EffectGroup: String, CaseIterable {
    case color = "Color"
    case tone = "Tone"
    case film = "Film"
    case disposable = "Disposable"
    case special = "Special"

    var effects: [EffectType] {
        EffectType.allCases.filter { $0.group == self }
    }
}

// MARK: - Camera Category (Extended)

/// Camera categories - matches existing FilterCategory for compatibility
enum CameraCategory: String, CaseIterable, Codable {
    case professional
    case slide
    case consumer
    case cinema
    case blackAndWhite
    case instant
    case disposable
    case food
    case night
    case creative

    var displayName: String {
        switch self {
        case .professional: return "Professional Film"
        case .slide: return "Slide Film"
        case .consumer: return "Consumer Film"
        case .cinema: return "Cinema Film"
        case .blackAndWhite: return "Black & White"
        case .instant: return "Instant Film"
        case .disposable: return "Disposable Camera"
        case .food: return "Food & Lifestyle"
        case .night: return "Night & Neon"
        case .creative: return "Creative"
        }
    }

    var icon: String {
        switch self {
        case .professional: return "camera.fill"
        case .slide: return "film"
        case .consumer: return "camera"
        case .cinema: return "film.stack"
        case .blackAndWhite: return "circle.lefthalf.filled"
        case .instant: return "photo.on.rectangle"
        case .disposable: return "camera.viewfinder"
        case .food: return "fork.knife"
        case .night: return "moon.stars.fill"
        case .creative: return "paintbrush.fill"
        }
    }

    /// Convert from existing FilterCategory
    init(from filterCategory: FilterCategory) {
        switch filterCategory {
        case .professional: self = .professional
        case .slide: self = .slide
        case .consumer: self = .consumer
        case .cinema: self = .cinema
        case .blackAndWhite: self = .blackAndWhite
        case .instant: self = .instant
        case .disposable: self = .disposable
        case .food: self = .food
        case .night: self = .night
        case .creative: self = .creative
        }
    }

    /// Convert to existing FilterCategory
    var filterCategory: FilterCategory {
        switch self {
        case .professional: return .professional
        case .slide: return .slide
        case .consumer: return .consumer
        case .cinema: return .cinema
        case .blackAndWhite: return .blackAndWhite
        case .instant: return .instant
        case .disposable: return .disposable
        case .food: return .food
        case .night: return .night
        case .creative: return .creative
        }
    }
}

// MARK: - Effect Definition

/// Defines default effects for a category
struct EffectDefinition: Codable {
    let category: CameraCategory
    var effects: [EffectType: EffectValue]

    init(category: CameraCategory, effects: [EffectType: EffectValue] = [:]) {
        self.category = category
        self.effects = effects
    }

    /// Get effect value or default
    func value(for effect: EffectType) -> EffectValue {
        effects[effect] ?? effect.defaultValue
    }

    /// Calculate total performance score
    var performanceScore: Float {
        effects.reduce(0) { total, pair in
            let (effectType, value) = pair
            guard value.isEnabled else { return total }
            return total + effectType.performance.weight
        }
    }

    /// Create from existing FilterPreset
    static func from(preset: FilterPreset) -> EffectDefinition {
        var effects: [EffectType: EffectValue] = [:]

        // Color Adjustments
        let ca = preset.colorAdjustments
        if ca.exposure != 0 { effects[.exposure] = .slider(value: ca.exposure, min: -1, max: 1) }
        if ca.contrast != 0 { effects[.contrast] = .slider(value: ca.contrast, min: -1, max: 1) }
        if ca.saturation != 0 { effects[.saturation] = .slider(value: ca.saturation, min: -1, max: 1) }
        if ca.vibrance != 0 { effects[.vibrance] = .slider(value: ca.vibrance, min: -1, max: 1) }
        if ca.temperature != 0 { effects[.temperature] = .slider(value: ca.temperature, min: -1, max: 1) }
        if ca.tint != 0 { effects[.tint] = .slider(value: ca.tint, min: -1, max: 1) }
        if ca.highlights != 0 { effects[.highlights] = .slider(value: ca.highlights, min: -1, max: 1) }
        if ca.shadows != 0 { effects[.shadows] = .slider(value: ca.shadows, min: -1, max: 1) }
        if ca.whites != 0 { effects[.whites] = .slider(value: ca.whites, min: -1, max: 1) }
        if ca.blacks != 0 { effects[.blacks] = .slider(value: ca.blacks, min: -1, max: 1) }
        if ca.fade != 0 { effects[.fade] = .slider(value: ca.fade, min: -1, max: 1) }
        if ca.clarity != 0 { effects[.clarity] = .slider(value: ca.clarity, min: -1, max: 1) }

        // Grain
        if preset.grain.enabled {
            effects[.grain] = .compound(values: [
                "enabled": 1.0,
                "intensity": preset.grain.globalIntensity,
                "size": preset.grain.channels.green.size,
                "softness": preset.grain.channels.green.softness
            ])
        }

        // Bloom
        if preset.bloom.enabled {
            effects[.bloom] = .compound(values: [
                "enabled": 1.0,
                "intensity": preset.bloom.intensity,
                "threshold": preset.bloom.threshold,
                "radius": preset.bloom.radius
            ])
        }

        // Vignette
        if preset.vignette.enabled {
            effects[.vignette] = .compound(values: [
                "enabled": 1.0,
                "intensity": preset.vignette.intensity,
                "roundness": preset.vignette.roundness,
                "feather": preset.vignette.feather
            ])
        }

        // Halation
        if preset.halation.enabled {
            effects[.halation] = .compound(values: [
                "enabled": 1.0,
                "intensity": preset.halation.intensity,
                "threshold": preset.halation.threshold,
                "radius": preset.halation.radius
            ])
        }

        // Split Tone
        let st = preset.splitTone
        if st.shadowsSat > 0 || st.highlightsSat > 0 {
            effects[.splitTone] = .compound(values: [
                "shadowsHue": st.shadowsHue,
                "shadowsSat": st.shadowsSat,
                "highlightsHue": st.highlightsHue,
                "highlightsSat": st.highlightsSat,
                "balance": st.balance
            ])
        }

        // Instant Frame
        if preset.instantFrame.enabled {
            effects[.instantFrame] = .toggle(enabled: true)
        }

        // Skin Tone Protection
        if preset.skinToneProtection.enabled {
            effects[.skinToneProtection] = .toggle(enabled: true)
        }

        // Tone Mapping
        if preset.toneMapping.enabled {
            effects[.toneMapping] = .toggle(enabled: true)
        }

        // Lens Distortion
        if preset.lensDistortion.enabled {
            effects[.lensDistortion] = .toggle(enabled: true)
        }

        // Flash
        if preset.flash.enabled {
            effects[.flash] = .compound(values: [
                "enabled": 1.0,
                "intensity": preset.flash.intensity,
                "falloff": preset.flash.falloff,
                "warmth": preset.flash.warmth,
                "shadowLift": preset.flash.shadowLift
            ])
        }

        // Light Leak
        if preset.lightLeak.enabled {
            effects[.lightLeak] = .compound(values: [
                "enabled": 1.0,
                "intensity": preset.lightLeak.opacity,
                "size": preset.lightLeak.size,
                "warmth": preset.lightLeak.warmth,
                "saturation": preset.lightLeak.saturation
            ])
        }

        return EffectDefinition(
            category: CameraCategory(from: preset.category),
            effects: effects
        )
    }
}

// MARK: - Performance Level

/// Overall performance level based on active effects
enum PerformanceLevel: String, Codable {
    case fast       // < 0.3 total weight
    case normal     // 0.3 - 0.8
    case heavy      // > 0.8

    var displayName: String {
        switch self {
        case .fast: return "Fast"
        case .normal: return "Normal"
        case .heavy: return "Heavy"
        }
    }

    var icon: String {
        switch self {
        case .fast: return "hare.fill"
        case .normal: return "figure.walk"
        case .heavy: return "tortoise.fill"
        }
    }

    var color: Color {
        switch self {
        case .fast: return .green
        case .normal: return .yellow
        case .heavy: return .red
        }
    }

    static func from(score: Float) -> PerformanceLevel {
        if score < 0.3 { return .fast }
        if score < 0.8 { return .normal }
        return .heavy
    }
}

// MARK: - Effect State Manager

/// Manages effect states and integrates with FilterPreset
@MainActor
final class EffectStateManager: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var currentPreset: FilterPreset?
    @Published private(set) var effectDefinition: EffectDefinition?
    @Published private(set) var performanceLevel: PerformanceLevel = .normal
    @Published var effectOverrides: [EffectType: EffectValue] = [:]

    // MARK: - Computed Properties

    /// Current performance score
    var performanceScore: Float {
        var score: Float = 0

        // Base preset effects
        if let definition = effectDefinition {
            score += definition.performanceScore
        }

        // Add overrides
        for (effectType, value) in effectOverrides {
            if value.isEnabled {
                score += effectType.performance.weight
            }
        }

        return score
    }

    /// Get effective value for an effect (override or preset default)
    func effectiveValue(for effect: EffectType) -> EffectValue {
        if let override = effectOverrides[effect] {
            return override
        }
        return effectDefinition?.value(for: effect) ?? effect.defaultValue
    }

    /// Check if effect is enabled
    func isEffectEnabled(_ effect: EffectType) -> Bool {
        effectiveValue(for: effect).isEnabled
    }

    /// Get intensity for an effect (0-1 normalized)
    func effectIntensity(for effect: EffectType) -> Float {
        effectiveValue(for: effect).normalizedValue
    }

    // MARK: - Actions

    /// Load a preset and create effect definition
    func loadPreset(_ preset: FilterPreset) {
        currentPreset = preset
        effectDefinition = EffectDefinition.from(preset: preset)
        effectOverrides.removeAll()
        updatePerformanceLevel()

        print("📊 EffectStateManager: Loaded preset '\(preset.label)' with performance: \(performanceLevel.displayName)")
    }

    /// Set an effect override
    func setEffect(_ effect: EffectType, value: EffectValue) {
        effectOverrides[effect] = value
        updatePerformanceLevel()
    }

    /// Toggle an effect on/off
    func toggleEffect(_ effect: EffectType) {
        let current = effectiveValue(for: effect)

        switch current {
        case .toggle(let enabled):
            effectOverrides[effect] = .toggle(enabled: !enabled)
        case .slider(let value, let min, let max):
            effectOverrides[effect] = .slider(value: value > 0 ? 0 : max * 0.5, min: min, max: max)
        case .compound(var values):
            let wasEnabled = values["enabled"] == 1.0 || (values["intensity"] ?? 0) > 0
            if wasEnabled {
                values["enabled"] = 0
                values["intensity"] = 0
            } else {
                values["enabled"] = 1.0
                values["intensity"] = 0.15
            }
            effectOverrides[effect] = .compound(values: values)
        }

        updatePerformanceLevel()
    }

    /// Set intensity for a compound effect
    func setEffectIntensity(_ effect: EffectType, intensity: Float) {
        var current = effectiveValue(for: effect)

        switch current {
        case .slider(_, let min, let max):
            effectOverrides[effect] = .slider(value: intensity, min: min, max: max)
        case .compound(var values):
            values["intensity"] = intensity
            if intensity > 0 {
                values["enabled"] = 1.0
            }
            effectOverrides[effect] = .compound(values: values)
        default:
            break
        }

        updatePerformanceLevel()
    }

    /// Reset all overrides
    func resetOverrides() {
        effectOverrides.removeAll()
        updatePerformanceLevel()
    }

    /// Apply overrides back to create a modified FilterPreset
    func applyToPreset() -> FilterPreset? {
        guard var preset = currentPreset else { return nil }

        // Apply color adjustment overrides
        for (effect, value) in effectOverrides {
            switch effect {
            case .exposure:
                preset.colorAdjustments.exposure = value.floatValue
            case .contrast:
                preset.colorAdjustments.contrast = value.floatValue
            case .saturation:
                preset.colorAdjustments.saturation = value.floatValue
            case .vibrance:
                preset.colorAdjustments.vibrance = value.floatValue
            case .temperature:
                preset.colorAdjustments.temperature = value.floatValue
            case .tint:
                preset.colorAdjustments.tint = value.floatValue
            case .highlights:
                preset.colorAdjustments.highlights = value.floatValue
            case .shadows:
                preset.colorAdjustments.shadows = value.floatValue
            case .whites:
                preset.colorAdjustments.whites = value.floatValue
            case .blacks:
                preset.colorAdjustments.blacks = value.floatValue
            case .fade:
                preset.colorAdjustments.fade = value.floatValue
            case .clarity:
                preset.colorAdjustments.clarity = value.floatValue

            case .grain:
                if case .compound(let values) = value {
                    preset.grain.enabled = values["enabled"] == 1.0
                    preset.grain.globalIntensity = values["intensity"] ?? 0.15
                }

            case .bloom:
                if case .compound(let values) = value {
                    preset.bloom.enabled = values["enabled"] == 1.0
                    preset.bloom.intensity = values["intensity"] ?? 0.05
                    preset.bloom.threshold = values["threshold"] ?? 0.75
                    preset.bloom.radius = values["radius"] ?? 12
                }

            case .vignette:
                if case .compound(let values) = value {
                    preset.vignette.enabled = values["enabled"] == 1.0
                    preset.vignette.intensity = values["intensity"] ?? 0.15
                    preset.vignette.roundness = values["roundness"] ?? 0.8
                    preset.vignette.feather = values["feather"] ?? 0.6
                }

            case .halation:
                if case .compound(let values) = value {
                    preset.halation.enabled = values["enabled"] == 1.0
                    preset.halation.intensity = values["intensity"] ?? 0.4
                    preset.halation.threshold = values["threshold"] ?? 0.65
                    preset.halation.radius = values["radius"] ?? 28
                }

            case .instantFrame:
                preset.instantFrame.enabled = value.isEnabled

            case .skinToneProtection:
                preset.skinToneProtection.enabled = value.isEnabled

            case .toneMapping:
                preset.toneMapping.enabled = value.isEnabled

            case .lensDistortion:
                preset.lensDistortion.enabled = value.isEnabled

            case .flash:
                if case .compound(let values) = value {
                    preset.flash.enabled = values["enabled"] == 1.0
                    preset.flash.intensity = values["intensity"] ?? 0.6
                    preset.flash.falloff = values["falloff"] ?? 2.0
                    preset.flash.warmth = values["warmth"] ?? 0.08
                    preset.flash.shadowLift = values["shadowLift"] ?? 0.15
                }

            case .lightLeak:
                if case .compound(let values) = value {
                    preset.lightLeak.enabled = values["enabled"] == 1.0
                    preset.lightLeak.opacity = values["intensity"] ?? 0.4
                    preset.lightLeak.size = values["size"] ?? 0.5
                    preset.lightLeak.warmth = values["warmth"] ?? 0.5
                    preset.lightLeak.saturation = values["saturation"] ?? 1.0
                }

            default:
                break
            }
        }

        return preset
    }

    // MARK: - Convenience Getters

    /// Number of active effects
    var activeCount: Int {
        var count = 0
        for effectType in EffectType.allCases {
            if isEffectEnabled(effectType) {
                count += 1
            }
        }
        return count
    }

    /// Quick accessors for common effects
    var grainIntensity: Float { effectIntensity(for: .grain) }
    var grainEnabled: Bool { isEffectEnabled(.grain) }

    var bloomIntensity: Float { effectIntensity(for: .bloom) }
    var bloomEnabled: Bool { isEffectEnabled(.bloom) }

    var vignetteIntensity: Float { effectIntensity(for: .vignette) }
    var vignetteEnabled: Bool { isEffectEnabled(.vignette) }

    var halationIntensity: Float { effectIntensity(for: .halation) }
    var halationEnabled: Bool { isEffectEnabled(.halation) }

    var flashIntensity: Float { effectIntensity(for: .flash) }
    var flashEnabled: Bool { isEffectEnabled(.flash) }

    var lightLeakIntensity: Float { effectIntensity(for: .lightLeak) }
    var lightLeakEnabled: Bool { isEffectEnabled(.lightLeak) }

    var dateStampEnabled: Bool { isEffectEnabled(.dateStamp) }

    var ccdBloomIntensity: Float { effectIntensity(for: .ccdBloom) }
    var ccdBloomEnabled: Bool { isEffectEnabled(.ccdBloom) }

    var instantFrameEnabled: Bool { isEffectEnabled(.instantFrame) }

    // MARK: - Persistence

    private static let userDefaultsKey = "EffectStateManager.overrides"

    /// Save current overrides to UserDefaults
    func saveOverrides() {
        guard let presetId = currentPreset?.id else { return }
        let key = "\(Self.userDefaultsKey).\(presetId)"

        // Convert to storable format
        var storable: [String: Data] = [:]
        for (effectType, value) in effectOverrides {
            if let encoded = try? JSONEncoder().encode(value) {
                storable[effectType.rawValue] = encoded
            }
        }

        UserDefaults.standard.set(try? JSONEncoder().encode(storable), forKey: key)
        print("💾 EffectStateManager: Saved \(effectOverrides.count) overrides for preset '\(currentPreset?.label ?? "unknown")'")
    }

    /// Load saved overrides for current preset
    func loadSavedOverrides() {
        guard let presetId = currentPreset?.id else { return }
        let key = "\(Self.userDefaultsKey).\(presetId)"

        guard let data = UserDefaults.standard.data(forKey: key),
              let storable = try? JSONDecoder().decode([String: Data].self, from: data) else {
            return
        }

        for (rawValue, valueData) in storable {
            if let effectType = EffectType(rawValue: rawValue),
               let value = try? JSONDecoder().decode(EffectValue.self, from: valueData) {
                effectOverrides[effectType] = value
            }
        }

        updatePerformanceLevel()
        print("📂 EffectStateManager: Loaded \(effectOverrides.count) saved overrides for preset '\(currentPreset?.label ?? "unknown")'")
    }

    /// Clear saved overrides for current preset
    func clearSavedOverrides() {
        guard let presetId = currentPreset?.id else { return }
        let key = "\(Self.userDefaultsKey).\(presetId)"
        UserDefaults.standard.removeObject(forKey: key)
    }

    // MARK: - Private Methods

    private func updatePerformanceLevel() {
        let score = performanceScore
        let newLevel = PerformanceLevel.from(score: score)

        if newLevel != performanceLevel {
            performanceLevel = newLevel
            print("📊 EffectStateManager: Performance level changed to \(newLevel.displayName) (score: \(String(format: "%.2f", score)))")
        }
    }
}

// MARK: - Effect Category Defaults

extension CameraCategory {

    /// Default effects for this category
    var defaultEffects: [EffectType: EffectValue] {
        switch self {
        case .professional:
            return [
                .grain: .compound(values: ["enabled": 1.0, "intensity": 0.12, "size": 1.0, "softness": 0.6]),
                .bloom: .compound(values: ["enabled": 1.0, "intensity": 0.04, "threshold": 0.8, "radius": 10]),
                .vignette: .compound(values: ["enabled": 1.0, "intensity": 0.10, "roundness": 0.8, "feather": 0.6])
            ]

        case .consumer:
            return [
                .grain: .compound(values: ["enabled": 1.0, "intensity": 0.20, "size": 1.15, "softness": 0.5]),
                .bloom: .compound(values: ["enabled": 1.0, "intensity": 0.05, "threshold": 0.78, "radius": 12]),
                .vignette: .compound(values: ["enabled": 1.0, "intensity": 0.12, "roundness": 0.85, "feather": 0.55])
            ]

        case .slide:
            return [
                .grain: .compound(values: ["enabled": 1.0, "intensity": 0.08, "size": 0.95, "softness": 0.65]),
                .bloom: .compound(values: ["enabled": 1.0, "intensity": 0.03, "threshold": 0.82, "radius": 8]),
                .vignette: .compound(values: ["enabled": 1.0, "intensity": 0.08, "roundness": 0.9, "feather": 0.62])
            ]

        case .cinema:
            return [
                .grain: .compound(values: ["enabled": 1.0, "intensity": 0.08, "size": 1.0, "softness": 0.6]),
                .bloom: .compound(values: ["enabled": 1.0, "intensity": 0.025, "threshold": 0.82, "radius": 8]),
                .vignette: .compound(values: ["enabled": 1.0, "intensity": 0.06, "roundness": 0.9, "feather": 0.7])
            ]

        case .blackAndWhite:
            return [
                .grain: .compound(values: ["enabled": 1.0, "intensity": 0.25, "size": 1.2, "softness": 0.48]),
                .bloom: .compound(values: ["enabled": 1.0, "intensity": 0.06, "threshold": 0.8, "radius": 8]),
                .vignette: .compound(values: ["enabled": 1.0, "intensity": 0.15, "roundness": 0.82, "feather": 0.58])
            ]

        case .instant:
            return [
                .grain: .compound(values: ["enabled": 1.0, "intensity": 0.08, "size": 1.0, "softness": 0.7]),
                .bloom: .compound(values: ["enabled": 1.0, "intensity": 0.15, "threshold": 0.6, "radius": 20]),
                .vignette: .compound(values: ["enabled": 1.0, "intensity": 0.18, "roundness": 0.75, "feather": 0.7]),
                .instantFrame: .toggle(enabled: true)
            ]

        case .disposable:
            return [
                .grain: .compound(values: ["enabled": 1.0, "intensity": 0.22, "size": 1.18, "softness": 0.5]),
                .vignette: .compound(values: ["enabled": 1.0, "intensity": 0.26, "roundness": 0.68, "feather": 0.55])
            ]

        case .food:
            return [
                .bloom: .compound(values: ["enabled": 1.0, "intensity": 0.08, "threshold": 0.7, "radius": 12]),
                .vignette: .compound(values: ["enabled": 1.0, "intensity": 0.10, "roundness": 0.9, "feather": 0.8]),
                .skinToneProtection: .toggle(enabled: true)
            ]

        case .night:
            return [
                .grain: .compound(values: ["enabled": 1.0, "intensity": 0.18, "size": 1.18, "softness": 0.52]),
                .bloom: .compound(values: ["enabled": 1.0, "intensity": 0.15, "threshold": 0.6, "radius": 20]),
                .halation: .compound(values: ["enabled": 1.0, "intensity": 0.4, "threshold": 0.65, "radius": 28]),
                .vignette: .compound(values: ["enabled": 1.0, "intensity": 0.15, "roundness": 0.8, "feather": 0.7])
            ]

        case .creative:
            return [
                .grain: .compound(values: ["enabled": 1.0, "intensity": 0.14, "size": 1.08, "softness": 0.55]),
                .bloom: .compound(values: ["enabled": 1.0, "intensity": 0.06, "threshold": 0.75, "radius": 14]),
                .vignette: .compound(values: ["enabled": 1.0, "intensity": 0.12, "roundness": 0.78, "feather": 0.62])
            ]
        }
    }
}
