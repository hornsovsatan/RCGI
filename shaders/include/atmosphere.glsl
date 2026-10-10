#ifndef INCLUDE_ATMOSPHERE
    #define INCLUDE_ATMOSPHERE

    // Data fisik dari fgarlin/skytracer (MIT License) - atmosphere.cxx
    // Rayleigh: tabel Bucholtz 1995 @ 680/550/440 nm, Ozon: Gorshelev 2014 + profil Dutsch

    const float planetRadius     = 6371e3;
    const float atmosphereRadius = 6471e3;
    const vec3  rayleighBeta     = vec3(4.847e-6, 11.49e-6, 28.70e-6);
    const float rayleighHeight   = 8000.0;
    const float mieBetaS         = 3.996e-6 * ATMOS_TURBIDITY;
    const float mieBetaE         = 4.440e-6 * ATMOS_TURBIDITY;
    const float mieHeight        = 1200.0;
    const float mieG             = 0.8;   // Henyey-Greenstein g, sama seperti skytracer
    const vec3  ozoneBeta        = vec3(0.99e-6, 1.51e-6, 0.071e-6);

    vec3 getSunDir ()   { return normalize(mat3(gbufferModelViewInverse) * sunPosition); }
    vec3 getMoonDir ()  { return normalize(mat3(gbufferModelViewInverse) * moonPosition); }
    vec3 getLightDir () { return normalize(mat3(gbufferModelViewInverse) * shadowLightPosition); }

    vec3 atmosOrigin ()
    {
        return vec3(0.0, planetRadius + 2.0 + max(cameraPosition.y - 63.0, 0.0) * ATMOS_HEIGHT_SCALE, 0.0);
    }

    vec2 raySphere (vec3 ro, vec3 rd, float r)
    {
        float b = dot(ro, rd);
        float c = dot(ro, ro) - r * r;
        float d = b * b - c;
        if (d < 0.0) return vec2(-1.0);
        d = sqrt(d);
        return vec2(-b - d, -b + d);
    }

    // Profil ozon skytracer (per 9 km), dinormalisasi supaya puncaknya = 1
    float ozoneProfile (float h)
    {
        h *= 1e-3;
        if (h <= 9.0)  return 9.0 / 111.0;
        if (h <= 18.0) return 14.0 / 111.0;
        if (h <= 27.0) return 1.0;
        if (h <= 36.0) return 64.0 / 111.0;
        if (h <= 54.0) return 6.0 / 111.0;
        return 0.0;
    }

    vec3 atmosDensity (float h)
    {
        h = max(h, 0.0);
        return vec3(exp(-h / rayleighHeight), exp(-h / mieHeight), ozoneProfile(h));
    }

    vec3 atmosExtinction (vec3 d)
    {
        return rayleighBeta * d.x + mieBetaE * d.y + ozoneBeta * d.z;
    }

    // Transmitansi dari titik p ke arah cahaya L (dengan fade halus di horizon)
    vec3 atmosTransmittance (vec3 p, vec3 L)
    {
        float r = length(p);
        float horizonMu = -sqrt(max(1.0 - sqr(planetRadius / r), 0.0));
        float fade = smoothstep(horizonMu - 0.01, horizonMu + 0.01, dot(p / r, L));
        if (fade <= 0.0) return vec3(0.0);

        float len = raySphere(p, L, atmosphereRadius).y;
        float dt = len / float(ATMOS_LIGHT_STEPS);
        vec3 od = vec3(0.0);

        for (int i = 0; i < ATMOS_LIGHT_STEPS; i++) {
            vec3 s = p + L * ((float(i) + 0.5) * dt);
            od += atmosExtinction(atmosDensity(length(s) - planetRadius));
        }

        return exp(-od * dt) * fade;
    }

    float phaseRayleigh (float mu) { return 3.0 / (16.0 * PI) * (1.0 + mu * mu); }

    float phaseHG (float mu, float g)
    {
        float g2 = g * g;
        return (1.0 - g2) / (4.0 * PI * pow(max(1.0 + g2 - 2.0 * g * mu, 1e-4), 1.5));
    }

    // Scattering atmosfer untuk satu sumber cahaya (matahari atau bulan)
    vec3 atmosScatter (vec3 dir, vec3 L)
    {
        vec3 ro = atmosOrigin();
        float tMax = raySphere(ro, dir, atmosphereRadius).y;
        vec2 tP = raySphere(ro, dir, planetRadius);
        bool hitGround = tP.x > 0.0;
        if (hitGround) tMax = tP.x;

        float mu = dot(dir, L);
        float pR = phaseRayleigh(mu);
        float pM = phaseHG(mu, mieG);

        vec3 T = vec3(1.0);
        vec3 sum = vec3(0.0);

        for (int i = 0; i < ATMOS_VIEW_STEPS; i++) {
            // langkah kuadratik: rapat di dekat kamera, tempat kabut aerosol paling tebal
            float t0 = tMax * sqr(float(i) / float(ATMOS_VIEW_STEPS));
            float t1 = tMax * sqr(float(i + 1) / float(ATMOS_VIEW_STEPS));
            float dt = t1 - t0;
            vec3 p = ro + dir * (0.5 * (t0 + t1));

            vec3 d = atmosDensity(length(p) - planetRadius);
            vec3 ext = atmosExtinction(d);
            vec3 sunT = atmosTransmittance(p, L);

            vec3 scatR = rayleighBeta * d.x;
            vec3 scatM = vec3(mieBetaS * d.y);

            vec3 S = sunT * (scatR * pR + scatM * pM)
                   + sunT * (scatR + scatM) * (ATMOS_MULTISCATTER / (4.0 * PI)); // perkiraan multiple scattering

            vec3 stepT = exp(-ext * dt);
            sum += T * (S - S * stepT) / max(ext, vec3(1e-12)); // integrasi energy-conserving
            T *= stepT;
        }

        if (hitGround) {
            vec3 gp = ro + dir * tMax;
            sum += T * atmosTransmittance(gp, L) * max(dot(normalize(gp), L), 0.0) * ATMOS_GROUND_ALBEDO / PI;
        }

        return sum;
    }

    // Langit lengkap (mahal): hanya dipanggil di begin_e.csh
    vec3 skyRadianceRaw (vec3 dir)
    {
        return atmosScatter(dir, getSunDir()) * SUN_INTENSITY
             + atmosScatter(dir, getMoonDir()) * MOON_INTENSITY * vec3(0.85, 0.92, 1.0);
    }

    // Mapping LUT: resolusi lebih tinggi di sekitar horizon
    vec2 skyLutEncode (vec3 dir)
    {
        float u = atan(dir.z, dir.x) / TWO_PI + 0.5;
        float lat = asin(clamp(dir.y, -1.0, 1.0));
        float v = 0.5 + 0.5 * sign(lat) * sqrt(abs(lat) / HALF_PI);
        return vec2(u, v);
    }

    vec3 skyLutDecode (vec2 uv)
    {
        float az = (uv.x - 0.5) * TWO_PI;
        float s = uv.y * 2.0 - 1.0;
        float lat = sign(s) * s * s * HALF_PI;
        return vec3(cos(lat) * cos(az), sin(lat), cos(lat) * sin(az));
    }

    // Langit murah (baca dari LUT): dipakai di mana saja
    vec3 skyRadiance (vec3 dir)
    {
        return texture(skySampler, skyLutEncode(dir)).rgb;
    }

    // Warna dan kekuatan cahaya matahari/bulan setelah menembus atmosfer
    vec3 getLightColor ()
    {
        vec3 L = getLightDir();
        bool isSun = dot(L, getSunDir()) > 0.5;
        vec3 base = isSun ? vec3(SUN_INTENSITY) : MOON_INTENSITY * vec3(0.85, 0.92, 1.0);
        return base * atmosTransmittance(atmosOrigin(), L);
    }

    // Piringan matahari dan bulan yang bulat
    vec3 celestialDisks (vec3 dir)
    {
        vec3 result = vec3(0.0);
        vec3 ro = atmosOrigin();

        vec3 s = getSunDir();
        float angS = acos(clamp(dot(dir, s), -1.0, 1.0));
        if (angS < SUN_ANGULAR_RADIUS * 1.1) {
            float x = saturate(angS / SUN_ANGULAR_RADIUS);
            float mu = sqrt(max(1.0 - x * x, 0.0));
            vec3 limb = pow(vec3(max(mu, 1e-3)), vec3(0.397, 0.503, 0.652)); // limb darkening
            float edge = 1.0 - smoothstep(SUN_ANGULAR_RADIUS * 0.96, SUN_ANGULAR_RADIUS * 1.04, angS);
            result += SUN_INTENSITY * SUN_DISK_BRIGHTNESS * limb * edge * atmosTransmittance(ro, s);
        }

        vec3 m = getMoonDir();
        float angM = acos(clamp(dot(dir, m), -1.0, 1.0));
        if (angM < MOON_ANGULAR_RADIUS * 1.1) {
            float x = saturate(angM / MOON_ANGULAR_RADIUS);
            float edge = 1.0 - smoothstep(MOON_ANGULAR_RADIUS * 0.96, MOON_ANGULAR_RADIUS * 1.04, angM);
            float shade = 0.8 + 0.2 * sqrt(max(1.0 - x * x, 0.0));
            result += MOON_INTENSITY * MOON_DISK_BRIGHTNESS * shade * edge * vec3(0.9, 0.93, 1.0) * atmosTransmittance(ro, m);
        }

        return result;
    }

#endif
