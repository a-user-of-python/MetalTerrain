# MTSkybox

`MTSkybox` is the library's sky renderer: a gradient sky dome with a visible
sun disc. It works on **all devices** — it is not gated behind `M3_FEATURES`
and needs no special GPU.

The skybox is drawn first each frame, behind everything else, and its sun
position matches the terrain's lighting direction (and the ray-traced shadow
direction on M3-family GPUs — see [RayTracing.md](RayTracing.md)).

---

## Basic usage

```swift
public final class MTSkybox {
    public init(device: MTLDevice)
    public var sunAzimuth: Float      // radians, default points east-ish
    public var sunElevation: Float    // radians above the horizon
    public func draw(encoder: MTLRenderCommandEncoder,
                     viewProjection: matrix_float4x4)
}
```

**5-line integration** with the renderer (this is the default — the renderer
creates its skybox itself, so you only need this if you're driving your own
render pass):

```swift
let skybox = MTSkybox(device: device)
// per frame:
skybox.sunElevation = Float.pi / 6   // 30° above the horizon
skybox.draw(encoder: encoder, viewProjection: viewProj)
```

With `MTTerrainRenderer` or `MTTerrainView` you don't even write that:

```swift
renderer.skybox?.sunAzimuth = 0.8
renderer.skybox?.sunElevation = 0.5
// drawn automatically at the start of renderer.draw(in:)
```

`renderer.skybox` is created by default; set it to `nil` to disable sky
rendering.

---

## Sun semantics

- **`sunAzimuth`** — horizontal angle of the sun, in radians. `0` points along
  +X; increasing values rotate toward +Z (right-handed about +Y). Full circle
  is `2π`.
- **`sunElevation`** — vertical angle above the horizon, in radians.
  `0` = sun on the horizon, `π/2` = directly overhead. Negative values put the
  sun below the horizon (sky darkens; terrain lighting dims accordingly).

Both are live: changing them mid-frame takes effect on the next `draw`. The
same angles drive the terrain shader's sun direction, so the sky's sun disc
and the light falling on the mountains always agree — move the sun and both
move together. On M3-family builds the ray-traced shadows
([RayTracing.md](RayTracing.md)) are traced toward this same position.

The same properties are mirrored on `MTTerrainView` (`sunAzimuth`,
`sunElevation`) as a convenience — they forward to `renderer.skybox`.

## See also

- [APIReference.md](APIReference.md#mtskybox) — full `MTSkybox` reference.
- [RayTracing.md](RayTracing.md) — sun shadows traced toward this sun.
