Shader "DensitiesCRT"
{
	Properties
	{
		_Tex2D ("Texture (2D)", 2D) = "white" {}
		_ColorRamp( "Color Ramp", 2D ) = "white" { }
		_TANoiseTex ("TANoise", 2D) = "white" {}
	}

	SubShader
	{
		Tags { }
		ZTest always
		ZWrite Off
		
		CGINCLUDE
		#include "/Assets/cnlohr/Shaders/tanoise/tanoise.cginc"
		#define CRTTEXTURETYPE float4
		
		#include "/Assets/AudioLink/Shaders/AudioLink.cginc"
		#include "/Assets/cnlohr/Shaders/hashwithoutsine/hashwithoutsine.cginc"
		ENDCG

		Pass
		{
			Name "Pepper"
			
			CGPROGRAM
			
			#pragma vertex vert
			#pragma fragment frag
			#pragma geometry geo
			#pragma multi_compile_fog
			#pragma target 5.0

			#include "flexcrt.cginc"

			struct v2g
			{
				float4 vertex : SV_POSITION;
				uint2 batchID : TEXCOORD0;
			};

			struct g2f
			{
				float4 vertex : SV_POSITION;
				nointerpolation  float4 color : TEXCOORD0;
				float3 vpos : POSID;
				float3 randval : RANDVAL;
			};

			// The vertex shader doesn't really perform much anything.
			v2g vert( appdata_customrendertexture IN )
			{
				v2g o;
				o.batchID = IN.vertexID / 6;

				// This is unused, but must be initialized otherwise things get janky.
				o.vertex = 0.;
				return o;
			}

			[maxvertexcount(2)]
			[instance(1)]
			void geo( point v2g input[1], inout PointStream<g2f> stream,
				uint instanceID : SV_GSInstanceID, uint geoPrimID : SV_PrimitiveID )
			{
				// Just FYI you get 64kB of local variable space.
				
				int batchID = input[0].batchID;

				int operationID = geoPrimID * 1 + ( instanceID - batchID );
				
				g2f o;

				uint PixelID = operationID * 1;
				
				// We first output random noise, then we output a stable block.

				//XXX TODO: Improve this logic.
				//float InvThreshold = AudioLinkData( ALPASS_AUDIOLINK + uint2( 0, 0 ) ) + AudioLinkData( ALPASS_AUDIOLINK + uint2( 0, 1 ) ) - .5;
				
				int band = 0;
				for( band = 0; band<  4; band++ )
				{
					float4 randval = chash44( float4( operationID, _Time.y*10., band, 0 ) );
					
					float avff = AudioLinkData( ALPASS_AUDIOLINK + uint2( 0, band ) );
					float avff_filter = AudioLinkData( ALPASS_FILTEREDAUDIOLINK + uint2( 0, band ) );

					avff -= avff_filter / 1.5;
					
					avff /= 6; // Make it less frequent.
					
					
					if( randval.w < avff  )
					{
						uint3 coordOut3D = randval.xyz * int3( FlexCRTSize.xx, FlexCRTSize.y / FlexCRTSize.x / 4 ) + int3(0,0,band*FlexCRTSize.y / FlexCRTSize.x / 4);
						uint2 coordOut2D;
						coordOut2D = uint2( coordOut3D.x, coordOut3D.y + coordOut3D.z * FlexCRTSize.x );
						
						float power = 
							// ((randval.w * 60000) % 12)-5.5; randomized
							((int(randval.w * 600) % 2)-0.5) * 5;
						

						o.randval = randval;
						o.vertex = FlexCRTCoordinateOut( coordOut2D );
						o.color = float4( power*5000, 0, 0.0, 1.0 );
						o.vpos = coordOut3D;
						stream.Append(o);
					}
				}
			}

			float4 frag( g2f IN ) : SV_Target
			{
				float4 col = IN.color;


				// XXX TODO

				// Stable
				//float3 coloro = normalize( AudioLinkData( ALPASS_THEME_COLOR0 ) ) * 255;
				
				// Wild
				//uint randseed = IN.vpos.x + IN.vpos.y * 16 + IN.vpos.z * 256;
				//float3 coloro = normalize( AudioLinkData( ALPASS_CCLIGHTS + uint2( randseed % 128, 0 ) ) ) * 255;

				// Strip 
				float3 coloro = normalize( AudioLinkData( ALPASS_CCSTRIP + uint2( IN.vpos.y /* Assuming 0..128 */, 0 ) ) ) * 255;
				
				coloro = max( 0, coloro );
				uint rcolor = ((uint)coloro.r) | (((uint)coloro.g)<<8) | (((uint)coloro.b)<<16);
				//rcolor = 0x10f01f;
				col.y = ( rcolor );
				
				
				return col;
			}
			ENDCG
		}
		
		Pass
		{
			Name "Fade"
			CGPROGRAM

			#pragma vertex DefaultCustomRenderTextureVertexShader
			#pragma fragment frag
			#pragma multi_compile_fog
			#pragma target 5.0

			#define CRTTEXTURETYPE float4
			#include "flexcrt.cginc"

			float4 getVirtual3DVoxel( int3 voxel )
			{
				if( any( voxel < 0 ) || voxel.x >= FlexCRTSize.x || voxel.y >= FlexCRTSize.y || voxel.z >= FlexCRTSize.x * FlexCRTSize.y )
				{
					return 0;
				}
				return _SelfTexture2D.Load( int3( voxel.x, voxel.y + voxel.z * FlexCRTSize.x, 0 ) );
			}
			

			float4 frag( v2f_customrendertexture IN ) : SV_Target
			{
				int3 vox = int3( IN.globalTexcoord * FlexCRTSize.xy, 0 );
				vox.z = vox.y / FlexCRTSize.x;
				vox.y %= FlexCRTSize.x;

				float4 tv = getVirtual3DVoxel( vox );
				float4 vusum = 0;
				float3 colorsum = 0;
				float colortot = 0;
				
				uint colraw = uint( tv.y );
				float3 thiscolor = float3( colraw & 0xff, (colraw>>8) & 0xff, (colraw>>16) & 0xff );

				colorsum += thiscolor * abs( tv.x );
				colortot += abs( tv.x );
				
				float3 strongest_color = thiscolor;
				float strongest_color_strength = abs(tv.x);

				float4 hashatpos1 = chash44( float4( _Time.y, vox ) );
				float4 hashatpos2 = chash44( float4( _Time.y+1, vox ) );
				float randomizepowerset[8] = { hashatpos1.rgba, hashatpos2.rgba };
				
				// The hatpos diff is what controls how things randomly expand
				strongest_color_strength += hashatpos1.x*11. * strongest_color_strength; ///dot( hashatpos1, 1.0 ) / 4.0;

				if( 0 )
				{
					float4 vus[6] = {
						getVirtual3DVoxel( vox + int3( -1, 0, 0 ) ),
						getVirtual3DVoxel( vox + int3( 1, 0, 0 ) ),
						getVirtual3DVoxel( vox + int3( 0, -1, 0 ) ),
						getVirtual3DVoxel( vox + int3( 0, 1, 0 ) ),
						getVirtual3DVoxel( vox + int3( 0, 0, -1 ) ),
						getVirtual3DVoxel( vox + int3( 0, 0, 1 ) ),
						};
					int i;
					for( i = 0; i < 6; i++ )
					{
						vusum += vus[i];
					}
					vusum/= 7.0;
				}
				else
				{
					float vutot = 0.0;
					int3 offset;
					uint idx = 0;
					for( offset.z = -1; offset.z <= 1; offset.z++ )
					for( offset.y = -1; offset.y <= 1; offset.y++ )
					for( offset.x = -1; offset.x <= 1; offset.x++ )
					{
						if( length( offset ) < 0.01 ) continue;
						
						float inten = 1.0 / length( offset );
						vutot += inten;
						float4 gv3 = getVirtual3DVoxel( vox + offset );
						
						float abs_gv3_x = abs( gv3.x );
						
						colraw = ( gv3.y );
						float3 this_color = float3( colraw & 0xff, (colraw>>8) & 0xff, (colraw>>16) & 0xff );
						colorsum += this_color * abs( gv3.x );
						colortot += abs_gv3_x;
						vusum += gv3;
						
						//abs_gv3_x += randomizepowerset[idx];
						if( abs_gv3_x > strongest_color_strength )
						{
							strongest_color = this_color;
							strongest_color_strength = abs_gv3_x;
						}
						idx++;
					}
					vusum /= vutot;
				}
				
				#ifdef NEARLIMIT
				// Very carefully balanced to dissapate.
				// Controls the diffusion speed and fade.
				// This is good for 128x128x16
				float timestep = 0.25;
				//float decay = 0.825; // 0.826 = aaalmost parity
				float decay = 0.82;
				#else
				// For 96x96
				float timestep = 0.44;
				float decay = 0.726;
				#endif
				
				float velocity = tv.z;
				float value = tv.x;
				float laplacian = 2.0*(vusum.x - value);
				value+=velocity*timestep;
				velocity+=laplacian*timestep;


				float3 colorout;

				if( 0 )
				{
					// Smooth colors
					colorout = normalize( colorsum ) * 255;
				}
				else
				{
					// Sharp colors
					colorout = strongest_color;
				}
				
				uint rcolor = ((uint)colorout.r) | (((uint)colorout.g)<<8) | (((uint)colorout.b)<<16);
				
				return float4( value * decay, ( rcolor ), velocity * decay, value );
			}
			
			ENDCG
		}
		
		Pass
		{
			Name "Display"
			CGPROGRAM

			#pragma vertex DefaultCustomRenderTextureVertexShader
			#pragma fragment frag
			#pragma multi_compile_fog
			#pragma target 5.0

			#define CRTTEXTURETYPE float4
			#include "flexcrt.cginc"
			
			Texture2D<float4> _Tex2D;
			sampler2D _ColorRamp;

			float4 frag( v2f_customrendertexture IN ) : SV_Target
			{

				float4 value = _Tex2D.Load( int3(IN.globalTexcoord * FlexCRTSize.xy, 0 ) );
				//float3 color = tex2Dlod( _ColorRamp, float4( pow( abs( value.x ), 0.1 ) * sign( value.x )+.6, 0, 0, 0 ) );

				uint colraw = ( value.y );
				float3 color = float3( (colraw) & 0xff, (colraw>>8) & 0xff, (colraw>>16) & 0xff );
				
				// Debug: Flicker negative densities.
				//if( value.x < 0 && frac( _Time.y *10 ) < 0.5 ) return 0; 
				return saturate( float4( 1.5 * color / 255., saturate( abs( value.x ) )/40.0 ) );
			}
			
			ENDCG
		}


		Pass
		{
			Name "Display2"
			CGPROGRAM

			#pragma vertex DefaultCustomRenderTextureVertexShader
			#pragma fragment frag
			#pragma multi_compile_fog
			#pragma target 5.0

			#define CRTTEXTURETYPE float4
			#include "flexcrt.cginc"
			
			Texture2D<float4> _Tex2D;
			sampler2D _ColorRamp;

			float4 frag( v2f_customrendertexture IN ) : SV_Target
			{
				int3 vox = int3( IN.globalTexcoord * FlexCRTSize.xy, 0 );
				vox.z = vox.y / FlexCRTSize.x;
				vox.y %= FlexCRTSize.x;
				
				float chronotime1 = (AudioLinkDecodeDataAsUInt( ALPASS_CHRONOTENSITY  + uint2( 1, 1 ) )%100000000)/200000.0;
				float chronotime2 = (AudioLinkDecodeDataAsUInt( ALPASS_CHRONOTENSITY  + uint2( 4, 0 ) )%100000000)/200000.0;
				
				chronotime1 = _Time.y * .2;				
				chronotime2 += _Time.y*.2;

				float4 noise4 = tanoise4( float4( vox*.2 + float3( 0, chronotime1*.05,  chronotime1 ), chronotime1 ) );
				float4 noiseB = tanoise4( float4( vox*.2 + float3( 0, chronotime2*.00, -chronotime2*.05 ), chronotime2 ) );

				float alphasel = (
					noise4.x * (AudioLinkData( ALPASS_FILTEREDAUDIOLINK + uint2( 1, 0 ) ) + 3 ) +
					noise4.y * (AudioLinkData( ALPASS_FILTEREDAUDIOLINK + uint2( 1, 1 ) ) + 3 ) +
					noise4.z * (AudioLinkData( ALPASS_FILTEREDAUDIOLINK + uint2( 1, 2 ) ) + 3 ) +
					noise4.w * (AudioLinkData( ALPASS_FILTEREDAUDIOLINK + uint2( 1, 3 ) ) + 3 )) / 10.0 - .8;
					
				
				float4 color;
				color.a = saturate( alphasel );
				int ColorChordOut = 0;
				if( ColorChordOut == 1 )
				{
					// Use alphasel to select between AudioLink values.
					float3 color0 = AudioLinkData( ALPASS_THEME_COLOR0 );
					float3 color1 = AudioLinkData( ALPASS_THEME_COLOR1 );
					float3 color2 = AudioLinkData( ALPASS_THEME_COLOR2 );
					float3 color3 = AudioLinkData( ALPASS_THEME_COLOR3 );
					if( length( color0 ) < 0.01 ) noiseB.r = 0;
					if( length( color1 ) < 0.01 ) noiseB.g = 0;
					if( length( color2 ) < 0.01 ) noiseB.b = 0;
					if( length( color3 ) < 0.01 ) noiseB.a = 0;
					
					float maxelem = max( max( noiseB.r, noiseB.g ), max( noiseB.b, noiseB.a ) );
					//Find max element.
					
					if( maxelem == noiseB.r ) color.rgb = color0;
					if( maxelem == noiseB.g ) color.rgb = color1;
					if( maxelem == noiseB.b ) color.rgb = color2;
					if( maxelem == noiseB.a ) color.rgb = color3;
					if( length( color.rgb ) < 0.01 ) color.rgb = 0.1;
				}
				else if( ColorChordOut == 2 )
				{
					color.rgb = AudioLinkLerp( ALPASS_CCSTRIP + float2( noiseB.r * AUDIOLINK_WIDTH, 0 ) );
				}
				else
				{
					color.rgb = noiseB.rgb;
				}
				
				
				
				// Force vividness to be high.
				float minc = min( min( color.r, color.g ), color.b );
				color.rgb = normalize( color.rgb - minc )*1.4;
				return color;
			}
			
			ENDCG
		}
	}
}
