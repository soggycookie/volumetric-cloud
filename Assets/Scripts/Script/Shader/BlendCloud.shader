Shader "Hidden/BlendCloud"
{
    Properties
    {
        _MainTex("Main Tex", 2D) = "white" {}
        _CloudTex("Cloud Tex", 2D) = "white" {}
    }
    SubShader
    {
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 3.0

            #include "UnityCG.cginc"


            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv: TEXCOORD0;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
                float4 screenPos: TEXCOORD1;
            };

            sampler2D _MainTex;
            sampler2D _CloudTex;
			float4 _MainTex_TexelSize;
            sampler2D _CameraDepthTexture;
            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                #if UNITY_UV_STARTS_AT_TOP
                if (_MainTex_TexelSize.y < 0)
                    o.uv.y = 1 - o.uv.y;
                #endif
                
                o.screenPos = ComputeScreenPos(o.vertex);
                
                return o;
            }


            fixed4 frag(v2f i) : SV_Target
            {
                float2 uv = i.uv;
                float4 col;
                float4 bg = tex2D(_MainTex, uv);
                float4 cloud = tex2D(_CloudTex, uv);
                
                float2 screenUV = i.screenPos.xy / i.screenPos.w;
                float depth01 = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, screenUV);
                
                col = float4(bg.rgb * (1 - cloud.a) + cloud.rgb , 1);

                //return depth01;
                return col;
            }
            ENDCG
        }
    }
}