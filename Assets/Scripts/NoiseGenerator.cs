using UnityEditor;
using UnityEngine;

public class NoiseGenerator : MonoBehaviour
{
    
    [SerializeField] Transform container;
    [SerializeField] int numCells, cellSize;
    int size;

    public Texture3D CreateTexture(int numCells, int cellSize)
    {
        size = numCells * cellSize;
        TextureFormat format = TextureFormat.RGBA32;
        TextureWrapMode wrapMode = TextureWrapMode.Repeat;

        Texture3D texture = new Texture3D(size, size, size, format, false);
        texture.wrapMode = wrapMode;

        Vector3[,,] points = CreatePoints(numCells);

        for(int x = 0; x<size; x++)
        {
            for (int y = 0; y < size; y++)
            {
                for ( int z = 0; z < size; z++)
                {

                    int cellx = x/ cellSize;
                    int celly = y/ cellSize;
                    int cellz = z/ cellSize;

                    float distance = Vector3.Distance(points[cellx, celly, cellz],
                        (new Vector3(x, y, z)/size)) * numCells;

                    for (int i = -1; i < 2; i++)
                    {
                        for (int j = -1; j < 2; j++)
                        {
                            for (int k = -1; k < 2; k++)
                            {
                                if (i == 0 && j == 0 && k == 0)
                                    break;

                                int loopx = cellx + i;
                                int loopy = celly + j;
                                int loopz = cellz + k;

                                //Vector3 projectedPoint = Vector3.zero;

                                if (loopx < 0) loopx = cellx;
                                if (loopz < 0) loopz = cellz;
                                if (loopy < 0) loopy = celly;

                                if (loopx == numCells) loopx = cellx;
                                if (loopy == numCells) loopy = cellz;
                                if (loopz == numCells) loopz = celly;

                                distance = Mathf.Min(distance, Vector3.Distance(points[loopx, loopy, loopz],
                                    (new Vector3(x, y, z) / size)) * numCells);

                            }
                        }
                    }

                    //if (distance < lowerThreshold) distance = 0;
                    //if (distance > upperThreshold) distance = 1;

                    Color color = (1-distance) * Color.white;
                    texture.SetPixel(x,y,z,color);

                    
                }
            }
        }
        texture.Apply();
        return texture;
    }

    Vector3[,,] CreatePoints(int numCells)
    {
        Vector3[,,] points = new Vector3[numCells,numCells,numCells];
        float cellSize = 1f / numCells;

        for (int x = 0; x < numCells; x++)
        {
            for (int y = 0; y < numCells; y++)
            {
                for (int z = 0; z < numCells; z++)
                {
                    float xOffset = Random.Range(0.15f, 0.85f);
                    float yOffset = Random.Range(0.15f, 0.85f);
                    float zOffset = Random.Range(0.15f, 0.85f);
                    Vector3 offset = new Vector3(xOffset, yOffset, zOffset) * cellSize;
                    Vector3 cellCorner = new Vector3(x ,y,z) * cellSize;

                    Debug.Log(x +","+y+","+z + ": " + cellCorner +" + " + offset);
                    Debug.DrawLine(cellCorner, cellCorner + offset);
                    points[x,y,z] = cellCorner + offset;
                }
            }
        }
        return points;
    }

    public Texture3D CreateLayeredTexture()
    {
        Texture3D first = CreateTexture(numCells, cellSize);
        Texture3D second = CreateTexture(numCells*2, cellSize/2);

        Color[] colors = new Color[size * size * size];
        for (int x = 0;x < size; x++)
        {
            int xOffset = x * size * size;
            for (int y = 0; y < size; y++)
            {
                int yOffset = y * size;
                for ( int z = 0; z < size; z++)
                {
                    colors[z + yOffset + xOffset] = Color.white * (Mathf.Max(first.GetPixel(x,y,z).r, second.GetPixel(x,y,z).r ));
                }
            }
        }
        first.SetPixels(colors);
        first.Apply();
        AssetDatabase.CreateAsset(first, "Assets/Example3DTexture.asset");
        return first;
    }
}
