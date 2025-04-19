Shader "Hidden/Cloud"
{
    //    Properties
    //    {
    //        _ShapeTex("Shape Texture", 3D) = "white" {}
    //        _DetailTex("Detail Texture", 3D) = "white" {}
    //        _WeatherTex("Weather Map", 2D) = "white" {}
    //        _Step("Step", int) = 128
    //
    //        _PLanetCenter("Planet Center", Vector) = (0,0,0,0)
    //        _PlanetRadius("Planet Radius", float)  = 4000000
    //        _HeightMinMax("Height Min Max", Vector) = (1500, 6000, 0, 0)
    //        
    //        _Gc("Global Coverage", Range(0, 1)) = 0
    //        _Gd("Global Density", float) = 1
    //        _FallOffCoverage("Fall Off Coverage", Range(0,1)) = 0.1
    //    }
    SubShader
    {
        Cull Off ZWrite Off ZTest Off

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 5.0


            #include "UnityCG.cginc"
            #include "UnityLightingCommon.cginc"

            #define HUMONGOUS_STEP 3


            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
                float4 ray : TEXCOORD1;
                float4 screenPos: TEXCOORD2;
            };

            uniform sampler2D _MainTex;

            sampler2D _CameraDepthTexture;

            uniform float4x4 _FrustumCorner;
            uniform float4x4 _CamToWorldMtx;

            uniform sampler3D _ShapeTex;
            uniform sampler3D _DetailTex;
            uniform sampler2D _WeatherTex;
            uniform sampler2D _CurlNoise;
            uniform sampler2D _BlueNoise;
            float4 _BlueNoise_TexelSize;

            uniform float _ExtinctionFactor;
            uniform float _ForwardScattering;
            uniform float _BackwardScattering;

            uniform float _SilverIntensity;
            uniform float _SilverSpread;
            
            uniform float2 _Random;
            uniform int _Step;

            uniform float _GlobalCoverage;
            uniform float _GlobalDensity;
            uniform float _FallOffCoverage;
            uniform float _Brightness;

            uniform float _NoiseScale;
            uniform float _DetailScale;
            uniform float _WeatherScale;

            uniform float _CurlNoiseScale;
            uniform float _CurlDistortionFactor;

            uniform float4 _CloudBaseColor;
            uniform float4 _CloudTopColor;
            uniform float _AmbientLightFactor;
            uniform float _DirectLightFactor;
            uniform float _ConeSpread;

            uniform float _FarPlane;
            uniform float4 _CameraWS;


            //w is radius
            uniform float4 _PLanetCenter;
            uniform float3 _PlanetZeroCoord;
            uniform float _PlanetRadius;
            //x is start height, y is x + thickness, z is thickness
            uniform float4 _CloudHeightMinMax;

            v2f vert(appdata v)
            {
                v2f o;

                int i = (int)v.vertex.z;
                v.vertex.z = 0.1;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                o.screenPos = ComputeScreenPos(o.vertex);
                o.ray = normalize(_FrustumCorner[i]);
                o.ray = mul(_CamToWorldMtx, o.ray);

                return o;
            }

            float remap(float value, float inMin, float inMax, float outMin, float outMax)
            {
                return outMin + (value - inMin) * (outMax - outMin) / (inMax - inMin);
            }

            float3 remap(float3 value, float3 inMin, float3 inMax, float3 outMin, float3 outMax)
            {
                return outMin + (value - inMin) * (outMax - outMin) / (inMax - inMin);
            }


            float getHeightFraction(float3 p)
            {
                float dst = distance(p, _PLanetCenter.xyz) - _PlanetRadius - _CloudHeightMinMax.x;
                dst /= _CloudHeightMinMax.z;

                return saturate(dst);
            }

            float beerLaw(float density)
            {
                float r = exp(-density * _ExtinctionFactor);

                return r;
            }

            float henyeyGreenstein(float g, float costh)
            {
                float gg = g * g;
                return (1.0 / (4.0 * 3.14)) * ((1.0 - gg) / pow(1.0 + gg - 2.0 * g * costh, 1.5));
            }


            float dualHenyeyGreenstein( float costh)
            {
                return lerp(henyeyGreenstein(-_BackwardScattering, costh), henyeyGreenstein(_ForwardScattering, costh), 0.7);
            }

            float phaseFunction( float costh)
            {
                return dualHenyeyGreenstein( costh);
            }

            float dualHenyeyGreenstein(float g, float costh)
            {
                return lerp(henyeyGreenstein(-g, costh), henyeyGreenstein(g, costh), 0.7);
            }

            float phaseFunction(float g, float costh)
            {
                return dualHenyeyGreenstein(g, costh);
            }

            float directionalScatteringProb(float costh)
            {
                return max(henyeyGreenstein(_ForwardScattering, costh),_SilverIntensity * henyeyGreenstein(0.99 - _SilverSpread, costh) );
            }
            
            float3 multipleOctaveScattering(float density, float mu)
            {
                float attenuation = 0.2;
                float contribution = 0.2;
                float phaseAttenuation = 0.5;
            
                float a = 1.0;
                float b = 1.0;
                float c = 1.0;
                float g = 0.85;
                const float scatteringOctaves = 4.0;
            
                float luminance = 0;
            
                for (float i = 0.0; i < scatteringOctaves; i++)
                {
                    float p = phaseFunction(0.3 * c, mu);
                    float beers = exp(-density * 0.8 * a);
            
                    luminance += b * p * beers;
            
                    a *= attenuation;
                    b *= contribution;
                    c *= (1.0 - phaseAttenuation);
                }
                return luminance;
            }


            float getHeightGradientDensity(float h, float type)
            {
                float a = saturate(remap(h, 0.15, 0.3, 0, 1))
                    * saturate(remap(h, 0.4, 0.6, 1, 0));
                return a;
            }

            float2 sampleWeatherData(float3 p)
            {
                float2 weatherData = tex2D(_WeatherTex, p.xz * _WeatherScale).rg;
                weatherData.r = saturate(weatherData.r - _FallOffCoverage);

                return weatherData;
            }


            //SIGGRAPH 2017 andrew schneider talk
            float sampleCloudDensity(float3 p, float h, float2 weatherData, int mip, bool useDetail)
            {
                // Wind settings.
                // float3 wind_direction = float3(1.0, 0.0, 0.0);
                // float cloud_speed =  _Time.x;
                // // cloud top offset pushes the tops of the clouds along
                // // this wind direction by this many units.
                // float cloud_top_offset = 700;
                // // Skew in wind direction.
                // p += h * wind_direction * cloud_top_offset * cloud_speed ;

                float4 lowFreqNoise = tex3Dlod(_ShapeTex, float4(p * _NoiseScale, mip));
                float lowFreqFBM = (lowFreqNoise.g * 0.625)
                    + (lowFreqNoise.b * 0.25)
                    + (lowFreqNoise.a * 0.125);
                

                float baseCloud = remap(lowFreqNoise.r, lowFreqFBM - 1 , 1, 0, 1);
                //float baseCloud = remap(lowFreqNoise.r * pow(1.2 - h, 0.1), lowFreqFBM - 1 , 1, 0, 1);
                //baseCloud = smoothstep(0,1, baseCloud);
                float heightGradient = getHeightGradientDensity(h, 1);
                //heightGradient = 1;

                baseCloud *= heightGradient;

                float cloudCoverage = weatherData.r;
                //cloudCoverage = pow(cloudCoverage, remap(h, 0.7, 0.8, 1.0, lerp(1.0, 0.5, 0.2)));
                //float baseCloudWithCoverage = remap(baseCloud,  saturate(h * 0.1 / cloudCoverage), 1.0, 0.0, 1.0);
                 float baseCloudWithCoverage = remap(baseCloud,    cloudCoverage  , 1.0, 0.0, 1.0);
                baseCloudWithCoverage *= cloudCoverage;


                
                float finalCloud = baseCloudWithCoverage;
                 //return finalCloud;
                if (useDetail)
                {
                    // Add some turbulence to bottoms of clouds.
                    float2 curl = tex2D(_CurlNoise, p.xz * _CurlNoiseScale).xz ;
                    p.xz += curl * h * _CurlDistortionFactor;
                    // Sample high−frequency noises.
                    float3 highFreqNoise = tex3Dlod(_DetailTex, float4(p * _DetailScale, mip)).rgb;
                    // Build−high frequency Worley noise FBM.
                    float highFreqFBM = (highFreqNoise.r * 0.625) + (highFreqNoise.g * 0.25) + (
                        highFreqNoise.b * 0.125);
                    // Get the height fraction for use with blending noise types
                    // over height.
                    float h2 = getHeightFraction(p);
                    // Transition from wispy shapes to billowy shapes over height.
                    float highFreqNoiseModifier = lerp(highFreqFBM, 1.0 - highFreqFBM,
                                saturate(h2 * 10.0));
                    // Erode the base cloud shape with the distorted
                    // high−frequency Worley noises.
                    finalCloud = remap(baseCloudWithCoverage, highFreqNoiseModifier * 0.2, 1.0, 0, 1.0);
                    //finalCloud = baseCloudWithCoverage + finalCloud * (1 - baseCloudWithCoverage);
                }

                return finalCloud;
            }

            float sampleCloudDensityAlongCone(float3 p, float lightStep)
            {
                const float3 noiseKernel[6] = {
                    {0.3, 0.8, -0.6},
                    {0.0, 0.5, -0.1},
                    {-0.9, 0.2, 0.4},
                    {-0.5, 0.3, -0.6},
                    {0.1, -0.2, -0.3},
                    {0.7, -0.8, 0.9},
                };

                float density = 0;

                for (int i = 0; i < 6; i++)
                {
                    //random offset inside a cone
                    p += lightStep * _WorldSpaceLightPos0.xyz;
                    p += lightStep * noiseKernel[i] * (i + 1) * _ConeSpread;

                    float h = getHeightFraction(p);
                    float2 weatherData = sampleWeatherData(p);

                    if (density < 0.3)
                    {
                    float cloudDensity = sampleCloudDensity(p, h, weatherData, 1, true);
                    density += cloudDensity;
                    }
                    else
                    {
                        float cloudDensity = sampleCloudDensity(p, h, weatherData, 1, false);
                        density += cloudDensity;
                    }
                }
        
                return density ;
            }


            // float CalculateLightEnergy(float coneDensity, float cloudDensity, float costh)
            // {
            //     float beersLaw = max(beerLaw(coneDensity), beerLaw(coneDensity * 0.25) * 0.7);
            //     float powder = 1.0 - exp(-cloudDensity * 2.0);
            //
            //     return beersLaw * lerp(2.0 * powder, 1.0, remap(costh, -1.0, 1.0, 0.0, 1.0)) * phaseFunction(costh);
            // }

            //SIGGRAPH 2017 andrew schneider talk
            float CalculateLightEnergy(float coneDensity, float h, float cloudDensity, float stepSize, float costh)
            {
                //attenuation 
                //float beersLaw = max(beerLaw(coneDensity), beerLaw(coneDensity * 0.25) * 0.7);
                float primaryAttem = beerLaw(coneDensity);
                float secondaryAtten =  beerLaw(coneDensity * 0.25) * 0.7;
                float attenuationProb = max(remap(costh, 0.7, 1.0, secondaryAtten, secondaryAtten * 0.25 ), primaryAttem);

                //float depthProb = lerp( 0.05 + pow( 20, remap( h, 0.3, 0.85, 0.5, 2.0 )), 1.0, saturate( coneDensity / stepSize));
                float verticalProbability = pow( remap( h, 0.07, 0.14, 0.1, 1.0 ), 1.2 );
                float powder = 1.0 - exp(-cloudDensity * 2.0);
                float energy =  powder * verticalProbability * attenuationProb * directionalScatteringProb(costh) * _Brightness;

                return energy;
                
                //return beersLaw * lerp(2.0 * powder, 1.0, remap(costh, -1.0, 1.0, 0.0, 1.0)) * phaseFunction(costh);

            }
            
            //source:
            // https://www.scratchapixel.com/lessons/3d-basic-rendering/minimal-ray-tracer-rendering-simple-shapes/ray-sphere-intersection
            float3 findRayStartPos(float3 rayOrigin, float3 rayDirection, float3 sphereCenter, float radius)
            {
                float3 l = rayOrigin - sphereCenter;
                float a = 1.0;
                float b = 2.0 * dot(rayDirection, l);
                float c = dot(l, l) - pow(radius, 2);
                float D = pow(b, 2) - 4.0 * a * c;
                if (D < 0.0)
                {
                    return rayOrigin;
                }
                else if (abs(D) - 0.00005 <= 0.0)
                {
                    return rayOrigin + rayDirection * (-0.5 * b / a);
                }
                else
                {
                    float q = 0.0;
                    if (b > 0.0)
                    {
                        q = -0.5 * (b + sqrt(D));
                    }
                    else
                    {
                        q = -0.5 * (b - sqrt(D));
                    }
                    float h1 = q / a;
                    float h2 = c / q;
                    float2 t = float2(min(h1, h2), max(h1, h2));
                    if (t.x < 0.0)
                    {
                        t.x = t.y;
                        if (t.x < 0.0)
                        {
                            return rayOrigin;
                        }
                    }
                    return rayOrigin + t.x * rayDirection;
                }
            }
            
	        float getRandomRayOffset(float2 uv) 
	        {
		        float noise = tex2D(_BlueNoise, uv).x;
		        noise = mad(noise, 2.0, -1.0);
		        return noise;
	        }

            float4 raymarch(float3 ro, float3 rd, int steps, float stepSize, float sceneDst, float sceneDepth, float cosTheta)
            {
                float3 p = ro;
                float4 col = 0;
                float transmission = 1;
                float alpha = 0;
                int stepMul = 1;
                int zeroCount = 0;

                [loop]
                for (int i = 0; i < steps; i += stepMul)
                {
                    float dst = length(_CameraWS.xyz - p);

                    if (transmission <= 0.01)
                        break;

                    float h = getHeightFraction(p);

                    //because we want to compare dst and sceneDst to know if geometry occlude our cloud
                    //dst mostly always > sceneDst even though sceneDst is at far plane
                    //which mean the cloud is not drawn, we don't want that
                    //we only compare when the sceneDepth in range [near, far)
                    //if we reach far, draw cloud
                    //if sceneDepth < far plane = cloud get occluded
                    //the 0.3 is a error threshold
                    //sceneDepth is not equal to far plane because of floating point error (far: 1000, sceneDepth:999,6)
                    if (_FarPlane - sceneDepth > 0.2 && dst >= sceneDst)
                        break;

                    if (p.y < _PlanetZeroCoord.y)
                        break;

                    float2 weatherData = sampleWeatherData(p);


                    float cloudDensity = sampleCloudDensity(p, h, weatherData, 0, true);

                    if (cloudDensity > .1)
                    {
                        transmission *= beerLaw(cloudDensity * stepSize * stepMul);

                        float ld = sampleCloudDensityAlongCone(p, 0.5);
                        float3 directLight = _LightColor0.xyz * _DirectLightFactor * CalculateLightEnergy(ld, h, cloudDensity,0.5,  cosTheta);

                        col.rgb += directLight * transmission * stepSize * stepMul * cloudDensity;
                        
                    }

                    p += rd * stepSize * stepMul;
                }


                // float dst = length(_CameraWS.xyz - p);
                //
                // if (_FarPlane - sceneDepth > 0.3 && dst >= sceneDst)
                //     return 0;
                // if (p.y < _PlanetZeroCoord.y)
                //     return 0;
                //                 float4 lowFreqNoise = tex3Dlod(_ShapeTex, float4(p * _NoiseScale, 0));
                // float lowFreqFBM = (lowFreqNoise.g * 0.625)
                //     + (lowFreqNoise.b * 0.25)
                //     + (lowFreqNoise.a * 0.125);
                //
                //
                //  float baseCloud = remap(lowFreqNoise.r, lowFreqFBM - 1, 1, 0, 1);
                // float h =0.5;
                //                   float heightGradient = getHeightGradientDensity(h, 1);
                // // //
                //   baseCloud *= heightGradient;
                //                   float cloudCoverage = sampleWeatherData(p).r ;
                // // //
                //  float baseCloudWithCoverage = remap(baseCloud,  cloudCoverage, 1.0, 0.0, 1.0);
                //  //baseCloudWithCoverage *= cloudCoverage;
                // //
                // float3 highFreqNoise = tex3Dlod(_DetailTex, float4(p * _DetailScale, 0)).rgb;
                // // Build−high frequency Worley noise FBM.
                // float highFreqFBM = (highFreqNoise.r * 0.625) + (highFreqNoise.g * 0.25) + (
                //     highFreqNoise.b * 0.125);
                // // Get the height fraction for use with blending noise types
                // // over height.
                // float h2 = 0.5;
                // // Transition from wispy shapes to billowy shapes over height.
                // float highFreqNoiseModifier = lerp(  1.0 - highFreqFBM, highFreqFBM,
                //                            saturate(h2 * 10.0));
                // // Erode the base cloud shape with the distorted
                // // high−frequency Worley noises.
                // float finalCloud = remap(baseCloudWithCoverage, highFreqNoiseModifier * 0.2, 1.0, 0.0, 1.0);
                // //
                // float4 d = cloudCoverage  ;
                //  d.a = 1;
                //  //return d;
                return float4(col.rgb, 1 - transmission);
            }

            float4 frag(v2f i) : SV_Target
            {
                float3 ro = _CameraWS;
                float3 rd = normalize(i.ray);

                float4 col = 0;
                float3 rs, re;
                int steps = _Step;
                float stepSize = 1;

                float dst = distance(ro, _PLanetCenter.xyz) - _PlanetRadius - _CloudHeightMinMax.x;

                float2 screenUV = i.screenPos.xy / i.screenPos.w;
                float depth01 = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, screenUV);

                float sceneDepth = LinearEyeDepth(depth01);
                // get the world space camera forward vector
                // view space is -Z forward, and the view matrix is always a uniform scale matrix
                // swapping the vector and matrix order in the mul() applies the transposed matrix to the vector
                // and the transpose of a uniform matrix is identical to the inverse matrix
                // so this is a view to world
                //float3 cam_forward_world = mul(float3(0,0,-1), (float3x3)UNITY_MATRIX_V);
                float3 cam_forward_world = mul((float3x3)UNITY_MATRIX_V, float3(0, 0, -1));
                // the dot product of the normalized forward and ray direction effectively
                // returns the "depth" of the ray direction vector
                float ray_depth_world = dot(cam_forward_world, rd);
                // with all that we can reconstruct a world position
                float sceneDistance = length(rd / ray_depth_world * sceneDepth);


                // if (ro.y <= _PLanetCenter.y)
                // {
                //     return float4(0,0,0,0);
                // }

                //below cloud
                // if (dst < 0)
                // {
                rs = findRayStartPos(ro, rd, _PLanetCenter.xyz, _PlanetRadius + _CloudHeightMinMax.x);
                re = findRayStartPos(ro, rd, _PLanetCenter.xyz, _PlanetRadius + _CloudHeightMinMax.y);

                steps = lerp(_Step * 0.5f, _Step, rd.y);
                stepSize = distance(rs, re) / steps;
                //}
                // //in cloud
                // else if (dst <= _CloudHeightMinMax.z)
                // {
                //     rs = findRayStartPos(ro, rd, _PLanetCenter.xyz, _PlanetRadius + _CloudHeightMinMax.x);
                //     re = findRayStartPos(ro, rd, _PLanetCenter.xyz, _PlanetRadius + _CloudHeightMinMax.y);
                //
                //     float d1 = distance(rs, ro);
                //     float d2 = distance(re, ro);
                //     float rs = ro;
                //
                //     steps = lerp(_Step * 0.5f, _Step, rd.y);
                //     stepSize = distance(ro, max(d1, d2)) / steps;
                // }
                // //above cloud
                // else
                // {
                //     re = findRayStartPos(ro, rd, _PLanetCenter.xyz, _PlanetRadius + _CloudHeightMinMax.x);
                //     rs = findRayStartPos(ro, rd, _PLanetCenter.xyz, _PlanetRadius + _CloudHeightMinMax.y);
                //
                //
                //     steps = lerp(_Step * 0.5f, _Step, rd.y);
                //     stepSize = distance(rs, re) / steps;
                // }

                float2 uv = i.uv;
                //rs += rd * stepSize * 0.5 * getRandomRayOffset(uv * _Random.xy) * HUMONGOUS_STEP ;
                float cosTheta = dot(-rd, _WorldSpaceLightPos0.xyz);
                col = raymarch(rs, rd, steps, stepSize, sceneDistance, sceneDepth, cosTheta);


                return col;
            }
            ENDCG
        }
    }
}