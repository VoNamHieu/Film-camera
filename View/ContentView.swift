// ContentView.swift
// Film Camera - Production Ready
// ★★★ UPDATED: Added Gallery integration ★★★

import SwiftUI
import AVFoundation
import Photos
import PhotosUI

struct ContentView: View {
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var effectManager = EffectStateManager()
    @ObservedObject private var galleryManager = GalleryManager.shared
    @State private var selectedPreset: FilterPreset = FilmPresets.kodakPortra400
    @State private var selectedCategory: FilterCategory = .professional
    @State private var showPresetPicker = false
    @State private var showSavedAlert = false
    @State private var isCapturing = false

    // Gallery states
    @State private var showGallery = false
    @State private var showPhotoEditor = false
    @State private var lastCapturedImage: UIImage?
    @State private var showLastPhoto = false

    // Video recording states
    @State private var isVideoMode = false
    @State private var showVideoSavedAlert = false

    // Effect controls state
    @State private var showEffectControls = false

    // Computed effective preset for preview (applies effect overrides)
    private var effectivePreset: FilterPreset {
        effectManager.applyToPreset() ?? selectedPreset
    }

    // Custom binding that uses effective preset for preview
    private var previewPresetBinding: Binding<FilterPreset> {
        Binding(
            get: { effectivePreset },
            set: { selectedPreset = $0 }
        )
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            switch cameraManager.permissionStatus {
            case .notDetermined:
                PermissionRequestView(onRequest: {
                    cameraManager.requestPermission()
                })
                
            case .denied, .restricted:
                PermissionDeniedView()
                
            case .authorized:
                cameraContentView
                
            @unknown default:
                PermissionRequestView(onRequest: {
                    cameraManager.requestPermission()
                })
            }
        }
        .onAppear {
            cameraManager.checkPermissionStatus()
            // Load last photo thumbnail from gallery
            if let lastPhoto = galleryManager.mostRecentPhoto {
                Task {
                    lastCapturedImage = await galleryManager.loadThumbnailAsync(id: lastPhoto.id)
                }
            }
        }
        .alert("Photo Saved", isPresented: $showSavedAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your photo has been saved to Gallery.")
        }
        .alert("Video Saved", isPresented: $showVideoSavedAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your video has been saved to Photos.")
        }
        // Gallery View
        .fullScreenCover(isPresented: $showGallery) {
            GalleryView()
        }
        // Photo Editor (import from Photo Library)
        .fullScreenCover(isPresented: $showPhotoEditor) {
            PhotoEditorView()
        }
        // Last Photo Preview Sheet
        .sheet(isPresented: $showLastPhoto) {
            if let image = lastCapturedImage {
                LastPhotoPreviewView(image: image, onDismiss: { showLastPhoto = false })
            }
        }
    }
    
    // MARK: - Camera Content View

    private var cameraContentView: some View {
        ZStack {
            // ★★★ FIX: Check if RenderEngine is fully available (Metal + shaders) ★★★
            if RenderEngine.isAvailable {
                // Use effective preset (with effect overrides) for real-time preview
                MetalPreviewView(cameraManager: cameraManager, selectedPreset: previewPresetBinding)
                    .ignoresSafeArea()
            } else {
                // Fallback when Metal or shaders unavailable
                CameraPreviewView(cameraManager: cameraManager)
                    .ignoresSafeArea()
            }

            // Loading overlay when session not ready
            if !cameraManager.isSessionRunning {
                Color.black
                    .ignoresSafeArea()
                    .overlay(
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                    )
            }
            
            // ★★★ NEW: Session Interruption overlay ★★★
            if cameraManager.isInterrupted {
                sessionInterruptedOverlay
            }
            
            // UI Overlay
            VStack(spacing: 0) {
                topBar
                    .padding(.top, 10)
                
                Spacer()
                
                // Current Filter Name
                filterNameBadge
                    .padding(.bottom, 12)
                
                // Bottom Controls
                bottomControls
            }
            
            // Capture flash effect
            if isCapturing {
                Color.white
                    .ignoresSafeArea()
                    .transition(.opacity)
            }

            // Effect Controls Panel (slides from bottom)
            if showEffectControls {
                VStack(spacing: 0) {
                    Spacer()

                    // Compact effect bar
                    CompactEffectBar(effectManager: effectManager)

                    // Full effect controls
                    EffectControlsView(effectManager: effectManager)
                        .frame(height: 350)
                        .transition(.move(edge: .bottom))
                }
                .background(Color.black.opacity(0.001)) // Tap to dismiss
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showEffectControls = false
                    }
                }
            }
        }
        .onChange(of: selectedPreset) { _, newPreset in
            effectManager.loadPreset(newPreset)
        }
        .onAppear {
            effectManager.loadPreset(selectedPreset)
        }
        .sheet(isPresented: $showPresetPicker) {
            PresetPickerView(
                selectedPreset: $selectedPreset,
                selectedCategory: $selectedCategory,
                onDismiss: { showPresetPicker = false }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }
    
    // ★★★ NEW: Session Interrupted Overlay ★★★
    private var sessionInterruptedOverlay: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.white.opacity(0.6))
                
                Text("Camera Interrupted")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                if let error = cameraManager.error {
                    Text(error.localizedDescription)
                        .font(.body)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            }
        }
    }
    
    // MARK: - Top Bar
    
    private var topBar: some View {
        HStack {
            // Flash Toggle
            Button(action: { cameraManager.toggleFlash() }) {
                Image(systemName: flashIconName)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(.black.opacity(0.4))
                    .clipShape(Circle())
            }
            
            Spacer()
            
            // Camera position indicator
            if cameraManager.currentPosition == .front {
                Text("Front")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.4))
                    .cornerRadius(12)
            }
            
            Spacer()

            // Effect controls button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.25)) {
                    showEffectControls.toggle()
                }
            }) {
                ZStack {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(showEffectControls ? .yellow : .white)
                        .frame(width: 44, height: 44)
                        .background(showEffectControls ? .yellow.opacity(0.3) : .black.opacity(0.4))
                        .clipShape(Circle())

                    // Performance indicator dot
                    Circle()
                        .fill(effectManager.performanceLevel.color)
                        .frame(width: 8, height: 8)
                        .offset(x: 14, y: -14)
                }
            }

            // More options
            Button(action: { showPresetPicker = true }) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(.black.opacity(0.4))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 16)
    }
    
    private var flashIconName: String {
        switch cameraManager.flashMode {
        case .off: return "bolt.slash"
        case .on: return "bolt.fill"
        case .auto: return "bolt.badge.automatic"
        @unknown default: return "bolt.slash"
        }
    }
    
    // MARK: - Filter Name Badge
    
    private var filterNameBadge: some View {
        Text(selectedPreset.label)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(.black.opacity(0.6))
            .cornerRadius(20)
    }
    
    // MARK: - Bottom Controls

    private var bottomControls: some View {
        VStack(spacing: 16) {
            // Recording indicator
            if cameraManager.isRecording {
                recordingIndicator
            }

            // Category Scroll
            categoryScrollView

            // Preset Scroll
            presetScrollView

            // Photo/Video mode toggle
            modeToggle

            // Capture Controls
            captureControlsBar
                .padding(.bottom, 20)
        }
        .padding(.top, 8)
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

    // MARK: - Recording Indicator

    private var recordingIndicator: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.red)
                .frame(width: 10, height: 10)
                .opacity(cameraManager.isRecording ? 1 : 0)
                .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: cameraManager.isRecording)

            Text(formatDuration(cameraManager.recordingDuration))
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.red.opacity(0.3))
        .cornerRadius(20)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - Mode Toggle

    private var modeToggle: some View {
        HStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isVideoMode = false
                }
            } label: {
                Text("Photo")
                    .font(.system(size: 14, weight: isVideoMode ? .regular : .semibold))
                    .foregroundColor(isVideoMode ? .gray : .white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(isVideoMode ? Color.clear : Color.white.opacity(0.2))
                    .cornerRadius(16)
            }

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isVideoMode = true
                }
            } label: {
                Text("Video")
                    .font(.system(size: 14, weight: isVideoMode ? .semibold : .regular))
                    .foregroundColor(isVideoMode ? .white : .gray)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(isVideoMode ? Color.white.opacity(0.2) : Color.clear)
                    .cornerRadius(16)
            }
        }
        .background(Color.black.opacity(0.3))
        .cornerRadius(20)
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
                            // Auto-select first preset in category
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
    
    // MARK: - Capture Controls
    
    private var captureControlsBar: some View {
        HStack(spacing: 50) {
            // Gallery button - opens local gallery
            Button(action: { showGallery = true }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.white.opacity(0.15))
                        .frame(width: 48, height: 48)

                    // Show last captured photo thumbnail if available
                    if let lastImage = lastCapturedImage {
                        Image(uiImage: lastImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 48, height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                    }

                    // Photo count badge
                    if galleryManager.count > 0 {
                        Text("\(galleryManager.count)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.blue)
                            .clipShape(Capsule())
                            .offset(x: 18, y: -18)
                    }
                }
            }
            
            // Capture/Record Button
            Button(action: {
                if isVideoMode {
                    toggleVideoRecording()
                } else {
                    capturePhoto()
                }
            }) {
                ZStack {
                    Circle()
                        .stroke(isVideoMode ? .red : .white, lineWidth: 4)
                        .frame(width: 72, height: 72)

                    if isVideoMode {
                        // Video mode: red circle or square when recording
                        RoundedRectangle(cornerRadius: cameraManager.isRecording ? 8 : 30)
                            .fill(.red)
                            .frame(
                                width: cameraManager.isRecording ? 28 : 60,
                                height: cameraManager.isRecording ? 28 : 60
                            )
                            .animation(.easeInOut(duration: 0.2), value: cameraManager.isRecording)
                    } else {
                        // Photo mode: white circle
                        Circle()
                            .fill(.white)
                            .frame(width: 60, height: 60)
                            .scaleEffect(isCapturing ? 0.9 : 1.0)
                    }
                }
            }
            .disabled(isCapturing || !cameraManager.isSessionRunning || cameraManager.isInterrupted)
            
            // Flip Camera
            Button(action: { cameraManager.switchCamera() }) {
                Circle()
                    .fill(.white.opacity(0.15))
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: "camera.rotate.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                    )
            }
        }
    }
    
    // MARK: - Actions

    private func capturePhoto() {
        guard !isCapturing else { return }

        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()

        withAnimation(.easeInOut(duration: 0.1)) {
            isCapturing = true
        }

        // Use modified preset with effect overrides applied
        let effectivePreset = effectManager.applyToPreset() ?? selectedPreset

        // Capture with both original and filtered images
        cameraManager.capturePhotoWithOriginal(preset: effectivePreset) { original, filtered in
            withAnimation(.easeInOut(duration: 0.1)) {
                isCapturing = false
            }

            guard let originalImage = original, let filteredImage = filtered else {
                return
            }

            // Update thumbnail preview
            lastCapturedImage = filteredImage

            // Save to gallery
            Task {
                if let _ = await galleryManager.save(
                    originalImage: originalImage,
                    filteredImage: filteredImage,
                    preset: selectedPreset
                ) {
                    await MainActor.run {
                        showSavedAlert = true
                        let notificationFeedback = UINotificationFeedbackGenerator()
                        notificationFeedback.notificationOccurred(.success)
                    }
                }
            }
        }
    }

    private func toggleVideoRecording() {
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()

        if cameraManager.isRecording {
            // Stop recording
            cameraManager.stopVideoRecording()
            showVideoSavedAlert = true
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.notificationOccurred(.success)
        } else {
            // Use modified preset with effect overrides applied
            let effectivePreset = effectManager.applyToPreset() ?? selectedPreset
            // Start recording
            cameraManager.startVideoRecording(preset: effectivePreset)
        }
    }
}

// MARK: - Last Photo Preview View

struct LastPhotoPreviewView: View {
    let image: UIImage
    var onDismiss: () -> Void
    
    @State private var showShareSheet = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
            .navigationTitle("Last Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { onDismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showShareSheet = true }) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [image])
        }
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

// MARK: - Permission Request View

struct PermissionRequestView: View {
    var onRequest: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "camera.fill")
                .font(.system(size: 64))
                .foregroundColor(.white.opacity(0.8))
            
            VStack(spacing: 12) {
                Text("Camera Access Required")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text("Film Camera needs access to your camera to take photos with beautiful film emulation filters.")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Button(action: onRequest) {
                Text("Enable Camera")
                    .font(.headline)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(.white)
                    .cornerRadius(27)
            }
            .padding(.horizontal, 40)
            .padding(.top, 16)
            
            Spacer()
            Spacer()
        }
    }
}

// MARK: - Permission Denied View

struct PermissionDeniedView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "camera.fill")
                .font(.system(size: 64))
                .foregroundColor(.white.opacity(0.5))
            
            VStack(spacing: 12) {
                Text("Camera Access Denied")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text("Please enable camera access in Settings to use Film Camera.")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Button(action: openSettings) {
                Text("Open Settings")
                    .font(.headline)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(.white)
                    .cornerRadius(27)
            }
            .padding(.horizontal, 40)
            .padding(.top, 16)
            
            Spacer()
            Spacer()
        }
    }
    
    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Category Pill Button

struct CategoryPillButton: View {
    let category: FilterCategory
    let isSelected: Bool
    let onTap: () -> Void
    
    private var categoryName: String {
        switch category {
        case .professional: return "Pro"
        case .consumer: return "Consumer"
        case .slide: return "Slide"
        case .cinema: return "Cinema"
        case .blackAndWhite: return "B&W"
        case .instant: return "Instant"
        case .disposable: return "Disposable"
        case .food: return "Food"
        case .night: return "Night"
        case .creative: return "Creative"
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            Text(categoryName)
                .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                .foregroundColor(isSelected ? .black : .white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? .white : .white.opacity(0.2))
                .cornerRadius(18)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preset Thumbnail Button

struct PresetThumbnailButton: View {
    let preset: FilterPreset
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                // Thumbnail
                RoundedRectangle(cornerRadius: 8)
                    .fill(thumbnailGradient)
                    .frame(width: 56, height: 56)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? .white : .clear, lineWidth: 2.5)
                    )
                    .shadow(color: .black.opacity(0.3), radius: isSelected ? 4 : 2, y: 2)
                
                // Name
                Text(shortName)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .frame(width: 56)
            }
        }
        .buttonStyle(.plain)
    }
    
    private var shortName: String {
        if !preset.filmStock.name.isEmpty {
            return preset.filmStock.name
        }
        return String(preset.label.prefix(10))
    }
    
    private var thumbnailGradient: LinearGradient {
        let colors: [Color] = {
            switch preset.category {
            case .professional: return [.orange, .orange.opacity(0.7)]
            case .consumer: return [.yellow, .orange.opacity(0.8)]
            case .slide: return [.green, .teal]
            case .cinema: return [.blue, .indigo]
            case .blackAndWhite: return [.gray, .black]
            case .instant: return [.white, .gray.opacity(0.3)]
            case .disposable: return [.mint, .green.opacity(0.6)]
            case .food: return [.brown, .orange.opacity(0.7)]
            case .night: return [.purple, .blue]
            case .creative: return [.pink, .purple]
            }
        }()
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - Preset Picker View

struct PresetPickerView: View {
    @Binding var selectedPreset: FilterPreset
    @Binding var selectedCategory: FilterCategory
    var onDismiss: () -> Void
    
    var body: some View {
        NavigationView {
            List {
                ForEach(FilterCategory.allCases, id: \.self) { category in
                    Section(header: Text(PresetManager.shared.getCategoryName(category))) {
                        ForEach(FilmPresets.presets(for: category), id: \.id) { preset in
                            PresetRowButton(
                                preset: preset,
                                isSelected: selectedPreset.id == preset.id
                            ) {
                                selectedPreset = preset
                                selectedCategory = category
                                onDismiss()
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Film Presets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { onDismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Preset Row Button

struct PresetRowButton: View {
    let preset: FilterPreset
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Color indicator
                RoundedRectangle(cornerRadius: 6)
                    .fill(categoryColor)
                    .frame(width: 40, height: 40)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(preset.label)
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    if !preset.filmStock.characteristics.isEmpty {
                        Text(preset.filmStock.characteristics.prefix(2).joined(separator: " · "))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title3)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private var categoryColor: Color {
        switch preset.category {
        case .professional: return .orange
        case .consumer: return .yellow
        case .slide: return .green
        case .cinema: return .blue
        case .blackAndWhite: return .gray
        case .instant: return .white
        case .disposable: return .mint
        case .food: return .brown
        case .night: return .purple
        case .creative: return .pink
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
