#include "/include/uniforms.glsl"
#include "/include/config.glsl"
#include "/include/constants.glsl"
#include "/include/common.glsl"
#include "/include/pbr.glsl"
#include "/include/main.glsl"
#include "/include/textureData.glsl"

#ifdef fsh

in VSOUT
{
    vec2 texcoord;
    vec3 vertexColor;

    #ifdef NORMAL_MAPPING
        vec4 vertexTangent;
    #endif

    flat uint vertexNormal;
    flat uint blockId;
} vsout;

/* RENDERTARGETS: 8,9,7 */
layout (location = 0) out uvec4 colortex8Out;
layout (location = 1) out uvec4 colortex9Out;
layout (location = 2) out vec4 colortex7Out;

void main ()
{
    if (any(greaterThan(gl_FragCoord.xy, screenSize))) discard;

    vec4 albedo = texture(gtexture, vsout.texcoord) * vec4(vsout.vertexColor, 1.0);
    vec4 specularData = textureLod(specular, vsout.texcoord, 0.0);

    vec3 geoNormal = octDecode(unpack2x16(vsout.vertexNormal));

    if (!gl_FrontFacing) geoNormal *= -1.0;

    #ifdef NORMAL_MAPPING
        vec3 textureNormal = vec3(texture(normals, vsout.texcoord).rg * 2.0 - 1.0, 1.0);
        textureNormal.xy *= step(vec2(rcp(128.0)), abs(textureNormal.xy));
        textureNormal.z = sqrt(max(0.0, 1.0 - lengthSquared(textureNormal.xy)));
        textureNormal = tbnNormalTangent(geoNormal, vsout.vertexTangent) * textureNormal;
    #else
        vec3 textureNormal = geoNormal;
    #endif

    #ifdef IPBR
        applyIntegratedSpecular(albedo.rgb, specularData, vsout.blockId);
    #endif

    uvec4 packedData = packMaterialData(albedo.rgb, geoNormal, textureNormal, specularData, vsout.blockId, 
        #ifdef STAGE_HAND
            true
        #else
            false
        #endif
    );

        colortex8Out = packedData;
    colortex9Out = packedData.zwxy;
    colortex7Out = vec4(0.0, 0.0, 0.0, 1.0); // hapus warna langit di bawah blok
    
    if (albedo.a < 0.1) discard;
}

#endif

#ifdef vsh

attribute vec2 mc_Entity;
attribute vec4 at_tangent;

out VSOUT
{
    vec2 texcoord;
    vec3 vertexColor;

    #ifdef NORMAL_MAPPING
        vec4 vertexTangent;
    #endif

    flat uint vertexNormal;
    flat uint blockId;
} vsout;

void main ()
{   
    gl_Position = ftransform();

    vsout.texcoord = mat4x2(gl_TextureMatrix[0]) * gl_MultiTexCoord0;
    vsout.vertexColor = gl_Color.rgb;
    vsout.vertexNormal = pack2x16(octEncode(alignNormal(transpose(mat3(gbufferModelView)) * gl_NormalMatrix * gl_Normal, 0.008)));

    #ifdef NORMAL_MAPPING
        vsout.vertexTangent = vec4(alignNormal(mat3(gbufferModelViewInverse) * mat3(gl_ModelViewMatrix) * at_tangent.xyz, 0.025), at_tangent.w);
    #endif

    #ifdef STAGE_TERRAIN
        vsout.blockId = uint(max(mc_Entity.x, 0.0));
    #elif defined STAGE_HAND
        vsout.blockId = uint(max(currentRenderedItemId, 0));
    #elif defined STAGE_ENTITIES
        vsout.blockId = uint(max(currentRenderedItemId == 0 ? entityId : currentRenderedItemId, 0));
    #elif defined STAGE_BLOCK_ENTITIES
        vsout.blockId = uint(max(blockEntityId, 0));
    #else
        vsout.blockId = 0u;
    #endif
}

#endif