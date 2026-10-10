#version 430 compatibility

uniform sampler2D gtexture;

uniform float alphaTestRef = 0.1;

in vec2 texcoord;
in vec4 glcolor;

/* RENDERTARGETS: 7,8,9 */
layout(location = 0) out vec4 color;
layout(location = 1) out uvec4 materialOut0;
layout(location = 2) out uvec4 materialOut1;

void main() {
	color = texture(gtexture, texcoord) * glcolor;
	if (color.a < alphaTestRef) {
		discard;
	}
	materialOut0 = uvec4(0u);
	materialOut1 = uvec4(0u);
}
