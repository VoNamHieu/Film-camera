//
//  ShaderTypes.h
//  Film camera
//
//  Created by mac on 17/12/25.
//

#ifndef ShaderTypes_h
#define ShaderTypes_h

#include <simd/simd.h>

// Vertex data
typedef struct {
    vector_float2 position;
    vector_float2 texCoord;
} Vertex;

// Buffer indices
typedef enum {
    BufferIndexVertices = 0,
    BufferIndexUniforms = 1
} BufferIndex;

// Texture indices
typedef enum {
    TextureIndexInput = 0,
    TextureIndexLUT = 1,
    TextureIndexOutput = 2
} TextureIndex;

// --- CORE ENGINE STRUCTS (Ported from WebGL) ---

// 1. SELECTIVE COLOR: Chỉnh HSL cho từng dải màu cụ thể
typedef struct {
    float hue;          // Màu mục tiêu (0.0 - 1.0)
    float range;        // Phạm vi ảnh hưởng
    float satAdj;       // Tăng/giảm độ bão hòa (-1.0 đến 1.0)
    float lumAdj;       // Tăng/giảm độ sáng (-1.0 đến 1.0)
    float hueShift;     // Dịch chuyển màu (-0.1 đến 0.1)
} SelectiveColorData;

// 2. LENS DISTORTION: Hiệu ứng vật lý Disposable Camera
typedef struct {
    int enabled;
    float k1;           // Hệ số méo hình (Barrel Distortion)
    float k2;           // Hệ số méo rìa
    float caStrength;   // Độ lệch màu (Chromatic Aberration)
    float scale;        // Zoom nhẹ để crop phần đen
} LensDistortionParams;

// 3. COLOR GRADING: Tổng hợp các tham số chỉnh màu
typedef struct {
    float exposure;
    float contrast;
    float highlights;
    float shadows;
    float whites;
    float blacks;
    float saturation;
    float vibrance;
    float temperature;
    float tint;
    float fade;
    float clarity;

    // Split Tone
    float shadowsHue;
    float shadowsSat;
    float highlightsHue;
    float highlightsSat;
    float splitBalance;     // Cân bằng giữa vùng sáng/tối
    float midtoneProtection;// Bảo vệ vùng trung tính

    // Selective Color Array (Tối đa 8 kênh màu)
    SelectiveColorData selectiveColors[8];
    int selectiveColorCount;

    // LUT
    float lutIntensity;
    int useLUT;
} ColorGradingParams;

// 4. GRAIN: Hạt nhiễu giả lập film
typedef struct {
    float globalIntensity;
    float size;             // Kích thước hạt
    float softness;         // Độ mềm
    vector_float3 channelIntensity; // Cường độ hạt cho R, G, B
    int enabled;
} GrainParams;

// 5. BLOOM: Hiệu ứng tỏa sáng
typedef struct {
    float intensity;
    float threshold;
    float radius;
    float softness;
    vector_float3 colorTint;
    int enabled;
} BloomParams;

// 6. HALATION: Vầng hào quang đỏ (CineStill)
typedef struct {
    float intensity;
    float threshold;
    float radius;
    float softness;
    vector_float3 color;
    int enabled;
} HalationParams;

// 7. VIGNETTE: Tối góc
typedef struct {
    float intensity;
    float roundness;
    float feather;
    float midpoint;
    int enabled;
} VignetteParams;

// 8. INSTANT FRAME: Khung ảnh Polaroid
typedef struct {
    vector_float4 borderWidths; // top, left, right, bottom
    vector_float3 borderColor;
    float edgeFade;
    float cornerDarkening;
    int enabled;
} InstantFrameParams;

#endif /* ShaderTypes_h */
