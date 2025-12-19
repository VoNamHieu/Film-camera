// FilterPreset+RGBCurves.swift
// Film Camera - FilterPreset extension for RGB Curves
// Add RGB Curves to existing filter presets
//
// ★ Uses FilmCurvesConfig (Swift) instead of RGBCurvesParams (Metal)

import Foundation

// MARK: - FilterPreset Extension

extension FilterPreset {
    
    /// Get RGB curves configuration for this preset
    var rgbCurves: FilmCurvesConfig {
        // Match preset to appropriate curves
        switch id {
        // Professional Film
        case let id where id.contains("portra"):
            return .kodakPortra
        case let id where id.contains("pro400h") || id.contains("fuji_pro"):
            return .fujiPro400H
        case let id where id.contains("ektar"):
            return .kodakEktar
            
        // Cinema
        case let id where id.contains("cinestill") || id.contains("800t"):
            return .cinestill800T
            
        // B&W
        case let id where id.contains("hp5") || id.contains("trix") || id.contains("bw"):
            return .ilfordHP5
            
        // Instant
        case let id where id.contains("polaroid") || id.contains("instax"):
            return .polaroid600
            
        // Disposable
        case let id where id.contains("disposable") || id.contains("fujifilm_simple"):
            return .disposable
            
        // Default: subtle curves
        default:
            return defaultCurvesForCategory()
        }
    }
    
    /// Get default curves based on category
    private func defaultCurvesForCategory() -> FilmCurvesConfig {
        switch category {
        case .professional:
            return FilmCurvesConfig(
                redCurve: [
                    FilmCurvePoint(input: 0.0, output: 0.02),
                    FilmCurvePoint(input: 0.5, output: 0.51),
                    FilmCurvePoint(input: 1.0, output: 0.98)
                ],
                greenCurve: [
                    FilmCurvePoint(input: 0.0, output: 0.01),
                    FilmCurvePoint(input: 0.5, output: 0.50),
                    FilmCurvePoint(input: 1.0, output: 0.99)
                ],
                blueCurve: [
                    FilmCurvePoint(input: 0.0, output: 0.03),
                    FilmCurvePoint(input: 0.5, output: 0.51),
                    FilmCurvePoint(input: 1.0, output: 0.97)
                ],
                enabled: true
            )
            
        case .consumer:
            return FilmCurvesConfig(
                redCurve: FilmCurvesConfig.sContrastCurve(strength: 0.1),
                greenCurve: FilmCurvesConfig.sContrastCurve(strength: 0.08),
                blueCurve: FilmCurvesConfig.sContrastCurve(strength: 0.12),
                enabled: true
            )
            
        case .slide:
            // High contrast for slide film
            return FilmCurvesConfig(
                redCurve: FilmCurvesConfig.sContrastCurve(strength: 0.25),
                greenCurve: FilmCurvesConfig.sContrastCurve(strength: 0.25),
                blueCurve: FilmCurvesConfig.sContrastCurve(strength: 0.25),
                enabled: true
            )
            
        case .cinema:
            return .cinestill800T
            
        case .blackAndWhite:
            return .ilfordHP5
            
        case .instant:
            return .polaroid600
            
        case .disposable:
            return .disposable
            
        case .food:
            // Warm, appetizing curves
            return FilmCurvesConfig(
                redCurve: [
                    FilmCurvePoint(input: 0.0, output: 0.02),
                    FilmCurvePoint(input: 0.3, output: 0.34),
                    FilmCurvePoint(input: 0.6, output: 0.62),
                    FilmCurvePoint(input: 1.0, output: 0.98)
                ],
                greenCurve: [
                    FilmCurvePoint(input: 0.0, output: 0.01),
                    FilmCurvePoint(input: 0.5, output: 0.50),
                    FilmCurvePoint(input: 1.0, output: 0.99)
                ],
                blueCurve: [
                    FilmCurvePoint(input: 0.0, output: 0.0),
                    FilmCurvePoint(input: 0.5, output: 0.48),
                    FilmCurvePoint(input: 1.0, output: 0.96)
                ],
                enabled: true
            )
            
        case .night:
            // Cool shadows, warm highlights
            return FilmCurvesConfig(
                redCurve: [
                    FilmCurvePoint(input: 0.0, output: 0.0),
                    FilmCurvePoint(input: 0.3, output: 0.28),
                    FilmCurvePoint(input: 0.7, output: 0.74),
                    FilmCurvePoint(input: 1.0, output: 1.0)
                ],
                greenCurve: [
                    FilmCurvePoint(input: 0.0, output: 0.01),
                    FilmCurvePoint(input: 0.5, output: 0.49),
                    FilmCurvePoint(input: 1.0, output: 0.98)
                ],
                blueCurve: [
                    FilmCurvePoint(input: 0.0, output: 0.04),
                    FilmCurvePoint(input: 0.3, output: 0.34),
                    FilmCurvePoint(input: 0.7, output: 0.68),
                    FilmCurvePoint(input: 1.0, output: 0.94)
                ],
                enabled: true
            )
            
        case .creative:
            // Cross-process style
            return FilmCurvesConfig(
                redCurve: [
                    FilmCurvePoint(input: 0.0, output: 0.05),
                    FilmCurvePoint(input: 0.25, output: 0.22),
                    FilmCurvePoint(input: 0.5, output: 0.55),
                    FilmCurvePoint(input: 0.75, output: 0.78),
                    FilmCurvePoint(input: 1.0, output: 0.95)
                ],
                greenCurve: [
                    FilmCurvePoint(input: 0.0, output: 0.02),
                    FilmCurvePoint(input: 0.5, output: 0.52),
                    FilmCurvePoint(input: 1.0, output: 0.98)
                ],
                blueCurve: [
                    FilmCurvePoint(input: 0.0, output: 0.08),
                    FilmCurvePoint(input: 0.25, output: 0.30),
                    FilmCurvePoint(input: 0.5, output: 0.48),
                    FilmCurvePoint(input: 0.75, output: 0.70),
                    FilmCurvePoint(input: 1.0, output: 0.90)
                ],
                enabled: true
            )
        }
    }
}
