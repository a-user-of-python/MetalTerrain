# Mesh Shading in MetalTerrain

On M3-family GPUs, MetalTerrain can replace the standard vertex pipeline with
**mesh shaders**: instead of the CPU generating every chunk vertex (heightmap
sample → position, normal, biome color → vertex buffer upload), the GPU
generates vertices itself from the chunk's heightmap texture.

What this replaces, concretely:

- **Standard path:** CPU `MTMeshBuilder` expands each chunk's height grid into
  a full indexed vertex buffer, uploads it, and a classic vertex shader
  transforms it.
- **Mesh-shader path:** the CPU uploads only the compact heightmap; an
  **object shader** decides per chunk which LOD to emit and culls off-screen
  chunks, then a **mesh shader** expands the height grid into vertices and
  triangles on the GPU. The vertex buffer for the chunk never exists on the
  CPU side at all.

The visual result is intended to be identical to the standard path — same
heights, same normals, same biome colors, same lighting.

---

## Supported hardware

**Supported:** M3, M3 Pro, M3 Max, M3 Ultra, M4, M4 Pro, M4 Max, M5 (and later
Apple Silicon), plus iPhone/iPad chips **A17 Pro, A18, A18 Pro, A19, A19 Pro**
(and later).

**Not supported:** M1, M2 (all variants including Pro/Max/Ultra), A16 and
earlier iPhone chips.

Runtime check: `device.supportsFamily(.apple9)` (iOS 17+) — wrapped in
`MTCapabilities.supportsMeshShading(device:)`.

---

## Enabling it

Same two gates as ray tracing
([RayTracing.md](RayTracing.md#enabling-it)):

1. **Build gate:** compile with the `M3_FEATURES` Swift compilation condition.
   Without it, no mesh-shader code is in the binary.
2. **Runtime gate:** `MTCapabilities.supportsMeshShading(device:)` must return
   true.

A renderer built with `M3_FEATURES` switches to the mesh-shader path
automatically on supported GPUs and falls back to CPU mesh generation
otherwise. There is no separate API to learn — chunk streaming, `update`, and
`draw` behave the same from the outside.

---

## What the shaders decide

**Object shader — per chunk, per frame.** Receives the chunk's bounds and
heightmap reference and outputs how many mesh-shader workgroups to launch and
at what LOD. This is where two decisions move from CPU to GPU:

- **LOD selection:** distance from the camera picks the grid density for this
  chunk this frame, mirroring the standard path's LOD table.
- **Culling:** chunks fully outside the view frustum (or fully below the
  terrain horizon from this camera) emit zero workgroups — they cost nothing
  in the mesh shader stage.

**Mesh shader — per workgroup.** Reads height samples from the chunk heightmap
texture, computes world-space positions, normals, and biome colors exactly as
`MTMeshBuilder` does on the CPU, and emits the chunk's triangle grid. The math
is a direct port of the CPU builder so the two paths agree vertex-for-vertex.

---

## Visual parity with the standard path

The mesh-shader path is a **performance optimization, not a visual upgrade**.
Deliberately:

- Same height field, same normals, same per-vertex biome colors → the terrain
  looks the same.
- Same LOD table and same culling behavior → the same chunks are visible at
  the same detail.
- Lighting, fog, water, and shadows are untouched — they run in the fragment
  stage downstream of either path.

If you ever see a difference between the two paths at the same seed and
camera, that's a bug — the mesh shader is meant to be a port of
`MTMeshBuilder`, and parity is the acceptance test.

## See also

- [RayTracing.md](RayTracing.md) — the other M3-family feature; the two can be
  combined (mesh-shaded chunks still provide BLAS geometry for shadows).
- [APIReference.md](APIReference.md#mtcapabilities) — `MTCapabilities`.
- [PerformanceGuide.md](PerformanceGuide.md) — when the mesh path actually
  matters (high `chunkResolution`, high `viewDistance`).
