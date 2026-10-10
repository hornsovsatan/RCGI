#ifndef INCLUDE_ATMOSPHERE
    #define INCLUDE_ATMOSPHERE

    // =====================================================================
    //  Langit RCGI
    //  - Struktur LUT  : Hillaire 2020 (port dari Revelation, Apache-2.0,
    //                    dicek terhadap sebh/UnrealEngineSkyAtmosphere)
    //  - LUT transmittance : parameterisasi Bruneton 2017
    //  - Spektral 4 sampel + data atmosfer : Fernando Garcia Linan (MIT),
    //    Rayleigh Bucholtz 1995, ozon Gorshelev 2014, aerosol Guimera 2018
    //  - Limb darkening : Hestroffer & Magnan 1998, Tabel 2
    //  SEMUA JARAK DALAM KILOMETER. Sampel: 630, 560, 490, 430 nm
    // =====================================================================

    const float R_GROUND = 6371.0;
    const float R_TOP    = 6471.0;
    const float H_ATMOS  = sqrt(R_TOP * R_TOP - R_GROUND * R_GROUND);

    const float TLUT_W = 256.0, TLUT_H = 64.0, MSLUT_RES = 32.0;
    const int   SKYVIEW_W = 512, SKYVIEW_H = 256;

    const vec4  SUN_SPECTRAL_IRRADIANCE = vec4(1.679, 1.828, 1.986, 1.307);          // W m^-2 nm^-1
    const vec4  MOLECULAR_SCATTERING    = vec4(6.605e-3, 1.067e-2, 1.842e-2, 3.156e-2); // km^-1
    const vec4  OZONE_CROSS_SECTION     = vec4(3.472e-25, 3.914e-25, 1.349e-25, 11.03e-27);
    const float OZONE_MEAN_DOBSON       = 334.5;
    const vec4  AEROSOL_ABS_CS          = vec4(2.8722e-24, 4.6168e-24, 7.9706e-24, 1.3578e-23);
    const vec4  AEROSOL_SCA_CS          = vec4(1.5908e-22, 1.7711e-22, 2.0942e-22, 2.4033e-22);
    const float AEROSOL_BASE_DENSITY    = 1.3681e20;
    const float AEROSOL_BG_DENSITY      = 2e6;
    const float AEROSOL_HEIGHT          = 0.73;
    const float AEROSOL_G               = 0.8;

    const vec4  LIMB_ALPHA   = vec4(0.429, 0.502, 0.575, 0.643); // Hestroffer & Magnan, Tabel 2
    const float sunAngularRadius  = 0.004653;  // 0.2666 derajat
    const float moonAngularRadius = 0.004521;
    const vec4  LUNAR_ALBEDO = vec4(0.135, 0.125, 0.110, 0.095); // perkiraan (albedo geometrik)

    // Spektral -> XYZ (fgarlin) -> sRGB linear
    const mat4x3 SPECTRAL_TO_XYZ = mat4x3(
        53.386917738564668, 22.981337506691025, 0.0,
        43.904844466369358, 71.347795700053394, 0.102506867965741,
        1.6137278251608962, 18.422960591455485, 31.742921188390806,
        20.762668673810577, 2.3614213523314369, 110.48009643252140);
    const mat3 XYZ_TO_SRGB = mat3(
         3.2404542, -0.9692660,  0.0556434,
        -1.5371385,  1.8760108, -0.2040259,
        -0.4985314,  0.0415560,  1.0572252);

    vec3 spectralToRgbRaw (vec4 L)  { return XYZ_TO_SRGB * (SPECTRAL_TO_XYZ * L); }
    vec3 spectralToRgb (vec4 L)     { return max(spectralToRgbRaw(L), 0.0) * ATMOS_UNIT_SCALE; }
    vec3 transmittanceToRgb (vec4 T){ return saturate(max(spectralToRgbRaw(T), 0.0) / spectralToRgbRaw(vec4(1.0))); }

    // ---------- arah cahaya ----------
    vec3 getSunDir ()   { return normalize(mat3(gbufferModelViewInverse) * sunPosition); }
    vec3 getMoonDir ()  { return normalize(mat3(gbufferModelViewInverse) * moonPosition); }
    vec3 getLightDir () { return normalize(mat3(gbufferModelViewInverse) * shadowLightPosition); }

    float viewRadius ()
    {
        return R_GROUND + ATMOS_BASE_ALTITUDE * 1e-3 + max(cameraPosition.y - 63.0, 0.0) * 1e-3 * ATMOS_HEIGHT_SCALE;
    }

    // ---------- geometri (Bruneton) ----------
    float safeSqrt (float x) { return sqrt(max(x, 0.0)); }
    float distToTop (float r, float mu)    { return max(-r * mu + safeSqrt(r * r * (mu * mu - 1.0) + R_TOP * R_TOP), 0.0); }
    float distToBottom (float r, float mu) { return max(-r * mu - safeSqrt(r * r * (mu * mu - 1.0) + R_GROUND * R_GROUND), 0.0); }
    bool  rayHitsGround (float r, float mu){ return mu < 0.0 && r * r * (mu * mu - 1.0) + R_GROUND * R_GROUND >= 0.0; }
    float unitToUv (float x, float n) { return 0.5 / n + x * (1.0 - 1.0 / n); }
    float uvToUnit (float u, float n) { return (u - 0.5 / n) / (1.0 - 1.0 / n); }

    // Bilinear manual (tidak bergantung filter image Iris)
    vec4 texBilinear (sampler2D s, vec2 uv, ivec2 size)
    {
        vec2 st = uv * vec2(size) - 0.5;
        ivec2 i = ivec2(floor(st));
        vec2 f = st - vec2(i);
        ivec2 i0 = clamp(i, ivec2(0), size - 1);
        ivec2 i1 = clamp(i + 1, ivec2(0), size - 1);
        return mix(mix(texelFetch(s, i0, 0),               texelFetch(s, ivec2(i1.x, i0.y), 0), f.x),
                   mix(texelFetch(s, ivec2(i0.x, i1.y), 0), texelFetch(s, i1, 0),               f.x), f.y);
    }

    // ---------- medium (fgarlin / Guimera) ----------
    void atmosCoeffs (float h, out vec4 scaMol, out vec4 scaAer, out vec4 ext)
    {
        h = max(h, 0.0);
        scaMol = MOLECULAR_SCATTERING * exp(-0.07771971 * pow(h, 1.16364243)) * AIR_DENSITY;

        float logh  = log(max(h, 1e-4));
        float ozone = 3.78547397e20 * exp(-sqr(logh - 3.22261) * 5.55555555 - logh);
        vec4 absMol = OZONE_CROSS_SECTION * OZONE_MEAN_DOBSON * ozone * OZONE_DENSITY;

        float aer = AEROSOL_BASE_DENSITY * (exp(-h / AEROSOL_HEIGHT) + AEROSOL_BG_DENSITY / AEROSOL_BASE_DENSITY) * AEROSOL_DENSITY;
        scaAer = AEROSOL_SCA_CS * aer;
        ext = scaMol + absMol + scaAer + AEROSOL_ABS_CS * aer;
    }

    float phaseRayleigh (float mu) { return 3.0 / (16.0 * PI) * (1.0 + mu * mu); }
    float phaseHG (float mu, float g)
    {
        float g2 = g * g;
        return (1.0 - g2) / (4.0 * PI * pow(max(1.0 + g2 - 2.0 * g * mu, 1e-5), 1.5));
    }

    // ---------- LUT transmittance (parameterisasi Bruneton) ----------
    vec2 transmittanceUv (float r, float mu)
    {
        float rho  = safeSqrt(r * r - R_GROUND * R_GROUND);
        float d    = distToTop(r, mu);
        float dMin = R_TOP - r;
        float dMax = rho + H_ATMOS;
        return vec2(unitToUv((d - dMin) / (dMax - dMin), TLUT_W), unitToUv(rho / H_ATMOS, TLUT_H));
    }

    void transmittanceRMu (vec2 uv, out float r, out float mu)
    {
        float xMu = uvToUnit(uv.x, TLUT_W);
        float rho = H_ATMOS * uvToUnit(uv.y, TLUT_H);
        r = sqrt(rho * rho + R_GROUND * R_GROUND);
        float dMin = R_TOP - r;
        float d = dMin + xMu * (rho + H_ATMOS - dMin);
        mu = d == 0.0 ? 1.0 : (H_ATMOS * H_ATMOS - rho * rho - d * d) / (2.0 * r * d);
        mu = clamp(mu, -1.0, 1.0);
    }

    vec4 transmittanceToTop (float r, float mu)
    {
        r = clamp(r, R_GROUND, R_TOP);
        return texBilinear(transmittanceSampler, transmittanceUv(r, mu), ivec2(256, 64));
    }

    // Transisi halus saat matahari melewati horizon (Bruneton)
    vec4 transmittanceToSun (float r, float muS)
    {
        float sinH = R_GROUND / max(r, R_GROUND);
        float cosH = -safeSqrt(1.0 - sinH * sinH);
        return transmittanceToTop(r, muS) * smoothstep(-sinH * sunAngularRadius, sinH * sunAngularRadius, muS - cosH);
    }

    // ---------- LUT multiscattering (Hillaire) ----------
    vec4 multiScattering (float r, float muS)
    {
        vec2 uv = vec2(unitToUv(saturate(muS * 0.5 + 0.5), MSLUT_RES),
                       unitToUv(saturate((r - R_GROUND) / (R_TOP - R_GROUND)), MSLUT_RES));
        return texBilinear(multiScatterSampler, uv, ivec2(32));
    }

    // ---------- bulan ----------
    float lambertPhase (float a) { return (sin(a) + (PI - a) * cos(a)) / PI; }

    vec4 moonIrradiance ()
    {
        float a = float(moonPhase) * PI * 0.25; // 0 = purnama
        float omega = TWO_PI * 2.0 * sqr(sin(0.5 * moonAngularRadius));
        return SUN_SPECTRAL_IRRADIANCE * LUNAR_ALBEDO * (omega / PI) * lambertPhase(a) * MOON_BRIGHTNESS;
    }

    // ---------- integrasi hamburan (matahari + bulan) ----------
    vec4 integrateScattering (vec3 ro, vec3 rd, float tMax, int steps, vec3 sunD, vec3 moonD, vec4 moonE, out vec4 transmittance)
    {
        float cS = dot(rd, sunD), cM = dot(rd, moonD);
        float pRs = phaseRayleigh(cS), pAs = phaseHG(cS, AEROSOL_G);
        float pRm = phaseRayleigh(cM), pAm = phaseHG(cM, AEROSOL_G);

        vec4 L = vec4(0.0), T = vec4(1.0);

        for (int i = 0; i < steps; i++) {
            float t0 = tMax * sqr(float(i) / float(steps));
            float t1 = tMax * sqr(float(i + 1) / float(steps));
            float dt = t1 - t0;
            vec3 p = ro + rd * (0.5 * (t0 + t1));
            float r = length(p);
            vec3 up = p / r;

            vec4 sMol, sAer, ext;
            atmosCoeffs(r - R_GROUND, sMol, sAer, ext);

            float muS = dot(up, sunD), muM = dot(up, moonD);
            vec4 S = SUN_SPECTRAL_IRRADIANCE * (transmittanceToSun(r, muS) * (sMol * pRs + sAer * pAs) + (sMol + sAer) * multiScattering(r, muS))
                   + moonE                   * (transmittanceToSun(r, muM) * (sMol * pRm + sAer * pAm) + (sMol + sAer) * multiScattering(r, muM));

            vec4 stepT = exp(-ext * dt);
            L += T * (S - S * stepT) / max(ext, vec4(1e-9)); // integrasi energy-conserving
            T *= stepT;
        }

        transmittance = T;
        return L;
    }

    // ---------- langit malam (Tahap 1: sederhana) ----------
    // Unit tabel: 1e-8 W m^-2 sr^-1 um^-1 @500 nm (= 1e-11 per nm).
    // NILAI PERKIRAAN: ganti dengan Tabel 16 Leinert et al. 1998 di Tahap 2.
    const float ZODI_ELONG[8] = float[8](30.0, 45.0, 60.0, 75.0, 90.0, 120.0, 150.0, 180.0);
    const float ZODI_TABLE[32] = float[32](
    //   b=0     b=30   b=60   b=90
        2450.0, 870.0, 260.0, 77.0,  // e=30
        1260.0, 580.0, 210.0, 77.0,  // e=45
         760.0, 410.0, 180.0, 77.0,  // e=60
         490.0, 310.0, 160.0, 77.0,  // e=75
         340.0, 240.0, 140.0, 77.0,  // e=90
         210.0, 170.0, 120.0, 77.0,  // e=120
         180.0, 150.0, 110.0, 77.0,  // e=150
         250.0, 160.0, 110.0, 77.0); // e=180 (gegenschein)

    float zodiacal500 (float elong, float beta)
    {
        elong = clamp(elong, 30.0, 180.0);
        beta  = clamp(abs(beta), 0.0, 90.0);
        int i = 0;
        for (int k = 1; k < 7; k++) if (elong >= ZODI_ELONG[k]) i = k;
        float fe = saturate((elong - ZODI_ELONG[i]) / (ZODI_ELONG[i + 1] - ZODI_ELONG[i]));
        float bj = beta / 30.0;
        int j = min(int(bj), 2);
        float fb = bj - float(j);
        float v0 = mix(ZODI_TABLE[i * 4 + j],       ZODI_TABLE[i * 4 + j + 1],       fb);
        float v1 = mix(ZODI_TABLE[(i + 1) * 4 + j], ZODI_TABLE[(i + 1) * 4 + j + 1], fb);
        return mix(v0, v1, fe);
    }

    const vec4  AIRGLOW_SPECTRUM = vec4(0.60, 1.00, 0.35, 0.30); // perkiraan, Tahap 2: dari data Zenodo
    const float STARLIGHT_MEAN   = 40.0;                          // perkiraan, Tahap 2: dari peta Gaia

    vec3 celestialAxis (vec3 sunD) // sumbu lintasan matahari Minecraft (= "ekliptika")
    {
        vec3 A = vec3(0.0, sin(radians(sunPathRotation)), cos(radians(sunPathRotation)));
        return normalize(A - sunD * dot(A, sunD));
    }

    vec4 nightSkyRadiance (vec3 rd, vec3 sunD)
    {
        float beta  = degrees(asin(clamp(dot(rd, celestialAxis(sunD)), -1.0, 1.0)));
        float elong = degrees(acos(clamp(dot(rd, sunD), -1.0, 1.0)));
        vec4 solar  = SUN_SPECTRAL_IRRADIANCE / 1.95;

        float k = R_GROUND / (R_GROUND + AIRGLOW_HEIGHT);
        float vanRhijn = inversesqrt(1.0 - k * k * (1.0 - sqr(max(rd.y, 0.0))));

        vec4 zodi = zodiacal500(elong, beta) * 1e-11 * solar;
        vec4 star = STARLIGHT_MEAN * 1e-11 * solar;
        vec4 glow = AIRGLOW_ZENITH * 1e-11 * AIRGLOW_SPECTRUM * vanRhijn;
        return (zodi + star + glow) * NIGHT_SKY_BRIGHTNESS;
    }

    // ---------- LUT sky-view ----------
    vec2 skyViewEncode (vec3 d)
    {
        float lat = asin(clamp(d.y, -1.0, 1.0));
        return vec2(atan(d.z, d.x) / TWO_PI + 0.5, 0.5 + 0.5 * sign(lat) * sqrt(abs(lat) / HALF_PI));
    }

    vec3 skyViewDecode (vec2 uv)
    {
        float az = (uv.x - 0.5) * TWO_PI;
        float s = uv.y * 2.0 - 1.0;
        float lat = sign(s) * s * s * HALF_PI;
        return vec3(cos(lat) * cos(az), sin(lat), cos(lat) * sin(az));
    }

    // Mahal: hanya dipanggil di begin_g.csh
    vec3 skyRadianceRaw (vec3 rd)
    {
        float r = viewRadius();
        vec3 ro = vec3(0.0, r, 0.0);
        bool ground = rayHitsGround(r, rd.y);
        float tMax = ground ? distToBottom(r, rd.y) : distToTop(r, rd.y);

        vec3 sunD = getSunDir(), moonD = getMoonDir();
        vec4 moonE = moonIrradiance();
        vec4 T;
        vec4 L = integrateScattering(ro, rd, tMax, ATMOS_SKY_STEPS, sunD, moonD, moonE, T);

        if (ground) {
            vec3 n = normalize(ro + rd * tMax);
            vec4 E = SUN_SPECTRAL_IRRADIANCE * transmittanceToSun(R_GROUND, dot(n, sunD))  * saturate(dot(n, sunD))
                   + moonE                   * transmittanceToSun(R_GROUND, dot(n, moonD)) * saturate(dot(n, moonD));
            L += T * E * ATMOS_GROUND_ALBEDO / PI;
        } else {
            L += T * nightSkyRadiance(rd, sunD);
        }
        return spectralToRgb(L);
    }

    // Murah: baca LUT (bilinear dengan wrap horizontal, tanpa garis sambungan)
    vec3 skyRadiance (vec3 dir)
    {
        vec2 st = skyViewEncode(dir) * vec2(SKYVIEW_W, SKYVIEW_H) - 0.5;
        ivec2 i = ivec2(floor(st));
        vec2 f = st - vec2(i);
        int x0 = ((i.x % SKYVIEW_W) + SKYVIEW_W) % SKYVIEW_W;
        int x1 = (x0 + 1) % SKYVIEW_W;
        int y0 = clamp(i.y, 0, SKYVIEW_H - 1), y1 = clamp(i.y + 1, 0, SKYVIEW_H - 1);
        vec3 a = texelFetch(skyViewSampler, ivec2(x0, y0), 0).rgb;
        vec3 b = texelFetch(skyViewSampler, ivec2(x1, y0), 0).rgb;
        vec3 c = texelFetch(skyViewSampler, ivec2(x0, y1), 0).rgb;
        vec3 d = texelFetch(skyViewSampler, ivec2(x1, y1), 0).rgb;
        return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
    }

    // Cahaya matahari/bulan di permukaan (sudah dibagi PI, cocok dengan directLight)
    vec3 getLightColor ()
    {
        vec3 L = getLightDir();
        vec4 E = dot(L, getSunDir()) > 0.0 ? SUN_SPECTRAL_IRRADIANCE : moonIrradiance();
        return spectralToRgb(E * transmittanceToSun(viewRadius(), L.y)) / PI;
    }

    // Aerial perspective (pengganti kabut lama)
    vec3 aerialPerspective (vec3 rd, float distBlocks, out vec3 transmitRgb)
    {
        vec4 T;
        vec4 L = integrateScattering(vec3(0.0, viewRadius(), 0.0), rd, distBlocks * 1e-3 * AERIAL_PERSPECTIVE_SCALE,
                                     AERIAL_STEPS, getSunDir(), getMoonDir(), moonIrradiance(), T);
        transmitRgb = transmittanceToRgb(T);
        return spectralToRgb(L);
    }

    // Piringan matahari (limb darkening spektral) & bulan (Lommel-Seeliger + fase)
    vec3 celestialDisks (vec3 dir)
    {
        float r = viewRadius();
        vec4 L = vec4(0.0);

        vec3 s = getSunDir();
        float Rs = sunAngularRadius * SUN_SIZE_MULT;
        if (dot(dir, s) > 0.0) {
            float ang = asin(min(length(cross(dir, s)), 1.0));
            if (ang < Rs) {
                float x = ang / Rs;
                float muD = sqrt(max(1.0 - x * x, 1e-6));
                float omega = TWO_PI * 2.0 * sqr(sin(0.5 * Rs));
                vec4 L0 = SUN_SPECTRAL_IRRADIANCE * (LIMB_ALPHA + 2.0) / (2.0 * omega); // irradiance tetap
                L += L0 * pow(vec4(muD), LIMB_ALPHA) * (1.0 - smoothstep(0.97, 1.0, x)) * transmittanceToSun(r, dir.y);
            }
        }

        vec3 m = getMoonDir();
        float Rm = moonAngularRadius * MOON_SIZE_MULT;
        if (dot(dir, m) > 0.0) {
            vec3 t1 = normalize(cross(m, abs(m.y) < 0.999 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0)));
            vec3 t2 = cross(m, t1);
            vec2 q = vec2(dot(dir, t1), dot(dir, t2)) / Rm;
            float q2 = dot(q, q);
            if (q2 < 1.0) {
                vec3 n = vec3(q, sqrt(1.0 - q2));
                float a = float(moonPhase) * PI * 0.25;
                float mu0 = max(dot(n, vec3(sin(a), 0.0, cos(a))), 0.0);
                float ls = 2.0 * mu0 / (mu0 + n.z + 1e-5);
                L += LUNAR_ALBEDO * SUN_SPECTRAL_IRRADIANCE / PI * ls * MOON_BRIGHTNESS * transmittanceToSun(r, dir.y);
            }
        }

        return min(spectralToRgb(L), vec3(60000.0)); // batas format R11F_G11F_B10F
    }

    // Auto exposure sederhana (tanpa data dari frame sebelumnya)
    float computeExposure ()
    {
        #ifdef AUTO_EXPOSURE
            float sky = luminance(skyRadiance(vec3(0.0, 1.0, 0.0)));
            for (int i = 0; i < 8; i++) {
                float a = float(i) * PI * 0.25;
                sky += luminance(skyRadiance(normalize(vec3(cos(a), 0.35, sin(a)))));
            }
            float lum = sky / 9.0 + 0.25 * luminance(getLightColor());
            return EXPOSURE * 0.35 / max(lum, AUTO_EXPOSURE_MIN);
        #else
            return EXPOSURE;
        #endif
    }

#endif
