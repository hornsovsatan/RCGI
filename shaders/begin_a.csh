#version 430 compatibility

#include "/include/uniforms.glsl"
#include "/include/config.glsl"
#include "/include/constants.glsl"
#include "/include/common.glsl"
#include "/include/pbr.glsl"
#include "/include/main.glsl"

layout (local_size_x = 64) in;

const ivec3 workGroups = ivec3(16, 1, 1); // 16 x 64 = 1024 key

void main ()
{   
    allTextures.keys[gl_GlobalInvocationID.x].hash = 0u;
}