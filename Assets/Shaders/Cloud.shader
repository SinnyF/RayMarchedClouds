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
        Tags { "RenderType" = "Transparent" "RenderPipeline" = "UniversalPipeline" "Queue"="Transparent"}
        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite Off
        Pass
        {
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 viewVector : TEXCOORD1;
                float opacity : INTERP0;
            };

            int lightStep;
            int rayStep;

            float3 boundsMin;
            float3 boundsMax;
            float3 timeOffset;
            float3 rayOffset;

            float stepSize;
            float densityMod;
            float scale;
            float shadowThreshold;
            float transmitance;
            float lightAbsorb;

            sampler3D _3DTexture;

            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
                half4 _ShadowColor;
                float4 _BaseMap_ST;
            CBUFFER_END


            bool inBound(float3 boundsMin, float3 boundsMax, float3 rayOrigin) {
                return rayOrigin.x>boundsMin.x && rayOrigin.y>boundsMin.y && rayOrigin.z>boundsMin.z
                       && rayOrigin.x<boundsMax.x && rayOrigin.y<boundsMax.y && rayOrigin.z<boundsMax.z;
            }

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.uv = TRANSFORM_TEX(IN.uv, _BaseMap);

                VertexPositionInputs vertexInput = GetVertexPositionInputs(IN.positionOS.xyz);
                
                float3 viewVector = vertexInput.positionWS;
                OUT.viewVector = viewVector;
                return OUT;
            }
             
            half4 frag(Varyings IN) : SV_Target
            {
                
                float opacity = 0;
                float3 rayPos = IN.viewVector;
                float3 viewDir = -normalize(_WorldSpaceCameraPos - rayPos);

                float3 light = GetMainLight().direction;
                float transmission = 0;
                float finalLight = 0;
                float lightAccumulation = 0;

                [loop]
                for(int i = 0; i<rayStep; i++){
  
                    rayPos +=(viewDir * stepSize);
                    float3 lightRay = rayPos;
                    [loop]
                    for(int j = 0; j < lightStep; j++){
                        float lightDensity = stepSize * densityMod * tex3D(_3DTexture, (TransformWorldToObject(lightRay)*scale) + timeOffset + rayOffset).r;
                        lightAccumulation += lightDensity;
                        lightDensity = min(lightDensity, 1);
                        lightRay += light*stepSize;
                        if(!inBound(boundsMin, boundsMax, lightRay) || lightAccumulation == 1)
                            break;
                    }
                    float lightTransmission = exp(-lightAccumulation);
                    float shadow = shadowThreshold + lightTransmission * (1.0 -shadowThreshold);
                    finalLight += opacity*transmitance*shadow;
                    transmitance *= exp(-opacity*lightAbsorb);

                    if(inBound(boundsMin, boundsMax, rayPos) && opacity < 1){
                        opacity += stepSize * densityMod * tex3D(_3DTexture, (TransformWorldToObject(rayPos)*scale) + timeOffset + rayOffset).r;
                        //opacity = min(opacity,1);
                    }
                    else
                        break;
                }

                transmission = exp(-opacity);           

                float4 color = lerp(_ShadowColor,_BaseColor, finalLight);
                color.a = opacity;
                return color;
            }
            ENDHLSL
        }
    }
}
