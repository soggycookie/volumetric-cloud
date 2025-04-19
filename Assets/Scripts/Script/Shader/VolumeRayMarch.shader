Shader "Unlit/VolumeRayMarch"
{
    Properties
    {
        _Color("Volume color", Color) = (0,0,0,1)
        _SigmaA("Absorption coefficient", float) = 0
        _SigmaS("Scattering coefficient", float) = 0
        _Density("Volume Density", float) = 1
        _Brightness("Brightness", float) = 1
        _StepSize("Step size ", Range(0.01,1)) = 0.1
        _AsymmetryFactor("Asymmetry factor - Scattered light distribution", Range(-1,1)) = 0
    }

    SubShader
    {
        Tags {  "Queue"= "Transparent" "RenderType"="Transparent" "LightMode"="ForwardBase" }
        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite Off
        Cull Off
        ZTest Always
        ZClip False

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"
            #include "UnityLightingCommon.cginc"
            #include "RayMarchUtilities.cginc"
            #include "PerlinNoise.cginc" 


            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float3 wPos: TEXCOORD1;
                float4 screenPos: TEXCOORD2;
                float depth: TEXCOORD3;
                float4 vertex : SV_POSITION;
            };
            
            float _SigmaA;
            float _SigmaS;
            float _Density;
            float _Brightness;
            float _StepSize;
            float4 _Color;
            float _AsymmetryFactor;
            uniform sampler3D _DetailTex;
            uniform sampler3D _ShapeTex;

            
            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.screenPos = ComputeScreenPos(o.vertex);
                o.wPos  = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.depth = o.vertex.z;
                o.uv = v.uv;
                return o;
            }
            



            float GetDist(float3 p){

                float4 s = float4(0,0,-5, 10);
                float sd1 = sdSphere(p, s);

                return sd1;
            }
            
            float HenyeyGreenstein(float g, float costh) {
              float gg = g * g;
	            return (1.0 / (4.0 * PI))  * ((1.0 - gg) / pow(1.0 + gg - 2.0 * g * costh, 1.5));
            }

            float IsotropicPhaseFunction(float g, float costh) {
              return 1.0 / (4.0 * PI);
            }

            float dualHenyeyGreenstein(float g, float costh) {
              return lerp(HenyeyGreenstein(-g, costh), HenyeyGreenstein(g, costh), 0.7);
            }

            float PhaseFunction(float g, float costh) {
              return dualHenyeyGreenstein(g, costh);
            }


            //return -1: ray miss the sphere/no intersection
            float GetIntersectionDist(float4 s,float3 o, float3 rd, float d){
                float3 L = (s.xyz - o) ;

                float tca = dot(L, rd);

                if(tca < 0 && d >= 0 ) return -1;
                

                float h2 = dot(L,L) - tca * tca;

                float r = sqrt(s.w * s.w - h2);
                

                return d >=0 ? r * 2 : r + tca;
            }

            //dst: distance
            //sigma: absorption coefficient, higher ac smaller result (less light pass through)
            //return amount of light pass through
            float BeerLaw( float density){
                float r = exp(-density * 0.7);
                
                return r;
            }


            
            //s.xyz sphere pos, s.w sphere rad
            //t0 sample point inside sphere
            //rd ray dir
            float GetLightRayDst(float3 t0, float4 s, float3 rd, float3 lightDir){
                float3 R0 = s.xyz - t0;
                float result = 0;
                float rp = dot(R0, lightDir);
                float h2 = dot(R0, R0) - rp * rp; 
                
                float d = sqrt(s.w * s.w - h2);

                return max(0.0, rp + d);
            }
            
            float remap(float value, float inMin, float inMax, float outMin, float outMax)
            {
                return outMin + (value - inMin) * (outMax - outMin) / (inMax - inMin);
            }
            
            float EvaluateDensity(float3 samplePoint, float4 s){
                
                float4 lowFreq =  tex3D(_ShapeTex, (samplePoint - s.xyz / s.w) * 0.05) ; ;
                float4 highFre =  tex3D(_DetailTex, (samplePoint - s.xyz / s.w) * 0.01) ; ;
                 float fbm = lowFreq.g * 0.625 + lowFreq.b * 0.25 + lowFreq.a * 0.125;
                //float fbm = lowFreq.g ;
                float base = remap(lowFreq.r, fbm - 1, 1, 0, 1);
                
                
                //noise = pow(noise, exponent);
                float dst = min( 1, length(samplePoint - s.xyz) / s.w);
                float falloff = remap(dst, 0.5, 0.7, 0 ,1);
                falloff = saturate(falloff);
                falloff = (1 - falloff * falloff) + base;
                falloff = saturate(falloff);
                // if (falloff < .2)
                //     falloff = 0;
                
                return falloff ;


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
                    float phaseFunction = PhaseFunction(0.5 * c, mu);
                    float beers = exp(-density * 0.8 * a);

                    luminance += b * phaseFunction * beers;

                    a *= attenuation;
                    b *= contribution;
                    c *= (1.0 - phaseAttenuation);
                }
                return luminance;
            }
            
            float CalculateLightEnergy(float3 p, float costh, float stepSize)
            {
                float tau = 0;
                for (int j = 0; j < 7; j++)
                {
                    float3 l0 = p + _WorldSpaceLightPos0.xyz * stepSize * (j + 0.5);
                    float sampleLightDensity = EvaluateDensity(l0, float4(0,0,-5, 10));
                    tau += sampleLightDensity;
                }
                float beersLaw = multipleOctaveScattering(tau, costh);
                float powder = 1.0 - exp(-tau * 2.0 * 0.7);

                return beersLaw * powder * 2;
                
                //return beersLaw * lerp(2.0 * powder, 1.0, remap(costh, -1.0, 1.0, 0.0, 1.0));
                
            }
            //t1 first intersection point
            //o.xyz = ray origin, o.w = intersection dst
            //rd ray dir
            float4 GetVolumeColor(float3 t1, float4 o, float3 rd){
                float transmission = 1;
                float3 resultCol = float3(0,0,0);
                int maxStep = 1000;
                
                if(o.w < 0){
                    return float4(resultCol, 1 - transmission);
                }
                
                if(_StepSize ==0)
                    _StepSize = 0.1;

                int steps = ceil(o.w / _StepSize);
                steps = min(maxStep, steps); 
                
                float3 t2 =  t1 + o.w * rd;
                float cosTheta = dot( -rd, _WorldSpaceLightPos0.xyz);

                [loop]
                for(int i =0 ; i < steps; i++){
                    #ifdef BACKWARD_RAYMARCH
                        //not updated
                        float3 t0 = t2 - rd * _StepSize * (i + 0.5);
                        float sampleAtten = BeerLambertLaw(_StepSize, EvaluateDensity(t0, float4(0,0,-5, 5)) );
                    
                        float  L = GetLightRayDst(t0, float4(0,0,-5, 5), rd, _WorldSpaceLightPos0.xyz);
                        float3 LT = BeerLambertLaw(L, 1);


                        resultCol = (resultCol + LT) * sampleAtten * _LightColor0.xyz * _StepSize * _Color.xyz * _SigmaS * Phase(cosTheta) ;
                        transmission *= sampleAtten;
                    
                    #else

                        float3 t0 = t1 + rd * _StepSize * (i + 0.5);
                        float sampleAtten = BeerLaw(_StepSize * EvaluateDensity(t0, float4(0,0,-5, 10)));

                        float  L = GetLightRayDst(t0, float4(0,0,-5, 10), rd, _WorldSpaceLightPos0.xyz);
                        transmission *= sampleAtten;
                        
                        if(transmission < 1e-3)
                          break;
                        
                        float stepSize = L/7;


                        float lumi = CalculateLightEnergy(t0, cosTheta, stepSize);
                        float3 c = lumi * _LightColor0.xyz;
                    

                        resultCol +=  transmission * c * _StepSize * _Color.xyz * 0.7  ;

                    #endif
                }



                return float4(resultCol * _Brightness, 1- transmission);
            }

            float4 frag (v2f i) : SV_Target
            {
                float3 ro = _WorldSpaceCameraPos;
                float3 rd = normalize(i.wPos - ro);
                

                float2 screenUV = i.screenPos.xy / i.screenPos.w;
                float depth01 = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, screenUV);

                float sceneDepth = LinearEyeDepth(depth01);

                // get the world space camera forward vector
                // view space is -Z forward, and the view matrix is always a uniform scale matrix
                // swapping the vector and matrix order in the mul() applies the transposed matrix to the vector
                // and the transpose of a uniform matrix is identical to the inverse matrix
                // so this is a view to world
                //float3 cam_forward_world = mul(float3(0,0,-1), (float3x3)UNITY_MATRIX_V);
                float3 cam_forward_world = mul( (float3x3)UNITY_MATRIX_V, float3(0,0,-1));
                // the dot product of the normalized forward and ray direction effectively
                // returns the "depth" of the ray direction vector
                float  ray_depth_world = dot(cam_forward_world, rd);
                // with all that we can reconstruct a world position
                float  sceneDistance = length(rd / ray_depth_world * sceneDepth) ;

                Ray ray;
                ray.origin = ro;
                ray.dir = rd;
                
                float d = RayMarch(ray.origin, ray.dir);
                
                //return float4(d.xxx + 100,1);
                
                int rayHit = step(d,min(MAX_DIST, sceneDistance));
                float3 n = GetNormal(ro + d * rd);
                
                //return float4(dot(n , _WorldSpaceLightPos0.xyz).xxx, 1);


                //return float4(step(d,0).xxx, rayHit);

                float intersectionDst = GetIntersectionDist(float4(0,0,-5, 10), ro, rd, d);
                
                
                float4 inscatter = GetVolumeColor(ro + rd * step(0,d) * d, float4(ro.xyz, intersectionDst), rd);
                //float t = BeerLambertLaw(intersectionDst);

                //return inscatter;
                //return float4(_Color.xyz, rayHit);

                //return float4(_Color.xyz, rayHit * (1 - t));
                // float4 lowFreq =  tex3D(_ShapeTex, (ro + rd * step(0,d) * d - float3(0,0,-5) / 10) * 0.05) ;
                // float fbm = lowFreq.g ;
                // float base = remap(lowFreq.r, fbm - 1, 1, 0, 1);
                // float4 a = base;
                // a.a = rayHit;

                
                //return a;
                return float4(inscatter.xyz , rayHit *  (inscatter.w) );
            }
            ENDCG
        }
    }
}
