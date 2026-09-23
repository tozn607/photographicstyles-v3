import SwiftUI
import UniformTypeIdentifiers
#if canImport(PhotosUI)
import PhotosUI
#endif

public struct DropZoneView: View {
    @ObservedObject var state: AppState
    @State private var isTargeted = false
    @State private var isShowingFileImporter = false

    #if canImport(PhotosUI)
    @State private var selectedPhotos: [PhotosPickerItem] = []
    #endif

    public init(state: AppState) {
        self.state = state
    }

    public var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.badge.plus")
                .font(.system(size: 40))
                .foregroundColor(isTargeted ? .accentColor : .secondary)

            VStack(spacing: 4) {
                Text("Drop imported pictures here")
                    .font(.headline)
                Text("Supports JPEG, PNG, HEIC, TIFF, WebP, ProRAW, DNG")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 12) {
                Button(action: {
                    #if os(macOS)
                    openMacFilePicker()
                    #else
                    isShowingFileImporter = true
                    #endif
                }) {
                    Label("Browse Files...", systemImage: "folder")
                }
                .buttonStyle(.borderedProminent)

                #if canImport(PhotosUI)
                PhotosPicker(
                    selection: $selectedPhotos,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    Label("Photos Library...", systemImage: "photo.on.rectangle")
                }
                .buttonStyle(.bordered)
                .onChange(of: selectedPhotos) { _, newItems in
                    loadFromPhotosPicker(newItems)
                }
                #endif
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    isTargeted ? Color.accentColor : Color.secondary.opacity(0.3),
                    style: StrokeStyle(lineWidth: 2, dash: [8, 6])
                )
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isTargeted ? Color.accentColor.opacity(0.08) : Color.clear)
                )
        )
        .onDrop(of: [.fileURL, .image], isTargeted: $isTargeted) { providers in
            handleDrop(providers: providers)
            return true
        }
        .fileImporter(
            isPresented: $isShowingFileImporter,
            allowedContentTypes: [.item, .image, .data],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                var stagedURLs: [URL] = []
                let fm = FileManager.default
                let stagingDir = fm.urls(for: .cachesDirectory, in: .userDomainMask).first?
                    .appendingPathComponent("Imported", isDirectory: true) ?? fm.temporaryDirectory
                try? fm.createDirectory(at: stagingDir, withIntermediateDirectories: true)

                for url in urls {
                    let isAccessing = url.startAccessingSecurityScopedResource()
                    defer {
                        if isAccessing {
                            url.stopAccessingSecurityScopedResource()
                        }
                    }

                    let destURL = stagingDir.appendingPathComponent(url.lastPathComponent)
                    if fm.fileExists(atPath: destURL.path) {
                        try? fm.removeItem(at: destURL)
                    }

                    do {
                        try fm.copyItem(at: url, to: destURL)
                        stagedURLs.append(destURL)
                    } catch {
                        if let data = try? Data(contentsOf: url) {
                            try? data.write(to: destURL)
                            stagedURLs.append(destURL)
                        } else {
                            stagedURLs.append(url)
                        }
                    }
                }
                state.addFiles(urls: stagedURLs)

            case .failure(let error):
                state.statusMessage = "Import failed: \(error.localizedDescription)"
            }
        }
    }

    private func handleDrop(providers: [NSItemProvider]) {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                    DispatchQueue.main.async {
                        state.addFiles(urls: [url])
                    }
                } else if let url = item as? URL {
                    DispatchQueue.main.async {
                        state.addFiles(urls: [url])
                    }
                }
            }
        }
    }

    #if os(macOS)
    private func openMacFilePicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image]
        if panel.runModal() == .OK {
            state.addFiles(urls: panel.urls)
        }
    }
    #endif

    #if canImport(PhotosUI)
    private func loadFromPhotosPicker(_ items: [PhotosPickerItem]) {
        Task {
            var loadedURLs: [URL] = []
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    let tempURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent(UUID().uuidString)
                        .appendingPathExtension("jpg")
                    try? data.write(to: tempURL)
                    loadedURLs.append(tempURL)
                }
            }
            if !loadedURLs.isEmpty {
                state.addFiles(urls: loadedURLs)
            }
        }
    }
    #endif
}
