Shader "Custom/Cloud"
{
    Properties
    {
        [MainColor] _BaseColor("Base Color", Color) = (1, 1, 1, 1)
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

            float3 boundsMin;
            float3 boundsMax;

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);

            TEXTURE3D(_3DTexture);
            SAMPLER(sampler_3DTexture);

            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
                float4 _BaseMap_ST;
            CBUFFER_END

            //Functions

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
                OUT.viewVector = viewVector;//TransformViewToWorld(viewVector);
                return OUT;
            }
             
            half4 frag(Varyings IN) : SV_Target
            {
                
                float opacity = 0;
                float3 rayPos = IN.viewVector;
                float3 viewDir = -normalize(_WorldSpaceCameraPos - rayPos);

                for(int i = 0; i<64; i++){
                    rayPos +=(viewDir * 0.02);
                    
                    
                    if(inBound(boundsMin, boundsMax, rayPos)){
                        opacity +=0.02;// * SAMPLE_TEXTURE3D(_3DTexture, sampler_3DTexture, rayPos);
                    }
                    else
                        break;
                }

                half4 color = (0,0,0,1);
                color.rgba = opacity;
                return color;
            }
            ENDHLSL
        }
    }
}
