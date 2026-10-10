#include "/include/uniforms.glsl"
#include "/include/config.glsl"
#include "/include/constants.glsl"
#include "/include/common.glsl"

#ifdef fsh

in VSOUT 
{
    vec2 texcoord;
    vec3 vertexColor;
} vsout;

/* RENDERTARGETS: 1 */
layout (location = 0) out vec4 colortex1Out;

void main ()
{
    colortex1Out = texture(gtexture, vsout.texcoord) * vec4(vsout.vertexColor, 1.0);
}

#endif

#ifdef vsh

out VSOUT 
{
    vec2 texcoord;
    vec3 vertexColor;
} vsout;

void main ()
{   
    gl_Position = ftransform();

    vsout.texcoord = mat4x2(gl_TextureMatrix[0]) * gl_MultiTexCoord0;
    vsout.vertexColor = gl_Color.rgb;

    #ifdef STAGE_WEATHER
        gl_Position = vec4(-1.0);
    #endif
}

#endif