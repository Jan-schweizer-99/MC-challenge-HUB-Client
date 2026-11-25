// Runde Böden für Hub, Lobby-Insel und Tempel – gleiche Technik wie roundArenaFloor: die Blocktexturen bleiben
// pixelgenau, nur die Grenzen zwischen den Materialien werden zu echten Kreisen. Werte wie Hub.java / Tempel.java.
// Braucht arena_materials.glsl (arenaPaletteAtlas, arenaTextureLevel). Alles spiegelbildlich zu x = 0.5.
const int HF_QUARTZ = 0, HF_CALCITE = 2, HF_AMETHYST = 4, HF_FROG = 6, HF_BLUE = 8, HF_CHISELED = 20, HF_DIAMOND = 22;
const int HF_PACKED = 54, HF_SNOW = 55;                                    // Zusatzspalten am Ende des Atlas (make-textures.ps1)

vec3 hubFloorTex(int col, vec2 uv, int level) {
    int size = 16 >> level, offset = 32 - (32 >> level);
    return texelFetch(arenaPaletteAtlas, ivec2(col * 32 + offset, 0) + ivec2(floor(fract(uv) * float(size))), 0).rgb;
}

// Welcher runde Boden liegt hier? 0 keiner, 1 Hub, 2 Insel, 3 Inselbalkon, 4 Tempel
int hubFloorZone(vec3 wp, vec3 nW) {
    if (nW.y < 0.9 || abs(wp.x - 0.5) > 31.0 || wp.z < -479.0 || wp.z > -312.0) return 0;
    float ax = abs(wp.x - 0.5);
    bool ground = abs(wp.y - 101.0) < 0.05;
#ifdef FX_HUB_ROUND
    vec2 h = wp.xz - vec2(0.5, -454.5);
    if (ground && length(h) < 23.5) return ax < 2.5 && h.y > 16.5 ? 0 : 1;          // Lichtstreifen zur Brücke bleibt gerade
#endif
#ifdef FX_LOBBY_ROUND
    vec2 l = wp.xz - vec2(0.5, -399.5);
    float lr = length(l);
    if (ground && (lr < 2.4 || ax > 2.5 && abs(l.y) > 1.5)) {
        if (lr < 9.4) return 2;
        if (length(vec2(ax - 10.0, l.y)) < 7.5) return 3;
    }
#endif
#ifdef FX_TEMPLE_ROUND
    vec2 q = wp.xz - vec2(0.5, -343.5);
    float r = length(q), ly = wp.y - 104.0, lvl = floor(ly / 13.0 + 0.5);
    if (abs(lvl) <= 2.0 && abs(ly - lvl * 13.0) < 0.05 && r < (lvl == 0.0 ? 29.5 : 22.4)) {
        if (r < 12.0 && lvl > -2.0) return 0;                                       // Treppen im Schacht
        if (ax < 2.5 && q.y < -12.0 && lvl == 0.0) return 0;                        // Lichtweg vom Tor
        if (abs(ax - 11.0) < 1.5 && abs(q.y + 11.0) < 1.5) return 0;                // Aufzüge
        return 4;
    }
#endif
    return 0;
}

// Weicher Ring von a bis b (fw = Pixelbreite)
float hubBand(float r, float a, float b, float fw) { return smoothstep(a - fw, a + fw, r) * (1.0 - smoothstep(b - fw, b + fw, r)); }

vec3 hubRoundFloor(int zone, vec3 wp, vec3 tint, vec3 light, float t, out int surfaceMat) {
    vec2 c = zone == 1 ? vec2(0.5, -454.5) : zone == 4 ? vec2(0.5, -343.5) : vec2(0.5, -399.5);
    vec2 q = wp.xz - c;
    if (zone == 3) q = vec2(abs(q.x) - 10.0, q.y);
    float r = length(q), fw = max(fwidth(r), 1e-3);
    vec2 uv = wp.xz;
    int level = arenaTextureLevel(uv);
    float deg = degrees(atan(abs(q.x), -q.y));
    if (zone == 3) deg = degrees(atan(abs(q.y), q.x));
    int a = HF_QUARTZ, b = HF_CALCITE;                                              // Grundmuster aus zwei Steinen
    float seg = 11.25;
    vec3 col = vec3(0.0);
    float used = 0.0;
    surfaceMat = 3;
#define HUB_LAYER(BAND, TEX, LIT) { float w = BAND * (1.0 - used); if (w > 0.0) { col += hubFloorTex(TEX, uv, level) * (LIT) * w; used += w; } }
    vec3 lit = max(light, vec3(0.55));                                              // leuchtende Ringe
    if (zone == 1) {
        HUB_LAYER(hubBand(r, -1.0, 1.6, fw), HF_FROG, lit)
        HUB_LAYER(hubBand(r, 5.5, 6.2, fw), HF_BLUE, lit)
        HUB_LAYER(hubBand(r, 12.4, 15.6, fw), HF_BLUE, light)
        HUB_LAYER(hubBand(r, 18.6, 19.2, fw), HF_BLUE, lit)
        HUB_LAYER(hubBand(r, 22.3, 24.0, fw), HF_CHISELED, light)
        if (r > 5.8) { a = HF_PACKED; b = HF_SNOW; seg = 18.0; surfaceMat = r < 22.3 ? 2 : 3; }   // 20 Felder, passend zu den 10 Sockeln
    } else if (zone == 2) {
        HUB_LAYER(hubBand(r, -1.0, 1.2, fw), HF_DIAMOND, light)
        HUB_LAYER(hubBand(r, 1.2, 2.4, fw), HF_FROG, lit)
        HUB_LAYER(hubBand(r, 3.5, 4.5, fw), HF_AMETHYST, light)
        HUB_LAYER(hubBand(r, 6.5, 7.5, fw), HF_BLUE, light)
        HUB_LAYER(hubBand(r, 8.7, 9.6, fw), HF_CHISELED, light)
    } else if (zone == 3) {
        HUB_LAYER(hubBand(r, 3.5, 4.5, fw), HF_AMETHYST, light)
        HUB_LAYER(hubBand(r, 5.5, 6.5, fw), HF_BLUE, light)
        seg = 22.5;
    } else {
        HUB_LAYER(hubBand(r, -1.0, 2.5, fw), HF_FROG, lit)
        HUB_LAYER(hubBand(r, 3.5, 4.5, fw) + hubBand(r, 7.5, 8.5, fw), HF_BLUE, light)
        HUB_LAYER(hubBand(r, 12.5, 13.5, fw) + hubBand(r, 18.5, 19.5, fw), HF_BLUE, light)
        HUB_LAYER(hubBand(r, 15.5, 16.5, fw), HF_PACKED, lit)
        HUB_LAYER(hubBand(r, 24.6, 25.1, fw) + hubBand(r, 27.0, 27.5, fw), HF_AMETHYST, light)
        HUB_LAYER(hubBand(r, 28.5, 30.0, fw), HF_CHISELED, light)
    }
#undef HUB_LAYER
    if (used < 1.0) {
        // Strahlen zwischen den Feldern ebenfalls kantengeglättet
        float u = deg / seg + (zone == 1 ? 0.5 : 0.0);               // Hub: Sockel stehen mitten auf ihrem Feld
        float w = abs(fract(u) - 0.5), aa = max(fw / max(r, 0.5) * 57.3 / seg, 1e-3);
        float odd = mod(floor(u), 2.0);
        float edge = 0.5 * (1.0 - smoothstep(0.0, aa, 0.5 - w));                     // an der Grenze halb/halb
        float mixB = mix(odd, 1.0 - odd, edge);
        col += mix(hubFloorTex(a, uv, level), hubFloorTex(b, uv, level), mixB) * light * (1.0 - used);
    }
    return col * tint;
}
