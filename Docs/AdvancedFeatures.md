# Advanced Features — MetalTerrain v1.1+

This guide covers the advanced rendering features in detail: smooth wireframe,
procedural 3D geometric detail, hardware ray tracing, mesh shading, skybox,
and real-time reflections.

---

## Smooth Animated Wireframe

**Property:** `renderer.wireframe: Bool` (default `false`)

Unlike traditional wireframe modes that draw raw triangle edges (the "Lego"
look), MetalTerrain renders a smooth animated overlay:

- **Contour lines**: Smooth iso-height bands that flow across the terrain
  surface, following the actual geometry rather than the triangulation.
- **Grid overlay**: A subtle world-aligned grid, anti-aliased using
  screen-space derivatives (`fwidth`) for crisp lines at any distance.
- **Animated pulse**: A wave radiates from the camera, brightening the lines
  as it passes — giving a "scanning" effect.
- **Distance fade**: Lines fade out beyond 800 units to prevent shimmering
  on distant terrain.

The wireframe is implemented in the fragment shader (both the standard
`terrain_fragment` and the mesh-shader `mesh_terrain_fragment`), so it works
on all devices without requiring mesh shading hardware.

```swift
renderer.wireframe = true  // Enable the smooth animated wireframe
```

**Use cases:**
- Debugging terrain generation (see the actual heightfield structure)
- Visualizing LOD transitions
- Aesthetic "hologram" or "scan" effects

---

## Procedural 3D Geometric Detail

**Property:** `renderer.detailAmount: Float` (default `1.0`, range `0`…`1`)

This is real geometric displacement — not just coloring or normal mapping.
Vertices are physically moved along their normals by material-specific
procedural noise, giving each surface true 3D texture you can see from
grazing angles:

| Material | Effect | Amplitude | Frequency |
|----------|--------|-----------|-----------|
| Grass (0) | Tufty bumps | 0.9 | 0.55 |
| Rock (1) | Craggy displacement | 1.6 | 0.35 |
| Sand (2) | Fine ripples | 0.35 | 1.4 |
| Snow (3, 4) | Soft drifts | 0.5 | 0.22 |
| Water (5) | None (stays flat) | 0 | — |

**How it works:**

1. **Mesh-shader path** (M3+ devices): The mesh shader displaces vertices
   when emitting them, using 2-octave value noise. Normals are perturbed by
   the noise gradient so lighting follows the bumps correctly.

2. **Standard path** (all devices): The vertex shader applies the same
   displacement using identical noise functions, ensuring visual parity.

The noise is deterministic (based on world position), so the detail is
stable — it doesn't swim or flicker as the camera moves.

**Performance:** The displacement is computed per-vertex, not per-pixel,
so the cost is minimal. Set `detailAmount = 0` to disable for maximum
performance on older devices.

```swift
renderer.detailAmount = 1.0  // Full detail (default)
renderer.detailAmount = 0.5  // Half detail
renderer.detailAmount = 0.0  // Disabled (flat shading)
```

**Water:** Water surfaces do NOT get geometric displacement. The water plane
must stay perfectly flat to avoid z-fighting and glitching where it meets
the shoreline. Water animation is handled in the fragment shader instead.

---

## Hardware Ray Tracing

**Build flag:** `M3_FEATURES` (Swift and Metal)  
**Runtime check:** `MTCapabilities.supportsHardwareRayTracing(device:)`

When enabled, the renderer builds acceleration structures for ray-traced
sun shadows:

- **BLAS** (Bottom-Level): One per terrain chunk, built from the chunk's
  triangle mesh. Cached by chunk ID and rebuilt only when chunks change.
- **TLAS** (Top-Level): One for the whole scene, instancing all visible
  chunk BLASes. Rebuilt when the visible chunk set changes.

The ray-traced shadows are subtle by design — they enhance the analytic
shadows rather than replacing them. On unsupported hardware, the renderer
automatically falls back to the standard shadow path.

**Supported hardware:**
- iPad Pro 11"/13" (M4, 2024), iPad Air 11"/13" (M3, 2025)
- iPad mini (A17 Pro, 7th gen)
- iPhone 15 Pro/Pro Max (A17 Pro), iPhone 16 series (A18/A18 Pro),
  iPhone 17 series (A19/A19 Pro)

See [RayTracing.md](RayTracing.md) for implementation details.

---

## Mesh Shading

**Build flag:** `M3_FEATURES`  
**Runtime check:** `MTCapabilities.supportsMeshShading(device:)`

The mesh-shader path generates terrain geometry entirely on the GPU:

- **Object shader** (`mesh_terrain_object`): One threadgroup per chunk.
  Performs frustum culling and calculates how many mesh threadgroups to
  dispatch based on the chunk's LOD.
- **Mesh shader** (`mesh_terrain_mesh`): One threadgroup per 8×8-quad tile.
  Samples the heightmap, computes positions/normals/colors, and emits
  triangles directly — no CPU vertex buffers needed.
- **Fragment shader** (`mesh_terrain_fragment`): Pixel-identical to the
  standard path, including the smooth wireframe overlay.

**Benefits:**
- Zero CPU overhead for mesh generation (no `MTMeshBuilder` on the main thread)
- Frustum culling in the object shader (culled chunks dispatch zero threadgroups)
- Procedural detail displacement happens naturally in the mesh shader

**Fallback:** If mesh shading is unavailable or the pipeline fails to compile,
the renderer automatically uses the standard vertex-shader path. The visual
result is identical.

See [MeshShading.md](MeshShading.md) for the shader architecture.

---

## Skybox with Visible Sun

**Property:** `renderer.skybox: MTSkybox?` (enabled by default)

A procedural sky with a visible sun disc that responds to the sun controls:

- **Sun position**: Controlled by `renderer.sunAzimuth` and
  `renderer.sunElevation` (degrees). The sun disc moves across the sky.
- **Atmosphere**: Gradient from horizon to zenith, with warm colors near
  the sun.
- **Stars**: Visible at night (when sun elevation is below the horizon).

The skybox is drawn first as a fullscreen pass at the far plane, with depth
writes disabled. Terrain drawn afterward occludes it correctly.

See [Skybox.md](Skybox.md) for customization.

---

## Real-Time Reflections

**Method:** `renderer.renderReflection(to:from:lookingAt:fovDegrees:)`

Renders the scene (skybox + terrain) into an offscreen texture from an
arbitrary camera position. Used for mirror reflections, but available for
any app-level effect.

```swift
// Create a small texture for the reflection (256x128 is plenty for mirrors)
let desc = MTLTextureDescriptor.texture2DDescriptor(
    pixelFormat: .bgra8Unorm, width: 256, height: 128, mipmapped: false)
desc.usage = [.renderTarget, .shaderRead]
desc.storageMode = .private
let reflectionTex = device.makeTexture(descriptor: desc)!

// Render the scene from behind the car (what the mirrors see)
renderer.renderReflection(to: reflectionTex,
                          from: carPosition + SIMD3<Float>(0, 4, 0),
                          lookingAt: carPosition - forward * 50)
```

**Performance notes:**
- Structures and water are skipped in reflection passes (they're small in
  mirrors anyway).
- The reflection uses a dedicated uniform slot, so it doesn't disturb the
  main render state.
- `waitUntilCompleted()` is called — use sparingly (once per frame max).

---

## Putting It All Together

```swift
import MetalTerrain

// Setup
let renderer = MTTerrainRenderer(device: device, world: world)

// Enable all the eye candy (M3+ device, M3_FEATURES build)
renderer.wireframe = false          // Set true for the scan effect
renderer.detailAmount = 1.0         // Full procedural 3D detail
renderer.shaderEffectsEnabled = true

// The renderer automatically uses:
// - Ray-traced shadows (if M3_FEATURES + supported hardware)
// - Mesh shading (if M3_FEATURES + supported hardware)
// - Standard path (otherwise — same visuals, CPU mesh generation)

// Per-frame
renderer.setCamera(position: camPos, target: camTarget,
                   fovDegrees: 55, aspect: aspect, near: 1, far: 4000)
renderer.update(cameraTarget: SIMD2<Float>(camTarget.x, camTarget.z))
renderer.draw(in: view)
```

---

## Feature Matrix

| Feature | Standard Build | M3_FEATURES Build (unsupported HW) | M3_FEATURES Build (M3+ HW) |
|---------|---------------|-----------------------------------|---------------------------|
| Smooth wireframe | ✅ | ✅ | ✅ |
| Procedural 3D detail | ✅ (vertex shader) | ✅ (vertex shader) | ✅ (mesh shader) |
| Skybox + sun | ✅ | ✅ | ✅ |
| Analytic shadows | ✅ | ✅ | ✅ |
| Ray-traced shadows | ❌ | ❌ (falls back) | ✅ |
| Mesh shading | ❌ | ❌ (falls back) | ✅ |
| Reflections API | ✅ | ✅ | ✅ |
