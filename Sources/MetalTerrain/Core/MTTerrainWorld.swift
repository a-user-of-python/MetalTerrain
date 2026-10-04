// MTTerrainWorld.swift
// MetalTerrain — the main entry point: seeded infinite terrain,
// biome lookup, chunk generation, and seeded structure placement.
//
// Everything here is deterministic: the same seed + config always
// produces the same heights, biomes, chunks, and structures.
// No I/O and no unseeded randomness.

import Foundation

/// Seeded infinite 3D heightmap terrain world. Matches DESIGN.md exactly.
public final class MTTerrainWorld {
    /// Live configuration (noise knobs, biomes, structure toggle, ...).
    public var config: MTTerrainConfig
    /// World seed. Height, chunk, and structure queries are pure
    /// functions of this seed plus `config`.
    public var seed: UInt64

    /// Custom biomes added via `setBiome`, in insertion order.
    /// These take precedence over `config.biomes` in `biomeAt`.
    private var customBiomes: [MTBiome] = []

    // Domain separation constants for the independent noise fields.
    private static let warpSeedXor: UInt64 = 0x9E3779B97F4A7C15
    private static let structureSeedXor: UInt64 = 0x94D049BB133111EB
    private static let kindSeedXor: UInt64 = 0xD1B54A32D192ED03
    private static let chunkSeedA: UInt64 = 0x9E3779B97F4A7C15
    private static let chunkSeedB: UInt64 = 0xBF58476D1CE4E5B9
    private static let chunkSeedC: UInt64 = 0xA24BAED4963EE407

    public init(seed: UInt64, config: MTTerrainConfig = .default) {
        self.seed = seed
        self.config = config
    }

    // MARK: - Height

    /// Normalized height in [0, 1] at world (x, z).
    /// Domain-warped fbm (or ridged, per `config.noise.ridged`).
    /// Pure function of seed + config.
    public func heightAt(x: Double, z: Double) -> Float {
        let noise = MTPerlinNoise(seed: seed)
        let warpNoise = MTPerlinNoise(seed: seed ^ Self.warpSeedXor)
        return mtHeightSample(x: x, y: z, config: config.noise,
                              noise: noise, warpNoise: warpNoise)
    }

    /// World-space Y of a normalized height.
    public func worldY(forHeight h: Float) -> Float {
        h * config.heightScale
    }

    // MARK: - Biomes

    /// Biome for a normalized height. `height` is clamped to [0, 1].
    /// Custom biomes (via `setBiome`) take precedence in insertion
    /// order; then the built-in `config.biomes` list is consulted.
    public func biomeAt(height: Float) -> MTBiome {
        let h = min(max(height, 0), 1)
        if let b = firstBiome(matching: h, inclusiveTop: false) { return b }
        if let b = firstBiome(matching: h, inclusiveTop: true) { return b }
        // Absolute fallback (e.g. empty biome lists): flat gray.
        return MTBiome(name: "void", minHeight: 0, maxHeight: 1,
                       groundColor: SIMD3<Float>(repeating: 0.5))
    }

    private func firstBiome(matching h: Float, inclusiveTop: Bool) -> MTBiome? {
        for b in customBiomes + config.biomes {
            guard h >= b.minHeight else { continue }
            if h < b.maxHeight || (inclusiveTop && h <= b.maxHeight) {
                return b
            }
        }
        return nil
    }

    /// Add a custom biome, or replace the existing custom biome with
    /// the same name. Custom biomes take precedence over built-ins.
    public func setBiome(_ biome: MTBiome) {
        if let i = customBiomes.firstIndex(where: { $0.name == biome.name }) {
            customBiomes[i] = biome
        } else {
            customBiomes.append(biome)
        }
    }

    /// Remove a custom biome by name. Built-in biomes are unaffected.
    public func removeBiome(named name: String) {
        customBiomes.removeAll(where: { $0.name == name })
    }

    /// Clear custom biomes and restore the built-in biome list.
    public func resetBiomesToDefault() {
        customBiomes.removeAll()
        config.biomes = MTBiome.default
    }

    // MARK: - Chunks

    /// Generate a chunk's heightmap. Deterministic: the same seed,
    /// config, and coord always yield the same grid.
    public func generateChunk(at coord: MTChunkCoord) -> MTChunk {
        let res = max(2, config.chunkResolution)
        let size = config.chunkWorldSize
        let x0 = Float(coord.x) * size
        let z0 = Float(coord.z) * size
        let step = size / Float(res - 1)

        // Build the noise tables once per chunk, then sample the grid.
        let noise = MTPerlinNoise(seed: seed)
        let warpNoise = MTPerlinNoise(seed: seed ^ Self.warpSeedXor)

        var heights = [Float](repeating: 0, count: res * res)
        for iz in 0..<res {
            let wz = Double(z0 + Float(iz) * step)
            for ix in 0..<res {
                let wx = Double(x0 + Float(ix) * step)
                heights[iz * res + ix] = mtHeightSample(
                    x: wx, y: wz, config: config.noise,
                    noise: noise, warpNoise: warpNoise)
            }
        }
        return MTChunk(coord: coord, heights: heights, resolution: res)
    }

    // MARK: - Structures

    /// Live structures toggle. Reads/writes `config.structuresEnabled`.
    public var structuresEnabled: Bool {
        get { config.structuresEnabled }
        set { config.structuresEnabled = newValue }
    }

    /// Structure placements for a chunk. Deterministic per (seed, coord).
    /// Returns [] when `structuresEnabled` is false.
    ///
    /// Algorithm: K candidate points from a chunk-seeded PRNG; keep a
    /// candidate when the structure-noise fbm exceeds a density-derived
    /// threshold and the terrain height is in [beachTop, 0.85]; the kind
    /// comes from a second noise field mapped over the 7 kinds, and
    /// rotation/scale come from the PRNG.
    public func structures(in coord: MTChunkCoord) -> [MTStructurePlacement] {
        guard structuresEnabled else { return [] }

        let size = Double(config.chunkWorldSize)
        let x0 = Double(coord.x) * size
        let z0 = Double(coord.z) * size

        var rng = MTSeededRandom(seed: chunkSeed(for: coord))
        let densityNoise = MTPerlinNoise(seed: seed ^ Self.structureSeedXor)
        let kindNoise = MTPerlinNoise(
            seed: (seed ^ Self.structureSeedXor) ^ Self.kindSeedXor)

        // Higher density -> lower keep threshold -> more structures.
        let threshold = 1.0 - Double(config.structureDensity)
        let beachTop: Float =
            config.biomes.first(where: { $0.name == "beach" })?.maxHeight
            ?? (config.seaLevel + 0.04)

        var out: [MTStructurePlacement] = []
        let candidateCount = 12
        for _ in 0..<candidateCount {
            let px = x0 + rng.nextDouble() * size
            let pz = z0 + rng.nextDouble() * size

            let density = mtFBM01(config: config.structureNoise,
                                  x: px, y: pz, noise: densityNoise)
            guard density > threshold else { continue }

            let h = heightAt(x: px, z: pz)
            guard h >= beachTop && h <= 0.85 else { continue }

            let t = mtFBM01(config: config.structureNoise,
                            x: px + 173.3, y: pz - 91.7, noise: kindNoise)
            let kinds = MTStructureKind.allCases
            let kindIndex = min(Int(t * Double(kinds.count)), kinds.count - 1)

            out.append(MTStructurePlacement(
                kind: kinds[kindIndex],
                position: SIMD3<Float>(Float(px), worldY(forHeight: h), Float(pz)),
                rotationY: Float(rng.nextDouble() * Double.pi * 2.0),
                scale: Float(0.8 + rng.nextDouble() * 0.6)))
        }
        return out
    }

    /// Deterministic per-chunk seed mixing the world seed with the coord.
    private func chunkSeed(for coord: MTChunkCoord) -> UInt64 {
        let cx = UInt64(bitPattern: Int64(coord.x))
        let cz = UInt64(bitPattern: Int64(coord.z))
        return seed
            ^ (cx &* Self.chunkSeedA)
            ^ (cz &* Self.chunkSeedB)
            ^ Self.chunkSeedC
    }
}
