// TexturePool.swift
// Film Camera - Metal Texture Memory Management (FIXED VERSION)
// Fix: Storage mode for iOS (.shared instead of .private)

import Foundation
import Metal

/// Manages reusable Metal textures to avoid allocation overhead
class TexturePool {
    private let device: MTLDevice
    private var availableTextures: [String: [MTLTexture]] = [:]
    private var inUseTextures: Set<ObjectIdentifier> = []
    private let lock = NSLock()
    
    init(device: MTLDevice) {
        self.device = device
    }
    
    /// Get or create a texture with the specified descriptor
    func texture(matching descriptor: MTLTextureDescriptor) -> MTLTexture? {
        lock.lock()
        defer { lock.unlock() }
        
        let key = textureKey(for: descriptor)
        
        // Try to reuse an existing texture
        if var textures = availableTextures[key], !textures.isEmpty {
            let texture = textures.removeLast()
            availableTextures[key] = textures
            inUseTextures.insert(ObjectIdentifier(texture))
            return texture
        }
        
        // Create a new texture
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            return nil
        }
        
        inUseTextures.insert(ObjectIdentifier(texture))
        return texture
    }
    
    /// Return a texture to the pool for reuse
    func recycle(_ texture: MTLTexture) {
        lock.lock()
        defer { lock.unlock() }
        
        let id = ObjectIdentifier(texture)
        guard inUseTextures.contains(id) else { return }
        
        inUseTextures.remove(id)
        
        let key = textureKey(for: texture)
        if availableTextures[key] == nil {
            availableTextures[key] = []
        }
        availableTextures[key]?.append(texture)
    }
    
    /// Create a texture for render target use
    func renderTargetTexture(width: Int, height: Int, pixelFormat: MTLPixelFormat = .bgra8Unorm) -> MTLTexture? {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: pixelFormat,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
        
        // ★ FIX: Use correct storage mode for platform
        #if os(iOS) || os(tvOS)
        // iOS uses unified memory - .shared allows CPU read/write
        descriptor.storageMode = .shared
        #elseif os(macOS)
        // macOS with discrete GPU benefits from .private
        // But for simplicity and compatibility, .shared works too
        if device.hasUnifiedMemory {
            descriptor.storageMode = .shared
        } else {
            descriptor.storageMode = .private
        }
        #else
        descriptor.storageMode = .shared
        #endif
        
        return texture(matching: descriptor)
    }
    
    /// Create a texture optimized for CPU read (for photo capture)
    func readableTexture(width: Int, height: Int, pixelFormat: MTLPixelFormat = .bgra8Unorm) -> MTLTexture? {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: pixelFormat,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
        
        // ★ Always use .shared for CPU-readable textures
        descriptor.storageMode = .shared
        
        return texture(matching: descriptor)
    }
    
    /// Clear all cached textures
    func purge() {
        lock.lock()
        defer { lock.unlock() }
        
        availableTextures.removeAll()
    }
    
    /// Get pool statistics for debugging
    func statistics() -> (available: Int, inUse: Int) {
        lock.lock()
        defer { lock.unlock() }
        
        let availableCount = availableTextures.values.reduce(0) { $0 + $1.count }
        return (availableCount, inUseTextures.count)
    }
    
    // MARK: - Private
    
    private func textureKey(for descriptor: MTLTextureDescriptor) -> String {
        return "\(descriptor.width)x\(descriptor.height)_\(descriptor.pixelFormat.rawValue)_\(descriptor.usage.rawValue)_\(descriptor.storageMode.rawValue)"
    }
    
    private func textureKey(for texture: MTLTexture) -> String {
        return "\(texture.width)x\(texture.height)_\(texture.pixelFormat.rawValue)_\(texture.usage.rawValue)_\(texture.storageMode.rawValue)"
    }
}
