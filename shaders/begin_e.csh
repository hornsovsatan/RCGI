#version 430 compatibility

#include "/include/uniforms.glsl"
#include "/include/config.glsl"
#include "/include/constants.glsl"
#include "/include/common.glsl"
#include "/include/atmosphere.glsl"

layout (local_size_x = 8, local_size_y = 8) in;
const ivec3 workGroups = ivec3(32, 8, 1); // 256 x 64

layout (rgba32f) uniform image2D transmittanceImg;

void main ()
{
    ivec2 p = ivec2(gl_GlobalInvocationID.xy);
    float r, mu;
    transmittanceRMu((vec2(p) + 0.5) / vec2(TLUT_W, TLUT_H), r, mu);

    float dt = distToTop(r, mu) / float(ATMOS_TLUT_STEPS);
    vec4 od = vec4(0.0);
    for (int i = 0; i < ATMOS_TLUT_STEPS; i++) {
        float t = (float(i) + 0.5) * dt;
        vec4 a, b, ext;
        atmosCoeffs(sqrt(t * t + 2.0 * r * mu * t + r * r) - R_GROUND, a, b, ext);
        od += ext * dt;
    }
    imageStore(transmittanceImg, p, exp(-od));
}
