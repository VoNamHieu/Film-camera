//
//  CapturedPhoto.swift
//  Film Camera
//
//  Core data model for captured photos stored in local gallery
//

import Foundation
import UIKit

// MARK: - User Adjustments
/// Adjustments that ADD to the preset values (not replace)
/// Range: -100 to +100, default = 0
struct UserAdjustments: Codable, Equatable {
    var exposure: Float = 0
    var contrast: Float = 0
    var saturation: Float = 0
    var temperature: Float = 0
    var fade: Float = 0
    var grain: Float = 0
    var vignette: Float = 0

    /// Check if any adjustment has been made
    var hasAdjustments: Bool {
        exposure != 0 || contrast != 0 || saturation != 0 ||
        temperature != 0 || fade != 0 || grain != 0 || vignette != 0
    }

    /// Clamp all values to valid range
    mutating func clamp() {
        exposure = max(-100, min(100, exposure))
        contrast = max(-100, min(100, contrast))
        saturation = max(-100, min(100, saturation))
        temperature = max(-100, min(100, temperature))
        fade = max(-100, min(100, fade))
        grain = max(-100, min(100, grain))
        vignette = max(-100, min(100, vignette))
    }

    static let `default` = UserAdjustments()
}

// MARK: - Captured Photo
/// Represents a photo captured and stored in the app's local gallery
struct CapturedPhoto: Codable, Identifiable, Equatable {
    let id: UUID
    let createdAt: Date
    let presetId: String
    let presetLabel: String

    /// Relative path from Documents directory
    let originalFileName: String
    let filteredFileName: String
    let thumbnailFileName: String

    var userAdjustments: UserAdjustments
    var isFavorite: Bool

    // MARK: - Computed Paths

    var originalPath: URL {
        GalleryManager.photosDirectory.appendingPathComponent(originalFileName)
    }

    var filteredPath: URL {
        GalleryManager.photosDirectory.appendingPathComponent(filteredFileName)
    }

    var thumbnailPath: URL {
        GalleryManager.thumbnailsDirectory.appendingPathComponent(thumbnailFileName)
    }

    // MARK: - Initializer

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        presetId: String,
        presetLabel: String,
        originalFileName: String,
        filteredFileName: String,
        thumbnailFileName: String,
        userAdjustments: UserAdjustments = .default,
        isFavorite: Bool = false
    ) {
        self.id = id
        self.createdAt = createdAt
        self.presetId = presetId
        self.presetLabel = presetLabel
        self.originalFileName = originalFileName
        self.filteredFileName = filteredFileName
        self.thumbnailFileName = thumbnailFileName
        self.userAdjustments = userAdjustments
        self.isFavorite = isFavorite
    }

    // MARK: - Convenience Methods

    /// Format creation date for display
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }

    /// Short date for grid display
    var shortDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: createdAt)
    }
}

// MARK: - Gallery Metadata
/// Container for persisting gallery state to JSON
struct GalleryMetadata: Codable {
    var photos: [CapturedPhoto]
    var lastModified: Date
    var version: Int

    static let currentVersion = 1

    init(photos: [CapturedPhoto] = [], lastModified: Date = Date()) {
        self.photos = photos
        self.lastModified = lastModified
        self.version = Self.currentVersion
    }
}
