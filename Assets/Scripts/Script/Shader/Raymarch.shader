Shader "Unlit/Raymarch"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Position ("Position", vector) = (0,0,0,0)
        _Height ("Height", float) = 1
        _HeightGradientPower("Height gradient power", float) = 1
        _Color ("Color", COLOR) = (1, 1, 1, 1)
        _HighlightColor("Outline color", Color) = (1, 1, 1, 1)
        _OutlinePower("Outline power", float) = 1
        _OutlineOffset("Outline offset", float) = 0.1
        _Brightness("Brightness", float) = 1
        _SmoothPower("Smooth Power", float) = 0.5
    }
    SubShader
    {
        Tags { "Queue"= "Transparent" "RenderType"="Transparent" "LightMode"="ForwardBase" }
        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite Off
        Cull Off
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"
            #include "UnityLightingCommon.cginc"
            #include "RayMarchUtilities.cginc"

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

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float4 _Position;
            float _Height;
            float _HeightGradientPower;
            float4 _Color;
            float4 _HighlightColor;
            float _OutlinePower;
            float _OutlineOffset;
            float _Brightness;
            float _SmoothPower;



            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.screenPos = ComputeScreenPos(o.vertex);
                o.wPos  = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.depth = o.vertex.z;
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }
            

            float GetDist(float3 p) {
	            float4 s1 = float4(_Position.xyzw);
	            //float4 s2 = float4(_Position.xyz + float3(0.5 ,7 , 0.2), 1);
	            float4 s3 = float4(_Position.xyz + float3(0 , 6 , 0 ), 0.8);
	            float4 s4 = float4(_Position.xyz + float3(0 ,8 , 0  ), 0.9);
	            float4 s5 = float4(_Position.xyz + float3(-0.4  ,10 ,-0.5), 1.4);
                
                float box = sdBox(p, float3(3,8,2), float3(2,6,2));
                
                s5.xz += cos(_Time.x * 3.5 + 5) * 0.3;
                s5.y += sin(_Time.x * 2.2) * 0.5;


                //s2.y += cos(_Time.x * 2.7 -2) * 4;
                //s2.xz += cos(_Time.x * 1.2) * 1.2;

                s3.y -= sin(_Time.x * 3.3 + s3.y) * 5;
                s3.z -= cos(_Time.y) * 1.2;

                s4.y += cos(_Time.x * 6.2) * 4 + sin(_Time.x) * 2;
                s4.z += sin(_Time.x * 1.2) * 0.6;

                float sd1 = sdSphere(p, s1);
                //float sd2 = sdSphere(p, s2);
                float sd3 = sdSphere(p, s3);
                float sd4 = sdSphere(p, s4);
                float sd5 = sdSphere(p, s5);
                
                float d = smin(sd1, sd3, _SmoothPower);
                d= smin(d, sd4, _SmoothPower);
                d= smin(d, sd5, _SmoothPower);

                d = opSmoothIntersection(d, box, _SmoothPower);
                //d= sd1;

                return d;
            }


            
            float Fresnel(float3 d, float3 n, float power){
                return pow(1 - saturate(dot(n, d)), power);
            }
            
            float3 BRDF(float3 normal, float3 rd){
                float3 objCol = float3(0.1,0.4, 1) ;
                float3 lightCol = _LightColor0.xyz;


                float3 lightDir =_WorldSpaceLightPos0.xyz ;
                float3 halfVec = -rd + lightDir;
                
                float  dif = saturate(dot(normal, lightDir));
                float3 difCol =  dif * lightCol;

                float3 ambientCol = 0.1 * lightCol ;


                float  spec = saturate(dot(halfVec, normal)) ;
                float3 specCol = pow(spec, 3) * spec * lightCol * 0.5;
                float3 col = objCol * (ambientCol + difCol + specCol);

                return col;
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

                float alpha = 1;
                
                float3 p = ro + rd * d; 
                float h = p.y / _Height;
                h = 1 -h;
                h = pow(h, _HeightGradientPower);


                float3 normal = GetNormal(p);
                float f = Fresnel(-rd, normal, _OutlinePower );
                float u = 1 - (saturate(dot(normal,float3(0,1,0))) * 0.9);

                float t = 1 -   f * h ;
                float3 col =  _Brightness * u  ;
                col = _Color * t + _HighlightColor * (1 - t);
                col *= u * h * _Brightness;


                if(d >= MAX_DIST|| d >= sceneDistance){
                    alpha = 0;
                }


                return float4(col, alpha);
            }
            ENDCG
        }
    }
}
