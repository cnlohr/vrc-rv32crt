Shader "Unlit/HoloBrook"
{
    Properties
    {
		_FlashMemory( "Flash Memory", 2D ) = "black" { }
		_SystemRam ("System RAM", 2D) = "white" {}
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

            v2g vert (appdata v)
            {
                v2g o;
				UNITY_SETUP_INSTANCE_ID( v );
				UNITY_INITIALIZE_OUTPUT( v2g, o );
				
				uint advanced_descritptor = o.advanced_descritptor = (_SelfTexture2D[uint2(12, _SelfTexture2D_TexelSize.w - 1)].y );
				o.this_descriptor = advanced_descritptor ? (LoadMemInternalRB( advanced_descritptor + 68 + v.vertexID * 4) ): 0;
				o.vertexID = v.vertexID; // Always zero?
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO( o );

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
				uint nMode = nModeAndNum >> 16;
				
				uint nPList = LoadMemInternalRB( descriptor + 8 );
				
				uint4 pXform1Ptr = LoadMemInternalRB( descriptor + 16 );
				uint4 pXform2Ptr = LoadMemInternalRB( descriptor + 24 );
				
				float4 pXform1A = float4( 1.0, 1.0, 1.0, 1.0 / 4096 ) * ( pXform1Ptr ? LoadMemInternalBlockNoCache( pXform1Ptr ) : uint4( 0, 0, 0, 4096 ) );
				float4 pXform1B = 1.0 / 4096 * ( pXform1Ptr ? LoadMemInternalBlockNoCache( pXform1Ptr + 16 ) : uint4( 4096, 0, 0, 0 ) );
				float4 pXform2A = float4( 1.0, 1.0, 1.0, 1.0 / 4096 ) * ( pXform2Ptr ? LoadMemInternalBlockNoCache( pXform2Ptr ) : uint4( 0, 0, 0, 4096 ) );
				float4 pXform2B = 1.0 / 4096 * ( pXform2Ptr ? LoadMemInternalBlockNoCache( pXform2Ptr + 16 ) : uint4( 4096, 0, 0, 0 ) );
				
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
					pTA.xyz = ( pTA.xyz + 2.0 * cross(pXform1B.xyz, cross(pXform1B.xyz, pTA.xyz) + pXform1B.w * pTA.xyz) ) * pXform1A.w + pXform1A.xyz;
					pTB.xyz = ( pTB.xyz + 2.0 * cross(pXform1B.xyz, cross(pXform1B.xyz, pTB.xyz) + pXform1B.w * pTB.xyz) ) * pXform1A.w + pXform1A.xyz;
					pTC.xyz = ( pTC.xyz + 2.0 * cross(pXform1B.xyz, cross(pXform1B.xyz, pTC.xyz) + pXform1B.w * pTC.xyz) ) * pXform1A.w + pXform1A.xyz;

					o.norm = cross( pTC.xyz - pTA.xyz, pTB.xyz - pTA.xyz );
					
					o.vertex = UnityObjectToClipPos( float4( pTA.xyz * rescale, 1 ) );
					o.uv = float4( pdTA.w&0xff, (pdTA.w>>8)&0xff, (pdTA.w>>16)&0xff, (pdTA.w>>24)&0xff );
					UNITY_TRANSFER_FOG(o,o.vertex);
					triStream.Append(o);
					o.vertex = UnityObjectToClipPos( float4( pTB.xyz * rescale, 1 ) );
					o.uv = float4( pdTB.w&0xff, (pdTB.w>>8)&0xff, (pdTB.w>>16)&0xff, (pdTB.w>>24)&0xff );
					UNITY_TRANSFER_FOG(o,o.vertex);
					triStream.Append(o);
					o.vertex = UnityObjectToClipPos( float4( pTC.xyz * rescale, 1 ) );
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
					col *= 0.8 * dot( -normalize( i.norm ), _WorldSpaceLightPos0.xyz ) + 0.2;
				}
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
    }
}
