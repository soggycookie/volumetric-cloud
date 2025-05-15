Shader "Hidden/Cloud"
{
    SubShader
    {
        Cull Off ZWrite Off ZTest Off

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 5.0
            #pragma multi_compile __ SHOW_MAPPED_WEATHER_TEX
            #pragma multi_compile __ BASE_CLOUD_ONLY


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

            sampler2D _MainTex;

            sampler2D _CameraDepthTexture;

            float4x4 _FrustumCorner;
            float4x4 _CamToWorldMtx;

            sampler3D _ShapeTex;
            sampler3D _DetailTex;
            sampler2D _WeatherTex;
            sampler2D _CurlNoise;
            sampler2D _BlueNoise;
            float4 _BlueNoise_TexelSize;

            float _ExtinctionFactor;
            float _ForwardScattering;
            float _BackwardScattering;

            float _SilverIntensity;
            float _SilverSpread;
            float _PhaseFactor;
            
            float2 _Random;
            int _Step;

            float _GlobalCoverage;
            float _Brightness;

            float _NoiseScale;
            float _DetailScale;
            float _WeatherScale;

            float _CurlNoiseScale;
            float _CurlDistortionFactor;

            float4 _CloudBaseColor;
            float4 _CloudTopColor;
            float _AmbientLightFactor;


            float _FarPlane;
            float4 _CameraWS;


            //w is radius
            float4 _PLanetCenter;
            float3 _PlanetZeroCoord;
            float _PlanetRadius;
            //x is start height, y is x + thickness, z is thickness
            float4 _CloudHeightMinMax;

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
                // float r = max(exp(-density * _ExtinctionFactor), 0.7 * exp(-density * _ExtinctionFactor * 0.25));

                return r;
            }

            float henyeyGreenstein(float g, float cosTheta)
            {
                float denom = 1.0 + g * g - 2.0 * g * cosTheta;
                return (1.0 - g * g) / (4.0 * 3.1415 * pow(denom, 1.5));
            }

            float dualHenyeyGreenstein(float costh)
            {
                return lerp(henyeyGreenstein(-_BackwardScattering, costh), henyeyGreenstein(_ForwardScattering, costh), 0.7);
            }


            float directionalScatteringProb(float costh)
            {
                return max(henyeyGreenstein(_ForwardScattering, costh), _SilverIntensity * henyeyGreenstein(0.99 - _SilverSpread, costh));
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
                weatherData.r = saturate(weatherData.r);

                return weatherData;
            }
            
            //SIGGRAPH 2017 andrew schneider presentation
            float sampleCloudDensity(float3 p, float h, float2 weatherData, int mip, bool useDetail)
            {
                
                float4 lowFreqNoise = tex3Dlod(_ShapeTex, float4( (p + float3(0,1,0) * _Time.x * 2000) * _NoiseScale, mip));
                float lowFreqFBM = (lowFreqNoise.g * 0.625)
                    + (lowFreqNoise.b * 0.25)
                    + (lowFreqNoise.a * 0.125);


                float baseCloud = remap(lowFreqNoise.r, lowFreqFBM - 1, 1, 0, 1);
                //float baseCloud = remap(lowFreqNoise.r * pow(1.2 - h, 0.1), lowFreqFBM - 1 , 1, 0, 1);
                //baseCloud = smoothstep(0,1, baseCloud);
                float heightGradient = getHeightGradientDensity(h, 1);
                //heightGradient = 1;

                baseCloud *= heightGradient;

                float cloudCoverage = weatherData.r;
                float baseCloudWithCoverage = remap(baseCloud, cloudCoverage, 1.0, 0.0, 1.0);
                baseCloudWithCoverage *= (cloudCoverage);
                
                
                float finalCloud = baseCloudWithCoverage;


                #ifndef  BASE_CLOUD_ONLY
                if (useDetail)
                {
                    // Add some turbulence to bottoms of clouds.
                    float2 curl = tex2D(_CurlNoise, p.xz * _CurlNoiseScale).xz;
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
                                                  saturate(h2 * 10));
                    // Erode the base cloud shape with the distorted
                    // high−frequency Worley noises.
                    finalCloud = remap(baseCloudWithCoverage, highFreqNoiseModifier * 0.15, 1.0, 0, 1.0);
                    //finalCloud = baseCloudWithCoverage + finalCloud * (1 - baseCloudWithCoverage);
                }
                #endif
                
                
                return saturate(finalCloud) ;
            }

            float sampleCloudDensityAlongCone(float3 p, float lightStep)
            {
                const float3 noiseKernel[6] = {
                    {0.3, -0.8, -0.6},
                    {0.0, 0.5, -0.1},
                    {-0.9, -0.2, 0.4},
                    {0.5, 0.3, 0.6},
                    {0.1, -0.2, 0.3},
                    {0.7, -0.8, -0.9},
                };

                float d = 0;
                float3 lp = p;
                float pd = 0;
                float h = 0;
                float2 wd = 0;
                
                for (int i = 0; i < 6; i++)
                {
                    //random offset inside a cone
                    float3 offset =  noiseKernel[i] * i ;
                    lp += (_WorldSpaceLightPos0 + offset) * lightStep;

                    h = getHeightFraction(p);
                    wd = sampleWeatherData(p);

                    if (d < 0.3)
                    {
                        pd = sampleCloudDensity(lp, h, wd, 1, true);
                        d += pd;
                    }
                    else
                    {
                        pd = sampleCloudDensity(lp, h, wd, 1, false);
                        d += pd;
                    }
                }

                lp = p + _WorldSpaceLightPos0 * lightStep * 10;
                h = getHeightFraction(lp);
                wd = sampleWeatherData(lp);
                pd = sampleCloudDensity(lp, h, wd, 1, false);
                d+= pd;
                
                return d ;
            }
            
            //SIGGRAPH 2017 andrew schneider presentation with modification
            float calculateLightEnergy(float coneDensity, float cloudDensity, float h, float lightStep, float cosTheta)
            {
                //attenuation 
                float primaryAtten = beerLaw(coneDensity);
                float secondaryAtten = beerLaw(coneDensity * 0.25) * 0.7;
                float attenuationProb = max(remap(cosTheta, 0.7, 1.0, secondaryAtten, secondaryAtten * 0.25), primaryAtten);
                float beer = max(beerLaw(coneDensity), beerLaw(coneDensity * 0.25) * 0.7);

                
                
                
                float depthProb = lerp( 0.05 + pow( 1, remap( h, 0.3, 0.85, 0.5, 2.0 )), 1.0, saturate( coneDensity / lightStep));
                float verticalProbability = pow(remap(h, 0.07, 0.14, 0.1, 1.0), 1.2);

                float energy = verticalProbability  * depthProb *  _Brightness  * beer * (directionalScatteringProb(cosTheta) * 0.1 + 0.6) ;

                return energy;
            }

            //
            float3 intersectSphere(float3 rayOrigin, float3 rayDirection, float3 sphereCenter, float radius)
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
            

            float4 raymarch(float3 ro, float3 rd, int steps, float stepSize, float lightStep, float sceneDst, float sceneDepth,
                                   float cosTheta)
            {
                float3 p = ro;
                float4 col = 0;
                float transmission = 1;
                float alpha = 0;
                int stepMul = 1;
                int zeroCount = 0;

                
                #if defined(SHOW_MAPPED_WEATHER_TEX)
                float dst = length(_CameraWS.xyz - p);
                 if (_FarPlane - sceneDepth >= 0.2 && dst >= sceneDst)
                    return 0;

                if (p.y < _PlanetZeroCoord.y)
                    return 0;
                
                float2 weatherData = sampleWeatherData(p);
                col = weatherData.x;
                col.a = 1;
                return col;
                
                #else

                
                [loop]
                for (int i = 0; i < steps; i += stepMul)
                {
                    p += rd * stepSize * stepMul;
                    
                    float dst = length(_CameraWS.xyz - p);

                    if (transmission <= 0.01)
                        break;

                    float h = getHeightFraction(p);
                    
                    if (_FarPlane - sceneDepth >= 0.2 && dst >= sceneDst)
                        break;

                    if (p.y < _PlanetZeroCoord.y)
                        break;

                    float2 weatherData = sampleWeatherData(p);
                    
                    float cloudDensity = sampleCloudDensity(p, h, weatherData, 0, true);
                    if (cloudDensity > 0)
                    {
                        if (stepMul == HUMONGOUS_STEP)
                        {
                            i--;
                            p-= rd * stepSize * (stepMul -1);
                            stepMul = 1;
                            zeroCount = 0;
                            continue;
                        }
                        
                        float atten = beerLaw(cloudDensity * stepSize);
                        transmission *= atten;
                        
                        float ld = sampleCloudDensityAlongCone(p, lightStep);
                        float lb = calculateLightEnergy(ld, cloudDensity, h, lightStep, cosTheta);
                        //float lb = max(beerLaw(ld), beerLaw( ld * 0.25) * 0.7);

                        alpha += (1 - alpha) * (1 - atten);
                        col.rgb += _LightColor0 * lb  * transmission * cloudDensity * stepSize  * 0.1  ;

                        zeroCount = 0;
                        stepMul = 1;
                    }else
                    {
                        zeroCount++;
                    }

                    if (zeroCount > 5)
                    {
                        stepMul = HUMONGOUS_STEP;
                    }
                    
                }

                return float4(col.rgb, alpha);
                #endif
            }

            float4 frag(v2f i) : SV_Target
            {
                float3 ro = _CameraWS;
                float3 rd = normalize(i.ray);

                float4 col = 0;
                float3 rs, re;
                int steps = _Step;
                float stepSize = 1;
                float lightStep = 1;
                
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
                
                float cosTheta = dot(rd, normalize(_WorldSpaceLightPos0.xyz));


                // if (ro.y <= _PLanetCenter.y)
                // {
                //     return float4(0,0,0,0);
                // }

                //below cloud
                // if (dst < 0)
                // {
                rs = intersectSphere(ro, rd, _PLanetCenter.xyz, _PlanetRadius + _CloudHeightMinMax.x);
                re = intersectSphere(ro, rd, _PLanetCenter.xyz, _PlanetRadius + _CloudHeightMinMax.y);

                steps = lerp(_Step, _Step * 0.5, saturate(dot(rd, float3(0,1,0))));

                stepSize = distance(rs, re) / steps;
                lightStep = _CloudHeightMinMax.z / 36.0;
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
                col = raymarch(rs, rd, steps, stepSize, lightStep, sceneDistance, sceneDepth, cosTheta);


                return col;
            }
            ENDCG
        }
    }
}