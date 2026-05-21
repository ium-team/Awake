// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Awake",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Awake", targets: ["Awake"])
    ],
    targets: [
        .executableTarget(
            name: "Awake",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("IOKit")
            ]
        )
    ]
)
