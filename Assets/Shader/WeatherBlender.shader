Shader "Hidden/WeatherBlender"
{
    SubShader
    {

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work

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

            uniform sampler2D _Prev;
            uniform sampler2D _Next;
            uniform float _LerpVal;

            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;

                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                float2 uv = i.uv;
                float4 col = float4(0, 0, 0, 0);

                float4 p = tex2D(_Prev, uv);
                float4 n = tex2D(_Next, uv);

                col = lerp(p, n, _LerpVal);

                return col;
            }
            ENDCG
        }
    }
}