// LUTLoader.swift
// Film Camera - .cube LUT File Loader

import Foundation
import Metal

/// Loads .cube LUT files and creates 3D Metal textures
class LUTLoader {
    
    /// Load a .cube file and create a 3D texture
    static func load(filename: String, device: MTLDevice) -> MTLTexture? {
        // Try bundle first, then documents
        let url = Bundle.main.url(forResource: filename, withExtension: nil)
            ?? Bundle.main.url(forResource: (filename as NSString).deletingPathExtension, withExtension: "cube")
        
        guard let fileURL = url else {
            print("LUT file not found: \(filename)")
            return nil
        }
        
        return load(url: fileURL, device: device)
    }
    
    /// Load a .cube file from URL
    static func load(url: URL, device: MTLDevice) -> MTLTexture? {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            print("Could not read LUT file: \(url)")
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
        
        guard size > 0, data.count == size * size * size * 3 else {
            print("Invalid LUT data: size=\(size), values=\(data.count)")
            return nil
        }
        
        return createTexture(data: data, size: size, device: device)
    }
    
    /// Create 3D texture from LUT data
    private static func createTexture(data: [Float], size: Int, device: MTLDevice) -> MTLTexture? {
        let descriptor = MTLTextureDescriptor()
        descriptor.textureType = .type3D
        descriptor.pixelFormat = .rgba32Float
        descriptor.width = size
        descriptor.height = size
        descriptor.depth = size
        descriptor.usage = .shaderRead
        
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            return nil
        }
        
        // Convert RGB to RGBA
        var rgbaData: [Float] = []
        rgbaData.reserveCapacity(size * size * size * 4)
        
        for i in stride(from: 0, to: data.count, by: 3) {
            rgbaData.append(data[i])     // R
            rgbaData.append(data[i + 1]) // G
            rgbaData.append(data[i + 2]) // B
            rgbaData.append(1.0)         // A
        }
        
        let region = MTLRegion(
            origin: MTLOrigin(x: 0, y: 0, z: 0),
            size: MTLSize(width: size, height: size, depth: size)
        )
        
        let bytesPerRow = size * 4 * MemoryLayout<Float>.size
        let bytesPerImage = bytesPerRow * size
        
        rgbaData.withUnsafeBytes { ptr in
            texture.replace(
                region: region,
                mipmapLevel: 0,
                slice: 0,
                withBytes: ptr.baseAddress!,
                bytesPerRow: bytesPerRow,
                bytesPerImage: bytesPerImage
            )
        }
        
        return texture
    }
}
