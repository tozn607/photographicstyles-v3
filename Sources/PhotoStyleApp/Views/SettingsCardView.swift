import SwiftUI
import PhotoStyleCore

public struct SettingsCardView: View {
    @ObservedObject var state: AppState

    public init(state: AppState) {
        self.state = state
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "wand.and.stars")
                        .foregroundColor(.accentColor)
                    Text("Apple Photos features (Experimental)")
                        .font(.headline)
                }

                Text("These options write editable data; the look is not baked into the photo.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 2)

            Divider()

            // Feature 1: Apple Photos Photographic Styles (Rust)
            VStack(alignment: .leading, spacing: 4) {
                Toggle(isOn: Binding(
                    get: { state.applePhotographicStyles },
                    set: { newVal in
                        if !state.applePhotographicStyles3 {
                            state.applePhotographicStyles = newVal
                        }
                    }
                )) {
                    Text("Apple Photos Photographic Styles (Rust)")
                        .font(.system(size: 14, weight: .medium))
                }
                .disabled(state.applePhotographicStyles3)

                Text(state.applePhotographicStyles3
                    ? "Included in Photographic Styles 3; turn that off to change this."
                    : "Uses Rust to generate Photographic Styles data editable in Apple Photos; selects Apple Standard output and disables GPU encoding.")
                    .font(.caption)
                    .foregroundColor(state.applePhotographicStyles3 ? .secondary : .secondary.opacity(0.8))
                    .padding(.leading, 2)
            }

            // Feature 2: Photographic Styles 3 (texture + grain)
            VStack(alignment: .leading, spacing: 4) {
                Toggle(isOn: $state.applePhotographicStyles3) {
                    Text("Photographic Styles 3 (texture + grain)")
                        .font(.system(size: 14, weight: .medium))
                }

                Text("Output carries a Standard texture_styles item so Apple Photos offers texture/grain editing; selects Apple Standard output and disables GPU encoding.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 2)
            }

            // Feature 3: Apple Portrait Mode (Rust)
            VStack(alignment: .leading, spacing: 4) {
                Toggle(isOn: $state.applePortrait) {
                    Text("Apple Portrait Mode (Rust)")
                        .font(.system(size: 14, weight: .medium))
                }

                Text("Generates editable Apple Portrait depth & disparity data for Apple Photos.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 2)
            }

            Divider()

            // Advanced options disclosure
            DisclosureGroup("Advanced Options") {
                VStack(alignment: .leading, spacing: 10) {
                    // Custom Grain Seed
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Film Grain Seed:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Auto (derived from file path)", text: $state.customGrainSeedText)
                            .textFieldStyle(.roundedBorder)
                            .font(.caption)
                    }

                    // Auto-Save to Photos
                    Toggle("Automatically save output to Apple Photos Library", isOn: $state.autoSaveToPhotos)
                        .font(.caption)
                }
                .padding(.top, 6)
            }
            .font(.subheadline)
            .accentColor(.secondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColorOrUIColor(ns: .windowBackgroundColor, ui: .secondarySystemBackground)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }

    private func nsColorOrUIColor(ns: NSColorName, ui: UIColorName) -> Color {
        #if os(macOS)
        return Color(NSColor.windowBackgroundColor)
        #else
        return Color(UIColor.secondarySystemBackground)
        #endif
    }
}

private enum NSColorName { case windowBackgroundColor }
private enum UIColorName { case secondarySystemBackground }
