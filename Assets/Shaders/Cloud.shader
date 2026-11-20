Shader "Custom/Cloud"
{
    Properties
    {
        [MainColor] _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        _ShadowColor("Shadow Color", Color) = (0,0,0,1)
        [MainTexture] _BaseMap("Base Map", 2D) = "white" {}
        _3DTexture ("Texture3D", 3D) = "" {}
    }

    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }
        
        Pass
        {
            HLSLPROGRAM

            #pragma vertex Vert
            #pragma fragment frag
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE 

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

            float4 _BaseColor; //Cloud Color
            float4 _ShadowColor; //Color of the shadow
            int lightStep; //Amount of max steps to do in Lightmarching
            int rayStep; //As above but for raymarching

            float3 boundsMin; //Lower bounds of the box to render the clouds within
            float3 boundsMax; //Upper bounds
            float3 timeOffset; //offset for the texture sampling based on time
            float3 rayOffset; //position offset for texture sampling
            
            float densityMod; //Modifier for the sampled density from the texture
            float scale; //Scale modifier when sampling the texture
            float noiseOffset; //How strongly the noise affects the initial ray position
            float threshold; //value below which samples from the texture are discarded
            float bias; //value making dense parts of the clouds denser while lower density areas are not increased as much
            float lightScattering;//How much the light scatters through the clouds
            float lightAbsorb;//how strongly is light absorbed
            TEXTURE3D(_3DTexture);

            //Henyey-Greenstein, approximates mathematicly light scattering through the clouds, which tends to scatter more forward from the light direction
            //Initial formula based on the formula found in the shader by Sebastian Lague
            float henyey_greenstein(float a, float g)
            {
                float g2 = g*g;
                float forwardScatter = (1-g2) / (4*3.141592*pow(1+g2-2*g*a, 1.5));
                
                return forwardScatter;
            }
            //Another formula from Sebastian Lague that helps find the distance from a defined box and the distance inside it along a ray
            float2 rayBoxDst(float3 boundsMin, float3 boundsMax, float3 rayOrigin, float3 invRaydir) {
                float3 t0 = (boundsMin - rayOrigin) * invRaydir;
                float3 t1 = (boundsMax - rayOrigin) * invRaydir;
                float3 tmin = min(t0, t1);
                float3 tmax = max(t0, t1);
                
                float dstA = max(max(tmin.x, tmin.y), tmin.z);
                float dstB = min(tmax.x, min(tmax.y, tmax.z));
                
                float dstToBox = max(0, dstA);
                float dstInsideBox = max(0, dstB - dstToBox);
                return float2(dstToBox, dstInsideBox);
            }
            
            half4 frag(Varyings IN) : SV_Target
            {
                //Sampling the current screen buffer color
                float4 col = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, IN.texcoord);
                float depth = SampleSceneDepth(IN.texcoord);
                //Getting drawn pixel world position from the camera view by reconstucting clip space and reversing View Projection using inverted view matrix
                float3 worldPos = ComputeWorldSpacePosition(IN.texcoord, depth, UNITY_MATRIX_I_VP);
                float maxTravelDistance = length(worldPos - _WorldSpaceCameraPos);
                
                float3 rayOrigin = _WorldSpaceCameraPos;
                float3 rayDir = normalize(worldPos.xyz - _WorldSpaceCameraPos);
                
                float2 pixelCoords = IN.texcoord * _BlitTexture_TexelSize.zw;
                float3 accumulatedLight = float3(0, 0, 0);
                
                float2 rayBox = rayBoxDst(boundsMin, boundsMax, rayOrigin, 1.0 / rayDir);
                //Noise for offsetting ray origin to blur banding at low amount of steps
                float ditherNoise = InterleavedGradientNoise(pixelCoords, (int)(_Time.y / max(HALF_EPS, unity_DeltaTime.x)));
                float3 rayPos = rayOrigin + rayBox.x * rayDir + rayDir * ditherNoise * noiseOffset;
                //Varaible stepsize depending on the distance within the box for the current ray
                float stepSize = (rayBox.y / rayStep);
                
                float transmittance = 1.0;
                //raymarching
                [loop]
                for(int i = 0; i < rayStep; i++){
                    rayPos += (rayDir * stepSize);
                    float currentRayDist = length(rayPos - _WorldSpaceCameraPos);
                    bool hit = rayBox.y > 0 && currentRayDist < maxTravelDistance;
                    //if we are outside box, break early
                    if(hit){
                        float texSample = _3DTexture.SampleLevel(sampler_TrilinearRepeat, (rayPos * scale) + timeOffset + rayOffset, 0).r;
                        texSample -= threshold - texSample * bias;
                        texSample = max(0, texSample);
                        //If the sample we took is zero there isn't much point in doing all the calculations
                        if(texSample > 0){
                            Light mainLight = GetMainLight(TransformWorldToShadowCoord(rayPos));
                            float lightTransmittance = 1.0;
                            
                            float3 lightRayPos = rayPos;
                            float2 lightRayBox = rayBoxDst(boundsMin, boundsMax, lightRayPos, 1.0 / mainLight.direction);
                            float lightStepSize = (lightRayBox.y / max(1, lightStep));
                            
                            lightRayPos += mainLight.direction * ditherNoise * lightStepSize;
                            
                            float lightDensity = 0;
                            //lightmarching
                            [loop]
                            for (int j = 0; j < lightStep; j++) {
                                lightRayPos += mainLight.direction * lightStepSize; 
                                
                                float lightSample = _3DTexture.SampleLevel(sampler_TrilinearRepeat, (lightRayPos * scale) + timeOffset + rayOffset, 0).r;
                                lightSample -= threshold - lightSample * bias;
                                lightSample = max(0, lightSample);
                                
                                lightDensity += lightSample * lightStepSize;
                            }
                            lightTransmittance *= exp(-lightDensity * densityMod * lightAbsorb);
                            
                            float powderSugar = 1.0 - exp(-lightDensity * densityMod * lightAbsorb * 2.0);
                            lightTransmittance = lightTransmittance * powderSugar * 2.0;
                            //Apply shadow from the mainlight
                            lightTransmittance = lightTransmittance * mainLight.shadowAttenuation;
                            //Mix between two HGs to add backscattering to the clouds, set at 0.2 to not mix in too much backscattering
                            float phase = lerp(henyey_greenstein(dot(rayDir, mainLight.direction), lightScattering), henyey_greenstein(dot(rayDir, mainLight.direction), -0.2),0.2);
                            
                            float3 lightEnergy = mainLight.color.rgb * lightTransmittance * phase + _ShadowColor.rgb;
                            
                            accumulatedLight += lightEnergy * texSample * densityMod * stepSize * transmittance * _BaseColor.rgb;
                            transmittance *= exp(-stepSize * texSample * densityMod * lightAbsorb);
                            //if we can't gather any more useful data, break early
                            if (transmittance < 0.01) {
                                transmittance = 0.0;
                                break;
                            }
                        }
                    }
                    else
                        break;
                }
                col.rgb = col.rgb * transmittance + accumulatedLight;
                //clamp final value
                return saturate(col);
            }

            ENDHLSL
        }
    }
}
