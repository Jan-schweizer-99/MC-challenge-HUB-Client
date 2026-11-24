uniform mat4 gbufferModelView;
#include "/lib/common.glsl"
// Entities, Hand, Partikel, Wetter, Block-Displays

uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;

out vec2 texcoord;
out vec2 lmcoord;
out vec4 glcolor;
out vec3 worldPos;
out vec3 displayNormal;

void main() {
    gl_Position = ftransform();
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    glcolor = gl_Color;
    displayNormal = mat3(gbufferModelViewInverse) * normalize(gl_NormalMatrix * gl_Normal);
    worldPos = (gbufferModelViewInverse * (gl_ModelViewMatrix * gl_Vertex)).xyz + cameraPosition;
#ifdef PVP_WORLD
#ifndef PORTAL_HAND
    if (portalSceneCamera(cameraPosition) && portalSceneGeometry(worldPos)) {
        vec3 aligned = portalProjectPosition(worldPos, cameraPosition);
        gl_Position = gl_ProjectionMatrix * (gbufferModelView * vec4(aligned - cameraPosition, 1.0));
        if (!portalGeometryNeeded(worldPos, cameraPosition + gbufferModelViewInverse[3].xyz, cameraPosition,
                gl_ProjectionMatrix * gbufferModelView)) gl_Position = vec4(2.0, 2.0, 2.0, 1.0);
    }
#endif
#endif
}
