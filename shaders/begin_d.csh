#version 430 compatibility

#include "/include/uniforms.glsl"
#include "/include/config.glsl"
#include "/include/constants.glsl"
#include "/include/common.glsl"
#include "/include/pbr.glsl"
#include "/include/main.glsl"

layout (local_size_x = 8) in;
const ivec3 workGroups = ivec3(1, 1, 1);

void main ()
{   
    renderState.probeCount[gl_GlobalInvocationID.x] = 0u;
}