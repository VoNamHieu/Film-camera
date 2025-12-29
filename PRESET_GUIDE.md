# 📚 Hướng Dẫn Thêm Filter/Preset - Film Camera iOS

## 📁 Cấu Trúc File Thực Tế

```
Film-camera/
├── Models.swift                    # ⭐ Tất cả configs (Grain, Bloom, etc.)
├── Presets/
│   └── FilmPresets_Complete.swift  # ⭐ Tất cả presets
├── Engine/
│   ├── FilterRenderer.swift        # Render pipeline
│   └── RenderEngine.swift          # Metal pipeline setup
├── Shaders/
│   ├── Shaders.metal              # Metal shaders
│   └── ShaderTypes.h              # Shader params
└── Models/
    └── EffectSystem.swift          # Effect state management
```

## 🎯 FilterPreset Struct (Models.swift:1125)

```swift
struct FilterPreset: Codable, Identifiable, Equatable {
    let id: String
    let label: String
    let category: FilterCategory

    // LUT
    var lutId: String?
    var lutFile: String?
    var lutIntensity: Float
    var colorSpace: String

    // Core
    var colorAdjustments: ColorAdjustments
    var splitTone: SplitToneConfig
    var selectiveColor: [SelectiveColorAdjustment]
    var lensDistortion: LensDistortionConfig
    var rgbCurves: RGBCurves

    // Film Effects
    var grain: GrainConfig
    var bloom: BloomConfig
    var vignette: VignetteConfig
    var halation: HalationConfig

    // Special Effects
    var instantFrame: InstantFrameConfig
    var flash: FlashConfig
    var lightLeak: LightLeakConfig
    var dateStamp: DateStampConfig
    var ccdBloom: CCDBloomConfig
    var bw: BWConfig
    var overlays: OverlaysConfig

    // Processing
    var skinToneProtection: SkinToneProtection
    var toneMapping: ToneMapping
    var filmStock: FilmStock
}
```

## 📋 Categories Hiện Có (Models.swift:10)

```swift
enum FilterCategory: String, CaseIterable, Codable, Equatable {
    case professional   // Portra, Pro 400H
    case slide          // Velvia, Provia
    case consumer       // Ultramax, Gold, Superia
    case cinema         // Eterna, CineStill
    case blackAndWhite  // Tri-X, Tri-X Orange
    case instant        // Polaroid, Instax
    case disposable     // FunSaver, QuickSnap
    case food           // Cafe, Fresh, Golden
    case night          // CineStill 800T, Cyberpunk
    case creative       // Nostalgic Neg, Classic Neg, Butter, Sakura, Golden Hour, Film 35mm
    case vhs            // VHS Camcorder, VHS Playback
    case digicam        // Canon IXY, Sony Cybershot
}
```

## 🔧 Thêm Preset Mới

### Bước 1: Mở `Presets/FilmPresets_Complete.swift`

### Bước 2: Thêm preset (copy template này):

```swift
static let myNewPreset = FilterPreset(
    id: "MY_PRESET_ID",                    // Unique ID
    label: "My Preset · Description",       // Hiển thị trong UI
    category: .creative,                    // Category

    // === LUT (optional) ===
    lutId: nil,                             // hoặc "MY_LUT"
    lutFile: nil,                           // hoặc "MyLUT.cube"
    colorSpace: "srgb",                     // "srgb" hoặc "linear"

    // === COLOR ADJUSTMENTS ===
    colorAdjustments: ColorAdjustments(
        exposure: 0.0,      // -1.0 to 1.0
        contrast: 0.0,      // -1.0 to 1.0
        highlights: 0.0,    // -1.0 to 1.0
        shadows: 0.0,       // -1.0 to 1.0
        whites: 0.0,        // -1.0 to 1.0
        blacks: 0.0,        // -1.0 to 1.0
        saturation: 0.0,    // -1.0 to 1.0
        vibrance: 0.0,      // -1.0 to 1.0
        temperature: 0.0,   // -1.0 (cool) to 1.0 (warm)
        tint: 0.0,          // -1.0 to 1.0
        fade: 0.0,          // 0.0 to 0.5 (lifted blacks)
        clarity: 0.0        // -1.0 to 1.0
    ),

    // === SPLIT TONE ===
    splitTone: SplitToneConfig(
        shadowsHue: 200,        // 0-360 (blue tint in shadows)
        shadowsSat: 0.10,       // 0.0-1.0
        highlightsHue: 40,      // 0-360 (warm highlights)
        highlightsSat: 0.08,    // 0.0-1.0
        balance: 0.0,           // -1.0 to 1.0
        midtoneProtection: 0.3  // 0.0-1.0
    ),

    // === GRAIN ===
    grain: GrainConfig(
        enabled: true,
        globalIntensity: 0.15,  // 0.0-0.5 (typical: 0.08-0.20)
        channels: GrainChannels(
            red: GrainChannel(intensity: 0.15, size: 1.0, seed: 1001, softness: 0.5),
            green: GrainChannel(intensity: 0.15, size: 1.0, seed: 1002, softness: 0.5),
            blue: GrainChannel(intensity: 0.18, size: 1.1, seed: 1003, softness: 0.5)
        ),
        texture: GrainTexture(
            type: "perlin",
            octaves: 2,
            persistence: 0.5,
            lacunarity: 2.0,
            baseFrequency: 1.0
        )
    ),

    // === BLOOM ===
    bloom: BloomConfig(
        enabled: true,
        intensity: 0.08,        // 0.0-0.5 (typical: 0.04-0.15)
        threshold: 0.75,        // 0.5-1.0 (lower = more bloom)
        radius: 12,             // 5-30 (blur radius)
        softness: 0.75,         // 0.5-1.0
        colorTint: ColorTint(r: 1.0, g: 0.98, b: 0.95)
    ),

    // === VIGNETTE ===
    vignette: VignetteConfig(
        enabled: true,
        intensity: 0.12,        // 0.0-0.5
        roundness: 0.8,         // 0.0-1.0 (1.0 = circular)
        feather: 0.6,           // 0.3-1.0 (soft edge)
        midpoint: 0.5           // 0.3-0.7
    ),

    // === HALATION (Red glow - CineStill style) ===
    halation: HalationConfig(
        enabled: false,         // Usually false, enable for cinema look
        color: HalationColor(r: 1.0, g: 0.3, b: 0.15),
        intensity: 0.3,         // 0.0-0.6
        threshold: 0.7,         // 0.5-0.9
        radius: 25,             // 15-40
        softness: 0.85          // 0.7-1.0
    ),

    // === CCD BLOOM (Digital camera bloom) ===
    ccdBloom: CCDBloomConfig(
        enabled: false,
        intensity: 0.3,
        threshold: 0.7,
        spread: 0.5,
        verticalSmear: 0.3,
        purpleFringing: 0.2
    ),

    // === BLACK & WHITE ===
    bw: BWConfig(
        enabled: false,         // Enable for B&W preset
        redWeight: 0.299,
        greenWeight: 0.587,
        blueWeight: 0.114,
        contrast: 0.0,
        brightness: 0.0,
        gamma: 1.0,
        toning: .none,          // .none, .sepia, .selenium, .cyanotype
        toningIntensity: 0.5
    ),

    // === OVERLAYS (Dust & Scratches) ===
    overlays: OverlaysConfig(
        enabled: false,
        dust: DustConfig(enabled: true, density: 0.3, opacity: 0.5),
        scratches: ScratchesConfig(enabled: true, density: 0.2, opacity: 0.4)
    ),

    // === FILM STOCK INFO ===
    filmStock: FilmStock(
        manufacturer: "Brand",
        name: "Film Name",
        type: "Color Negative (C-41)",
        speed: 400,
        year: 2024,
        characteristics: [
            "Feature 1",
            "Feature 2",
            "Feature 3"
        ]
    )
)
```

### Bước 3: Thêm vào `allPresets` array (line ~678)

```swift
static let allPresets: [FilterPreset] = [
    // Professional
    kodakPortra400, kodakPortra160, fujiPro400H,
    // ... existing presets ...
    // ⭐ ADD NEW:
    myNewPreset
]
```

## 📊 Giá Trị Tham Khảo Theo Style

### Film Look (Natural)
```swift
grain: globalIntensity: 0.12-0.18
bloom: intensity: 0.04-0.08, threshold: 0.75-0.85
vignette: intensity: 0.08-0.15
```

### Dreamy/Soft
```swift
bloom: intensity: 0.15-0.30, threshold: 0.55-0.70
fade: 0.05-0.10
contrast: -0.10 to -0.20
```

### Cinema/Cinematic
```swift
halation: enabled: true, intensity: 0.25-0.40
bloom: intensity: 0.10-0.20
colorAdjustments: temperature: 0.05-0.15 (warm) or -0.05 to -0.15 (cool)
```

### Vintage/Faded
```swift
fade: 0.08-0.15
saturation: -0.15 to -0.25
grain: globalIntensity: 0.20-0.30
overlays: enabled: true
```

### High Contrast B&W
```swift
bw: enabled: true, contrast: 0.20-0.40
grain: globalIntensity: 0.25-0.35
vignette: intensity: 0.15-0.25
```

## ✅ Checklist

```
□ 1. Tạo preset với unique ID
□ 2. Chọn category phù hợp
□ 3. Config color adjustments
□ 4. Enable/config effects cần thiết (grain, bloom, vignette)
□ 5. Thêm filmStock metadata
□ 6. Thêm vào allPresets array
□ 7. Build và test
```

## 🎨 Presets Hiện Có (33 presets)

| Category | Presets |
|----------|---------|
| Professional | Portra 400, Portra 160, Pro 400H |
| Consumer | Ultramax 400, Gold 200, ColorPlus, Superia |
| Slide | Velvia 100, Provia 100F, Astia 100F |
| Cinema | Eterna 500T |
| B&W | Tri-X 400, Tri-X Orange |
| Instant | Polaroid 600, Instax Mini, SX-70 |
| Disposable | FunSaver, QuickSnap |
| Food | Cafe Mood, Fresh Clean, Golden Food |
| Night | CineStill 800T, Cyberpunk |
| Creative | Nostalgic Neg, Classic Neg, Butter, Sakura, Golden Hour, Film 35mm |
| VHS | VHS Camcorder, VHS Playback |
| Digicam | Canon IXY, Sony Cybershot |

## 🆕 New Effect Configs

### VHSEffectsConfig
```swift
vhsEffects: VHSEffectsConfig(
    enabled: true,
    scanlines: ScanlineConfig(enabled: true, intensity: 0.15, density: 1.0),
    colorBleed: ColorBleedConfig(enabled: true, intensity: 0.3, redShift: 0.005, blueShift: 0.003),
    tracking: TrackingConfig(enabled: false),  // Enable for worn tape look
    noiseIntensity: 0.15,
    saturationLoss: 0.1,
    sharpnessLoss: 0.2,
    dateOverlay: true
)
```

### DigicamEffectsConfig
```swift
digicamEffects: DigicamEffectsConfig(
    enabled: true,
    digitalNoise: DigitalNoiseConfig(enabled: true, intensity: 0.15, luminanceNoise: 0.12, chrominanceNoise: 0.10),
    jpegArtifacts: 0.1,
    whiteBalance: 0.05,
    sharpening: 0.4,
    timestamp: true
)
```

### FilmStripEffectsConfig
```swift
filmStripEffects: FilmStripEffectsConfig(
    enabled: true,
    perforations: .standard35mm,  // .none, .standard35mm, .cinema, .super8
    borderColor: ColorTint(r: 0.12, g: 0.08, b: 0.04),
    borderOpacity: 0.95,
    frameLineWidth: 0.003,
    frameLineOpacity: 0.8,
    rebateVisible: true,
    rebateText: "KODAK 400TX",
    frameNumber: true,
    kodakStyle: true  // Orange Kodak rebate
)
```
