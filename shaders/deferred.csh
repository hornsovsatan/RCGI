#version 430 compatibility

#include "/include/uniforms.glsl"
#include "/include/config.glsl"
#include "/include/constants.glsl"
#include "/include/common.glsl"
#include "/include/pbr.glsl"
#include "/include/main.glsl"
#include "/include/raytracing.glsl"
#include "/include/radiance.glsl"
#include "/include/text.glsl"

layout (local_size_x = 8, local_size_y = 8) in;
const vec2 workGroupsRender = vec2(1.0, 1.0);

void main () 
{
	if (any(greaterThanEqual(gl_GlobalInvocationID.xy, uvec2(viewWidth, viewHeight)))) return;

	float depth = texelFetch(depthtex1, ivec2(gl_GlobalInvocationID.xy), 0).r;
	vec4 playerPos = gbufferModelViewInverse * gbufferProjectionInverse * vec4(vec2(gl_GlobalInvocationID.xy + 0.5) / vec2(viewWidth, viewHeight) * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
	playerPos.xyz /= playerPos.w;

	DeferredMaterial mat = unpackMaterialData(ivec2(gl_GlobalInvocationID.xy));

	#ifdef RC_ADD_PROBES
		if (depth != 1.0)
	#else
		if (depth != 1.0 && !hideGUI)
	#endif
	
	addProbe(playerPos.xyz * 0.999, mat.geoNormal, int(clamp(log2(maxOf(abs(playerPos.xyz))) - log2(RC_CASCADE_RES / 128.0), 0.0, 8.0)));
}