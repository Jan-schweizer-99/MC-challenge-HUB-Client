#include "/lib/common.glsl"

uniform sampler2D gtexture;
uniform sampler2D lightmap;
uniform vec4 entityColor;
uniform vec3 cameraPosition;
uniform mat4 gbufferModelViewInverse;
uniform int entityId;
uniform float frameTimeCounter;
#ifdef PVP_WORLD
#include "/lib/arena_materials.glsl"
#endif

in vec2 texcoord;
in vec2 lmcoord;
in vec4 glcolor;
in vec3 worldPos;
in vec3 displayNormal;

layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outData;    // "kein Material": keine Spiegelung/Verdeckung auf Hand und Figuren
layout(location = 2) out vec4 outLight;

void main() {
#ifdef PVP_WORLD
#ifdef PORTAL_BLOCK_ENTITY
    // End-Portal-Ersatzflaeche fuer Spieler ohne Shader (Arena.sendPortalSurface): hier unsichtbar
    vec3 portalLocal = portalSceneLocal(worldPos);
    if (portalLocal.y > PORTAL_Y + 0.3 && portalLocal.y < PORTAL_Y + 0.8 && portalOpeningCell(portalLocal.xz)) discard;
#endif
#ifndef PORTAL_HAND
    if (!portalFragmentVisible(worldPos, cameraPosition + gbufferModelViewInverse[3].xyz, cameraPosition)) discard;
#endif
#endif
    vec4 c = texture(gtexture, texcoord) * glcolor;
    if (c.a < 0.1) discard;
#ifdef PVP_WORLD

    vec3 local = arenaLocal(worldPos);
    if (entityId == 101 && local.y > 108.99 && local.y < 110.01 && arenaPaletteChanging(worldPos)) {
        ivec3 block = ivec3(floor(local - normalize(displayNormal) * 0.001));
        if (block.y == 109 && max(abs(block.x), abs(block.z)) == 3) {
            bool corner = abs(block.x) == 3 && abs(block.z) == 3;
            int role = corner ? 7 : (block.x + block.z) % 3 == 0 ? 6 : 5;
            vec2 uv = texcoord * vec2(textureSize(gtexture, 0)) / 16.0;
            c.rgb = arenaPairedTexture(role, uv, arenaTextureLevel(uv), frameTimeCounter).rgb * glcolor.rgb;
        }
    }
#endif
#ifdef PVP_WORLD
    // Gedrehte Sockel in Hub und Hall of Fame: gleiche Schattierung
    vec2 hallQ = worldPos.xz - vec2(0.5, -554.5);
    bool hallBase = entityId == 101 && worldPos.y > 103.9 && worldPos.y < 107.1 && length(hallQ) < 27.0;
    if (hallBase) {
        vec3 hn = displayNormal * displayNormal / max(dot(displayNormal, displayNormal), 1e-4);
        c.rgb *= hn.x * 0.6 + hn.z * 0.8 + hn.y * (displayNormal.y > 0.0 ? 1.0 : 0.5);
        c.rgb *= mix(0.78, 1.0, smoothstep(104.0, 104.7, worldPos.y));
    }
    // Gedrehte Hub-Sockel (Block-Displays) wie Bloecke schattieren: oben hell, Seiten dunkler, fliessend je Drehung
    if (entityId == 101 && worldPos.y > 100.9 && worldPos.y < 104.1 && length(worldPos.xz - CHAL.xz) < 18.0) {
        vec3 n2 = displayNormal * displayNormal / max(dot(displayNormal, displayNormal), 1e-4);
        c.rgb *= n2.x * 0.6 + n2.z * 0.8 + n2.y * (displayNormal.y > 0.0 ? 1.0 : 0.5);
        c.rgb *= mix(0.78, 1.0, smoothstep(101.0, 101.7, worldPos.y));      // weicher Kontaktschatten am Boden
    }
#endif
    c.rgb = mix(c.rgb, entityColor.rgb, entityColor.a);   // rotes Aufblinken bei Treffern
    c.rgb *= texture(lightmap, lmcoord).rgb;
    outColor = c;
    outData = vec4(0.0, 0.0, 0.0, 0.0);
    outLight = vec4(lmcoord, 0.0, 1.0);
}
