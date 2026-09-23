import Foundation
import Photos

public enum PhotoLibraryExporter {
    public static func requestAuthorization() async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        return status == .authorized || status == .limited
    }

    public static func exportToLibrary(fileURL: URL) async throws {
        guard await requestAuthorization() else {
            throw NSError(
                domain: "PhotoStyle",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Photo Library access not authorized"]
            )
        }

        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .photo, fileURL: fileURL, options: nil)
        }
    }
}
