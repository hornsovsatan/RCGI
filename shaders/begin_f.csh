#version 430 compatibility

#include "/include/uniforms.glsl"
#include "/include/config.glsl"
#include "/include/constants.glsl"
#include "/include/common.glsl"
#include "/include/atmosphere.glsl"

layout (local_size_x = 8, local_size_y = 8) in;
const ivec3 workGroups = ivec3(4, 4, 1); // 32 x 32

layout (rgba32f) uniform image2D multiScatterImg;

void main ()
{
    ivec2 p = ivec2(gl_GlobalInvocationID.xy);
    vec2 uv = (vec2(p) + 0.5) / MSLUT_RES;
    float muS = uvToUnit(uv.x, MSLUT_RES) * 2.0 - 1.0;
    float r = clamp(R_GROUND + uvToUnit(uv.y, MSLUT_RES) * (R_TOP - R_GROUND), R_GROUND + 1e-3, R_TOP - 1e-3);

    vec3 ro = vec3(0.0, r, 0.0);
    vec3 sunD = vec3(sqrt(max(1.0 - muS * muS, 0.0)), muS, 0.0);

    vec4 Lsum = vec4(0.0), fSum = vec4(0.0);

    for (int k = 0; k < ATMOS_MS_DIRECTIONS; k++) {
        float z = 1.0 - 2.0 * (float(k) + 0.5) / float(ATMOS_MS_DIRECTIONS); // bola Fibonacci
        float phi = float(k) * 2.39996323;
        vec3 rd = vec3(sqrt(1.0 - z * z) * cos(phi), z, sqrt(1.0 - z * z) * sin(phi));

        bool ground = rayHitsGround(r, rd.y);
        float tMax = ground ? distToBottom(r, rd.y) : distToTop(r, rd.y);
        float dt = tMax / float(ATMOS_MS_STEPS);

        vec4 L = vec4(0.0), f = vec4(0.0), T = vec4(1.0);
        for (int i = 0; i < ATMOS_MS_STEPS; i++) {
            vec3 pos = ro + rd * ((float(i) + 0.5) * dt);
            float rr = length(pos);
            vec4 sMol, sAer, ext;
            atmosCoeffs(rr - R_GROUND, sMol, sAer, ext);
            vec4 scat  = sMol + sAer;
            vec4 stepT = exp(-ext * dt);
            vec4 integ = (vec4(1.0) - stepT) / max(ext, vec4(1e-9));

            L += T * scat * transmittanceToSun(rr, dot(pos / rr, sunD)) * (1.0 / (4.0 * PI)) * integ;
            f += T * scat * integ;
            T *= stepT;
        }

        if (ground) {
            vec3 n = normalize(ro + rd * tMax);
            L += T * transmittanceToSun(R_GROUND, dot(n, sunD)) * saturate(dot(n, sunD)) * ATMOS_GROUND_ALBEDO / PI;
        }

        Lsum += L;
        fSum += f;
    }

    Lsum /= float(ATMOS_MS_DIRECTIONS);
    fSum /= float(ATMOS_MS_DIRECTIONS);

    imageStore(multiScatterImg, p, Lsum / max(vec4(1.0) - fSum, vec4(1e-4))); // Psi_ms = L2 / (1 - f_ms)
}
