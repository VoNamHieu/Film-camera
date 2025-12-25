//
//  GalleryManager.swift
//  Film Camera
//
//  Singleton manager for local photo gallery with metadata persistence
//

import Foundation
import UIKit
import Photos
import Combine

final class GalleryManager: ObservableObject {

    // MARK: - Singleton

    static let shared = GalleryManager()

    // MARK: - Published State

    @Published private(set) var photos: [CapturedPhoto] = []
    @Published private(set) var isLoading = false

    // MARK: - Directory Structure (nonisolated for static access)

    static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    static var photosDirectory: URL {
        documentsDirectory.appendingPathComponent("photos", isDirectory: true)
    }

    static var thumbnailsDirectory: URL {
        documentsDirectory.appendingPathComponent("thumbnails", isDirectory: true)
    }

    static var metadataURL: URL {
        documentsDirectory.appendingPathComponent("photos_metadata.json")
    }

    // MARK: - Configuration

    private let thumbnailSize: CGFloat = 450 // For @3x Retina displays
    private let jpegQualityFiltered: CGFloat = 0.88
    private let jpegQualityThumbnail: CGFloat = 0.75

    // MARK: - Thumbnail Cache

    private var thumbnailCache = NSCache<NSString, UIImage>()

    // MARK: - Private Queue

    private let fileQueue = DispatchQueue(label: "com.filmcamera.gallery.file", qos: .userInitiated)

    // MARK: - Initialization

    private init() {
        setupDirectories()
        loadMetadata()
        setupMemoryWarningObserver()
    }

    // MARK: - Setup

    private func setupDirectories() {
        let fm = FileManager.default
        do {
            try fm.createDirectory(at: Self.photosDirectory, withIntermediateDirectories: true)
            try fm.createDirectory(at: Self.thumbnailsDirectory, withIntermediateDirectories: true)
        } catch {
            print("[GalleryManager] Failed to create directories: \(error)")
        }
    }

    private func setupMemoryWarningObserver() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.clearThumbnailCache()
        }
    }

    // MARK: - CRUD Operations

    /// Save a captured photo with its preset to the gallery
    /// - Parameters:
    ///   - originalImage: The unfiltered image from camera
    ///   - filteredImage: The image with filter applied
    ///   - preset: The filter preset used
    /// - Returns: The saved CapturedPhoto model, or nil if failed
    func save(
        originalImage: UIImage,
        filteredImage: UIImage,
        preset: FilterPreset
    ) async -> CapturedPhoto? {
        let id = UUID()
        let originalFileName = "\(id.uuidString)_original.jpg"
        let filteredFileName = "\(id.uuidString)_filtered.jpg"
        let thumbnailFileName = "\(id.uuidString)_thumb.jpg"

        // Normalize image orientation
        let normalizedOriginal = originalImage.normalizedOrientation()
        let normalizedFiltered = filteredImage.normalizedOrientation()

        // Generate thumbnail from filtered image
        guard let thumbnail = generateThumbnail(from: normalizedFiltered) else {
            print("[GalleryManager] Failed to generate thumbnail")
            return nil
        }

        // Write files on background queue
        let success = await withCheckedContinuation { continuation in
            fileQueue.async {
                let fm = FileManager.default

                // Check available disk space (need at least 10MB)
                if let attrs = try? fm.attributesOfFileSystem(forPath: Self.documentsDirectory.path),
                   let freeSpace = attrs[.systemFreeSize] as? Int64,
                   freeSpace < 10_000_000 {
                    print("[GalleryManager] Insufficient disk space")
                    continuation.resume(returning: false)
                    return
                }

                // Write original (high quality)
                let originalPath = Self.photosDirectory.appendingPathComponent(originalFileName)
                guard let originalData = normalizedOriginal.jpegData(compressionQuality: 0.95) else {
                    continuation.resume(returning: false)
                    return
                }

                // Write filtered
                let filteredPath = Self.photosDirectory.appendingPathComponent(filteredFileName)
                guard let filteredData = normalizedFiltered.jpegData(compressionQuality: self.jpegQualityFiltered) else {
                    continuation.resume(returning: false)
                    return
                }

                // Write thumbnail
                let thumbnailPath = Self.thumbnailsDirectory.appendingPathComponent(thumbnailFileName)
                guard let thumbnailData = thumbnail.jpegData(compressionQuality: self.jpegQualityThumbnail) else {
                    continuation.resume(returning: false)
                    return
                }

                do {
                    try originalData.write(to: originalPath, options: .atomic)
                    try filteredData.write(to: filteredPath, options: .atomic)
                    try thumbnailData.write(to: thumbnailPath, options: .atomic)
                    continuation.resume(returning: true)
                } catch {
                    print("[GalleryManager] Failed to write files: \(error)")
                    // Cleanup partial writes
                    try? fm.removeItem(at: originalPath)
                    try? fm.removeItem(at: filteredPath)
                    try? fm.removeItem(at: thumbnailPath)
                    continuation.resume(returning: false)
                }
            }
        }

        guard success else { return nil }

        // Create photo model
        let photo = CapturedPhoto(
            id: id,
            createdAt: Date(),
            presetId: preset.id,
            presetLabel: preset.label,
            originalFileName: originalFileName,
            filteredFileName: filteredFileName,
            thumbnailFileName: thumbnailFileName
        )

        // Add to collection and save metadata
        photos.insert(photo, at: 0) // Most recent first
        await saveMetadata()

        // Cache thumbnail
        thumbnailCache.setObject(thumbnail, forKey: id.uuidString as NSString)

        return photo
    }

    /// Load a specific photo by ID
    func load(id: UUID) -> CapturedPhoto? {
        photos.first { $0.id == id }
    }

    /// Load all photos (already loaded at init)
    func loadAll() -> [CapturedPhoto] {
        photos
    }

    /// Update a photo's properties
    func update(_ photo: CapturedPhoto) async -> Bool {
        guard let index = photos.firstIndex(where: { $0.id == photo.id }) else {
            return false
        }

        photos[index] = photo
        await saveMetadata()
        return true
    }

    /// Toggle favorite status
    func toggleFavorite(id: UUID) async -> Bool {
        guard let index = photos.firstIndex(where: { $0.id == id }) else {
            return false
        }

        photos[index].isFavorite.toggle()
        await saveMetadata()
        return true
    }

    /// Delete a photo and its files
    func delete(id: UUID) async -> Bool {
        guard let index = photos.firstIndex(where: { $0.id == id }) else {
            return false
        }

        let photo = photos[index]

        // Remove files on background queue
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            fileQueue.async {
                let fm = FileManager.default
                try? fm.removeItem(at: photo.originalPath)
                try? fm.removeItem(at: photo.filteredPath)
                try? fm.removeItem(at: photo.thumbnailPath)
                continuation.resume()
            }
        }

        // Remove from collection
        photos.remove(at: index)
        thumbnailCache.removeObject(forKey: id.uuidString as NSString)
        await saveMetadata()

        return true
    }

    /// Delete multiple photos
    func deleteMultiple(ids: Set<UUID>) async {
        for id in ids {
            _ = await delete(id: id)
        }
    }

    // MARK: - Thumbnail Operations

    /// Generate thumbnail from image
    private func generateThumbnail(from image: UIImage) -> UIImage? {
        let size = CGSize(width: thumbnailSize, height: thumbnailSize)
        let aspectRatio = image.size.width / image.size.height

        var targetSize: CGSize
        if aspectRatio > 1 {
            // Landscape - fit height
            targetSize = CGSize(width: size.height * aspectRatio, height: size.height)
        } else {
            // Portrait - fit width
            targetSize = CGSize(width: size.width, height: size.width / aspectRatio)
        }

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }

        // Center crop to square
        let cropRect = CGRect(
            x: (targetSize.width - size.width) / 2,
            y: (targetSize.height - size.height) / 2,
            width: size.width,
            height: size.height
        )

        guard let cgImage = resized.cgImage?.cropping(to: cropRect) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }

    /// Load thumbnail with caching
    func loadThumbnail(id: UUID) -> UIImage? {
        let cacheKey = id.uuidString as NSString

        // Check cache first
        if let cached = thumbnailCache.object(forKey: cacheKey) {
            return cached
        }

        // Find photo
        guard let photo = photos.first(where: { $0.id == id }) else {
            return nil
        }

        // Load from disk
        guard let image = UIImage(contentsOfFile: photo.thumbnailPath.path) else {
            return nil
        }

        // Cache and return
        thumbnailCache.setObject(image, forKey: cacheKey)
        return image
    }

    /// Load thumbnail asynchronously
    func loadThumbnailAsync(id: UUID) async -> UIImage? {
        let cacheKey = id.uuidString as NSString

        // Check cache first
        if let cached = thumbnailCache.object(forKey: cacheKey) {
            return cached
        }

        // Find photo
        guard let photo = photos.first(where: { $0.id == id }) else {
            return nil
        }

        // Load from disk on background
        let image = await withCheckedContinuation { continuation in
            fileQueue.async {
                let img = UIImage(contentsOfFile: photo.thumbnailPath.path)
                continuation.resume(returning: img)
            }
        }

        // Cache and return
        if let image = image {
            thumbnailCache.setObject(image, forKey: cacheKey)
        }
        return image
    }

    /// Clear thumbnail cache
    func clearThumbnailCache() {
        thumbnailCache.removeAllObjects()
        print("[GalleryManager] Thumbnail cache cleared")
    }

    // MARK: - Full Image Loading

    /// Load filtered image for a photo
    func loadFilteredImage(id: UUID) async -> UIImage? {
        guard let photo = photos.first(where: { $0.id == id }) else {
            return nil
        }

        return await withCheckedContinuation { continuation in
            fileQueue.async {
                let image = UIImage(contentsOfFile: photo.filteredPath.path)
                continuation.resume(returning: image)
            }
        }
    }

    /// Load original image for a photo
    func loadOriginalImage(id: UUID) async -> UIImage? {
        guard let photo = photos.first(where: { $0.id == id }) else {
            return nil
        }

        return await withCheckedContinuation { continuation in
            fileQueue.async {
                let image = UIImage(contentsOfFile: photo.originalPath.path)
                continuation.resume(returning: image)
            }
        }
    }

    // MARK: - Export

    /// Export photo to system Photo Library
    func exportToPhotoLibrary(_ photo: CapturedPhoto) async -> Bool {
        guard let image = await loadFilteredImage(id: photo.id) else {
            return false
        }

        return await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                guard status == .authorized || status == .limited else {
                    continuation.resume(returning: false)
                    return
                }

                PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.creationRequestForAsset(from: image)
                } completionHandler: { success, error in
                    if let error = error {
                        print("[GalleryManager] Export failed: \(error)")
                    }
                    continuation.resume(returning: success)
                }
            }
        }
    }

    // MARK: - Metadata Persistence

    private func saveMetadata() async {
        let metadata = GalleryMetadata(photos: photos, lastModified: Date())

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            fileQueue.async {
                do {
                    let encoder = JSONEncoder()
                    encoder.dateEncodingStrategy = .iso8601
                    encoder.outputFormatting = .prettyPrinted
                    let data = try encoder.encode(metadata)

                    // Atomic write using temp file
                    let tempURL = Self.documentsDirectory.appendingPathComponent("metadata_temp.json")
                    try data.write(to: tempURL, options: .atomic)
                    try FileManager.default.moveItem(at: tempURL, to: Self.metadataURL)
                } catch {
                    // Fallback: direct write
                    do {
                        let encoder = JSONEncoder()
                        encoder.dateEncodingStrategy = .iso8601
                        let data = try encoder.encode(metadata)
                        try data.write(to: Self.metadataURL, options: .atomic)
                    } catch {
                        print("[GalleryManager] Failed to save metadata: \(error)")
                    }
                }
                continuation.resume()
            }
        }
    }

    private func loadMetadata() {
        isLoading = true

        guard FileManager.default.fileExists(atPath: Self.metadataURL.path) else {
            isLoading = false
            return
        }

        do {
            let data = try Data(contentsOf: Self.metadataURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let metadata = try decoder.decode(GalleryMetadata.self, from: data)

            // Validate files exist
            photos = metadata.photos.filter { photo in
                FileManager.default.fileExists(atPath: photo.filteredPath.path)
            }

            // Remove orphaned photos from metadata if any were filtered
            if photos.count != metadata.photos.count {
                Task {
                    await saveMetadata()
                }
            }

        } catch {
            print("[GalleryManager] Failed to load metadata: \(error)")
            photos = []
        }

        isLoading = false
    }

    // MARK: - Helpers

    /// Get most recent photo (for camera preview thumbnail)
    var mostRecentPhoto: CapturedPhoto? {
        photos.first
    }

    /// Get favorites only
    var favoritePhotos: [CapturedPhoto] {
        photos.filter { $0.isFavorite }
    }

    /// Get photos by preset
    func photos(forPreset presetId: String) -> [CapturedPhoto] {
        photos.filter { $0.presetId == presetId }
    }

    /// Total count
    var count: Int {
        photos.count
    }

    /// Check if gallery is empty
    var isEmpty: Bool {
        photos.isEmpty
    }
}

// MARK: - UIImage Extension

extension UIImage {
    /// Normalize image orientation to .up
    func normalizedOrientation() -> UIImage {
        guard imageOrientation != .up else { return self }

        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let normalized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return normalized ?? self
    }
}
