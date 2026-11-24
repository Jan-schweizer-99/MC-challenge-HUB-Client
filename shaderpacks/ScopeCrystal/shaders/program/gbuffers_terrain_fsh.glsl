#include "/lib/common.glsl"

uniform sampler2D gtexture;
uniform sampler2D lightmap;
uniform float frameTimeCounter;
uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;

in vec2 texcoord;
in vec2 lmcoord;
in vec4 glcolor;
in vec3 viewNormal;
flat in int mat;
flat in int crystal;
flat in int blockId;
flat in int arenaRole;
flat in vec2 midUV;
in vec3 worldPos;

layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outData;    // Normale (Blickraum) + Material
layout(location = 2) out vec4 outLight;   // Lightmap (Fackel, Himmel)

#ifdef PVP_WORLD
#include "/lib/arena_floor.glsl"
#endif

float lum(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }

vec3 hue(float h) { return clamp(abs(fract(h + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0) - 1.0, 0.0, 1.0); }

// Ortsbezogene Fackelfarbe: 16 Fackeln rund um die Arena (alle 22,5°, r ≈ 26, y ≈ 103.5).
// Farbe = Himmelsrichtung der Fackel → einmal rundherum ein Farbkreis.
#ifdef PVP_WORLD
vec3 torchColor(float ang, bool lavaSide) { return arenaFxPalette(mix(vec3(1.0), hue(ang / 6.2832 + 0.5), 0.9), lavaSide); }
#endif

float nearestTorch(vec3 wp, out float tAng) {
    float ang = atan(wp.z - 0.5, wp.x - 0.5);
    float k = floor(ang / 0.3927 + 0.5);                 // 22,5° = 0.3927 rad
    tAng = k * 0.3927;
    vec3 tp = vec3(cos(tAng) * 25.9 + 0.5, 103.5, sin(tAng) * 25.9 + 0.5);
    return length(wp - tp);
}

void main() {
#ifdef PVP_WORLD
#ifndef PORTAL_HAND
    if (!portalFragmentVisible(worldPos, cameraPosition + gbufferModelViewInverse[3].xyz, cameraPosition)) discard;
#endif
#endif
    vec4 c = texture(gtexture, texcoord) * glcolor;
#ifdef PVP_WORLD
    // Lava-Insel: Glas (Rolle 4) deckt den Lava-Graben ab. Seine Oberseite wird unten vollflächig als
    // runder Ring gemalt – darum hier nicht die durchsichtigen Glaspixel verwerfen (sonst bleibt nur das Rahmengitter).
    bool roundTop = arenaRole == 4 && arenaFloorSurface(worldPos, mat3(gbufferModelViewInverse) * normalize(viewNormal));
    if (c.a < 0.1 && !roundTop) discard;
#else
    if (c.a < 0.1) discard;
#endif
#ifdef PVP_WORLD

    if (arenaRole >= 0 && arenaPaletteChanging(worldPos)) {
        vec2 uv = (texcoord - midUV) * vec2(textureSize(gtexture, 0)) / 16.0 + 0.5;
        int role = arenaRole;
        vec3 faceNormal = mat3(gbufferModelViewInverse) * normalize(viewNormal);
        if (role == 8 && abs(faceNormal.y) > 0.5) role = 17;
        c.rgb = arenaPairedTexture(role, uv, arenaTextureLevel(uv), frameTimeCounter).rgb * glcolor.rgb;
    }
#endif
    vec3 albedo = c.rgb;
    vec3 light = texture(lightmap, lmcoord).rgb;
#ifdef PVP_WORLD
    // Fackellicht in der Arena nach Ort färben – nur in der Nähe der Fackeln, andere Lichtquellen bleiben
    float tAng;
    vec3 wpI = worldPos;
    if (wpI.x > TWIN_SPLIT) wpI.x -= TWIN_X;            // Lava-Zwilling: gleiche Fackelanordnung
    float td = nearestTorch(wpI, tAng);
    if (td < 9.0 && length(wpI.xz - vec2(0.5)) < 30.0) {
        vec3 skyOnly = texture(lightmap, vec2(1.0 / 32.0, lmcoord.y)).rgb;
        float blockAmt = max(lum(light) - lum(skyOnly), 0.0);
        float w = smoothstep(9.0, 2.5, td);
        light = mix(light, skyOnly + torchColor(tAng, arenaLavaEffects(worldPos)) * blockAmt * 1.35, w);
    }
    if (blockId == 10011) {                   // die Flamme selbst: helle, gesättigte Pixel umfärben + leuchten
        vec3 raw = texture(gtexture, texcoord).rgb;                     // ohne Schattierung prüfen
        float sat = max(raw.r, max(raw.g, raw.b)) - min(raw.r, min(raw.g, raw.b));
        if (sat > 0.2 && lum(raw) > 0.52 && raw.r >= raw.b) {            // gelb/orange = Flamme, nicht der Holzstiel
            c.rgb = torchColor(tAng, arenaLavaEffects(worldPos)) * (0.6 + lum(raw)) * 1.6;
            light = vec3(1.0);
        }
    }
#endif
    vec3 emissive = vec3(0.0);
#ifdef PVP_WORLD
    // Quarzsäulen: Ornament pixelgenau im 16×16-Raster der Textur – eingraviert wie die Original-Rillen
    vec3 nW = mat3(gbufferModelViewInverse) * normalize(viewNormal);
    if (blockId == 10007 && abs(nW.y) < 0.5) {
        float u = fract(abs(nW.x) > 0.5 ? worldPos.z : worldPos.x);
        if (abs(nW.x) > 0.5 ? nW.x < 0.0 : nW.z > 0.0) u = 1.0 - u;
        float v = worldPos.y - 101.0;                       // Höhe über dem Arenaboden
        float tx = floor(u * 16.0), ty = floor(v * 16.0);   // Texel-Spalte / -Zeile
        vec3 ice = vec3(0.45, 0.8, 1.0);
        float pulseT = frameTimeCounter;
        if (v >= 0.0 && v < 3.5) {
            // Sockel: weiße Leuchtstriche über die ganze Breite (jede 2. Texel-Spalte, inkl. beider Ränder),
            // unten am hellsten, über ~3,5 Blöcke nach oben in Transparenz auslaufend
            if (mod(tx, 2.0) == 0.0 || tx == 15.0) {
                float fade = 1.0 - smoothstep(0.0, 3.5, v);           // unten 1 → oben 0
                emissive += vec3(1.0) * fade * fade * (0.9 + 0.1 * sin(pulseT * 2.0 + tx * 0.6));
            }
        }
        if (v >= 1.0 && v < 12.0) {
            // Energie-Impulse laufen in den echten dunklen Rillen der Textur nach oben
            vec3 tex = texture(gtexture, texcoord).rgb;
            float groove = 1.0 - smoothstep(0.8, 0.92, lum(tex) / max(lum(textureLod(gtexture, midUV, 4.0).rgb), 0.05));
            float pulse = pow(fract((ty / 16.0 + floor(v)) * 0.22 - pulseT * 0.55 + tx * 0.07), 10.0);
            emissive += mix(ice, vec3(1.0), 0.3) * groove * (0.12 + 1.4 * pulse) * exp(-(v - 1.0) * 0.25);
        }
        if (v >= 0.0 && v < 3.0) emissive += ice * exp(-v * 1.3) * 0.12;   // leichtes Licht vom Fuß
    }
#endif
    c.rgb *= light;
#ifdef PVP_WORLD
    emissive = arenaFxPalette(emissive, arenaLavaEffects(worldPos));
#endif
    c.rgb += emissive;
    int surfaceMat = mat;
#ifdef PVP_WORLD
    if ((arenaRole == 0 || arenaRole == 1 || arenaRole == 2 || arenaRole == 4) && arenaFloorSurface(worldPos, nW)) {
        c.rgb = roundArenaFloor(worldPos, glcolor.rgb, light, frameTimeCounter);
        c.a = 1.0;                            // auch über Glas (Lava-Insel) deckend
        surfaceMat = 3;
    }
    if (crystal == 1) {                       // Kristalle leuchten pulsierend von selbst
        float pulse = 0.45 + 0.35 * sin(frameTimeCounter * 2.5 + gl_FragCoord.x * 0.002);
        c.rgb += arenaFxPalette(albedo * vec3(1.0, 0.75, 1.2) * pulse, arenaLavaEffects(worldPos));
    }
#endif
    outColor = c;
    outData = vec4(normalize(viewNormal) * 0.5 + 0.5, encodeMat(surfaceMat));
    outLight = vec4(lmcoord, 0.0, 1.0);
}
