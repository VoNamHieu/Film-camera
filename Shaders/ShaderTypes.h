//
//  ShaderTypes.h
//  Film camera
//
//  Created by mac on 17/12/25.
//  ★★★ UPDATED: Added RGB Curves support ★★★

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

// ★★★ NEW: RGB CURVE POINT ★★★
typedef struct {
    float input;        // Input value (0.0 - 1.0)
    float output;       // Output value (0.0 - 1.0)
} CurvePoint;

// ★★★ NEW: RGB CURVES DATA ★★★
// Maximum 8 control points per channel (including endpoints)
#define MAX_CURVE_POINTS 8

typedef struct {
    CurvePoint redCurve[MAX_CURVE_POINTS];
    CurvePoint greenCurve[MAX_CURVE_POINTS];
    CurvePoint blueCurve[MAX_CURVE_POINTS];
    int redPointCount;
    int greenPointCount;
    int bluePointCount;
    int enabled;
} RGBCurvesParams;

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
    
    // ★★★ NEW: RGB Curves ★★★
    RGBCurvesParams rgbCurves;
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

// ★★★ NEW: SKIN TONE PROTECTION ★★★
typedef struct {
    int enabled;
    float hueCenter;        // Center hue (degrees, typically 25 for skin)
    float hueRange;         // Range around center (degrees)
    float satProtection;    // How much to protect saturation (0-1)
    float warmthBoost;      // Slight warmth addition (0-0.1)
} SkinToneParams;

// ★★★ NEW: TONE MAPPING ★★★
typedef struct {
    int enabled;
    float whitePoint;
    float shoulderStrength;
    float linearStrength;
    float toeStrength;
} ToneMappingParams;

// ★★★ NEW: ASPECT RATIO SCALING ★★★
// Used for aspect-fill scaling to prevent object stretching
typedef struct {
    float inputAspect;      // Input texture aspect ratio (width/height)
    float outputAspect;     // Output drawable aspect ratio (width/height)
} AspectScaleParams;

// ★★★ NEW: FLASH EFFECT (Disposable Camera) ★★★
// Simulates on-camera flash with realistic falloff and warm tint
typedef struct {
    int enabled;
    float intensity;        // Overall flash strength (0.0-1.0)
    float falloff;          // Radial falloff exponent (1.5-3.0)
    float warmth;           // Warm tint amount (0.0-0.3)
    float shadowLift;       // Lift shadows in flash area (0.0-0.5)
    float centerBoost;      // Extra brightness at center (0.0-0.5)
    vector_float2 position; // Flash origin (normalized 0-1)
    float radius;           // Flash radius (0.3-1.0)
} FlashParams;

#endif /* ShaderTypes_h */
