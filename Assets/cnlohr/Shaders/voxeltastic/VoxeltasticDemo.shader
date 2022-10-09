Shader "Unlit/VoxeltasticDemo"
{
	Properties
	{
		_Tex ("Texture", 3D) = "white" {}
		_ColorRamp( "Color Ramp", 2D ) = "white" { }
		_MinVal ("Min Val", float ) = 0.6
		_MaxVal ("Min Val", float ) = 1.0
		_GenAlpha ("Gen Alpha", float ) = 1.0
		
		[Toggle(ENABLE_CUTTING_EDGE)] ENABLE_CUTTING_EDGE ("Enable Cutting Edge", int ) = 1
		[Toggle(DO_CUSTOM_EFFECT)] DO_CUSTOM_EFFECT ("Do Custom Effect", int ) = 0
	}
	SubShader
	{
		Tags {"RenderType"="Transparent"  "Queue"="Transparent+1" }
		
		Pass
		{
			Tags {"LightMode"="ForwardBase" }
			Blend One OneMinusSrcAlpha 
			Cull Front
			ZWrite Off
			
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag alpha earlydepthstencil

			#pragma multi_compile_fog
			#pragma multi_compile _ VERTEXLIGHT_ON 
			#pragma multi_compile_local _ ENABLE_CUTTING_EDGE
			#pragma multi_compile_local _ DO_CUSTOM_EFFECT
			#pragma target 5.0

			#include "UnityCG.cginc"
			#include "UnityInstancing.cginc"
			#include "UnityShadowLibrary.cginc"
			#include "AutoLight.cginc"
			
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
				float4 screenPosition : TEXCOORD1; // Trivially refactorable to a float2
				float3 worldDirection : TEXCOORD3;
				UNITY_VERTEX_OUTPUT_STEREO
			};

			Texture3D<float4> _Tex;
			sampler2D _ColorRamp;
			float _MinVal;
			float _MaxVal;
			float _GenAlpha;
			UNITY_DECLARE_DEPTH_TEXTURE( _CameraDepthTexture );
  
			float AudioLinkRemap(float t, float a, float b, float u, float v) { return ((t-a) / (b-a)) * (v-u) + u; }

			#ifdef DO_CUSTOM_EFFECT
				#define VT_FN custom_effect_function
			#else
				#define VT_FN my_density_function
			#endif
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

			void custom_effect_function( int3 pos, float distance, inout float4 accum )
			{
				
				float a = 0.0;
				float usetime = _Time.y / 6.0;
				a += 1.0/length( pos - (float3(sin(usetime), -.4, cos(usetime) )*10+16 ) );
				a += 1.0/length( pos - (float3(sin(usetime+2.1), -.6, cos(usetime+2.1) )*10+16 ) );
				a += 1.0/length( pos - (float3(sin(usetime+4.2), -.8, cos(usetime+4.2) )*10+16 ) );

				a = AudioLinkRemap( a, _MinVal, _MaxVal, 0, 1 );
				a = saturate( a );
				float initiala = accum.a;
				float this_alpha = a*distance*accum.a*_GenAlpha;
				float3 color = tex2Dlod( _ColorRamp, float4( a, 0, 0, 0 ) );
				accum.rgb += this_alpha * color;//lerp( accum.rgba, float4( normalize(AudioLinkHSVtoRGB(float3( a,1,1 ))), 0.0 ), this_alpha );
				accum.a = initiala - this_alpha;
			}			

			#include "Voxeltastic.cginc"



			struct shadowHelper
			{
				float4 vertex;
				float3 normal;
				V2F_SHADOW_CASTER;
			};

			float4 colOut(shadowHelper data)
			{
				SHADOW_CASTER_FRAGMENT(data);
			}


            // Inspired by Internal_ScreenSpaceeShadow implementation.
			// This code can be found on google if you search for "computeCameraSpacePosFromDepthAndInvProjMat"
            float GetLinearZFromZDepth_WorksWithMirrors(float zDepthFromMap, float2 screenUV) {
                #if defined(UNITY_REVERSED_Z)
                    zDepthFromMap = 1 - zDepthFromMap;
                #endif
				if( zDepthFromMap >= 1.0 ) return _ProjectionParams.z;
                float4 clipPos = float4(screenUV.xy, zDepthFromMap, 1.0);
                clipPos.xyz = 2.0f * clipPos.xyz - 1.0f;
                float2 camPos = mul(unity_CameraInvProjection, clipPos).zw;
				return -camPos.x / camPos.y;
            }


			v2f vert (appdata v)
			{
				v2f o;
				
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_INITIALIZE_OUTPUT(v2f, o);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

				o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv;
				// Subtract camera position from vertex position in world
				// to get a ray pointing from the camera to this vertex.
				o.worldDirection = mul(unity_ObjectToWorld, v.vertex).xyz - _WorldSpaceCameraPos;

				// Save the clip space position so we can use it later.
				// This also handles situations where the Y is flipped.
				float2 suv = o.vertex * float2( 0.5, 0.5*_ProjectionParams.x);
							
				// Tricky, constants like the 0.5 and the second paramter
				// need to be premultiplied by o.vertex.w.
				o.screenPosition = float4( TransformStereoScreenSpaceTex(
					suv+0.5*o.vertex.w, o.vertex.w), 0, o.vertex.w );
				UNITY_TRANSFER_FOG(o,o.vertex);
				return o;
			}

			// was SV_DepthLessEqual
			fixed4 frag (v2f i, uint is_front : SV_IsFrontFace, out float outDepth : SV_Depth ) : SV_Target
			{
				UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX( i );
				float3 fullVectorFromEyeToGeometry = i.worldPos - _WorldSpaceCameraPos;
				float3 worldSpaceDirection = normalize( fullVectorFromEyeToGeometry );

				// Compute projective scaling factor.
				// perspectiveFactor is 1.0 for the center of the screen, and goes above 1.0 toward the edges,
				// as the frustum extent is further away than if the zfar in the center of the screen
				// went to the edges.
				float perspectiveDivide = 1.0f / i.vertex.w;
				float perspectiveFactor = length( fullVectorFromEyeToGeometry * perspectiveDivide );

				// Calculate our UV within the screen (for reading depth buffer)
				float2 screenUV = i.screenPosition.xy * perspectiveDivide;
				float eyeDepthWorld =
					GetLinearZFromZDepth_WorksWithMirrors( 
						SAMPLE_DEPTH_TEXTURE( _CameraDepthTexture, screenUV), 
						screenUV ) * perspectiveFactor;
				
				// eyeDepthWorld is in world space, it is where the "termination" of our ray should happen, or rather
				// how far away from the camera we should be.
				float3 worldPosModified = _WorldSpaceCameraPos;

				#if VERTEXLIGHT_ON && ENABLE_CUTTING_EDGE
					// We use a cutting edge with lights.
					// This is not needed, but an interesting feature to add.
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
					float3 wobj = mul(unity_ObjectToWorld, float4(0,0,0,1));

					int n;
					for( n = 0; n < 4; n++ )
					{
						if( (frac( lrads[n]*100 ) - .1)<0.05 )
						{
							float len = length( lxyz[n]- wobj );
							if( len < cls )
							{
								lid0 = n;
								cls = length( lxyz[n] - wobj );
							}
						}
					}
					for( n = 0; n < 4; n++ )
					{
						if( n != lid0 && (frac( lrads[n]*100 ) - .2)<0.05 && floor( lrads[n]*100 ) == floor( lrads[lid0]*100 ) )
						{
							lid1 = n;
						}
					}

					if( lid1 >= 0 && lid0 >= 0 )
					{
						float3 vecSlice = lxyz[lid0];
						float3 vecNorm = normalize( lxyz[lid1] - vecSlice );
						float3 vecDiff = vecSlice - worldPosModified;
						float vd = dot(worldSpaceDirection, vecNorm );

						float dist = dot(vecDiff, vecNorm)/vd;

						if( dot(vecDiff, vecNorm) > 0 )
						{
							if( vd < 0 ) discard;
							worldPosModified += worldSpaceDirection * dist;
						}
						else
						{
							if( vd < 0 )
							{
								// Tricky:  We also want to z out on the slicing plane.
								// XXX: I have no idea why you have to / perspectiveFactor.
								// Like literally, no idea.
								// 
								eyeDepthWorld = dist;
							}
						}
					}
				#endif

				// We transform into object space for operations.

				float3 objectSpaceCamera = mul(unity_WorldToObject, float4(worldPosModified,1.0));
				float3 objectSpaceEyeDepthHit = mul(unity_WorldToObject, float4( worldPosModified + eyeDepthWorld * worldSpaceDirection, 1.0 ) );
				float3 objectSpaceDirection = mul(unity_WorldToObject, float4(worldSpaceDirection,0.0));
				
				// We want to transform into the local object space.
				
				#ifdef DO_CUSTOM_EFFECT
				int3 samplesize = 32;
				#else
				int3 samplesize; int dummy; _Tex.GetDimensions( 0, samplesize.x, samplesize.y, samplesize.z, dummy );
				#endif
				
				// This has been commented out for a long time.
				//samplesize += 1; // XXX Currently hack - but sometimes it doesn't work out cleanly on the top edges.

				objectSpaceDirection = normalize( objectSpaceDirection * samplesize );
				float3 surfhit = objectSpaceCamera*(samplesize);
				float TravelLength = length( (objectSpaceEyeDepthHit - objectSpaceCamera) * samplesize);
				float4 col = VT_TRACE( samplesize, surfhit, objectSpaceDirection, float4( 0, 0, 0, 1 ), TravelLength );

				// Compute what our Z value should be, so the front of our shape appears on top of
				// objects inside the volume of the traced area.
				// surfhit is the location in object space where the ray "started"
				float3 WorldSpace_StartOfTrace = mul(unity_ObjectToWorld, float4( (surfhit) / samplesize, 1.0 ));
				float zDistanceWorldSpace = length( WorldSpace_StartOfTrace - _WorldSpaceCameraPos );
				float3 WorldSpace_BasedOnComputedDepth = normalize( i.worldPos - _WorldSpaceCameraPos ) * zDistanceWorldSpace + _WorldSpaceCameraPos;
				float4 clipPosSurface = mul(UNITY_MATRIX_VP, float4(WorldSpace_BasedOnComputedDepth, 1.0));

#if defined(UNITY_REVERSED_Z)
				outDepth = clipPosSurface.z / clipPosSurface.w;
#else
				outDepth = clipPosSurface.z / clipPosSurface.w *0.5+0.5;
#endif

				col.a = 1.0 - col.a;
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
			Cull Front
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
