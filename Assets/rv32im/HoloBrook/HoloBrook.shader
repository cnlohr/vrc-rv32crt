Shader "Unlit/HoloBrook"
{
    Properties
    {
		_FlashMemory( "Flash Memory", 2D ) = "black" { }
		_SystemRam ("System RAM", 2D) = "white" {}
		_BackScreenFromCamera( "Back Screen From Camera", 2D) = "black" { }
		_MSDFTex ("MSDF Texture", 2DArray) = "white" {}
    }
    SubShader
    {

        Pass
        {
			Tags { "RenderType"="Opaque" }
			Cull Off
			
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma geometry geo
			#pragma target 5.0
            #pragma multi_compile_fog
			#pragma multi_compile_instancing

			#define _SelfTexture2D _SystemRam
			#define _SelfTexture2D_TexelSize _SystemRam_TexelSize

			#define _UdonMSDFPrintf _MSDFTex
			#define sampler_UdonMSDFPrintf sampler_MSDFTex
			#define _UdonMSDFPrintf_TexelSize _MSDFTex_TexelSize

			#include "UnityCG.cginc"
			#include "../vrc-rv32im.cginc"
			#include "../gpucache.h"
			#include "/Assets/MSDFShaderPrintf/MSDFShaderPrintf.cginc"

            struct appdata
            {
				uint	vertexID : SV_VertexID;
				UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2g
            {
				uint  advanced_descritptor : AD;
				uint  this_descriptor : TD;
				uint  vertexID : VID;
				
				float4x4 matrixxform : MAT;
				UNITY_VERTEX_OUTPUT_STEREO
            };

            struct g2f
            {
                float4 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
				float3 norm : NORMAL;
                UNITY_FOG_COORDS(1)
				UNITY_VERTEX_OUTPUT_STEREO
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;

			float4x4 GenTransform( uint mode, uint ptr )
			{
				if( !ptr || (ptr & 15) ) mode = 0;

				float4 transcale = float4( 0.0, 0.0, 0.0, 1.0 );
				float4 q = float4( 1.0, 0.0, 0.0, 0.0 );

				if( mode == 1 )
				{
					uint4 intTS = LoadMemInternalBlockNoCache( ptr );
					uint4 intQ  = LoadMemInternalBlockNoCache( ptr + 16 );
					transcale = intTS * 1.0 / 4096.0;
					q = intQ;
				}
				else if( mode == 2 )
				{
					uint4 intTS = LoadMemInternalBlockNoCache( ptr );
					uint4 intQ  = LoadMemInternalBlockNoCache( ptr + 16 );
					transcale = intTS * 1.0 / 4096.0;
					
					
					float X = intQ.x / 4096.0 * 3.1415926536 / 1.0f; // roll
					float Y = intQ.y / 4096.0 * 3.1415926536 / 1.0f; // pitch
					float Z = intQ.z / 4096.0 * 3.1415926536 / 1.0f; // yaw
					float cx = cos(X);
					float sx = sin(X);
					float cy = cos(Y);
					float sy = sin(Y);
					float cz = cos(Z);
					float sz = sin(Z);

					// Correct according to
					// http://en.wikipedia.org/wiki/Conversion_between_MQuaternions_and_Euler_angles
					q[0] = cx * cy * cz + sx * sy * sz; // q1
					q[1] = sx * cy * cz - cx * sy * sz; // q2
					q[2] = cx * sy * cz + sx * cy * sz; // q3
					q[3] = cx * cy * sz - sx * sy * cz; // q4
				}
				else if( mode == 3 )
				{
					int4 blk0 = LoadMemInternalBlockNoCache( ptr );
					int4 blk1 = LoadMemInternalBlockNoCache( ptr + 16 );
					int4 blk2 = LoadMemInternalBlockNoCache( ptr + 32 );
					int4 blk3 = LoadMemInternalBlockNoCache( ptr + 48 );
					//if( blk3.w > 4095 )
					//	return float4x4( 1, 0, 0, 0,  0, 1, 0, 0,  0, 0, 1, 0,  0, 0, 0, 1 );				
					float4 i0 = ((float4)blk0) * 1.0 / 4096.0;
					float4 i1 = ((float4)blk1) * 1.0 / 4096.0;
					float4 i2 = ((float4)blk2) * 1.0 / 4096.0;
					float4 i3 = ((float4)blk3) * 1.0 / 4096.0;
					return transpose( float4x4( i0, i1, i2, i3 ) );
				}

				q = normalize( q );
				
				// Reduced calculation for speed
				
				float xx = 2 * q[1] * q[1];
				float xy = 2 * q[1] * q[2];
				float xz = 2 * q[1] * q[3];
				float xw = 2 * q[1] * q[0];

				float yy = 2 * q[2] * q[2];
				float yz = 2 * q[2] * q[3];
				float yw = 2 * q[2] * q[0];

				float zz = 2 * q[3] * q[3];
				float zw = 2 * q[3] * q[0];
				
				float scaleX, scaleY, scaleZ;
				scaleX = scaleY = scaleZ = transcale.w;
				
				return float4x4(
					scaleX * (1 - yy - zz),
					scaleX * (xy - zw),
					scaleX * (xz + yw),
					transcale.x,				
			
					scaleY * (xy + zw),
					scaleY * (1 - xx - zz),
					scaleY * (yz - xw),
					transcale.y,

					scaleZ * (xz - yw),
					scaleZ * (yz + xw),
					scaleZ * (1 - xx - yy),
					transcale.z,

					0,
					0,
					0,
					1 );
			
				//return float4x4( 1, 0, 0, 0,  0, 1, 0, 0,  0, 0, 1, 0,  0, 0, 0, 1 );
			}
			

            v2g vert (appdata v)
            {
                v2g o;
				UNITY_SETUP_INSTANCE_ID( v );
				UNITY_INITIALIZE_OUTPUT( v2g, o );
				
				uint advanced_descritptor = o.advanced_descritptor = (_SelfTexture2D[uint2(12, _SelfTexture2D_TexelSize.w - 1)].y );
				uint descriptor = o.this_descriptor = advanced_descritptor ? (LoadMemInternalRB( advanced_descritptor + 68 + v.vertexID * 4) ): 0;
				
				o.vertexID = v.vertexID; // Always zero?
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO( o );

				if( descriptor )
				{
					uint nModeAndNum = LoadMemInternalRB( descriptor );
					uint nNumTris = nModeAndNum & 0xffff;
					uint nMode = (nModeAndNum >> 16);
					
					uint nTransModes = LoadMemInternalRB( descriptor + 4 );
					
					uint nPList = LoadMemInternalRB( descriptor + 16 );
					
					uint4 pXform0Ptr = LoadMemInternalRB( descriptor + 32 );
					uint4 pXform1Ptr = LoadMemInternalRB( descriptor + 36 );
					uint4 pXform2Ptr = LoadMemInternalRB( descriptor + 40 );
					uint4 pXform3Ptr = LoadMemInternalRB( descriptor + 44 );
					
					float4x4 pXform0 = GenTransform( (nTransModes >> 0 )  & 0xff, pXform0Ptr );
					float4x4 pXform1 = GenTransform( (nTransModes >> 8 )  & 0xff, pXform1Ptr );
					float4x4 pXform2 = GenTransform( (nTransModes >> 16 ) & 0xff, pXform2Ptr );
					float4x4 pXform3 = GenTransform( (nTransModes >> 24 ) & 0xff, pXform3Ptr );
					
					o.matrixxform = mul( mul( mul( pXform3, pXform2 ), pXform1), pXform0 );
				}
				else
				{
					o.matrixxform = float4x4( 1, 0, 0, 0,  0, 1, 0, 0,  0, 0, 1, 0,  0, 0, 0, 1 );
				}

                return o;
            }


			[maxvertexcount(48)] // 16 Triangles.
			[instance(32)]       // 32 instances = Up to 512 triangles.
			void geo(point v2g pin[1], inout TriangleStream<g2f> triStream, 
				uint instanceID : SV_GSInstanceID, uint geoPrimID : SV_PrimitiveID )
			{
				v2g p = pin[0];
				UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(p);
				int triBase = instanceID * 16;
				int tri = triBase;
				uint descriptor = p.this_descriptor;
				if( descriptor == 0 ) return;
				
				/*									
					struct holoSteamObject
					{
						uint16_t nNumberOfTriangles;
						uint16_t nMode;
						uint16_t nReserved;
						uint16_t nReserved2;
						const uint32_t * pTriangleList;
						const uint32_t * pReserved1; // UNUSED
						
						struct holoTransform * pXform1;
						const uint32_t * pReserved2; // UNUSED
						struct holoTransform * pXform2;
						const uint32_t * pReserved3; // UNUSED
					} __attribute__((packed));
				*/

				uint nModeAndNum = LoadMemInternalRB( descriptor );
				uint nNumTris = nModeAndNum & 0xffff;
				uint nMode = (nModeAndNum >> 16);
				
				uint nTransModes = LoadMemInternalRB( descriptor + 4 );
				
				uint nPList = LoadMemInternalRB( descriptor + 16 );
				
				//pXform1B = float4( 1, 0, 0, 0 );
				g2f o;
				UNITY_INITIALIZE_OUTPUT( g2f, o );
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO( o );
				
				int i;
				
				float rescale = 1.0 / 4096.0;
				
				for( i = 0; i < 32; i++ )
				{
					if( tri > nNumTris ) break;
					
					int4 pdTA = LoadMemInternalBlockNoCache( nPList + ( tri * 3 + 0 ) * 16 );
					int4 pdTB = LoadMemInternalBlockNoCache( nPList + ( tri * 3 + 1 ) * 16 );
					int4 pdTC = LoadMemInternalBlockNoCache( nPList + ( tri * 3 + 2 ) * 16 );
					
					float4 pTA = pdTA;
					float4 pTB = pdTB;
					float4 pTC = pdTC;

					// vector rotate quat.
					//( pTB.xyz + 2.0 * cross(pXform1B.xyz, cross(pXform1B.xyz, pTB.xyz) + pXform1B.w * pTB.xyz) ) * pXform1A.w + pXform1A.xyz;
					pTA.xyz = mul( p.matrixxform, float4( pTA.xyz, 4096.0 ) );
					pTB.xyz = mul( p.matrixxform, float4( pTB.xyz, 4096.0 ) );
					pTC.xyz = mul( p.matrixxform, float4( pTC.xyz, 4096.0 ) );

					o.norm = cross( pTC.xyz - pTA.xyz, pTB.xyz - pTA.xyz );
					
					o.vertex = mul(UNITY_MATRIX_VP, float4( pTA.xyz * rescale, 1 ) );
					o.uv = float4( pdTA.w&0xff, (pdTA.w>>8)&0xff, (pdTA.w>>16)&0xff, (pdTA.w>>24)&0xff );
					UNITY_TRANSFER_FOG(o,o.vertex);
					triStream.Append(o);
					o.vertex = mul(UNITY_MATRIX_VP, float4( pTB.xyz * rescale, 1 ) );
					o.uv = float4( pdTB.w&0xff, (pdTB.w>>8)&0xff, (pdTB.w>>16)&0xff, (pdTB.w>>24)&0xff );
					UNITY_TRANSFER_FOG(o,o.vertex);
					triStream.Append(o);
					o.vertex = mul(UNITY_MATRIX_VP, float4( pTC.xyz * rescale, 1 ) );
					o.uv = float4( pdTC.w&0xff, (pdTC.w>>8)&0xff, (pdTC.w>>16)&0xff, (pdTC.w>>24)&0xff );
					UNITY_TRANSFER_FOG(o,o.vertex);
					triStream.Append(o);
					triStream.RestartStrip();
					tri++;
				}
			}

            fixed4 frag (g2f i) : SV_Target
            {
				UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
				float4 col = 1.0;
				int mode = i.uv.a + 0.5;
				if( mode == 1 )
				{
					col = float4( i.uv.rgb / 255.0, 1.0 );
					col *= 0.5 * dot( -normalize( i.norm ), _WorldSpaceLightPos0.xyz ) + 0.5;
				}
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
    }
}
