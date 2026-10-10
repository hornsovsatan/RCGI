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
    radianceLayout.entries[gl_GlobalInvocationID.x] = RCVoxel(0u, 0u, 0u, 0u);
}