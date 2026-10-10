#ifndef INCLUDE_CONFIG
    #define INCLUDE_CONFIG

    #define RANDOMIZE_HASH_ENTRIES
    #define USE_OCTREES
    #define TEXTURE_HASH_ENTRIES 16 // [1 2 4 8 16 24 32]
    #define TRIANGLE_ARRAY_SIZE 2097152 // [1048576 2097152 3145728 4194304 8388608 16777216]
    //#define FORCE_TRIANGLE_TRACING
    #define VOXELIZATION_DISTANCE 128 // [32 64 128 192 256 512]
    #define VOXEL_ARRAY_SIZE 8388608 // [65536 1048576 2097152 4194304 8388608 16777216]
    #define VOXEL_PROBE_ATTEMPTS 8 // [1 2 4 8 16 24 32]

    #define VOXELIZE_ENTITIES
    //#define VOXELIZE_BLOCK_ENTITIES
    #define VOXELIZE_PLAYER
    //#define VOXELIZE_ITEMS
    
    #define GLOWING_LAPIS_BLOCK
    //#define GLOWING_ARMOR_TRIMS
    #define IPBR
    #define NORMAL_MAPPING
    #define SHADOW_SOFTNESS 0.010 // [0.000 0.001 0.002 0.003 0.004 0.005 0.006 0.007 0.008 0.009 0.010]
    #define EMISSION_BRIGHTNESS 1.0 // [0.5 1.0 2.0 3.0 4.0 5.0 6.0 7.0 8.0]

    //#define DEBUG_VIEW

    #define RC_ADD_PROBES
    #define RC_LAYER_COUNT 7 // [1 2 3 4 5 6 7]
    #define RC_CASCADE_RES 128 // [32 48 64 80 96 112 128 144 160 176 192 208 224 240 256 272 288 304 320 336 352 368 384 400 416 432 448 464 480 496 512]
    #define RC_INTERVAL_SIZE 0.02 // [0.001 0.005 0.01 0.015 0.02 0.025 0.03 0.035 0.04 0.045 0.05 0.055 0.06 0.065 0.07 0.075 0.08 0.085 0.09 0.095 0.1]
    #define RC_INTERVAL_OVERLAP 2.0 // [0.0 0.25 0.5 0.75 1.0 1.25 1.5 1.75 2.0]
    #define RC_VOXEL_ARRAY_SIZE 4194304 // [524288 786432 1048576 1572864 2097152 3145728 4194304]
    #define RC_PROBE_ATTEMPTS 4 // [1 2 4 8 16]

      // ===== ATMOSPHERE =====
    #define ATMOS_BASE_ALTITUDE 250.0      // [0.0 100.0 250.0 500.0 1000.0 2000.0]
    #define ATMOS_HEIGHT_SCALE 1.0         // [1.0 5.0 10.0 50.0]
    #define AIR_DENSITY 1.0                // [0.5 0.75 1.0 1.25 1.5 2.0]
    #define AEROSOL_DENSITY 1.0            // [0.0 0.25 0.5 0.75 1.0 1.5 2.0 3.0 5.0]
    #define OZONE_DENSITY 1.0              // [0.0 0.5 1.0 1.5 2.0]
    #define ATMOS_GROUND_ALBEDO 0.3        // [0.1 0.2 0.3 0.4 0.5]
    #define ATMOS_SKY_STEPS 64             // [32 48 64 96 128 192 256]
    #define ATMOS_TLUT_STEPS 256           // [64 128 256 512]
    #define ATMOS_MS_DIRECTIONS 256        // [64 128 256 512 1024]
    #define ATMOS_MS_STEPS 32              // [16 24 32 48 64]
    #define AERIAL_STEPS 16                // [8 16 24 32]
    #define AERIAL_PERSPECTIVE_SCALE 4.0   // [0.0 1.0 2.0 4.0 8.0 16.0]
    #define SUN_SIZE_MULT 1.0              // [1.0 1.5 2.0 3.0 4.0 5.0]
    #define MOON_SIZE_MULT 1.0             // [1.0 1.5 2.0 3.0 4.0 5.0]
    #define MOON_BRIGHTNESS 1.0            // [0.5 1.0 2.0 4.0 8.0]
    #define NIGHT_SKY_BRIGHTNESS 1.0       // [0.0 0.5 1.0 2.0 4.0 8.0]
    #define AIRGLOW_ZENITH 100.0           // [0.0 50.0 100.0 150.0 200.0]
    #define AIRGLOW_HEIGHT 90.0
    #define ATMOS_UNIT_SCALE 0.1           // [0.01 0.05 0.1 0.2 0.5 1.0]
    #define AUTO_EXPOSURE
    #define AUTO_EXPOSURE_MIN 0.002        // [0.0001 0.0005 0.001 0.002 0.005 0.01 0.05]
    
    // ===== LIGHTING =====
    #define SUN_SHADOW_SAMPLES 16      // [1 4 8 16 32 64]
    #define SPECULAR_STRENGTH 1.0      // [0.0 0.5 1.0 1.5 2.0]
    #define GI_STRENGTH 0.15           // [0.05 0.1 0.15 0.2 0.3 0.5 1.0]
    #define GI_SKY_STRENGTH 1.0        // [0.0 0.5 1.0 1.5 2.0 3.0]
    #define GI_SUN_BOUNCE 1.0          // [0.0 0.5 1.0 1.5 2.0]
    #define EXPOSURE 1.0               // [0.25 0.5 0.75 1.0 1.25 1.5 2.0 3.0]
    
#endif