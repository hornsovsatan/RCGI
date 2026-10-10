#include "/include/uniforms.glsl"
#include "/include/config.glsl"
#include "/include/constants.glsl"
#include "/include/common.glsl"
#include "/include/pbr.glsl"
#include "/include/main.glsl"
#include "/include/octree.glsl"
#include "/include/raytracing.glsl"
#include "/include/textureData.glsl"
#include "/include/radiance.glsl"
#include "/include/atmosphere.glsl"
#include "/include/lighting.glsl"

layout (local_size_x = 64) in;
#if RC_VOXEL_ARRAY_SIZE == 524288
    const ivec3 workGroups = ivec3(57344, 1, 1);
#elif RC_VOXEL_ARRAY_SIZE == 786432
    const ivec3 workGroups = ivec3(86016, 1, 1);
#elif RC_VOXEL_ARRAY_SIZE == 1048576
    const ivec3 workGroups = ivec3(114688, 1, 1);
#elif RC_VOXEL_ARRAY_SIZE == 1572864
    const ivec3 workGroups = ivec3(172032, 1, 1);
#elif RC_VOXEL_ARRAY_SIZE == 2097152
    const ivec3 workGroups = ivec3(229376, 1, 1);
#elif RC_VOXEL_ARRAY_SIZE == 3145728
    const ivec3 workGroups = ivec3(344064, 1, 1);
#elif RC_VOXEL_ARRAY_SIZE == 4194304
    const ivec3 workGroups = ivec3(458752, 1, 1);
#endif

void main ()
{   
    uint layer = gl_GlobalInvocationID.x / RC_VOXEL_ARRAY_SIZE;
    uint index = gl_GlobalInvocationID.x & ~((1u << (2u * layer + 5u)) - 1u);
    RCVoxel voxel = radianceLayout.entries[index];

    if (voxel.packedPos == 0u) return;

    uint interval = gl_GlobalInvocationID.x - index;
    vec2 angle = (vec2(float((interval >> (2 * layer)) & 7u), (interval >> (2 * layer + 3))) + exp2(-float(layer)) * (decodeMorton2D(interval & ((1 << (2 * layer)) - 1)) + 0.5)) * vec2(0.125, 0.25);
    angle.y = angle.y * 2.0 - 1.0;

    vec3 dir = vec3(sqrt(1.0 - angle.y * angle.y) * vec2(cos(angle.x * TWO_PI), sin(angle.x * TWO_PI)), angle.y).xzy;
    
    RayHitInfo rt = TraceGenericRay(Ray(decodePosition(voxel.packedPos) + vec3(0.001, 0.005, 0.007), dir), 
        layer == 0 ? 0.0   : exp2(float(voxel.packedPos & 31u) + layer + log2(RC_INTERVAL_SIZE) - 2.0),
        layer == uint(RC_LAYER_COUNT - 1) ? 128.0 : exp2(float(voxel.packedPos & 31u) + layer + log2(RC_INTERVAL_SIZE) + RC_INTERVAL_OVERLAP),
    true, false);

    radianceLayout.entries[gl_GlobalInvocationID.x].packedPos = voxel.packedPos;
        vec3 outRadiance = vec3(0.0);

    if (rt.hit) {
        vec3 L = getLightDir();
        vec3 hitPos = decodePosition(voxel.packedPos) + vec3(0.001, 0.005, 0.007) + dir * rt.dist;
        float NoL = max(dot(rt.normal, L), 0.0);
        vec3 sunBounce = vec3(0.0);

        if (NoL > 0.0)
            sunBounce = rt.albedo.rgb * NoL * getLightColor() * TraceShadowRay(Ray(hitPos + rt.normal * 0.01, L), 0.0, 512.0, false);

        outRadiance = rt.albedo.rgb * rt.emission + sunBounce * GI_SUN_BOUNCE;
    } else if (layer == uint(RC_LAYER_COUNT - 1)) {
        outRadiance = skyRadiance(dir) * GI_SKY_STRENGTH;
    }

    radianceLayout.entries[gl_GlobalInvocationID.x].radiance = packRGB11F(outRadiance);
    radianceLayout.entries[gl_GlobalInvocationID.x].hitDist = packHalf2x16(vec2(rt.hit ? rt.dist : 256.0, 0.0));
}