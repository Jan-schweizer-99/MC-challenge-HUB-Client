#include "/lib/common.glsl"

uniform sampler2D gtexture;
uniform sampler2D lightmap;
uniform float frameTimeCounter;
uniform vec3 cameraPosition;
uniform mat4 gbufferModelViewInverse;

in vec2 texcoord;
in vec2 lmcoord;
in vec4 glcolor;
in vec3 viewNormal;
in vec3 worldPos;
flat in int mat;
flat in int ctm;
flat in int blockId;
flat in int arenaRole;
flat in vec2 midUV;

layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outData;
layout(location = 2) out vec4 outLight;

#ifdef PVP_WORLD
#include "/lib/arena_floor.glsl"
#endif

void main() {
#ifdef PVP_WORLD
#ifndef PORTAL_HAND
    if (!portalFragmentVisible(worldPos, cameraPosition + gbufferModelViewInverse[3].xyz, cameraPosition)) discard;
#endif
#endif
    vec4 c = texture(gtexture, texcoord) * glcolor;
#if GLASS_STYLE >= 1
    // Glas-Option: Farbe aus der Kachelmitte → durchgehende Scheibe ohne Rahmenlinien zwischen den Blöcken
    if (ctm == 1) {
        vec4 m = textureLod(gtexture, midUV, 0.0) * glcolor;
#if GLASS_STYLE >= 2
        // fancy: Glanzstreifen in Weltkoordinaten laufen nahtlos über die ganze Scheibe
        float diag = worldPos.x + worldPos.z + worldPos.y * 1.4;
        float sheen = smoothstep(0.93, 1.0, sin(diag * 0.9 + frameTimeCounter * 0.4)) * 0.5
                    + smoothstep(0.97, 1.0, sin(diag * 2.3 - 1.0)) * 0.25;
#else
        float sheen = 0.0;
#endif
        c = vec4(m.rgb + vec3(sheen), max(m.a, 0.28) + sheen * 0.3);
    }
#endif
#ifdef PVP_WORLD
    if (arenaRole >= 0 && arenaRole != 4 && arenaPaletteChanging(worldPos)) {
        vec2 uv = (texcoord - midUV) * vec2(textureSize(gtexture, 0)) / 16.0 + 0.5;
        vec4 paired = arenaPairedTexture(arenaRole, uv, arenaTextureLevel(uv), frameTimeCounter);
        vec3 sheen = max(c.rgb - textureLod(gtexture, midUV, 0.0).rgb * glcolor.rgb, vec3(0.0));
        c.rgb = paired.rgb * glcolor.rgb + sheen;
    }
    // Lava-Insel: Glas (Rolle 4) deckt den Lava-Graben ab und wird unten vollflächig als runder Ring gemalt.
    // Darum seine durchsichtigen Pixel NICHT verwerfen – sonst bleibt nur das Rahmengitter übrig.
    vec3 nW = mat3(gbufferModelViewInverse) * normalize(viewNormal);
    bool roundTop = arenaRole == 4 && arenaFloorSurface(worldPos, nW);
    if (c.a < 0.02 && !roundTop) discard;
#else
    if (c.a < 0.02) discard;
#endif
    c.rgb *= texture(lightmap, lmcoord).rgb;
#if REFLECTIONS > 0
    if (mat == 1) c.a = max(c.a, 0.55);       // Wasser etwas dichter, damit die Spiegelung trägt
#endif
    int surfaceMat = mat == 0 ? 2 : mat;
#ifdef PVP_WORLD
    if (roundTop) {
        c = vec4(roundArenaFloor(worldPos, glcolor.rgb, texture(lightmap, lmcoord).rgb, frameTimeCounter), 1.0);
        surfaceMat = 3;
    }
#endif
    outColor = c;
    outData = vec4(normalize(viewNormal) * 0.5 + 0.5, encodeMat(surfaceMat));
    outLight = vec4(lmcoord, 0.0, 1.0);
}
