#version 430 compatibility

#include "/include/uniforms.glsl"
#include "/include/config.glsl"
#include "/include/constants.glsl"
#include "/include/common.glsl"
#include "/include/pbr.glsl"
#include "/include/main.glsl"
#include "/include/raytracing.glsl"
#include "/include/text.glsl"

in vec2 texcoord;

/* RENDERTARGETS: 7 */
layout(location = 0) out vec4 color;

void main() {
	color = texelFetch(colortex7, ivec2(gl_FragCoord.xy), 0) * texelFetch(colortex1, ivec2(gl_FragCoord.xy), 0);
}