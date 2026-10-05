# Hardware Ray Tracing in MetalTerrain

MetalTerrain can use Apple Silicon's **hardware ray-tracing units** (the same
hardware that accelerates `MPSRayIntersector` and Metal's `MTLAccelerationStructure`
APIs) for one purpose: **ray-traced sun shadows on terrain**. Instead of the
analytic shadow term in the standard shader, shadow rays are traced from each
surface point toward the sun against an acceleration structure built from the
actual chunk geometry, so mountains and cliffs cast true shadows on each other
and on the terrain.

This is an M3-family feature only — see the chip list below.

---

## Supported hardware

> **iOS only for now.** MetalTerrain targets iPhone and iPad — there is no Mac
> build yet.

**Supported iPads (M3+):**
- iPad Pro 11" (M4, 2024), iPad Pro 13" (M4, 2024)
- iPad Air 11" (M3, 2025), iPad Air 13" (M3, 2025)
- iPad mini (A17 Pro, 7th gen, 2024)

**Supported iPhones:**
- iPhone 15 Pro / Pro Max (A17 Pro)
- iPhone 16 / 16 Plus / 16e (A18), iPhone 16 Pro / Pro Max (A18 Pro)
- iPhone 17 series (A19 / A19 Pro)

**Not supported:** M1/M2 iPads (all), A16 and earlier iPhones.

The library never assumes support from the device name. The runtime check is
`device.supportsFamily(.apple9)` (available iOS 17+), wrapped in
`MTCapabilities` (see [APIReference.md](APIReference.md#mtcapabilities))
so your code can branch on the actual GPU in front of it.

---

## Enabling it

Two gates, both required:

1. **Build gate — the `M3_FEATURES` Swift compilation condition.** All
   ray-tracing code in the library is compiled only when this flag is set, e.g.
   `swift build -Xswiftc -D -Xswiftc M3_FEATURES` or the equivalent
   "Other Swift Flags" entry in Xcode. A standard build (no flag) contains no
   ray-tracing code at all and runs on every supported device.
2. **Runtime gate — the device check.** With the flag on, `MTTerrainRenderer`
   calls `MTCapabilities.supportsHardwareRayTracing(device:)` at init and only
   creates `rayTracing` when the GPU answers yes.

You don't do any of this by hand in the normal case: **a renderer built with
`M3_FEATURES` enables ray-traced sun shadows automatically on supported
devices**, and silently falls back to the analytic shadow path on everything
else. Checking manually looks like this:

```swift
import MetalTerrain

if MTCapabilities.supportsHardwareRayTracing(device: device) {
    // MTRayTracing is available; renderer.rayTracing is non-nil
    // only when the library was also built with M3_FEATURES.
}
```

Note that `MTCapabilities.supportsHardwareRayTracing(device:)` returning true
is not enough on its own — the `M3_FEATURES` build flag must also be set, or
`renderer.rayTracing` stays `nil`.

---

## How acceleration structures work here

The renderer keeps two levels of Metal acceleration structures:

- **BLAS (bottom-level): one per chunk.** Each visible chunk's triangle mesh
  (vertex buffer + index buffer) is baked into its own bottom-level
  acceleration structure. Geometry is static while a chunk is resident, so a
  BLAS is built once when the chunk's buffers are created and dropped when the
  chunk is recycled.
- **TLAS (top-level): one for the frame.** Built over the currently visible
  chunk set, with each chunk's BLAS placed at its world transform
  (`matrix_float4x4`). The TLAS is what the shadow ray-tracing pass intersects
  against.

**Rebuild policy:** the TLAS is rebuilt whenever the visible chunk set changes
— the same streaming that pages chunks in and out in
`renderer.update(cameraTarget:)`. Chunks don't move or deform once built, so
there is no per-frame geometry refit: a stable camera position means a stable
TLAS and zero build cost per frame. You interact with this through one method:

```swift
rayTracing.update(chunks: [
    (id: 0, vertexBuffer: vb0, indexBuffer: ib0, indexCount: n0, transform: t0),
    // … one entry per visible chunk
])
```

The renderer calls this for you; it's public for custom integrations using
`MTRayTracing` directly with `MTTerrainRenderer.draw` overrides.

---

## Performance notes

- **Build cost is the whole price.** BLAS construction runs on the GPU and is
  paid once per chunk, TLAS construction once per visible-set change. Steady
  state (camera still or drifting inside the resident set) costs one ray per
  fragment in the shadow pass — that is what the hardware units are for.
- **Fast camera moves cost builds, not hitches.** Chunk streaming pages a
  bounded number of chunks per frame, so the number of new BLAS builds per
  frame is bounded too; distant pop-in degrades to shadows lagging a frame or
  two behind new geometry, never a frame drop.
- **Memory:** each BLAS holds the chunk's triangle data in the GPU's
  acceleration-structure format — roughly proportional to the standard vertex
  buffer. Chunks leaving the view distance release their BLAS with their
  buffers.

## Caveats

- **This is new and needs device testing.** The host-side logic is
  straightforward, but ray-traced shadow quality, build latency on A17
  Pro-class GPUs, and driver behavior have not yet been validated on a physical
  device. Report what you see.
- Ray tracing here covers **sun shadows on terrain only**. Structures, water,
  and the skybox use their existing shading paths.
- On unsupported devices (M1/M2, A16 and earlier) the analytic shadow term is
  used and the visual difference is intentionally subtle — same sun, same
  direction, softer contact. Nothing else in the API changes.

## See also

- [MeshShading.md](MeshShading.md) — the other M3-family feature.
- [Skybox.md](Skybox.md) — the sun position these shadows are traced toward.
- [APIReference.md](APIReference.md#mtraytracing) — `MTRayTracing`,
  `MTCapabilities`.
