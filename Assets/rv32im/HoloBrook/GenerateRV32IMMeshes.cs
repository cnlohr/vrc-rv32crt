#if UNITY_EDITOR
using UnityEngine;
using UnityEditor;

public class GenerateRV32IMMeshes : MonoBehaviour
{
	[MenuItem("Tools/Create rv32im Meshes")]
	static void CreateMesh_()
	{
		int size = 256;
		Mesh mesh = new Mesh();
		mesh.vertices = new Vector3[size];
		int[] mindices = new int[size];
		for( int i = 0; i < size; i++ )
		{
			mesh.vertices[i] = new Vector3( 0, 0, 0 );
			mindices[i] = i;
		}

		mesh.bounds = new Bounds(new Vector3(0, 0, 0), new Vector3(5, 5, 5));
		mesh.SetIndices( mindices, MeshTopology.Points, 0, false, 0);
		AssetDatabase.CreateAsset(mesh, "Assets/rv32im/HoloBrook/HoloBrook-Geo.asset");

		mesh = new Mesh();
		mesh.vertices = new Vector3[6] { new Vector3( -1, -1, -1 ), new Vector3( -1, 1, -1 ), new Vector3( 1, -1, 1 ), new Vector3( 1, 1, 1 ), new Vector3( 1, -1, -1 ), new Vector3( -1, 1, 1 ) };
		mesh.uv = new Vector2[6] { new Vector2( 0, 0 ), new Vector2( 1, 0 ), new Vector2( 0, 1 ), new Vector2( 1, 0 ), new Vector2( 0, 1 ), new Vector2( 1, 1 ) };
		mesh.bounds = new Bounds(new Vector3(0, 0, 0), new Vector3(5, 5, 5));
		int[] indices = new int[6] { 0, 1, 2, 3, 4, 5 };
		mesh.SetIndices(indices, MeshTopology.Triangles, 0, false, 0);
		AssetDatabase.CreateAsset(mesh, "Assets/rv32im/tracked_mesh.asset");
	}
}
#endif