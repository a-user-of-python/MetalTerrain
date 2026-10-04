// MTConfig.swift
// MetalTerrain — top-level terrain configuration.

import Foundation

/// All tweakables for a terrain world. Matches DESIGN.md exactly.
public struct MTTerrainConfig {
    public var chunkResolution: Int   // vertices per chunk side, default 64
    public var chunkWorldSize: Float  // world units, default 128
    public var viewDistance: Int      // chunk radius around camera, default 6
    public var seaLevel: Float        // normalized 0...1, default 0.45
    public var heightScale: Float     // world units at height=1, default 60
    public var biomes: [MTBiome]      // default MTBiome.default
    public var noise: MTNoiseConfig
    public var structureNoise: MTNoiseConfig
    public var structuresEnabled: Bool    // default true
    public var structureDensity: Float    // 0...1, default 0.35
    public var waterColor: SIMD3<Float>   // linear RGB
    public var fogColor: SIMD3<Float>      // linear RGB
    public var fogDensity: Float

    public init(
        chunkResolution: Int = 64,
        chunkWorldSize: Float = 128,
        viewDistance: Int = 6,
        seaLevel: Float = 0.45,
        heightScale: Float = 60,
        biomes: [MTBiome] = MTBiome.default,
        noise: MTNoiseConfig = MTNoiseConfig(),
        structureNoise: MTNoiseConfig = MTNoiseConfig(
            seed: 90210, octaves: 3, baseFrequency: 0.004,
            amplitude: 1.0, lacunarity: 2.03, gain: 0.5,
            warpStrength: 0.0, warpFrequency: 0.02, ridged: false),
        structuresEnabled: Bool = true,
        structureDensity: Float = 0.35,
        waterColor: SIMD3<Float> = SIMD3<Float>(0.10, 0.35, 0.62),
        fogColor: SIMD3<Float> = SIMD3<Float>(0.62, 0.74, 0.86),
        fogDensity: Float = 0.0028
    ) {
        self.chunkResolution = chunkResolution
        self.chunkWorldSize = chunkWorldSize
        self.viewDistance = viewDistance
        self.seaLevel = seaLevel
        self.heightScale = heightScale
        self.biomes = biomes
        self.noise = noise
        self.structureNoise = structureNoise
        self.structuresEnabled = structuresEnabled
        self.structureDensity = structureDensity
        self.waterColor = waterColor
        self.fogColor = fogColor
        self.fogDensity = fogDensity
    }

    /// Sensible defaults for every field.
    public static var `default`: MTTerrainConfig {
        MTTerrainConfig()
    }
}
