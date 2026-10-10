#ifndef INCLUDE_RAYTRACING
    #define INCLUDE_RAYTRACING

    #include "/include/octree.glsl"

    RayHitInfo TraceGenericRay (in Ray ray, float tMin, float tMax, bool useBackFaceCulling, bool alphaBlend)
    {   
        #include "/include/rtfunc.glsl"
    }

      vec3 TraceShadowRay (in Ray ray, float tMin, float tMax, bool useBackFaceCulling)
    {   
        #define RT_SHADOW
        #include "/include/rtfunc.glsl"
        #undef RT_SHADOW
    }
    
#endif