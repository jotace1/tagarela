// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "tagarela",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .executable(name: "tagarela", targets: ["Tagarela"])
    ],
    targets: [
        .executableTarget(
            name: "Tagarela",
            path: "Sources/Tagarela",
            linkerSettings: [
                .linkedFramework("AVFoundation"),
                .linkedFramework("Carbon"),
                .linkedFramework("ScreenCaptureKit"),
                .linkedFramework("Speech"),
                .linkedFramework("SwiftUI")
            ]
        )
    ]
)
