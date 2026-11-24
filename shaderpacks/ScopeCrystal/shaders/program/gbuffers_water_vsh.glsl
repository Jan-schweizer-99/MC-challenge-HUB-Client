uniform mat4 gbufferModelView;
#include "/lib/common.glsl"
in vec4 mc_Entity;
in vec4 mc_midTexCoord;
#include "/lib/arena_material_ids.glsl"

uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;

out vec2 texcoord;
out vec2 lmcoord;
out vec4 glcolor;
out vec3 viewNormal;
out vec3 worldPos;
flat out int mat;
flat out int ctm;              // 1 = Glas als durchgehende Scheibe zeichnen (Connected Textures)
flat out int blockId;
flat out int arenaRole;
flat out vec2 midUV;           // Mitte der Textur-Kachel im Atlas

void main() {
    gl_Position = ftransform();
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    glcolor = gl_Color;
    viewNormal = normalize(gl_NormalMatrix * gl_Normal);
    worldPos = (gbufferModelViewInverse * (gl_ModelViewMatrix * gl_Vertex)).xyz + cameraPosition;
    int rawId = int(mc_Entity.x + 0.5);
    int id = arenaBaseMaterial(rawId);
    arenaRole = arenaMaterialRole(rawId);
    mat = id == 10001 ? 1 : (id == 10002 || id == 10006 || id == 10014) ? 2 : id == 10003 ? 3 : 0;
    ctm = (id == 10002 || id == 10014) ? 1 : 0;
    blockId = id;
    midUV = (gl_TextureMatrix[0] * mc_midTexCoord).xy;
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
