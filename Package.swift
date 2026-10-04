// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MetalTerrain",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "MetalTerrain", targets: ["MetalTerrain"]),
    ],
    targets: [
        .target(
            name: "MetalTerrain",
            path: "Sources/MetalTerrain"
        ),
    ]
)
