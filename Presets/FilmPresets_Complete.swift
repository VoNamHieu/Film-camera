// FilmPresets_Complete.swift
// Film Emulation Preset Data - 24 Presets
// ★ FIXED: Correct LUT filenames to match actual files in Resources/LUTs/

import Foundation

struct FilmPresets {
    
    // MARK: - PROFESSIONAL FILM STOCKS
    
    static let kodakPortra400 = FilterPreset(
        id: "PORTRA_400_AUTHENTIC",
        label: "Kodak Portra 400",
        category: .professional,
        lutId: "PORTRA_400_LINEAR",
        lutFile: "Kodak_Portra_400_Linear.cube",  // ★ Fixed: removed "luts/" prefix
        colorSpace: "linear",
        colorAdjustments: ColorAdjustments(exposure: 0.0, contrast: 0.04, saturation: 0.0, vibrance: 0.02),
        grain: GrainConfig(
            enabled: true, globalIntensity: 0.16,
            channels: GrainChannels(
                red: GrainChannel(intensity: 0.18, size: 1.08, seed: 4001, softness: 0.58),
                green: GrainChannel(intensity: 0.20, size: 1.10, seed: 4002, softness: 0.55),
                blue: GrainChannel(intensity: 0.24, size: 1.15, seed: 4003, softness: 0.50)),
            texture: GrainTexture(type: "perlin", octaves: 2, persistence: 0.58, lacunarity: 1.75, baseFrequency: 1.0),
            densityCurve: [
                GrainDensityPoint(luma: 0.0, multiplier: 0.05), GrainDensityPoint(luma: 0.15, multiplier: 0.35),
                GrainDensityPoint(luma: 0.30, multiplier: 0.75), GrainDensityPoint(luma: 0.45, multiplier: 1.0),
                GrainDensityPoint(luma: 0.60, multiplier: 0.85), GrainDensityPoint(luma: 0.75, multiplier: 0.50),
                GrainDensityPoint(luma: 0.90, multiplier: 0.15), GrainDensityPoint(luma: 1.0, multiplier: 0.0)],
            chromatic: GrainChromatic(enabled: true, redShift: ChromaticShift(x: 0.12, y: -0.05), blueShift: ChromaticShift(x: -0.14, y: 0.08)),
            clumping: GrainClumping(enabled: true, strength: 0.18, threshold: 0.25, clusterSize: 1.2),
            temporal: GrainTemporal(enabled: true, refreshRate: 1, seedIncrement: 7919, coherence: 0.22),
            colorJitter: GrainColorJitter(enabled: true, strength: 0.0018, perPixel: true, blueStrength: 1.1, seed: 400)),
        bloom: BloomConfig(enabled: true, intensity: 0.04, threshold: 0.80, radius: 10, softness: 0.72, colorTint: ColorTint(r: 1.0, g: 0.96, b: 0.88)),
        vignette: VignetteConfig(enabled: true, intensity: 0.10, roundness: 0.80, feather: 0.60),
        filmStock: FilmStock(manufacturer: "Kodak", name: "Portra 400", type: "Color Negative (C-41)", speed: 400, year: 2010,
            characteristics: ["Natural skin tones", "Wide dynamic range", "Low saturation", "Fine grain"]))
    
    static let kodakPortra160 = FilterPreset(
        id: "KODAK_PORTRA_160",
        label: "Kodak Portra 160 · Natural Portrait",
        category: .professional,
        lutId: "KODAK_PORTRA_160",
        lutFile: "Kodak_Portra_160_Linear.cube",  // ★ Fixed
        colorSpace: "linear",
        colorAdjustments: ColorAdjustments(exposure: 0.0, contrast: -0.05),
        splitTone: SplitToneConfig(shadowsHue: 185, shadowsSat: 0.08, highlightsHue: 32, highlightsSat: 0.06, balance: 0.35, midtoneProtection: 0.45),
        grain: GrainConfig(
            enabled: true, globalIntensity: 0.08,
            channels: GrainChannels(
                red: GrainChannel(intensity: 0.07, size: 0.82, seed: 6001, softness: 0.68),
                green: GrainChannel(intensity: 0.08, size: 0.85, seed: 6002, softness: 0.65),
                blue: GrainChannel(intensity: 0.10, size: 0.90, seed: 6003, softness: 0.62)),
            texture: GrainTexture(type: "perlin", octaves: 2, persistence: 0.45, lacunarity: 1.6, baseFrequency: 0.70),
            densityCurve: [GrainDensityPoint(luma: 0.0, multiplier: 0.05), GrainDensityPoint(luma: 0.48, multiplier: 1.0), GrainDensityPoint(luma: 1.0, multiplier: 0.05)],
            chromatic: GrainChromatic(enabled: true, redShift: ChromaticShift(x: 0.06, y: -0.03), blueShift: ChromaticShift(x: -0.07, y: 0.04)),
            clumping: GrainClumping(enabled: true, strength: 0.10, threshold: 0.32, clusterSize: 1.0),
            temporal: GrainTemporal(enabled: true, refreshRate: 1, seedIncrement: 8191, coherence: 0.40)),
        bloom: BloomConfig(enabled: true, intensity: 0.045, threshold: 0.78, radius: 12, softness: 0.75, colorTint: ColorTint(r: 1.04, g: 1.0, b: 0.92)),
        vignette: VignetteConfig(enabled: true, intensity: 0.08, roundness: 0.82, feather: 0.70),
        filmStock: FilmStock(manufacturer: "Kodak", name: "Portra 160", type: "Color Negative (C-41)", speed: 160, year: 2010,
            characteristics: ["Very fine grain", "Pastel look", "Natural colors", "Studio favorite"]))
    
    static let fujiPro400H = FilterPreset(
        id: "FUJI_400H",
        label: "Fuji Pro 400H · Linear",
        category: .professional,
        lutId: "FUJI_400H",
        lutFile: "Fuji_400H_Linear.cube",  // ★ Fixed
        colorSpace: "linear",
        colorAdjustments: ColorAdjustments(exposure: 0.03, contrast: -0.08, highlights: -0.04, shadows: 0.06, saturation: -0.08, vibrance: 0.12, temperature: -0.03, tint: 0.04, fade: 0.03),
        splitTone: SplitToneConfig(shadowsHue: 195, shadowsSat: 0.08, highlightsHue: 42, highlightsSat: 0.04),
        rgbCurves: RGBCurves(
            red: [RGBCurvePoint(input: 0, output: 0.02), RGBCurvePoint(input: 0.25, output: 0.24), RGBCurvePoint(input: 0.5, output: 0.51), RGBCurvePoint(input: 0.75, output: 0.77), RGBCurvePoint(input: 1, output: 0.98)],
            green: [RGBCurvePoint(input: 0, output: 0.02), RGBCurvePoint(input: 0.25, output: 0.26), RGBCurvePoint(input: 0.5, output: 0.52), RGBCurvePoint(input: 0.75, output: 0.78), RGBCurvePoint(input: 1, output: 0.99)],
            blue: [RGBCurvePoint(input: 0, output: 0.03), RGBCurvePoint(input: 0.25, output: 0.28), RGBCurvePoint(input: 0.5, output: 0.54), RGBCurvePoint(input: 0.75, output: 0.80), RGBCurvePoint(input: 1, output: 1.02)]),
        grain: GrainConfig(
            enabled: true, globalIntensity: 0.16,
            channels: GrainChannels(
                red: GrainChannel(intensity: 0.14, size: 1.08, seed: 4001, softness: 0.58),
                green: GrainChannel(intensity: 0.16, size: 1.10, seed: 4002, softness: 0.55),
                blue: GrainChannel(intensity: 0.20, size: 1.15, seed: 4003, softness: 0.50)),
            texture: GrainTexture(type: "perlin", octaves: 2, persistence: 0.55, lacunarity: 1.7, baseFrequency: 1.0),
            densityCurve: [GrainDensityPoint(luma: 0.0, multiplier: 0.15), GrainDensityPoint(luma: 0.35, multiplier: 1.0), GrainDensityPoint(luma: 0.80, multiplier: 0.30), GrainDensityPoint(luma: 1.0, multiplier: 0.05)],
            chromatic: GrainChromatic(enabled: true, redShift: ChromaticShift(x: 0.10, y: -0.05), blueShift: ChromaticShift(x: -0.12, y: 0.08)),
            clumping: GrainClumping(enabled: true, strength: 0.22, threshold: 0.20, clusterSize: 1.3),
            temporal: GrainTemporal(enabled: true, refreshRate: 1, seedIncrement: 9971, coherence: 0.25),
            colorJitter: GrainColorJitter(enabled: true, strength: 0.002, perPixel: true, blueStrength: 1.15, seed: 400)),
        bloom: BloomConfig(enabled: true, intensity: 0.04, threshold: 0.80, radius: 10, softness: 0.70, colorTint: ColorTint(r: 1.0, g: 0.96, b: 0.88)),
        vignette: VignetteConfig(enabled: true, intensity: 0.10, roundness: 0.88, feather: 0.60),
        filmStock: FilmStock(manufacturer: "Fujifilm", name: "Pro 400H", type: "Color Negative (C-41)", speed: 400, year: 2004,
            characteristics: ["Soft pastel tones", "Cool shadows", "Fine grain", "Discontinued 2021"]))
    
    // MARK: - CONSUMER FILM STOCKS
    
    static let kodakUltramax400 = FilterPreset(
        id: "ULTRAMAX_400_AUTHENTIC",
        label: "Kodak Ultramax 400 v6.0",
        category: .consumer,
        lutId: "KODAK_ULTRAMAX_400_LINEAR",
        lutFile: "Kodak_Ultramax_400_linear_inout.cube",  // ★ Fixed
        colorSpace: "linear",
        colorAdjustments: ColorAdjustments(exposure: 0.0, contrast: 0.08, saturation: 0.0, vibrance: 0.02),
        splitTone: SplitToneConfig(shadowsHue: 185, shadowsSat: 0.10, highlightsHue: 40, highlightsSat: 0.05),
        selectiveColor: [SelectiveColorAdjustment(hue: 15, range: 30, sat: 0.10), SelectiveColorAdjustment(hue: 0, range: 25, sat: 0.08)],
        grain: GrainConfig(
            enabled: true, globalIntensity: 0.22,
            channels: GrainChannels(
                red: GrainChannel(intensity: 0.24, size: 1.12, seed: 1997, softness: 0.52),
                green: GrainChannel(intensity: 0.26, size: 1.15, seed: 2003, softness: 0.50),
                blue: GrainChannel(intensity: 0.32, size: 1.22, seed: 3007, softness: 0.45)),
            texture: GrainTexture(type: "perlin", octaves: 2, persistence: 0.55, lacunarity: 1.8, baseFrequency: 1.1),
            densityCurve: [GrainDensityPoint(luma: 0.0, multiplier: 0.0), GrainDensityPoint(luma: 0.35, multiplier: 1.0), GrainDensityPoint(luma: 0.80, multiplier: 0.35), GrainDensityPoint(luma: 1.0, multiplier: 0.0)],
            chromatic: GrainChromatic(enabled: true, redShift: ChromaticShift(x: 0.20, y: -0.08), blueShift: ChromaticShift(x: -0.22, y: 0.12)),
            clumping: GrainClumping(enabled: true, strength: 0.30, threshold: 0.22, clusterSize: 1.4),
            temporal: GrainTemporal(enabled: true, refreshRate: 1, seedIncrement: 9973, coherence: 0.20),
            colorJitter: GrainColorJitter(enabled: true, strength: 0.0025, perPixel: true, blueStrength: 1.2, seed: 42)),
        bloom: BloomConfig(enabled: true, intensity: 0.045, threshold: 0.78, radius: 12, softness: 0.75, colorTint: ColorTint(r: 1.0, g: 0.94, b: 0.82)),
        vignette: VignetteConfig(enabled: true, intensity: 0.12, roundness: 0.85, feather: 0.55),
        filmStock: FilmStock(manufacturer: "Kodak", name: "Ultramax 400", type: "Color Negative (C-41)", speed: 400, year: 1997,
            characteristics: ["Vibrant colors", "Punchy contrast", "Visible grain", "Great for everyday"]))
    
    static let kodakGold200 = FilterPreset(
        id: "KODAK_GOLD_200_V2",
        label: "Kodak Gold 200 v4.0",
        category: .consumer,
        lutId: "KODAK_GOLD_200_V2",
        lutFile: "Kodak_Gold_200_v2_linear.cube",  // ★ Fixed
        colorSpace: "linear",
        colorAdjustments: ColorAdjustments(exposure: 0.0, contrast: 0.04, saturation: 0.0, vibrance: 0.03),
        grain: GrainConfig(
            enabled: true, globalIntensity: 0.18,
            channels: GrainChannels(
                red: GrainChannel(intensity: 0.20, size: 1.10, seed: 2000, softness: 0.55),
                green: GrainChannel(intensity: 0.22, size: 1.12, seed: 2001, softness: 0.52),
                blue: GrainChannel(intensity: 0.26, size: 1.18, seed: 2002, softness: 0.48)),
            texture: GrainTexture(type: "perlin", octaves: 2, persistence: 0.60, lacunarity: 1.7, baseFrequency: 1.1),
            densityCurve: [GrainDensityPoint(luma: 0.0, multiplier: 0.0), GrainDensityPoint(luma: 0.35, multiplier: 1.0), GrainDensityPoint(luma: 0.80, multiplier: 0.3), GrainDensityPoint(luma: 1.0, multiplier: 0.0)],
            chromatic: GrainChromatic(enabled: true, redShift: ChromaticShift(x: 0.15, y: -0.08), blueShift: ChromaticShift(x: -0.18, y: 0.10)),
            clumping: GrainClumping(enabled: true, strength: 0.28, threshold: 0.18, clusterSize: 1.3),
            temporal: GrainTemporal(enabled: true, refreshRate: 1, seedIncrement: 8191, coherence: 0.22),
            colorJitter: GrainColorJitter(enabled: true, strength: 0.002, perPixel: true, blueStrength: 1.2, seed: 200)),
        bloom: BloomConfig(enabled: true, intensity: 0.06, threshold: 0.78, radius: 12, softness: 0.70, colorTint: ColorTint(r: 1.0, g: 0.88, b: 0.68)),
        vignette: VignetteConfig(enabled: true, intensity: 0.12, roundness: 0.75, feather: 0.65),
        filmStock: FilmStock(manufacturer: "Kodak", name: "Gold 200", type: "Color Negative (C-41)", speed: 200, year: 1988,
            characteristics: ["Warm golden tones", "Budget friendly", "Great for daylight"]))
    
    static let kodakColorPlus200 = FilterPreset(
        id: "KODAK_COLORPLUS_200",
        label: "Kodak ColorPlus 200 · Warm Consumer",
        category: .consumer,
        lutId: "KODAK_COLORPLUS_200",
        lutFile: "Kodak_ColorPlus_200_Linear.cube",  // ★ Fixed
        colorSpace: "linear",
        filmStock: FilmStock(manufacturer: "Kodak", name: "ColorPlus 200", type: "Color Negative (C-41)", speed: 200, year: 2005,
            characteristics: ["Warm tones", "Budget consumer film", "Nostalgic everyday look"]))
    
    static let fujiSuperia400 = FilterPreset(
        id: "SUPERIA_400",
        label: "Fuji Superia X-TRA 400",
        category: .consumer,
        lutFile: "Fuji_Superia_400_Linear.cube",  // ★ Added LUT file
        colorAdjustments: ColorAdjustments(exposure: 0.05, contrast: 0.12, highlights: -0.05, shadows: 0.08, saturation: 0.15, vibrance: 0.10, temperature: -0.02, tint: 0.04, fade: 0.05),
        splitTone: SplitToneConfig(shadowsHue: 170, shadowsSat: 0.12, highlightsHue: 40, highlightsSat: 0.05),
        rgbCurves: RGBCurves(
            red: [RGBCurvePoint(input: 0, output: 0.02), RGBCurvePoint(input: 0.25, output: 0.23), RGBCurvePoint(input: 0.5, output: 0.52), RGBCurvePoint(input: 0.75, output: 0.78), RGBCurvePoint(input: 1, output: 1.0)],
            green: [RGBCurvePoint(input: 0, output: 0.02), RGBCurvePoint(input: 0.25, output: 0.25), RGBCurvePoint(input: 0.5, output: 0.52), RGBCurvePoint(input: 0.75, output: 0.77), RGBCurvePoint(input: 1, output: 0.98)],
            blue: [RGBCurvePoint(input: 0, output: 0.04), RGBCurvePoint(input: 0.25, output: 0.28), RGBCurvePoint(input: 0.5, output: 0.54), RGBCurvePoint(input: 0.75, output: 0.80), RGBCurvePoint(input: 1, output: 1.0)]),
        grain: GrainConfig(enabled: true, globalIntensity: 0.22),
        bloom: BloomConfig(enabled: true, intensity: 0.12, threshold: 0.75, radius: 12),
        vignette: VignetteConfig(enabled: true, intensity: 0.15),
        filmStock: FilmStock(manufacturer: "Fujifilm", name: "Superia X-TRA 400", type: "Color Negative (C-41)", speed: 400, year: 1998,
            characteristics: ["Vivid colors", "Cyan shadows", "Consumer favorite"]))
    
    // MARK: - SLIDE FILM STOCKS
    
    static let fujiVelvia100 = FilterPreset(
        id: "FUJI_VELVIA_100",
        label: "Fuji Velvia 100 · Vivid Slide",
        category: .slide,
        lutId: "FUJI_VELVIA_100",
        lutFile: "Fuji_Velvia_100_Linear.cube",  // ★ Fixed
        colorSpace: "linear",
        colorAdjustments: ColorAdjustments(exposure: 0.0, contrast: 0.08, saturation: 0.18, vibrance: 0.12, temperature: 0.02),
        splitTone: SplitToneConfig(shadowsHue: 225, shadowsSat: 0.12, highlightsHue: 35, highlightsSat: 0.05),
        selectiveColor: [
            SelectiveColorAdjustment(hue: 120, range: 50, sat: 0.20, hueShift: -10),
            SelectiveColorAdjustment(hue: 210, range: 40, sat: 0.15),
            SelectiveColorAdjustment(hue: 15, range: 30, sat: 0.12, hueShift: 8)],
        grain: GrainConfig(enabled: true, globalIntensity: 0.08,
            channels: GrainChannels(
                red: GrainChannel(intensity: 0.07, size: 0.92, seed: 5001, softness: 0.68),
                green: GrainChannel(intensity: 0.08, size: 0.95, seed: 5002, softness: 0.65),
                blue: GrainChannel(intensity: 0.10, size: 1.00, seed: 5003, softness: 0.62))),
        bloom: BloomConfig(enabled: true, intensity: 0.03, threshold: 0.82, radius: 8, softness: 0.68),
        vignette: VignetteConfig(enabled: true, intensity: 0.08, roundness: 0.90, feather: 0.62),
        filmStock: FilmStock(manufacturer: "Fujifilm", name: "Velvia 100", type: "Color Reversal (E-6 Slide)", speed: 100, year: 2007,
            characteristics: ["Extremely high saturation", "Vivid colors", "High contrast", "Landscape favorite"]))
    
    static let fujiProvia100F = FilterPreset(
        id: "FUJI_PROVIA_100F",
        label: "Fuji Provia 100F · LUT",
        category: .slide,
        lutId: "FUJI_PROVIA_100F",
        lutFile: "provia_100f_33.cube",  // ★★★ FIXED: Was "Fuji_Provia_100F_Linear.cube"
        colorSpace: "linear",
        colorAdjustments: ColorAdjustments(exposure: 0.0, contrast: 0.05, saturation: 0.0, vibrance: 0.05),
        filmStock: FilmStock(manufacturer: "Fujifilm", name: "Provia 100F", type: "Color Reversal (E-6 Slide)", speed: 100, year: 2002,
            characteristics: ["Neutral colors", "Fine grain", "Versatile slide film"]))
    
    static let fujiAstia100F = FilterPreset(
        id: "FUJI_ASTIA_100F",
        label: "Fuji Astia 100F · LUT",
        category: .slide,
        lutId: "FUJI_ASTIA_100F",
        lutFile: "Fuji_Astia_100F_Linear.cube",  // ★ Confirmed correct
        colorSpace: "linear",
        colorAdjustments: ColorAdjustments(exposure: 0.0, contrast: -0.02, saturation: -0.05, vibrance: 0.03),
        filmStock: FilmStock(manufacturer: "Fujifilm", name: "Astia 100F", type: "Color Reversal (E-6 Slide)", speed: 100, year: 2002,
            characteristics: ["Soft colors", "Portrait friendly", "Lower contrast"]))
    
    // MARK: - CINEMA FILM STOCKS
    
    static let fujiEterna500T = FilterPreset(
        id: "ETERNA",
        label: "Fuji ETERNA 500T Cinema",
        category: .cinema,
        lutId: "ETERNA",
        lutFile: "Fuji_Eterna_linear.cube",  // ★ Fixed
        colorSpace: "linear",
        colorAdjustments: ColorAdjustments(exposure: -0.01, contrast: -0.08, highlights: -0.05, shadows: 0.05, saturation: -0.15, vibrance: -0.03, temperature: -0.03, tint: 0.01, fade: 0.04),
        splitTone: SplitToneConfig(shadowsHue: 195, shadowsSat: 0.06),
        selectiveColor: [SelectiveColorAdjustment(hue: 120, range: 40, sat: -0.10), SelectiveColorAdjustment(hue: 30, range: 25, sat: 0.02)],
        rgbCurves: RGBCurves(
            red: [RGBCurvePoint(input: 0, output: 0.02), RGBCurvePoint(input: 0.25, output: 0.24), RGBCurvePoint(input: 0.5, output: 0.50), RGBCurvePoint(input: 0.75, output: 0.75), RGBCurvePoint(input: 1, output: 0.97)],
            green: [RGBCurvePoint(input: 0, output: 0.02), RGBCurvePoint(input: 0.25, output: 0.25), RGBCurvePoint(input: 0.5, output: 0.51), RGBCurvePoint(input: 0.75, output: 0.76), RGBCurvePoint(input: 1, output: 0.97)],
            blue: [RGBCurvePoint(input: 0, output: 0.03), RGBCurvePoint(input: 0.25, output: 0.26), RGBCurvePoint(input: 0.5, output: 0.52), RGBCurvePoint(input: 0.75, output: 0.77), RGBCurvePoint(input: 1, output: 0.98)]),
        grain: GrainConfig(
            enabled: true, globalIntensity: 0.08,
            channels: GrainChannels(
                red: GrainChannel(intensity: 0.09, size: 0.95, seed: 2001, softness: 0.60),
                green: GrainChannel(intensity: 0.10, size: 1.00, seed: 2002, softness: 0.58),
                blue: GrainChannel(intensity: 0.08, size: 1.02, seed: 2003, softness: 0.62)),
            texture: GrainTexture(type: "perlin", octaves: 2, persistence: 0.42, lacunarity: 1.5, baseFrequency: 0.85),
            densityCurve: [GrainDensityPoint(luma: 0.0, multiplier: 0.0), GrainDensityPoint(luma: 0.42, multiplier: 1.0), GrainDensityPoint(luma: 1.0, multiplier: 0.0)],
            chromatic: GrainChromatic(enabled: true, redShift: ChromaticShift(x: 0.06, y: -0.02), blueShift: ChromaticShift(x: -0.08, y: 0.04)),
            clumping: GrainClumping(enabled: true, strength: 0.12, threshold: 0.28, clusterSize: 1.1),
            temporal: GrainTemporal(enabled: true, refreshRate: 1, seedIncrement: 7919, coherence: 0.35)),
        bloom: BloomConfig(enabled: true, intensity: 0.025, threshold: 0.82, radius: 8, softness: 0.80, colorTint: ColorTint(r: 1.0, g: 0.98, b: 0.95)),
        vignette: VignetteConfig(enabled: true, intensity: 0.06, roundness: 0.90, feather: 0.70),
        filmStock: FilmStock(manufacturer: "Fujifilm", name: "ETERNA 500T", type: "Motion Picture Negative (ECN-2)", speed: 500, year: 2006,
            characteristics: ["Flat profile for grading", "Low saturation", "Cinema look", "Wide latitude"]))
    
    // MARK: - BLACK & WHITE FILM STOCKS
    
    static let kodakTriX400 = FilterPreset(
        id: "KODAK_TRI_X_400",
        label: "Kodak Tri-X 400 · Classic B&W",
        category: .blackAndWhite,
        lutId: "KODAK_TRI_X_400",
        lutFile: "Kodak_Tri-X_400_Linear.cube",  // ★ Fixed
        colorSpace: "linear",
        grain: GrainConfig(
            enabled: true, globalIntensity: 0.25,
            channels: GrainChannels(
                red: GrainChannel(intensity: 0.25, size: 1.20, seed: 3001, softness: 0.48),
                green: GrainChannel(intensity: 0.25, size: 1.20, seed: 3002, softness: 0.48),
                blue: GrainChannel(intensity: 0.25, size: 1.20, seed: 3003, softness: 0.48)),
            texture: GrainTexture(type: "perlin", octaves: 3, persistence: 0.62, lacunarity: 1.8, baseFrequency: 1.25),
            densityCurve: [GrainDensityPoint(luma: 0.0, multiplier: 0.12), GrainDensityPoint(luma: 0.40, multiplier: 1.0), GrainDensityPoint(luma: 0.85, multiplier: 0.30), GrainDensityPoint(luma: 1.0, multiplier: 0.08)],
            chromatic: GrainChromatic(enabled: false),
            clumping: GrainClumping(enabled: true, strength: 0.32, threshold: 0.22, clusterSize: 1.4),
            temporal: GrainTemporal(enabled: true, refreshRate: 1, seedIncrement: 7919, coherence: 0.25)),
        bloom: BloomConfig(enabled: true, intensity: 0.06, threshold: 0.80, radius: 8, softness: 0.72, colorTint: ColorTint(r: 1.0, g: 1.0, b: 1.0)),
        vignette: VignetteConfig(enabled: true, intensity: 0.15, roundness: 0.82, feather: 0.58),
        filmStock: FilmStock(manufacturer: "Kodak", name: "Tri-X 400", type: "Black & White Negative", speed: 400, year: 1954,
            characteristics: ["High contrast", "Distinctive grain", "Classic B&W look", "Wide latitude"]))
    
    // MARK: - INSTANT FILM STOCKS
    
    static let polaroid600 = FilterPreset(
        id: "POLAROID_600",
        label: "Polaroid 600 · Classic Instant",
        category: .instant,
        lutFile: "Polaroid_600_Linear.cube",  // ★ Added LUT
        colorAdjustments: ColorAdjustments(exposure: 0.08, contrast: 0.15, highlights: -0.20, shadows: -0.05, whites: -0.05, blacks: 0.12, saturation: -0.08, vibrance: 0.05, temperature: 0.06, tint: -0.02, fade: 0.08, clarity: -0.08),
        splitTone: SplitToneConfig(shadowsHue: 185, shadowsSat: 0.15, highlightsHue: 350, highlightsSat: 0.08, balance: 0.35, midtoneProtection: 0.30),
        selectiveColor: [
            SelectiveColorAdjustment(hue: 120, range: 50, sat: -0.25),
            SelectiveColorAdjustment(hue: 240, range: 40, sat: -0.15),
            SelectiveColorAdjustment(hue: 0, range: 30, sat: 0.05, lum: 0.03),
            SelectiveColorAdjustment(hue: 30, range: 25, sat: 0.08)],
        rgbCurves: RGBCurves(
            red: [RGBCurvePoint(input: 0, output: 0.06), RGBCurvePoint(input: 0.25, output: 0.28), RGBCurvePoint(input: 0.5, output: 0.52), RGBCurvePoint(input: 0.75, output: 0.77), RGBCurvePoint(input: 1, output: 0.96)],
            green: [RGBCurvePoint(input: 0, output: 0.05), RGBCurvePoint(input: 0.25, output: 0.26), RGBCurvePoint(input: 0.5, output: 0.50), RGBCurvePoint(input: 0.75, output: 0.76), RGBCurvePoint(input: 1, output: 0.95)],
            blue: [RGBCurvePoint(input: 0, output: 0.08), RGBCurvePoint(input: 0.25, output: 0.28), RGBCurvePoint(input: 0.5, output: 0.51), RGBCurvePoint(input: 0.75, output: 0.76), RGBCurvePoint(input: 1, output: 0.94)]),
        grain: GrainConfig(
            enabled: true, globalIntensity: 0.08,
            channels: GrainChannels(
                red: GrainChannel(intensity: 0.07, size: 1.0, seed: 11001, softness: 0.70),
                green: GrainChannel(intensity: 0.08, size: 1.0, seed: 11002, softness: 0.68),
                blue: GrainChannel(intensity: 0.09, size: 1.1, seed: 11003, softness: 0.65)),
            texture: GrainTexture(type: "perlin", octaves: 2, persistence: 0.45, lacunarity: 1.8, baseFrequency: 0.8),
            densityCurve: [GrainDensityPoint(luma: 0.0, multiplier: 0.3), GrainDensityPoint(luma: 0.40, multiplier: 1.0), GrainDensityPoint(luma: 0.80, multiplier: 0.4), GrainDensityPoint(luma: 1.0, multiplier: 0.1)],
            chromatic: GrainChromatic(enabled: true, redShift: ChromaticShift(x: 0.05, y: -0.02), blueShift: ChromaticShift(x: -0.06, y: 0.03)),
            clumping: GrainClumping(enabled: true, strength: 0.15, threshold: 0.25, clusterSize: 1.1),
            temporal: GrainTemporal(enabled: true, refreshRate: 1, seedIncrement: 7919, coherence: 0.35),
            colorJitter: GrainColorJitter(enabled: true, strength: 0.0015, perPixel: true, blueStrength: 1.1, seed: 1100)),
        bloom: BloomConfig(enabled: true, intensity: 0.15, threshold: 0.60, radius: 20, softness: 0.92, colorTint: ColorTint(r: 1.02, g: 1.0, b: 0.96)),
        vignette: VignetteConfig(enabled: true, intensity: 0.18, roundness: 0.75, feather: 0.70, midpoint: 0.55),
        instantFrame: InstantFrameConfig(
            enabled: true,
            type: "polaroid_600",
            borderColor: BorderColor(r: 0.98, g: 0.97, b: 0.96),
            borderWidth: BorderWidth(top: 0.06, left: 0.05, right: 0.05, bottom: 0.18),
            texture: "matte",
            shadow: FrameShadow(enabled: true, blur: 15, opacity: 0.25, offsetY: 8)
        ),
        skinToneProtection: SkinToneProtection(enabled: true, hueCenter: 25, hueRange: 30, satProtection: 0.4, warmthBoost: 0.03),
        toneMapping: ToneMapping(enabled: true, method: "filmic", whitePoint: 1.15, shoulderStrength: 0.20, linearStrength: 0.30, toeStrength: 0.25),
        filmStock: FilmStock(manufacturer: "Polaroid", name: "600 Film", type: "Instant Integral", speed: 640, year: 1981,
            characteristics: ["Iconic white frame", "Warm color cast", "Cyan shadows", "Pink highlights", "Chemical development look"]))
    
    static let instaxMini = FilterPreset(
        id: "INSTAX_MINI",
        label: "Instax Mini · Bright Pop",
        category: .instant,
        colorAdjustments: ColorAdjustments(exposure: 0.12, contrast: -0.08, highlights: -0.05, shadows: 0.18, whites: 0.05, blacks: 0.10, saturation: 0.08, vibrance: 0.15, temperature: -0.02, tint: 0.02, fade: 0.05, clarity: -0.05),
        splitTone: SplitToneConfig(shadowsHue: 210, shadowsSat: 0.08, highlightsHue: 45, highlightsSat: 0.06, balance: 0.45, midtoneProtection: 0.35),
        selectiveColor: [
            SelectiveColorAdjustment(hue: 120, range: 45, sat: -0.15),
            SelectiveColorAdjustment(hue: 180, range: 35, sat: 0.08),
            SelectiveColorAdjustment(hue: 330, range: 30, sat: 0.10),
            SelectiveColorAdjustment(hue: 60, range: 25, sat: 0.05)],
        rgbCurves: RGBCurves(
            red: [RGBCurvePoint(input: 0, output: 0.04), RGBCurvePoint(input: 0.25, output: 0.27), RGBCurvePoint(input: 0.5, output: 0.51), RGBCurvePoint(input: 0.75, output: 0.77), RGBCurvePoint(input: 1, output: 0.98)],
            green: [RGBCurvePoint(input: 0, output: 0.04), RGBCurvePoint(input: 0.25, output: 0.27), RGBCurvePoint(input: 0.5, output: 0.51), RGBCurvePoint(input: 0.75, output: 0.77), RGBCurvePoint(input: 1, output: 0.98)],
            blue: [RGBCurvePoint(input: 0, output: 0.05), RGBCurvePoint(input: 0.25, output: 0.28), RGBCurvePoint(input: 0.5, output: 0.52), RGBCurvePoint(input: 0.75, output: 0.78), RGBCurvePoint(input: 1, output: 0.99)]),
        grain: GrainConfig(enabled: true, globalIntensity: 0.05,
            channels: GrainChannels(
                red: GrainChannel(intensity: 0.05, size: 0.9, seed: 12001, softness: 0.75),
                green: GrainChannel(intensity: 0.05, size: 0.9, seed: 12002, softness: 0.75),
                blue: GrainChannel(intensity: 0.06, size: 0.95, seed: 12003, softness: 0.72)),
            texture: GrainTexture(type: "perlin", octaves: 1, persistence: 0.35, lacunarity: 2.0, baseFrequency: 0.6),
            chromatic: GrainChromatic(enabled: false), clumping: GrainClumping(enabled: false),
            temporal: GrainTemporal(enabled: true, refreshRate: 1, seedIncrement: 4999, coherence: 0.40)),
        bloom: BloomConfig(enabled: true, intensity: 0.12, threshold: 0.55, radius: 18, softness: 0.90, colorTint: ColorTint(r: 1.0, g: 1.0, b: 1.02)),
        vignette: VignetteConfig(enabled: true, intensity: 0.10, roundness: 0.85, feather: 0.75),
        instantFrame: InstantFrameConfig(
            enabled: true,
            type: "instax_mini",
            borderColor: BorderColor(r: 1.0, g: 1.0, b: 1.0),
            borderWidth: BorderWidth(top: 0.08, left: 0.04, right: 0.04, bottom: 0.15),
            texture: "glossy",
            shadow: FrameShadow(enabled: true, blur: 12, opacity: 0.20, offsetY: 6)
        ),
        skinToneProtection: SkinToneProtection(enabled: true, hueCenter: 22, hueRange: 28, satProtection: 0.35, warmthBoost: 0.02),
        toneMapping: ToneMapping(enabled: true, method: "filmic", whitePoint: 1.2, shoulderStrength: 0.15, linearStrength: 0.40, toeStrength: 0.15),
        filmStock: FilmStock(manufacturer: "Fujifilm", name: "Instax Mini", type: "Instant Integral", speed: 800, year: 1998,
            characteristics: ["Bright and airy", "Slightly cool tone", "High key friendly", "Gen Z aesthetic"]))
    
    static let polaroidSX70 = FilterPreset(
        id: "POLAROID_SX70",
        label: "Polaroid SX-70 · Vintage 70s",
        category: .instant,
        colorAdjustments: ColorAdjustments(exposure: 0.03, contrast: 0.05, highlights: -0.10, shadows: 0.08, whites: -0.08, blacks: 0.05, saturation: 0.08, vibrance: 0.10, temperature: 0.10, tint: 0.02, fade: 0.06),
        splitTone: SplitToneConfig(shadowsHue: 175, shadowsSat: 0.18, highlightsHue: 35, highlightsSat: 0.14, balance: 0.30, midtoneProtection: 0.25),
        selectiveColor: [
            SelectiveColorAdjustment(hue: 30, range: 30, sat: 0.15, lum: 0.03),
            SelectiveColorAdjustment(hue: 120, range: 50, sat: -0.30),
            SelectiveColorAdjustment(hue: 0, range: 25, sat: 0.10),
            SelectiveColorAdjustment(hue: 200, range: 40, sat: -0.15),
            SelectiveColorAdjustment(hue: 55, range: 25, sat: 0.08)],
        rgbCurves: RGBCurves(
            red: [RGBCurvePoint(input: 0, output: 0.04), RGBCurvePoint(input: 0.25, output: 0.28), RGBCurvePoint(input: 0.5, output: 0.54), RGBCurvePoint(input: 0.75, output: 0.79), RGBCurvePoint(input: 1, output: 0.97)],
            green: [RGBCurvePoint(input: 0, output: 0.03), RGBCurvePoint(input: 0.25, output: 0.25), RGBCurvePoint(input: 0.5, output: 0.50), RGBCurvePoint(input: 0.75, output: 0.76), RGBCurvePoint(input: 1, output: 0.95)],
            blue: [RGBCurvePoint(input: 0, output: 0.05), RGBCurvePoint(input: 0.25, output: 0.26), RGBCurvePoint(input: 0.5, output: 0.49), RGBCurvePoint(input: 0.75, output: 0.74), RGBCurvePoint(input: 1, output: 0.92)]),
        grain: GrainConfig(
            enabled: true, globalIntensity: 0.12,
            channels: GrainChannels(
                red: GrainChannel(intensity: 0.11, size: 1.1, seed: 13001, softness: 0.62),
                green: GrainChannel(intensity: 0.12, size: 1.1, seed: 13002, softness: 0.60),
                blue: GrainChannel(intensity: 0.14, size: 1.2, seed: 13003, softness: 0.58)),
            texture: GrainTexture(type: "perlin", octaves: 2, persistence: 0.50, lacunarity: 1.7, baseFrequency: 0.9),
            densityCurve: [GrainDensityPoint(luma: 0.0, multiplier: 0.35), GrainDensityPoint(luma: 0.40, multiplier: 1.0), GrainDensityPoint(luma: 0.80, multiplier: 0.45), GrainDensityPoint(luma: 1.0, multiplier: 0.15)],
            chromatic: GrainChromatic(enabled: true, redShift: ChromaticShift(x: 0.08, y: -0.03), blueShift: ChromaticShift(x: -0.09, y: 0.04)),
            clumping: GrainClumping(enabled: true, strength: 0.20, threshold: 0.22, clusterSize: 1.2),
            temporal: GrainTemporal(enabled: true, refreshRate: 1, seedIncrement: 8191, coherence: 0.30),
            colorJitter: GrainColorJitter(enabled: true, strength: 0.002, perPixel: true, blueStrength: 1.15, seed: 1300)),
        bloom: BloomConfig(enabled: true, intensity: 0.10, threshold: 0.65, radius: 15, softness: 0.88, colorTint: ColorTint(r: 1.04, g: 1.0, b: 0.94)),
        vignette: VignetteConfig(enabled: true, intensity: 0.22, roundness: 0.70, feather: 0.65, midpoint: 0.50),
        instantFrame: InstantFrameConfig(
            enabled: true,
            type: "polaroid_sx70",
            borderColor: BorderColor(r: 0.97, g: 0.96, b: 0.94),
            borderWidth: BorderWidth(top: 0.05, left: 0.05, right: 0.05, bottom: 0.16),
            texture: "matte",
            shadow: FrameShadow(enabled: true, blur: 18, opacity: 0.28, offsetY: 10)
        ),
        skinToneProtection: SkinToneProtection(enabled: true, hueCenter: 28, hueRange: 32, satProtection: 0.45, warmthBoost: 0.05),
        toneMapping: ToneMapping(enabled: true, method: "filmic", whitePoint: 1.1, shoulderStrength: 0.25, linearStrength: 0.28, toeStrength: 0.20),
        filmStock: FilmStock(manufacturer: "Polaroid", name: "SX-70", type: "Instant Integral", speed: 160, year: 1972,
            characteristics: ["70s aesthetic", "Rich warm tones", "Deeper colors", "Vintage character"]))
    
    // MARK: - DISPOSABLE CAMERA PRESETS
    
    static let kodakFunSaver = FilterPreset(
        id: "KODAK_FUNSAVER",
        label: "Kodak FunSaver · Party Flash",
        category: .disposable,
        lutId: "KODAK_GOLD_200_V2",
        lutFile: "Kodak_Gold_200_v2_linear.cube",  // ★ Fixed
        colorSpace: "linear",
        colorAdjustments: ColorAdjustments(exposure: 0.05, contrast: 0.12, highlights: 0.08, shadows: -0.05, whites: 0.05, blacks: -0.03, saturation: 0.10, vibrance: 0.05, temperature: 0.02, tint: -0.04, clarity: -0.08),
        splitTone: SplitToneConfig(shadowsHue: 140, shadowsSat: 0.10, highlightsHue: 50, highlightsSat: 0.08, balance: 0.40, midtoneProtection: 0.20),
        selectiveColor: [SelectiveColorAdjustment(hue: 120, range: 40, sat: 0.05), SelectiveColorAdjustment(hue: 25, range: 25, sat: 0.08)],
        rgbCurves: RGBCurves(
            red: [RGBCurvePoint(input: 0, output: 0.02), RGBCurvePoint(input: 0.25, output: 0.24), RGBCurvePoint(input: 0.5, output: 0.50), RGBCurvePoint(input: 0.75, output: 0.78), RGBCurvePoint(input: 1, output: 1.0)],
            green: [RGBCurvePoint(input: 0, output: 0.03), RGBCurvePoint(input: 0.25, output: 0.26), RGBCurvePoint(input: 0.5, output: 0.52), RGBCurvePoint(input: 0.75, output: 0.78), RGBCurvePoint(input: 1, output: 1.0)],
            blue: [RGBCurvePoint(input: 0, output: 0.02), RGBCurvePoint(input: 0.25, output: 0.24), RGBCurvePoint(input: 0.5, output: 0.49), RGBCurvePoint(input: 0.75, output: 0.76), RGBCurvePoint(input: 1, output: 0.98)]),
        grain: GrainConfig(
            enabled: true, globalIntensity: 0.25,
            channels: GrainChannels(
                red: GrainChannel(intensity: 0.22, size: 1.15, seed: 21001, softness: 0.52),
                green: GrainChannel(intensity: 0.25, size: 1.18, seed: 21002, softness: 0.50),
                blue: GrainChannel(intensity: 0.30, size: 1.25, seed: 21003, softness: 0.48)),
            texture: GrainTexture(type: "perlin", octaves: 2, persistence: 0.58, lacunarity: 1.75, baseFrequency: 1.1),
            densityCurve: [GrainDensityPoint(luma: 0.0, multiplier: 0.3), GrainDensityPoint(luma: 0.30, multiplier: 1.0), GrainDensityPoint(luma: 0.70, multiplier: 0.5), GrainDensityPoint(luma: 1.0, multiplier: 0.1)],
            chromatic: GrainChromatic(enabled: true, redShift: ChromaticShift(x: 0.12, y: -0.05), blueShift: ChromaticShift(x: -0.15, y: 0.06)),
            clumping: GrainClumping(enabled: true, strength: 0.25, threshold: 0.20, clusterSize: 1.3),
            temporal: GrainTemporal(enabled: true, refreshRate: 1, seedIncrement: 7919, coherence: 0.22),
            colorJitter: GrainColorJitter(enabled: true, strength: 0.0025, perPixel: true, blueStrength: 1.2, seed: 2100)),
        vignette: VignetteConfig(enabled: true, intensity: 0.28, roundness: 0.65, feather: 0.55, midpoint: 0.45),
        skinToneProtection: SkinToneProtection(enabled: true, hueCenter: 25, hueRange: 30, satProtection: 0.30, warmthBoost: 0.02),
        filmStock: FilmStock(manufacturer: "Kodak", name: "FunSaver", type: "Disposable (Gold 400)", speed: 400, year: 1987,
            characteristics: ["Flash falloff", "Barrel distortion", "Chromatic aberration", "Light leaks", "Party aesthetic"]))
    
    static let fujiQuickSnap = FilterPreset(
        id: "FUJI_QUICKSNAP",
        label: "Fuji QuickSnap · Cool Flash",
        category: .disposable,
        colorAdjustments: ColorAdjustments(exposure: 0.03, contrast: 0.15, highlights: 0.10, shadows: -0.08, whites: 0.03, blacks: -0.05, saturation: 0.12, vibrance: 0.08, temperature: -0.05, tint: 0.02, clarity: -0.10),
        splitTone: SplitToneConfig(shadowsHue: 195, shadowsSat: 0.14, highlightsHue: 45, highlightsSat: 0.06, balance: 0.35, midtoneProtection: 0.22),
        selectiveColor: [
            SelectiveColorAdjustment(hue: 180, range: 40, sat: 0.10),
            SelectiveColorAdjustment(hue: 120, range: 50, sat: -0.10),
            SelectiveColorAdjustment(hue: 0, range: 30, sat: 0.08)],
        rgbCurves: RGBCurves(
            red: [RGBCurvePoint(input: 0, output: 0.02), RGBCurvePoint(input: 0.25, output: 0.23), RGBCurvePoint(input: 0.5, output: 0.49), RGBCurvePoint(input: 0.75, output: 0.77), RGBCurvePoint(input: 1, output: 1.0)],
            green: [RGBCurvePoint(input: 0, output: 0.03), RGBCurvePoint(input: 0.25, output: 0.26), RGBCurvePoint(input: 0.5, output: 0.52), RGBCurvePoint(input: 0.75, output: 0.78), RGBCurvePoint(input: 1, output: 1.0)],
            blue: [RGBCurvePoint(input: 0, output: 0.04), RGBCurvePoint(input: 0.25, output: 0.28), RGBCurvePoint(input: 0.5, output: 0.54), RGBCurvePoint(input: 0.75, output: 0.80), RGBCurvePoint(input: 1, output: 1.02)]),
        grain: GrainConfig(
            enabled: true, globalIntensity: 0.20,
            channels: GrainChannels(
                red: GrainChannel(intensity: 0.18, size: 1.12, seed: 22001, softness: 0.54),
                green: GrainChannel(intensity: 0.20, size: 1.15, seed: 22002, softness: 0.52),
                blue: GrainChannel(intensity: 0.24, size: 1.20, seed: 22003, softness: 0.50)),
            texture: GrainTexture(type: "perlin", octaves: 2, persistence: 0.55, lacunarity: 1.75, baseFrequency: 1.05),
            densityCurve: [GrainDensityPoint(luma: 0.0, multiplier: 0.35), GrainDensityPoint(luma: 0.30, multiplier: 0.95), GrainDensityPoint(luma: 0.70, multiplier: 0.55), GrainDensityPoint(luma: 1.0, multiplier: 0.08)],
            chromatic: GrainChromatic(enabled: true, redShift: ChromaticShift(x: 0.10, y: -0.04), blueShift: ChromaticShift(x: -0.12, y: 0.05)),
            clumping: GrainClumping(enabled: true, strength: 0.22, threshold: 0.22, clusterSize: 1.25),
            temporal: GrainTemporal(enabled: true, refreshRate: 1, seedIncrement: 7993, coherence: 0.24),
            colorJitter: GrainColorJitter(enabled: true, strength: 0.0022, perPixel: true, blueStrength: 1.18, seed: 2200)),
        vignette: VignetteConfig(enabled: true, intensity: 0.25, roundness: 0.68, feather: 0.58, midpoint: 0.48),
        skinToneProtection: SkinToneProtection(enabled: true, hueCenter: 22, hueRange: 28, satProtection: 0.35, warmthBoost: 0.03),
        filmStock: FilmStock(manufacturer: "Fujifilm", name: "QuickSnap", type: "Disposable (Superia 400)", speed: 400, year: 1986,
            characteristics: ["Cool flash tone", "Cyan shadows", "Punchy contrast", "Y2K nostalgia"]))
    
    // MARK: - FOOD & LIFESTYLE PRESETS
    
    static let cafeMood = FilterPreset(
        id: "CAFE_MOOD",
        label: "Cafe Mood · Warm Cozy",
        category: .food,
        colorAdjustments: ColorAdjustments(exposure: 0.05, contrast: 0.08, highlights: -0.08, shadows: 0.12, whites: -0.03, blacks: 0.08, saturation: -0.05, vibrance: 0.08, temperature: 0.12, tint: 0.02, fade: 0.04, clarity: 0.05),
        splitTone: SplitToneConfig(shadowsHue: 30, shadowsSat: 0.12, highlightsHue: 45, highlightsSat: 0.08, balance: 0.40, midtoneProtection: 0.35),
        selectiveColor: [
            SelectiveColorAdjustment(hue: 30, range: 35, sat: 0.15, lum: 0.05),
            SelectiveColorAdjustment(hue: 55, range: 25, sat: 0.10),
            SelectiveColorAdjustment(hue: 120, range: 50, sat: -0.35),
            SelectiveColorAdjustment(hue: 200, range: 40, sat: -0.25),
            SelectiveColorAdjustment(hue: 0, range: 25, sat: 0.08)],
        rgbCurves: RGBCurves(
            red: [RGBCurvePoint(input: 0, output: 0.05), RGBCurvePoint(input: 0.25, output: 0.29), RGBCurvePoint(input: 0.5, output: 0.53), RGBCurvePoint(input: 0.75, output: 0.78), RGBCurvePoint(input: 1, output: 0.97)],
            green: [RGBCurvePoint(input: 0, output: 0.04), RGBCurvePoint(input: 0.25, output: 0.26), RGBCurvePoint(input: 0.5, output: 0.50), RGBCurvePoint(input: 0.75, output: 0.76), RGBCurvePoint(input: 1, output: 0.96)],
            blue: [RGBCurvePoint(input: 0, output: 0.03), RGBCurvePoint(input: 0.25, output: 0.24), RGBCurvePoint(input: 0.5, output: 0.47), RGBCurvePoint(input: 0.75, output: 0.73), RGBCurvePoint(input: 1, output: 0.93)]),
        grain: GrainConfig(enabled: true, globalIntensity: 0.03,
            channels: GrainChannels(
                red: GrainChannel(intensity: 0.03, size: 1.0, seed: 31001, softness: 0.80),
                green: GrainChannel(intensity: 0.03, size: 1.0, seed: 31002, softness: 0.80),
                blue: GrainChannel(intensity: 0.035, size: 1.0, seed: 31003, softness: 0.78)),
            texture: GrainTexture(type: "perlin", octaves: 1, persistence: 0.30, lacunarity: 2.0, baseFrequency: 0.5)),
        bloom: BloomConfig(enabled: true, intensity: 0.08, threshold: 0.70, radius: 12, softness: 0.85, colorTint: ColorTint(r: 1.04, g: 1.0, b: 0.94)),
        vignette: VignetteConfig(enabled: true, intensity: 0.10, roundness: 0.90, feather: 0.80),
        skinToneProtection: SkinToneProtection(enabled: true, hueCenter: 28, hueRange: 30, satProtection: 0.40, warmthBoost: 0.04),
        toneMapping: ToneMapping(enabled: true, method: "filmic", whitePoint: 1.12, shoulderStrength: 0.18, linearStrength: 0.32, toeStrength: 0.18),
        filmStock: FilmStock(manufacturer: "Digital", name: "Cafe Mood", type: "Lifestyle Filter",
            characteristics: ["Rich warm browns", "Coffee shop aesthetic", "Great for food photos", "Instagram friendly"]))
    
    static let freshClean = FilterPreset(
        id: "FRESH_CLEAN",
        label: "Fresh Clean · Bright Healthy",
        category: .food,
        colorAdjustments: ColorAdjustments(exposure: 0.10, contrast: 0.05, highlights: -0.05, shadows: 0.15, whites: 0.05, blacks: 0.08, saturation: 0.08, vibrance: 0.15, temperature: -0.02, fade: 0.02, clarity: 0.10),
        splitTone: SplitToneConfig(shadowsHue: 200, shadowsSat: 0.04, highlightsHue: 55, highlightsSat: 0.03, balance: 0.50, midtoneProtection: 0.40),
        selectiveColor: [
            SelectiveColorAdjustment(hue: 120, range: 45, sat: 0.20, lum: 0.08),
            SelectiveColorAdjustment(hue: 0, range: 30, sat: 0.15),
            SelectiveColorAdjustment(hue: 55, range: 30, sat: 0.12),
            SelectiveColorAdjustment(hue: 30, range: 25, sat: 0.10)],
        rgbCurves: RGBCurves(
            red: [RGBCurvePoint(input: 0, output: 0.03), RGBCurvePoint(input: 0.25, output: 0.26), RGBCurvePoint(input: 0.5, output: 0.51), RGBCurvePoint(input: 0.75, output: 0.77), RGBCurvePoint(input: 1, output: 0.99)],
            green: [RGBCurvePoint(input: 0, output: 0.03), RGBCurvePoint(input: 0.25, output: 0.27), RGBCurvePoint(input: 0.5, output: 0.52), RGBCurvePoint(input: 0.75, output: 0.78), RGBCurvePoint(input: 1, output: 1.0)],
            blue: [RGBCurvePoint(input: 0, output: 0.03), RGBCurvePoint(input: 0.25, output: 0.26), RGBCurvePoint(input: 0.5, output: 0.51), RGBCurvePoint(input: 0.75, output: 0.77), RGBCurvePoint(input: 1, output: 0.99)]),
        grain: GrainConfig(enabled: false),
        bloom: BloomConfig(enabled: true, intensity: 0.05, threshold: 0.75, radius: 10, softness: 0.80, colorTint: ColorTint(r: 1.0, g: 1.0, b: 1.0)),
        vignette: VignetteConfig(enabled: true, intensity: 0.05, roundness: 1.0, feather: 0.90),
        toneMapping: ToneMapping(enabled: true, method: "filmic", whitePoint: 1.25, shoulderStrength: 0.12, linearStrength: 0.42, toeStrength: 0.10),
        filmStock: FilmStock(manufacturer: "Digital", name: "Fresh Clean", type: "Lifestyle Filter",
            characteristics: ["Bright and airy", "Vibrant colors", "Great for salads", "Health food aesthetic"]))
    
    static let goldenFood = FilterPreset(
        id: "GOLDEN_FOOD",
        label: "Golden Food · Rich Dinner",
        category: .food,
        colorAdjustments: ColorAdjustments(exposure: 0.02, contrast: 0.12, highlights: -0.10, shadows: 0.05, whites: -0.05, saturation: 0.05, vibrance: 0.12, temperature: 0.15, tint: 0.03, fade: 0.02, clarity: 0.08),
        splitTone: SplitToneConfig(shadowsHue: 25, shadowsSat: 0.15, highlightsHue: 50, highlightsSat: 0.12, balance: 0.35, midtoneProtection: 0.30),
        selectiveColor: [
            SelectiveColorAdjustment(hue: 35, range: 35, sat: 0.20, lum: 0.08),
            SelectiveColorAdjustment(hue: 0, range: 30, sat: 0.15),
            SelectiveColorAdjustment(hue: 55, range: 25, sat: 0.12),
            SelectiveColorAdjustment(hue: 120, range: 40, sat: -0.20),
            SelectiveColorAdjustment(hue: 200, range: 40, sat: -0.30)],
        rgbCurves: RGBCurves(
            red: [RGBCurvePoint(input: 0, output: 0.04), RGBCurvePoint(input: 0.25, output: 0.29), RGBCurvePoint(input: 0.5, output: 0.54), RGBCurvePoint(input: 0.75, output: 0.79), RGBCurvePoint(input: 1, output: 0.98)],
            green: [RGBCurvePoint(input: 0, output: 0.03), RGBCurvePoint(input: 0.25, output: 0.26), RGBCurvePoint(input: 0.5, output: 0.50), RGBCurvePoint(input: 0.75, output: 0.76), RGBCurvePoint(input: 1, output: 0.96)],
            blue: [RGBCurvePoint(input: 0, output: 0.02), RGBCurvePoint(input: 0.25, output: 0.23), RGBCurvePoint(input: 0.5, output: 0.46), RGBCurvePoint(input: 0.75, output: 0.72), RGBCurvePoint(input: 1, output: 0.92)]),
        grain: GrainConfig(enabled: true, globalIntensity: 0.02,
            channels: GrainChannels(
                red: GrainChannel(intensity: 0.02, size: 1.0, seed: 33001, softness: 0.85),
                green: GrainChannel(intensity: 0.02, size: 1.0, seed: 33002, softness: 0.85),
                blue: GrainChannel(intensity: 0.025, size: 1.0, seed: 33003, softness: 0.82)),
            texture: GrainTexture(type: "perlin", octaves: 1, persistence: 0.25, lacunarity: 2.0, baseFrequency: 0.4)),
        bloom: BloomConfig(enabled: true, intensity: 0.10, threshold: 0.65, radius: 15, softness: 0.88, colorTint: ColorTint(r: 1.05, g: 1.0, b: 0.92)),
        vignette: VignetteConfig(enabled: true, intensity: 0.15, roundness: 0.85, feather: 0.75),
        toneMapping: ToneMapping(enabled: true, method: "filmic", whitePoint: 1.08, shoulderStrength: 0.22, linearStrength: 0.28, toeStrength: 0.15),
        filmStock: FilmStock(manufacturer: "Digital", name: "Golden Food", type: "Lifestyle Filter",
            characteristics: ["Rich golden tones", "Appetizing warmth", "Great for dinner", "Restaurant quality look"]))
    
    // MARK: - NIGHT & NEON PRESETS
    
    static let cineStill800T = FilterPreset(
        id: "CINESTILL_800T",
        label: "Cinestill 800T · Night Halation",
        category: .night,
        colorAdjustments: ColorAdjustments(exposure: 0.02, contrast: 0.08, highlights: -0.08, shadows: 0.10, whites: -0.05, blacks: 0.06, saturation: 0.08, vibrance: 0.10, temperature: -0.12, tint: 0.03, fade: 0.03, clarity: 0.02),
        splitTone: SplitToneConfig(shadowsHue: 215, shadowsSat: 0.18, highlightsHue: 38, highlightsSat: 0.14, balance: 0.38, midtoneProtection: 0.25),
        selectiveColor: [
            SelectiveColorAdjustment(hue: 35, range: 35, sat: 0.18, lum: 0.06),
            SelectiveColorAdjustment(hue: 210, range: 45, sat: 0.15),
            SelectiveColorAdjustment(hue: 120, range: 50, sat: -0.25),
            SelectiveColorAdjustment(hue: 55, range: 30, sat: -0.10),
            SelectiveColorAdjustment(hue: 0, range: 25, sat: 0.10)],
        rgbCurves: RGBCurves(
            red: [RGBCurvePoint(input: 0, output: 0.02), RGBCurvePoint(input: 0.25, output: 0.24), RGBCurvePoint(input: 0.5, output: 0.50), RGBCurvePoint(input: 0.75, output: 0.79), RGBCurvePoint(input: 1, output: 1.02)],
            green: [RGBCurvePoint(input: 0, output: 0.02), RGBCurvePoint(input: 0.25, output: 0.24), RGBCurvePoint(input: 0.5, output: 0.49), RGBCurvePoint(input: 0.75, output: 0.75), RGBCurvePoint(input: 1, output: 0.96)],
            blue: [RGBCurvePoint(input: 0, output: 0.06), RGBCurvePoint(input: 0.25, output: 0.30), RGBCurvePoint(input: 0.5, output: 0.53), RGBCurvePoint(input: 0.75, output: 0.77), RGBCurvePoint(input: 1, output: 0.98)]),
        grain: GrainConfig(
            enabled: true, globalIntensity: 0.20,
            channels: GrainChannels(
                red: GrainChannel(intensity: 0.18, size: 1.15, seed: 41001, softness: 0.55),
                green: GrainChannel(intensity: 0.20, size: 1.18, seed: 41002, softness: 0.52),
                blue: GrainChannel(intensity: 0.25, size: 1.25, seed: 41003, softness: 0.48)),
            texture: GrainTexture(type: "perlin", octaves: 2, persistence: 0.58, lacunarity: 1.8, baseFrequency: 1.1),
            densityCurve: [GrainDensityPoint(luma: 0.0, multiplier: 0.5), GrainDensityPoint(luma: 0.30, multiplier: 1.0), GrainDensityPoint(luma: 0.70, multiplier: 0.55), GrainDensityPoint(luma: 1.0, multiplier: 0.1)],
            chromatic: GrainChromatic(enabled: true, redShift: ChromaticShift(x: 0.15, y: -0.06), blueShift: ChromaticShift(x: -0.18, y: 0.08)),
            clumping: GrainClumping(enabled: true, strength: 0.28, threshold: 0.18, clusterSize: 1.35),
            temporal: GrainTemporal(enabled: true, refreshRate: 1, seedIncrement: 8191, coherence: 0.20),
            colorJitter: GrainColorJitter(enabled: true, strength: 0.003, perPixel: true, blueStrength: 1.25, seed: 4100)),
        bloom: BloomConfig(enabled: true, intensity: 0.15, threshold: 0.60, radius: 20, softness: 0.85, colorTint: ColorTint(r: 1.10, g: 0.98, b: 0.90)),
        vignette: VignetteConfig(enabled: true, intensity: 0.15, roundness: 0.80, feather: 0.70),
        halation: HalationConfig(enabled: true, color: HalationColor(r: 1.0, g: 0.31, b: 0.16), intensity: 0.40, threshold: 0.65, radius: 28, softness: 0.88,
            colorGradient: HalationGradient(enabled: true, inner: HalationColor(r: 1.0, g: 0.39, b: 0.20), outer: HalationColor(r: 1.0, g: 0.20, b: 0.12))),
        skinToneProtection: SkinToneProtection(enabled: true, hueCenter: 25, hueRange: 30, satProtection: 0.35, warmthBoost: 0.05),
        toneMapping: ToneMapping(enabled: true, method: "filmic", whitePoint: 1.15, shoulderStrength: 0.20, linearStrength: 0.30, toeStrength: 0.18),
        filmStock: FilmStock(manufacturer: "Cinestill", name: "800T", type: "Color Negative (C-41)", speed: 800, year: 2012,
            characteristics: ["★ ICONIC red-orange halation", "Tungsten balanced", "Blue shadows", "Night photography staple", "Cinema aesthetic"]))
    
    static let cyberpunk = FilterPreset(
        id: "CYBERPUNK",
        label: "Cyberpunk · Neon City",
        category: .night,
        colorAdjustments: ColorAdjustments(exposure: -0.03, contrast: 0.20, highlights: -0.08, whites: -0.05, blacks: -0.05, saturation: 0.15, vibrance: 0.20, temperature: -0.10, tint: 0.08, fade: 0.03, clarity: 0.12),
        splitTone: SplitToneConfig(shadowsHue: 180, shadowsSat: 0.30, highlightsHue: 300, highlightsSat: 0.18, balance: 0.45, midtoneProtection: 0.20),
        selectiveColor: [
            SelectiveColorAdjustment(hue: 180, range: 50, sat: 0.35, lum: -0.05),
            SelectiveColorAdjustment(hue: 300, range: 40, sat: 0.30),
            SelectiveColorAdjustment(hue: 240, range: 35, sat: 0.15),
            SelectiveColorAdjustment(hue: 120, range: 50, sat: -0.40),
            SelectiveColorAdjustment(hue: 55, range: 30, sat: -0.30),
            SelectiveColorAdjustment(hue: 30, range: 25, sat: -0.15)],
        rgbCurves: RGBCurves(
            red: [RGBCurvePoint(input: 0, output: 0.02), RGBCurvePoint(input: 0.25, output: 0.22), RGBCurvePoint(input: 0.5, output: 0.48), RGBCurvePoint(input: 0.75, output: 0.78), RGBCurvePoint(input: 1, output: 1.0)],
            green: [RGBCurvePoint(input: 0, output: 0.04), RGBCurvePoint(input: 0.25, output: 0.28), RGBCurvePoint(input: 0.5, output: 0.53), RGBCurvePoint(input: 0.75, output: 0.78), RGBCurvePoint(input: 1, output: 1.0)],
            blue: [RGBCurvePoint(input: 0, output: 0.08), RGBCurvePoint(input: 0.25, output: 0.32), RGBCurvePoint(input: 0.5, output: 0.56), RGBCurvePoint(input: 0.75, output: 0.80), RGBCurvePoint(input: 1, output: 1.02)]),
        grain: GrainConfig(
            enabled: true, globalIntensity: 0.08,
            channels: GrainChannels(
                red: GrainChannel(intensity: 0.07, size: 1.0, seed: 42001, softness: 0.65),
                green: GrainChannel(intensity: 0.08, size: 1.0, seed: 42002, softness: 0.62),
                blue: GrainChannel(intensity: 0.10, size: 1.05, seed: 42003, softness: 0.60)),
            texture: GrainTexture(type: "perlin", octaves: 2, persistence: 0.45, lacunarity: 1.9, baseFrequency: 0.9),
            densityCurve: [GrainDensityPoint(luma: 0.0, multiplier: 0.4), GrainDensityPoint(luma: 0.50, multiplier: 0.9), GrainDensityPoint(luma: 1.0, multiplier: 0.2)],
            chromatic: GrainChromatic(enabled: true, redShift: ChromaticShift(x: 0.08, y: -0.04), blueShift: ChromaticShift(x: -0.10, y: 0.05)),
            clumping: GrainClumping(enabled: true, strength: 0.15, threshold: 0.25, clusterSize: 1.15),
            temporal: GrainTemporal(enabled: true, refreshRate: 1, seedIncrement: 9001, coherence: 0.28),
            colorJitter: GrainColorJitter(enabled: true, strength: 0.002, perPixel: true, blueStrength: 1.3, seed: 4200)),
        bloom: BloomConfig(enabled: true, intensity: 0.20, threshold: 0.55, radius: 25, softness: 0.90, colorTint: ColorTint(r: 1.0, g: 0.95, b: 1.05)),
        vignette: VignetteConfig(enabled: true, intensity: 0.20, roundness: 0.75, feather: 0.65),
        skinToneProtection: SkinToneProtection(enabled: true, hueCenter: 25, hueRange: 28, satProtection: 0.50),
        toneMapping: ToneMapping(enabled: true, method: "filmic", whitePoint: 1.05, shoulderStrength: 0.28, linearStrength: 0.25, toeStrength: 0.22),
        filmStock: FilmStock(manufacturer: "Digital", name: "Cyberpunk", type: "Creative Filter",
            characteristics: ["Teal & Magenta split", "High contrast", "Neon city aesthetic", "Blade Runner vibes", "Sci-fi atmosphere"]))
    
    // MARK: - CREATIVE PRESETS
    
    static let nostalgicNeg = FilterPreset(
        id: "NOSTALGIC_NEG",
        label: "Nostalgic Neg · Vintage Color",
        category: .creative,
        lutId: "NOSTALGIC_NEG",
        lutFile: "Nostalgic_Neg_Linear.cube",  // ★ Fixed
        colorSpace: "linear",
        splitTone: SplitToneConfig(shadowsHue: 190, shadowsSat: 0.10, highlightsHue: 35, highlightsSat: 0.08, balance: 0.38, midtoneProtection: 0.42),
        selectiveColor: [
            SelectiveColorAdjustment(hue: 0, range: 30, sat: 0.15),
            SelectiveColorAdjustment(hue: 30, range: 25, sat: 0.12),
            SelectiveColorAdjustment(hue: 120, range: 50, sat: -0.25, hueShift: 20),
            SelectiveColorAdjustment(hue: 180, range: 40, sat: -0.20),
            SelectiveColorAdjustment(hue: 220, range: 35, sat: 0.08)],
        grain: GrainConfig(
            enabled: true, globalIntensity: 0.14,
            channels: GrainChannels(
                red: GrainChannel(intensity: 0.13, size: 1.05, seed: 7001, softness: 0.58),
                green: GrainChannel(intensity: 0.14, size: 1.08, seed: 7002, softness: 0.55),
                blue: GrainChannel(intensity: 0.16, size: 1.12, seed: 7003, softness: 0.52)),
            texture: GrainTexture(type: "perlin", octaves: 2, persistence: 0.52, lacunarity: 1.7, baseFrequency: 0.90),
            densityCurve: [GrainDensityPoint(luma: 0.0, multiplier: 0.08), GrainDensityPoint(luma: 0.55, multiplier: 1.0), GrainDensityPoint(luma: 1.0, multiplier: 0.08)],
            chromatic: GrainChromatic(enabled: true, redShift: ChromaticShift(x: 0.10, y: -0.04), blueShift: ChromaticShift(x: -0.12, y: 0.06)),
            clumping: GrainClumping(enabled: true, strength: 0.18, threshold: 0.28, clusterSize: 1.2),
            temporal: GrainTemporal(enabled: true, refreshRate: 1, seedIncrement: 7919, coherence: 0.32),
            colorJitter: GrainColorJitter(enabled: true, strength: 0.0018, perPixel: true, blueStrength: 1.2, seed: 700)),
        bloom: BloomConfig(enabled: true, intensity: 0.06, threshold: 0.75, radius: 14, softness: 0.78, colorTint: ColorTint(r: 1.08, g: 1.02, b: 0.88)),
        vignette: VignetteConfig(enabled: true, intensity: 0.12, roundness: 0.78, feather: 0.62),
        filmStock: FilmStock(manufacturer: "Fujifilm", name: "Nostalgic Neg", type: "Film Simulation",
            characteristics: ["Vintage color rendering", "Muted greens", "Warm highlights", "Aged film look"]))
    
    static let classicNegative = FilterPreset(
        id: "CLASSIC_NEGATIVE",
        label: "Classic Negative",
        category: .creative,
        lutFile: "classic_chrome_linear.cube",  // ★ Added LUT
        colorAdjustments: ColorAdjustments(exposure: -0.02, contrast: 0.18, highlights: 0.08, shadows: -0.10, saturation: -0.10, vibrance: -0.04, temperature: 0.03, tint: -0.02),
        splitTone: SplitToneConfig(shadowsHue: 220, shadowsSat: 0.14, highlightsHue: 32, highlightsSat: 0.12),
        rgbCurves: RGBCurves(
            red: [RGBCurvePoint(input: 0, output: 0.0), RGBCurvePoint(input: 0.25, output: 0.22), RGBCurvePoint(input: 0.5, output: 0.48), RGBCurvePoint(input: 0.75, output: 0.78), RGBCurvePoint(input: 1, output: 1.0)],
            green: [RGBCurvePoint(input: 0, output: 0.0), RGBCurvePoint(input: 0.25, output: 0.21), RGBCurvePoint(input: 0.5, output: 0.49), RGBCurvePoint(input: 0.75, output: 0.77), RGBCurvePoint(input: 1, output: 1.0)],
            blue: [RGBCurvePoint(input: 0, output: 0.0), RGBCurvePoint(input: 0.25, output: 0.23), RGBCurvePoint(input: 0.5, output: 0.51), RGBCurvePoint(input: 0.75, output: 0.74), RGBCurvePoint(input: 1, output: 0.96)]),
        grain: GrainConfig(enabled: true, globalIntensity: 0.18),
        bloom: BloomConfig(enabled: true, intensity: 0.04),
        vignette: VignetteConfig(enabled: true, intensity: 0.12),
        filmStock: FilmStock(manufacturer: "Fujifilm", name: "Classic Negative", type: "Film Simulation",
            characteristics: ["High contrast", "Desaturated", "Nostalgic look"]))

    // MARK: - NEW CREATIVE PRESETS

    static let butter = FilterPreset(
        id: "BUTTER",
        label: "Butter · Creamy Warm",
        category: .creative,
        colorAdjustments: ColorAdjustments(
            exposure: 0.08, contrast: -0.05, highlights: -0.08, shadows: 0.15,
            saturation: -0.12, vibrance: 0.05, temperature: 0.15, tint: 0.02, fade: 0.08
        ),
        splitTone: SplitToneConfig(shadowsHue: 40, shadowsSat: 0.12, highlightsHue: 50, highlightsSat: 0.15, balance: 0.4, midtoneProtection: 0.35),
        grain: GrainConfig(enabled: true, globalIntensity: 0.08),
        bloom: BloomConfig(enabled: true, intensity: 0.12, threshold: 0.65, radius: 18, softness: 0.88, colorTint: ColorTint(r: 1.08, g: 1.02, b: 0.92)),
        vignette: VignetteConfig(enabled: true, intensity: 0.10, roundness: 0.85, feather: 0.75),
        filmStock: FilmStock(manufacturer: "Digital", name: "Butter", type: "Creative Filter",
            characteristics: ["Creamy warm tones", "Soft fade", "Dreamy aesthetic", "Golden hour vibes"]))

    static let sakura = FilterPreset(
        id: "SAKURA",
        label: "Sakura · Cherry Blossom",
        category: .creative,
        colorAdjustments: ColorAdjustments(
            exposure: 0.10, contrast: -0.08, highlights: 0.05, shadows: 0.12,
            saturation: 0.05, vibrance: 0.10, temperature: -0.02, tint: 0.08, fade: 0.05
        ),
        splitTone: SplitToneConfig(shadowsHue: 280, shadowsSat: 0.08, highlightsHue: 340, highlightsSat: 0.12, balance: 0.45, midtoneProtection: 0.40),
        selectiveColor: [
            SelectiveColorAdjustment(hue: 330, range: 40, sat: 0.15),  // Pink boost
            SelectiveColorAdjustment(hue: 120, range: 50, sat: -0.20)  // Muted greens
        ],
        grain: GrainConfig(enabled: true, globalIntensity: 0.05),
        bloom: BloomConfig(enabled: true, intensity: 0.15, threshold: 0.60, radius: 20, softness: 0.92, colorTint: ColorTint(r: 1.02, g: 0.98, b: 1.02)),
        vignette: VignetteConfig(enabled: true, intensity: 0.08, roundness: 0.90, feather: 0.80),
        filmStock: FilmStock(manufacturer: "Digital", name: "Sakura", type: "Creative Filter",
            characteristics: ["Soft pink tones", "Cherry blossom aesthetic", "Spring vibes", "Japanese influence"]))

    static let goldenHour = FilterPreset(
        id: "GOLDEN_HOUR",
        label: "Golden Hour · Sunset Glow",
        category: .creative,
        colorAdjustments: ColorAdjustments(
            exposure: 0.05, contrast: 0.05, highlights: -0.12, shadows: 0.10,
            saturation: 0.12, vibrance: 0.15, temperature: 0.20, tint: 0.03, fade: 0.03
        ),
        splitTone: SplitToneConfig(shadowsHue: 25, shadowsSat: 0.15, highlightsHue: 40, highlightsSat: 0.20, balance: 0.35, midtoneProtection: 0.30),
        selectiveColor: [
            SelectiveColorAdjustment(hue: 35, range: 40, sat: 0.18, lum: 0.05),
            SelectiveColorAdjustment(hue: 15, range: 30, sat: 0.12),
            SelectiveColorAdjustment(hue: 200, range: 50, sat: -0.15)
        ],
        grain: GrainConfig(enabled: true, globalIntensity: 0.06),
        bloom: BloomConfig(enabled: true, intensity: 0.18, threshold: 0.58, radius: 22, softness: 0.90, colorTint: ColorTint(r: 1.10, g: 0.98, b: 0.88)),
        vignette: VignetteConfig(enabled: true, intensity: 0.12, roundness: 0.80, feather: 0.70),
        filmStock: FilmStock(manufacturer: "Digital", name: "Golden Hour", type: "Creative Filter",
            characteristics: ["Rich golden warmth", "Sunset glow", "Magic hour aesthetic", "Romantic atmosphere"]))

    // MARK: - VHS PRESETS

    static let vhsCamcorder = FilterPreset(
        id: "VHS_CAMCORDER",
        label: "VHS Camcorder · Home Video",
        category: .vhs,
        colorAdjustments: ColorAdjustments(
            exposure: 0.03, contrast: 0.08, highlights: 0.05, shadows: -0.05,
            saturation: -0.10, vibrance: -0.05, temperature: 0.02, clarity: -0.15
        ),
        splitTone: SplitToneConfig(shadowsHue: 200, shadowsSat: 0.08, highlightsHue: 40, highlightsSat: 0.05),
        grain: GrainConfig(enabled: true, globalIntensity: 0.12),
        bloom: BloomConfig(enabled: true, intensity: 0.08, threshold: 0.70, radius: 15, softness: 0.80),
        vignette: VignetteConfig(enabled: true, intensity: 0.15, roundness: 0.70, feather: 0.60),
        vhsEffects: VHSEffectsConfig(
            enabled: true,
            scanlines: ScanlineConfig(enabled: true, intensity: 0.12, density: 1.2, flickerIntensity: 0.08),
            colorBleed: ColorBleedConfig(enabled: true, intensity: 0.25, redShift: 0.004, blueShift: 0.003),
            tracking: TrackingConfig(enabled: false),
            noiseIntensity: 0.10,
            saturationLoss: 0.08,
            sharpnessLoss: 0.15,
            dateOverlay: true
        ),
        dateStamp: DateStampConfig(enabled: true, format: .full, position: .bottomRight, color: .orange, opacity: 0.9, scale: 0.9),
        filmStock: FilmStock(manufacturer: "Sony", name: "Handycam", type: "VHS-C",
            characteristics: ["Home video look", "Soft focus", "Color bleeding", "90s camcorder aesthetic"]))

    static let vhsPlayback = FilterPreset(
        id: "VHS_PLAYBACK",
        label: "VHS Playback · Worn Tape",
        category: .vhs,
        colorAdjustments: ColorAdjustments(
            exposure: -0.02, contrast: 0.12, highlights: 0.08, shadows: -0.08,
            saturation: -0.18, vibrance: -0.10, temperature: -0.03, clarity: -0.20
        ),
        splitTone: SplitToneConfig(shadowsHue: 190, shadowsSat: 0.12, highlightsHue: 35, highlightsSat: 0.08),
        grain: GrainConfig(enabled: true, globalIntensity: 0.18),
        bloom: BloomConfig(enabled: true, intensity: 0.06, threshold: 0.72, radius: 12),
        vignette: VignetteConfig(enabled: true, intensity: 0.20, roundness: 0.65, feather: 0.55),
        vhsEffects: VHSEffectsConfig(
            enabled: true,
            scanlines: ScanlineConfig(enabled: true, intensity: 0.20, density: 1.0, flickerSpeed: 0.4, flickerIntensity: 0.15),
            colorBleed: ColorBleedConfig(enabled: true, intensity: 0.45, redShift: 0.008, blueShift: 0.006, verticalBleed: 0.35),
            tracking: TrackingConfig(enabled: true, intensity: 0.18, speed: 0.6, noise: 0.35, waveHeight: 0.025),
            noiseIntensity: 0.22,
            saturationLoss: 0.18,
            sharpnessLoss: 0.30,
            dateOverlay: false
        ),
        overlays: OverlaysConfig(enabled: true, dust: DustConfig(enabled: true, density: 0.15, opacity: 0.25), scratches: ScratchesConfig(enabled: true, density: 0.10, opacity: 0.20)),
        filmStock: FilmStock(manufacturer: "Generic", name: "VHS Tape", type: "VHS Playback",
            characteristics: ["Worn tape look", "Tracking artifacts", "Color degradation", "80s/90s nostalgia"]))

    // MARK: - FILM STRIP PRESET

    static let film35mm = FilterPreset(
        id: "FILM_35MM",
        label: "35mm Film Strip · Kodak Style",
        category: .creative,
        colorAdjustments: ColorAdjustments(
            exposure: 0.02, contrast: 0.06, highlights: -0.05, shadows: 0.08,
            saturation: 0.05, vibrance: 0.08, temperature: 0.05, fade: 0.04
        ),
        splitTone: SplitToneConfig(shadowsHue: 30, shadowsSat: 0.10, highlightsHue: 45, highlightsSat: 0.08),
        grain: GrainConfig(
            enabled: true, globalIntensity: 0.18,
            channels: GrainChannels(
                red: GrainChannel(intensity: 0.16, size: 1.10, seed: 35001, softness: 0.55),
                green: GrainChannel(intensity: 0.18, size: 1.12, seed: 35002, softness: 0.52),
                blue: GrainChannel(intensity: 0.22, size: 1.18, seed: 35003, softness: 0.48)),
            texture: GrainTexture(type: "perlin", octaves: 2, persistence: 0.58, lacunarity: 1.75, baseFrequency: 1.05)),
        bloom: BloomConfig(enabled: true, intensity: 0.05, threshold: 0.78, radius: 10, softness: 0.72, colorTint: ColorTint(r: 1.02, g: 0.98, b: 0.92)),
        vignette: VignetteConfig(enabled: true, intensity: 0.10, roundness: 0.75, feather: 0.60),
        filmStripEffects: FilmStripEffectsConfig(
            enabled: true,
            perforations: .standard35mm,
            borderColor: ColorTint(r: 0.12, g: 0.08, b: 0.04),
            borderOpacity: 0.95,
            frameLineWidth: 0.003,
            frameLineOpacity: 0.8,
            rebateVisible: true,
            rebateText: "KODAK 400TX",
            frameNumber: true,
            kodakStyle: true
        ),
        filmStock: FilmStock(manufacturer: "Kodak", name: "35mm Film Strip", type: "Negative Scan",
            characteristics: ["Film border visible", "Sprocket holes", "Kodak rebate", "Authentic scan look"]))

    static let triXOrange = FilterPreset(
        id: "TRI_X_ORANGE",
        label: "Tri-X · Orange Filter",
        category: .blackAndWhite,
        colorAdjustments: ColorAdjustments(contrast: 0.12, highlights: -0.05, shadows: -0.08),
        grain: GrainConfig(
            enabled: true, globalIntensity: 0.28,
            channels: GrainChannels(
                red: GrainChannel(intensity: 0.28, size: 1.22, seed: 36001, softness: 0.45),
                green: GrainChannel(intensity: 0.28, size: 1.22, seed: 36002, softness: 0.45),
                blue: GrainChannel(intensity: 0.28, size: 1.22, seed: 36003, softness: 0.45)),
            texture: GrainTexture(type: "perlin", octaves: 3, persistence: 0.65, lacunarity: 1.8, baseFrequency: 1.3)),
        bloom: BloomConfig(enabled: true, intensity: 0.05, threshold: 0.78, radius: 8, softness: 0.70, colorTint: ColorTint(r: 1.0, g: 1.0, b: 1.0)),
        vignette: VignetteConfig(enabled: true, intensity: 0.18, roundness: 0.80, feather: 0.55),
        bw: BWConfig(
            enabled: true,
            redWeight: 0.50,      // Orange filter boosts reds
            greenWeight: 0.40,
            blueWeight: 0.10,
            contrast: 0.18,
            brightness: 0.0,
            gamma: 0.95,
            toning: .none,
            grainIntensity: 0.25,
            grainSize: 1.2
        ),
        filmStock: FilmStock(manufacturer: "Kodak", name: "Tri-X 400 Orange", type: "Black & White Negative",
            characteristics: ["Orange filter effect", "Dramatic skies", "High contrast", "Classic B&W portrait"]))

    // MARK: - DIGICAM PRESETS

    static let canonIXY = FilterPreset(
        id: "CANON_IXY",
        label: "Canon IXY · 2000s Digicam",
        category: .digicam,
        colorAdjustments: ColorAdjustments(
            exposure: 0.05, contrast: 0.10, highlights: 0.08, shadows: -0.05,
            saturation: 0.12, vibrance: 0.08, temperature: 0.02, clarity: 0.15
        ),
        splitTone: SplitToneConfig(shadowsHue: 220, shadowsSat: 0.05, highlightsHue: 45, highlightsSat: 0.04),
        grain: GrainConfig(enabled: false),
        bloom: BloomConfig(enabled: true, intensity: 0.08, threshold: 0.72, radius: 12, softness: 0.75),
        vignette: VignetteConfig(enabled: true, intensity: 0.12, roundness: 0.80, feather: 0.65),
        ccdBloom: CCDBloomConfig(
            enabled: true,
            intensity: 0.35,
            threshold: 0.70,
            verticalSmear: 0.20,
            smearLength: 0.12,
            smearFalloff: 1.6,
            horizontalBloom: 0.12,
            horizontalRadius: 0.04,
            purpleFringing: 0.15,
            fringeWidth: 0.008,
            warmShift: 0.08
        ),
        digicamEffects: DigicamEffectsConfig(
            enabled: true,
            digitalNoise: DigitalNoiseConfig(enabled: true, intensity: 0.12, luminanceNoise: 0.10, chrominanceNoise: 0.08, banding: 0.04),
            jpegArtifacts: 0.08,
            whiteBalance: 0.03,
            sharpening: 0.45,
            timestamp: true
        ),
        dateStamp: DateStampConfig(enabled: true, format: .full, position: .bottomRight, color: .red, opacity: 0.85, scale: 0.8, glowEnabled: false),
        filmStock: FilmStock(manufacturer: "Canon", name: "IXY Digital", type: "CCD Digicam", speed: 400, year: 2003,
            characteristics: ["CCD sensor look", "Punchy colors", "Purple fringing", "Early 2000s aesthetic"]))

    static let sonyCybershot = FilterPreset(
        id: "SONY_CYBERSHOT",
        label: "Sony Cybershot · DSC Style",
        category: .digicam,
        colorAdjustments: ColorAdjustments(
            exposure: 0.03, contrast: 0.08, highlights: 0.10, shadows: -0.08,
            saturation: 0.08, vibrance: 0.05, temperature: -0.03, clarity: 0.12
        ),
        splitTone: SplitToneConfig(shadowsHue: 200, shadowsSat: 0.06, highlightsHue: 40, highlightsSat: 0.05),
        grain: GrainConfig(enabled: false),
        bloom: BloomConfig(enabled: true, intensity: 0.10, threshold: 0.68, radius: 14, softness: 0.78),
        vignette: VignetteConfig(enabled: true, intensity: 0.10, roundness: 0.85, feather: 0.70),
        ccdBloom: CCDBloomConfig(
            enabled: true,
            intensity: 0.45,
            threshold: 0.65,
            verticalSmear: 0.30,
            smearLength: 0.18,
            smearFalloff: 1.4,
            horizontalBloom: 0.18,
            horizontalRadius: 0.05,
            purpleFringing: 0.22,
            fringeWidth: 0.010,
            warmShift: 0.10
        ),
        digicamEffects: DigicamEffectsConfig(
            enabled: true,
            digitalNoise: DigitalNoiseConfig(enabled: true, intensity: 0.18, luminanceNoise: 0.15, chrominanceNoise: 0.12, banding: 0.06, hotPixels: 0.015),
            jpegArtifacts: 0.12,
            whiteBalance: -0.05,
            sharpening: 0.35,
            timestamp: true
        ),
        dateStamp: DateStampConfig(enabled: true, format: .japanese, position: .bottomRight, color: .orange, opacity: 0.85, scale: 0.85, glowEnabled: true, glowIntensity: 0.4),
        filmStock: FilmStock(manufacturer: "Sony", name: "Cybershot DSC", type: "CCD Digicam", speed: 400, year: 2004,
            characteristics: ["Heavy CCD bloom", "Vertical smear", "Purple fringing", "Sony color science"]))

    // MARK: - ALL PRESETS
    
    static let allPresets: [FilterPreset] = [
        // Professional
        kodakPortra400, kodakPortra160, fujiPro400H,
        // Consumer
        kodakUltramax400, kodakGold200, kodakColorPlus200, fujiSuperia400,
        // Slide
        fujiVelvia100, fujiProvia100F, fujiAstia100F,
        // Cinema
        fujiEterna500T,
        // Black & White
        kodakTriX400, triXOrange,
        // Instant
        polaroid600, instaxMini, polaroidSX70,
        // Disposable
        kodakFunSaver, fujiQuickSnap,
        // Food
        cafeMood, freshClean, goldenFood,
        // Night
        cineStill800T, cyberpunk,
        // Creative
        nostalgicNeg, classicNegative, butter, sakura, goldenHour, film35mm,
        // VHS
        vhsCamcorder, vhsPlayback,
        // Digicam
        canonIXY, sonyCybershot
    ]
    
    static func presets(for category: FilterCategory) -> [FilterPreset] {
        allPresets.filter { $0.category == category }
    }
    
    static func preset(byId id: String) -> FilterPreset? {
        allPresets.first { $0.id == id }
    }
}

// MARK: - Preset Manager

class PresetManager {
    static let shared = PresetManager()
    private init() {}
    
    func getAllPresets() -> [FilterPreset] { FilmPresets.allPresets }
    func getPresets(for category: FilterCategory) -> [FilterPreset] { FilmPresets.presets(for: category) }
    func getPreset(byId id: String) -> FilterPreset? { FilmPresets.preset(byId: id) }
    func getCategories() -> [FilterCategory] { FilterCategory.allCases }
    
    func getCategoryName(_ category: FilterCategory) -> String {
        switch category {
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
        case .vhs: return "VHS & Retro Video"
        case .digicam: return "Digital Camera (Y2K)"
        }
    }
}
