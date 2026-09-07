using Unity.Mathematics;
using UnityEngine;

[ExecuteAlways]
public class Renderer : MonoBehaviour
{
    [SerializeField] Material material;
    [SerializeField] Transform container;

    [SerializeField] float stepSize = 0.2f, density = 0.02f, scale = 1;

    Vector3 timeOffset = Vector3.zero;

    void Update()
    {
        timeOffset.x += Time.deltaTime / 10;
        material.SetVector("boundsMin", container.position - container.localScale / 2);
        material.SetVector("boundsMax", container.position + container.localScale / 2);
        material.SetVector("timeOffset", timeOffset);
        material.SetFloat("stepSize", stepSize);
        material.SetFloat("densityMod", density);
        material.SetFloat("scale", scale);
    }

}
