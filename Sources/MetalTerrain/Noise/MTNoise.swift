// MTNoise.swift
// MetalTerrain — fractal noise composition: fbm, ridged multifractal,
// and domain-warped height sampling.
//
// Original implementations. `MTNoiseConfig` carries every knob;
// the free functions `fbm`, `ridged`, and `height` are pure functions
// of (config, x, y).

import Foundation

// MARK: - Noise configuration

/// All tunables for the terrain noise field. Matches DESIGN.md exactly.
public struct MTNoiseConfig {
    public var seed: UInt64
    public var octaves: Int          // 1...12, default 5
    public var baseFrequency: Double // default 0.008
    public var amplitude: Double     // default 1.0
    public var lacunarity: Double    // default 2.03
    public var gain: Double          // default 0.5
    public var warpStrength: Double  // default 0.35 (0 = off)
    public var warpFrequency: Double // default 0.02
    public var ridged: Bool          // default false (mountain mode)

    public init(seed: UInt64 = 1337, octaves: Int = 5,
                baseFrequency: Double = 0.004, amplitude: Double = 1.0,
                lacunarity: Double = 2.03, gain: Double = 0.42,
                warpStrength: Double = 0.25, warpFrequency: Double = 0.015,
                ridged: Bool = false) {
        self.seed = seed
        self.octaves = octaves
        self.baseFrequency = baseFrequency
        self.amplitude = amplitude
        self.lacunarity = lacunarity
        self.gain = gain
        self.warpStrength = warpStrength
        self.warpFrequency = warpFrequency
        self.ridged = ridged
    }
}

// MARK: - Public free functions

/// Fractal Brownian motion: layered gradient noise, amplitude-normalized
/// to roughly [-1, 1]. Pure function of (config, x, y).
public func fbm(_ config: MTNoiseConfig, x: Double, y: Double) -> Double {
    let noise = MTPerlinNoise(seed: config.seed)
    return mtFBMSum(config: config,
                    nx: x * config.baseFrequency,
                    ny: y * config.baseFrequency,
                    noise: noise)
}

/// Labeled-`field` alias of `fbm(_:x:y:)`.
public func fbm(field config: MTNoiseConfig, x: Double, y: Double) -> Double {
    fbm(config, x: x, y: y)
}

/// Ridged multifractal: `(1 - |n|)^2` per octave, normalized to [0, 1].
/// Produces sharp mountain ridges. Pure function of (config, x, y).
public func ridged(_ config: MTNoiseConfig, x: Double, y: Double) -> Double {
    let noise = MTPerlinNoise(seed: config.seed)
    return mtRidgedSum(config: config,
                       nx: x * config.baseFrequency,
                       ny: y * config.baseFrequency,
                       noise: noise)
}

/// Domain-warped terrain height in [0, 1].
///
/// The sample point is first warped by a low-octave fbm vector field
/// (`warpStrength == 0` disables warping), then evaluated with fbm or
/// ridged per `config.ridged`, and finally mapped via `0.5 + 0.5 * v`.
/// Pure function of (config, x, y).
public func height(x: Double, y: Double, config: MTNoiseConfig) -> Float {
    let noise = MTPerlinNoise(seed: config.seed)
    let warpNoise = MTPerlinNoise(seed: config.seed ^ 0x9E3779B97F4A7C15)
    return mtHeightSample(x: x, y: y, config: config,
                          noise: noise, warpNoise: warpNoise)
}

// MARK: - Internal sampling core (pre-built noise fields)

/// Octave count clamped to the supported 1...12 range.
func mtClampedOctaves(_ config: MTNoiseConfig) -> Int {
    max(1, min(12, config.octaves))
}

/// Raw fbm octave sum over already frequency-scaled coords,
/// normalized by total amplitude (roughly [-1, 1]).
func mtFBMSum(config: MTNoiseConfig, nx: Double, ny: Double,
              noise: MTPerlinNoise) -> Double {
    var sum = 0.0
    var amp = config.amplitude
    var freq = 1.0
    var norm = 0.0
    for _ in 0..<mtClampedOctaves(config) {
        sum += amp * noise.noise(x: nx * freq, y: ny * freq)
        norm += amp
        amp *= config.gain
        freq *= config.lacunarity
    }
    return norm > 0 ? sum / norm : 0
}

/// Ridged octave sum over already frequency-scaled coords,
/// normalized by total amplitude ([0, 1]).
func mtRidgedSum(config: MTNoiseConfig, nx: Double, ny: Double,
                 noise: MTPerlinNoise) -> Double {
    var sum = 0.0
    var amp = config.amplitude
    var freq = 1.0
    var norm = 0.0
    for _ in 0..<mtClampedOctaves(config) {
        let n = noise.noise(x: nx * freq, y: ny * freq)
        let r = 1.0 - abs(n)
        sum += amp * r * r
        norm += amp
        amp *= config.gain
        freq *= config.lacunarity
    }
    return norm > 0 ? sum / norm : 0
}

/// fbm mapped to [0, 1] — used for structure density / kind fields.
func mtFBM01(config: MTNoiseConfig, x: Double, y: Double,
             noise: MTPerlinNoise) -> Double {
    let v = mtFBMSum(config: config,
                     nx: x * config.baseFrequency,
                     ny: y * config.baseFrequency,
                     noise: noise)
    return min(max(0.5 + 0.5 * v, 0.0), 1.0)
}

/// Full height pipeline with pre-built noise fields (fast path for
/// chunk generation: build the tables once, sample many points).
func mtHeightSample(x: Double, y: Double, config: MTNoiseConfig,
                    noise: MTPerlinNoise, warpNoise: MTPerlinNoise) -> Float {
    var nx = x * config.baseFrequency
    var ny = y * config.baseFrequency

    if config.warpStrength > 0 {
        // Domain warp: sample a low-octave fbm vector field in noise
        // space and offset the lookup point by it. The warp field is
        // sampled at warpFrequency (relative to baseFrequency).
        var warpConfig = config
        warpConfig.octaves = 3
        warpConfig.amplitude = 1.0
        warpConfig.ridged = false
        let wScale = config.baseFrequency != 0
            ? config.warpFrequency / config.baseFrequency : 1.0
        let wx = mtFBMSum(config: warpConfig,
                          nx: nx * wScale + 5.2, ny: ny * wScale + 1.3,
                          noise: warpNoise)
        let wy = mtFBMSum(config: warpConfig,
                          nx: nx * wScale - 1.7, ny: ny * wScale + 9.2,
                          noise: warpNoise)
        nx += config.warpStrength * wx
        ny += config.warpStrength * wy
    }

    let v: Double
    if config.ridged {
        v = mtRidgedSum(config: config, nx: nx, ny: ny, noise: noise)
    } else {
        v = mtFBMSum(config: config, nx: nx, ny: ny, noise: noise)
    }
    return Float(min(max(0.5 + 0.5 * v, 0.0), 1.0))
}
