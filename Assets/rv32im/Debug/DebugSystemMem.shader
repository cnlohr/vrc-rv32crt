Shader "Unlit/DebugSystemMem"
{
	Properties
	{
		_SystemMemory ("SystemMemory", 2D) = "white" {}
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" }

		Pass
		{			
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#pragma multi_compile_fog

			#pragma target 5.0

			#include "UnityCG.cginc"

			#include "/Packages/com.llealloo.audiolink/Runtime/Shaders/SmoothPixelFont.cginc"

			Texture2D<uint4> _SystemMemory;
			float4 _SystemMemory_TexSize;
			float4 _SystemMemory_ST;

			float PrintHex( uint4 val, float2 uv )
			{
				uv *= float2( 32, 7*4 );
				int charno = uv.x/4;
				int row = uv.y/7;
				uint dig = (val[3-row] >> (28-charno*4))&0xf;
				return PrintChar( (dig<10)?(dig+48):(dig+87), float2( charno*4-uv.x+4, uv.y-row*7 ), 2.0/(length( ddx( uv ) ) + length( ddy( uv ) )), 0.0);
			}

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float4 vertex : SV_POSITION;
				float2 uv : TEXCOORD0;
				UNITY_FOG_COORDS(1)
			};

			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv;
				UNITY_TRANSFER_FOG(o,o.vertex);
				return o;
			}

			float4 frag (v2f i) : SV_Target
			{
				float4 col = PrintHex( _SystemMemory.Load( uint3( 0, 0, 0 ) ), i.uv );
				UNITY_APPLY_FOG(i.fogCoord, col);
				return col;
			}
			ENDCG
		}
	}
}
