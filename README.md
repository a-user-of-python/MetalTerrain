# MetalTerrain

A 3D terrain generation **library** for iOS — Swift + native Metal (Metal 4 fast paths where available, Metal 3 fallback).

Chunked, seeded, infinite 3D heightmap terrain with streaming, data-driven biomes,
exposed noise controls, automatic seeded structure placement, and a vertex-color
renderer with fog, water, and LOD — targeting 60 fps on Apple Silicon.

**Design principle:** the library owns everything Metal — LOD, shaders, pipelines,
chunk streaming, instancing. Your app only handles what it must: the view
hierarchy, camera, input, and UI.

## The 30-second pitch

Add one Swift package, write five lines, and your app has an endless explorable
3D world: mountains, beaches, oceans, forests, snowy peaks, plus scattered
low-poly structures — all deterministic from a single seed. Change the seed and
get a brand-new planet. No assets, no textures, no physics engine, no
third-party code.

## Quickstart (5 lines)

```swift
import MetalTerrain

let terrainView = MTTerrainView(frame: view.bounds)
terrainView.world = MTTerrainWorld(seed: 1337)
view.addSubview(terrainView)

terrainView.onFrame = { tv, dt in
    // Your camera logic here — the library handles the rest.
    tv.setCamera(position: eye, target: lookAt, aspect: aspect)
}
```

For full control (custom MTKView, manual render loop), use `MTTerrainRenderer`
directly. See [Docs/Quickstart.md](Docs/Quickstart.md).

## Features

- **Seeded infinite terrain** — deterministic heightmap; same seed always builds the same world.
- **Chunked streaming** — the world pages in around the camera; unused chunks are pooled and reused.
- **Data-driven biomes** — 7 built-ins (deep ocean, ocean, beach, grass, forest, mountain, snowy peak) keyed on normalized height; add or override your own at runtime.
- **Exposed noise config** — seed, octaves, frequency, lacunarity, gain, domain warp, and a ridged "mountain mode".
- **Seeded structures** — houses, towers, trees, boulders, wells, windmills, dungeons placed by a second noise field; one instanced draw call per kind; live on/off toggle.
- **Metal renderer** — one indexed vertex buffer per chunk (baked vertex colors, slope-based cliffs), a transparent water plane at sea level, simple directional lighting + distance fog; Metal 4 fast paths on iOS 26+ devices that support them.
- **LOD** — far chunks build at half resolution automatically. Handled internally; the app never touches it.
- **Per-material specular** — rock, sand, grass, snow, and water each get their own specular response. No ray tracing.
- **Zero assets** — vertex colors only; no textures, no downloads.

## Requirements

| Requirement | Minimum |
|---|---|
| iOS | 17.0+ |
| Chip | Apple Silicon (A-series 11+ / M-series) |
| Xcode | 16.0+ (26+ for Metal 4 fast paths) |
| Language | Swift 5.9+ |

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
    MTTerrainWorld.swift    MTTerrainWorld — world API, findSafeSpawn
  Structures/
    MTStructures.swift      MTStructureKind, MTStructurePlacement,
                            low-poly mesh builders, seeded placement
  Rendering/
    MTMeshBuilder.swift     heightmap -> indexed triangle mesh + LOD
    MTShaders.metal         lighting, fog, water shaders (+ RT shadows w/ M3_FEATURES)
    MTMeshShaders.metal     object/mesh shaders for terrain (M3_FEATURES only)
    MTSkyShaders.metal      skybox shaders (all devices)
    MTTerrainRenderer.swift Metal 3/4 renderer, chunk streaming, instancing
    MTTerrainView.swift     MTKView subclass — zero-boilerplate integration
    MTRayTracing.swift      hardware ray-traced shadows (M3_FEATURES only)
    MTSkybox.swift          skybox with visible sun (all devices)
Docs/                      the documentation set
```

## Public API

| Type | Purpose |
|---|---|
| `MTTerrainView` | Drop-in MTKView. Set `world`, drive camera via `setCamera`, done. |
| `MTTerrainRenderer` | Lower-level renderer for custom MTKView setups. |
| `MTTerrainWorld` | World generation: `heightAt`, `biomeAt`, `findSafeSpawn`, chunk gen. |
| `MTTerrainConfig` | All tweakables (chunk size, view distance, noise, sea level...). |
| `MTBiome` | Biome definition; `setBiome`/`removeBiome` for customization. |

## Docs

- [Docs/Quickstart.md](Docs/Quickstart.md) — 5-minute integration.
- [Docs/APIReference.md](Docs/APIReference.md) — every public type and method.
- [Docs/BiomeAuthoring.md](Docs/BiomeAuthoring.md) — biome system and custom biome recipes.
- [Docs/NoiseTuning.md](Docs/NoiseTuning.md) — noise knobs and terrain recipes.
- [Docs/PerformanceGuide.md](Docs/PerformanceGuide.md) — chunk budgets, LOD, per-device settings.
- [DESIGN.md](DESIGN.md) — the design contract.

## License

All code is **written fresh for this project** — no third-party code, no copied
game assets.

MetalTerrain is released under a permissive MIT-style grant: use it in personal
or commercial apps, modify it, redistribute it, with attribution. See
[LICENSE](LICENSE).
