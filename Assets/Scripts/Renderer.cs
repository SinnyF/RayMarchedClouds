using Unity.Mathematics;
using UnityEngine;

[ExecuteAlways]
public class Renderer : MonoBehaviour
{
    [SerializeField] Material material;
    [SerializeField] Transform container;
    [SerializeField] NoiseGenerator noiseGenerator;

    [SerializeField] int rayStep = 32, lightStep = 16;

    [SerializeField][Range(0.001f, 1f)] float noiseOffset = 0.1f, lightAbsorb = 0.1f, density = 1f, lightScattering = 0.7f;
    [SerializeField][Min(0.01f)] float scale = 1;
    [SerializeField] Vector3 offset = Vector3.zero;
    [SerializeField][Range(0,1)] float threshold, bias;
    Vector3 timeOffset = Vector3.zero;
    [SerializeField] Texture3D texture;

    public bool generateTexture = false;

    private void Start()
    {
        if(generateTexture)
            texture = noiseGenerator.CreateLayeredTexture();
    }
    void Update()
    {
        //setting various uniforms at runtime for easier testing
        timeOffset.x += Time.deltaTime / 10;
        material.SetVector("boundsMin", container.position - container.localScale / 2);
        material.SetVector("boundsMax", container.position + container.localScale / 2);
        material.SetVector("timeOffset", timeOffset);
        material.SetFloat("densityMod", density);
        material.SetFloat("scale", scale);
        material.SetFloat("noiseOffset", noiseOffset);
        material.SetFloat("lightAbsorb", lightAbsorb);
        material.SetTexture("_3DTexture", texture);
        material.SetVector("rayOffset", offset);
        material.SetInt("lightStep", lightStep);
        material.SetInt("rayStep", rayStep);
        material.SetFloat("threshold", threshold);
        material.SetFloat("bias", bias);
        material.SetFloat("lightScattering",  lightScattering);
    }

}
