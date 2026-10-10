#version 430 compatibility

uniform sampler2D lightmap;

uniform float alphaTestRef = 0.1;

in vec2 lmcoord;
in vec4 glcolor;

/* RENDERTARGETS: 7,8,9 */
layout(location = 0) out vec4 color;
layout(location = 1) out uvec4 materialOut0;
layout(location = 2) out uvec4 materialOut1;

void main() {
	color = glcolor * texture(lightmap, lmcoord);
	if (color.a < alphaTestRef) {
		discard;
	}
	materialOut0 = uvec4(0u);
	materialOut1 = uvec4(0u);
}
