Shader "Unlit/VoxeltasticWifiData"
{
	Properties
	{
		_Tex ("Texture", 3D) = "white" {}
		_ColorRamp( "Color Ramp", 2D ) = "white" { }
		_MinVal ("Min Val", float ) = 0.6
		_MaxVal ("Min Val", float ) = 1.0
		_GenAlpha ("Gen Alpha", float ) = 1.0
	}
	SubShader
	{
		Tags { "RenderType"="Transparent" "Queue"="Transparent" }
		Blend One OneMinusSrcAlpha 
		Cull Off
		
		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_fog
			
			#pragma target 5.0

			#include "UnityCG.cginc"
			#include "UnityInstancing.cginc"
			
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
				float3 worldPos : TEXCOORD2;
				UNITY_VERTEX_OUTPUT_STEREO
			};

			Texture3D<float4> _Tex;
			sampler2D _ColorRamp;
			float _MinVal;
			float _MaxVal;
			float _GenAlpha;

			float AudioLinkRemap(float t, float a, float b, float u, float v) { return ((t-a) / (b-a)) * (v-u) + u; }


			float3 AudioLinkHSVtoRGB(float3 HSV)
			{
				float3 RGB = 0;
				float C = HSV.z * HSV.y;
				float H = HSV.x * 6;
				float X = C * (1 - abs(fmod(H, 2) - 1));
				if (HSV.y != 0)
				{
					float I = floor(H);
					if (I == 0) { RGB = float3(C, X, 0); }
					else if (I == 1) { RGB = float3(X, C, 0); }
					else if (I == 2) { RGB = float3(0, C, X); }
					else if (I == 3) { RGB = float3(0, X, C); }
					else if (I == 4) { RGB = float3(X, 0, C); }
					else { RGB = float3(C, 0, X); }
				}
				return RGB;
				float M = HSV.z - C;
				return RGB + M;
			}


			#define VT_FN my_density_function
			#define VT_TRACE trace
			void my_density_function( int3 pos, float distance, inout float4 accum )
			{
				float a = _Tex.Load( int4( pos.xyz, 0.0 ) ).a;
				a = AudioLinkRemap( a, _MinVal, _MaxVal, 0, 1 );
				a = saturate( a );
				float initiala = accum.a;
				float this_alpha = a*distance*accum.a*_GenAlpha;
				float3 color = tex2Dlod( _ColorRamp, float4( a, 0, 0, 0 ) );
				accum.rgb += this_alpha * color;//lerp( accum.rgba, float4( normalize(AudioLinkHSVtoRGB(float3( a,1,1 ))), 0.0 ), this_alpha );
				accum.a = initiala - this_alpha;
			}			
			#include "Voxeltastic.cginc"

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

			fixed4 frag (v2f i, uint is_front : SV_IsFrontFace ) : SV_Target
			{
				UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX( i );
				float3 wpos = i.worldPos;
				float3 wdir = normalize( wpos - _WorldSpaceCameraPos );
				
				if( is_front < 1 )
				{
					//Backface (we're inside)
					wpos = _WorldSpaceCameraPos + wdir * _ProjectionParams.y;
					wdir = normalize( wpos - _WorldSpaceCameraPos );
					//TODO: Skip if we're outside the box.
				}
				else
				{
					// font-face do nothing.
				}
				float3 lpos = mul(unity_WorldToObject, float4(wpos,1.0))+.5; 
				float3 ldir = mul(unity_WorldToObject, float4(wdir,0.0));
				
				
				fixed4 col = 1.;
				
				int3 samplesize; int dummy;
				_Tex.GetDimensions( 0, samplesize.x, samplesize.y, samplesize.z, dummy );

				ldir = normalize( ldir * samplesize );
				float3 surfhit = lpos*(samplesize) + ldir * 0.003;
				col = VT_TRACE( samplesize, surfhit, ldir, float4( 0, 0, 0, 1 ) );
				col.a = 1.0 - col.a;
				UNITY_APPLY_FOG(i.fogCoord, col);
				return col;
			}
			ENDCG
		}
	}
}
