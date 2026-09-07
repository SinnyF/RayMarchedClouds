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
            float3 timeOffset;

            float stepSize;
            float densityMod;
            float scale;

            sampler3D _3DTexture;

            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
                float4 _BaseMap_ST;
            CBUFFER_END

            //Functions

            float rand3dTo1d(float3 value, float3 dotDir = float3(12.9898, 78.233, 37.719)){
	            //make value smaller to avoid artefacts
	            float3 smallValue = sin(value);
	            //get scalar value from 3d vector
	            float random = dot(smallValue, dotDir);
	            //make value more random by making it bigger and then taking the factional part
	            random = frac(sin(random) * 143758.5453);
	            return random;
            }

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

                for(int i = 0; i<256; i++){
                    rayPos +=(viewDir * stepSize);
                    
                    if(inBound(boundsMin, boundsMax, rayPos) && opacity < 1){
                        opacity += densityMod * tex3D(_3DTexture, ((TransformWorldToObject(rayPos)/TransformWorldToObject(boundsMax))*scale) + timeOffset).r;
                    }
                    else
                        break;
                }

                float4 color = _BaseColor;
                color.a = opacity;
                return color;
            }
            ENDHLSL
        }
    }
}
