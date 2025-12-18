// ContentView.swift
// Film Camera - Production Ready

import SwiftUI
import AVFoundation
import Photos

struct ContentView: View {
    @StateObject private var cameraManager = CameraManager()
    @State private var selectedPreset: FilterPreset = FilmPresets.kodakPortra400
    @State private var selectedCategory: FilterCategory = .professional
    @State private var showPresetPicker = false
    @State private var showSavedAlert = false
    @State private var isCapturing = false
    
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
        }
        .alert("Photo Saved", isPresented: $showSavedAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your photo has been saved to the camera roll.")
        }
    }
    
    // MARK: - Camera Content View
    
    private var cameraContentView: some View {
        ZStack {
            // Camera Preview with Real-time Filtering
            MetalPreviewView(cameraManager: cameraManager, selectedPreset: $selectedPreset)
                .ignoresSafeArea()
            
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
            // Category Scroll
            categoryScrollView
            
            // Preset Scroll
            presetScrollView
            
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
            // Gallery button (placeholder)
            Button(action: { openPhotoLibrary() }) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.white.opacity(0.15))
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                    )
            }
            
            // Capture Button
            Button(action: { capturePhoto() }) {
                ZStack {
                    Circle()
                        .stroke(.white, lineWidth: 4)
                        .frame(width: 72, height: 72)
                    
                    Circle()
                        .fill(.white)
                        .frame(width: 60, height: 60)
                        .scaleEffect(isCapturing ? 0.9 : 1.0)
                }
            }
            .disabled(isCapturing || !cameraManager.isSessionRunning)
            
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
        
        cameraManager.capturePhoto { image in
            withAnimation(.easeInOut(duration: 0.1)) {
                isCapturing = false
            }
            
            if let image = image {
                saveToPhotoLibrary(image)
            }
        }
    }
    
    private func saveToPhotoLibrary(_ image: UIImage) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else { return }
            
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }) { success, error in
                DispatchQueue.main.async {
                    if success {
                        showSavedAlert = true
                        let notificationFeedback = UINotificationFeedbackGenerator()
                        notificationFeedback.notificationOccurred(.success)
                    }
                }
            }
        }
    }
    
    private func openPhotoLibrary() {
        // Placeholder - implement photo library picker
    }
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
