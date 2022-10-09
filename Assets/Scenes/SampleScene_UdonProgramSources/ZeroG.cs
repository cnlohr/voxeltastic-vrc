
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.Udon;

public class ZeroG : UdonSharpBehaviour
{

    private VRCPlayerApi localPlayer;
    
    void Start()
    {
        localPlayer = Networking.LocalPlayer;
    }
    private void EnableSwimming()
    {
        localPlayer.SetGravityStrength(.1f);
        //localPlayer.Immobilize(true);
    }

    private void DisableSwimming()
    {
        localPlayer.SetGravityStrength(1);
        //localPlayer.Immobilize(false);
    }
	
    public void OnPlayerTriggerEnter (VRCPlayerApi  other)
    {
		Debug.Log( "OnTriggerEnter!!" );
		if( other == localPlayer) EnableSwimming();
    }

    public void OnPlayerTriggerExit (VRCPlayerApi  other)
    {
		Debug.Log( "OnTriggerExit!!" );
		if( other == localPlayer) DisableSwimming();
    }

}
