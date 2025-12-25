//
//  GalleryView.swift
//  Film Camera
//
//  Grid view displaying captured photos from local gallery
//

import SwiftUI

struct GalleryView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var galleryManager = GalleryManager.shared

    @State private var selectedPhoto: CapturedPhoto?
    @State private var isSelectionMode = false
    @State private var selectedIds: Set<UUID> = []
    @State private var showDeleteConfirmation = false
    @State private var showExportSuccess = false
    @State private var filterFavorites = false

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    var displayedPhotos: [CapturedPhoto] {
        filterFavorites ? galleryManager.favoritePhotos : galleryManager.photos
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if galleryManager.isLoading {
                    ProgressView()
                        .tint(.white)
                } else if galleryManager.isEmpty {
                    emptyStateView
                } else {
                    photoGrid
                }
            }
            .navigationTitle(filterFavorites ? "Favorites" : "Gallery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        // Favorites filter
                        Button {
                            withAnimation {
                                filterFavorites.toggle()
                            }
                        } label: {
                            Image(systemName: filterFavorites ? "heart.fill" : "heart")
                                .foregroundColor(filterFavorites ? .red : .white)
                        }

                        // Selection mode
                        Button {
                            withAnimation {
                                isSelectionMode.toggle()
                                if !isSelectionMode {
                                    selectedIds.removeAll()
                                }
                            }
                        } label: {
                            Text(isSelectionMode ? "Done" : "Select")
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(item: $selectedPhoto) { photo in
                PhotoDetailView(photo: photo)
            }
            .confirmationDialog(
                "Delete \(selectedIds.count) photo\(selectedIds.count == 1 ? "" : "s")?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    Task {
                        await galleryManager.deleteMultiple(ids: selectedIds)
                        selectedIds.removeAll()
                        isSelectionMode = false
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
            .overlay(alignment: .bottom) {
                if isSelectionMode && !selectedIds.isEmpty {
                    selectionToolbar
                }
            }
            .alert("Exported to Photos", isPresented: $showExportSuccess) {
                Button("OK", role: .cancel) {}
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("No Photos Yet")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)

            Text("Capture photos with film filters\nand they'll appear here")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Photo Grid

    private var photoGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(displayedPhotos) { photo in
                    PhotoThumbnailCell(
                        photo: photo,
                        isSelected: selectedIds.contains(photo.id),
                        isSelectionMode: isSelectionMode
                    )
                    .onTapGesture {
                        if isSelectionMode {
                            toggleSelection(photo.id)
                        } else {
                            selectedPhoto = photo
                        }
                    }
                    .onLongPressGesture {
                        if !isSelectionMode {
                            isSelectionMode = true
                            selectedIds.insert(photo.id)
                        }
                    }
                }
            }
            .padding(.bottom, isSelectionMode && !selectedIds.isEmpty ? 80 : 0)
        }
    }

    // MARK: - Selection Toolbar

    private var selectionToolbar: some View {
        HStack(spacing: 40) {
            // Export button
            Button {
                Task {
                    await exportSelected()
                }
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title2)
                    Text("Export")
                        .font(.caption)
                }
                .foregroundColor(.white)
            }

            // Delete button
            Button {
                showDeleteConfirmation = true
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "trash")
                        .font(.title2)
                    Text("Delete")
                        .font(.caption)
                }
                .foregroundColor(.red)
            }

            // Select all
            Button {
                if selectedIds.count == displayedPhotos.count {
                    selectedIds.removeAll()
                } else {
                    selectedIds = Set(displayedPhotos.map { $0.id })
                }
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: selectedIds.count == displayedPhotos.count ? "checkmark.circle.fill" : "checkmark.circle")
                        .font(.title2)
                    Text("All")
                        .font(.caption)
                }
                .foregroundColor(.white)
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 40)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .padding(.bottom, 20)
    }

    // MARK: - Actions

    private func toggleSelection(_ id: UUID) {
        if selectedIds.contains(id) {
            selectedIds.remove(id)
        } else {
            selectedIds.insert(id)
        }
    }

    private func exportSelected() async {
        var successCount = 0

        for id in selectedIds {
            if let photo = galleryManager.load(id: id) {
                let success = await galleryManager.exportToPhotoLibrary(photo)
                if success { successCount += 1 }
            }
        }

        if successCount > 0 {
            showExportSuccess = true
        }

        selectedIds.removeAll()
        isSelectionMode = false
    }
}

// MARK: - Thumbnail Cell

struct PhotoThumbnailCell: View {
    let photo: CapturedPhoto
    let isSelected: Bool
    let isSelectionMode: Bool

    @State private var thumbnail: UIImage?
    private let galleryManager = GalleryManager.shared

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topTrailing) {
                // Thumbnail image
                if let thumbnail = thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.width)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: geometry.size.width, height: geometry.size.width)
                        .overlay {
                            ProgressView()
                                .tint(.white)
                        }
                }

                // Selection overlay
                if isSelectionMode {
                    ZStack {
                        Circle()
                            .fill(isSelected ? Color.blue : Color.black.opacity(0.5))
                            .frame(width: 24, height: 24)

                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.caption.bold())
                                .foregroundColor(.white)
                        }
                    }
                    .padding(6)
                }

                // Favorite indicator
                if photo.isFavorite && !isSelectionMode {
                    Image(systemName: "heart.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(6)
                }
            }
            .overlay {
                if isSelected {
                    Rectangle()
                        .stroke(Color.blue, lineWidth: 3)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .task {
            thumbnail = await galleryManager.loadThumbnailAsync(id: photo.id)
        }
    }
}

// MARK: - Preview

#Preview {
    GalleryView()
}
