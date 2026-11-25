
out vec2 texcoord;
#ifdef PVP_WORLD
uniform mat4 gbufferModelView;
uniform mat4 gbufferProjection;
uniform vec3 cameraPosition;
#include "/lib/common.glsl"
#include "/lib/fx_view.glsl"
flat out float fxAct[6];                                // Aufbau je Ort (lib/places.glsl), 0 aus bis 1 voll
uniform float skyPosX, skyPosZ;                         // geglaettete Position: auch Teleports bauen weich auf
#include "/lib/places.glsl"
uniform float frameTimeCounter;
flat out vec4 heartA, heartB, heartC;                   // Hub-Herz (lib/hub.glsl)
flat out int fxSeen;                                   // ein Bit je Effekt-Bereich im Blickfeld

bool fxInView(int i, mat4 m, vec3 cam) {
    // Kiste ist nur dann sicher unsichtbar, wenn alle Ecken hinter derselben Bildebene liegen
    ivec4 side = ivec4(0); int behind = 0;
    for (int k = 0; k < 8; k++) {
        vec3 corner = mix(FXV_LO[i], FXV_HI[i], vec3(float(k & 1), float(k >> 1 & 1), float(k >> 2 & 1)));
        vec4 c = m * vec4(corner - cam, 1.0);
        side += ivec4(c.x < -c.w, c.x > c.w, c.y < -c.w, c.y > c.w);
        if (c.w <= 0.0) behind++;
    }
    return behind < 8 && side.x < 8 && side.y < 8 && side.z < 8 && side.w < 8;
}

// Gleiche Entfernungen (mit Reserve) wie am Anfang von hub, temple, lobby, hall und arena
bool fxNear(int i, vec3 cam) {
    if (i == FXV_BEAM || i >= FXV_BEAM_HALL && i <= FXV_BEAM_ARCADE) return cam.z < -200.0 && abs(cam.y - 104.0) < 220.0;      // Strahlen sieht man im ganzen Hub-Bereich
    vec3 c = i == FXV_WORLD ? CHAL : i == FXV_ARCADE ? ARCADE : i <= FXV_AURORA || i == FXV_HEART ? vec3(0.0, 100.0, -455.0) : i <= FXV_BEAM ? vec3(0.5, 104.0, -343.5) : i == FXV_LOBBY ? vec3(0.5, 101.0, -399.5)
        : i == FXV_ARENA ? vec3(0.5, 101.0, 0.5) : vec3(0.5, 104.0, -554.5);
    float R = i == FXV_HEART ? 175.0 : i >= FXV_WORLD ? 170.0 : i <= FXV_AURORA ? 175.0 : i <= FXV_BEAM ? 155.0 : i == FXV_LOBBY ? 135.0 : i == FXV_ARENA ? 95.0 : 165.0;
    return length(cam.xz - c.xz) < R && abs(cam.y - c.y) < 130.0;
}
#endif

void main() {
    gl_Position = ftransform();
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
#ifdef PVP_WORLD
    mat4 m = gbufferProjection * gbufferModelView;
    vec3 local = cameraPosition;                        // Arena-Kiste liegt in Insel-Koordinaten
    local.x -= arenaOffsetX(arenaSideAt(cameraPosition));
    // Hub-Herz: Ankunftszeit aus portal_state, daraus Lage, Groesse und Drehung
    vec4 hs = texelFetch(colortex4, ivec2(2, 0), 0);
    float ht = abs(hs.w - 2611.0) < 0.1 ? hs.x : 7.0, hl = 3.2, tm = frameTimeCounter;
    float he = clamp(ht / hl, 0.0, 1.0), hr = 1.0 - he, ha = max(ht - hl, 0.0);
    float hb = (pow(max(0.0, sin(tm * 2.3)), 14.0) + 0.6 * pow(max(0.0, sin(tm * 2.3 - 0.6)), 14.0)) * smoothstep(0.5, 2.0, ha);
    float spring = ha > 0.0 ? -1.1 * exp(-ha * 2.0) * sin(ha * 6.5) : 0.0, spin = tm * 0.5 + 10.0 * hr * hr;
    heartA = vec4(HUB + vec3(0.5, 9.6 + 36.0 * hr * hr * hr + spring + 0.35 * sin(tm * 1.1) * smoothstep(1.0, 3.0, ha), 0.5),
        0.80 * mix(0.15, 1.0, smoothstep(0.0, 0.85, he)) * (1.0 + 0.045 * hb));
    heartB = vec4(he, ha, hb, smoothstep(0.05, 1.0, ht / (hl + 0.4)) * 1.02);
    heartC = vec4(cos(spin), sin(spin), smoothstep(0.0, 0.25, he), ha > 0.0 ? exp(-ha * 2.2) : 0.0);
    // Welcher Ort ist dran? Die Reichweiten schliessen andere Gebaeude aus
    for (int p = 0; p < 6; p++) {
        vec3 k = placeRange(p);
        fxAct[p] = 1.0 - smoothstep(k.y, k.z, length(vec2(skyPosX, skyPosZ) - placeCenter(p).xz));
    }
#ifndef FX_HUB_DYNAMIC
    for (int p = 0; p < 6; p++) fxAct[p] = 1.0;
#endif
    bool on[15] = bool[15](fxAct[PL_HUB] > 0.002, fxAct[PL_HUB] > 0.002, fxAct[PL_TEMPLE] > 0.002, true, fxAct[PL_LOBBY] > 0.002, fxAct[PL_HALL] > 0.002, fxAct[PL_HALL] > 0.002,
        fxAct[PL_HALL] > 0.002, true, fxAct[PL_WORLD] > 0.002, fxAct[PL_ARCADE] > 0.002, true, true, true, fxAct[PL_HUB] > 0.002);
    fxSeen = 0;
    for (int i = 0; i < FXV_COUNT; i++) if (on[i] && fxNear(i, i == FXV_ARENA ? local : cameraPosition) && fxInView(i, m, i == FXV_ARENA ? local : cameraPosition)) fxSeen |= 1 << i;
#endif
}
