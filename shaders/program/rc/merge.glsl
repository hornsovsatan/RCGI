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

layout (local_size_x = 64) in;
#if RC_VOXEL_ARRAY_SIZE == 524288
    const ivec3 workGroups = ivec3(8192, 1, 1);
#elif RC_VOXEL_ARRAY_SIZE == 786432
    const ivec3 workGroups = ivec3(12288, 1, 1);
#elif RC_VOXEL_ARRAY_SIZE == 1048576
    const ivec3 workGroups = ivec3(16384, 1, 1);
#elif RC_VOXEL_ARRAY_SIZE == 1572864
    const ivec3 workGroups = ivec3(24576, 1, 1);
#elif RC_VOXEL_ARRAY_SIZE == 2097152
    const ivec3 workGroups = ivec3(32768, 1, 1);
#elif RC_VOXEL_ARRAY_SIZE == 3145728
    const ivec3 workGroups = ivec3(49152, 1, 1);
#elif RC_VOXEL_ARRAY_SIZE == 4194304
    const ivec3 workGroups = ivec3(65536, 1, 1);
#endif

void main ()
{   
    uint selfIndex = gl_GlobalInvocationID.x + MERGE_PASS * RC_VOXEL_ARRAY_SIZE;
    RCVoxel voxel = radianceLayout.entries[selfIndex];

    if (voxel.packedPos == 0u) return;

    vec2 dist = unpackHalf2x16(voxel.hitDist);
    vec3 ownRadiance = unpackRGB11F(voxel.radiance);
    float minParentDist = 256.0;

    uint interval = 4u * (gl_GlobalInvocationID.x & ((1u << (2u * MERGE_PASS + 5u)) - 1u));
    ivec4 pos = unpackRCPosition(voxel.packedPos);
    ivec3 offset = pos.xyz & 1;
    vec3 radiance = vec3(0.0);
    float weightSum = 0.0;

    for (int x = 0; x < 8; x++) {
        ivec3 corner = ivec3(x >> 2, x >> 1, x) & 1;
        ivec4 cascadePos = ivec4(pos.xyz >> 1, pos.w + 1) + ivec4(offset - 1 + corner, 0);
        vec3 weight = vec3(corner ^ offset) * 0.5 + 0.25; // selalu positif: 0.75 atau 0.25

        uint packedPos = packRCPosition(cascadePos);
        uint hashedPos = hashRCPosition(cascadePos & ivec4(511, 511, 511, 31));

        if (packedPos == 0u) continue;

        for (uint attempt = 0u; attempt < RC_PROBE_ATTEMPTS; attempt++)
        {   
            uint index = (((hashedPos + attempt * attempt) % (RC_VOXEL_ARRAY_SIZE >> (2u * MERGE_PASS + 7u))) << (2u * MERGE_PASS + 7u)) + (MERGE_PASS + 1u) * RC_VOXEL_ARRAY_SIZE + interval;

            if (radianceLayout.entries[index].packedPos == packedPos) {
                float sampleWeight = weight.x * weight.y * weight.z * 0.25;

                for (uint i = 0u; i < 4u; i++) {
                    float parentDist = unpackHalf2x16(radianceLayout.entries[index + i].hitDist).x;

                    if (parentDist <= dist.x) {
                        radiance += sampleWeight * unpackRGB11F(radianceLayout.entries[index + i].radiance);
                        minParentDist = min(minParentDist, parentDist);
                    } else {
                        radiance += sampleWeight * ownRadiance;
                    }

                    weightSum += sampleWeight; // bobot sama untuk kedua cabang
                }

                break;
            }
        }
    }

    // Kalau tidak ada parent sama sekali, pakai radiance sendiri (jangan jadi hitam)
    vec3 result = weightSum > 0.0 ? radiance / weightSum : ownRadiance;

    radianceLayout.entries[selfIndex].radiance = packRGB11F(result);
    radianceLayout.entries[selfIndex].hitDist = packHalf2x16(vec2(min(dist.x, minParentDist), dist.y));
}
