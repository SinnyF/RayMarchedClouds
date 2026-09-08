using NUnit.Framework.Constraints;
using UnityEditor;
using UnityEngine;

public class NoiseGenerator : MonoBehaviour
{
    
    [SerializeField] Transform container;
    [SerializeField] int numCells, size;
    Vector3[,,] points;
    private void Start()
    {
        CreatePoints();
        CreateTexture();
    }
    void Update()
    {
        foreach(Vector3 point in points)
        {
            Debug.DrawLine(point, point + new Vector3(0.001f, 0.001f, 0.001f));
        }
    }

    public Texture3D CreateTexture()
    {
        TextureFormat format = TextureFormat.RGBA32;
        TextureWrapMode wrapMode = TextureWrapMode.Repeat;
        Texture3D texture = new Texture3D(size, size, size, format, false);
        texture.wrapMode = wrapMode;

        Color[] colors = new Color[size * size * size];

        for(int x = 0; x<size; x++)
        {
            int xOffset = x * size * size;
            for (int y = 0; y < size; y++)
            {
                int yOffset = y * size;
                for ( int z = 0; z < size; z++)
                {

                    int cellx = (int)((float)x / ((float)size / (float)numCells));
                    int celly = (int)((float)y / ((float)size / (float)numCells));
                    int cellz = (int)((float)z / ((float)size / (float)numCells));




                    int mod = (cellx + celly + cellz) % 2;
                    if (mod == 0)
                        colors[z + yOffset + xOffset] = Color.white;
                    else
                        colors[z + yOffset + xOffset] = Color.black;
                }
            }
        }

        texture.SetPixels(colors);
        texture.Apply();
        AssetDatabase.CreateAsset(texture, "Assets/Example3DTexture.asset");
        return texture;
    }

    void CreatePoints()
    {
        points = new Vector3[numCells,numCells,numCells];
        float cellSize = 1f / numCells;

        for (int x = 0; x < numCells; x++)
        {
            for (int y = 0; y < numCells; y++)
            {
                for (int z = 0; z < numCells; z++)
                {
                    float xOffset = Random.Range(0f, 1f);
                    float yOffset = Random.Range(0f, 1f);
                    float zOffset = Random.Range(0f, 1f);
                    Vector3 offset = new Vector3(xOffset, yOffset, zOffset) * cellSize;
                    Vector3 cellCorner = new Vector3(x ,y,z) * cellSize;

                    Debug.Log(x +","+y+","+z + ": " + cellCorner +" + " + offset);
                    Debug.DrawLine(cellCorner, cellCorner + offset);
                    points[x,y,z] = cellCorner + offset;
                }
            }
        }
    }
}
