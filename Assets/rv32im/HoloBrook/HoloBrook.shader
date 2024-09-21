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
                float3 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
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
				
				uint advanced_descritptor = o.advanced_descritptor = _SelfTexture2D[uint2(12, _SelfTexture2D_TexelSize.w - 1)].y - MINIRV32_RAM_IMAGE_OFFSET;
				o.this_descriptor = advanced_descritptor ? LoadMemInternalRB( advanced_descritptor + 68 + v.vertexID * 4 ) : 0;
				o.vertexID = v.vertexID; // Always zero?
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO( o );

                return o;
            }
			
			[maxvertexcount(96)] // 32 Triangles.
			[instance(16)]
			void geo(point v2g pin[1], inout TriangleStream<g2f> triStream, 
				uint instanceID : SV_GSInstanceID, uint geoPrimID : SV_PrimitiveID )
			{
				v2g p = pin[0];
				UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(p);
				
				if( p.this_descriptor == 0 ) return;
				
				g2f o;
				UNITY_INITIALIZE_OUTPUT( g2f, o );
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO( o );
				o.uv = 0;
				int i;
				for( i = 0; i < 32; i++ )
				{
					o.vertex = UnityObjectToClipPos( float4( 0, 0, instanceID, 1 ) );
					UNITY_TRANSFER_FOG(o,o.vertex);
					triStream.Append(o);
					o.vertex = UnityObjectToClipPos( float4( 1, 0, instanceID, 1 ) );
					UNITY_TRANSFER_FOG(o,o.vertex);
					triStream.Append(o);
					o.vertex = UnityObjectToClipPos( float4( 0, 1, instanceID, 1 ) );
					UNITY_TRANSFER_FOG(o,o.vertex);
					triStream.Append(o);
					triStream.RestartStrip();
				}
			}

            fixed4 frag (g2f i) : SV_Target
            {
				UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
                fixed4 col = tex2D(_MainTex, i.uv);
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
    }
}
