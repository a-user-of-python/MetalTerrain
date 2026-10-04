# TerrainDemo — MetalTerrain demo app

A SwiftUI iOS app proving MetalTerrain's drop-in integration. Full-screen
3D terrain (MTKView) with orbit / pinch-zoom / two-finger pan, a seed field
with Regenerate, biome presets (Default / Desert / Alien / Custom),
Structures / Wireframe / Water toggles, and an FPS readout.

## 5-step setup

1. **Build the library first.** This project links MetalTerrain as a local
   Swift package at `../..` (the `metal-terrain` repo root). Make sure
   `Package.swift` exists there with a `MetalTerrain` library product
   (the library agent provides this).
2. **Open** `Demo/TerrainDemo/TerrainDemo.xcodeproj` in Xcode 15 or later.
3. **Select the `TerrainDemo` scheme** and an iOS 17+ simulator
   (iPhone or iPad) — or a physical device.
4. **Signing (physical device only):** in the target's *Signing &
   Capabilities*, pick your Development Team and change the bundle ID
   from `com.example.TerrainDemo` to your own. Simulator builds need nothing.
5. **Press Cmd+R.** First open resolves the local package; if Xcode asks,
   let it "Resolve Package Versions".

## Run on Mac (Mac Catalyst — Intel + Apple Silicon)

The same target runs natively on Macs via Mac Catalyst
(`SUPPORTS_MACCATALYST = YES` is set in the project). No separate target.

1. Open `Demo/TerrainDemo/TerrainDemo.xcodeproj` in Xcode 16 or later.
2. In the scheme destination picker, choose **My Mac (Mac Catalyst)**
   (not "My Mac" — that's the native macOS destination, which this
   iOS-target project doesn't build for).
3. **Signing:** pick your Development Team once (same as iOS).
4. **Press Cmd+R.** The app launches as a Mac window with the full 3D
   terrain, control panel, and FPS readout.

Notes:
- Catalyst builds are universal: the same build runs on **Intel** and
  Apple Silicon Macs.
- On Intel Macs (macOS 15 and earlier) the renderer automatically uses
  the Metal 3 path — Metal 4 requires macOS 26+ (Tahoe), and the
  `#available(iOS 26, macOS 26, *)` check falls back cleanly.
- Metal needs a real GPU: the iOS Simulator and Catalyst both render
  with the Mac's GPU, so performance is representative.

## Gestures

| Gesture (iOS) | Gesture (Mac) | Action |
|---|---|---|
| One-finger drag | Mouse drag | Orbit (yaw / pitch) |
| Pinch | Trackpad pinch | Zoom (camera distance) |
| Two-finger drag | Trackpad two-finger scroll, or set Mouse-drag → Pan | Pan the orbit target |
| Double-tap | Double-click | Reset to the opening 3/4 aerial view |
| — | Arrow keys | Pan the orbit target |
| — | `+` / `−` | Zoom in / out |
| — | `0` | Reset view |

The **Mouse drag** segmented control in the panel (Mac only) switches
mouse-drag between Orbit and Pan.

## What the demo exercises

- `MTTerrainWorld(seed:config:)` + `MTTerrainRenderer(device:world:)`
  (~10 lines — marked "this is the whole integration" in `TerrainView.swift`)
- `world.setBiome(_:)` — the **Custom** preset injects a `highPeaks`
  biome (0.80–1.0) that takes precedence over the built-ins
- Live `world.structuresEnabled`, `renderer.wireframe`, `renderer.showsWater`
- Per-frame `renderer.setCamera(...)` / `renderer.update(cameraTarget:)` /
  `renderer.draw(in:)`

## Files

- `TerrainDemo/TerrainDemoApp.swift` — `@main` entry
- `TerrainDemo/ContentView.swift` — layout (portrait bottom panel,
  landscape side panel), seed/regenerate state
- `TerrainDemo/TerrainView.swift` — MTKView wrapper, Coordinator with
  gestures + camera + FPS EMA, biome preset definitions
- `TerrainDemo/ControlPanel.swift` — big-type, high-contrast controls
