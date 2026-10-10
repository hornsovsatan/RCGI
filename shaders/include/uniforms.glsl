#ifndef INCLUDE_UNIFORMS
    #define INCLUDE_UNIFORMS

    uniform sampler3D noisetex;

	uniform sampler3D shadowcolor1;
    uniform sampler2D shadowcolor0;

    uniform usampler2D colortex9; 
    uniform usampler2D colortex8;

    uniform sampler2D shadowtex1;
    uniform sampler2D shadowtex0;
    
    uniform sampler2D colortex13;
    uniform sampler2D colortex12;
    uniform sampler2D colortex11;
    uniform sampler2D colortex10;
    uniform sampler2D colortex7;
    uniform sampler2D colortex6;
    uniform sampler2D colortex5;
    uniform sampler2D colortex4;
    uniform sampler2D colortex3;
    uniform sampler2D colortex2;
    uniform sampler2D colortex1;
    uniform sampler2D colortex0;
    uniform sampler2D depthtex1;
    uniform sampler2D depthtex0;

    uniform sampler2D gtexture;
    uniform sampler2D specular;
    uniform sampler2D normals;

    uniform mat4 gbufferProjectionInverse;
    uniform mat4 gbufferModelViewInverse;
    uniform mat4 shadowModelViewInverse;
    uniform mat4 gbufferProjection;
    uniform mat4 gbufferModelView;

    uniform vec3 cameraPositionFract;
    uniform vec3 playerLookVector;
    uniform vec3 cameraVelocity;
    uniform vec3 cameraPosition;
    uniform vec3 voxelOffset;
    uniform vec3 shadowDir;
    uniform vec3 skyColor;
    uniform vec3 fogColor;
    uniform vec3 moonDir;
    uniform vec3 sunDir;
    uniform vec3 sunPosition;          // view-space, bawaan Iris
    uniform vec3 moonPosition;
    uniform vec3 shadowLightPosition;  // matahari di siang hari, bulan di malam hari
    uniform sampler2D skySampler;      // sky LUT dari begin_e.csh
    

    uniform vec2 taaOffsetPrev;
    uniform vec2 renderSize;
    uniform vec2 taaOffset;
    uniform vec2 texelSize;

    uniform float centerDepthSmooth;
    uniform float lightBrightness;
    uniform float rainStrength;
    uniform float eyeAltitude;
    uniform float aspectRatio;
    uniform float viewHeight;
    uniform float frameRate;
    uniform float viewWidth;

    uniform ivec3 previousCameraPositionInt;
    uniform ivec3 cameraPositionInt;

    uniform ivec2 atlasSize;

    uniform int currentRenderedItemId;
    uniform int blockEntityId;
    uniform int frameCounter;
    uniform int renderStage;
    uniform int entityId;

    uniform bool hideGUI;

    #define gbufferPreviousModelViewProjection mat4(gbufferPreviousModelViewProjection0, gbufferPreviousModelViewProjection1, gbufferPreviousModelViewProjection2, gbufferPreviousModelViewProjection3)
    #define gbufferModelViewProjectionInverse mat4(gbufferModelViewProjectionInverse0, gbufferModelViewProjectionInverse1, gbufferModelViewProjectionInverse2, gbufferModelViewProjectionInverse3)
    #define gbufferModelViewProjection mat4(gbufferModelViewProjection0, gbufferModelViewProjection1, gbufferModelViewProjection2, gbufferModelViewProjection3)

    #define gbufferPreviousModelViewProjection3x4 mat3x4(gbufferPreviousModelViewProjection0, gbufferPreviousModelViewProjection1, gbufferPreviousModelViewProjection2)
    #define gbufferModelViewProjectionInverse3x4 mat3x4(gbufferModelViewProjectionInverse0, gbufferModelViewProjectionInverse1, gbufferModelViewProjectionInverse2)
    #define gbufferModelViewProjection3x4 mat3x4(gbufferModelViewProjection0, gbufferModelViewProjection1, gbufferModelViewProjection2)

    #define gbufferModelViewProjection3x2 mat3x2(gbufferModelViewProjection0.zw, gbufferModelViewProjection1.zw, gbufferModelViewProjection2.zw)

#endif