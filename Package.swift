// swift-tools-version: 5.10
import PackageDescription
import Foundation

let packageDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent().path

let package = Package(
    name: "photostyle",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(name: "PhotoStyleCore", targets: ["PhotoStyleCore"]),
        .executable(name: "PhotoStyleApp", targets: ["PhotoStyleApp"]),
        .executable(name: "photostyle", targets: ["photostyle-cli"])
    ],
    targets: [
        .target(
            name: "CPhotoStyleCore",
            path: "Sources/CPhotoStyleCore",
            publicHeadersPath: "include"
        ),
        .target(
            name: "PhotoStyleCore",
            dependencies: ["CPhotoStyleCore"],
            path: "Sources/PhotoStyleCore",
            linkerSettings: [
                .unsafeFlags([
                    "-L\(packageDir)/Libraries",
                    "-L\(packageDir)/target/release",
                    "-lxdremux_core",
                    "-lc++"
                ])
            ]
        ),
        .executableTarget(
            name: "PhotoStyleApp",
            dependencies: ["PhotoStyleCore"],
            path: "Sources/PhotoStyleApp"
        ),
        .executableTarget(
            name: "photostyle-cli",
            dependencies: ["PhotoStyleCore"],
            path: "Sources/photostyle-cli"
        ),
        .testTarget(
            name: "PhotoStyleCoreTests",
            dependencies: ["PhotoStyleCore"],
            path: "Tests/PhotoStyleCoreTests"
        )
    ]
)
