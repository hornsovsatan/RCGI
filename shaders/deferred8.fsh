#version 430 compatibility

#include "/include/uniforms.glsl"
#include "/include/config.glsl"
#include "/include/constants.glsl"
#include "/include/common.glsl"
#include "/include/pbr.glsl"
#include "/include/main.glsl"
#include "/include/raytracing.glsl"
#include "/include/radiance.glsl"
#include "/include/atmosphere.glsl"
#include "/include/lighting.glsl"

in vec2 texcoord;

/* RENDERTARGETS: 7 */
layout(location = 0) out vec4 color;

void main() {
	ivec2 texel = ivec2(gl_FragCoord.xy);
	color = texelFetch(colortex7, texel, 0);

	float depth = texture(depthtex1, texcoord).r;
	vec4 playerPos = gbufferModelViewInverse * gbufferProjectionInverse * vec4(texcoord * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
	playerPos.xyz /= playerPos.w;

	vec3 viewDir = normalize(playerPos.xyz);

	// ---- LANGIT ----
	if (depth == 1.0) {
		color.rgb = skyRadiance(viewDir) + celestialDisks(viewDir);
		return;
	}

	DeferredMaterial mat = unpackMaterialData(texel);

	// ---- GI (radiance cascades) ----
	int lod = int(clamp(log2(maxOf(abs(playerPos.xyz))) - log2(RC_CASCADE_RES / 128.0), 0.0, 8.0));
	vec3 indirect = mat.albedo * getProbe(playerPos.xyz, mat.geoNormal, mat.textureNormal, lod) * GI_STRENGTH;

	// ---- MATAHARI / BULAN langsung + bayangan ray-traced ----
	vec3 L = getLightDir();
	vec3 lightColor = getLightColor();
	uint seed = uint(texel.x) * 1973u + uint(texel.y) * 9277u + 26699u;

	vec3 vis = vec3(0.0);
	if (luminance(lightColor) > 1e-6)
		vis = mat.isHand ? vec3(1.0) : sunVisibility(playerPos.xyz, mat.geoNormal, L, seed);

	vec3 direct = directLight(mat, -viewDir, L, lightColor, vis);

	// ---- EMISI ----
	vec3 emissive = mat.albedo * mat.emission;

	color.rgb += indirect + direct + emissive;

	// ---- AERIAL PERSPECTIVE (fisik, spektral) ----
	vec3 apTransmit;
	vec3 apInscatter = aerialPerspective(viewDir, length(playerPos.xyz), apTransmit);
	color.rgb = color.rgb * apTransmit + apInscatter;
	