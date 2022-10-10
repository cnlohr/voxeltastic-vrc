Shader "Unlit/RandomPlatform"
{
    Properties
    {
		_TANoiseTex ("TANoise", 2D) = "white" {}
		_ColorRamp ("TANoise", 2D) = "white" {}
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

            #include "UnityCG.cginc"
			#include "/Assets/cnlohr/Shaders/tanoise/tanoise.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
				UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
                float3 worldPos : WORLDPOS;
				
				// This is needed for SPS-I Support
				UNITY_VERTEX_OUTPUT_STEREO
            };

            sampler2D _ColorRamp;
            float4 _ColorRamp_ST;

            v2f vert (appdata v)
            {
				v2f o;
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_INITIALIZE_OUTPUT(v2f, o);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
				o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv;
				UNITY_TRANSFER_FOG(o,o.vertex);
				return o;

            }

            fixed4 frag (v2f i) : SV_Target
            {
				// Need to do this first to support single-pass stereo instanced.
				UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX( i );
				float3 stray = i.worldPos.xyz;
				float4 tanv = abs( (tanoise3_1d_fast( stray * 43. ) * .3 + tanoise3_1d_fast( stray * 151. ) * .2 + tanoise3_1d_fast( stray * .7 ) * .6 + tanoise3_1d_fast( stray * 8.5 ) * .5 - .6 ) )/2.0;
				tanv += tex2Dlod( _ColorRamp, float4( stray.y, 0, 0, 0 ) );
				
				tanv = tanv / 30. + .01;
				
                // sample the texture
                fixed4 col = tanv;
                // apply fog
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }


		
		// shadow caster rendering pass, implemented manually
		// using macros from UnityCG.cginc
		Pass
		{
			Tags {"LightMode"="ShadowCaster"}
			
			// We actually only want to draw backfaces on the shadowcast.
			Cull Back
			ZWrite On
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_shadowcaster
			#pragma multi_compile_instancing
			#include "UnityCG.cginc"

			struct v2f { 
				V2F_SHADOW_CASTER;
				float4 uv : TEXCOORD0;
			};

			v2f vert(appdata_base v)
			{
				v2f o;
				UNITY_SETUP_INSTANCE_ID(v);
				TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)
				o.uv = v.texcoord;
				return o;
			}

			float4 frag(v2f i) : SV_Target
			{
				SHADOW_CASTER_FRAGMENT(i)
			}
			ENDCG
		}
	}
}
