#include <metal_stdlib>
using namespace metal;

#include "ShaderTypes.h"

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

// ═══════════════════════════════════════════════════════════════
// UTILITY FUNCTIONS (Core Math ported from WebGL)
// ═══════════════════════════════════════════════════════════════

float luminance(float3 color) {
    return dot(color, float3(0.2126, 0.7152, 0.0722));
}

// Chuyển đổi RGB sang HSL (Logic từ index.html)
float3 rgb2hsl(float3 c) {
    float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    float4 p = mix(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
    float4 q = mix(float4(p.xyw, c.r), float4(c.r, p.yzx), step(p.x, c.r));

    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return float3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

// Chuyển đổi HSL sang RGB
float3 hsl2rgb(float3 c) {
    float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    float3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

float3 hueToRGB(float hue) {
    float3 rgb = abs(fmod(hue * 6.0 + float3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0;
    return saturate(rgb);
}

// Noise function
float random(float2 st, uint seed) {
    return fract(sin(dot(st + float2(seed), float2(12.9898, 78.233))) * 43758.5453);
}

// Simplex-like noise
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
    float r2 = dot(dc, dc); // Bán kính bình phương

    // Công thức biến dạng quang học: r_new = r * (1 + k1*r^2 + k2*r^4)
    float distortion = 1.0 + p.k1 * r2 + p.k2 * r2 * r2;

    // Tính UV mới cho từng kênh màu (Chromatic Aberration)
    // Kênh Đỏ méo ít hơn Kênh Xanh Dương
    float2 uvR = center + dc * distortion * (1.0 - p.caStrength) * p.scale;
    float2 uvG = center + dc * distortion * p.scale;
    float2 uvB = center + dc * distortion * (1.0 + p.caStrength) * p.scale;

    float r = inputTexture.sample(s, uvR).r;
    float g = inputTexture.sample(s, uvG).g;
    float b = inputTexture.sample(s, uvB).b;

    return float4(r, g, b, 1.0);
}

// ═══════════════════════════════════════════════════════════════
// 2. COLOR GRADING SHADER (The Core Engine)
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
    float3 rgb = color.rgb;

    // === 1. BASIC CORRECTIONS ===
    // Exposure
    rgb *= pow(2.0, p.exposure);

    // Contrast
    rgb = (rgb - 0.5) * (1.0 + p.contrast) + 0.5;

    // Highlights / Shadows
    float luma = luminance(rgb);
    float shadowMask = 1.0 - smoothstep(0.0, 0.5, luma);
    float highlightMask = smoothstep(0.5, 1.0, luma);

    rgb += p.shadows * shadowMask * 0.2;
    rgb += p.highlights * highlightMask * 0.2;
    rgb += p.whites * smoothstep(0.8, 1.0, luma) * 0.15;
    rgb += p.blacks * (1.0 - smoothstep(0.0, 0.2, luma)) * 0.15;

    // Temperature & Tint
    rgb.r += p.temperature * 0.1;
    rgb.b -= p.temperature * 0.1;
    rgb.g += p.tint * 0.05;

    // === 2. SELECTIVE COLOR (Ported from WebGL) ===
    // "Linh hồn" của các preset như Portra hay Gold
    if (p.selectiveColorCount > 0) {
        float3 hsl = rgb2hsl(rgb);

        for (int i = 0; i < p.selectiveColorCount; i++) {
            SelectiveColorData adj = p.selectiveColors[i];

            // Tính khoảng cách màu (xử lý hue wrap-around)
            float dist = abs(hsl.x - adj.hue);
            if (dist > 0.5) dist = 1.0 - dist;

            // Tính mask ảnh hưởng
            float mask = 1.0 - smoothstep(0.0, adj.range, dist);

            if (mask > 0.0) {
                // Shift Hue
                hsl.x += adj.hueShift * mask;
                // Adjust Saturation
                hsl.y = clamp(hsl.y * (1.0 + adj.satAdj * mask), 0.0, 1.0);
                // Adjust Luminance
                hsl.z = clamp(hsl.z * (1.0 + adj.lumAdj * mask * 0.5), 0.0, 1.0);
            }
        }
        rgb = hsl2rgb(hsl);
    }

    // === 3. SATURATION & VIBRANCE ===
    luma = luminance(rgb); // Recalculate luma
    rgb = mix(float3(luma), rgb, 1.0 + p.saturation);

    // Vibrance
    float maxChannel = max(max(rgb.r, rgb.g), rgb.b);
    float minChannel = min(min(rgb.r, rgb.g), rgb.b);
    float colorfulness = maxChannel - minChannel;
    rgb = mix(float3(luma), rgb, 1.0 + p.vibrance * (1.0 - colorfulness));

    // === 4. LUT LOOKUP ===
    if (p.useLUT > 0 && p.lutIntensity > 0) {
        float3 lutCoord = saturate(rgb);
        float3 lutColor = lutTexture.sample(lutSampler, lutCoord).rgb;
        rgb = mix(rgb, lutColor, p.lutIntensity);
    }

    // === 5. FADE & CLARITY ===
    rgb = mix(rgb, float3(1.0), p.fade * (1.0 - rgb) * 0.15);

    if (abs(p.clarity) > 0.001) {
        rgb += (luma - 0.5) * p.clarity * 0.5;
    }

    // === 6. SPLIT TONING (Advanced) ===
    if (p.shadowsSat > 0 || p.highlightsSat > 0) {
        // Chuyển input hue (độ) sang RGB tint
        float3 shadowTint = hueToRGB(p.shadowsHue / 360.0);
        float3 highlightTint = hueToRGB(p.highlightsHue / 360.0);

        // Midtone protection
        float midtoneMask = 1.0 - abs(luma - 0.5) * 2.0;
        float sStr = shadowMask * (1.0 - midtoneMask * p.midtoneProtection);
        float hStr = highlightMask * (1.0 - midtoneMask * p.midtoneProtection);

        rgb = mix(rgb, rgb * shadowTint, sStr * p.shadowsSat * 0.3);
        rgb = mix(rgb, rgb * highlightTint, hStr * p.highlightsSat * 0.3);
    }

    return saturate(float4(rgb, color.a));
}

// ═══════════════════════════════════════════════════════════════
// 3. GRAIN, BLOOM, HALATION, VIGNETTE
// (Giữ nguyên hoặc tinh chỉnh nhẹ từ code cũ để khớp pipeline)
// ═══════════════════════════════════════════════════════════════

fragment float4 grainFragment(
    VertexOut in [[stage_in]],
    texture2d<float> inputTexture [[texture(0)]],
    constant GrainParams &p [[buffer(0)]]
) {
    constexpr sampler s(filter::linear);
    float4 color = inputTexture.sample(s, in.texCoord);

    if (p.enabled == 0) return color;

    float2 texSize = float2(inputTexture.get_width(), inputTexture.get_height());
    float2 grainCoord = in.texCoord * texSize / (p.size * 2.0); // Scale grain size

    // Generate noise per channel
    float3 noise;
    noise.r = noise2D(grainCoord, 100);
    noise.g = noise2D(grainCoord, 200);
    noise.b = noise2D(grainCoord, 300);
    noise = (noise - 0.5) * 2.0;

    // Density Curve: Grain xuất hiện nhiều ở vùng Midtones, ít ở Black/White
    float luma = luminance(color.rgb);
    float density = 1.0 - smoothstep(0.0, 1.0, abs(luma - 0.5) * 2.5); // Bell curve

    color.rgb += noise * p.channelIntensity * p.globalIntensity * density;

    return saturate(color);
}

// Bloom, Vignette, Halation, InstantFrame giữ nguyên logic cũ
// nhưng đảm bảo tham số khớp với struct mới trong ShaderTypes.h

fragment float4 vignetteFragment(
    VertexOut in [[stage_in]],
    texture2d<float> inputTexture [[texture(0)]],
    constant VignetteParams &p [[buffer(0)]]
) {
    constexpr sampler s(filter::linear);
    float4 color = inputTexture.sample(s, in.texCoord);

    if (p.enabled == 0) return color;

    float2 uv = in.texCoord - 0.5;
    // Chỉnh aspect ratio cho vignette tròn
    float aspect = float(inputTexture.get_width()) / float(inputTexture.get_height());
    uv.x *= mix(1.0, aspect, p.roundness);

    float dist = length(uv);
    float v = 1.0 - smoothstep(p.midpoint - p.feather, p.midpoint + p.feather, dist);

    color.rgb *= mix(1.0, v, p.intensity);
    return color;
}

// ═══════════════════════════════════════════════════════════════════
// BLOOM SHADER - 4 PASS (Optimized Separable Blur)
// ═══════════════════════════════════════════════════════════════════

// PASS 1: BLOOM THRESHOLD EXTRACTION
fragment float4 bloomThresholdFragment(
    VertexOut in [[stage_in]],
    texture2d<float> inputTexture [[texture(0)]],
    constant BloomParams &p [[buffer(0)]]
) {
    constexpr sampler s(filter::linear, address::clamp_to_edge);
    float4 color = inputTexture.sample(s, in.texCoord);

    if (p.enabled == 0) return float4(0.0);

    // Soft threshold extraction (giống HTML line 10365-10380)
    float luma = dot(color.rgb, float3(0.2126, 0.7152, 0.0722));
    float softThreshold = p.threshold * 0.7;

    if (luma > softThreshold) {
        float t = max(0.0, (luma - softThreshold) / (1.0 - softThreshold));
        float bloomStrength = pow(t, 1.5);
        return float4(color.rgb * bloomStrength * p.colorTint, 1.0);
    }

    return float4(0.0, 0.0, 0.0, 1.0);
}

// PASS 2: HORIZONTAL BLUR (Separable)
fragment float4 blurHorizontalFragment(
    VertexOut in [[stage_in]],
    texture2d<float> inputTexture [[texture(0)]],
    constant float &radius [[buffer(0)]]
) {
    constexpr sampler s(filter::linear, address::clamp_to_edge);

    float2 texelSize = 1.0 / float2(inputTexture.get_width(), inputTexture.get_height());

    // Gaussian weights (pre-computed for radius ~16)
    const int KERNEL_SIZE = 9;
    float weights[KERNEL_SIZE] = {
        0.0162, 0.0540, 0.1216, 0.1945, 0.2270,
        0.1945, 0.1216, 0.0540, 0.0162
    };
    float offsets[KERNEL_SIZE] = {-4, -3, -2, -1, 0, 1, 2, 3, 4};

    float3 result = float3(0.0);
    float weightSum = 0.0;

    for (int i = 0; i < KERNEL_SIZE; i++) {
        float2 offset = float2(offsets[i] * radius * 0.25, 0.0) * texelSize;
        result += inputTexture.sample(s, in.texCoord + offset).rgb * weights[i];
        weightSum += weights[i];
    }

    return float4(result / weightSum, 1.0);
}

// PASS 3: VERTICAL BLUR (Separable)
fragment float4 blurVerticalFragment(
    VertexOut in [[stage_in]],
    texture2d<float> inputTexture [[texture(0)]],
    constant float &radius [[buffer(0)]]
) {
    constexpr sampler s(filter::linear, address::clamp_to_edge);

    float2 texelSize = 1.0 / float2(inputTexture.get_width(), inputTexture.get_height());

    const int KERNEL_SIZE = 9;
    float weights[KERNEL_SIZE] = {
        0.0162, 0.0540, 0.1216, 0.1945, 0.2270,
        0.1945, 0.1216, 0.0540, 0.0162
    };
    float offsets[KERNEL_SIZE] = {-4, -3, -2, -1, 0, 1, 2, 3, 4};

    float3 result = float3(0.0);
    float weightSum = 0.0;

    for (int i = 0; i < KERNEL_SIZE; i++) {
        float2 offset = float2(0.0, offsets[i] * radius * 0.25) * texelSize;
        result += inputTexture.sample(s, in.texCoord + offset).rgb * weights[i];
        weightSum += weights[i];
    }

    return float4(result / weightSum, 1.0);
}

// PASS 4: BLOOM COMPOSITE
fragment float4 bloomCompositeFragment(
    VertexOut in [[stage_in]],
    texture2d<float> originalTexture [[texture(0)]],
    texture2d<float> blurredBloomTexture [[texture(1)]],
    constant BloomParams &p [[buffer(0)]]
) {
    constexpr sampler s(filter::linear, address::clamp_to_edge);

    float4 original = originalTexture.sample(s, in.texCoord);
    float4 bloom = blurredBloomTexture.sample(s, in.texCoord);

    // Additive blend (giống HTML line 10385-10389)
    float softness = 0.8;
    original.rgb = saturate(original.rgb + bloom.rgb * p.intensity * softness);

    return original;
}

// ═══════════════════════════════════════════════════════════════════
// HALATION SHADER - 4 PASS (Separable Blur with Red/Orange Tint)
// ═══════════════════════════════════════════════════════════════════

// PASS 1: HALATION THRESHOLD EXTRACTION
fragment float4 halationThresholdFragment(
    VertexOut in [[stage_in]],
    texture2d<float> inputTexture [[texture(0)]],
    constant HalationParams &p [[buffer(0)]]
) {
    constexpr sampler s(filter::linear, address::clamp_to_edge);
    float4 color = inputTexture.sample(s, in.texCoord);

    if (p.enabled == 0) return float4(0.0);

    float luma = dot(color.rgb, float3(0.2126, 0.7152, 0.0722));

    if (luma > p.threshold) {
        float strength = (luma - p.threshold) / (1.0 - p.threshold);
        // Halation color: đỏ/cam (Cinestill 800T style) RGB(255, 100, 50)
        float3 halationColor = float3(1.0, 0.39, 0.20);
        return float4(halationColor * strength * p.color, 1.0);
    }

    return float4(0.0, 0.0, 0.0, 1.0);
}

// Halation uses same blurHorizontalFragment and blurVerticalFragment

// PASS 4: HALATION COMPOSITE
fragment float4 halationCompositeFragment(
    VertexOut in [[stage_in]],
    texture2d<float> originalTexture [[texture(0)]],
    texture2d<float> blurredHalationTexture [[texture(1)]],
    constant HalationParams &p [[buffer(0)]]
) {
    constexpr sampler s(filter::linear, address::clamp_to_edge);

    float4 original = originalTexture.sample(s, in.texCoord);
    float4 halation = blurredHalationTexture.sample(s, in.texCoord);

    // Additive blend with softness
    original.rgb = saturate(original.rgb + halation.rgb * p.intensity * p.softness);

    return original;
}

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

    // Check if inside photo area
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
