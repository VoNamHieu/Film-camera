// RGBCurves.swift
// Film Camera - RGB Curves Color Grading
// Swift integration for Metal RGB Curves shader
//
// ★ NOTE: Swift structs renamed to avoid conflict with C structs in ShaderTypes.h
// - FilmCurvePoint (Swift) → CurvePoint (Metal)
// - FilmCurvesConfig (Swift) → RGBCurvesParams (Metal)

import Foundation
import simd

// MARK: - Curve Point (Swift)

/// A single control point on an RGB curve
/// Named "FilmCurvePoint" to avoid conflict with Metal's "CurvePoint"
struct FilmCurvePoint: Codable, Equatable {
    var input: Float   // X-axis: input value (0.0 - 1.0)
    var output: Float  // Y-axis: output value (0.0 - 1.0)
    
    init(input: Float, output: Float) {
        self.input = max(0, min(1, input))
        self.output = max(0, min(1, output))
    }
    
    /// Identity point (no change)
    static func identity(at value: Float) -> FilmCurvePoint {
        return FilmCurvePoint(input: value, output: value)
    }
    
    /// Convert to Metal CurvePoint
    func toMetal() -> CurvePoint {
        return CurvePoint(input: input, output: output)
    }
}

// MARK: - RGB Curves Configuration (Swift)

/// Complete RGB curves configuration for color grading
/// Named "FilmCurvesConfig" to avoid conflict with Metal's "RGBCurvesParams"
struct FilmCurvesConfig: Codable, Equatable {
    var redCurve: [FilmCurvePoint]
    var greenCurve: [FilmCurvePoint]
    var blueCurve: [FilmCurvePoint]
    var enabled: Bool
    
    /// Default identity curves (no change)
    static var identity: FilmCurvesConfig {
        let defaultCurve = [
            FilmCurvePoint(input: 0.0, output: 0.0),
            FilmCurvePoint(input: 1.0, output: 1.0)
        ]
        return FilmCurvesConfig(
            redCurve: defaultCurve,
            greenCurve: defaultCurve,
            blueCurve: defaultCurve,
            enabled: false
        )
    }
    
    // MARK: - Film Stock Presets
    
    /// Kodak Portra 400 - Lifted shadows, compressed highlights
    static var kodakPortra: FilmCurvesConfig {
        return FilmCurvesConfig(
            redCurve: [
                FilmCurvePoint(input: 0.0, output: 0.03),  // Lifted blacks
                FilmCurvePoint(input: 0.25, output: 0.28),
                FilmCurvePoint(input: 0.5, output: 0.52),
                FilmCurvePoint(input: 0.75, output: 0.73),
                FilmCurvePoint(input: 1.0, output: 0.97)   // Soft highlights
            ],
            greenCurve: [
                FilmCurvePoint(input: 0.0, output: 0.02),
                FilmCurvePoint(input: 0.25, output: 0.26),
                FilmCurvePoint(input: 0.5, output: 0.50),
                FilmCurvePoint(input: 0.75, output: 0.74),
                FilmCurvePoint(input: 1.0, output: 0.98)
            ],
            blueCurve: [
                FilmCurvePoint(input: 0.0, output: 0.05),  // Blue lifted more
                FilmCurvePoint(input: 0.25, output: 0.30),
                FilmCurvePoint(input: 0.5, output: 0.52),
                FilmCurvePoint(input: 0.75, output: 0.72),
                FilmCurvePoint(input: 1.0, output: 0.95)
            ],
            enabled: true
        )
    }
    
    /// Fuji Pro 400H - Pastel tones, green shadows
    static var fujiPro400H: FilmCurvesConfig {
        return FilmCurvesConfig(
            redCurve: [
                FilmCurvePoint(input: 0.0, output: 0.02),
                FilmCurvePoint(input: 0.25, output: 0.24),
                FilmCurvePoint(input: 0.5, output: 0.48),
                FilmCurvePoint(input: 0.75, output: 0.76),
                FilmCurvePoint(input: 1.0, output: 0.98)
            ],
            greenCurve: [
                FilmCurvePoint(input: 0.0, output: 0.04),  // Green shadows
                FilmCurvePoint(input: 0.25, output: 0.28),
                FilmCurvePoint(input: 0.5, output: 0.52),
                FilmCurvePoint(input: 0.75, output: 0.74),
                FilmCurvePoint(input: 1.0, output: 0.97)
            ],
            blueCurve: [
                FilmCurvePoint(input: 0.0, output: 0.03),
                FilmCurvePoint(input: 0.25, output: 0.27),
                FilmCurvePoint(input: 0.5, output: 0.50),
                FilmCurvePoint(input: 0.75, output: 0.73),
                FilmCurvePoint(input: 1.0, output: 0.96)
            ],
            enabled: true
        )
    }
    
    /// CineStill 800T - Tungsten balanced, cinema look
    static var cinestill800T: FilmCurvesConfig {
        return FilmCurvesConfig(
            redCurve: [
                FilmCurvePoint(input: 0.0, output: 0.01),
                FilmCurvePoint(input: 0.2, output: 0.18),
                FilmCurvePoint(input: 0.5, output: 0.52),  // Slight red push in mids
                FilmCurvePoint(input: 0.8, output: 0.82),
                FilmCurvePoint(input: 1.0, output: 1.0)
            ],
            greenCurve: [
                FilmCurvePoint(input: 0.0, output: 0.0),
                FilmCurvePoint(input: 0.25, output: 0.24),
                FilmCurvePoint(input: 0.5, output: 0.48),
                FilmCurvePoint(input: 0.75, output: 0.76),
                FilmCurvePoint(input: 1.0, output: 1.0)
            ],
            blueCurve: [
                FilmCurvePoint(input: 0.0, output: 0.04),  // Blue shadows (tungsten)
                FilmCurvePoint(input: 0.25, output: 0.30),
                FilmCurvePoint(input: 0.5, output: 0.54),  // Teal mids
                FilmCurvePoint(input: 0.75, output: 0.74),
                FilmCurvePoint(input: 1.0, output: 0.96)
            ],
            enabled: true
        )
    }
    
    /// Kodak Ektar 100 - High contrast, vivid colors
    static var kodakEktar: FilmCurvesConfig {
        return FilmCurvesConfig(
            redCurve: [
                FilmCurvePoint(input: 0.0, output: 0.0),
                FilmCurvePoint(input: 0.2, output: 0.15),  // Deep shadows
                FilmCurvePoint(input: 0.5, output: 0.50),
                FilmCurvePoint(input: 0.8, output: 0.88),  // Bright highlights
                FilmCurvePoint(input: 1.0, output: 1.0)
            ],
            greenCurve: [
                FilmCurvePoint(input: 0.0, output: 0.0),
                FilmCurvePoint(input: 0.2, output: 0.16),
                FilmCurvePoint(input: 0.5, output: 0.50),
                FilmCurvePoint(input: 0.8, output: 0.86),
                FilmCurvePoint(input: 1.0, output: 1.0)
            ],
            blueCurve: [
                FilmCurvePoint(input: 0.0, output: 0.0),
                FilmCurvePoint(input: 0.2, output: 0.18),
                FilmCurvePoint(input: 0.5, output: 0.48),
                FilmCurvePoint(input: 0.8, output: 0.84),
                FilmCurvePoint(input: 1.0, output: 1.0)
            ],
            enabled: true
        )
    }
    
    /// Ilford HP5 - B&W with slight warm tone
    static var ilfordHP5: FilmCurvesConfig {
        // For B&W, all channels should be similar with slight variations
        let curve = [
            FilmCurvePoint(input: 0.0, output: 0.02),
            FilmCurvePoint(input: 0.15, output: 0.12),
            FilmCurvePoint(input: 0.5, output: 0.50),
            FilmCurvePoint(input: 0.85, output: 0.90),
            FilmCurvePoint(input: 1.0, output: 0.98)
        ]
        return FilmCurvesConfig(
            redCurve: curve,
            greenCurve: curve,
            blueCurve: curve,
            enabled: true
        )
    }
    
    /// Polaroid 600 - Faded, vintage look
    static var polaroid600: FilmCurvesConfig {
        return FilmCurvesConfig(
            redCurve: [
                FilmCurvePoint(input: 0.0, output: 0.06),  // Very lifted blacks
                FilmCurvePoint(input: 0.25, output: 0.30),
                FilmCurvePoint(input: 0.5, output: 0.54),
                FilmCurvePoint(input: 0.75, output: 0.72),
                FilmCurvePoint(input: 1.0, output: 0.92)   // Compressed whites
            ],
            greenCurve: [
                FilmCurvePoint(input: 0.0, output: 0.05),
                FilmCurvePoint(input: 0.25, output: 0.28),
                FilmCurvePoint(input: 0.5, output: 0.52),
                FilmCurvePoint(input: 0.75, output: 0.74),
                FilmCurvePoint(input: 1.0, output: 0.94)
            ],
            blueCurve: [
                FilmCurvePoint(input: 0.0, output: 0.08),  // Blue shadow lift
                FilmCurvePoint(input: 0.25, output: 0.32),
                FilmCurvePoint(input: 0.5, output: 0.50),
                FilmCurvePoint(input: 0.75, output: 0.70),
                FilmCurvePoint(input: 1.0, output: 0.90)
            ],
            enabled: true
        )
    }
    
    /// Disposable Camera - Cross-processed look
    static var disposable: FilmCurvesConfig {
        return FilmCurvesConfig(
            redCurve: [
                FilmCurvePoint(input: 0.0, output: 0.0),
                FilmCurvePoint(input: 0.25, output: 0.22),
                FilmCurvePoint(input: 0.5, output: 0.55),  // Red push
                FilmCurvePoint(input: 0.75, output: 0.80),
                FilmCurvePoint(input: 1.0, output: 1.0)
            ],
            greenCurve: [
                FilmCurvePoint(input: 0.0, output: 0.02),
                FilmCurvePoint(input: 0.25, output: 0.28),
                FilmCurvePoint(input: 0.5, output: 0.52),
                FilmCurvePoint(input: 0.75, output: 0.74),
                FilmCurvePoint(input: 1.0, output: 0.96)
            ],
            blueCurve: [
                FilmCurvePoint(input: 0.0, output: 0.04),
                FilmCurvePoint(input: 0.25, output: 0.26),
                FilmCurvePoint(input: 0.5, output: 0.46),  // Blue suppressed
                FilmCurvePoint(input: 0.75, output: 0.72),
                FilmCurvePoint(input: 1.0, output: 0.94)
            ],
            enabled: true
        )
    }
    
    // MARK: - Custom Curve Helpers
    
    /// Create S-curve for contrast enhancement
    static func sContrastCurve(strength: Float = 0.2) -> [FilmCurvePoint] {
        let s = strength
        return [
            FilmCurvePoint(input: 0.0, output: 0.0),
            FilmCurvePoint(input: 0.25, output: 0.25 - s * 0.5),
            FilmCurvePoint(input: 0.5, output: 0.5),
            FilmCurvePoint(input: 0.75, output: 0.75 + s * 0.5),
            FilmCurvePoint(input: 1.0, output: 1.0)
        ]
    }
    
    /// Create lifted blacks curve
    static func liftedBlacksCurve(lift: Float = 0.05) -> [FilmCurvePoint] {
        return [
            FilmCurvePoint(input: 0.0, output: lift),
            FilmCurvePoint(input: 0.25, output: 0.25 + lift * 0.5),
            FilmCurvePoint(input: 0.5, output: 0.5),
            FilmCurvePoint(input: 1.0, output: 1.0)
        ]
    }
    
    /// Create crushed whites curve
    static func crushedWhitesCurve(crush: Float = 0.05) -> [FilmCurvePoint] {
        return [
            FilmCurvePoint(input: 0.0, output: 0.0),
            FilmCurvePoint(input: 0.5, output: 0.5),
            FilmCurvePoint(input: 0.75, output: 0.75 - crush * 0.3),
            FilmCurvePoint(input: 1.0, output: 1.0 - crush)
        ]
    }
}

// MARK: - Metal Buffer Conversion

extension FilmCurvesConfig {
    
    /// Convert to Metal-compatible RGBCurvesParams struct
    func toMetalParams() -> RGBCurvesParams {
        var params = RGBCurvesParams()
        
        // Fill curves using unsafe pointer access
        let redCount = min(redCurve.count, Int(MAX_CURVE_POINTS))
        let greenCount = min(greenCurve.count, Int(MAX_CURVE_POINTS))
        let blueCount = min(blueCurve.count, Int(MAX_CURVE_POINTS))
        
        // Use withUnsafeMutablePointer to set tuple values
        withUnsafeMutablePointer(to: &params.redCurve) { ptr in
            let curvePtr = UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: CurvePoint.self)
            for i in 0..<redCount {
                curvePtr[i] = redCurve[i].toMetal()
            }
        }
        
        withUnsafeMutablePointer(to: &params.greenCurve) { ptr in
            let curvePtr = UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: CurvePoint.self)
            for i in 0..<greenCount {
                curvePtr[i] = greenCurve[i].toMetal()
            }
        }
        
        withUnsafeMutablePointer(to: &params.blueCurve) { ptr in
            let curvePtr = UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: CurvePoint.self)
            for i in 0..<blueCount {
                curvePtr[i] = blueCurve[i].toMetal()
            }
        }
        
        params.redPointCount = Int32(redCount)
        params.greenPointCount = Int32(greenCount)
        params.bluePointCount = Int32(blueCount)
        params.enabled = enabled ? 1 : 0
        
        return params
    }
}

// MARK: - Preview Helpers

#if DEBUG
extension FilmCurvesConfig {
    /// Print curve values for debugging
    func debugPrint() {
        print("=== Film Curves Config ===")
        print("Enabled: \(enabled)")
        print("Red curve (\(redCurve.count) points):")
        for p in redCurve {
            print("  (\(p.input), \(p.output))")
        }
        print("Green curve (\(greenCurve.count) points):")
        for p in greenCurve {
            print("  (\(p.input), \(p.output))")
        }
        print("Blue curve (\(blueCurve.count) points):")
        for p in blueCurve {
            print("  (\(p.input), \(p.output))")
        }
    }
}
#endif
