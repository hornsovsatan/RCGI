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

layout(location = 0) out vec4 color;

void main() {
	color = texelFetch(colortex7, ivec2(gl_FragCoord.xy), 0);
		color.rgb *= EXPOSURE;
	color.rgb = (color.rgb * (2.51 * color.rgb + 0.03)) / (color.rgb * (2.43 * color.rgb + 0.59) + 0.14);
	color.rgb = pow(saturate(color.rgb), vec3(1.0 / 2.2));
	
	//vec4 rayDir = gbufferModelViewInverse * gbufferProjectionInverse * vec4(texcoord * 2.0 - 1.0, 1.0, 1.0);
	//rayDir.xyz /= rayDir.w;

	//float dist = TraceGenericRay(Ray(vec3(0.0), normalize(rayDir.xyz)), 0.0, 128.0, true, true).albedo.r;

	//color.rgb = magmaQuintic(dist);

	#ifdef DEBUG_VIEW
		#define FONT_SIZE 1 // [1 2 3 4 5 6 7 8]
		
		beginText(ivec2(gl_FragCoord.xy / FONT_SIZE), ivec2(20, viewHeight / FONT_SIZE - 20));
		text.fgCol = vec4(vec3(1.0), 1.0);
		text.bgCol = vec4(vec3(0.0), 0.0);
		
		if (!hideGUI) {
			for (int i = 0; i < 8; i++) {
				printChar(_c);
				printInt(i);
				printString((_space, _p, _r, _o, _b, _e, _space, _c, _o, _u, _n, _t, _colon, _space));
				printUnsignedInt(renderState.probeCount[i]);
				printLine();
			}
			/*
				printLine();

				for (int i = 0; i < 8; i++) {
					printChar(_c);
					printInt(i);
					printString((_space, _i, _n, _t, _e, _r, _v, _a, _l, _space, _s, _i, _z, _e, _colon, _space));
					printVec2(vec2(exp2(float(i) + log2(RC_INTERVAL_SIZE) - 1.0), exp2(float(i) + log2(RC_INTERVAL_SIZE) + i * RC_INTERVAL_OVERLAP)));
					printLine();
				}
			*/
		}
		
		endText(color.rgb);
	#endif
}