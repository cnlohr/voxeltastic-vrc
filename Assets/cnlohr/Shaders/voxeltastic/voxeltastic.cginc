#ifndef SHADER_TARGET_SURFACE_ANALYSIS

//uint3 textureDimensions = 0;
//_MainTex.GetDimensions(0,textureDimensions.x,textureDimensions.y,textureDimensions.z);

// You must define:
// VT_TRACE as a name for the trace function
// VT_FN    as a function you implement for getting data
//

#ifndef VT_MAXITER
#define VT_MAXITER 511
#endif

float4 VT_TRACE( float3 ARRAYSIZE, float3 RayPos, float3 RayDir, float4 Accumulator )
{
	
	float adv = 0;
/*
	{
		float lin = max( 0, (length( surfacedistance )-1.) );
		adv = max( adv, lin );
	}
*/

	//Trace to Y.
	{
/*
		float yadv = 0;
		if( RayPos.y >= ARRAYSIZE.y )
		{
			float distY = RayPos.y-(ARRAYSIZE.y-1);
			yadv = -distY / RayDir.y;
		}
		else if( RayPos.y <= 0 )
		{
			float distY = -RayPos.y;
			yadv = distY / RayDir.y;
		}
		adv = max( adv, yadv );

		float xadv = 0, zadv = 0;
		if( RayPos.x >= (ARRAYSIZE.x) )
		{
			float distX = RayPos.x-(ARRAYSIZE.x-1);
			xadv = -distX / RayDir.x;
		}
		else if( RayPos.x <= 0 )
		{
			float distX = -RayPos.x;
			xadv = distX / RayDir.x;
		}
		if( RayPos.z >= (ARRAYSIZE.z))
		{
			float distZ = RayPos.z-(ARRAYSIZE.z-1);
			zadv = -distZ / RayDir.z;
		}
		else if( RayPos.z <= 0 )
		{
			float distZ = -RayPos.z;
			zadv = distZ / RayDir.z;
		}
		adv = max( adv, xadv );
		adv = max( adv, zadv );*/
	}

	//RayPos += ARRAYSIZE;

	{
		//adv += 0.001;
		//RayPos += RayDir * adv;
	}
	

	fixed3 Normal;
	int3 CellD = int3( sign( RayDir ) );
	int3 CellP = int3( floor( RayPos ) );

	float4 VecZP = 0.;
	float4 VecZM = 0.;
	int iteration = 0;
	float3 PartialRayPos = frac( RayPos ); 
	
	{
		//Fist step is to step into the the cell, colliding with the grid
		//defined by AddTex.

		//Used for binary search subtracer.
		float TracedMinM = 0.;
		float MinDist;
		float MixTot = 0;

		int3 LowestAxis = 0.0;
		float3 DirComps = -sign( RayDir ); //+1 if pos, -1 if neg
		half3 DirAbs = abs( RayDir );

		UNITY_LOOP
		int3 AO2 = ARRAYSIZE/2;
		do
		{
			iteration++;

			if( CellP.y >= ARRAYSIZE.y ) break;
			if( CellP.y < 0 ) break;
			if( CellP.x < 0 || 
				CellP.z < 0 || 
				CellP.x >= ARRAYSIZE.x || 
				CellP.z >= ARRAYSIZE.z )
				break;
			
			//if( any( abs( CellP - AO2 - 0.5 ) > AO2 ) ) break;

			//We are tracing into a cell.  Need to figure out how far we move
			//to get into the next cell.
			float3 NextSteps = frac( PartialRayPos * DirComps );

			//Anywhere we have already stepped, force it to be one full step forward.
			NextSteps = NextSteps * ( 1 - LowestAxis ) + LowestAxis;

			//Find out how many units the intersection point between us and
			//the next intersection is in ray space.  This is effectively
			float3 Dists = NextSteps / DirAbs;

			//XXX TODO: This should be optimized!
			LowestAxis = (Dists.x < Dists.y) ?
				 ( ( Dists.x < Dists.z ) ? int3( 1, 0, 0 ) : int3( 0, 0, 1 ) ) :
				 ( ( Dists.y < Dists.z ) ? int3( 0, 1, 0 ) : int3( 0, 0, 1 ) );

			//Find the closest axis.  We do this so we don't overshoot a hit.
			MinDist = min( min( Dists.x, Dists.y ), Dists.z );

			//XXX XXX XXX
			VT_FN( CellP, MinDist.xxxx, Accumulator );
			
			//We now know which direction we wish to step.
			CellP += CellD * LowestAxis;

			float3 Motion = MinDist * RayDir;
			PartialRayPos = frac( PartialRayPos + Motion );

		} while( iteration < VT_MAXITER );
	}
	return Accumulator;
}


#endif
