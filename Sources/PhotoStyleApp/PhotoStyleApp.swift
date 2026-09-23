import SwiftUI
import PhotoStyleCore

@main
struct PhotoStyleApp: App {
    var body: some Scene {
        WindowGroup {
            MainContentView()
                #if os(macOS)
                .frame(minWidth: 640, minHeight: 600)
                #endif
        }
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 720, height: 750)
        #endif
    }
}
