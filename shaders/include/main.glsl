#ifndef INCLUDE_MAIN
    #define INCLUDE_MAIN
    
    struct DeferredMaterial
    {
        vec3 albedo;
        vec3 geoNormal;
        vec3 textureNormal;
        vec3 F0;
        float roughness;
        float emission;
        uint blockId;
        bool isHand;
    };

    struct RayHitInfo 
    {
        vec4 albedo;
        vec4 specularData;
        vec3 normal;
        vec3 F0;
        float roughness;
        float emission;
        float dist;
        uint blockId;
        bool hit;
    };

    struct RCVoxel
    {
        uint packedPos;
        uint normal;
        uint radiance;
        uint hitDist;
    };

    struct Ray 
    {
        vec3 origin;
        vec3 direction;
    };

    struct Voxel
    {
        uint packedPos;
        uint data;
    };

    struct PackedTriangle
    {
        uvec4 a, b, c;
    };

    struct BVHTriangle
    {
        vec3 pos; 
        vec3 tangent; 
        vec3 bitangent; 
        vec2 uv0; 
        vec2 uv1; 
        vec2 uv2; 
        uint textureIndex; 
        uint next; 
        uint blockId;
        vec3 color; 
        bool isQuad; 
        bool doBackFaceCulling;
        bool isTranslucent;
    };

    struct TextureKey 
    {
        uint hash;
        uint bounds;
    };

    layout (std430, binding = 0) buffer all_triangles 
    {
        uint last;
        PackedTriangle list[];
    } allTriangles;

    layout (std430, binding = 1) buffer all_textures 
    {
        uint atlasHash;
        uint last;
        TextureKey keys[1024];
        uint data[];
    } allTextures;

    layout (std430, binding = 2) buffer radiance_layout 
    {
        RCVoxel entries[];
    } radianceLayout;

    layout (std430, binding = 3) buffer voxel_buffer
    {
        Voxel voxels[];
    } voxelBuffer;

    layout (std430, binding = 4) buffer render_state
    {
        uint probeCount[8];
    } renderState;

    layout (r8ui) uniform uimage3D voxelBufferLod;

    uint addVoxel (ivec3 voxel, uint data)
    {
        uint packedPos = packPosition(voxel);
        uint hashedPos = hashPosition(voxel);

        if (data > END_MARKER || packedPos == 0u) return END_MARKER;

        for (uint attempt = 0u; attempt < VOXEL_PROBE_ATTEMPTS; attempt++)
        {   
            uint index = (hashedPos + attempt * attempt) % VOXEL_ARRAY_SIZE;
            uint state = atomicCompSwap(voxelBuffer.voxels[index].packedPos, 0u, packedPos);

            if (state == 0u || state == packedPos) {
                return atomicExchange(voxelBuffer.voxels[index].data, data);
            }
        }

        return END_MARKER;
    }

    uint getVoxel (ivec3 voxel)
    {
        uint packedPos = packPosition(voxel);
        uint hashedPos = hashPosition(voxel);

        if (packedPos == 0u) return END_MARKER;

        for (uint attempt = 0u; attempt < VOXEL_PROBE_ATTEMPTS; attempt++)
        {   
            uint index = (hashedPos + attempt * attempt) % VOXEL_ARRAY_SIZE;
            uint pos = voxelBuffer.voxels[index].packedPos;

            if (pos == packedPos) {
                return voxelBuffer.voxels[index].data;
            } else if (pos == 0u) break;
        }

        return END_MARKER;
    }

    DeferredMaterial unpackMaterialData (ivec2 texel)
    {
        uvec3 data = uvec3(texelFetch(colortex8, texel, 0).rg, texelFetch(colortex9, texel, 0).r);

        vec4 albedo = unpackUnorm4x8(data.x);
        vec4 specularData = unpackUnorm4x8(data.y).gbra;
        #ifdef NORMAL_MAPPING
            vec4 normalData = unpackExp4x8(data.z);
        #else
            vec4 normalData = unpackExp4x8(data.z).zwzw;
        #endif
        
        DeferredMaterial result;

        result.F0 = vec3(0.0);
        result.roughness = 0.0;
        result.emission = 0.0;

        result.albedo = pow(albedo.rgb, vec3(2.2));
        result.geoNormal = octDecode(normalData.xy);
        result.textureNormal = octDecode(normalData.zw);

        applySpecularMap(specularData, result.albedo.rgb, result.F0, result.roughness, result.emission);

        result.blockId = (data.x >> 24u) | ((data.y & 127u) << 8u);
        result.isHand = (data.y & 0x00000080u) == 0x00000080u;

        return result;
    }

    uvec4 packMaterialData (vec3 albedo, vec3 geoNormal, vec3 textureNormal, vec4 specularData, uint blockId, bool isHand)
    {
        uvec4 pack;

        pack.x = packUnorm4x8(vec4(albedo, 0.0)) | ((blockId & 255u) << 24u);
        pack.y = packUnorm4x8(vec4(0.0, specularData.rga)) | ((blockId >> 8u) & 127u) | (uint(isHand) << 7u);
        #ifdef NORMAL_MAPPING
            pack.z = packExp4x8(vec4(octEncode(geoNormal), octEncode(textureNormal)));
        #else
            pack.z = packExp4x8(vec4(0.0, 0.0, octEncode(geoNormal).xy));
        #endif
        pack.w = 0u;

        return pack;
    }

    PackedTriangle packTriangle (BVHTriangle tri)
    {
        PackedTriangle pack;

        pack.a.xyz = floatBitsToUint(tri.pos) & 0xffffff00u;
        pack.b.xyz = floatBitsToUint(tri.tangent) & 0xffffff00u;
        pack.c.xyz = floatBitsToUint(tri.bitangent) & 0xffffff00u;

        pack.a.w = pack2x16(tri.uv0);
        pack.b.w = pack2x16(tri.uv1);
        pack.c.w = pack2x16(tri.uv2);

        pack.a.xyz |= uvec3(saturate(tri.color) * 63.0);

        pack.a.x |= (uint(tri.isQuad) << 6u) | (uint(tri.doBackFaceCulling) << 7u);
        pack.a.y |= (tri.textureIndex >> 4u) & 192u;
        pack.a.z |= (tri.textureIndex >> 2u) & 192u;
        pack.b.x |= tri.textureIndex & 255u;
        pack.b.y |= ((tri.blockId >> 8u) & 127u) | (uint(tri.isTranslucent) << 7u);
        pack.b.z |= tri.blockId & 255u;
        pack.c.x |= (tri.next >> 16u) & 255u;
        pack.c.y |= (tri.next >> 8u) & 255u;
        pack.c.z |= tri.next & 255u;

        return pack;
    }

    BVHTriangle unpackTriangle (PackedTriangle pack)
    {    
        BVHTriangle unpack;

        unpack.pos = uintBitsToFloat(pack.a.xyz & 0xffffff00u);
        unpack.tangent = uintBitsToFloat(pack.b.xyz & 0xffffff00u);
        unpack.bitangent = uintBitsToFloat(pack.c.xyz & 0xffffff00u);

        unpack.uv0 = unpack2x16(pack.a.w);
        unpack.uv1 = unpack2x16(pack.b.w);
        unpack.uv2 = unpack2x16(pack.c.w);

        unpack.textureIndex = ((pack.a.y & 192u) << 4u) | ((pack.a.z & 192u) << 2u) | (pack.b.x & 255u);
        unpack.blockId = ((pack.b.y & 127u) << 8u) | (pack.b.z & 255u);

        unpack.next = ((pack.c.x & 255u) << 16u) | ((pack.c.y & 255u) << 8u) | (pack.c.z & 255u);
        
        unpack.color = vec3(pack.a.xyz & 63u) / 63.0;

        unpack.isQuad = (pack.a.x & 64u) == 64u;
        unpack.doBackFaceCulling = (pack.a.x & 128u) == 128u;
        unpack.isTranslucent = (pack.b.y & 128u) == 128u;

        return unpack;
    }

    #define miss(maxDist) RayHitInfo(vec4(1.0), vec4(0.0), vec3(0.0), vec3(0.0), 0.0, 0.0, maxDist, 0u, false)

#endif