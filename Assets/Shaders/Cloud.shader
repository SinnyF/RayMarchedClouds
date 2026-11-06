Shader "Custom/Cloud"
{
    Properties
    {
        [MainColor] _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        _ShadowColor("Shadow Color", Color) = (0,0,0,1)
        [MainTexture] _BaseMap("Base Map", 2D) = "white" {}
        _3DTexture ("Texture3D", 3D) = "" {}
        _LightScattering("Light scattering", Range(0, 1)) = 0.7
        _PowderIntensity("Powder Sugar Intensity", Range(0, 5)) = 1.0
    }

    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }
        
        Pass
        {
            HLSLPROGRAM

            #pragma vertex Vert
            #pragma fragment frag
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

            float4 _BaseColor;
            float4 _ShadowColor;
            int lightStep;
            int rayStep;

            float3 boundsMin;
            float3 boundsMax;
            float3 timeOffset;
            float3 rayOffset;

            float stepSize;
            float densityMod;
            float scale;
            float noiseOffset;
            float threshold;
            float bias;
            float _LightScattering;
            float shadowThreshold;
            float lightAbsorb;
            float _PowderIntensity;
            TEXTURE3D(_3DTexture);

            // Dual Henyey-Greenstein to provide both a forward silver lining and a subtle backscatter glow
            float henyey_greenstein(float a, float g)
            {
                float g2 = g*g;
                float forwardScatter = (1-g2) / (4*3.141592*pow(1+g2-2*g*a, 1.5));
                
                // Secondary backward scattering
                float k = 0.3; 
                float backwardScatter = (1-(k*k)) / (4*3.141592*pow(1+(k*k)-2*(-k)*a, 1.5));
                
                return lerp(forwardScatter, backwardScatter, 0.2);
            }
            
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
                float4 col = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, IN.texcoord);
                float depth = SampleSceneDepth(IN.texcoord);
                float3 worldPos = ComputeWorldSpacePosition(IN.texcoord, depth, UNITY_MATRIX_I_VP);
                float maxTravelDistance = length(worldPos - _WorldSpaceCameraPos);
                float transmittance = 1.0;
                float3 rayOrigin = _WorldSpaceCameraPos;
                float3 rayDir = normalize(worldPos.xyz - _WorldSpaceCameraPos);
                
                float2 pixelCoords = IN.texcoord * _BlitTexture_TexelSize.zw;
                float3 accumulatedLight = float3(0, 0, 0);
                
                depth = LinearEyeDepth(depth, _ZBufferParams);
                float2 rayBox = rayBoxDst(boundsMin, boundsMax, rayOrigin, 1.0 / rayDir);
                
                float ditherNoise = InterleavedGradientNoise(pixelCoords, (int)(_Time.y / max(HALF_EPS, unity_DeltaTime.x)));
                
                float3 rayPos = rayOrigin + rayBox.x * rayDir + rayDir * ditherNoise * noiseOffset;
                stepSize = (rayBox.y / rayStep);
                
                [loop]
                for(int i = 0; i < rayStep; i++){
                    rayPos += (rayDir * stepSize);
                    float currentRayDist = length(rayPos - _WorldSpaceCameraPos);
                    bool hit = rayBox.y > 0 && currentRayDist < maxTravelDistance;
                    
                    if(hit){
                        float texSample = _3DTexture.SampleLevel(sampler_TrilinearRepeat, (rayPos * scale) + timeOffset + rayOffset, 0).r;
                        texSample -= threshold - texSample * bias;
                        texSample = max(0, texSample);
                        
                        if(texSample > 0){
                            Light mainLight = GetMainLight(TransformWorldToShadowCoord(rayPos));
                            float lightTransmittance = 1.0;
                            
                            float3 lightRayPos = rayPos;
                            float2 lightRayBox = rayBoxDst(boundsMin, boundsMax, lightRayPos, 1.0 / mainLight.direction);
                            float lightStepSize = (lightRayBox.y / max(1, lightStep));
                            
                            lightRayPos += mainLight.direction * ditherNoise * lightStepSize;
                            
                            float lightDensity = 0;
                            
                            [loop]
                            for (int j = 0; j < lightStep; j++) {
                                lightRayPos += mainLight.direction * lightStepSize; 
                                
                                float lightSample = _3DTexture.SampleLevel(sampler_TrilinearRepeat, (lightRayPos * scale) + timeOffset + rayOffset, 0).r;
                                lightSample -= threshold - lightSample * bias;
                                lightSample = max(0, lightSample);
                                
                                lightDensity += lightSample * lightStepSize;
                            }
                            lightTransmittance *= exp(-lightDensity * densityMod * lightAbsorb);
                            
                            float powderSugar = 1.0 - exp(-texSample * _PowderIntensity);
                            lightTransmittance = lerp(lightTransmittance, lightTransmittance * powderSugar, 1.0 - lightTransmittance);
                            
                            lightTransmittance = shadowThreshold + lightTransmittance * (1.0 - shadowThreshold) * mainLight.shadowAttenuation;
                            
                            float phase = henyey_greenstein(dot(rayDir, mainLight.direction), _LightScattering);
                            float3 lightEnergy = lerp(_ShadowColor.rgb, mainLight.color.rgb, lightTransmittance) * phase;
                            
                            accumulatedLight += lightEnergy * texSample * stepSize * transmittance * _BaseColor.rgb;
                            transmittance *= exp(-stepSize * texSample * densityMod * lightAbsorb);
                        
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
                return saturate(col);
            }

            ENDHLSL
        }
    }
}
