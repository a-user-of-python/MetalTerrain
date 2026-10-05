// swift-tools-version: 5.9
import PackageDescription

// M3+ FEATURES (hardware ray tracing + mesh shading):
// The M3-only code paths are gated behind the `M3_FEATURES` Swift compilation
// condition (and `#ifdef M3_FEATURES` for the Metal compiler). The default
// build below does NOT define it — the standard path compiles everywhere.
//
// To enable M3 features, define M3_FEATURES for both compilers:
//   Swift:  -D M3_FEATURES  (Other Swift Flags / SWIFT_ACTIVE_COMPILATION_CONDITIONS)
//   Metal:  -DM3_FEATURES   (Other Metal Compiler Flags / MTL_HEADER_SEARCH_PATHS adjacent)
// At runtime the renderer checks MTCapabilities before engaging either path,
// so an M3 build still runs (with standard rendering) on M1/M2/A16 devices.
// See Docs/RayTracing.md and Docs/MeshShading.md.
let package = Package(
    name: "MetalTerrain",
    // macOS for native Mac apps; Catalyst apps build against the iOS SDK.
    // The library is pure Swift + Metal + simd (no UIKit) so it works on both.
    platforms: [.iOS(.v17), .macOS(.v14)],
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
