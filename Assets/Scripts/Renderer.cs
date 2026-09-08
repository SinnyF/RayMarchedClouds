using Unity.Mathematics;
using UnityEngine;

[ExecuteAlways]
public class Renderer : MonoBehaviour
{
    [SerializeField] Material material;
    [SerializeField] Transform container;
    [SerializeField] NoiseGenerator noiseGenerator;

    [SerializeField][Range(0.001f,1f)] float stepSize = 0.2f, density = 0.02f;
    [SerializeField][Min(0.01f)] float scale = 1;
    [SerializeField] Vector3 offset = Vector3.zero;

    Vector3 timeOffset = Vector3.zero;
    Texture3D texture;

    private void Start()
    {
        texture = noiseGenerator.CreateTexture();
    }
    void Update()
    {
        timeOffset.x += Time.deltaTime / 10;
        material.SetVector("boundsMin", container.position - container.localScale / 2);
        material.SetVector("boundsMax", container.position + container.localScale / 2);
        material.SetVector("timeOffset", timeOffset);
        material.SetFloat("stepSize", stepSize);
        material.SetFloat("densityMod", density);
        material.SetFloat("scale", scale);
        material.SetTexture("_3DTexture", texture);
        material.SetVector("rayOffset", offset);
    }

}
