//
//  PhotoDetailView.swift
//  Film Camera
//
//  Detail view for viewing, editing, and sharing captured photos
//

import SwiftUI

struct PhotoDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var galleryManager = GalleryManager.shared

    let photo: CapturedPhoto

    @State private var displayImage: UIImage?
    @State private var isLoading = true
    @State private var showShareSheet = false
    @State private var showDeleteConfirmation = false
    @State private var showExportSuccess = false
    @State private var showOriginal = false
    @State private var originalImage: UIImage?
    @State private var isFavorite: Bool

    init(photo: CapturedPhoto) {
        self.photo = photo
        _isFavorite = State(initialValue: photo.isFavorite)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else if let image = showOriginal ? originalImage : displayImage {
                    GeometryReader { geometry in
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: geometry.size.width, maxHeight: geometry.size.height)
                            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "photo")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        Text("Failed to load image")
                            .foregroundColor(.gray)
                    }
                }

                // Original/Filtered toggle indicator
                if showOriginal {
                    VStack {
                        Text("Original")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                            .padding(.top, 60)
                        Spacer()
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                    }
                }

                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Text(photo.presetLabel)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        Text(photo.formattedDate)
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            Task {
                                await toggleFavorite()
                            }
                        } label: {
                            Label(
                                isFavorite ? "Remove from Favorites" : "Add to Favorites",
                                systemImage: isFavorite ? "heart.slash" : "heart"
                            )
                        }

                        Button {
                            Task {
                                await exportToPhotos()
                            }
                        } label: {
                            Label("Save to Photos", systemImage: "square.and.arrow.down")
                        }

                        Button {
                            showShareSheet = true
                        } label: {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }

                        Divider()

                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.white)
                    }
                }
            }
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .overlay(alignment: .bottom) {
                bottomToolbar
            }
            .gesture(
                LongPressGesture(minimumDuration: 0.1)
                    .onChanged { _ in
                        if originalImage != nil {
                            showOriginal = true
                        }
                    }
                    .onEnded { _ in
                        showOriginal = false
                    }
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { _ in
                        showOriginal = false
                    }
            )
            .confirmationDialog(
                "Delete this photo?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    Task {
                        await deletePhoto()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This photo will be permanently deleted from your gallery.")
            }
            .sheet(isPresented: $showShareSheet) {
                if let image = displayImage {
                    ShareSheet(items: [image])
                }
            }
            .alert("Saved to Photos", isPresented: $showExportSuccess) {
                Button("OK", role: .cancel) {}
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await loadImages()
        }
    }

    // MARK: - Bottom Toolbar

    private var bottomToolbar: some View {
        HStack(spacing: 50) {
            // Favorite button
            Button {
                Task {
                    await toggleFavorite()
                }
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .font(.title2)
                        .foregroundColor(isFavorite ? .red : .white)
                    Text("Favorite")
                        .font(.caption2)
                        .foregroundColor(.white)
                }
            }

            // Compare button (hold to see original)
            VStack(spacing: 4) {
                Image(systemName: "rectangle.on.rectangle")
                    .font(.title2)
                    .foregroundColor(originalImage != nil ? .white : .gray)
                Text("Hold to Compare")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            .opacity(originalImage != nil ? 1 : 0.5)

            // Export button
            Button {
                Task {
                    await exportToPhotos()
                }
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.title2)
                        .foregroundColor(.white)
                    Text("Save")
                        .font(.caption2)
                        .foregroundColor(.white)
                }
            }
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 40)
        .background(.ultraThinMaterial)
    }

    // MARK: - Actions

    private func loadImages() async {
        isLoading = true

        // Load filtered image first (primary display)
        displayImage = await galleryManager.loadFilteredImage(id: photo.id)

        // Load original for comparison
        originalImage = await galleryManager.loadOriginalImage(id: photo.id)

        isLoading = false
    }

    private func toggleFavorite() async {
        isFavorite.toggle()
        _ = await galleryManager.toggleFavorite(id: photo.id)
    }

    private func exportToPhotos() async {
        let success = await galleryManager.exportToPhotoLibrary(photo)
        if success {
            showExportSuccess = true
        }
    }

    private func deletePhoto() async {
        _ = await galleryManager.delete(id: photo.id)
        dismiss()
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    PhotoDetailView(
        photo: CapturedPhoto(
            presetId: "portra_400",
            presetLabel: "Portra 400",
            originalFileName: "test_original.jpg",
            filteredFileName: "test_filtered.jpg",
            thumbnailFileName: "test_thumb.jpg"
        )
    )
}
