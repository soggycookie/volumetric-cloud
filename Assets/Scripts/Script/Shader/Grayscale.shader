Shader "Custom/MultiRenderTargetShader" {
 Properties {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader {
        Pass {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            sampler2D _MainTex;
            float4 _MainTex_ST;

            struct appdata {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            struct MRT {
                fixed4 color0 : SV_Target0;  // First render texture
                fixed4 color1 : SV_Target1;  // Second render texture
            };

            v2f vert (appdata v) {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

            MRT frag (v2f i) {
                MRT o;
                
                // Sample the camera texture
                fixed4 texColor = tex2D(_MainTex, i.uv);
                
                // Render the same camera texture to both render targets
                o.color0 = texColor;
                o.color1 = texColor;
                
                return o;
            }
            ENDCG
        }
    }
}

