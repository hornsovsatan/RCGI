#ifndef INCLUDE_RADIANCE
    #define INCLUDE_RADIANCE

    uint packRCPosition (ivec4 pos) 
    {
        pos &= ivec4(511, 511, 511, 31);
        return (pos.x << 23) | (pos.y << 14) | (pos.z << 5) | (pos.w);
    }

    ivec4 unpackRCPosition (uint pack)
    {
        ivec4 result = ivec4(pack >> 23, pack >> 14, pack >> 5, pack) & ivec4(511, 511, 511, 31);
        return ((result - ivec4((cameraPositionInt >> max(0, result.w - 5)) << max(0, 5 - result.w), 0) + ivec4(256, 256, 256, 0)) & ivec4(511, 511, 511, 31)) + ivec4((cameraPositionInt >> max(0, result.w - 5)) << max(0, 5 - result.w), 0) - ivec4(256, 256, 256, 0);
    }

    uint hashRCPosition (ivec4 pos)
    {
        return (uint(pos.x) * 0xfc8dab43u) ^ (uint(pos.y) * 0xbbde26afu) ^ (uint(pos.z) * 0xfb14ca22u) ^ (uint(pos.w) * 0x74dc9abeu);
    }

    vec3 decodePosition (uint pos)
    {
        ivec4 voxel = unpackRCPosition(pos);

        return ((voxel.xyz << voxel.w) - (cameraPositionInt << 5)) / 32.0 - cameraPositionFract + exp2(voxel.w -6.0);
    }

    void addProbe (vec3 playerPos, vec3 normal, int lod)
    {   
        ivec4 voxelPos = ivec4(((cameraPositionInt >> max(0, lod - 5)) << max(0, 5 - lod)) + ivec3(floor(exp2(5.0 - lod) * (vec3(cameraPositionInt & ((1u << max(0, int(lod) - 5)) - 1u)) + cameraPositionFract + playerPos) + normal * 0.7)), lod);

        for (int layer = 0; layer < RC_LAYER_COUNT; layer++, voxelPos.xyz >>= 1, voxelPos.w += 1) {
            uint packedPos = packRCPosition(voxelPos);
            uint hashedPos = hashRCPosition(voxelPos & ivec4(511, 511, 511, 31));

            if (packedPos == 0u) continue;

            for (uint attempt = 0u; attempt < RC_PROBE_ATTEMPTS; attempt++)
            {   
                uint index = (((hashedPos + attempt * attempt) % (RC_VOXEL_ARRAY_SIZE >> (2 * layer + 5))) << (2 * layer + 5)) + layer * RC_VOXEL_ARRAY_SIZE;
                uint state = atomicCompSwap(radianceLayout.entries[index].packedPos, 0u, packedPos);

                if (state == 0u || state == packedPos) {
                    if (state == 0u) atomicAdd(renderState.probeCount[layer], 1u);
    
                    break;
                }
            }
        }
    }

    vec3 getProbe (vec3 playerPos, vec3 normal, vec3 textureNormal, int lod)
    {
        vec3 voxelPos =exp2(5.0 - lod) * (vec3(cameraPositionInt & ((1u << max(0, int(lod) - 5)) - 1u)) + cameraPositionFract + playerPos) + normal * 0.7 - 0.5;

        float weightSum = 0.00001;
        vec3 radiance = vec3(0.0);

        for (int i = 0; i < 8; i++) {
            ivec3 offset = ivec3(i >> 2, i >> 1, i) & 1;
            ivec4 cascadePos = ivec4(((cameraPositionInt >> max(0, lod - 5)) << max(0, 5 - lod)) + ivec3(floor(voxelPos)), lod) + ivec4(offset, 0);

            uint packedPos = packRCPosition(cascadePos);
            uint hashedPos = hashRCPosition(cascadePos & ivec4(511, 511, 511, 31));

            if (packedPos == 0u) continue;

            for (uint attempt = 0u; attempt < RC_PROBE_ATTEMPTS; attempt++)
            {   
                uint index = (((hashedPos + attempt * attempt) % (RC_VOXEL_ARRAY_SIZE >> 5)) << 5);

                if (radianceLayout.entries[index].packedPos == packedPos) {
                    vec3 r = vec3(0.0);
                    
                    for (int i = 0; i < 32; i++) {
                        vec2 angle = vec2((i & 7) / 8.0 + 1.0 / 16.0, (i >> 3) * 0.5 - 0.75);
                        float cosTheta = dot(textureNormal, vec3(sqrt(1.0 - angle.y * angle.y) * vec2(cos(angle.x * TWO_PI), sin(angle.x * TWO_PI)), angle.y).xzy);

                        if (cosTheta > 0.0) r += cosTheta * unpackRGB11F(radianceLayout.entries[index + i].radiance);
                    }

                    float sampleWeight = (1.0 - abs(voxelPos.x - floor(voxelPos.x + offset.x))) 
                                         * (1.0 - abs(voxelPos.y - floor(voxelPos.y + offset.y))) 
                                         * (1.0 - abs(voxelPos.z - floor(voxelPos.z + offset.z)));

                    weightSum += sampleWeight;
                    radiance += sampleWeight * r;                    

                    break;
                }
            }
        }
        
        return radiance / weightSum;
    }

#endif