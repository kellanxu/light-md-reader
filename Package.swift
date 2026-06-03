// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LightMDReader",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "LightMDReader", targets: ["LightMDReader"])
    ],
    targets: [
        .executableTarget(
            name: "LightMDReader",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("WebKit")
            ]
        )
    ]
)
