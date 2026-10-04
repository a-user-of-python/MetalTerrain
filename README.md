# MetalTerrain

A 3D terrain generation library for iOS — **Swift + native Metal 3** (Metal 4 fast paths where available).

Chunked, seeded, infinite 3D heightmap terrain with streaming, data-driven biomes,
exposed noise controls, automatic seeded structure placement (houses, towers,
trees, boulders, wells, windmills, dungeons as low-poly 3D meshes), and a
vertex-color renderer with fog, water, and LOD — targeting 60 fps on Apple Silicon.

## The 30-second pitch

Add one Swift package, write ten lines, and your app has an endless explorable
3D world: mountains, beaches, oceans, forests, snowy peaks, plus scattered
low-poly structures — all deterministic from a single seed. Change the seed and
get a brand-new planet. No assets, no textures, no physics engine, no
third-party code.

## Quickstart (about 10 lines)

```swift
import MetalTerrain
import MetalKit

let device = MTLCreateSystemDefaultDevice()!
let world = MTTerrainWorld(seed: 1337)                        // your planet
let renderer = MTTerrainRenderer(device: device, world: world) // GPU side
renderer.setCamera(position: [0, 220, 320], target: [0, 0, 0],
                   fovDegrees: 60, aspect: 16.0 / 9.0,
                   near: 0.1, far: 6000)
renderer.update(cameraTarget: SIMD2(0, 0))  // call every frame
renderer.draw(in: mtkView)                 // call every frame
```

See [Docs/Quickstart.md](Docs/Quickstart.md) for the full 5-minute integration,
including camera setup and the demo app.

## Features

- **Seeded infinite terrain** — deterministic heightmap; same seed always builds the same world.
- **Chunked streaming** — the world pages in around the camera; unused chunks are pooled and reused.
- **Data-driven biomes** — 7 built-ins (deep ocean, ocean, beach, grass, forest, mountain, snowy peak) keyed on normalized height; add or override your own at runtime.
- **Exposed noise config** — seed, octaves, frequency, lacunarity, gain, domain warp, and a ridged "mountain mode".
- **Seeded structures** — houses, towers, trees, boulders, wells, windmills, dungeons placed by a second noise field; one instanced draw call per kind; live on/off toggle.
- **Metal 3 renderer** — one indexed vertex buffer per chunk (baked vertex colors, slope-based cliffs), a transparent water plane at sea level, simple directional lighting + distance fog; Metal 4 argument-table fast paths on iOS 26+ devices that support them.
- **LOD** — far chunks build at half resolution automatically.
- **Zero assets** — vertex colors only; no textures, no downloads.

## Requirements

| Requirement | Minimum |
|---|---|
| iOS | 17.0+ |
| Chip | Apple Silicon (A-series 11+ / M-series) |
| Xcode | 16.0+ |
| Language | Swift 5.9+ |

> **Not yet verified on device.** The library is implemented against the design
> contract in `DESIGN.md` and host-tested where possible, but it has **not yet
> been run on physical iOS hardware**. Treat all "60 fps on M1+" claims as
> design targets until someone confirms them on a real device. The demo app
> (`Demo/TerrainDemo`) exists to prove the API end to end.

## Project layout

```
Sources/MetalTerrain/
  Noise/
    MTSeededRandom.swift    deterministic PRNG (xorshift64*)
    MTPerlinNoise.swift     2D gradient noise, seed-shuffled permutation table
    MTNoise.swift           fbm, ridged, domain warp + MTNoiseConfig
  Core/
    MTConfig.swift          MTTerrainConfig (all tweakables, .default)
    MTBiome.swift           MTBiome + built-in biome table
    MTChunk.swift           MTChunkCoord (Hashable), MTChunk heightmap grid
    MTTerrainWorld.swift    MTTerrainWorld — the main public API
  Structures/
    MTStructures.swift      MTStructureKind, MTStructurePlacement,
                            low-poly mesh builders, seeded placement
  Rendering/
    MTMeshBuilder.swift     heightmap -> indexed triangle mesh + LOD
    MTShaders.metal         lighting, fog, water shaders
    MTTerrainRenderer.swift Metal 3/4 renderer, chunk streaming, instancing
Demo/TerrainDemo/          SwiftUI + MTKView demo app
Docs/                      the documentation set (start here)
```

## Docs

- [Docs/Quickstart.md](Docs/Quickstart.md) — 5-minute integration: add the package, first terrain, camera, first tweaks.
- [Docs/APIReference.md](Docs/APIReference.md) — every public type and method: signatures, defaults, semantics, determinism notes.
- [Docs/BiomeAuthoring.md](Docs/BiomeAuthoring.md) — how biomes map from height, the built-in table, custom biome recipes (higher mountains, lava, underwater).
- [Docs/NoiseTuning.md](Docs/NoiseTuning.md) — what each noise knob does, with "turn this up for X" recipes: archipelago, rolling hills, jagged peaks, canyonlands.
- [Docs/PerformanceGuide.md](Docs/PerformanceGuide.md) — chunk budget math, LOD, instancing, memory estimates, per-device settings, profiling.
- [DESIGN.md](DESIGN.md) — the design contract the implementation must match (authoritative for API signatures).

## License

All code is **written fresh for this project** — no third-party code, no copied
game assets. The concepts are inspired by the `sb_terrain` Scratch extension
(seeded noise, height-threshold biomes, structure noise field), but every line
of source is original.

MetalTerrain is released under a permissive MIT-style grant: use it in personal
or commercial apps, modify it, redistribute it, with attribution. See
[LICENSE](LICENSE).

## Status

- API design: **done** (`DESIGN.md`, matches the implementation contract exactly)
- Implementation: **in progress** — sibling agents are building the modules now
- Demo app: planned
- On-device verification: **not yet** (see honesty note above)
