#include <metal_stdlib>
using namespace metal;

#include "ShaderTypes.h"

// ═══════════════════════════════════════════════════════════════
// LINEAR COLOR SPACE UTILITIES
// ═══════════════════════════════════════════════════════════════

// sRGB → Linear (Gamma decode)
float srgbToLinear(float c) {
    return (c <= 0.04045) ? (c / 12.92) : pow((c + 0.055) / 1.055, 2.4);
}

float3 srgbToLinear3(float3 c) {
    return float3(srgbToLinear(c.r), srgbToLinear(c.g), srgbToLinear(c.b));
}

// Linear → sRGB (Gamma encode)
float linearToSrgb(float c) {
    return (c <= 0.0031308) ? (c * 12.92) : (1.055 * pow(c, 1.0/2.4) - 0.055);
}

float3 linearToSrgb3(float3 c) {
    return float3(linearToSrgb(c.r), linearToSrgb(c.g), linearToSrgb(c.b));
}

// ═══════════════════════════════════════════════════════════════
// COMMON VERTEX SHADER
// ═══════════════════════════════════════════════════════════════

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

vertex VertexOut vertexPassthrough(uint vertexID [[vertex_id]]) {
    float2 positions[4] = {
        float2(-1, -1), float2(1, -1), float2(-1, 1), float2(1, 1)
    };
    float2 texCoords[4] = {
        float2(0, 1), float2(1, 1), float2(0, 0), float2(1, 0)
    };

    VertexOut out;
    out.position = float4(positions[vertexID], 0, 1);
    out.texCoord = texCoords[vertexID];
    return out;
}

// ★★★ NEW: Aspect-Fill Vertex Shader ★★★
// Scales UV to perform aspect-fill (crop to fill, maintain aspect ratio)
vertex VertexOut vertexAspectFill(uint vertexID [[vertex_id]],
                                   constant AspectScaleParams &aspect [[buffer(0)]]) {
    float2 positions[4] = {
        float2(-1, -1), float2(1, -1), float2(-1, 1), float2(1, 1)
    };
    float2 texCoords[4] = {
        float2(0, 1), float2(1, 1), float2(0, 0), float2(1, 0)
    };

    VertexOut out;
    out.position = float4(positions[vertexID], 0, 1);

    // Calculate aspect-fill UV correction
    float2 uv = texCoords[vertexID];

    float inputAspect = aspect.inputAspect;
    float outputAspect = aspect.outputAspect;

    if (outputAspect > inputAspect) {
        // Output is wider: crop top/bottom
        float scale = outputAspect / inputAspect;
        uv.y = (uv.y - 0.5) / scale + 0.5;
    } else if (outputAspect < inputAspect) {
        // Output is taller: crop left/right
        float scale = inputAspect / outputAspect;
        uv.x = (uv.x - 0.5) / scale + 0.5;
    }

    out.texCoord = uv;
    return out;
}

// ═══════════════════════════════════════════════════════════════
// UTILITY FUNCTIONS
// ═══════════════════════════════════════════════════════════════

float luminance(float3 color) {
    return dot(color, float3(0.2126, 0.7152, 0.0722));
}

float3 rgb2hsl(float3 c) {
    float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    float4 p = mix(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
    float4 q = mix(float4(p.xyw, c.r), float4(c.r, p.yzx), step(p.x, c.r));

    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return float3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

float3 hsl2rgb(float3 c) {
    float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    float3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

float3 hueToRGB(float hue) {
    float3 rgb = abs(fmod(hue * 6.0 + float3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0;
    return saturate(rgb);
}

// Perlin-like noise
float random(float2 st, uint seed) {
    return fract(sin(dot(st + float2(seed), float2(12.9898, 78.233))) * 43758.5453);
}

float noise2D(float2 st, uint seed) {
    float2 i = floor(st);
    float2 f = fract(st);
    float a = random(i, seed);
    float b = random(i + float2(1.0, 0.0), seed);
    float c = random(i + float2(0.0, 1.0), seed);
    float d = random(i + float2(1.0, 1.0), seed);
    float2 u = f * f * (3.0 - 2.0 * f);
    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

// Gaussian weight
float gaussianWeight(float x, float sigma) {
    return exp(-(x * x) / (2.0 * sigma * sigma));
}

// ═══════════════════════════════════════════════════════════════
// ★★★ NEW: RGB CURVES FUNCTIONS ★★★
// ═══════════════════════════════════════════════════════════════

// Evaluate a single curve at input value using linear interpolation
// between control points. Uses Catmull-Rom spline for smoothness.
float evaluateCurve(float input, constant CurvePoint* curve, int pointCount) {
    if (pointCount <= 0) return input;
    if (pointCount == 1) return curve[0].output;
    
    // Clamp input to valid range
    input = saturate(input);
    
    // Find the two points to interpolate between
    int idx = 0;
    for (int i = 0; i < pointCount - 1; i++) {
        if (input >= curve[i].input && input <= curve[i + 1].input) {
            idx = i;
            break;
        }
        if (i == pointCount - 2) {
            idx = i; // Fallback to last segment
        }
    }
    
    // Get the four control points for Catmull-Rom (or use endpoints)
    float2 p0 = float2(curve[max(0, idx - 1)].input, curve[max(0, idx - 1)].output);
    float2 p1 = float2(curve[idx].input, curve[idx].output);
    float2 p2 = float2(curve[min(idx + 1, pointCount - 1)].input, curve[min(idx + 1, pointCount - 1)].output);
    float2 p3 = float2(curve[min(idx + 2, pointCount - 1)].input, curve[min(idx + 2, pointCount - 1)].output);
    
    // Calculate t parameter (0-1 within this segment)
    float segmentWidth = p2.x - p1.x;
    float t = (segmentWidth > 0.0001) ? (input - p1.x) / segmentWidth : 0.0;
    t = saturate(t);
    
    // Catmull-Rom spline interpolation
    float t2 = t * t;
    float t3 = t2 * t;
    
    float output = 0.5 * (
        (2.0 * p1.y) +
        (-p0.y + p2.y) * t +
        (2.0 * p0.y - 5.0 * p1.y + 4.0 * p2.y - p3.y) * t2 +
        (-p0.y + 3.0 * p1.y - 3.0 * p2.y + p3.y) * t3
    );
    
    return saturate(output);
}

// Apply RGB curves to a color
float3 applyRGBCurves(float3 color, constant RGBCurvesParams& curves) {
    if (curves.enabled == 0) return color;
    
    float3 result = color;
    
    // Apply each channel curve
    if (curves.redPointCount > 0) {
        result.r = evaluateCurve(color.r, curves.redCurve, curves.redPointCount);
    }
    if (curves.greenPointCount > 0) {
        result.g = evaluateCurve(color.g, curves.greenCurve, curves.greenPointCount);
    }
    if (curves.bluePointCount > 0) {
        result.b = evaluateCurve(color.b, curves.blueCurve, curves.bluePointCount);
    }
    
    return result;
}

// ═══════════════════════════════════════════════════════════════
// 1. LENS DISTORTION SHADER (Disposable Camera Effect)
// ═══════════════════════════════════════════════════════════════

fragment float4 lensDistortionFragment(VertexOut in [[stage_in]],
                                       texture2d<float> inputTexture [[texture(0)]],
                                       constant LensDistortionParams &p [[buffer(0)]]) {
    constexpr sampler s(filter::linear, address::clamp_to_edge);

    if (p.enabled == 0) {
        return inputTexture.sample(s, in.texCoord);
    }

    float2 uv = in.texCoord;
    float2 center = float2(0.5, 0.5);
    float2 dc = uv - center;
    float r2 = dot(dc, dc);

    float distortion = 1.0 + p.k1 * r2 + p.k2 * r2 * r2;

    float2 uvR = center + dc * distortion * (1.0 - p.caStrength) * p.scale;
    float2 uvG = center + dc * distortion * p.scale;
    float2 uvB = center + dc * distortion * (1.0 + p.caStrength) * p.scale;

    float r = inputTexture.sample(s, uvR).r;
    float g = inputTexture.sample(s, uvG).g;
    float b = inputTexture.sample(s, uvB).b;

    return float4(r, g, b, 1.0);
}

// ═══════════════════════════════════════════════════════════════
// 2. COLOR GRADING SHADER (Core Engine) ★★★ WITH RGB CURVES ★★★
// ═══════════════════════════════════════════════════════════════

fragment float4 colorGradingFragment(
    VertexOut in [[stage_in]],
    texture2d<float> inputTexture [[texture(0)]],
    texture3d<float> lutTexture [[texture(1)]],
    constant ColorGradingParams &p [[buffer(0)]]
) {
    constexpr sampler s(filter::linear, address::clamp_to_edge);
    constexpr sampler lutSampler(filter::linear, address::clamp_to_edge);

    float4 color = inputTexture.sample(s, in.texCoord);
    
    // ★ Convert to LINEAR space for accurate processing
    float3 rgb = srgbToLinear3(color.rgb);

    // === 1. BASIC CORRECTIONS ===
    rgb *= pow(2.0, p.exposure);
    rgb = (rgb - 0.5) * (1.0 + p.contrast) + 0.5;

    float luma = luminance(rgb);
    float shadowMask = 1.0 - smoothstep(0.0, 0.5, luma);
    float highlightMask = smoothstep(0.5, 1.0, luma);

    rgb += p.shadows * shadowMask * 0.2;
    rgb += p.highlights * highlightMask * 0.2;
    rgb += p.whites * smoothstep(0.8, 1.0, luma) * 0.15;
    rgb += p.blacks * (1.0 - smoothstep(0.0, 0.2, luma)) * 0.15;

    rgb.r += p.temperature * 0.1;
    rgb.b -= p.temperature * 0.1;
    rgb.g += p.tint * 0.05;

    // === 2. ★★★ RGB CURVES (NEW) ★★★ ===
    rgb = applyRGBCurves(rgb, p.rgbCurves);

    // === 3. SELECTIVE COLOR (Fixed hue normalization) ===
    if (p.selectiveColorCount > 0) {
        float3 hsl = rgb2hsl(rgb);

        for (int i = 0; i < p.selectiveColorCount; i++) {
            SelectiveColorData adj = p.selectiveColors[i];

            // ★ FIX: Normalize hue to 0-1 (adj.hue might be 0-360)
            float targetHue = adj.hue;
            if (targetHue > 1.0) targetHue /= 360.0;
            
            float dist = abs(hsl.x - targetHue);
            if (dist > 0.5) dist = 1.0 - dist;

            // ★ FIX: Normalize range as well
            float rangeNorm = adj.range;
            if (rangeNorm > 1.0) rangeNorm /= 360.0;
            
            float mask = 1.0 - smoothstep(0.0, rangeNorm, dist);

            if (mask > 0.0) {
                hsl.x += adj.hueShift * mask;
                if (hsl.x > 1.0) hsl.x -= 1.0;
                if (hsl.x < 0.0) hsl.x += 1.0;
                hsl.y = clamp(hsl.y * (1.0 + adj.satAdj * mask), 0.0, 1.0);
                hsl.z = clamp(hsl.z * (1.0 + adj.lumAdj * mask * 0.5), 0.0, 1.0);
            }
        }
        rgb = hsl2rgb(hsl);
    }

    // === 4. SATURATION & VIBRANCE ===
    luma = luminance(rgb);
    rgb = mix(float3(luma), rgb, 1.0 + p.saturation);

    float maxChannel = max(max(rgb.r, rgb.g), rgb.b);
    float minChannel = min(min(rgb.r, rgb.g), rgb.b);
    float colorfulness = maxChannel - minChannel;
    rgb = mix(float3(luma), rgb, 1.0 + p.vibrance * (1.0 - colorfulness));

    // === 5. LUT LOOKUP ===
    if (p.useLUT > 0 && p.lutIntensity > 0) {
        float3 lutCoord = saturate(rgb);
        float3 lutColor = lutTexture.sample(lutSampler, lutCoord).rgb;
        rgb = mix(rgb, lutColor, p.lutIntensity);
    }

    // === 6. FADE & CLARITY ===
    rgb = mix(rgb, float3(1.0), p.fade * (1.0 - rgb) * 0.15);

    if (abs(p.clarity) > 0.001) {
        rgb += (luma - 0.5) * p.clarity * 0.5;
    }

    // === 7. SPLIT TONING ===
    if (p.shadowsSat > 0 || p.highlightsSat > 0) {
        float3 shadowTint = hueToRGB(p.shadowsHue / 360.0);
        float3 highlightTint = hueToRGB(p.highlightsHue / 360.0);

        float midtoneMask = 1.0 - abs(luma - 0.5) * 2.0;
        float sStr = shadowMask * (1.0 - midtoneMask * p.midtoneProtection);
        float hStr = highlightMask * (1.0 - midtoneMask * p.midtoneProtection);

        rgb = mix(rgb, rgb * shadowTint, sStr * p.shadowsSat * 0.3);
        rgb = mix(rgb, rgb * highlightTint, hStr * p.highlightsSat * 0.3);
    }

    // ★ Convert back to sRGB
    rgb = linearToSrgb3(saturate(rgb));
    
    return float4(rgb, color.a);
}

// ═══════════════════════════════════════════════════════════════
// 3. GRAIN SHADER (Enhanced)
// ═══════════════════════════════════════════════════════════════

fragment float4 grainFragment(
    VertexOut in [[stage_in]],
    texture2d<float> inputTexture [[texture(0)]],
    constant GrainParams &p [[buffer(0)]]
) {
    constexpr sampler s(filter::linear);
    float4 color = inputTexture.sample(s, in.texCoord);

    if (p.enabled == 0) return color;

    // Convert to linear for processing
    float3 rgb = srgbToLinear3(color.rgb);
    
    float2 texSize = float2(inputTexture.get_width(), inputTexture.get_height());
    float2 grainCoord = in.texCoord * texSize / (p.size * 2.0);

    // Generate noise per channel
    float3 noise;
    noise.r = noise2D(grainCoord, 100);
    noise.g = noise2D(grainCoord, 200);
    noise.b = noise2D(grainCoord, 300);
    noise = (noise - 0.5) * 2.0;

    // Density Curve: grain peaks at midtones
    float luma = luminance(rgb);
    float density = 1.0 - smoothstep(0.0, 1.0, abs(luma - 0.5) * 2.5);

    // Apply grain in linear space
    rgb += noise * p.channelIntensity * p.globalIntensity * density * 0.1;

    // Convert back to sRGB
    rgb = linearToSrgb3(saturate(rgb));
    
    return float4(rgb, color.a);
}

// ═══════════════════════════════════════════════════════════════
// 4. SEPARABLE BLOOM PIPELINE (4 passes)
// ═══════════════════════════════════════════════════════════════

// Pass 1: Threshold extraction
fragment float4 bloomThresholdFragment(
    VertexOut in [[stage_in]],
    texture2d<float> inputTexture [[texture(0)]],
    constant BloomParams &p [[buffer(0)]]
) {
    constexpr sampler s(filter::linear, address::clamp_to_edge);
    float4 color = inputTexture.sample(s, in.texCoord);
    
    if (p.enabled == 0) return float4(0.0);
    
    float3 rgb = srgbToLinear3(color.rgb);
    float luma = luminance(rgb);
    
    // Soft threshold extraction
    float softThreshold = p.threshold * 0.7;
    if (luma > softThreshold) {
        float t = max(0.0, (luma - softThreshold) / (1.0 - softThreshold));
        float bloomStrength = pow(t, 1.5);
        
        float3 bloom = rgb * bloomStrength * p.colorTint;
        return float4(bloom, 1.0);
    }
    
    return float4(0.0, 0.0, 0.0, 1.0);
}

// Pass 2: Horizontal Gaussian blur - O(n)
fragment float4 bloomHorizontalFragment(
    VertexOut in [[stage_in]],
    texture2d<float> inputTexture [[texture(0)]],
    constant BloomParams &p [[buffer(0)]]
) {
    constexpr sampler s(filter::linear, address::clamp_to_edge);
    
    float2 texelSize = 1.0 / float2(inputTexture.get_width(), inputTexture.get_height());
    // ★ FIX: Cap radius for performance
    int radius = min(int(p.radius), 20);
    float sigma = float(radius) / 3.0;
    
    float3 result = float3(0.0);
    float totalWeight = 0.0;
    
    // ★ SEPARABLE: Only horizontal - O(n) instead of O(n²)
    for (int x = -radius; x <= radius; x++) {
        float2 offset = float2(float(x) * texelSize.x, 0.0);
        float weight = gaussianWeight(float(x), sigma);
        
        result += inputTexture.sample(s, in.texCoord + offset).rgb * weight;
        totalWeight += weight;
    }
    
    return float4(result / totalWeight, 1.0);
}

// Pass 3: Vertical Gaussian blur - O(n)
fragment float4 bloomVerticalFragment(
    VertexOut in [[stage_in]],
    texture2d<float> inputTexture [[texture(0)]],
    constant BloomParams &p [[buffer(0)]]
) {
    constexpr sampler s(filter::linear, address::clamp_to_edge);
    
    float2 texelSize = 1.0 / float2(inputTexture.get_width(), inputTexture.get_height());
    // ★ FIX: Cap radius for performance
    int radius = min(int(p.radius), 20);
    float sigma = float(radius) / 3.0;
    
    float3 result = float3(0.0);
    float totalWeight = 0.0;
    
    // ★ SEPARABLE: Only vertical - O(n) instead of O(n²)
    for (int y = -radius; y <= radius; y++) {
        float2 offset = float2(0.0, float(y) * texelSize.y);
        float weight = gaussianWeight(float(y), sigma);
        
        result += inputTexture.sample(s, in.texCoord + offset).rgb * weight;
        totalWeight += weight;
    }
    
    return float4(result / totalWeight, 1.0);
}

// Pass 4: Composite bloom with original
fragment float4 bloomCompositeFragment(
    VertexOut in [[stage_in]],
    texture2d<float> originalTexture [[texture(0)]],
    texture2d<float> bloomTexture [[texture(1)]],
    constant BloomParams &p [[buffer(0)]]
) {
    constexpr sampler s(filter::linear, address::clamp_to_edge);
    
    float4 original = originalTexture.sample(s, in.texCoord);
    float3 bloom = bloomTexture.sample(s, in.texCoord).rgb;
    
    // Convert to linear for additive blend
    float3 rgb = srgbToLinear3(original.rgb);
    
    // ★ Additive blend in linear space (physically correct)
    rgb = rgb + bloom * p.intensity * p.softness;
    
    // Convert back to sRGB
    rgb = linearToSrgb3(saturate(rgb));
    
    return float4(rgb, original.a);
}

// Legacy single-pass bloom (for backwards compatibility, but slow)
fragment float4 bloomFragment(
    VertexOut in [[stage_in]],
    texture2d<float> inputTexture [[texture(0)]],
    constant BloomParams &p [[buffer(0)]]
) {
    constexpr sampler s(filter::linear, address::clamp_to_edge);
    float4 color = inputTexture.sample(s, in.texCoord);

    if (p.enabled == 0) return color;

    // ⚠️ Legacy nested loop - use separable pipeline instead!
    float3 bloom = float3(0.0);
    float totalWeight = 0.0;
    int radius = min(int(p.radius), 15);  // ★ Cap for performance
    float2 texelSize = 1.0 / float2(inputTexture.get_width(), inputTexture.get_height());

    for (int x = -radius; x <= radius; x+=2) {
        for (int y = -radius; y <= radius; y+=2) {
            float2 offset = float2(x, y) * texelSize;
            float3 sample = inputTexture.sample(s, in.texCoord + offset).rgb;
            float bLuma = luminance(sample);

            if (bLuma > p.threshold) {
                float weight = exp(-(float(x*x + y*y)) / (2.0 * (p.radius/2.0) * (p.radius/2.0)));
                bloom += sample * weight;
                totalWeight += weight;
            }
        }
    }

    if (totalWeight > 0.0) {
        bloom /= totalWeight;
        color.rgb += bloom * p.intensity * p.colorTint;
    }

    return saturate(color);
}

// ═══════════════════════════════════════════════════════════════
// 5. SEPARABLE HALATION PIPELINE (4 passes)
// ═══════════════════════════════════════════════════════════════

// Pass 1: Extract bright spots and apply red-orange tint
fragment float4 halationThresholdFragment(
    VertexOut in [[stage_in]],
    texture2d<float> inputTexture [[texture(0)]],
    constant HalationParams &p [[buffer(0)]]
) {
    constexpr sampler s(filter::linear, address::clamp_to_edge);
    float4 color = inputTexture.sample(s, in.texCoord);
    
    if (p.enabled == 0) return float4(0.0);
    
    float3 rgb = srgbToLinear3(color.rgb);
    float luma = luminance(rgb);
    
    if (luma > p.threshold) {
        // Calculate excess brightness
        float excess = (luma - p.threshold) / (1.0 - p.threshold);
        excess = pow(excess, 1.5);  // Sharper falloff
        
        // ★ Apply halation color tint (red-orange for Cinestill)
        float3 halation = rgb * excess * p.color;
        return float4(halation, 1.0);
    }
    
    return float4(0.0, 0.0, 0.0, 1.0);
}

// Pass 2: Horizontal blur for halation
fragment float4 halationHorizontalFragment(
    VertexOut in [[stage_in]],
    texture2d<float> inputTexture [[texture(0)]],
    constant HalationParams &p [[buffer(0)]]
) {
    constexpr sampler s(filter::linear, address::clamp_to_edge);
    
    float2 texelSize = 1.0 / float2(inputTexture.get_width(), inputTexture.get_height());
    // ★ FIX: Cap radius for performance
    int radius = min(int(p.radius), 25);
    float sigma = float(radius) / 2.5;  // Wider spread for halation
    
    float3 result = float3(0.0);
    float totalWeight = 0.0;
    
    for (int x = -radius; x <= radius; x++) {
        float2 offset = float2(float(x) * texelSize.x, 0.0);
        float weight = gaussianWeight(float(x), sigma);
        
        result += inputTexture.sample(s, in.texCoord + offset).rgb * weight;
        totalWeight += weight;
    }
    
    return float4(result / totalWeight, 1.0);
}

// Pass 3: Vertical blur for halation
fragment float4 halationVerticalFragment(
    VertexOut in [[stage_in]],
    texture2d<float> inputTexture [[texture(0)]],
    constant HalationParams &p [[buffer(0)]]
) {
    constexpr sampler s(filter::linear, address::clamp_to_edge);
    
    float2 texelSize = 1.0 / float2(inputTexture.get_width(), inputTexture.get_height());
    // ★ FIX: Cap radius for performance
    int radius = min(int(p.radius), 25);
    float sigma = float(radius) / 2.5;
    
    float3 result = float3(0.0);
    float totalWeight = 0.0;
    
    for (int y = -radius; y <= radius; y++) {
        float2 offset = float2(0.0, float(y) * texelSize.y);
        float weight = gaussianWeight(float(y), sigma);
        
        result += inputTexture.sample(s, in.texCoord + offset).rgb * weight;
        totalWeight += weight;
    }
    
    // Apply softness (gamma)
    result = pow(result / totalWeight, float3(p.softness));
    
    return float4(result, 1.0);
}

// Pass 4: Composite halation with original (ADDITIVE blend)
fragment float4 halationCompositeFragment(
    VertexOut in [[stage_in]],
    texture2d<float> originalTexture [[texture(0)]],
    texture2d<float> halationTexture [[texture(1)]],
    constant HalationParams &p [[buffer(0)]]
) {
    constexpr sampler s(filter::linear, address::clamp_to_edge);
    
    float4 original = originalTexture.sample(s, in.texCoord);
    float3 halation = halationTexture.sample(s, in.texCoord).rgb;
    
    // Convert to linear for physically correct additive blend
    float3 rgb = srgbToLinear3(original.rgb);
    
    // ★ ADDITIVE blend (physically correct light addition)
    rgb = min(float3(1.0), rgb + halation * p.intensity);
    
    // Convert back to sRGB
    rgb = linearToSrgb3(rgb);
    
    return float4(rgb, original.a);
}

// Legacy single-pass halation (slow, for backwards compatibility)
fragment float4 halationFragment(
    VertexOut in [[stage_in]],
    texture2d<float> inputTexture [[texture(0)]],
    constant HalationParams &p [[buffer(0)]]
) {
    constexpr sampler s(filter::linear, address::clamp_to_edge);
    float4 color = inputTexture.sample(s, in.texCoord);

    if (p.enabled == 0) return color;

    // ⚠️ Legacy nested loop - use separable pipeline instead!
    float3 halo = float3(0.0);
    float totalWeight = 0.0;
    int radius = min(int(p.radius), 20);  // ★ Cap for performance
    float2 texelSize = 1.0 / float2(inputTexture.get_width(), inputTexture.get_height());

    for (int x = -radius; x <= radius; x+=3) {
        for (int y = -radius; y <= radius; y+=3) {
            float2 offset = float2(x, y) * texelSize;
            float3 sample = inputTexture.sample(s, in.texCoord + offset).rgb;
            float bLuma = luminance(sample);

            if (bLuma > p.threshold) {
                float weight = exp(-(float(x*x + y*y)) / (2.0 * (p.radius/2.5) * (p.radius/2.5)));
                halo += sample * weight;
                totalWeight += weight;
            }
        }
    }

    if (totalWeight > 0.0) {
        halo /= totalWeight;
        // ★ FIX: Additive blend in linear space
        float3 rgb = srgbToLinear3(color.rgb);
        float3 haloLinear = halo * p.color * p.intensity * p.softness;
        rgb = min(float3(1.0), rgb + haloLinear);
        color.rgb = linearToSrgb3(rgb);
    }

    return saturate(color);
}

// ═══════════════════════════════════════════════════════════════
// 6. VIGNETTE SHADER (Fixed aspect ratio)
// ═══════════════════════════════════════════════════════════════

fragment float4 vignetteFragment(
    VertexOut in [[stage_in]],
    texture2d<float> inputTexture [[texture(0)]],
    constant VignetteParams &p [[buffer(0)]]
) {
    constexpr sampler s(filter::linear);
    float4 color = inputTexture.sample(s, in.texCoord);

    if (p.enabled == 0) return color;

    float2 uv = in.texCoord - 0.5;
    
    // ★ FIX: Correct aspect ratio handling for circular vignette
    float aspect = float(inputTexture.get_width()) / float(inputTexture.get_height());
    if (aspect > 1.0) {
        uv.x *= aspect;  // Landscape: stretch X
    } else {
        uv.y /= aspect;  // Portrait: stretch Y
    }
    
    // Apply roundness (1.0 = circle, 0.5 = oval)
    uv.x *= mix(1.0, 1.0, p.roundness);

    float dist = length(uv);
    float v = 1.0 - smoothstep(p.midpoint - p.feather, p.midpoint + p.feather, dist);

    // Apply in linear space
    float3 rgb = srgbToLinear3(color.rgb);
    rgb *= mix(1.0, v, p.intensity);
    rgb = linearToSrgb3(rgb);
    
    return float4(rgb, color.a);
}

// ═══════════════════════════════════════════════════════════════
// 7. INSTANT FRAME SHADER
// ═══════════════════════════════════════════════════════════════

fragment float4 instantFrameFragment(
    VertexOut in [[stage_in]],
    texture2d<float> photoTexture [[texture(0)]],
    constant InstantFrameParams &p [[buffer(0)]]
) {
    constexpr sampler s(filter::linear, address::clamp_to_edge);
    float2 uv = in.texCoord;

    if (p.enabled == 0) return photoTexture.sample(s, uv);

    float top = p.borderWidths.x;
    float left = p.borderWidths.y;
    float right = 1.0 - p.borderWidths.z;
    float bottom = 1.0 - p.borderWidths.w;

    if (uv.x > left && uv.x < right && uv.y > top && uv.y < bottom) {
        float2 photoUV = float2(
            (uv.x - left) / (right - left),
            (uv.y - top) / (bottom - top)
        );
        float4 color = photoTexture.sample(s, photoUV);

        // Edge fade
        float dX = min(photoUV.x, 1.0 - photoUV.x);
        float dY = min(photoUV.y, 1.0 - photoUV.y);
        float edgeDist = min(dX, dY);
        float fade = smoothstep(0.0, p.edgeFade, edgeDist);
        color.rgb *= mix(0.8, 1.0, fade);

        // Corner darkening
        float distCenter = length(photoUV - 0.5);
        color.rgb *= (1.0 - smoothstep(0.4, 0.8, distCenter) * p.cornerDarkening);

        return color;
    } else {
        return float4(p.borderColor, 1.0);
    }
}

// ═══════════════════════════════════════════════════════════════
// 8. TONE MAPPING SHADER (Filmic)
// ═══════════════════════════════════════════════════════════════

// Filmic tone mapping curve (Uncharted 2 style)
float3 filmicToneMap(float3 x, float A, float B, float C, float D, float E, float F) {
    return ((x * (A * x + C * B) + D * E) / (x * (A * x + B) + D * F)) - E / F;
}

fragment float4 toneMappingFragment(
    VertexOut in [[stage_in]],
    texture2d<float> inputTexture [[texture(0)]],
    constant ToneMappingParams &params [[buffer(0)]]
) {
    constexpr sampler s(filter::linear, address::clamp_to_edge);
    float4 color = inputTexture.sample(s, in.texCoord);
    
    if (params.enabled == 0) return color;
    
    float3 rgb = srgbToLinear3(color.rgb);
    
    // Filmic parameters
    float A = params.shoulderStrength;
    float B = params.linearStrength;
    float C = 0.10;      // linearAngle
    float D = params.toeStrength;
    float E = 0.01;      // toeNumerator
    float F = 0.30;      // toeDenominator
    float W = params.whitePoint;
    
    float3 whiteScale = 1.0 / filmicToneMap(float3(W), A, B, C, D, E, F);
    rgb = filmicToneMap(rgb, A, B, C, D, E, F) * whiteScale;
    
    rgb = linearToSrgb3(saturate(rgb));
    
    return float4(rgb, color.a);
}

// ═══════════════════════════════════════════════════════════════
// ★★★ NEW: SKIN TONE PROTECTION SHADER ★★★
// ═══════════════════════════════════════════════════════════════

fragment float4 skinToneProtectionFragment(
    VertexOut in [[stage_in]],
    texture2d<float> inputTexture [[texture(0)]],
    constant SkinToneParams &p [[buffer(0)]]
) {
    constexpr sampler s(filter::linear, address::clamp_to_edge);
    float4 color = inputTexture.sample(s, in.texCoord);
    
    if (p.enabled == 0) return color;
    
    float3 rgb = color.rgb;
    float3 hsl = rgb2hsl(rgb);
    
    // Calculate distance from skin tone center
    float hueCenter = p.hueCenter / 360.0;  // Convert to 0-1
    float hueRange = p.hueRange / 360.0;
    
    float hueDist = abs(hsl.x - hueCenter);
    if (hueDist > 0.5) hueDist = 1.0 - hueDist;  // Handle wrap-around
    
    // Create smooth mask for skin tones
    float skinMask = 1.0 - smoothstep(0.0, hueRange, hueDist);
    
    // Also check saturation (skin is typically medium saturation)
    float satMask = smoothstep(0.1, 0.3, hsl.y) * (1.0 - smoothstep(0.5, 0.8, hsl.y));
    skinMask *= satMask;
    
    if (skinMask > 0.0) {
        // Protect saturation (don't over-saturate skin)
        float satProtection = mix(1.0, 0.85, p.satProtection * skinMask);
        hsl.y *= satProtection;
        
        // Add slight warmth boost
        hsl.x += p.warmthBoost * skinMask * 0.02;
        if (hsl.x > 1.0) hsl.x -= 1.0;
        
        rgb = hsl2rgb(hsl);
    }
    
    return float4(rgb, color.a);
}
