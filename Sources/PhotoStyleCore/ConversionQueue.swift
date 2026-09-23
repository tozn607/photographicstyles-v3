import Foundation
import SwiftUI

public struct QueueItem: Identifiable, Sendable {
    public let id: UUID
    public let sourceURL: URL
    public let outputURL: URL
    public var status: ItemStatus
    public var progress: Double
    public var result: PhotoConversionResult?
    public var errorMessage: String?

    public enum ItemStatus: String, Sendable {
        case pending = "Pending"
        case processing = "Processing"
        case completed = "Completed"
        case failed = "Failed"
        case cancelled = "Cancelled"
    }

    public init(sourceURL: URL, outputURL: URL) {
        self.id = UUID()
        self.sourceURL = sourceURL
        self.outputURL = outputURL
        self.status = .pending
        self.progress = 0.0
        self.result = nil
        self.errorMessage = nil
    }
}

public actor ConversionQueue {
    public static let shared = ConversionQueue()

    private var isCancelled = false

    public func cancelAll() {
        isCancelled = true
    }

    public func convertSingle(
        item: QueueItem,
        options: ConversionOptions,
        progressHandler: (@Sendable (Double) -> Void)? = nil
    ) async -> PhotoConversionResult {
        progressHandler?(0.1)

        let result = await Task.detached(priority: .userInitiated) {
            progressHandler?(0.3)
            let convResult = PhotoStyleBridge.convert(
                inputPath: item.sourceURL.path,
                outputPath: item.outputURL.path,
                options: options
            )
            progressHandler?(1.0)
            return convResult
        }.value

        return result
    }
}
