import simd

struct InstantFrameConfig: Codable {
    var enabled: Bool = true
    var borderColor: SIMD3<Float> = SIMD3<Float>(0.98, 0.96, 0.94)
    var borderTop: Float = 0.06
    var borderBottom: Float = 0.18      // Larger (chemical area)
    var borderSides: Float = 0.06
    var cornerRadius: Float = 0.01
}
