import SwiftUI
import PhotoStyleCore

public struct PhotoInspectorSheet: View {
    public let item: QueueItem
    @ObservedObject var state: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var previewImage: PlatformImage? = nil

    public init(item: QueueItem, state: AppState) {
        self.item = item
        self.state = state
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Preview
                    if let img = previewImage {
                        #if os(macOS)
                        Image(nsImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 280)
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                            )
                        #else
                        Image(uiImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 280)
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                            )
                        #endif
                    }

                    // Feature Verification Card
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Apple Photos Verified Features")
                            .font(.headline)

                        if let res = item.result {
                            VStack(spacing: 8) {
                                featureRow(
                                    title: "Apple Photographic Styles",
                                    subtitle: "Delta map, 51,840-byte styleData lattice, linear thumbnail, Apple MakerNote",
                                    verified: res.hasStyles
                                )
                                Divider()
                                featureRow(
                                    title: "Photographic Styles 3 (Texture & Grain)",
                                    subtitle: "Standard texture_styles item + 12 semantic part-matte placeholders",
                                    verified: res.hasStyles3
                                )
                                Divider()
                                featureRow(
                                    title: "Apple Portrait Mode",
                                    subtitle: "Apple disparity/depth map & aperture rendering metadata",
                                    verified: res.hasPortrait
                                )
                                Divider()
                                featureRow(
                                    title: "ISO 21496-1 Gain Map",
                                    subtitle: "Standard HDR tone-mapping auxiliary item",
                                    verified: res.hasGainMap
                                )
                            }
                        } else {
                            Text("No conversion result available.")
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(14)
                    .background(Color.secondary.opacity(0.06))
                    .cornerRadius(10)

                    // File Information Card
                    VStack(alignment: .leading, spacing: 8) {
                        Text("File Information")
                            .font(.headline)

                        infoRow(label: "Source File", value: item.sourceURL.path)
                        infoRow(label: "Output File", value: item.outputURL.path)

                        if let res = item.result {
                            infoRow(
                                label: "Original Size",
                                value: ByteCountFormatter.string(fromByteCount: res.inputSizeBytes, countStyle: .file)
                            )
                            infoRow(
                                label: "Styled Size",
                                value: ByteCountFormatter.string(fromByteCount: res.outputSizeBytes, countStyle: .file)
                            )
                            if let mode = res.mode {
                                infoRow(label: "Container Mode", value: mode.uppercased())
                            }
                            if let fam = res.family {
                                infoRow(label: "Profile Family", value: fam.uppercased())
                            }
                        }
                    }
                    .padding(14)
                    .background(Color.secondary.opacity(0.06))
                    .cornerRadius(10)

                    // Diagnostic Summary Card
                    let inspectInfo = PhotoStyleBridge.inspect(path: item.outputURL.path)
                    if inspectInfo.success {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("ISOBMFF Inspection")
                                .font(.headline)

                            infoRow(label: "EDR Headroom", value: String(format: "%.2f stops", inspectInfo.edrScale))
                            infoRow(label: "Gain Map Max", value: String(format: "%.2f", inspectInfo.gainMapMax))
                        }
                        .padding(14)
                        .background(Color.secondary.opacity(0.06))
                        .cornerRadius(10)
                    }

                    // Bottom Action Buttons
                    HStack(spacing: 12) {
                        Button(action: {
                            state.exportItemToPhotos(item)
                        }) {
                            Label("Save to Photos Library", systemImage: "square.and.arrow.down")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)

                        #if os(macOS)
                        Button(action: {
                            state.revealInFinder(url: item.outputURL)
                        }) {
                            Label("Reveal in Finder", systemImage: "folder")
                        }
                        .buttonStyle(.bordered)
                        #endif
                    }
                    .padding(.top, 4)
                }
                .padding(20)
            }
            .navigationTitle("Photo Inspector")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            loadPreview()
        }
    }

    private func featureRow(title: String, subtitle: String, verified: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: verified ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundColor(verified ? .green : .secondary.opacity(0.5))
                .font(.system(size: 16))
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(verified ? .primary : .secondary)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(verified ? "Verified" : "Not Present")
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(verified ? Color.green.opacity(0.12) : Color.secondary.opacity(0.1))
                .foregroundColor(verified ? .green : .secondary)
                .cornerRadius(4)
        }
    }

    private func infoRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .lineLimit(2)
                .truncationMode(.middle)
        }
    }

    private func loadPreview() {
        Task.detached(priority: .userInitiated) {
            let thumb = ImageLoader.loadThumbnail(from: item.outputURL, maxDimension: 600)
            await MainActor.run {
                self.previewImage = thumb
            }
        }
    }
}
