//
//  ShaderTypes.h
//  Film camera
//
//  Metal Shader Type Definitions - C Header File
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

// Color grading parameters
typedef struct {
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
    float shadowsHue;
    float shadowsSat;
    float highlightsHue;
    float highlightsSat;
    float splitBalance;
    float lutIntensity;
    int lutSize;
    int useLUT;
} ColorGradingParams;

// Vignette parameters
typedef struct {
    float intensity;
    float roundness;
    float feather;
    float midpoint;
    float aspectRatio;
    int enabled;
} VignetteParams;

// Grain parameters
typedef struct {
    float intensity;
    float size;
    float softness;
    float time;
    int seed;
    int enabled;
    vector_float3 channelIntensity;
    vector_float3 channelSize;
    vector_float2 redShift;
    vector_float2 blueShift;
    int chromaticEnabled;
} GrainParams;

// Bloom parameters
typedef struct {
    float intensity;
    float threshold;
    float radius;
    float softness;
    vector_float3 colorTint;
    int enabled;
} BloomParams;

// Halation parameters
typedef struct {
    float intensity;
    float threshold;
    float radius;
    float softness;
    vector_float3 color;
    int enabled;
} HalationParams;

// Instant film frame parameters
typedef struct {
    vector_float4 borderWidths;
    vector_float3 borderColor;
    float edgeFade;
    float cornerDarkening;
    int enabled;
} InstantFrameParams;

#endif /* ShaderTypes_h */
