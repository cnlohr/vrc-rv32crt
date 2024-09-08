Shader "rv32im/TerminalFromDescriptor"
{
	Properties
	{
		_SystemRam ("System RAM", 2D) = "white" {}
		[Toggle(_ShowHex)] _ShowHex ("Show Hex", float) = 0.0
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" }

		Pass
		{			
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma target 5.0
			#pragma multi_compile_local _ _ShowHex

			
			#define _SelfTexture2D _SystemRam
			#define _SelfTexture2D_TexelSize _SystemRam_TexelSize
			
//			Texture2D<uint4> _SystemRam;
//			float4 _SystemRam_TexelSize;
			
			#include "UnityCG.cginc"
			#include "../vrc-rv32im.cginc"
			#include "../gpucache.h"
			
			float PrintHex( uint val, float2 uv )
			{
				uv.x = 1.0 - uv.x;
				uv *= float2( 8, 7 );
				int charno = uv.x/4;
				int row = uv.y/7;
				uint dig = (val >> (4-charno*4))&0xf;
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
				nointerpolation uint  advanced_descritptor : AD;
				nointerpolation uint  term : TM;
				nointerpolation uint  termscroll : TC;
				nointerpolation uint2 termsize : TS;
				UNITY_FOG_COORDS(1)
			};
			
			
			uint LoadMemInternalRBNoCache( uint ptr )
			{
				uint remainder4 = ((ptr&0xc)>>2);
				uint4 ret = 0;
				
				if( ptr < MEMORY_SPLIT )
				{
					uint blockno = ptr >> 4;
					ret = FlashSystemAccess( blockno );	
				}
				else
				{
					ptr -= MEMORY_SPLIT;
					uint blockno = ptr >> 4;
					ret = MainSystemAccess( blockno );
				}
				return U4Select( ret, remainder4 );
			}

			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv;

				uint advanced_descritptor = _SelfTexture2D[uint2(12, _SelfTexture2D_TexelSize.w - 1)].y;

				o.advanced_descritptor = advanced_descritptor;
				o.term = LoadMemInternalRB( advanced_descritptor - MINIRV32_RAM_IMAGE_OFFSET + 0x0c ) - MINIRV32_RAM_IMAGE_OFFSET;
				o.termsize = uint2(
						LoadMemInternalRB( advanced_descritptor - MINIRV32_RAM_IMAGE_OFFSET + 0x00 ),
						LoadMemInternalRB( advanced_descritptor - MINIRV32_RAM_IMAGE_OFFSET + 0x04 ) );
				o.termscroll = LoadMemInternalRB( advanced_descritptor - MINIRV32_RAM_IMAGE_OFFSET + 0x08 );

				UNITY_TRANSFER_FOG(o,o.vertex);
				return o;
			}

			float4 frag (v2f i) : SV_Target
			{
				float2 uv = i.uv;
				
				uint2 termsize = i.termsize;

				uv *= termsize;
				uint2 coord = uint2( uv.x, termsize.y-uv.y );
				uv.x = frac( uv );
				float4 color = 0;

				uv.x = 1.0 - uv.x;
				
				uint u = LoadMemInternalRBNoCache( i.term + coord.x * 4 + ( ( coord.y + i.termscroll ) % i.termsize.y ) * 4 * termsize.x );
				
				color = PrintChar( u, uv * float2( 4.0, 8.0 ), 2.0/(length( ddx( uv ) ) + length( ddy( uv ) )), 0.0);
#ifdef _ShowHex
				float phv = PrintHex( u, uv ).x;
				color = color * float4( 1.0-phv*2.0, 1.0, 1.0, 1.0 ) + float4( phv * 0.5, 0, 0, 0);
#endif
				UNITY_APPLY_FOG(i.fogCoord, color);
				return color;
			}
			ENDCG
		}
	}
}
