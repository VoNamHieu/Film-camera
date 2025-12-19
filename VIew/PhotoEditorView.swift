// PhotoEditorView.swift
// Film Camera - Photo Editor with Filter Application
// Allows selecting photos from library and applying film presets

import SwiftUI
import PhotosUI
import Photos

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
    @GestureState private var isDragging = false
    
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
                    Button("Cancel") { dismiss() }
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
        .onChange(of: selectedPreset) { _, _ in
            applyFilter()
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
                        // Single image view (filtered or original)
                        Image(uiImage: filteredImage ?? original)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
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
                
                // Filter name
                Text(selectedPreset.label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Spacer()
                
                // Before/After toggle
                Button(action: { showBeforeAfter.toggle() }) {
                    HStack(spacing: 6) {
                        Image(systemName: showBeforeAfter ? "square.split.2x1.fill" : "square.split.2x1")
                        Text(showBeforeAfter ? "Compare" : "Compare")
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
                
                Text("Applying Filter...")
                    .font(.headline)
                    .foregroundColor(.white)
            }
        }
    }
    
    // MARK: - Actions
    
    private func loadImage(from item: PhotosPickerItem?) {
        guard let item = item else { return }
        
        isProcessing = true
        
        Task {
            do {
                if let data = try await item.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    await MainActor.run {
                        // Resize if too large (for performance)
                        let maxDimension: CGFloat = 3000
                        self.originalImage = uiImage.resizedIfNeeded(maxDimension: maxDimension)
                        self.filteredImage = nil
                        self.isProcessing = false
                        
                        // Apply current filter
                        applyFilter()
                    }
                } else {
                    await MainActor.run {
                        self.isProcessing = false
                        self.errorMessage = "Could not load the selected image."
                        self.showErrorAlert = true
                    }
                }
            } catch {
                await MainActor.run {
                    self.isProcessing = false
                    self.errorMessage = "Error loading image: \(error.localizedDescription)"
                    self.showErrorAlert = true
                }
            }
        }
    }
    
    private func applyFilter() {
        guard let original = originalImage else { return }
        
        isProcessing = true
        
        // Process on background queue
        DispatchQueue.global(qos: .userInitiated).async {
            let filtered = RenderEngine.shared.applyFilter(to: original, preset: selectedPreset)
            
            DispatchQueue.main.async {
                self.filteredImage = filtered ?? original
                self.isProcessing = false
            }
        }
    }
    
    private func savePhoto() {
        guard let imageToSave = filteredImage ?? originalImage else { return }
        
        isProcessing = true
        
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.errorMessage = "Photo library access denied. Please enable in Settings."
                    self.showErrorAlert = true
                }
                return
            }
            
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: imageToSave)
            }) { success, error in
                DispatchQueue.main.async {
                    self.isProcessing = false
                    
                    if success {
                        self.showSavedAlert = true
                        let feedback = UINotificationFeedbackGenerator()
                        feedback.notificationOccurred(.success)
                    } else {
                        self.errorMessage = error?.localizedDescription ?? "Could not save photo."
                        self.showErrorAlert = true
                    }
                }
            }
        }
    }
}

// MARK: - Compare Slider View

struct CompareSliderView: View {
    let beforeImage: UIImage
    let afterImage: UIImage
    @Binding var position: CGFloat
    
    @GestureState private var isDragging = false
    
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
