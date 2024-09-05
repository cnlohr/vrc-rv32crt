Shader "Unlit/MSDFTerminal"
{
	Properties
	{
		_TerminalData ("TerminalData", 2D) = "white" {}
		_FGColor ("Foreground Color", Color) = (1,1,1,1)	
	}
	SubShader
	{
		Tags {"Queue"="Transparent" "RenderType"="Transparent"}

		Pass
		{
			//ZWrite Off
			Blend SrcAlpha OneMinusSrcAlpha
		
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			// make fog work
			#pragma multi_compile_fog

			#include "UnityCG.cginc"
			#include "../MSDFShaderPrintf.cginc"
			#include "Packages/com.llealloo.audiolink/Runtime/Shaders/AudioLink.cginc"
		
			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				UNITY_FOG_COORDS(1)
				float4 vertex : SV_POSITION;
			};

			
			Texture2D< uint4 > _TerminalData;
			float4 _TerminalData_TexelSize;
			float4 _FGColor;
	
			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv;
				UNITY_TRANSFER_FOG(o,o.vertex);
				return o;
			}

			fixed4 frag (v2f i) : SV_Target
			{
				float4 col = 0.0;
				
				int lines = _TerminalData_TexelSize.w;
				int columns = _TerminalData_TexelSize.z;
				float2 inuv = i.uv;
				inuv.y = 1.0 - inuv.y;
				float2 uv = inuv * float2( columns, lines );
				int2 dig = floor( uv );

				float2 gradval = uv;
				float4 grad = float4( ddx(gradval), ddy(gradval) );


				dig = floor( uv );
				int val = _TerminalData.Load( int3(dig.xy,0 ));
				col = MSDFPrintChar( val, uv,  grad ).xxxy * _FGColor;
				
				// apply fog
				UNITY_APPLY_FOG(i.fogCoord, col);
				return col;
			}
			ENDCG
		}
	}
}
