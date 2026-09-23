import Foundation
import CoreGraphics
import ImageIO

#if canImport(AppKit)
import AppKit
public typealias PlatformImage = NSImage
#elseif canImport(UIKit)
import UIKit
public typealias PlatformImage = UIImage
#endif

public enum ImageLoader {
    public static func loadThumbnail(from url: URL, maxDimension: CGFloat = 256) -> PlatformImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension
        ]
        guard let cgThumb = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }

        #if canImport(AppKit)
        let size = NSSize(width: cgThumb.width, height: cgThumb.height)
        return NSImage(cgImage: cgThumb, size: size)
        #elseif canImport(UIKit)
        return UIImage(cgImage: cgThumb)
        #endif
    }

    public static func imageDimensions(from url: URL) -> (width: Int, height: Int)? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            return nil
        }
        let w = props[kCGImagePropertyPixelWidth] as? Int ?? 0
        let h = props[kCGImagePropertyPixelHeight] as? Int ?? 0
        return (w, h)
    }
}
