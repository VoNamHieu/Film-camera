//
//  EffectControlsView.swift
//  Film Camera
//
//  UI Controls for Effect System
//

import SwiftUI

// MARK: - Effect Controls View

struct EffectControlsView: View {
    @ObservedObject var effectManager: EffectStateManager
    @State private var selectedCategory: EffectCategory = .filmEffects
    @State private var expandedEffect: EffectType?

    enum EffectCategory: String, CaseIterable {
        case colorAdjustments = "Color"
        case filmEffects = "Film"
        case specialEffects = "Special"

        var effects: [EffectType] {
            switch self {
            case .colorAdjustments:
                return [.exposure, .contrast, .saturation, .vibrance, .temperature, .tint, .highlights, .shadows, .fade, .clarity]
            case .filmEffects:
                return [.grain, .bloom, .vignette, .halation]
            case .specialEffects:
                return [.instantFrame, .skinToneProtection, .lensDistortion, .toneMapping]
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Performance Indicator
            performanceIndicator

            // Category Selector
            categorySelector

            // Effect Controls
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(selectedCategory.effects, id: \.self) { effect in
                        EffectControlRow(
                            effect: effect,
                            value: effectManager.effectiveValue(for: effect),
                            isExpanded: expandedEffect == effect,
                            onToggle: { effectManager.toggleEffect(effect) },
                            onIntensityChange: { effectManager.setEffectIntensity(effect, intensity: $0) },
                            onTap: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    expandedEffect = expandedEffect == effect ? nil : effect
                                }
                            }
                        )
                    }
                }
                .padding()
            }
        }
        .background(Color.black.opacity(0.9))
    }

    // MARK: - Performance Indicator

    private var performanceIndicator: some View {
        HStack(spacing: 8) {
            Image(systemName: effectManager.performanceLevel.icon)
                .foregroundColor(effectManager.performanceLevel.color)

            Text(effectManager.performanceLevel.displayName)
                .font(.caption)
                .foregroundColor(effectManager.performanceLevel.color)

            Spacer()

            // Score bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.3))

                    Capsule()
                        .fill(effectManager.performanceLevel.color)
                        .frame(width: geo.size.width * CGFloat(min(effectManager.performanceScore, 1.0)))
                }
            }
            .frame(width: 60, height: 4)

            Text(String(format: "%.0f%%", effectManager.performanceScore * 100))
                .font(.caption2)
                .foregroundColor(.gray)
                .frame(width: 35, alignment: .trailing)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.black)
    }

    // MARK: - Category Selector

    private var categorySelector: some View {
        HStack(spacing: 0) {
            ForEach(EffectCategory.allCases, id: \.self) { category in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedCategory = category
                        expandedEffect = nil
                    }
                } label: {
                    Text(category.rawValue)
                        .font(.subheadline.weight(selectedCategory == category ? .semibold : .regular))
                        .foregroundColor(selectedCategory == category ? .white : .gray)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            selectedCategory == category ?
                            Color.white.opacity(0.15) : Color.clear
                        )
                }
            }
        }
        .background(Color.black.opacity(0.5))
    }
}

// MARK: - Effect Control Row

struct EffectControlRow: View {
    let effect: EffectType
    let value: EffectValue
    let isExpanded: Bool
    let onToggle: () -> Void
    let onIntensityChange: (Float) -> Void
    let onTap: () -> Void

    private var isEnabled: Bool { value.isEnabled }

    var body: some View {
        VStack(spacing: 0) {
            // Main row
            HStack(spacing: 12) {
                // Icon
                Image(systemName: effect.icon)
                    .font(.system(size: 18))
                    .foregroundColor(isEnabled ? .white : .gray)
                    .frame(width: 28)

                // Name
                Text(effect.displayName)
                    .font(.subheadline)
                    .foregroundColor(isEnabled ? .white : .gray)

                Spacer()

                // Performance indicator
                Circle()
                    .fill(performanceColor)
                    .frame(width: 6, height: 6)

                // Value display
                valueDisplay

                // Toggle/Expand
                if effect.hasIntensity {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)

            // Expanded controls
            if isExpanded && effect.hasIntensity {
                expandedControls
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isEnabled ? Color.white.opacity(0.08) : Color.white.opacity(0.03))
        )
    }

    // MARK: - Value Display

    @ViewBuilder
    private var valueDisplay: some View {
        switch value {
        case .toggle(let enabled):
            Toggle("", isOn: Binding(
                get: { enabled },
                set: { _ in onToggle() }
            ))
            .labelsHidden()
            .tint(.blue)

        case .slider(let val, _, _):
            Text(String(format: "%.0f", val * 100))
                .font(.caption)
                .foregroundColor(.gray)
                .frame(width: 35, alignment: .trailing)

        case .compound(let values):
            let intensity = values["intensity"] ?? 0
            Text(String(format: "%.0f%%", intensity * 100))
                .font(.caption)
                .foregroundColor(.gray)
                .frame(width: 45, alignment: .trailing)
        }
    }

    // MARK: - Expanded Controls

    @ViewBuilder
    private var expandedControls: some View {
        VStack(spacing: 12) {
            Divider()
                .background(Color.gray.opacity(0.3))

            // Enable toggle
            HStack {
                Text("Enabled")
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { isEnabled },
                    set: { _ in onToggle() }
                ))
                .labelsHidden()
                .tint(.blue)
            }

            // Intensity slider
            if case .compound(let values) = value {
                let intensity = values["intensity"] ?? 0

                HStack {
                    Text("Intensity")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Slider(
                        value: Binding(
                            get: { intensity },
                            set: { onIntensityChange($0) }
                        ),
                        in: 0...1
                    )
                    .tint(.blue)
                    Text(String(format: "%.0f%%", intensity * 100))
                        .font(.caption)
                        .foregroundColor(.gray)
                        .frame(width: 40, alignment: .trailing)
                }
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Performance Color

    private var performanceColor: Color {
        switch effect.performance {
        case .low: return .green
        case .medium: return .yellow
        case .high: return .orange
        }
    }
}

// MARK: - Compact Effect Bar

/// Compact horizontal effect bar for quick access
struct CompactEffectBar: View {
    @ObservedObject var effectManager: EffectStateManager
    let effects: [EffectType] = [.grain, .bloom, .vignette, .halation]

    var body: some View {
        HStack(spacing: 16) {
            ForEach(effects, id: \.self) { effect in
                CompactEffectButton(
                    effect: effect,
                    isEnabled: effectManager.isEffectEnabled(effect),
                    intensity: effectManager.effectIntensity(for: effect)
                ) {
                    effectManager.toggleEffect(effect)
                }
            }

            Spacer()

            // Performance badge
            HStack(spacing: 4) {
                Image(systemName: effectManager.performanceLevel.icon)
                    .font(.caption2)
                Text(effectManager.performanceLevel.displayName)
                    .font(.caption2)
            }
            .foregroundColor(effectManager.performanceLevel.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(effectManager.performanceLevel.color.opacity(0.2))
            )
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.8))
    }
}

// MARK: - Compact Effect Button

struct CompactEffectButton: View {
    let effect: EffectType
    let isEnabled: Bool
    let intensity: Float
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .stroke(isEnabled ? Color.white : Color.gray.opacity(0.5), lineWidth: 2)
                        .frame(width: 36, height: 36)

                    // Intensity ring
                    if isEnabled && intensity > 0 {
                        Circle()
                            .trim(from: 0, to: CGFloat(intensity))
                            .stroke(Color.blue, lineWidth: 2)
                            .frame(width: 36, height: 36)
                            .rotationEffect(.degrees(-90))
                    }

                    Image(systemName: effect.icon)
                        .font(.system(size: 14))
                        .foregroundColor(isEnabled ? .white : .gray)
                }

                Text(shortName)
                    .font(.system(size: 9))
                    .foregroundColor(isEnabled ? .white : .gray)
            }
        }
        .buttonStyle(.plain)
    }

    private var shortName: String {
        switch effect {
        case .grain: return "Grain"
        case .bloom: return "Bloom"
        case .vignette: return "Vig"
        case .halation: return "Halo"
        default: return effect.displayName
        }
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @StateObject private var effectManager = EffectStateManager()

        var body: some View {
            VStack(spacing: 0) {
                CompactEffectBar(effectManager: effectManager)

                Spacer()

                EffectControlsView(effectManager: effectManager)
                    .frame(height: 400)
            }
            .background(Color.black)
            .onAppear {
                // Load a sample preset for preview
                effectManager.loadPreset(FilmPresets.kodakPortra400)
            }
        }
    }

    return PreviewWrapper()
}
