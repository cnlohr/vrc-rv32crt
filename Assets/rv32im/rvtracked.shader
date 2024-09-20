Shader "rv32im/rvtracked"
{
    Properties
    {
		_TrackedID( "Tracked Object ID", float ) = 0
		_TrackedPropertyBase( "Tracked Property Base", float ) = 0
		[ToggleUI] _TrackedPropertyBaseEnable( "Enable Tracked Property Base", float ) = 0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }

        Pass
        {
			// Back of pad, used for transmitting information.
			Tags { "Queue" = "Overlay" }
			ZTest Off
			Cull Off
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
			#pragma target 5.0
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
				uint	vertexID	: SV_VertexID;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
            };

			float _TrackedID;
			float _TrackedProperty0;
			float _TrackedPropertyBaseEnable;

            v2f vert (appdata v)
            {
                v2f o;
				
				// If not the ingest camera, drop it.
				if( _ScreenParams.x != 64 || _ScreenParams.y != 128 || v.vertexID > 6 )
				{
					o.vertex = 0.0;
					o.uv = 0.0;
				}
				else
				{
					o.vertex = float4(  v.uv-0.5, 0.0, 0.5 );
					o.uv = v.uv * float2( 64, 128 );
				}
                return o;
            }

            float4 frag (v2f i, out float depth : SV_Depth ) : SV_Target
            {
				uint2 iuv = i.uv;
				depth = 1;
				
				uint tak = floor( _TrackedID * 16 );
				uint iuvx = iuv.x - tak;

				if( iuv.y == 0 )
				{
					if( iuvx < 16 && iuvx >= 0 )
					{
						uint tp = iuvx;
						depth = unity_ObjectToWorld[tp%4][tp/4] / ( 16777216.0 );
						return 1.0;
					}
					if( iuv.x == uint(_TrackedID)*4 && _TrackedPropertyBaseEnable > 0.5)
					{
						depth = _TrackedProperty0;
						return 1.0;
					}
				}
				else if( iuv.y == 1 )
				{
					if( iuvx < 16 && iuvx >= 0 )
					{
						uint tp = iuvx;
						depth = -unity_ObjectToWorld[tp%4][tp/4] / ( 16777216.0 );
						return 1.0;
					}
					if( iuv.x == uint(_TrackedID)*4 && _TrackedPropertyBaseEnable > 0.5 )
					{
						depth = -_TrackedProperty0;
						return 1.0;
					}
				}
				discard;
				return 1.0;
	        }
            ENDCG
        }
    }
}
