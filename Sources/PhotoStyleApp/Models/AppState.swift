import Foundation
import SwiftUI
import PhotoStyleCore
import Photos

@MainActor
public final class AppState: ObservableObject {
    @Published public var items: [QueueItem] = []
    @Published public var selectedItem: QueueItem? = nil
    @Published public var isConverting: Bool = false
    @Published public var progressOverall: Double = 0.0

    // Feature Toggles matching xdremux
    // 1. Apple Photos Photographic Styles
    @Published public var applePhotographicStyles: Bool = true
    // 2. Photographic Styles 3 (texture + grain)
    @Published public var applePhotographicStyles3: Bool = true {
        didSet {
            if applePhotographicStyles3 {
                // Included in Photographic Styles 3; turn that off to change this.
                applePhotographicStyles = true
            }
        }
    }
    // 3. Apple Portrait Mode
    @Published public var applePortrait: Bool = false

    // Output settings
    @Published public var customGrainSeedText: String = ""
    @Published public var autoSaveToPhotos: Bool = false
    @Published public var customOutputFolder: URL? = nil

    // UI state
    @Published public var statusMessage: String = "Drag & drop photos or click Browse to get started."
    @Published public var isShowingInspector: Bool = false
    @Published public var alertMessage: String? = nil
    @Published public var showAlert: Bool = false

    public init() {}

    public var effectiveOptions: ConversionOptions {
        let seed = UInt64(customGrainSeedText.trimmingCharacters(in: .whitespaces))
        return ConversionOptions(
            applePhotographicStyles: applePhotographicStyles,
            applePhotographicStyles3: applePhotographicStyles3,
            applePortrait: applePortrait,
            customGrainSeed: seed
        )
    }

    public func addFiles(urls: [URL]) {
        let validExtensions: Set<String> = ["jpg", "jpeg", "heic", "heif", "png", "tiff", "tif", "dng", "raw", "webp"]
        var addedCount = 0

        for url in urls {
            // Check if folder
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                if let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: nil) {
                    for case let fileURL as URL in enumerator {
                        if validExtensions.contains(fileURL.pathExtension.lowercased()) {
                            appendItem(for: fileURL)
                            addedCount += 1
                        }
                    }
                }
            } else if validExtensions.contains(url.pathExtension.lowercased()) {
                appendItem(for: url)
                addedCount += 1
            }
        }

        if addedCount > 0 {
            statusMessage = "Added \(addedCount) photo\(addedCount == 1 ? "" : "s") to the queue."
        }
    }

    private func appendItem(for url: URL) {
        // Prevent duplicate pending items
        if items.contains(where: { $0.sourceURL.path == url.path && $0.status == .pending }) {
            return
        }

        let outDir = customOutputFolder ?? url.deletingLastPathComponent()
        let stem = url.deletingPathExtension().lastPathComponent
        let outURL = outDir.appendingPathComponent("\(stem)_photostyle.heic")
        let item = QueueItem(sourceURL: url, outputURL: outURL)
        items.append(item)
    }

    public func removeItem(_ item: QueueItem) {
        items.removeAll(where: { $0.id == item.id })
        if selectedItem?.id == item.id {
            selectedItem = nil
        }
    }

    public func clearAll() {
        guard !isConverting else { return }
        items.removeAll()
        selectedItem = nil
        statusMessage = "Queue cleared."
    }

    public func clearCompleted() {
        guard !isConverting else { return }
        items.removeAll(where: { $0.status == .completed })
    }

    public func startConversion() {
        guard !isConverting else { return }
        let pendingIndices = items.indices.filter { items[$0].status == .pending || items[$0].status == .failed }
        guard !pendingIndices.isEmpty else {
            statusMessage = "No photos waiting to convert."
            return
        }

        isConverting = true
        progressOverall = 0.0
        statusMessage = "Converting \(pendingIndices.count) photo(s)..."

        let options = effectiveOptions
        let autoSave = autoSaveToPhotos

        Task {
            var completedCount = 0
            let total = pendingIndices.count

            for index in pendingIndices {
                guard isConverting else { break }

                items[index].status = .processing
                items[index].progress = 0.2

                let item = items[index]
                let result = await ConversionQueue.shared.convertSingle(
                    item: item,
                    options: options
                ) { [weak self] p in
                    Task { @MainActor in
                        if let self = self, self.items.indices.contains(index) {
                            self.items[index].progress = p
                        }
                    }
                }

                if result.success {
                    items[index].status = .completed
                    items[index].progress = 1.0
                    items[index].result = result

                    if autoSave {
                        do {
                            try await PhotoLibraryExporter.exportToLibrary(fileURL: item.outputURL)
                        } catch {
                            // Non-fatal
                            print("Auto-save to Photos failed: \(error)")
                        }
                    }
                } else {
                    items[index].status = .failed
                    items[index].progress = 1.0
                    items[index].errorMessage = result.errorMessage
                }

                completedCount += 1
                progressOverall = Double(completedCount) / Double(total)
            }

            isConverting = false
            statusMessage = "Finished processing \(completedCount) of \(total) photo(s)."
        }
    }

    public func exportItemToPhotos(_ item: QueueItem) {
        guard item.status == .completed else { return }
        Task {
            do {
                try await PhotoLibraryExporter.exportToLibrary(fileURL: item.outputURL)
                alertMessage = "Successfully exported '\(item.outputURL.lastPathComponent)' to your Apple Photos library!"
                showAlert = true
            } catch {
                alertMessage = "Failed to export to Photos: \(error.localizedDescription)"
                showAlert = true
            }
        }
    }

    public func revealInFinder(url: URL) {
        #if os(macOS)
        NSWorkspace.shared.activateFileViewerSelecting([url])
        #endif
    }
}
