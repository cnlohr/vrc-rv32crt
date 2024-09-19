Shader "Unlit/DebugSystemState"
{
	Properties
	{
		_MSDFTex ("MSDF Texture", 2DArray) = "white" {}
		_SystemMemory ("SystemMemory", 2D) = "white" {}
		_CoreNo ("Core No", int) = 0
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

			#define _UdonMSDFPrintf _MSDFTex
			#define sampler_UdonMSDFPrintf sampler_MSDFTex
			#define _UdonMSDFPrintf_TexelSize _MSDFTex_TexelSize

//			#include "/Packages/com.llealloo.audiolink/Runtime/Shaders/SmoothPixelFont.cginc"
			#include "/Assets/MSDFShaderPrintf/MSDFShaderPrintf.cginc"

			Texture2D<uint4> _SystemMemory;
			float4 _SystemMemory_TexelSize;
			float4 _SystemMemory_ST;
			uint _CoreNo;

			float4 PrintHex( uint4 val, float2 uv, float4 grad )
			{
				uv *= float2( 8, 1 );
				int charno = uv.x;
				int row = uv.y/7;
				uint dig = (val[3-row] >> (28-charno*4))&0xf;				
				return MSDFPrintChar( (dig<10)?(dig+48):(dig+87), float2( charno*4+uv.x+4, 1.0 - uv.y-row*7 ), grad ).xxxy;
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
				float2 uv = i.uv;
				uv.x *= 2;
				uv.y *= 26;
				uint col = uv.x;
				uint row = 26 - uv.y;
				uint group = row * 2 + col;
				
				uv.x = frac( uv );
				float4 color = 0;

				float4 grad = float4( ddx(uv), ddy(uv) );


				if( uv.x < 0 )
				{
					color = 0;
				}
				else
				{
					uv.x *= (16./8.);
					uv.x -= 0.5;
					
					if( uv.x < 0 )
					{
						uv.x += 0.5;
						uv *= float2( 8, 1 );
						int char = uv.x;
						uv = frac( uv );
						uv.x = uv.x;
						uint4 label[] = { 
							uint4( 0, __x, __0, __COLON ),
							uint4( 0, __r, __a, __COLON ),
							uint4( 0, __s, __p, __COLON ),
							uint4( 0, __g, __p, __COLON ),
							uint4( 0, __t, __p, __COLON ),
							uint4( 0, __t, __0, __COLON ),
							uint4( 0, __t, __1, __COLON ),
							uint4( 0, __t, __2, __COLON ),
							uint4( 0, __s, __0, __COLON ),
							uint4( 0, __s, __1, __COLON ),
							uint4( 0, __a, __0, __COLON ),
							uint4( 0, __a, __1, __COLON ),
							uint4( 0, __a, __2, __COLON ),
							uint4( 0, __a, __3, __COLON ),
							uint4( 0, __a, __4, __COLON ),
							uint4( 0, __a, __5, __COLON ),
							uint4( 0, __a, __6, __COLON ),
							uint4( 0, __a, __7, __COLON ),
							uint4( 0, __s, __2, __COLON ),
							uint4( 0, __s, __3, __COLON ),
							uint4( 0, __s, __4, __COLON ),
							uint4( 0, __s, __5, __COLON ),
							uint4( 0, __s, __6, __COLON ),
							uint4( 0, __s, __7, __COLON ),
							uint4( 0, __s, __8, __COLON ),
							uint4( 0, __s, __9, __COLON ),
							uint4( __s, __1, __0, __COLON ),
							uint4( __s, __1, __1, __COLON ),
							uint4( 0, __t, __3, __COLON ),
							uint4( 0, __t, __4, __COLON ),
							uint4( 0, __t, __5, __COLON ),
							uint4( 0, __t, __6, __COLON ),

							uint4( 0, __p, __c, __COLON ),
							uint4( __m, __s, __t, __COLON ),
							uint4( __c, __y, __c, __l ),
							uint4( __c, __y, __c, __h ),

							uint4( __t, __i, __m, __l ),
							uint4( __t, __i, __m, __h ),

							uint4( __t, __m, __l, __COLON ),
							uint4( __t, __m, __h, __COLON ),

							uint4( __s, __c, __r, __COLON ),
							uint4( __m, __t, __v, __COLON ),
							uint4( __m, __i, __e, __COLON ),
							uint4( __m, __i, __p, __COLON ),

							uint4( __m, __e, __p, __COLON ),
							uint4( __m, __t, __v, __a ),
							uint4( __m, __c, __a, __COLON ),
							uint4( __e, __x, __t, __COLON ),
							uint4( __s, __t, __e, __COLON ),
							uint4( __r, __0, __0, __COLON ),
							uint4( __r, __0, __0, __COLON ),
							uint4( __r, __0, __0, __COLON ),
						};
						float3 tcol[] = {
							float3( 0.4, 0.4, 0.4 ),
							float3( 1.0, 1.0, 1.0 ),
							float3( 0.0, 0.0, 1.0 ),
							float3( 1.0, 1.0, 1.0 ),
							float3( 0.0, 1.0, 1.0 ),
							float3( 0.0, 0.6, 0.6 ),
							float3( 0.0, 0.6, 0.6 ),
							float3( 0.0, 0.6, 0.6 ),
							float3( 1.0, 0.0, 1.0 ),
							float3( 1.0, 0.0, 1.0 ),
							float3( 1.0, 1.0, 0.0 ),
							float3( 1.0, 1.0, 0.0 ),
							float3( 1.0, 1.0, 0.0 ),
							float3( 1.0, 1.0, 0.0 ),
							float3( 1.0, 1.0, 0.0 ),
							float3( 1.0, 1.0, 0.0 ),
							float3( 1.0, 1.0, 0.0 ),
							float3( 1.0, 1.0, 0.0 ),
							float3( 1.0, 0.0, 1.0 ),
							float3( 1.0, 0.0, 1.0 ),
							float3( 1.0, 0.0, 1.0 ),
							float3( 1.0, 0.0, 1.0 ),
							float3( 1.0, 0.0, 1.0 ),
							float3( 1.0, 0.0, 1.0 ),
							float3( 1.0, 0.0, 1.0 ),
							float3( 1.0, 0.0, 1.0 ),
							float3( 1.0, 0.0, 1.0 ),
							float3( 1.0, 0.0, 1.0 ),
							float3( 0.0, 0.6, 0.6 ),
							float3( 0.0, 0.6, 0.6 ),
							float3( 0.0, 0.6, 0.6 ),
							float3( 0.0, 0.6, 0.6 ),
							float3( 1.0, 0.0, 0.0 ),
							float3( 0.0, 1.0, 0.0 ),
							float3( 0.4, 0.4, 0.4 ),
							float3( 0.4, 0.4, 0.4 ),
							float3( 0.4, 0.4, 0.4 ),
							float3( 0.4, 0.4, 0.4 ),
							float3( 0.4, 0.4, 0.4 ),
							float3( 0.4, 0.4, 0.4 ),
							float3( 0.0, 1.0, 0.0 ),
							float3( 0.0, 1.0, 0.0 ),
							float3( 0.0, 1.0, 0.0 ),
							float3( 0.0, 1.0, 0.0 ),
							float3( 0.0, 1.0, 0.0 ),
							float3( 0.0, 1.0, 0.0 ),
							float3( 0.0, 0.8, 0.0 ),
							float3( 0.0, 0.8, 0.0 ),
							float3( 1.0, 0.8, 0.0 ),
							float3( 0.0, 0.8, 0.0 ),
							float3( 0.0, 0.8, 0.0 ),
							float3( 0.0, 0.8, 0.0 ),
							};
						uv *= float2( 1, 1 );
						uv.y = 1.0-uv.y;
						color = float4( tcol[group], 1.0 ) * 
							//PrintChar( label[group][char], uv, 2.0/(length( ddx( uv ) ) + length( ddy( uv ) )), 0.0);
							MSDFPrintChar( label[group][char], uv, grad ).xxxy;
					}
					else
					{
						uint mcell = group/4;
						uint4 cell = _SystemMemory.Load( uint3( mcell, _SystemMemory_TexelSize.w-1-_CoreNo, 0 ) );
						if( uv.x > 1 )
						{
							uv.x *= 8.0;
							uint xcell = 12 - uv.x;
							uint digpair = (cell[group%4]>>(xcell*8)) & 0xff; 
							uv.y = frac( uv.y );
							uv.y = 1.0 - uv.y;
							if( digpair )
							{
								float charness = MSDFPrintChar( digpair, uv, grad ).xxxy;
								color = charness * 0.2;
							}
						}
						else
						{
							color = PrintHex( cell[group%4], frac(uv), grad );
						}
					}
				}
				UNITY_APPLY_FOG(i.fogCoord, color);
				return color;
			}
			ENDCG
		}
	}
}
