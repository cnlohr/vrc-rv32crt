Shader "rv32im/backscreen-process"
{
	Properties
	{
		_CamData ("Camera Data", 2D) = "white" {}
	}

	CGINCLUDE
		#pragma vertex DefaultCustomRenderTextureVertexShader
		#pragma fragment frag
		#pragma multi_compile_fog
		#pragma target 5.0

		#define CRTTEXTURETYPE uint4

		#include "/Assets/flexcrt/flexcrt.cginc"
	ENDCG


	SubShader
	{
		Tags { }
		ZTest always
		ZWrite Off

		Pass
		{
			Name "Compile Touch Screen Data"
			
			CGPROGRAM

			struct v2f
			{
				float4 vertex		   : SV_POSITION;
				float2 uv : TEXCOORD0;
				uint2 batchID : TEXCOORD0;
			};
			
			Texture2D< float4 > _CamData;
			
			float4 frag( v2f_customrendertexture IN ) : SV_Target
			{
				uint2 coord = uint2( IN.globalTexcoord.xy * _CustomRenderTextureInfo.xy );
				coord.y = _CustomRenderTextureInfo.y - coord.y - 1;
				
				if( coord.y == 0 )
				{
					if( coord.x < 4 )
					{
						if( coord.x == 2 )
						{
							// Last 3 are free!
							return asfloat( uint4( _Time.y * 1000, 0 /* Still to do */, _CamData[uint2(8,127)].r * 65536, 0 ) );
						}
						else if( coord.x == 3 )
						{
							return 0.0; // Free!
						}
						else
						{
							return asfloat( int4( 0, 0, 0 ,0 ) );
						}
					}
					float4 cvo = float4( 
						_CamData[uint2(coord.x*4+0,127)].r,
						_CamData[uint2(coord.x*4+1,127)].r,
						_CamData[uint2(coord.x*4+2,127)].r,
						_CamData[uint2(coord.x*4+3,127)].r ) * 16777216;
					float4 cvoi = float4( 
						_CamData[uint2(coord.x*4+0,126)].r,
						_CamData[uint2(coord.x*4+1,126)].r,
						_CamData[uint2(coord.x*4+2,126)].r,
						_CamData[uint2(coord.x*4+3,126)].r ) * 16777216;
					return asfloat( int4( ( cvo - cvoi ) * 4096 ) );
				}
				else if( coord.x < 8 && coord.y <= 8 )
				{
					uint xs, ys;
					float highest = 0;
					float2 huv = 0.0;
					
					for( ys = 0; ys < 8; ys++ )
					for( xs = 0; xs < 8; xs++ )
					{
						int2 c = uint2( coord.x*8+xs, (coord.y-1)*8+ys+64 );
						float fv = _CamData[c];
						if( fv > highest && c.y < 126)
						{
							float fu = _CamData[c + int2(0,-1)] - fv;
							float fd = _CamData[c + int2(0,1)] - fv;
							float fl = _CamData[c + int2(-1,0)] - fv;
							float fr = _CamData[c + int2(1,0)] - fv;
							
							// Find X-centroid.
							//
							//       FV
							//   FU      FD
							//
							//  
							float fyv = (fd - fu) / 2.0 / ( - min( fu, fd ) );
							float fxv = (fr - fl) / 2.0 / ( - min( fr, fl ) );
							//fyv = fxv = 0;
							huv = float2( fxv + c.x, fyv + c.y - 64.0 );
							highest = fv;
						}
					}
					
					return float4( huv, highest, 0 );
				}
				
				return float4( coord, 0.0, 1.0 );
			}
			ENDCG
		}
		
		Pass
		{
			Name "Find Touch Centroid"
			
			CGPROGRAM

			struct v2f
			{
				float4 vertex		   : SV_POSITION;
				float2 uv : TEXCOORD0;
				uint2 batchID : TEXCOORD0;
			};
			
			Texture2D< float4 > _CamData;
			
			float4 frag( v2f_customrendertexture IN ) : SV_Target
			{
				uint2 coord = uint2( IN.globalTexcoord.xy * _CustomRenderTextureInfo.xy );
				coord.y = _CustomRenderTextureInfo.y - coord.y - 1;
				if( coord.x > 1 || coord.y != 0 ) { discard; return 0.0; }
				
				float zDep0 = 0;
				float zDep1 = 0;
				float2 c0 = 0;
				float2 c1 = 0;
				int x, y;
				for( y = 0; y < 8; y++ )
				for( x = 0; x < 8; x++ )
				{
					float4 ft = asfloat( _SelfTexture2D[uint2( x , y )] );
					if( ft.z > zDep0 )
					{
						zDep1 = zDep0;
						c1 = c0;
						zDep0 = ft.z;
						c0 = ft.xy;
					}
					else if( ft.z > zDep1 )
					{
						zDep1 = ft.z;
						c1 = ft.xy;
					}
				}
				
				c0 /= 64.0;
				c1 /= 64.0;
				
				if( coord.x == 0 )
					return asfloat( uint4( c0*4096, zDep0*4096, 0 ) );
				if( coord.x == 1 )
					return asfloat( uint4( c1*4096, zDep1*4096, 0 ) );
				
				// Next 2 are reserved.
				
				return float4( 1.0, 0.0, 0.0, 1.0 );
			}
			ENDCG
		}
	}
}
