Shader "rv32im/backscreen"
{
    Properties
    {
		_SystemRam ("System RAM", 2D) = "white" {}
		[Toggle(_ShowHex)] _ShowHex ("Show Hex", float) = 0.0
		_WhichTerminal ("Which Terminal", int) = 0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        Pass
        {
			Cull Back
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma target 5.0
			#pragma multi_compile_local _ _ShowHex

			#define _SelfTexture2D _SystemRam
			#define _SelfTexture2D_TexelSize _SystemRam_TexelSize
			
			#include "UnityCG.cginc"
			#include "../vrc-rv32im.cginc"
			#include "../gpucache.h"
			#include "/Assets/MSDFShaderPrintf/MSDFShaderPrintf.cginc"

			uint _WhichTerminal;

			float PrintHex( uint val, float2 uv, float grad )
			{
				//uv.x = 1.0 - uv.x;
				uv *= float2( 2, 1 );
				int charno = uv.x;
				int row = uv.y/7;
				uint dig = (val >> (4-charno*4))&0xf;
				return MSDFPrintChar( (dig<10)?(dig+48):(dig+87), float2( charno*4+uv.x+4, 1.0 - uv.y-row*7 ), grad ).xxxy;
				//return MSDFPrintChar( (dig<10)?(dig+48):(dig+87), float2( charno*4-uv.x+4, uv.y-row*7 ), 2.0/(length( ddx( uv ) ) + length( ddy( uv ) )), 0.0);
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
				nointerpolation uint2 termscroll : TC;
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
				o.term = LoadMemInternalRB( advanced_descritptor + 0x10 + _WhichTerminal * 0x20 );
				o.termsize = uint2(
						LoadMemInternalRB( advanced_descritptor + 0x00 + _WhichTerminal * 0x20 ),
						LoadMemInternalRB( advanced_descritptor + 0x04 + _WhichTerminal * 0x20 ) );
				o.termscroll = uint2(
						LoadMemInternalRB( advanced_descritptor + 0x08 + _WhichTerminal * 0x20 ),
						LoadMemInternalRB( advanced_descritptor + 0x0c + _WhichTerminal * 0x20 ) );

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

//				uv.x = 1.0 - uv.x;
				float4 grad = float4( ddx(uv), ddy(uv) );
				float4 gradC = float4( ddx(coord), ddy(coord) );
				
				// Blank corners.
				if( length(gradC)>0.0 ) return 0.0;
			
				uint u = LoadMemInternalRBNoCache( i.term + ( ( ( coord.x + i.termscroll.x ) % i.termsize.x ) * 4 ) + ( ( coord.y + i.termscroll.y ) % i.termsize.y ) * 4 * termsize.x );
				
				{
					float2 tuv = float2( uv.x, 1.0 - uv.y );
					//tuv.y = floor( tuv.y ) + frac( tuv.y ) * .9 + 0.1;
					color = MSDFPrintChar( u, tuv, grad ).xxxy;
				}
#ifdef _ShowHex
				float phv = PrintHex( u, uv, grad ).x;
				color = color * float4( 1.0-phv*2.0, 1.0, 1.0, 1.0 ) + float4( phv * 0.5, 0, 0, 0);
#endif
				UNITY_APPLY_FOG(i.fogCoord, color);
				return color;
			}
			ENDCG
        }
    }
}
