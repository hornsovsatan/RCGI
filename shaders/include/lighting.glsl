#ifndef INCLUDE_LIGHTING
    #define INCLUDE_LIGHTING

    float D_GGX (float NoH, float a)
    {
        float a2 = a * a;
        float d = NoH * NoH * (a2 - 1.0) + 1.0;
        return a2 / (PI * d * d);
    }

    float V_SmithGGX (float NoV, float NoL, float a)
    {
        float a2 = a * a;
        float gv = NoL * sqrt(NoV * NoV * (1.0 - a2) + a2);
        float gl = NoV * sqrt(NoL * NoL * (1.0 - a2) + a2);
        return 0.5 / max(gv + gl, 1e-5);
    }

    vec3 F_Schlick (vec3 f0, float VoH)
    {
        return f0 + (1.0 - f0) * pow(1.0 - VoH, 5.0);
    }

    // Bayangan lembut ray-traced: beberapa ray ke piringan matahari
    vec3 sunVisibility (vec3 playerPos, vec3 geoNormal, vec3 L, uint seed)
    {
        if (dot(geoNormal, L) <= 0.0) return vec3(0.0);

        vec3 origin = playerPos + geoNormal * 0.01;
        vec3 vis = vec3(0.0);

        for (int i = 0; i < SUN_SHADOW_SAMPLES; i++) {
            vec2 xi = vec2(randomValue(seed), randomValue(seed));
            vec3 d = normalize(sampleSunDir(L, xi));
            vis += TraceShadowRay(Ray(origin, d), 0.0, 512.0, false);
        }

        return vis / float(SUN_SHADOW_SAMPLES);
    }

    // Diffuse + specular GGX dari matahari/bulan
    vec3 directLight (DeferredMaterial mat, vec3 V, vec3 L, vec3 lightColor, vec3 visibility)
    {
        vec3 N = mat.textureNormal;
        float NoL = max(dot(N, L), 0.0);
        if (NoL <= 0.0) return vec3(0.0);

        vec3 H = normalize(V + L);
        float NoV = max(dot(N, V), 1e-4);
        float NoH = max(dot(N, H), 0.0);
        float VoH = max(dot(V, H), 0.0);
        float a = max(mat.roughness, 0.02);

        vec3 F = F_Schlick(mat.F0, VoH);
        vec3 spec = D_GGX(NoH, a) * V_SmithGGX(NoV, NoL, a) * F * PI; // *PI agar sejalan dengan diffuse tanpa 1/PI
        vec3 diff = mat.albedo * (1.0 - F);

        return (diff + spec * SPECULAR_STRENGTH) * NoL * lightColor * visibility;
    }

#endif
