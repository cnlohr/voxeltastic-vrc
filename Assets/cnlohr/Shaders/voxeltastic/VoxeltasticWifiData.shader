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
		Tags { "RenderType"="Transparent" "Queue"="Transparent+1" "LightMode"="ForwardBase" }
		Blend One OneMinusSrcAlpha 
		Cull Front
		ZWrite Off

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_fog
			#pragma multi_compile _ VERTEXLIGHT_ON
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
				float3 wobj = mul(unity_ObjectToWorld, float4(0,0,0,1));
				float3 wdir = normalize( i.worldPos - _WorldSpaceCameraPos );
				float3 wpos = _WorldSpaceCameraPos + wdir * _ProjectionParams.y;

				#ifdef VERTEXLIGHT_ON
				
				// Use lights to control cutting plane
				int lid0 = -1;
				int lid1 = -1;
				float cls = 1e20;
				float4 lrads = 5 * rsqrt(unity_4LightAtten0);
				float3 lxyz[4] = {
					float3( unity_4LightPosX0[0], unity_4LightPosY0[0], unity_4LightPosZ0[0] ),
					float3( unity_4LightPosX0[1], unity_4LightPosY0[1], unity_4LightPosZ0[1] ),
					float3( unity_4LightPosX0[2], unity_4LightPosY0[2], unity_4LightPosZ0[2] ),
					float3( unity_4LightPosX0[3], unity_4LightPosY0[3], unity_4LightPosZ0[3] ) };
					
				// Find cutting 
				for( int i = 0; i < 4; i++ )
				{
					if( (frac( lrads[i]*100 ) - .1)<0.05 )
					{
						float len = length( lxyz[i]- wobj );
						if( len < cls )
						{
							lid0 = i;
							cls = length( lxyz[i] - wobj );
						}
					}
				}
				for( int i = 0; i < 4; i++ )
				{
					if( i != lid0 && (frac( lrads[i]*100 ) - .2)<0.05 && floor( lrads[i]*100 ) == floor( lrads[lid0]*100 ) )
					{
						lid1 = i;
					}
				}
				
				if( lid1 >= 0 && lid0 >= 0 )
				{
					float3 vecSlice = lxyz[lid0];
					float3 vecNorm = normalize( lxyz[lid1] - vecSlice );
					float3 vecDiff = vecSlice - wpos;
					float vd = dot(wdir, vecNorm );
					//return float4( length(vecNorm, 1.0 );
					if( dot(vecDiff, vecNorm) > 0 )
					{
						if( vd < 0 ) discard;
						float dist = dot(vecDiff, vecNorm)/vd;
						wpos += wdir * dist;
					}
				}
				#endif

				float3 lpos = mul(unity_WorldToObject, float4(wpos,1.0))+.5; // hmm +.5 
				float3 ldir = mul(unity_WorldToObject, float4(wdir,0.0));

				
				int3 samplesize; int dummy;
				_Tex.GetDimensions( 0, samplesize.x, samplesize.y, samplesize.z, dummy );
				//samplesize += 1; // XXX Currently hack - but sometimes it doesn't work out cleanly on the top edges.

				ldir = normalize( ldir * samplesize );
				float3 surfhit = lpos*(samplesize) + ldir;
				float4 col = VT_TRACE( samplesize, surfhit, ldir, float4( 0, 0, 0, 1 ) );
				col.a = 1.0 - col.a;
				UNITY_APPLY_FOG(i.fogCoord, col);
				return col;
			}
			ENDCG
		}
	}
}
