import SwiftUI
import PhotoStyleCore

public struct BadgesView: View {
    public let result: PhotoConversionResult?
    public let options: ConversionOptions?

    public init(result: PhotoConversionResult? = nil, options: ConversionOptions? = nil) {
        self.result = result
        self.options = options
    }

    public var body: some View {
        HStack(spacing: 6) {
            if let res = result {
                if res.hasStyles {
                    badge(title: "Styles", icon: "slider.horizontal.3", color: .purple)
                }
                if res.hasStyles3 {
                    badge(title: "PS3 (Texture+Grain)", icon: "sparkles", color: .indigo)
                }
                if res.hasPortrait {
                    badge(title: "Portrait", icon: "person.crop.circle", color: .orange)
                }
                if res.hasGainMap {
                    badge(title: "HDR Gain Map", icon: "sun.max.fill", color: .blue)
                }
            } else if let opt = options {
                if opt.applePhotographicStyles || opt.applePhotographicStyles3 {
                    badge(title: "Styles", icon: "slider.horizontal.3", color: .purple)
                }
                if opt.applePhotographicStyles3 {
                    badge(title: "PS3", icon: "sparkles", color: .indigo)
                }
                if opt.applePortrait {
                    badge(title: "Portrait", icon: "person.crop.circle", color: .orange)
                }
            }
        }
    }

    private func badge(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
            Text(title)
                .font(.system(size: 10, weight: .semibold))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(color.opacity(0.15))
        .foregroundColor(color)
        .cornerRadius(6)
    }
}
