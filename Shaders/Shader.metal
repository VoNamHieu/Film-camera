#include <metal_stdlib>
using namespace metal;

// Define VertexOut directly in Metal
struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

// Parameter structs
struct ColorGradingParams {
    float exposure;
    float contrast;
    float highlights;
    float shadows;
    float whites;
    float blacks;
    float temperature;
    float tint;
    float saturation;
    float vibrance;
    float fade;
    float clarity;
    int useLUT;
    float lutIntensity;
    float shadowsHue;
    float shadowsSat;
    float highlightsHue;
    float highlightsSat;
    float balance;
    float midtoneProtection;
};

struct VignetteParams {
    float intensity;
    float roundness;
    float feather;
    float midpoint;
};

struct GrainParams {
    float globalIntensity;
    float3 channelIntensity;
    float3 channelSize;
    uint seed;
    int chromaticEnabled;
    float2 redShift;
    float2 blueShift;
    float4 densityLuma;
    float4 densityMultiplier;
};

struct BloomParams {
    float intensity;
    float threshold;
    float radius;
    float softness;
    float3 colorTint;
};

struct HalationParams {
    int enabled;
    float3 color;
    float intensity;
    float threshold;
    float radius;
    float softness;
    int gradientEnabled;
    float3 innerColor;
    float3 outerColor;
};

struct InstantFrameParams {
    float borderTop;
    float borderLeft;
    float borderRight;
    float borderBottom;
    float3 borderColor;
    float edgeFade;
    float cornerDarkening;
};

// ═══════════════════════════════════════════════════════════════
// VERTEX SHADER
// ═══════════════════════════════════════════════════════════════

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

// ═══════════════════════════════════════════════════════════════
// UTILITY FUNCTIONS
// ═══════════════════════════════════════════════════════════════

float luminance(float3 color) {
    return dot(color, float3(0.2126, 0.7152, 0.0722));
}

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

float3 hueToRGB(float hue) {
    float h = hue / 360.0;
    float3 rgb = abs(fmod(h * 6.0 + float3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0;
    return saturate(rgb);
}

// Interpolate density curve
float sampleDensityCurve(float luma, float4 lumaPoints, float4 multipliers) {
    if (luma <= lumaPoints.x) return multipliers.x;
    if (luma >= lumaPoints.w) return multipliers.w;
    
    if (luma < lumaPoints.y) {
        float t = (luma - lumaPoints.x) / (lumaPoints.y - lumaPoints.x);
        return mix(multipliers.x, multipliers.y, t);
    }
    if (luma < lumaPoints.z) {
        float t = (luma - lumaPoints.y) / (lumaPoints.z - lumaPoints.y);
        return mix(multipliers.y, multipliers.z, t);
    }
    float t = (luma - lumaPoints.z) / (lumaPoints.w - lumaPoints.z);
    return mix(multipliers.z, multipliers.w, t);
}

// ═══════════════════════════════════════════════════════════════
// COLOR GRADING SHADER
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
    
    // === Exposure ===
    color.rgb *= pow(2.0, p.exposure);
    
    // === Contrast ===
    color.rgb = (color.rgb - 0.5) * (1.0 + p.contrast) + 0.5;
    
    // === Highlights / Shadows / Whites / Blacks ===
    float luma = luminance(color.rgb);
    float shadowMask = 1.0 - smoothstep(0.0, 0.5, luma);
    float highlightMask = smoothstep(0.5, 1.0, luma);
    float whiteMask = smoothstep(0.8, 1.0, luma);
    float blackMask = 1.0 - smoothstep(0.0, 0.2, luma);
    
    color.rgb += p.shadows * shadowMask * 0.2;
    color.rgb += p.highlights * highlightMask * 0.2;
    color.rgb += p.whites * whiteMask * 0.15;
    color.rgb += p.blacks * blackMask * 0.15;
    
    // === Temperature & Tint ===
    color.r += p.temperature * 0.1;
    color.b -= p.temperature * 0.1;
    color.g += p.tint * 0.05;
    
    // === Saturation ===
    float gray = luminance(color.rgb);
    color.rgb = mix(float3(gray), color.rgb, 1.0 + p.saturation);
    
    // === Vibrance (smart saturation) ===
    float maxChannel = max(max(color.r, color.g), color.b);
    float minChannel = min(min(color.r, color.g), color.b);
    float colorfulness = maxChannel - minChannel;
    float vibranceAmount = p.vibrance * (1.0 - colorfulness);
    color.rgb = mix(float3(gray), color.rgb, 1.0 + vibranceAmount);
    
    // === LUT Lookup ===
    if (p.useLUT > 0 && p.lutIntensity > 0) {
        float3 lutCoord = saturate(color.rgb);
        float3 lutColor = lutTexture.sample(lutSampler, lutCoord).rgb;
        color.rgb = mix(color.rgb, lutColor, p.lutIntensity);
    }
    
    // === Fade (lift blacks) ===
    color.rgb = mix(color.rgb, float3(1.0), p.fade * (1.0 - color.rgb) * 0.15);
    
    // === Split Toning ===
    if (p.shadowsSat > 0 || p.highlightsSat > 0) {
        float3 shadowTint = hueToRGB(p.shadowsHue);
        float3 highlightTint = hueToRGB(p.highlightsHue);
        
        // Protect midtones
        float midtoneMask = 1.0 - abs(luma - 0.5) * 2.0;
        float shadowStrength = shadowMask * (1.0 - midtoneMask * p.midtoneProtection);
        float highlightStrength = highlightMask * (1.0 - midtoneMask * p.midtoneProtection);
        
        color.rgb = mix(color.rgb, color.rgb * shadowTint, shadowStrength * p.shadowsSat * 0.3);
        color.rgb = mix(color.rgb, color.rgb * highlightTint, highlightStrength * p.highlightsSat * 0.3);
    }
    
    // === Clarity (midtone contrast) ===
    if (abs(p.clarity) > 0.001) {
        float localContrast = (luma - 0.5) * p.clarity * 0.5;
        color.rgb += localContrast;
    }
    
    return saturate(color);
}

// ═══════════════════════════════════════════════════════════════
// VIGNETTE SHADER
// ═══════════════════════════════════════════════════════════════

fragment float4 vignetteFragment(
    VertexOut in [[stage_in]],
    texture2d<float> inputTexture [[texture(0)]],
    constant VignetteParams &p [[buffer(0)]]
) {
    constexpr sampler s(filter::linear);
    float4 color = inputTexture.sample(s, in.texCoord);
    
    float2 center = float2(0.5, 0.5);
    float2 uv = in.texCoord;
    
    // Adjust for roundness (1.0 = circular, 0.0 = rectangular)
    float aspect = float(inputTexture.get_width()) / float(inputTexture.get_height());
    float2 coord = (uv - center);
    coord.x *= mix(1.0, aspect, p.roundness);
    
    float dist = length(coord);
    
    // Smooth falloff from midpoint
    float vignetteStart = p.midpoint * (1.0 - p.feather);
    float vignetteEnd = p.midpoint + p.feather * 0.5;
    float vignette = 1.0 - smoothstep(vignetteStart, vignetteEnd, dist);
    
    color.rgb *= mix(1.0, vignette, p.intensity);
    
    return color;
}

// ═══════════════════════════════════════════════════════════════
// GRAIN SHADER (Advanced Film Grain)
// ═══════════════════════════════════════════════════════════════

fragment float4 grainFragment(
    VertexOut in [[stage_in]],
    texture2d<float> inputTexture [[texture(0)]],
    constant GrainParams &p [[buffer(0)]]
) {
    constexpr sampler s(filter::linear);
    float4 color = inputTexture.sample(s, in.texCoord);
    
    float2 texSize = float2(inputTexture.get_width(), inputTexture.get_height());
    
    // Per-channel grain with different sizes
    float2 grainCoordR = in.texCoord * texSize / p.channelSize.x;
    float2 grainCoordG = in.texCoord * texSize / p.channelSize.y;
    float2 grainCoordB = in.texCoord * texSize / p.channelSize.z;
    
    // Apply chromatic shift if enabled
    if (p.chromaticEnabled > 0) {
        grainCoordR += p.redShift * 0.01;
        grainCoordB += p.blueShift * 0.01;
    }
    
    // Generate per-channel noise
    float grainR = (noise2D(grainCoordR, p.seed) - 0.5) * 2.0;
    float grainG = (noise2D(grainCoordG, p.seed + 100) - 0.5) * 2.0;
    float grainB = (noise2D(grainCoordB, p.seed + 200) - 0.5) * 2.0;
    
    float3 grain = float3(grainR, grainG, grainB) * p.channelIntensity;
    
    // Apply density curve (more grain in midtones, less in shadows/highlights)
    float luma = luminance(color.rgb);
    float densityMult = sampleDensityCurve(luma, p.densityLuma, p.densityMultiplier);
    
    color.rgb += grain * p.globalIntensity * densityMult;
    
    return saturate(color);
}

// ═══════════════════════════════════════════════════════════════
// BLOOM SHADER
// ═══════════════════════════════════════════════════════════════

fragment float4 bloomFragment(
    VertexOut in [[stage_in]],
    texture2d<float> inputTexture [[texture(0)]],
    constant BloomParams &p [[buffer(0)]]
) {
    constexpr sampler s(filter::linear, address::clamp_to_edge);
    float4 color = inputTexture.sample(s, in.texCoord);
    
    float4 bloom = float4(0.0);
    float weightSum = 0.0;
    int radius = int(p.radius);
    float sigma = p.radius / 3.0;
    
    float2 texelSize = 1.0 / float2(inputTexture.get_width(), inputTexture.get_height());
    
    // Gaussian blur on bright areas
    for (int dy = -radius; dy <= radius; dy++) {
        for (int dx = -radius; dx <= radius; dx++) {
            float2 offset = float2(float(dx), float(dy)) * texelSize;
            float4 sampleColor = inputTexture.sample(s, in.texCoord + offset);
            float luma = luminance(sampleColor.rgb);
            
            if (luma > p.threshold) {
                float dist = length(float2(dx, dy));
                float weight = exp(-(dist * dist) / (2.0 * sigma * sigma));
                weight *= pow(smoothstep(p.threshold, 1.0, luma), p.softness * 2.0);
                bloom += sampleColor * weight;
                weightSum += weight;
            }
        }
    }
    
    if (weightSum > 0) {
        bloom /= weightSum;
        // Apply color tint to bloom
        bloom.rgb *= p.colorTint;
        color.rgb += bloom.rgb * p.intensity;
    }
    
    return saturate(color);
}

// ═══════════════════════════════════════════════════════════════
// HALATION SHADER (CineStill 800T Red Glow)
// ═══════════════════════════════════════════════════════════════

fragment float4 halationFragment(
    VertexOut in [[stage_in]],
    texture2d<float> inputTexture [[texture(0)]],
    constant HalationParams &p [[buffer(0)]]
) {
    constexpr sampler s(filter::linear, address::clamp_to_edge);
    float4 color = inputTexture.sample(s, in.texCoord);
    
    if (p.enabled == 0) return color;
    
    float4 halation = float4(0.0);
    float weightSum = 0.0;
    int radius = int(p.radius);
    float sigma = p.radius / 2.5;
    
    float2 texelSize = 1.0 / float2(inputTexture.get_width(), inputTexture.get_height());
    
    // Find bright spots and create colored glow
    for (int dy = -radius; dy <= radius; dy++) {
        for (int dx = -radius; dx <= radius; dx++) {
            float2 offset = float2(float(dx), float(dy)) * texelSize;
            float4 sampleColor = inputTexture.sample(s, in.texCoord + offset);
            float luma = luminance(sampleColor.rgb);
            
            if (luma > p.threshold) {
                float dist = length(float2(dx, dy));
                float weight = exp(-(dist * dist) / (2.0 * sigma * sigma));
                weight *= (luma - p.threshold) / (1.0 - p.threshold);
                
                // Apply halation color
                float3 halationColor = p.color;
                if (p.gradientEnabled > 0) {
                    float gradientT = dist / float(radius);
                    halationColor = mix(p.innerColor, p.outerColor, gradientT);
                }
                
                halation.rgb += halationColor * weight;
                weightSum += weight;
            }
        }
    }
    
    if (weightSum > 0) {
        halation.rgb /= weightSum;
        // Additive blend for glow effect
        color.rgb += halation.rgb * p.intensity * p.softness;
    }
    
    return saturate(color);
}

// ═══════════════════════════════════════════════════════════════
// INSTANT FRAME SHADER (Polaroid/Instax Border)
// ═══════════════════════════════════════════════════════════════

fragment float4 instantFrameFragment(
    VertexOut in [[stage_in]],
    texture2d<float> photoTexture [[texture(0)]],
    constant InstantFrameParams &p [[buffer(0)]]
) {
    constexpr sampler s(filter::linear, address::clamp_to_edge);
    
    float2 uv = in.texCoord;
    
    // Define photo area
    float left = p.borderLeft;
    float right = 1.0 - p.borderRight;
    float top = p.borderTop;
    float bottom = 1.0 - p.borderBottom;
    
    // Check if inside photo area
    if (uv.x >= left && uv.x <= right && uv.y >= top && uv.y <= bottom) {
        // Map UV to photo texture
        float2 photoUV = float2(
            (uv.x - left) / (right - left),
            (uv.y - top) / (bottom - top)
        );
        
        float4 photoColor = photoTexture.sample(s, photoUV);
        
        // Apply edge fade (chemical development look)
        if (p.edgeFade > 0) {
            float2 edgeDist = min(photoUV, 1.0 - photoUV);
            float edgeMask = smoothstep(0.0, 0.15, min(edgeDist.x, edgeDist.y));
            photoColor.rgb *= mix(1.0 - p.edgeFade, 1.0, edgeMask);
        }
        
        // Apply corner darkening
        if (p.cornerDarkening > 0) {
            float cornerDist = length(photoUV - 0.5) / 0.707; // 0.707 = sqrt(0.5)
            float cornerMask = 1.0 - smoothstep(0.5, 1.0, cornerDist) * p.cornerDarkening;
            photoColor.rgb *= cornerMask;
        }
        
        return photoColor;
    }
    
    // Border area - return border color
    return float4(p.borderColor, 1.0);
}

// ═══════════════════════════════════════════════════════════════
// RGB CURVES SHADER (Simplified)
// ═══════════════════════════════════════════════════════════════

fragment float4 rgbCurvesFragment(
    VertexOut in [[stage_in]],
    texture2d<float> inputTexture [[texture(0)]]
) {
    constexpr sampler s(filter::linear);
    float4 color = inputTexture.sample(s, in.texCoord);
    
    // For MVP: pass through (full implementation would use curve LUT)
    return color;
}
