#ifdef RAY_MARCH_VAR
#else
#define RAY_MARCH_VAR

    struct Ray {
        float3 origin;
        float3 dir;
    };

    sampler2D _CameraDepthTexture;
#endif