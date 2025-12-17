#include <metal_stdlib>
using namespace metal;

#include "ShaderTypes.h"

// ═══════════════════════════════════════════════════════════════
// VERTEX SHADER (Fullscreen Quad)
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
    float3 rgb = abs(fmod(hue * 6.0 + float3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0;
    return saturate(rgb);
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
    
    // Exposure
    color.rgb *= pow(2.0, p.exposure);
    
    // Contrast
    color.rgb = (color.rgb - 0.5) * (1.0 + p.contrast) + 0.5;
    
    // Highlights / Shadows
    float luma = luminance(color.rgb);
    float shadowMask = 1.0 - smoothstep(0.0, 0.5, luma);
    float highlightMask = smoothstep(0.5, 1.0, luma);
    
    color.rgb += p.shadows * shadowMask * 0.2;
    color.rgb += p.highlights * highlightMask * 0.2;
    color.rgb += p.whites * smoothstep(0.8, 1.0, luma) * 0.15;
    color.rgb += p.blacks * (1.0 - smoothstep(0.0, 0.2, luma)) * 0.15;
    
    // Temperature & Tint
    color.r += p.temperature * 0.1;
    color.b -= p.temperature * 0.1;
    color.g += p.tint * 0.05;
    
    // Saturation
    float gray = luminance(color.rgb);
    color.rgb = mix(float3(gray), color.rgb, 1.0 + p.saturation);
    
    // LUT Lookup
    if (p.lutIntensity > 0) {
        float3 lutCoord = saturate(color.rgb);
        float3 lutColor = lutTexture.sample(lutSampler, lutCoord).rgb;
        color.rgb = mix(color.rgb, lutColor, p.lutIntensity);
    }
    
    // Fade (lift blacks)
    color.rgb = mix(color.rgb, float3(1.0), p.fade * (1.0 - color.rgb) * 0.15);
    
    // Split Toning
    if (p.shadowsSat > 0 || p.highlightsSat > 0) {
        float3 shadowTint = hueToRGB(p.shadowsHue / 360.0);
        float3 highlightTint = hueToRGB(p.highlightsHue / 360.0);
        
        color.rgb = mix(color.rgb, color.rgb * shadowTint, shadowMask * p.shadowsSat * 0.3);
        color.rgb = mix(color.rgb, color.rgb * highlightTint, highlightMask * p.highlightsSat * 0.3);
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
    
    float aspect = float(inputTexture.get_width()) / float(inputTexture.get_height());
    float2 coord = (uv - center) * float2(aspect, 1.0);
    
    float dist = length(coord);
    float vignette = 1.0 - smoothstep(p.radius, p.radius + p.softness, dist);
    
    color.rgb *= mix(1.0, vignette, p.intensity);
    
    return color;
}

// ═══════════════════════════════════════════════════════════════
// GRAIN SHADER
// ═══════════════════════════════════════════════════════════════

fragment float4 grainFragment(
    VertexOut in [[stage_in]],
    texture2d<float> inputTexture [[texture(0)]],
    constant GrainParams &p [[buffer(0)]]
) {
    constexpr sampler s(filter::linear);
    float4 color = inputTexture.sample(s, in.texCoord);
    
    float2 grainCoord = in.texCoord * float2(inputTexture.get_width(), inputTexture.get_height()) / p.size;
    
    float grainR = (noise2D(grainCoord, p.seed) - 0.5) * 2.0;
    float grainG = (noise2D(grainCoord + 100.0, p.seed) - 0.5) * 2.0;
    float grainB = (noise2D(grainCoord + 200.0, p.seed) - 0.5) * 2.0;
    
    float3 grain = float3(grainR, grainG, grainB) * p.channelMultipliers;
    
    float luma = luminance(color.rgb);
    float shadowBoost = mix(1.0 + p.luminanceResponse, 1.0, luma);
    
    color.rgb += grain * p.intensity * shadowBoost;
    
    return saturate(color);
}

// ═══════════════════════════════════════════════════════════════
// BLOOM SHADER (Simplified)
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
    
    for (int dy = -radius; dy <= radius; dy++) {
        for (int dx = -radius; dx <= radius; dx++) {
            float2 offset = float2(float(dx), float(dy)) * texelSize;
            float4 sample = inputTexture.sample(s, in.texCoord + offset);
            float luma = luminance(sample.rgb);
            
            if (luma > p.threshold) {
                float dist = length(float2(dx, dy));
                float weight = exp(-(dist * dist) / (2.0 * sigma * sigma));
                bloom += sample * weight * (luma - p.threshold);
                weightSum += weight;
            }
        }
    }
    
    if (weightSum > 0) {
        bloom /= weightSum;
        color.rgb += bloom.rgb * p.intensity;
    }
    
    return saturate(color);
}

// ═══════════════════════════════════════════════════════════════
// INSTANT FRAME SHADER (Polaroid)
// ═══════════════════════════════════════════════════════════════

fragment float4 instantFrameFragment(
    VertexOut in [[stage_in]],
    texture2d<float> photoTexture [[texture(0)]],
    constant InstantFrameParams &p [[buffer(0)]]
) {
    constexpr sampler s(filter::linear, address::clamp_to_edge);
    
    float2 uv = in.texCoord;
    
    float left = p.borderSides;
    float right = 1.0 - p.borderSides;
    float top = p.borderTop;
    float bottom = 1.0 - p.borderBottom;
    
    if (uv.x >= left && uv.x <= right && uv.y >= top && uv.y <= bottom) {
        float2 photoUV = float2(
            (uv.x - left) / (right - left),
            (uv.y - top) / (bottom - top)
        );
        return photoTexture.sample(s, photoUV);
    }
    
    return float4(p.borderColor, 1.0);
}
