Shader "rv32vrc/convert-rgba8-to-rgba32f"
{
    Properties
    {
        _MainTex ("Flash Memory (source)", 2D) = "black" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
			Name "Convert RGBA8 (non-SRGB) to RGBA32F"
			
            CGPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "/Assets/flexcrt/flexcrt.cginc"

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

			Texture2D<float4> _MainTex;
			float4 _MainTex_TexelSize;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            uint4 frag (v2f i) : SV_Target
            {
				uint2 ocoord = i.uv * _CustomRenderTextureInfo.xy;
				//ocoord.y = _CustomRenderTextureInfo.y - ocoord.y - 1;  //(For now, don't, flip Y)
				uint2 idim;
				uint dummy;
				_MainTex.GetDimensions( 0, idim.x, idim.y, dummy );

				uint wordno = ( ocoord.y * _CustomRenderTextureInfo.x + ocoord.x ) * 4;
				uint2 coord = uint2( wordno % idim.x, wordno / idim.x );
                uint4 col0 = _MainTex[coord+uint2(0,0)] * 255.5;
                uint4 col1 = _MainTex[coord+uint2(1,0)] * 255.5;
                uint4 col2 = _MainTex[coord+uint2(2,0)] * 255.5;
                uint4 col3 = _MainTex[coord+uint2(3,0)] * 255.5;
                return uint4(
					col0.r + col0.g * 256 + col0.b * 65536 + col0.a * 16777216, 
					col1.r + col1.g * 256 + col1.b * 65536 + col1.a * 16777216, 
					col2.r + col2.g * 256 + col2.b * 65536 + col2.a * 16777216, 
					col3.r + col3.g * 256 + col3.b * 65536 + col3.a * 16777216
				);
            }
            ENDCG
        }
    }
}
