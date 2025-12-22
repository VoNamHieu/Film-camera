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
    @State private var selectedPreset: FilterPreset = FilmPresets.kodakPortra400
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
    
    // ★★★ NEW: Debug state ★★★
    @State private var lastFilterResult: String = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Image Display Area
                    imageDisplayArea
                    
                    // Controls
                    if originalImage != nil {
                        controlsArea
                    }
                }
                
                // Processing overlay
                if isProcessing {
                    processingOverlay
                }
            }
            .navigationTitle("Photo Editor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        currentFilterTask?.cancel()
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if filteredImage != nil {
                        Button("Save") { savePhoto() }
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                }
            }
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .onChange(of: selectedItem) { _, newItem in
            loadImage(from: newItem)
        }
        .onChange(of: selectedPreset) { oldPreset, newPreset in
            print("🔄 PhotoEditor: Preset changed from '\(oldPreset.label)' to '\(newPreset.label)'")
            applyFilterDebounced(preset: newPreset)
        }
        .alert("Photo Saved", isPresented: $showSavedAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your edited photo has been saved to the camera roll.")
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .onDisappear {
            currentFilterTask?.cancel()
        }
    }
    
    // MARK: - Image Display Area
    
    private var imageDisplayArea: some View {
        GeometryReader { geometry in
            ZStack {
                if let original = originalImage {
                    if showBeforeAfter, let filtered = filteredImage {
                        // Before/After comparison view
                        CompareSliderView(
                            beforeImage: original,
                            afterImage: filtered,
                            position: $comparePosition
                        )
                    } else {
                        // ★★★ FIX: Show filtered image if available, otherwise original ★★★
                        let imageToShow = filteredImage ?? original
                        Image(uiImage: imageToShow)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    
                    // ★★★ DEBUG: Show filter status overlay ★★★
                    #if DEBUG
                    VStack {
                        Spacer()
                        HStack {
                            Text(lastFilterResult)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.green)
                                .padding(4)
                                .background(.black.opacity(0.6))
                                .cornerRadius(4)
                            Spacer()
                        }
                        .padding(8)
                    }
                    #endif
                } else {
                    // Photo picker prompt
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
            // Compare toggle & Change photo
            HStack {
                // Change photo button
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
                
                // Filter name with processing indicator
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
                
                // Before/After toggle
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
            
            // Category scroll
            categoryScrollView
            
            // Preset scroll
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

    /// ★★★ FIXED: Use custom Transferable type for reliable loading on real devices ★★★
    private func loadImage(from item: PhotosPickerItem?) {
        guard let item = item else { return }

        print("📷 PhotoEditor: Loading new image...")

        // Cancel any pending filter task
        currentFilterTask?.cancel()
        currentFilterTask = nil

        isProcessing = true
        filteredImage = nil
        lastFilterResult = "Loading..."

        Task {
            do {
                // ★★★ FIX: Use PickedImage (custom Transferable) instead of Data.self ★★★
                // This is more reliable on real devices
                guard let pickedImage = try await item.loadTransferable(type: PickedImage.self) else {
                    await handleLoadError(message: "Could not load the selected image. Please try another photo.")
                    return
                }

                let uiImage = pickedImage.image
                print("✅ PhotoEditor: Image loaded: \(Int(uiImage.size.width))x\(Int(uiImage.size.height))")

                // Create both preview and full-res versions
                let maxPreviewDimension: CGFloat = 1200
                let maxFullResDimension: CGFloat = 3000

                let preview = uiImage.resizedIfNeeded(maxDimension: maxPreviewDimension)
                let fullRes = uiImage.resizedIfNeeded(maxDimension: maxFullResDimension)

                print("   Preview: \(Int(preview.size.width))x\(Int(preview.size.height))")
                print("   FullRes: \(Int(fullRes.size.width))x\(Int(fullRes.size.height))")

                await MainActor.run {
                    self.previewImage = preview
                    self.fullResImage = fullRes
                    self.originalImage = preview
                    self.isProcessing = false
                    self.lastFilterResult = "Image loaded"

                    // Apply current filter
                    applyFilterDebounced(preset: selectedPreset)
                }
            } catch {
                await handleLoadError(message: "Error loading image: \(error.localizedDescription)")
            }
        }
    }

    /// Helper to handle loading errors on main thread
    private func handleLoadError(message: String) async {
        print("❌ PhotoEditor: \(message)")
        await MainActor.run {
            self.isProcessing = false
            self.errorMessage = message
            self.showErrorAlert = true
            self.lastFilterResult = "Load failed"
        }
    }
    
    // MARK: - ★★★ FIXED: Filter Application ★★★
    
    private func applyFilterDebounced(preset: FilterPreset) {
        // Cancel any existing filter task
        currentFilterTask?.cancel()
        
        guard let original = previewImage ?? originalImage else {
            print("⚠️ PhotoEditor: No image to filter")
            lastFilterResult = "No image"
            return
        }
        
        print("🎨 PhotoEditor: Queuing filter '\(preset.label)'")
        
        // Track which preset is being processed
        processingPresetId = preset.id
        lastFilterResult = "Processing \(preset.label)..."
        
        // Create new task with cancellation support
        currentFilterTask = Task { @MainActor in
            // Small delay to debounce rapid preset changes
            try? await Task.sleep(nanoseconds: 100_000_000)  // 100ms debounce
            
            // Check if cancelled
            guard !Task.isCancelled else {
                print("🚫 PhotoEditor: Filter task cancelled (debounce)")
                return
            }
            
            // Check if this is still the active preset
            guard preset.id == selectedPreset.id else {
                print("🚫 PhotoEditor: Preset changed, skipping \(preset.id)")
                return
            }
            
            print("🔄 PhotoEditor: Applying filter '\(preset.label)' to \(Int(original.size.width))x\(Int(original.size.height))")
            let startTime = CFAbsoluteTimeGetCurrent()

            // Process on background thread
            // ★ Use lightweight 2-pass preview for fast scrolling
            let filtered: UIImage? = await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    // Check cancellation before heavy work
                    guard !Task.isCancelled else {
                        print("🚫 PhotoEditor: Cancelled before processing")
                        continuation.resume(returning: nil)
                        return
                    }

                    // ★ Use fast preview pipeline (Color Grading + Vignette only)
                    let result = RenderEngine.shared.applyFilterPreview(to: original, preset: preset)
                    continuation.resume(returning: result)
                }
            }
            
            // Check if cancelled or preset changed
            guard !Task.isCancelled else {
                print("🚫 PhotoEditor: Filter task cancelled (after processing)")
                return
            }
            
            guard preset.id == selectedPreset.id else {
                print("🚫 PhotoEditor: Preset changed during processing, discarding result")
                return
            }
            
            let elapsed = CFAbsoluteTimeGetCurrent() - startTime
            
            // ★★★ FIX: Always update the UI state ★★★
            if let filtered = filtered {
                print("✅ PhotoEditor: Filter applied successfully in \(String(format: "%.2f", elapsed))s")
                print("   Result size: \(Int(filtered.size.width))x\(Int(filtered.size.height))")
                
                self.filteredImage = filtered
                self.lastFilterResult = "✓ \(preset.label) (\(String(format: "%.1f", elapsed))s)"
            } else {
                print("⚠️ PhotoEditor: Filter returned nil, showing original")
                // ★★★ FIX: Set filteredImage to original so user sees something ★★★
                self.filteredImage = original
                self.lastFilterResult = "⚠️ Filter failed, showing original"
            }
            
            // Clear processing indicator
            if processingPresetId == preset.id {
                processingPresetId = nil
            }
        }
    }
    
    // MARK: - Save with Full Resolution
    
    private func savePhoto() {
        guard let fullRes = fullResImage ?? originalImage else { return }
        
        print("💾 PhotoEditor: Saving photo...")
        isProcessing = true
        
        Task {
            // Apply filter to full resolution image
            let imageToSave: UIImage = await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    print("   Applying filter to full-res image...")
                    if let filtered = RenderEngine.shared.applyFilter(to: fullRes, preset: selectedPreset) {
                        print("   ✅ Full-res filter applied")
                        continuation.resume(returning: filtered)
                    } else {
                        print("   ⚠️ Full-res filter failed, using original")
                        continuation.resume(returning: fullRes)
                    }
                }
            }
            
            // Save to photo library
            await saveToPhotoLibrary(imageToSave)
        }
    }
    
    private func saveToPhotoLibrary(_ image: UIImage) async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        
        guard status == .authorized || status == .limited else {
            await MainActor.run {
                self.isProcessing = false
                self.errorMessage = "Photo library access denied. Please enable in Settings."
                self.showErrorAlert = true
            }
            return
        }
        
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
            
            await MainActor.run {
                self.isProcessing = false
                self.showSavedAlert = true
                let feedback = UINotificationFeedbackGenerator()
                feedback.notificationOccurred(.success)
            }
        } catch {
            await MainActor.run {
                self.isProcessing = false
                self.errorMessage = error.localizedDescription
                self.showErrorAlert = true
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
