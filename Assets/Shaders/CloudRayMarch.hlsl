#if !defined(SHADERGRAPH_PREVIEW)
void raymarchv1_float( float3 rayOrigin, float3 rayDirection, float numSteps, float stepSize,
                     float densityScale, float4 Sphere, out float result )
{
	float density = 0;
	
	for(int i =0; i< numSteps; i++){
		rayOrigin += (rayDirection*stepSize);
					
		//Calculate density
		float sphereDist = distance(rayOrigin, Sphere.xyz);

		if(sphereDist < Sphere.w){
			density += 0.15;
        }
					
	}

	result = density * densityScale;
}
#endif