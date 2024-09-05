Shader "Unlit/DataView"
{
    Properties
    {
        _MainSystemMemory ("Texture", 2D) = "white" {}
        [Toggle(_DoOverlay)] _DoOverlay( "Do Overlay", float ) = 1.0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog
            #pragma multi_compile _ _DoOverlay
            #include "UnityCG.cginc"

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

            Texture2D< uint4 > _MainSystemMemory;
            float4 _MainSystemMemory_ST;
            float4 _MainSystemMemory_TexelSize;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainSystemMemory);
                UNITY_TRANSFER_FOG(o, o.vertex);
                return o;
            }

            float hitmarker( uint pcreg, float2 thisCoord )
            {
                uint pcv = _MainSystemMemory[uint2( pcreg/4, _MainSystemMemory_TexelSize.w - 1 )][pcreg%4] - 0x80000000;
                pcv /= 16;
                float2 dpos = thisCoord - float2(
                    pcv % _MainSystemMemory_TexelSize.z,
                    pcv / int( _MainSystemMemory_TexelSize.w )
                ) - .5;
                float fw = fwidth( thisCoord );
                float cross_thickness = 1 + 2*fw;  // make it more crisp as you look closely
                float cross = max(
                    cross_thickness - abs( dpos.x - dpos.y ),
                    cross_thickness - abs( dpos.x + dpos.y )
                );

                float sharpness = 1/fw;  // mathematical antialiasing
                // set a min radius around the pixel and max radius around the cross
                float circular_mask = saturate( sharpness*(10.0 - abs( 10.70710678118 - length( dpos ) ) ));
                return min(circular_mask, saturate( sharpness*cross ) );
            }

            float4 frag (v2f i) : SV_Target
            {
                float4 col = _MainSystemMemory[i.uv*_MainSystemMemory_TexelSize.zw] / (float)(0xffffffff);
                float2 thisCoord = i.uv * _MainSystemMemory_TexelSize.zw;

                #if _DoOverlay
                    col = lerp( col, float4( 1.0, 1.0, 0.0, 0.0 ), hitmarker( 10, thisCoord ) );
                    col = lerp( col, float4( 1.0, 1.0, 0.0, 0.0 ), hitmarker( 11, thisCoord ) );
                    col = lerp( col, float4( 1.0, 1.0, 0.0, 0.0 ), hitmarker( 12, thisCoord ) );
                    col = lerp( col, float4( 1.0, 1.0, 0.0, 0.0 ), hitmarker( 13, thisCoord ) );

                    col = lerp( col, float4( 1.0, 0.0, 0.0, 0.0 ), hitmarker( 32, thisCoord ) );
                    col = lerp( col, float4( 0.0, 0.0, 1.0, 0.0 ), hitmarker(  2, thisCoord ) );
                    col = lerp( col, float4( 0.0, 1.0, 1.0, 0.0 ), hitmarker(  4, thisCoord ) );
                #endif
                // apply fog
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
    }
}
