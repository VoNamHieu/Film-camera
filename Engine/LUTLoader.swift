// LUTLoader.swift
// Film Camera - .cube LUT File Loader
// ★ FIX: Better path handling + Debug logging

import Foundation
import Metal

/// Loads .cube LUT files and creates 3D Metal textures
class LUTLoader {
    
    /// Load a .cube file and create a 3D texture
    static func load(filename: String, device: MTLDevice) -> MTLTexture? {
        // ★ FIX: Handle "luts/xxx.cube" path format
        let cleanFilename = extractFilename(from: filename)
        
        // ★ DEBUG: List all .cube files in bundle
        print("🔍 Looking for LUT: \(filename) (cleaned: \(cleanFilename))")
        
        #if DEBUG
        listBundleCubeFiles()
        #endif
        
        // Try multiple locations
        let url = findLUTFile(named: cleanFilename)
        
        guard let fileURL = url else {
            print("❌ LUT file NOT FOUND: \(filename) (cleaned: \(cleanFilename))")
            return nil
        }
        
        print("✅ LUT file FOUND: \(fileURL.lastPathComponent)")
        return load(url: fileURL, device: device)
    }
    
    /// Debug: List all .cube files in bundle
    private static func listBundleCubeFiles() {
        if let resourcePath = Bundle.main.resourcePath {
            let fm = FileManager.default
            if let enumerator = fm.enumerator(atPath: resourcePath) {
                let allFiles = enumerator.allObjects.compactMap { $0 as? String }
                let cubeFiles = allFiles.filter { $0.lowercased().hasSuffix(".cube") }
                if cubeFiles.isEmpty {
                    print("⚠️ NO .cube files found in bundle! Check Target Membership.")
                } else {
                    print("📁 All .cube files in bundle (\(cubeFiles.count)):")
                    cubeFiles.prefix(10).forEach { print("   - \($0)") }
                    if cubeFiles.count > 10 {
                        print("   ... and \(cubeFiles.count - 10) more")
                    }
                }
            }
        }
    }
    
    /// Extract filename from path like "luts/Kodak_Portra_400_Linear.cube"
    private static func extractFilename(from path: String) -> String {
        // Remove directory components
        let filename = (path as NSString).lastPathComponent
        return filename
    }
    
    /// Search for LUT file in multiple locations
    private static func findLUTFile(named filename: String) -> URL? {
        let filenameWithoutExtension = (filename as NSString).deletingPathExtension
        
        // Try these locations in order:
        let searchPaths: [(String?, String?)] = [
            (filename, nil),                           // Exact filename
            (filenameWithoutExtension, "cube"),        // Without extension
            ("LUTs/\(filename)", nil),                 // In LUTs folder
            ("luts/\(filename)", nil),                 // In luts folder (lowercase)
            ("Resources/LUTs/\(filename)", nil),       // In Resources/LUTs
        ]
        
        for (name, ext) in searchPaths {
            if let name = name {
                if let ext = ext {
                    if let url = Bundle.main.url(forResource: name, withExtension: ext) {
                        return url
                    }
                } else {
                    if let url = Bundle.main.url(forResource: name, withExtension: nil) {
                        return url
                    }
                    // Also try without path components
                    let baseName = (name as NSString).lastPathComponent
                    let baseNameWithoutExt = (baseName as NSString).deletingPathExtension
                    if let url = Bundle.main.url(forResource: baseNameWithoutExt, withExtension: "cube") {
                        return url
                    }
                }
            }
        }
        
        return nil
    }
    
    /// Load a .cube file from URL
    static func load(url: URL, device: MTLDevice) -> MTLTexture? {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            print("❌ Could not read LUT file: \(url)")
            return nil
        }
        
        return parse(content: content, device: device)
    }
    
    /// Parse .cube file content
    private static func parse(content: String, device: MTLDevice) -> MTLTexture? {
        var size: Int = 0
        var data: [Float] = []
        
        let lines = content.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Skip comments and empty lines
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                continue
            }
            
            // Parse LUT size
            if trimmed.hasPrefix("LUT_3D_SIZE") {
                let parts = trimmed.split(separator: " ")
                if parts.count >= 2, let s = Int(parts[1]) {
                    size = s
                    print("📊 LUT size: \(size)x\(size)x\(size)")
                }
                continue
            }
            
            // Skip other metadata
            if trimmed.hasPrefix("TITLE") || trimmed.hasPrefix("DOMAIN") {
                continue
            }
            
            // Parse RGB values
            let values = trimmed.split(separator: " ").compactMap { Float($0) }
            if values.count >= 3 {
                data.append(contentsOf: values[0..<3])
            }
        }
        
        let expectedCount = size * size * size * 3
        guard size > 0, data.count == expectedCount else {
            print("❌ Invalid LUT data: size=\(size), values=\(data.count), expected=\(expectedCount)")
            return nil
        }
        
        return createTexture(data: data, size: size, device: device)
    }
    
    /// Create 3D texture from LUT data
    /// ★ OPTIMIZED: Use rgba16Float instead of rgba32Float
    /// - rgba32Float: 16 bytes/pixel → 575 KB for 33³ LUT
    /// - rgba16Float: 8 bytes/pixel → 288 KB for 33³ LUT (50% reduction)
    /// Visual quality is identical for color grading purposes
    private static func createTexture(data: [Float], size: Int, device: MTLDevice) -> MTLTexture? {
        let descriptor = MTLTextureDescriptor()
        descriptor.textureType = .type3D
        descriptor.pixelFormat = .rgba16Float  // ★ CHANGED from .rgba32Float
        descriptor.width = size
        descriptor.height = size
        descriptor.depth = size
        descriptor.usage = .shaderRead

        guard let texture = device.makeTexture(descriptor: descriptor) else {
            print("❌ Failed to create 3D texture")
            return nil
        }

        // Convert RGB Float32 to RGBA Float16
        let totalPixels = size * size * size
        var rgba16Data = [UInt16](repeating: 0, count: totalPixels * 4)

        for i in 0..<totalPixels {
            let srcIdx = i * 3
            let dstIdx = i * 4
            rgba16Data[dstIdx + 0] = floatToHalf(data[srcIdx + 0])  // R
            rgba16Data[dstIdx + 1] = floatToHalf(data[srcIdx + 1])  // G
            rgba16Data[dstIdx + 2] = floatToHalf(data[srcIdx + 2])  // B
            rgba16Data[dstIdx + 3] = floatToHalf(1.0)               // A
        }

        let region = MTLRegion(
            origin: MTLOrigin(x: 0, y: 0, z: 0),
            size: MTLSize(width: size, height: size, depth: size)
        )

        let bytesPerRow = size * 4 * MemoryLayout<UInt16>.size  // 8 bytes per pixel
        let bytesPerImage = bytesPerRow * size

        rgba16Data.withUnsafeBytes { ptr in
            texture.replace(
                region: region,
                mipmapLevel: 0,
                slice: 0,
                withBytes: ptr.baseAddress!,
                bytesPerRow: bytesPerRow,
                bytesPerImage: bytesPerImage
            )
        }

        print("✅ LUT texture created: \(size)x\(size)x\(size) (rgba16Float)")
        return texture
    }

    /// Convert Float32 to Float16 (IEEE 754 half-precision)
    private static func floatToHalf(_ value: Float) -> UInt16 {
        let bits = value.bitPattern
        let sign = (bits >> 31) & 0x1
        let exp = (bits >> 23) & 0xFF
        let mantissa = bits & 0x7FFFFF

        var halfSign = UInt16(sign << 15)
        var halfExp: UInt16
        var halfMantissa: UInt16

        if exp == 0 {
            // Zero or denormalized
            halfExp = 0
            halfMantissa = 0
        } else if exp == 0xFF {
            // Infinity or NaN
            halfExp = 0x1F
            halfMantissa = mantissa != 0 ? 0x200 : 0
        } else {
            // Normalized
            let newExp = Int(exp) - 127 + 15
            if newExp >= 31 {
                // Overflow → Infinity
                halfExp = 0x1F
                halfMantissa = 0
            } else if newExp <= 0 {
                // Underflow → Zero
                halfExp = 0
                halfMantissa = 0
            } else {
                halfExp = UInt16(newExp)
                halfMantissa = UInt16(mantissa >> 13)
            }
        }

        return halfSign | (halfExp << 10) | halfMantissa
    }
}
