// MTShaders.metal — ORIGINAL shaders for the MetalTerrain library.
//
// Terrain, water, and instanced-structure shaders sharing one vertex format
// (position/normal/color float3) and one lighting model: directional NdotL +
// ambient, with exponential distance fog. Metal 3 baseline; no Metal 4-only
// shading-language features are used, so the same source compiles on both.

#include <metal_stdlib>
using namespace metal;

// Must match MTVertex in MTMeshBuilder.swift (36 bytes).
struct MTVertexIn {
    float3 position;
    float3 normal;
    float3 color;
};

// Must match MTUniforms in MTTerrainRenderer.swift (192 bytes).
struct MTUniforms {
    float4x4 viewProj;
    float4x4 model;
    float3 cameraPos;
    float _pad0;
    float3 fogColor;
    float fogDensity;
    float3 lightDir;
    float ambient;
    float time;
    float3 _pad1;
};

// Must match MTInstanceData in MTTerrainRenderer.swift (80 bytes).
struct MTInstanceData {
    float4x4 model;
    float3 tint;
    float pad;
};

struct MTVaryings {
    float4 clipPos [[position]];
    float3 worldPos;
    float3 normal;
    float3 color;
};

// Shared vertex transform: model matrix, then view-projection.
vertex MTVaryings terrain_vertex(const device MTVertexIn *vertices [[buffer(0)]],
                                 constant MTUniforms &uniforms [[buffer(1)]],
                                 uint vid [[vertex_id]]) {
    MTVertexIn v = vertices[vid];
    float4 world = uniforms.model * float4(v.position, 1.0);
    MTVaryings out;
    out.clipPos = uniforms.viewProj * world;
    out.worldPos = world.xyz;
    out.normal = (uniforms.model * float4(v.normal, 0.0)).xyz;
    out.color = v.color;
    return out;
}

// Directional NdotL + ambient, then exponential distance fog.
float3 applyLighting(float3 albedo,
                     float3 normal,
                     float3 worldPos,
                     constant MTUniforms &uniforms) {
    float3 n = normalize(normal);
    float ndl = max(dot(n, uniforms.lightDir), 0.0);
    float3 lit = albedo * (uniforms.ambient + ndl * (1.0 - uniforms.ambient));
    float dist = distance(worldPos, uniforms.cameraPos);
    float f = 1.0 - exp(-uniforms.fogDensity * uniforms.fogDensity * dist * dist);
    return mix(lit, uniforms.fogColor, clamp(f, 0.0, 1.0));
}

fragment float4 terrain_fragment(MTVaryings in [[stage_in]],
                                 constant MTUniforms &uniforms [[buffer(1)]]) {
    float3 col = applyLighting(in.color, in.normal, in.worldPos, uniforms);
    return float4(col, 1.0);
}

// Water reuses terrain_vertex; adds alpha and a subtle animated ripple.
fragment float4 water_fragment(MTVaryings in [[stage_in]],
                               constant MTUniforms &uniforms [[buffer(1)]],
                               constant float &alpha [[buffer(2)]]) {
    float3 ripple = float3(0.03 * sin(uniforms.time * 1.7 + in.worldPos.x * 0.35),
                           0.0,
                           0.03 * cos(uniforms.time * 1.3 + in.worldPos.z * 0.31));
    float3 n = normalize(in.normal + ripple);
    float3 col = applyLighting(in.color, n, in.worldPos, uniforms);
    return float4(col, alpha);
}

// Structures: per-instance model matrix + color tint from the instance buffer.
vertex MTVaryings structure_vertex(const device MTVertexIn *vertices [[buffer(0)]],
                                   constant MTUniforms &uniforms [[buffer(1)]],
                                   const device MTInstanceData *instances [[buffer(2)]],
                                   uint vid [[vertex_id]],
                                   uint iid [[instance_id]]) {
    MTVertexIn v = vertices[vid];
    MTInstanceData inst = instances[iid];
    float4 world = inst.model * float4(v.position, 1.0);
    MTVaryings out;
    out.clipPos = uniforms.viewProj * world;
    out.worldPos = world.xyz;
    out.normal = (inst.model * float4(v.normal, 0.0)).xyz;
    out.color = v.color * inst.tint;
    return out;
}

fragment float4 structure_fragment(MTVaryings in [[stage_in]],
                                   constant MTUniforms &uniforms [[buffer(1)]]) {
    float3 col = applyLighting(in.color, in.normal, in.worldPos, uniforms);
    return float4(col, 1.0);
}
