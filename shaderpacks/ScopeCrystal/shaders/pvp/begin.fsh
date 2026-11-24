#version 330 compatibility
#define PVP_WORLD
/*
const int colortex4Format = RGBA32F;
*/
const bool colortex4Clear = false;
const vec4 colortex4ClearColor = vec4(0.0, 0.0, 0.0, 0.0);
/* RENDERTARGETS: 4 */
#include "/program/portal_state.glsl"
