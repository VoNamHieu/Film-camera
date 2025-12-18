# LUT (Lookup Table) File Guide

## Overview

The Film Camera app supports 3D LUT (.cube) files for color grading. LUTs provide professional-grade color transformations similar to analog film stocks.

## File Format

### Supported Format
- **File Extension**: `.cube`
- **Type**: 3D Lookup Table (Adobe Cube format)
- **Texture Type**: 3D RGBA32Float Metal texture

### .cube File Structure

```
TITLE "My Film Stock"
LUT_3D_SIZE 33

# RGB triplets (0.0 - 1.0 range)
0.000000 0.000000 0.000000
0.031373 0.000000 0.000000
0.062745 0.000000 0.000000
...
```

**Key Elements**:
- `TITLE`: Optional name of the LUT
- `LUT_3D_SIZE`: Cube dimension (typically 17, 33, or 65)
- RGB values: One triplet per line (normalized 0.0-1.0)
- Total values: size³ × 3 (e.g., 33³ × 3 = 107,811 values)

## File Location

### Xcode Project Setup

1. **Create Resources folder** (if not exists):
   ```
   Film camera/
   └── Resources/
       └── LUTs/
           ├── kodak_portra_400.cube
           ├── fuji_velvia_50.cube
           └── cinematic_teal_orange.cube
   ```

2. **Add to Xcode**:
   - Drag LUT files into Xcode project navigator
   - Check "Copy items if needed"
   - Select target: "Film camera"
   - Verify in Build Phases → Copy Bundle Resources

## Usage in Code

### Loading LUT in FilterPreset

```swift
let preset = FilterPreset(
    id: "kodak_portra",
    label: "Kodak Portra 400",
    category: .professional,
    lutFile: "kodak_portra_400.cube",  // ← Filename
    lutIntensity: 0.8                    // ← Blend strength (0.0-1.0)
)
```

### LUT Loading Pipeline

```
FilterPreset.lutFile
    ↓
RenderEngine.loadLUT(named:)
    ↓
LUTLoader.load(filename:device:)
    ↓
Parse .cube file → [Float] RGB data
    ↓
Create MTLTexture (type3D, rgba32Float)
    ↓
Cache in RenderEngine.lutCache
    ↓
Pass to colorGradingFragment shader
```

## Creating LUTs

### Option 1: Professional Tools
- **DaVinci Resolve**: Export → LUT → 3D Cube (33×33×33)
- **Adobe Premiere**: Lumetri → Export LUT
- **Capture One**: Export Color Profile as LUT

### Option 2: Online Generators
- [LUT Generator](https://www.3dlutcreator.com/)
- [RocketStock LUTs](https://www.rocketstock.com/free-after-effects-templates/35-free-luts-for-color-grading-videos/)

### Option 3: Convert from Other Formats
```bash
# Using LUT Calculator (Windows/Mac)
lutcalc convert input.3dl -o output.cube -f 33
```

## Popular Film Stock LUTs

| Film Stock | Characteristics | Recommended Size |
|------------|----------------|------------------|
| Kodak Portra 400 | Warm skin tones, low contrast | 33×33×33 |
| Fuji Velvia 50 | High saturation, vivid colors | 33×33×33 |
| Kodak Vision3 500T | Cinematic teal-orange look | 33×33×33 |
| Ilford HP5 Plus | B&W with grain | 17×17×17 |

## Shader Implementation

### Fragment Shader Usage (Shaders.metal)

```metal
fragment float4 colorGradingFragment(
    VertexOut in [[stage_in]],
    texture2d<float> inputTexture [[texture(0)]],
    texture3d<float> lutTexture [[texture(1)]],  // ← 3D LUT
    constant ColorGradingParams& p [[buffer(0)]]
) {
    float3 color = inputTexture.sample(s, in.texCoord).rgb;

    // Apply color adjustments...

    // Apply LUT if enabled
    if (p.useLUT == 1) {
        constexpr sampler lutSampler(filter::linear, address::clamp_to_edge);
        float3 lutColor = lutTexture.sample(lutSampler, color).rgb;
        color = mix(color, lutColor, p.lutIntensity);
    }

    return float4(color, 1.0);
}
```

## Performance Considerations

### LUT Size vs Performance

| Size | Values | Memory | Speed | Recommended For |
|------|--------|--------|-------|-----------------|
| 17³ | 4,913 | ~20 KB | Fastest | Mobile preview |
| 33³ | 35,937 | ~144 KB | Fast | **Recommended** |
| 65³ | 274,625 | ~1.1 MB | Slower | High-end photos |

### Optimization Tips

1. **Use 33×33×33** for best quality/performance balance
2. **Cache LUTs**: RenderEngine automatically caches loaded LUTs
3. **Clear cache** if memory is limited:
   ```swift
   RenderEngine.shared.clearLUTCache()
   ```

## Troubleshooting

### LUT Not Loading

**Check Console Logs**:
```
❌ LUT file not found: my_lut.cube
→ File not in bundle. Add to Xcode project.

❌ Invalid LUT data: size=0, values=0
→ File corrupt or wrong format.

❌ Could not read LUT file: ...
→ File permissions or encoding issue.
```

**Debug Steps**:
1. Verify file is in Xcode project navigator
2. Check Build Phases → Copy Bundle Resources
3. Ensure filename matches exactly (case-sensitive)
4. Validate .cube format (use online validator)

### LUT Not Applying

**Check Shader Logs**:
```swift
// In RenderEngine.setupPipelines():
✅ RenderEngine: colorGradingPipeline created
→ Pipeline OK

// In FilterRenderer.applyColorGrading():
renderEncoder.setFragmentTexture(lutTexture, index: 1)
→ LUT passed to shader
```

**Verify Preset**:
```swift
print("LUT File: \(preset.lutFile ?? "nil")")
print("LUT Intensity: \(preset.lutIntensity)")
print("Use LUT: \(preset.lutFile != nil ? 1 : 0)")
```

## Example: Adding New LUT

### Step 1: Download LUT
```bash
curl -O https://example.com/kodak_gold_200.cube
```

### Step 2: Add to Xcode
1. Create `Film camera/Resources/LUTs/` folder
2. Drag `kodak_gold_200.cube` into Xcode
3. Check "Film camera" target

### Step 3: Create Preset (Models.swift or Presets/)
```swift
static let kodakGold = FilterPreset(
    id: "kodak_gold",
    label: "Kodak Gold 200",
    category: .vintage,
    lutFile: "kodak_gold_200.cube",
    lutIntensity: 0.75,
    colorAdjustments: ColorAdjustments(
        exposure: 0.1,
        contrast: 1.05,
        saturation: 1.1
    )
)
```

### Step 4: Test
```swift
let filtered = RenderEngine.shared.applyFilter(
    to: myImage,
    preset: .kodakGold
)
```

## Free LUT Resources

- [RocketStock 35 Free LUTs](https://www.rocketstock.com/free-after-effects-templates/35-free-luts-for-color-grading-videos/)
- [SpeedGrade LUTs](https://www.adobe.com/products/speedgrade/luts.html)
- [Dehancer Film LUTs](https://www.dehancer.com/)
- [LUT Generator Tool](https://lut.lutify.com/)

## Technical Details

### LUTLoader.swift Implementation

```swift
// Parse .cube file
for line in lines {
    if trimmed.hasPrefix("LUT_3D_SIZE") {
        size = Int(parts[1])
    }

    // Parse RGB triplets
    let values = trimmed.split(separator: " ").compactMap { Float($0) }
    if values.count >= 3 {
        data.append(contentsOf: values[0..<3])
    }
}

// Validate: size³ × 3 values
guard data.count == size * size * size * 3 else {
    return nil
}
```

### Metal Texture Creation

```swift
let descriptor = MTLTextureDescriptor()
descriptor.textureType = .type3D           // ← 3D texture!
descriptor.pixelFormat = .rgba32Float
descriptor.width = size
descriptor.height = size
descriptor.depth = size
descriptor.usage = .shaderRead

// Convert RGB → RGBA
for i in stride(from: 0, to: data.count, by: 3) {
    rgbaData.append(data[i])      // R
    rgbaData.append(data[i + 1])  // G
    rgbaData.append(data[i + 2])  // B
    rgbaData.append(1.0)          // A
}
```

## FAQ

**Q: Can I use .3dl files?**
A: Not directly. Convert to .cube using LUT Calculator or online tools.

**Q: Why aren't my LUTs applying?**
A: Check `lutIntensity` value. 0.0 = no effect, 1.0 = full effect.

**Q: Can I stack multiple LUTs?**
A: No, only one LUT per preset. Combine LUTs externally before importing.

**Q: Do LUTs work with all filters?**
A: Yes, LUTs are applied in the color grading pass before grain/bloom/etc.

**Q: How do I create a film-like look?**
A: Combine LUT with grain, halation, and slight vignette for authentic film emulation.

---

**Last Updated**: 2025-12-18
**Related Files**: `Engine/LUTLoader.swift`, `Engine/RenderEngine.swift`, `Shaders/Shaders.metal`
