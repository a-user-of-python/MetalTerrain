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

## Gestures

| Gesture | Action |
|---|---|
| One-finger drag | Orbit (yaw / pitch) |
| Pinch | Zoom (camera distance) |
| Two-finger drag | Pan the orbit target |
| Double-tap | Reset to the opening 3/4 aerial view |

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
