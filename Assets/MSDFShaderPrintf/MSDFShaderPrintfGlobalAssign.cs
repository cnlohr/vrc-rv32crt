using UnityEngine;

#if UDONSHARP
using UdonSharp;
using VRC.SDKBase;
using VRC.Udon.Common.Interfaces;
using VRC.Udon;
using static VRC.SDKBase.VRCShader;
[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class MSDFShaderPrintfGlobalAssign : UdonSharpBehaviour
{
	public Texture MSDFAssignTexture;

	void Start()
	{
		int id = VRCShader.PropertyToID("_UdonMSDFPrintf"); 
		VRCShader.SetGlobalTexture( id, MSDFAssignTexture );
	}
}
#else

public class MSDFShaderPrintfGlobalAssign : Behaviour
{
	public Texture MSDFAssignTexture;

	void Start()
	{
		int id = Shader.PropertyToID("_UdonMSDFPrintf"); 
		Shader.SetGlobalTexture( id, MSDFAssignTexture );
	}
}
	
#endif
