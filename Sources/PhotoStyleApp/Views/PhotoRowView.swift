import SwiftUI
import PhotoStyleCore

public struct PhotoRowView: View {
    public let item: QueueItem
    @ObservedObject var state: AppState
    @State private var thumbnail: PlatformImage? = nil

    public init(item: QueueItem, state: AppState) {
        self.item = item
        self.state = state
    }

    public var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            Group {
                #if os(macOS)
                if let thumb = thumbnail {
                    Image(nsImage: thumb)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    placeholderThumbnail
                }
                #else
                if let thumb = thumbnail {
                    Image(uiImage: thumb)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    placeholderThumbnail
                }
                #endif
            }
            .frame(width: 54, height: 54)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )

            // Details
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(item.sourceURL.lastPathComponent)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer()

                    // Status icon or text
                    statusBadge
                }

                HStack(spacing: 8) {
                    if let res = item.result {
                        Text("\(ByteCountFormatter.string(fromByteCount: res.inputSizeBytes, countStyle: .file)) → \(ByteCountFormatter.string(fromByteCount: res.outputSizeBytes, countStyle: .file))")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        BadgesView(result: res)
                    } else {
                        let attrs = try? FileManager.default.attributesOfItem(atPath: item.sourceURL.path)
                        let size = (attrs?[.size] as? NSNumber)?.int64Value ?? 0
                        Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        BadgesView(options: state.effectiveOptions)
                    }
                }

                if let err = item.errorMessage {
                    Text(err)
                        .font(.caption2)
                        .foregroundColor(.red)
                        .lineLimit(1)
                }
            }

            // Quick actions
            HStack(spacing: 4) {
                if item.status == .completed {
                    Button(action: {
                        state.exportItemToPhotos(item)
                    }) {
                        Image(systemName: "square.and.arrow.down")
                    }
                    .buttonStyle(.borderless)
                    .help("Save to Photos Library")

                    #if os(macOS)
                    Button(action: {
                        state.revealInFinder(url: item.outputURL)
                    }) {
                        Image(systemName: "folder")
                    }
                    .buttonStyle(.borderless)
                    .help("Reveal in Finder")
                    #endif

                    Button(action: {
                        state.selectedItem = item
                        state.isShowingInspector = true
                    }) {
                        Image(systemName: "info.circle")
                    }
                    .buttonStyle(.borderless)
                    .help("Inspect Metadata")
                }

                Button(action: {
                    state.removeItem(item)
                }) {
                    Image(systemName: "xmark.circle")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)
                .disabled(state.isConverting && item.status == .processing)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.secondary.opacity(0.04))
        )
        .task {
            loadThumb()
        }
    }

    private var placeholderThumbnail: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.1))
            .overlay(
                Image(systemName: "photo")
                    .foregroundColor(.secondary)
            )
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch item.status {
        case .pending:
            Text("Ready")
                .font(.caption2)
                .foregroundColor(.secondary)
        case .processing:
            ProgressView()
                .scaleEffect(0.6)
                .frame(width: 14, height: 14)
        case .completed:
            HStack(spacing: 3) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Ready for Apple Photos")
                    .font(.caption2)
                    .foregroundColor(.green)
            }
        case .failed:
            HStack(spacing: 3) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                Text("Failed")
                    .font(.caption2)
                    .foregroundColor(.red)
            }
        case .cancelled:
            Text("Cancelled")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    private func loadThumb() {
        Task.detached(priority: .background) {
            let loaded = ImageLoader.loadThumbnail(from: item.sourceURL, maxDimension: 128)
            await MainActor.run {
                self.thumbnail = loaded
            }
        }
    }
}
