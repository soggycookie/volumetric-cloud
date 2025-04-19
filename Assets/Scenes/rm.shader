Shader "Unlit/rm"
{
    Properties
    {
        _Color("Volume color", Color) = (0,0,0,1)
        _SigmaA("Absorption coefficient", float) = 0
        _Density("Volume Density", float) = 1
        _Brightness("Brightness", float) = 1
        _StepSize("Step size ", Range(0.001,1)) = 0.1
        _AsymmetryFactor("Asymmetry factor - Scattered light distribution", Range(-1,1)) = 0
        _Cube("Cube", Vector) = (0,0,0,0)
        _Bound("Bound", Vector) = (1,1,1,1)
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
            float _Density;
            float _Brightness;
            float _StepSize;
            float4 _Color;
            float _AsymmetryFactor;
            float4 _Cube;
            float4 _Bound;
            sampler2D _CameraDepthTexture;
            uniform sampler3D _Perlin;
            // uniform sampler3D _DetailTex;
            // uniform sampler3D _ShapeTex;
            struct Ray {
                float3 origin;
                float3 dir;
            };

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

            float sdBox( float3 p, float3 s, float3 b )
            {
              float3 q = abs(p - s) - b;
              return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0);
            }

            float remap(float value, float inMin, float inMax, float outMin, float outMax)
            {
                return outMin + (value - inMin) * (outMax - outMin) / (inMax - inMin);
            }
            
            float GetDist(float3 p)
            {
                float d = sdBox(p, _Cube, _Bound);

                return d;
            }

            float RayMarch(float3 ro, float3 rd) {
	            float d=0.;
    

                for(int i=0; i< 100; i++) {
    	            float3 p = ro + rd * d;
                    float dS = (GetDist(p));

                    d += dS;
                    
                    if(d> 100)
                        break;
                    
                    if(dS<= 0.01f) 
                        break;
                    
                }
    
                return d;
            }
            
            float HenyeyGreenstein(float g, float costh) {
              float gg = g * g;
	            return (1.0 / (4.0 * 3.14))  * ((1.0 - gg) / pow(1.0 + gg - 2.0 * g * costh, 1.5));
            }


            
            float2 boxIntersection( float3 ro, float3 rd, float3 rad, out float3 oN ) 
            {
                float3 m = 1.0/rd;
                float3 n = m*ro;
                float3 k = abs(m)*rad;
                float3 t1 = -n - k;
                float3 t2 = -n + k;

                float tN = max( max( t1.x, t1.y ), t1.z );
                float tF = min( min( t2.x, t2.y ), t2.z );
	            
                if( tN>tF || tF<0.0) return float2(-1.0, -1.0); // no intersection
                
                oN = -sign(rd)*step(t1.yzx,t1.xyz)*step(t1.zxy,t1.xyz);

                return float2( tN, tF );
            }

            float2 boxIntersection( float3 ro, float3 rd, float3 rad ) 
            {
                float3 m = 1.0/rd;
                float3 n = m*ro;
                float3 k = abs(m)*rad;
                float3 t1 = -n - k;
                float3 t2 = -n + k;

                float tN = max( max( t1.x, t1.y ), t1.z );
                float tF = min( min( t2.x, t2.y ), t2.z );
	            
                if( tN>tF || tF<0.0) return float2(-1.0, -1.0); // no intersection
                
                return float2( tN, tF );
            }
            
            float sampleDensity(float3 p)
            {
                float3 windDir = float3(1,0.3, - 0.2);
                float speed = 10 * _Time.x;

                p+= windDir * speed;
                
                float d = tex3D(_Perlin, p * 0.5);
                float3 a = abs(p - _Cube);
                float3 s = a / (_Bound * 0.5);
                float f = max(s.x, max(s.y, s.z));
                
                if ( d < .3)
                {
                    d = smoothstep(0, 1,remap(d, 0.3, 1, 0, 1));
                }
                
                // f = remap(f, 0, 2, 0 ,1);
                // f = saturate(remap(f, 0.7, 0.9, 1, 0));
                //f= smoothstep(1, 0, f);
                
                
                return  d ;
            }
            
            float beerLaw(float density)
            {
                return exp(-density * 0.9);
            }
            
            float4 getColor(float3 ro, float3 rd, float2 ip, float costh)
            {
                float3 p = ro;
                float l = ip.y - ip.x;
                float step = ceil(l / _StepSize);
                float3 col = 0;
                float transmission = 1;
                
                [loop]
                for (int i = 0; i < step; i++)
                {
                    // float d = tex3D(_Perlin, p * 0.5);
                    //
                    // // if (d < .1)
                    // //     d = 0;
                    
                    float atten = beerLaw(_StepSize * sampleDensity(p) * _Density);
                    transmission *= atten;

                    float l = boxIntersection(p, _WorldSpaceLightPos0.xyz, _Bound).y;
                     int lightStepSize = l / 6;
                    
                    float lightDensity = 0;
                    float l0 = p;
                     for (int j = 0; j < 6; j++)
                     {
                         float density = sampleDensity(l0);
                         lightDensity += density * lightStepSize;
                         l0 +=  _WorldSpaceLightPos0.xyz * lightStepSize;
                     }
                    float lightAtten = beerLaw(lightDensity * _Density );
                    
                    col += transmission * lightAtten * _StepSize   * _LightColor0.xyz * 0.5 * HenyeyGreenstein(_AsymmetryFactor , costh) * _Brightness;
                    //col+= transmission *  _Color.rgb * _StepSize;
                    
                    if (transmission <= 0.01)
                    {
                        transmission = 0;
                        break;
                    }
                    
                    p += rd * _StepSize ;
                }
                // float d = tex3D(_Perlin, ro * 0.5 );
                //
                // return d;
                
                return float4(col.rgb , 1 - transmission);
            }
            
            fixed4 frag (v2f i) : SV_Target
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
                float3 oN = 0;
                //return float4(d.xxx + 100,1);
                float2 ip = boxIntersection(ro, rd, _Bound, oN);

                
                int rayHit = step(d,min(100, sceneDistance));

                if (ip.x == -1)
                {
                    return 0;
                }
                float cosTheta = dot(-rd, _WorldSpaceLightPos0.xyz);
                float4 color = getColor(ro + rd * d, rd, ip, cosTheta);
                
                
                float b = saturate(dot(_WorldSpaceLightPos0.xyz, oN));
                float3 col = rayHit * b;
                //return float4(col, rayHit);
                return float4(color.rgb, color.a * rayHit);
            }
            ENDCG
        }
    }
}
