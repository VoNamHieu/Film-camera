// PhotoEditorView.swift
// Film Camera - Photo Editor with Filter Application
// ★★★ FIXED: Better debug logging, proper state updates, filter display ★★★

import SwiftUI
import PhotosUI
import Photos
import UniformTypeIdentifiers

// MARK: - ★★★ FIX: Custom Transferable for reliable image loading on real devices ★★★

struct PickedImage: Transferable {
    let image: UIImage

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .image) { data in
            guard let uiImage = UIImage(data: data) else {
                throw TransferError.importFailed
            }
            return PickedImage(image: uiImage)
        }
    }

    enum TransferError: Error {
        case importFailed
    }
}

// MARK: - Photo Editor View

struct PhotoEditorView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var selectedItem: PhotosPickerItem?
    @State private var originalImage: UIImage?
    @State private var filteredImage: UIImage?
    @State private var selectedPreset: FilterPreset = FilmPresets.warmPortrait400
    @State private var selectedCategory: FilterCategory = .professional

    @State private var isProcessing = false
    @State private var showSavedAlert = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var showBeforeAfter = false

    // Compare slider position
    @State private var comparePosition: CGFloat = 0.5

    // Task cancellation to prevent race conditions
    @State private var currentFilterTask: Task<Void, Never>?

    // Separate preview and full-res images
    @State private var previewImage: UIImage?
    @State private var fullResImage: UIImage?

    // Processing state with ID to track which filter is active
    @State private var processingPresetId: String?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Navigation bar
                customNavigationBar

                // Image display area
                imageDisplayArea

                // Controls (only show when image is loaded)
                if originalImage != nil {
                    controlsArea
                }
            }

            // Processing overlay
            if isProcessing {
                processingOverlay
            }
        }
        .onChange(of: selectedItem) { _, newItem in
            loadImage(from: newItem)
        }
        .onChange(of: selectedPreset) { _, newPreset in
            if originalImage != nil {
                applyFilterDebounced(preset: newPreset)
            }
        }
        .alert("Photo Saved", isPresented: $showSavedAlert) {
            Button("OK") { dismiss() }
        } message: {
            Text("Your edited photo has been saved to your library.")
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Custom Navigation Bar

    private var customNavigationBar: some View {
        HStack {
            Button("Cancel") {
                currentFilterTask?.cancel()
                dismiss()
            }
            .foregroundColor(.white)

            Spacer()

            Text("Photo Editor")
                .font(.headline)
                .foregroundColor(.white)

            Spacer()

            if filteredImage != nil {
                Button("Save") { savePhoto() }
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            } else {
                Text("Save")
                    .fontWeight(.semibold)
                    .foregroundColor(.clear)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.black)
    }

    // MARK: - Image Display Area

    private var imageDisplayArea: some View {
        GeometryReader { geometry in
            ZStack {
                if let original = originalImage {
                    if showBeforeAfter, let filtered = filteredImage {
                        CompareSliderView(
                            beforeImage: original,
                            afterImage: filtered,
                            position: $comparePosition
                        )
                    } else {
                        let imageToShow = filteredImage ?? original
                        Image(uiImage: imageToShow)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    photoPickerPrompt
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Photo Picker Prompt

    private var photoPickerPrompt: some View {
        VStack(spacing: 24) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 64))
                .foregroundColor(.white.opacity(0.6))

            Text("Select a Photo to Edit")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.white)

            PhotosPicker(selection: $selectedItem, matching: .images) {
                HStack {
                    Image(systemName: "photo.fill")
                    Text("Choose from Library")
                }
                .font(.headline)
                .foregroundColor(.black)
                .frame(width: 220, height: 50)
                .background(.white)
                .cornerRadius(25)
            }
        }
    }

    // MARK: - Controls Area

    private var controlsArea: some View {
        VStack(spacing: 12) {
            HStack {
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    HStack(spacing: 6) {
                        Image(systemName: "photo.badge.plus")
                        Text("Change")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.2))
                    .cornerRadius(18)
                }

                Spacer()

                HStack(spacing: 6) {
                    if processingPresetId == selectedPreset.id {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.7)
                    }
                    Text(selectedPreset.label)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }

                Spacer()

                Button(action: { showBeforeAfter.toggle() }) {
                    HStack(spacing: 6) {
                        Image(systemName: showBeforeAfter ? "square.split.2x1.fill" : "square.split.2x1")
                        Text("Compare")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(showBeforeAfter ? .black : .white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(showBeforeAfter ? .white : .white.opacity(0.2))
                    .cornerRadius(18)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            categoryScrollView
            presetScrollView
                .padding(.bottom, 20)
        }
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - Category Scroll

    private var categoryScrollView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(FilterCategory.allCases, id: \.self) { category in
                    CategoryPillButton(
                        category: category,
                        isSelected: selectedCategory == category
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedCategory = category
                            if let firstPreset = FilmPresets.presets(for: category).first {
                                selectedPreset = firstPreset
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Preset Scroll

    private var presetScrollView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(FilmPresets.presets(for: selectedCategory), id: \.id) { preset in
                    PresetThumbnailButton(
                        preset: preset,
                        isSelected: selectedPreset.id == preset.id
                    ) {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedPreset = preset
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Processing Overlay

    private var processingOverlay: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)

                Text("Loading Photo...")
                    .font(.headline)
                    .foregroundColor(.white)
            }
        }
    }

    // MARK: - Image Loading

    private func loadImage(from item: PhotosPickerItem?) {
        guard let item = item else { return }

        currentFilterTask?.cancel()
        currentFilterTask = nil

        isProcessing = true
        filteredImage = nil

        Task {
            do {
                guard let pickedImage = try await item.loadTransferable(type: PickedImage.self) else {
                    await MainActor.run {
                        isProcessing = false
                        errorMessage = "Could not load the selected image."
                        showErrorAlert = true
                    }
                    return
                }

                let uiImage = pickedImage.image
                let maxPreviewDimension: CGFloat = 1200
                let maxFullResDimension: CGFloat = 3000

                let preview = uiImage.resizedIfNeeded(maxDimension: maxPreviewDimension)
                let fullRes = uiImage.resizedIfNeeded(maxDimension: maxFullResDimension)

                await MainActor.run {
                    self.previewImage = preview
                    self.fullResImage = fullRes
                    self.originalImage = preview
                    self.isProcessing = false
                    applyFilterDebounced(preset: selectedPreset)
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    errorMessage = "Error loading image: \(error.localizedDescription)"
                    showErrorAlert = true
                }
            }
        }
    }

    // MARK: - Filter Application

    private func applyFilterDebounced(preset: FilterPreset) {
        currentFilterTask?.cancel()

        guard let original = previewImage ?? originalImage else { return }

        processingPresetId = preset.id

        currentFilterTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 100_000_000)

            guard !Task.isCancelled, preset.id == selectedPreset.id else { return }

            let filtered: UIImage? = await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    guard !Task.isCancelled else {
                        continuation.resume(returning: nil)
                        return
                    }

                    if RenderEngine.isAvailable {
                        let result = RenderEngine.shared.applyFilterPreview(to: original, preset: preset)
                        continuation.resume(returning: result)
                    } else {
                        continuation.resume(returning: nil)
                    }
                }
            }

            guard !Task.isCancelled, preset.id == selectedPreset.id else { return }

            if let filtered = filtered {
                self.filteredImage = filtered
            } else {
                self.filteredImage = original
            }

            if processingPresetId == preset.id {
                processingPresetId = nil
            }
        }
    }

    // MARK: - Save Photo

    private func savePhoto() {
        guard let fullRes = fullResImage ?? originalImage else { return }

        isProcessing = true

        Task {
            let imageToSave: UIImage = await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    guard RenderEngine.isAvailable else {
                        continuation.resume(returning: fullRes)
                        return
                    }
                    if let filtered = RenderEngine.shared.applyFilter(to: fullRes, preset: selectedPreset) {
                        continuation.resume(returning: filtered)
                    } else {
                        continuation.resume(returning: fullRes)
                    }
                }
            }

            await saveToPhotoLibrary(imageToSave)
        }
    }

    private func saveToPhotoLibrary(_ image: UIImage) async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)

        guard status == .authorized || status == .limited else {
            await MainActor.run {
                isProcessing = false
                errorMessage = "Photo library access denied. Please enable in Settings."
                showErrorAlert = true
            }
            return
        }

        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }

            await MainActor.run {
                isProcessing = false
                showSavedAlert = true
                let feedback = UINotificationFeedbackGenerator()
                feedback.notificationOccurred(.success)
            }
        } catch {
            await MainActor.run {
                isProcessing = false
                errorMessage = error.localizedDescription
                showErrorAlert = true
            }
        }
    }
}

// MARK: - Compare Slider View

struct CompareSliderView: View {
    let beforeImage: UIImage
    let afterImage: UIImage
    @Binding var position: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // After image (full)
                Image(uiImage: afterImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                
                // Before image (clipped)
                Image(uiImage: beforeImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipShape(
                        HorizontalClipShape(position: position)
                    )
                
                // Divider line
                Rectangle()
                    .fill(.white)
                    .frame(width: 2)
                    .position(x: geometry.size.width * position, y: geometry.size.height / 2)
                    .shadow(color: .black.opacity(0.5), radius: 2)
                
                // Handle
                Circle()
                    .fill(.white)
                    .frame(width: 36, height: 36)
                    .overlay(
                        HStack(spacing: 2) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 10, weight: .bold))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundColor(.black)
                    )
                    .shadow(color: .black.opacity(0.3), radius: 4)
                    .position(x: geometry.size.width * position, y: geometry.size.height / 2)
                
                // Labels
                VStack {
                    HStack {
                        Text("BEFORE")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.black.opacity(0.6))
                            .cornerRadius(4)
                            .opacity(position > 0.15 ? 1 : 0)
                        
                        Spacer()
                        
                        Text("AFTER")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.black.opacity(0.6))
                            .cornerRadius(4)
                            .opacity(position < 0.85 ? 1 : 0)
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 12)
                    
                    Spacer()
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let newPosition = value.location.x / geometry.size.width
                        position = max(0.05, min(0.95, newPosition))
                    }
            )
        }
    }
}

// MARK: - Horizontal Clip Shape

struct HorizontalClipShape: Shape {
    var position: CGFloat
    
    var animatableData: CGFloat {
        get { position }
        set { position = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(CGRect(x: 0, y: 0, width: rect.width * position, height: rect.height))
        return path
    }
}

// MARK: - UIImage Extension

extension UIImage {
    func resizedIfNeeded(maxDimension: CGFloat) -> UIImage {
        let currentMax = max(size.width, size.height)
        
        guard currentMax > maxDimension else { return self }
        
        let scale = maxDimension / currentMax
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

// MARK: - Preview

#Preview {
    PhotoEditorView()
}
