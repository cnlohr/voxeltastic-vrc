# voxeltastic-vrc

Voxel Tracing Shader for VRChat

Direct voxel tracer that can support varying densities.

It works with:
  * Arbitrary density functions/maps
  * Mirrors
  * Players and objects in the midst of the map
  * Has example shader / data (MRI, Wifi data, Bunny)

It is written as a generic shader that:
  * Demonstrates Z Write
  * Demonstrates Depth Texture Read
  * Demonstrates World-Space operations from pixel shader.


Demo here: https://github.com/cnlohr/voxeltastic-vrc/blob/master/Assets/cnlohr/Shaders/voxeltastic/VoxeltasticDemo.shader

Underlying Marcher here: https://github.com/cnlohr/voxeltastic-vrc/blob/master/Assets/cnlohr/Shaders/voxeltastic/voxeltastic.cginc
