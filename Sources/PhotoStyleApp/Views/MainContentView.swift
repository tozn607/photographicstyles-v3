import SwiftUI
import PhotoStyleCore

public struct MainContentView: View {
    @StateObject private var state = AppState()

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Main Scrollable Area
                ScrollView {
                    VStack(spacing: 16) {
                        // Features & Settings Card
                        SettingsCardView(state: state)

                        // Dropzone & Importer
                        DropZoneView(state: state)

                        // Queue Section
                        if !state.items.isEmpty {
                            queueSection
                        }
                    }
                    .padding(18)
                }

                Divider()

                // Bottom Action Bar
                bottomBar
            }
            .navigationTitle("PhotoStyle")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .sheet(isPresented: $state.isShowingInspector) {
                if let selected = state.selectedItem {
                    PhotoInspectorSheet(item: selected, state: state)
                }
            }
            .alert(isPresented: $state.showAlert) {
                Alert(
                    title: Text("PhotoStyle"),
                    message: Text(state.alertMessage ?? ""),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }

    private var queueSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Queue (\(state.items.count))")
                    .font(.headline)

                Spacer()

                if state.items.contains(where: { $0.status == .completed }) {
                    Button("Clear Completed") {
                        state.clearCompleted()
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                    .disabled(state.isConverting)
                }

                Button("Clear All") {
                    state.clearAll()
                }
                .buttonStyle(.borderless)
                .font(.caption)
                .disabled(state.isConverting)
            }

            LazyVStack(spacing: 8) {
                ForEach(state.items) { item in
                    PhotoRowView(item: item, state: state)
                }
            }
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(state.statusMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    if state.isConverting {
                        ProgressView(value: state.progressOverall)
                            .frame(maxWidth: 220)
                    }
                }

                Spacer()

                if state.isConverting {
                    Button(action: {
                        Task {
                            await ConversionQueue.shared.cancelAll()
                            state.isConverting = false
                            state.statusMessage = "Cancelled conversion."
                        }
                    }) {
                        Text("Stop")
                    }
                    .buttonStyle(.bordered)
                } else {
                    let pendingCount = state.items.filter { $0.status == .pending || $0.status == .failed }.count
                    Button(action: {
                        state.startConversion()
                    }) {
                        Label(
                            pendingCount > 0 ? "Enable Styles (\(pendingCount))" : "Enable Styles",
                            systemImage: "wand.and.stars"
                        )
                        .padding(.horizontal, 4)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(pendingCount == 0)
                }
            }

            Divider()

            HStack {
                Text("PhotoStyle v1.0.2")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                Text("•")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.5))
                Text("Author: @tozn607")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Text("Apple Photos Photographic Styles & Portrait Mode")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.6))
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(
            Color(nsColorOrUIColor(ns: .windowBackgroundColor, ui: .secondarySystemBackground))
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
