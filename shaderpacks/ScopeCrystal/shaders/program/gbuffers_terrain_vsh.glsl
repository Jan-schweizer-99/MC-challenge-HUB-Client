#include "/lib/common.glsl"
in vec4 mc_Entity;
in vec4 mc_midTexCoord;
#include "/lib/arena_material_ids.glsl"

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;
uniform float frameTimeCounter;

out vec2 texcoord;
out vec2 lmcoord;
out vec4 glcolor;
out vec3 viewNormal;
flat out int mat;
flat out int crystal;          // 1 = Amethyst-Kristall (pulsiert im Fragment-Shader)
flat out int blockId;          // Roh-ID aus block.properties (für das Umfärben des Arenabodens)
flat out int arenaRole;
flat out vec2 midUV;           // Mitte der Textur-Kachel
out vec3 worldPos;

void main() {
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    glcolor = gl_Color;                       // enthält die Vanilla-Umgebungsverdeckung
    viewNormal = normalize(gl_NormalMatrix * gl_Normal);
    int rawId = int(mc_Entity.x + 0.5);
    int id = arenaBaseMaterial(rawId);
    arenaRole = arenaMaterialRole(rawId);
    mat = id == 10001 ? 1 : (id == 10002 || id == 10006 || id == 10014) ? 2
        : (id == 10003 || id == 10008 || id == 10009 || id == 10010 || id == 10012) ? 3 : id == 10007 ? 4 : 0;
    crystal = id == 10004 ? 1 : 0;
#ifdef PVP_WORLD
    if (arenaRole == 4 || (arenaRole >= 5 && arenaRole <= 7) || arenaRole == 14) mat = 2;
    else if (arenaRole == 8) mat = 4;
    else if ((arenaRole >= 0 && arenaRole <= 3) || (arenaRole >= 9 && arenaRole <= 12)) mat = 3;
#endif
    blockId = id;
    midUV = (gl_TextureMatrix[0] * mc_midTexCoord).xy;
    worldPos = (gbufferModelViewInverse * (gl_ModelViewMatrix * gl_Vertex)).xyz + cameraPosition;

    gl_Position = ftransform();
#ifdef PVP_WORLD
    // Vertex-Shader-Animation: obere Eckpunkte der Amethyst-Kristalle wiegen im "Kristallwind"
    if (crystal == 1) {
        vec4 rel = gbufferModelViewInverse * (gl_ModelViewMatrix * gl_Vertex);   // relativ zur Kamera
        vec3 world = rel.xyz + cameraPosition;
        bool top = gl_MultiTexCoord0.t < mc_midTexCoord.t;                       // obere Hälfte der Textur
        if (top) {
            float t = frameTimeCounter;
            float phase = world.x * 0.7 + world.z * 0.9;
            rel.xz += vec2(sin(t * 2.1 + phase), cos(t * 1.7 + phase * 1.3)) * 0.14;
            rel.y += sin(t * 3.0 + phase) * 0.05;
        }
        worldPos = rel.xyz + cameraPosition;
        gl_Position = gl_ProjectionMatrix * (gbufferModelView * rel);
    }
#endif
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
