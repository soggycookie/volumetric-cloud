Shader "Hidden/WeatherMapCombiner"
{
    Properties
    {
        _R ("Texture R", 2D) = "white" {}
        _G ("Texture G", 2D) = "white" {}
        _B ("Texture B", 2D) = "white" {}
        _A ("Texture A", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag


            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            sampler2D _R, _G, _B, _A;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                
                return o;
            }

            float maxComponent(float4 col)
            {
                return max(col.x, max(col.y, col.z));
            }
            
            float4 frag (v2f i) : SV_Target
            {
                float r = (tex2D(_R, i.uv).r);
                float g = (tex2D(_G, i.uv).r);
                float b = (tex2D(_B, i.uv).r);
                float a = (tex2D(_A, i.uv).r);

                float4 col = float4(r,g,b,a);
                
                return col;
            }
            ENDCG
        }
    }
}
