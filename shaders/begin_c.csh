#version 430 compatibility

#include "/include/uniforms.glsl"
#include "/include/config.glsl"
#include "/include/constants.glsl"
#include "/include/common.glsl"
#include "/include/pbr.glsl"
#include "/include/main.glsl"

layout (local_size_x = 64) in;

#if VOXEL_ARRAY_SIZE == 65536
    const ivec3 workGroups = ivec3(1024, 1, 1);
#elif VOXEL_ARRAY_SIZE == 1048576
    const ivec3 workGroups = ivec3(16384, 1, 1);
#elif VOXEL_ARRAY_SIZE == 2097152
    const ivec3 workGroups = ivec3(32768, 1, 1);
#elif VOXEL_ARRAY_SIZE == 4194304
    const ivec3 workGroups = ivec3(65536, 1, 1);
#elif VOXEL_ARRAY_SIZE == 8388608
    const ivec3 workGroups = ivec3(131072, 1, 1);
#else
    const ivec3 workGroups = ivec3(262144, 1, 1);
#endif

void main ()
{   
    if (gl_GlobalInvocationID.x >= uint(VOXEL_ARRAY_SIZE)) return;
    voxelBuffer.voxels[gl_GlobalInvocationID.x] = Voxel(0u, END_MARKER);
}
