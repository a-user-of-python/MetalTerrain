import SwiftUI
import MetalKit
import MetalTerrain

// MARK: - Biome presets

/// Biome presets offered by the demo's segmented picker.
enum BiomePreset: String, CaseIterable, Identifiable {
    case `default` = "Default"
    case desert = "Desert"
    case alien = "Alien"
    case custom = "Custom"

    var id: String { rawValue }
}

// MARK: - Drag mode (Mac Catalyst)

/// On Mac there's no two-finger touch: the user picks what mouse-drag does.
/// Trackpad pinch still zooms and two-finger trackpad scroll still pans.
enum DragMode: String, CaseIterable, Identifiable {
    case orbit = "Orbit"
    case pan = "Pan"

    var id: String { rawValue }
}

// MARK: - TerrainView

#if targetEnvironment(macCatalyst)
/// MTKView subclass so Mac key commands have a UIResponder to land on.
/// Forwards to the Coordinator (which owns the camera state).
private final class TerrainMTKView: MTKView {
    weak var keyTarget: TerrainView.Coordinator?

    override var canBecomeFirstResponder: Bool { true }

    @objc private func keyPanUp() { keyTarget?.keyPanUp() }
    @objc private func keyPanDown() { keyTarget?.keyPanDown() }
    @objc private func keyPanLeft() { keyTarget?.keyPanLeft() }
    @objc private func keyPanRight() { keyTarget?.keyPanRight() }
    @objc private func keyZoomIn() { keyTarget?.keyZoomIn() }
    @objc private func keyZoomOut() { keyTarget?.keyZoomOut() }
    @objc private func keyResetView() { keyTarget?.keyResetView() }
}
#endif

/// SwiftUI wrapper around an MTKView that renders a MetalTerrain world.
struct TerrainView: UIViewRepresentable {
    @Binding var seed: UInt64
    /// Bump to force a full world + renderer rebuild (Regenerate button).
    @Binding var rebuildToken: Int
    @Binding var preset: BiomePreset
    @Binding var structuresEnabled: Bool
    @Binding var wireframe: Bool
    @Binding var showsWater: Bool
    /// Updated ~2x/sec with the frame-time EMA.
    @Binding var fps: Double
    /// Mac Catalyst: what mouse-drag does (touch devices always orbit).
    @Binding var dragMode: DragMode

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MTKView {
        #if targetEnvironment(macCatalyst)
        let view = TerrainMTKView()
        #else
        let view = MTKView()
        #endif
        view.device = MTLCreateSystemDefaultDevice()
        view.delegate = context.coordinator
        view.preferredFramesPerSecond = 60
        view.isPaused = false
        view.enableSetNeedsDisplay = false
        view.colorPixelFormat = .bgra8Unorm
        view.depthStencilPixelFormat = .depth32Float
        view.clearColor = MTLClearColor(red: 0.04, green: 0.06, blue: 0.11, alpha: 1.0)
        context.coordinator.attach(to: view, parent: self)
        #if targetEnvironment(macCatalyst)
        (view as? TerrainMTKView)?.keyTarget = context.coordinator
        #endif
        return view
    }

    func updateUIView(_ uiView: MTKView, context: Context) {
        context.coordinator.sync(with: self)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, MTKViewDelegate {
        // Camera: orbit around `target` (spherical). Survives world rebuilds.
        // Starts at a 3/4 aerial view.
        var yaw: Float = -0.6
        var pitch: Float = 0.62
        var distance: Float = 340
        var target = SIMD3<Float>(0, 0, 0)

        private var parent = TerrainView(
            seed: .constant(1337), rebuildToken: .constant(0),
            preset: .constant(.default), structuresEnabled: .constant(true),
            wireframe: .constant(false), showsWater: .constant(true),
            fps: .constant(0), dragMode: .constant(.orbit)
        )
        private var device: MTLDevice?
        private var world: MTTerrainWorld?
        private var renderer: MTTerrainRenderer?

        private var lastSeed: UInt64?
        private var lastToken: Int?
        private var lastPreset: BiomePreset?

        private var fpsEMA: Double = 60
        private var lastFrameTime: CFTimeInterval = 0
        private var lastFPSPush: CFTimeInterval = 0

        // MARK: Setup

        func attach(to view: MTKView, parent: TerrainView) {
            self.parent = parent
            self.device = view.device

            let orbit = UIPanGestureRecognizer(target: self, action: #selector(handleOrbit(_:)))
            orbit.minimumNumberOfTouches = 1
            orbit.maximumNumberOfTouches = 1
            view.addGestureRecognizer(orbit)

            let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            pan.minimumNumberOfTouches = 2
            pan.maximumNumberOfTouches = 2
            view.addGestureRecognizer(pan)

            let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
            view.addGestureRecognizer(pinch)

            let reset = UITapGestureRecognizer(target: self, action: #selector(handleReset(_:)))
            reset.numberOfTapsRequired = 2
            view.addGestureRecognizer(reset)

            #if targetEnvironment(macCatalyst)
            // Mac keyboard controls: arrows pan, +/- zoom, 0 resets.
            // (Trackpad pinch/scroll already work via the recognizers above.)
            view.addKeyCommand(UIKeyCommand(input: UIKeyCommand.inputUpArrow,
                                            modifierFlags: [],
                                            action: #selector(keyPanUp)))
            view.addKeyCommand(UIKeyCommand(input: UIKeyCommand.inputDownArrow,
                                            modifierFlags: [],
                                            action: #selector(keyPanDown)))
            view.addKeyCommand(UIKeyCommand(input: UIKeyCommand.inputLeftArrow,
                                            modifierFlags: [],
                                            action: #selector(keyPanLeft)))
            view.addKeyCommand(UIKeyCommand(input: UIKeyCommand.inputRightArrow,
                                            modifierFlags: [],
                                            action: #selector(keyPanRight)))
            view.addKeyCommand(UIKeyCommand(input: "+", modifierFlags: [],
                                            action: #selector(keyZoomIn)))
            view.addKeyCommand(UIKeyCommand(input: "-", modifierFlags: [],
                                            action: #selector(keyZoomOut)))
            view.addKeyCommand(UIKeyCommand(input: "0", modifierFlags: [],
                                            action: #selector(keyResetView)))
            // Key commands need first responder.
            DispatchQueue.main.async { view.becomeFirstResponder() }
            #endif
        }

        /// Applies SwiftUI state to the Metal objects. Rebuilds the world only
        /// when the seed, rebuild token, or biome preset changed.
        func sync(with parent: TerrainView) {
            self.parent = parent
            if lastSeed != parent.seed || lastToken != parent.rebuildToken || lastPreset != parent.preset {
                rebuildWorld(seed: parent.seed, preset: parent.preset)
                lastSeed = parent.seed
                lastToken = parent.rebuildToken
                lastPreset = parent.preset
            }
            renderer?.wireframe = parent.wireframe
            renderer?.showsWater = parent.showsWater
            world?.structuresEnabled = parent.structuresEnabled
        }

        // MARK: World construction

        private func rebuildWorld(seed: UInt64, preset: BiomePreset) {
            guard let device else { return }

            // ─────────────────────────────────────────────────────────
            // This is the whole integration:
            // ─────────────────────────────────────────────────────────
            let world: MTTerrainWorld
            switch preset {
            case .default:
                world = MTTerrainWorld(seed: seed, config: .default)
            case .desert:
                var config = MTTerrainConfig.default
                config.biomes = Self.desertBiomes
                world = MTTerrainWorld(seed: seed, config: config)
            case .alien:
                var config = MTTerrainConfig.default
                config.biomes = Self.alienBiomes
                world = MTTerrainWorld(seed: seed, config: config)
            case .custom:
                world = MTTerrainWorld(seed: seed, config: .default)
                // Custom biome: takes precedence over the built-ins in 0.80–1.0,
                // replacing the default mountain/snowyPeak bands up there.
                world.setBiome(MTBiome(
                    name: "highPeaks",
                    minHeight: 0.80, maxHeight: 1.0,
                    groundColor: SIMD3<Float>(0.80, 0.78, 0.85),
                    slopeColor: SIMD3<Float>(0.30, 0.28, 0.34)
                ))
            }
            self.world = world
            let renderer = MTTerrainRenderer(device: device, world: world)
            renderer.wireframe = parent.wireframe
            renderer.showsWater = parent.showsWater
            self.renderer = renderer
            // ─────────────────────────────────────────────────────────
        }

        // MARK: - MTKViewDelegate

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            // Aspect is recomputed every frame in draw(in:).
        }

        func draw(in view: MTKView) {
            guard let renderer else { return }

            // Frame-time EMA -> FPS label (pushed to SwiftUI at most 2x/sec).
            let now = CACurrentMediaTime()
            if lastFrameTime > 0 {
                let dt = now - lastFrameTime
                if dt > 0 {
                    fpsEMA = fpsEMA * 0.92 + (1.0 / dt) * 0.08
                }
                if now - lastFPSPush > 0.5 {
                    lastFPSPush = now
                    let value = fpsEMA
                    DispatchQueue.main.async { self.parent.$fps.wrappedValue = value }
                }
            }
            lastFrameTime = now

            let aspect = Float(view.drawableSize.width / max(1, view.drawableSize.height))
            let cp = cos(pitch)
            let position = target + SIMD3<Float>(sin(yaw) * cp, sin(pitch), cos(yaw) * cp) * distance

            renderer.setCamera(position: position, target: target,
                               fovDegrees: 55, aspect: aspect,
                               near: 1, far: 4000)
            renderer.update(cameraTarget: SIMD2<Float>(target.x, target.z))
            renderer.draw(in: view)
        }

        // MARK: - Gestures

        /// Single-finger drag: orbit (yaw / pitch) — or pan when the Mac
        /// drag-mode picker is set to Pan. Mouse drag on Catalyst fires this
        /// recognizer, so it doubles as the Mac orbit control.
        @objc private func handleOrbit(_ g: UIPanGestureRecognizer) {
            guard let v = g.view else { return }
            #if targetEnvironment(macCatalyst)
            if parent.dragMode == .pan {
                handlePan(g)
                return
            }
            #endif
            let t = g.translation(in: v)
            yaw -= Float(t.x * 0.0055)
            pitch = min(1.35, max(0.08, pitch - Float(t.y * 0.0055)))
            g.setTranslation(.zero, in: v)
        }

        /// Two-finger drag: pan the orbit target across the ground.
        @objc private func handlePan(_ g: UIPanGestureRecognizer) {
            guard let v = g.view else { return }
            let t = g.translation(in: v)
            let s: Float = distance * 0.0016
            let right = SIMD3<Float>(cos(yaw), 0, -sin(yaw))
            let fwd = SIMD3<Float>(sin(yaw), 0, cos(yaw))
            target += (-Float(t.x) * right + Float(t.y) * fwd) * s
            g.setTranslation(.zero, in: v)
        }

        /// Pinch: zoom (camera distance).
        @objc private func handlePinch(_ g: UIPinchGestureRecognizer) {
            distance = min(1200, max(40, distance / Float(g.scale)))
            g.scale = 1
        }

        /// Double-tap: reset to the opening 3/4 aerial view.
        @objc private func handleReset(_ g: UITapGestureRecognizer) {
            yaw = -0.6
            pitch = 0.62
            distance = 340
            target = SIMD3<Float>(0, 0, 0)
        }

        #if targetEnvironment(macCatalyst)
        // MARK: - Mac keyboard controls
        // (Called by TerrainMTKView, which owns the UIResponder slot.)

        func panTarget(dx: Float, dy: Float) {
            let s: Float = distance * 0.08
            let right = SIMD3<Float>(cos(yaw), 0, -sin(yaw))
            let fwd = SIMD3<Float>(sin(yaw), 0, cos(yaw))
            target += (dx * right + dy * fwd) * s
        }

        func keyPanUp() { panTarget(dx: 0, dy: 1) }
        func keyPanDown() { panTarget(dx: 0, dy: -1) }
        func keyPanLeft() { panTarget(dx: -1, dy: 0) }
        func keyPanRight() { panTarget(dx: 1, dy: 0) }
        func keyZoomIn() { distance = max(40, distance * 0.9) }
        func keyZoomOut() { distance = min(1200, distance * 1.1) }
        func keyResetView() {
            yaw = -0.6
            pitch = 0.62
            distance = 340
            target = SIMD3<Float>(0, 0, 0)
        }
        #endif
    }
}

// MARK: - Demo biome sets

extension TerrainView.Coordinator {
    /// Sun-baked desert: water, sand, dunes, mesa rock, pale peaks.
    static let desertBiomes: [MTBiome] = [
        MTBiome(name: "deepWater", minHeight: 0.00, maxHeight: 0.36,
                groundColor: SIMD3<Float>(0.04, 0.12, 0.30)),
        MTBiome(name: "shallowWater", minHeight: 0.36, maxHeight: 0.44,
                groundColor: SIMD3<Float>(0.08, 0.28, 0.50)),
        MTBiome(name: "sand", minHeight: 0.44, maxHeight: 0.60,
                groundColor: SIMD3<Float>(0.84, 0.68, 0.42)),
        MTBiome(name: "dunes", minHeight: 0.60, maxHeight: 0.76,
                groundColor: SIMD3<Float>(0.76, 0.57, 0.33)),
        MTBiome(name: "mesaRock", minHeight: 0.76, maxHeight: 0.88,
                groundColor: SIMD3<Float>(0.58, 0.38, 0.24),
                slopeColor: SIMD3<Float>(0.42, 0.27, 0.17)),
        MTBiome(name: "palePeak", minHeight: 0.88, maxHeight: 1.00,
                groundColor: SIMD3<Float>(0.90, 0.84, 0.70)),
    ]

    /// Alien world: dark seas, fungal plains, glowing crystal fields.
    static let alienBiomes: [MTBiome] = [
        MTBiome(name: "voidOcean", minHeight: 0.00, maxHeight: 0.38,
                groundColor: SIMD3<Float>(0.03, 0.02, 0.12)),
        MTBiome(name: "acidSea", minHeight: 0.38, maxHeight: 0.45,
                groundColor: SIMD3<Float>(0.10, 0.50, 0.30)),
        MTBiome(name: "fungusField", minHeight: 0.45, maxHeight: 0.60,
                groundColor: SIMD3<Float>(0.38, 0.14, 0.55)),
        MTBiome(name: "crystal", minHeight: 0.60, maxHeight: 0.76,
                groundColor: SIMD3<Float>(0.16, 0.62, 0.72),
                emitsLight: true),
        MTBiome(name: "voidRock", minHeight: 0.76, maxHeight: 0.88,
                groundColor: SIMD3<Float>(0.22, 0.07, 0.32),
                slopeColor: SIMD3<Float>(0.10, 0.03, 0.16)),
        MTBiome(name: "starCap", minHeight: 0.88, maxHeight: 1.00,
                groundColor: SIMD3<Float>(0.92, 0.96, 1.00),
                emitsLight: true),
    ]
}
