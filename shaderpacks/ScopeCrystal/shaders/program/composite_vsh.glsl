
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
flat out vec4 obA[3], obB[3], obC[3];                   // Voxel-Objekte (lib/objects.glsl)
flat out int obT[3];
#include "/lib/objects_spec.glsl"
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
    if (i == FXV_BEAM || i >= FXV_BEAM_HALL) return cam.z < -200.0 && abs(cam.y - 104.0) < 220.0;      // Strahlen sieht man im ganzen Hub-Bereich
    vec3 c = i == FXV_WORLD ? CHAL : i == FXV_ARCADE ? ARCADE : i <= FXV_AURORA ? vec3(0.0, 100.0, -455.0) : i <= FXV_BEAM ? vec3(0.5, 104.0, -343.5) : i == FXV_LOBBY ? vec3(0.5, 101.0, -399.5)
        : i == FXV_ARENA ? vec3(0.5, 101.0, 0.5) : vec3(0.5, 104.0, -554.5);
    float R = i >= FXV_WORLD ? 170.0 : i <= FXV_AURORA ? 175.0 : i <= FXV_BEAM ? 155.0 : i == FXV_LOBBY ? 135.0 : i == FXV_ARENA ? 95.0 : 165.0;
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
    // Voxel-Objekte: Platz 0 Hub-Herz, Platz 1 das naechste Gebaeude, Platz 2 die Lobby-Schwerter
    obT[0] = objOn(0) && objTime(0) > 0.0 ? 0 : -1;
    obT[1] = -1;
    obT[2] = objOn(1) && objTime(1) > 0.0 ? 1 : -1;
    float closest = 1e6;
    for (int p = 3; p < 6; p++) if (objOn(p) && objTime(p) > 0.0 && length(cameraPosition.xz - placeCenter(p).xz) < closest) { closest = length(cameraPosition.xz - placeCenter(p).xz); obT[1] = p; }
    float tm = frameTimeCounter;
    for (int i = 0; i < 3; i++) {
        int p = max(obT[i], 0);
        vec4 rest = objRest(p);
        float ht = objTime(p), he = clamp(ht / OBJ_LAND, 0.0, 1.0), hr = 1.0 - he, ha = max(ht - OBJ_LAND, 0.0);
        float hb = (pow(max(0.0, sin(tm * 2.3)), 14.0) + 0.6 * pow(max(0.0, sin(tm * 2.3 - 0.6)), 14.0)) * smoothstep(0.5, 2.0, ha) * (p == 0 ? 1.0 : 0.35);
        float spring = ha > 0.0 ? -1.1 * exp(-ha * 2.0) * sin(ha * 6.5) : 0.0, spin = tm * (p == 4 ? 0.22 : 0.5) + 10.0 * hr * hr;
        // im Zelt und unter dem Glasdach nicht von so weit oben, sonst steckt das Objekt im Dach
        float high = p == 5 ? 9.0 : p == 3 ? 24.0 : 36.0;
        obA[i] = vec4(rest.xyz + vec3(0.0, high * hr * hr * hr + spring + 0.35 * sin(tm * 1.1) * smoothstep(1.0, 3.0, ha), 0.0),
            rest.w * mix(0.15, 1.0, smoothstep(0.0, 0.85, he)) * (1.0 + 0.045 * hb));
        obB[i] = vec4(he, ha, hb, smoothstep(0.05, 1.0, ht / (OBJ_LAND + 0.4)) * 1.02);
        obC[i] = vec4(cos(spin), sin(spin), smoothstep(0.0, 0.25, he), ha > 0.0 ? exp(-ha * 2.2) : 0.0);
    }
    // Welcher Ort ist dran? Die Reichweiten schliessen andere Gebaeude aus
    for (int p = 0; p < 6; p++) {
        vec3 k = placeRange(p);
        fxAct[p] = 1.0 - smoothstep(k.y, k.z, length(vec2(skyPosX, skyPosZ) - placeCenter(p).xz));
    }
#ifndef FX_HUB_DYNAMIC
    for (int p = 0; p < 6; p++) fxAct[p] = 1.0;
#endif
    bool on[14] = bool[14](fxAct[PL_HUB] > 0.002, fxAct[PL_HUB] > 0.002, fxAct[PL_TEMPLE] > 0.002, true, fxAct[PL_LOBBY] > 0.002, fxAct[PL_HALL] > 0.002, fxAct[PL_HALL] > 0.002,
        fxAct[PL_HALL] > 0.002, true, fxAct[PL_WORLD] > 0.002, fxAct[PL_ARCADE] > 0.002, true, true, true);
    fxSeen = 0;
    for (int i = 0; i < FXV_COUNT; i++) if (on[i] && fxNear(i, i == FXV_ARENA ? local : cameraPosition) && fxInView(i, m, i == FXV_ARENA ? local : cameraPosition)) fxSeen |= 1 << i;
#endif
}
