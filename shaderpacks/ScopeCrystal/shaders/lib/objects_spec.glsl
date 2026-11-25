// Voxel-Objekte der Orte: 0 Hub-Herz, 1 Lobby-Schwerter, 3 Hall-Pokal, 4 Globus, 5 Wuerfel (Nummern wie PL_* in places.glsl, Tempel hat keins).
// Ankunftszeit je Ort steht in colortex4, Zeile 0, x = 2 + Ort (program/portal_state.glsl).
const float OBJ_LAND = 3.2;             // Sekunden bis zur Landung
const float OBJ_FULL = 7.0;

bool objOn(int p) {
#ifdef FX_HUB_HEART
    if (p == 0) return true;
#endif
#ifdef FX_LOBBY_SWORDS
    if (p == 1) return true;
#endif
#ifdef FX_HALL_CUP
    if (p == 3) return true;
#endif
#ifdef FX_WORLD_SPHERE
    if (p == 4) return true;
#endif
#ifdef FX_ARCADE_CUBE
    if (p == 5) return true;
#endif
    return false;
}
float objTime(int p) { vec4 h = texelFetch(colortex4, ivec2(2 + p, 0), 0); return abs(h.w - 2611.0) < 0.1 ? h.x : 0.0; }
// Ruhelage (Mitte) und Bloecke pro Voxel
vec4 objRest(int p) {
    return p == 0 ? vec4(0.5, 117.0, -454.5, 0.80) : p == 1 ? vec4(0.5, 119.5, -399.5, 0.70) : p == 3 ? vec4(0.5, 115.0, -554.5, 1.0)
        : p == 4 ? vec4(CHAL.x, 121.5, CHAL.z, 1.0) : vec4(ARCADE.x, 111.0, ARCADE.z, 1.10);
}
float objGround(int p) { return p == 3 ? 104.0 : 101.0; }

// Gebaute Bloecke ausblenden, solange das Voxel-Objekt des Ortes zu sehen ist
bool objHidden(vec3 w) {
    if (w.z > -380.0 || w.y < 106.5 || w.y > 130.0) return false;
#ifdef FX_HUB_HEART
    if (abs(w.x - 0.5) < 7.0) { if (abs(w.z + 454.5) < 1.6) return w.y > 110.9 && w.y < 123.1 && objTime(0) > 0.02; }
#endif
#ifdef FX_HALL_CUP
    if (w.z < -540.0) return w.y > 106.98 && w.y < 121.5 && length(w.xz - vec2(0.5, -554.5)) < 7.3 && objTime(3) > 0.02;
#endif
#ifdef FX_LOBBY_SWORDS
    if (w.z > -410.0) return w.y > 111.9 && w.y < 127.1 && abs(w.x - 0.5) < 7.6 && abs(w.z + 399.5) < 1.6 && objTime(1) > 0.02;
#endif
#ifdef FX_WORLD_SPHERE
    if (w.x < -60.0) return length(w - vec3(CHAL.x, 121.5, CHAL.z)) < 7.95 && objTime(4) > 0.02;
#endif
#ifdef FX_ARCADE_CUBE
    if (w.x > 60.0) return w.y > 106.98 && w.y < 114.02 && max(abs(w.x - ARCADE.x), abs(w.z - ARCADE.z)) < 3.6 && objTime(5) > 0.02;
#endif
    return false;
}
