// Kristall-Himmelsarena (Welt "pvp", Mitte x 0.5 / z 0.5, Boden-Oberfläche y 101)
// Alle Effekte in Weltkoordinaten, verdeckt durch Blöcke (sceneDist).
// Bahnpunkte kommen vorberechnet aus colortex4 (lib/arena_paths.glsl, begin-Pass).
// Leistung: Schweife sind durchgehende Lichtlinien mit nahtlos laufendem Muster statt Punktketten,
// Partikel auf den Bögen sind wandernde Pulse in der Röhre – möglichst wenige Einzel-Leuchtpunkte.
#include "/lib/arena_paths.glsl"

const vec3 ARENA = vec3(0.5, 101.0, 0.5);
const float ARENA_R = 26.0;

vec4 arenaCache(int x, int y) { return texelFetch(colortex4, ivec2(x, y), 0); }

// Trifft der Blickstrahl (vor der Szene) die Kugel c/R? Sonst kann nichts darin leuchten.
bool rayNear(vec3 c, float R, vec3 camW, vec3 dir, float sceneDist) {
    vec3 oc = c - camW;
    float tc = dot(oc, dir);
    return tc > -R && tc - R < sceneDist && dot(oc, oc) - tc * tc < R * R;
}

// Blickstrahl ↔ Strecke a-b: x = Abstand, y = Position auf der Strecke (0..1), z = Entfernung entlang des Strahls
vec3 raySegment(vec3 a, vec3 b, vec3 camW, vec3 dir) {
    vec3 ba = b - a, w0 = camW - a;
    float B = dot(dir, ba), C = dot(ba, ba), D = dot(dir, w0), E = dot(ba, w0);
    float h = clamp((E - B * D) / max(C - B * B, 1e-5), 0.0, 1.0);
    vec3 q = a + ba * h;
    float s = max(dot(q - camW, dir), 0.0);
    return vec3(length(camW + dir * s - q), h, s);
}

// Schweif als durchgehende Lichtlinie durch die Stützpunkte im Cache: nach hinten dünner und dunkler,
// darin läuft ein Lichtmuster nahtlos (sin) den Schweif entlang – ersetzt die frühere Punktkette.
vec3 trailStreak(int row, int n, vec3 c, float r0, float r1, float w, float flow,
                 vec3 camW, vec3 dir, float sceneDist, float t) {
    float best = 0.0;
    vec3 a = arenaCache(0, row).xyz;
    for (int j = 1; j < n; j++) {
        vec3 b = arenaCache(j, row).xyz;
        vec3 seg = raySegment(a, b, camW, dir);
        if (seg.z > 0.0 && seg.z < sceneDist) {
            float k = (float(j - 1) + seg.y) / float(n - 1);       // 0 = Kopf, 1 = Schweifende
            float r = mix(r0, r1, k);
            float roll = 0.7 + 0.3 * sin(k * 19.0 - t * flow);    // rollendes Muster, läuft nach hinten
            best = max(best, exp(-seg.x * seg.x / (r * r)) * (1.0 - k) * roll);
        }
        a = b;
    }
    return c * best * w;
}

vec3 crystalAura(vec3 camW, vec3 dir, float sceneDist, float t) {
    vec3 col = vec3(0.0);
    vec3 center = vec3(0.5, 109.5, 0.5);
    // Batching: eine Kugel r 13.5 umschließt Aura (r 5.5 → unter 1/1000 ab ~13) und alle Bahnen (≤ ~11)
    if (!rayNear(center, 13.5, camW, dir, sceneDist)) return col;
#ifdef FX_ARENA_AURA
    float breathe = 0.75 + 0.25 * sin(t * 1.7);
    col += vec3(0.6, 0.35, 1.0) * pointGlow(center, camW, dir, sceneDist, 5.5) * 0.35 * breathe;
    col += vec3(0.4, 0.8, 1.0) * pointGlow(center, camW, dir, sceneDist, 2.2) * 0.25 * breathe;
#endif
#ifdef FX_ARENA_ORBS
    for (int i = 0; i < ORB_COUNT; i++) {
        int row = CACHE_ORB_ROW + i;
        vec4 bound = arenaCache(ORB_SAMPLES, row);
        if (!rayNear(bound.xyz, bound.w, camW, dir, sceneDist)) continue;
        vec3 c = orbColor(i % 6);
        vec3 head = arenaCache(0, row).xyz;
        col += c * pointGlow(head, camW, dir, sceneDist, 0.22) * 3.0;
        col += c * pointGlow(head, camW, dir, sceneDist, 0.9) * 0.3;
        col += trailStreak(row, ORB_SAMPLES, c, 0.2, 0.03, 0.85, 7.0, camW, dir, sceneDist, t);
    }
#endif
    return col;
}

// ---------------------------------------------------------------- Jumppad-Flugbahnen: Lichtröhre mit wandernden Lichtpulsen
vec3 padArc(int k, vec3 camW, vec3 dir, float sceneDist, float t) {
    int row = CACHE_ARC_ROW + k;
    vec4 bound = arenaCache(CACHE_ARC_BOUND, row);
    if (!rayNear(bound.xyz, bound.w, camW, dir, sceneDist)) return vec3(0.0);
    vec3 c = arcColor(k);
    // Lichtröhre entlang der Bahn: Abstand Blickstrahl ↔ Kurvenstück; hell am Rand (zwei Linien von der Seite)
    const float RAD = 0.22;
    vec3 a = arenaCache(0, row).xyz;
    float best = 1e9, bestK = 0.0;
    for (int j = 1; j <= ARC_SEG; j++) {
        vec3 b = arenaCache(j, row).xyz;
        vec3 seg = raySegment(a, b, camW, dir);
        if (seg.z < sceneDist && seg.x < best) { best = seg.x; bestK = (float(j - 1) + seg.y) / float(ARC_SEG); }
        a = b;
    }
    if (best >= 1.5) return vec3(0.0);
    // Opazität über den Weg: am Pad voll, Richtung Ziel stetig durchsichtig – keine harte Kante am Ende
    float ends = smoothstep(0.0, 0.06, bestK) * pow(1.0 - bestK, 1.6);
    float rim = exp(-pow((best - RAD) / 0.04, 2.0));
    float inner = exp(-best * best / (RAD * RAD)) * 0.025;
    float flow = 0.75 + 0.25 * sin(bestK * 30.0 - t * 6.0);           // Lichtfluss entlang der Röhre
    vec3 col = c * (rim * 0.45 * flow + inner) * ends;
    // Lichtpulse statt Partikeln: ARC_PARTICLES helle Kerne wandern nahtlos (fract) durch die Röhre,
    // gleicher Takt wie die früheren Partikel (t * 0.45, Versatz je Bogentyp), mit kurzem Nachleuchten
    float seed = float(k % 3) * 0.3;
    float ph = fract((bestK - t * 0.45 - seed) * float(ARC_PARTICLES));
    float dk = (ph < 0.5 ? ph : ph - 1.0) / float(ARC_PARTICLES);   // >0 vor dem Puls, <0 dahinter
    float pulse = exp(-dk * dk / (0.011 * 0.011)) + (dk < 0.0 ? exp(dk / 0.025) * 0.35 : 0.0);
    float core = exp(-best * best / (0.12 * 0.12));
    float fade = smoothstep(0.0, 0.08, bestK) * pow(1.0 - bestK, 1.6);
    col += c * pulse * core * fade * 0.9;
    return col;
}

vec3 padArcs(vec3 camW, vec3 dir, float sceneDist, float t) {
    vec3 col = vec3(0.0);
    for (int g = 0; g < 4; g++) {                                      // Batching: 3 Bögen pro Gruppentest
        vec4 gb = arenaCache(g, CACHE_GROUP_ROW);
        if (!rayNear(gb.xyz, gb.w, camW, dir, sceneDist)) continue;
        for (int k = g * 3; k < g * 3 + 3; k += 2) col += padArc(k, camW, dir, sceneDist, t);   // Typ 1 (Hochpads) gibt es nicht mehr
    }
    return col;
}

// ---------------------------------------------------------------- Kristall-Schacht: Leuchtringe an Ein-/Ausgang, aufsteigende Funken
// Ring aus 12 Lichtern als rotierendes Muster: Strahl trifft die Ringebene → nur die zwei nächsten
// Lichter auswerten. Nur bei sehr flachem Blick (Ring fast von der Seite) alle 12 einzeln.
vec3 shaftRing(float y, float rot, vec3 camW, vec3 dir, float sceneDist) {
    const int N = 12;
    const float R = 1.7;
    float g = 0.0;
    if (abs(dir.y) > 0.2) {
        float tp = (y - camW.y) / dir.y;
        vec2 q = camW.xz + dir.xz * tp - vec2(0.5);
        float idx = floor((atan(q.y, q.x) - rot) / 6.2832 * float(N) + 0.5);
        for (int o = -1; o <= 1; o++) {
            float a = (idx + float(o)) / float(N) * 6.2832 + rot;
            g += pointGlow(vec3(0.5 + cos(a) * R, y, 0.5 + sin(a) * R), camW, dir, sceneDist, 0.13);
        }
    } else {
        for (int i = 0; i < N; i++) {
            float a = float(i) / float(N) * 6.2832 + rot;
            g += pointGlow(vec3(0.5 + cos(a) * R, y, 0.5 + sin(a) * R), camW, dir, sceneDist, 0.13);
        }
    }
    return vec3(g);
}

vec3 shaftFx(vec3 camW, vec3 dir, float sceneDist, float t) {
    if (!rayNear(vec3(0.5, 110.5, 0.5), 10.0, camW, dir, sceneDist)) return vec3(0.0);
    vec3 col = vec3(0.0);
    vec3 ice = vec3(0.45, 0.85, 1.0), white = vec3(1.0);
    for (int ring = 0; ring < 2; ring++) {
        float y = ring == 0 ? 104.05 : 117.5;
        if (!rayNear(vec3(0.5, y, 0.5), 2.2, camW, dir, sceneDist)) continue;   // Ring r 1.7 + Leuchten
        float pulse = 0.7 + 0.3 * sin(t * 3.0 + float(ring) * 1.6);
        col += mix(ice, white, 0.4) * shaftRing(y, t * (ring == 0 ? 0.6 : -0.6), camW, dir, sceneDist) * 1.2 * pulse;
    }
    if (rayNear(vec3(0.5, 111.5, 0.5), 8.0, camW, dir, sceneDist)) {
        for (int i = 0; i < 6; i++) {                     // Funken strömen durch den Schacht nach oben
            float s = fract(t * 0.7 + float(i) / 6.0);
            float a = float(i) * 2.4 + t;
            vec3 p = vec3(0.5 + cos(a) * 0.6, 104.0 + s * 15.0, 0.5 + sin(a) * 0.6);
            col += white * pointGlow(p, camW, dir, sceneDist, 0.1) * 1.6 * sin(s * 3.1416);
        }
    }
    return col;
}

// ---------------------------------------------------------------- Decken-Portal: nur von unten sichtbar, zeigt die Farben des Ziels
vec3 ceilingPortal(vec3 camW, vec3 dir, float sceneDist, float t, bool lavaSide) {
    const float PY = 106.0, PR = 2.9;
    if (dir.y <= 0.001 || camW.y >= PY) return vec3(0.0);    // nur Blick nach oben, von unterhalb
    float tp = (PY - camW.y) / dir.y;
    if (tp > sceneDist) return vec3(0.0);
    vec2 q = (camW + dir * tp).xz - vec2(0.5);
    float d = length(q);
    if (d > PR + 0.6) return vec3(0.0);
    float ang = atan(q.y, q.x);
    float swirl = 0.5 + 0.5 * sin(ang * 5.0 + d * 4.5 - t * 3.2);
    float swirl2 = 0.5 + 0.5 * sin(ang * 3.0 - d * 6.0 + t * 2.1);
    float paletteBlend = smoothstep(0.02, 0.98, arenaLavaMix);
    vec3 a = mix(vec3(1.0, 0.35, 0.05), vec3(0.45, 0.85, 1.0), paletteBlend);
    vec3 b = mix(vec3(1.0, 0.85, 0.2), vec3(1.0, 0.45, 0.95), paletteBlend);
    float inside = 1.0 - smoothstep(PR - 0.15, PR, d);
    float rim = exp(-pow((d - PR) / 0.08, 2.0));
    vec3 col = mix(a, b, swirl * swirl2) * inside * (0.55 + 0.6 * (1.0 - d / PR));
    col += vec3(1.0) * rim * 1.6;
    return col;
}

// Lauflicht-Farbe (rotiert um das Stadion)
vec3 chase(float ang, float t, float k) {
    return 0.55 + 0.45 * cos(6.2832 * (ang / 6.2832 * k - t * 0.25 + vec3(0.0, 0.33, 0.67)));
}

// Kantengeglättete Kreislinie mit Radius R und halber Breite w (fw = Pixelbreite in Blöcken)
float circ(float r, float R, float w, float fw) {
    return 1.0 - clamp((abs(r - R) - w) / fw, 0.0, 1.0);
}

// Perfekt runde Bodenkreise über den eckigen Block-Ringen – wie ein Ziffernblatt
vec3 floorCircles(vec2 p, float r, float t) {
    float fw = max(fwidth(r), 1e-3) * 1.2;
    float a = atan(p.y, p.x);
    float turn = a / 6.2832 + 0.5;                       // 0..1 um den Kreis
    vec3 ice = vec3(0.45, 0.8, 1.0), white = vec3(1.0), violet = vec3(0.75, 0.5, 1.0);
    vec3 col = vec3(0.0);
    // Ringe auf den Amethyst-Ringen (Blöcke bei r 6, 12, 18, 24 → Mitte .5)
    col += ice    * circ(r, 6.5,  0.05, fw) * 1.3;
    col += white  * circ(r, 12.5, 0.06, fw) * 1.2;
    col += violet * circ(r, 18.5, 0.06, fw) * 1.3;
    col += ice    * circ(r, 24.5, 0.07, fw) * 1.3;
    // Eisring sauber eingefasst
    col += white * (circ(r, 19.0, 0.03, fw) + circ(r, 20.5, 0.03, fw)) * 0.9;
    // Skala: Teilstriche außen am 12er-Ring (48 klein, 8 groß)
    float tick = step(fract(turn * 48.0 + 0.04), 0.08) * step(12.6, r) * step(r, 13.2);
    float major = step(fract(turn * 8.0 + 0.01), 0.02) * step(12.6, r) * step(r, 13.8);
    col += white * max(tick, major) * 1.1;
    // gestrichelter Ring, der sich langsam dreht
    float dash = step(0.5, fract(turn * 36.0 + t * 0.06));
    col += ice * circ(r, 9.5, 0.05, fw) * dash * 1.4;
    // zweiter, gegenläufiger Strichring außen
    float dash2 = step(0.65, fract(turn * 72.0 - t * 0.04));
    col += violet * circ(r, 22.0, 0.04, fw) * dash2 * 1.2;
    return col;
}

// Effekte auf den Oberflächen der Arena
vec3 arenaSurface(vec3 wp, vec3 nW, float t, float edge) {
    vec2 p = wp.xz - ARENA.xz;
    float r = length(p);
    if (r > ARENA_R + 3.0 || wp.y < 99.0 || wp.y > 118.0) return vec3(0.0);
    vec3 col = vec3(0.0);
    bool floorUp = nW.y > 0.9 && wp.y < 103.5;
    if (floorUp && r < ARENA_R) {
#ifdef FX_ARENA_CIRCLES
        if (wp.y < 101.2) col += floorCircles(p, r, t);   // nur auf der Bodenebene, nicht auf Podest/Mauern
#endif
#ifdef FX_ARENA_WAVES
        // Energiewellen von der Mitte
        for (int i = 0; i < 2; i++) {
            float wr = mod(t * 7.0 + float(i) * 20.0, 40.0);
            float wv = exp(-pow(r - wr, 2.0) * 0.9) * smoothstep(40.0, 10.0, wr);
            col += mix(vec3(0.3, 0.8, 1.0), vec3(1.0, 0.35, 0.9), float(i)) * wv * 0.55;
        }
#endif
#ifdef FX_ARENA_SPOKES
        // Licht-Impulse auf den Speichen
        float ang = atan(p.y, p.x);
        float spoke = abs(sin(4.0 * ang)) * r;
        if (spoke < 0.7 && r > 5.0) {
            float pulse = pow(fract(r / 7.0 - t * 0.9), 6.0);
            col += vec3(0.5, 0.9, 1.0) * pulse * (1.0 - spoke / 0.7) * 1.4;
        }
#endif
#ifdef FX_ARENA_SPARKLE
        // Funkeln auf dem Eisring
        if (r > 19.0 && r < 20.5) {
            float s = hash12(floor(wp.xz * 5.0) + floor(t * 6.0));
            col += vec3(0.85, 0.95, 1.0) * step(0.965, s) * 1.6;
        }
#endif
#ifdef FX_ARENA_SPAWNS
        // Ringe um die Diamant-Spawnpunkte
        for (int i = 0; i < 8; i++) {
            float a = radians(22.5 + float(i) * 45.0);
            vec2 c = vec2(floor(cos(a) * 22.5 + 0.5) + 0.5, floor(sin(a) * 22.5 + 0.5) + 0.5);
            float d = length(wp.xz - c);
            float ring = exp(-pow(d - 0.9 - 0.25 * sin(t * 3.0 + float(i)), 2.0) * 60.0);
            col += vec3(0.6, 0.95, 1.0) * ring * 0.9;
        }
#endif
    }
    // Tribüne + Mauerkrone: echte Blockkanten leuchten im Lauflicht (Outline aus dem Bild),
    // dazu Lauf-Punkte an den Stufenfronten. Weicher Übergang statt harter Radiusgrenze.
    // Mauer: Kanten laufen bis zum Arenaboden hinunter und verblassen dabei nach unten (y 101 → 107)
    float down = pow(smoothstep(100.8, 107.0, wp.y), 1.6);
    float trib = smoothstep(25.0, 26.0, r) * (1.0 - smoothstep(34.5, 35.5, r)) * max(down, smoothstep(105.5, 106.5, wp.y));
    if (trib > 0.0) {
        float ang = atan(p.y, p.x);
#ifdef FX_ARENA_EDGES
        // Eisblau mit umlaufenden weißen Lichtblitzen
        float flash = pow(max(0.0, cos(ang * 3.0 - t * 1.6)), 28.0) + pow(max(0.0, cos(ang * 5.0 + t * 2.3)), 40.0) * 0.6;
        vec3 ice = vec3(0.42, 0.78, 1.0) * (0.85 + 0.15 * sin(t * 1.3 + ang * 2.0));
        col += (ice + vec3(1.0) * flash * 1.8) * edge * 1.3 * trib;
#endif
#ifdef FX_ARENA_DOTS
        if (abs(nW.y) < 0.5 && r > ARENA_R + 1.0) {
            float dots = step(0.72, fract(ang * 24.0 / 6.2832 - t * 2.5));
            float band = exp(-pow(fract(wp.y) - 0.5, 2.0) * 40.0);
            col += chase(ang + 1.5, t, 2.0) * dots * band * 1.1 * trib;
        }
#endif
    }
    return col;
}

// ---------------------------------------------------------------- Wand-Partikel: animierte Runen-Sprites aus eigener Textur
uniform sampler2D runeAtlas;

vec3 wallSprites(vec3 wp, vec3 nW, float t) {
    vec2 p = wp.xz - ARENA.xz;
    float ang = atan(p.y, p.x);
    vec2 w = vec2(ang * 27.0, wp.y);                     // abgewickelte Wand: u = Bogenlänge, v = Höhe
    const vec2 CELL = vec2(3.2, 3.0);
    vec2 cell = floor(w / CELL);
    vec3 col = vec3(0.0);
    for (int dx = -1; dx <= 1; dx++) for (int dy = -1; dy <= 0; dy++) {
        vec2 c = cell + vec2(float(dx), float(dy));
        float h = hash12(c * 1.37 + 11.0);
        if (h < 0.25) continue;                          // nicht in jeder Zelle ein Partikel
        float period = 3.5 + h * 4.0;
        float life = fract(t / period + h * 7.0);        // 0 → 1 Lebenszeit
        vec2 center = (c + 0.5 + (vec2(hash12(c + 3.1), hash12(c + 7.7)) - 0.5) * 0.7) * CELL;
        center.y += life * 1.8;                          // steigt langsam auf
        float size = mix(0.9, 2.3, hash12(c + 5.3));
        vec2 q = (w - center) / size + 0.5;
        if (q.x < 0.0 || q.x > 1.0 || q.y < 0.0 || q.y > 1.0) continue;
        float frame = min(floor(life * 16.0), 15.0);    // Sprite-Animation (4x4 Bilder)
        vec2 uv = (vec2(mod(frame, 4.0), floor(frame / 4.0)) + vec2(q.x, 1.0 - q.y)) / 4.0;
        vec4 s = texture(runeAtlas, uv);
        vec3 tint = chase(ang + h * 6.0, t * 0.3, 1.0);
        col += tint * s.rgb * s.a * 1.8;
    }
    return col;
}

// Polarlicht am Himmel über der Arena
vec3 aurora(vec3 dir, float t) {
    if (dir.y <= 0.02) return vec3(0.0);
    vec2 uv = dir.xz / (dir.y + 0.15);
    float band = 0.0;
    for (int i = 0; i < 3; i++) {
        float fi = float(i);
        float wave = sin(uv.x * (1.3 + fi * 0.4) + t * (0.15 + fi * 0.05) + sin(uv.y * 0.9 + t * 0.1 + fi) * 1.5);
        band += exp(-pow(uv.y * 0.7 - wave * 0.8 - fi * 0.9 + 0.6, 2.0) * 3.0) * (0.6 - fi * 0.15);
    }
    float h = smoothstep(0.05, 0.35, dir.y) * smoothstep(1.0, 0.6, dir.y);
    vec3 c = mix(vec3(0.2, 1.0, 0.7), vec3(0.7, 0.3, 1.0), 0.5 + 0.5 * sin(uv.x * 0.5 + t * 0.2));
    return c * band * h * 0.55;
}

// ---------------------------------------------------------------- Kometen-Blöcke: fliegende Würfel mit leuchtenden Kanten
mat3 cometRot(int i, float t) {
    float fi = float(i);
    return rotX(t * (0.9 + 0.2 * fi) + fi) * rotY(t * (1.3 - 0.1 * fi) + fi * 2.0);
}

vec3 cometBlocks(vec3 camW, vec3 dir, float sceneDist, float t) {
    vec3 col = vec3(0.0);
    vec4 gb = arenaCache(4, CACHE_GROUP_ROW);                          // Batching: alle Kometen in einem Test
    if (!rayNear(gb.xyz, gb.w, camW, dir, sceneDist)) return col;
    for (int i = 0; i < COMET_COUNT; i++) {
        int row = CACHE_COMET_ROW + i;
        vec3 c = orbColor(i);
        vec3 P = arenaCache(0, row).xyz;
        float s = cometHalfSize(i);                            // halbe Kantenlänge
        if (rayNear(P, s * 1.74, camW, dir, sceneDist)) {      // Würfel nur testen, wenn der Strahl nah vorbeigeht
            mat3 Ri = transpose(cometRot(i, t));
            vec3 ro = Ri * (camW - P), rd = Ri * dir;          // Strahl im Würfel-Raum
            vec3 inv = 1.0 / rd;
            vec3 t0 = (-vec3(s) - ro) * inv, t1 = (vec3(s) - ro) * inv;
            vec3 tmin = min(t0, t1), tmax = max(t0, t1);
            float tn = max(max(tmin.x, tmin.y), tmin.z), tf = min(min(tmax.x, tmax.y), tmax.z);
            if (tf > max(tn, 0.0) && tn < sceneDist) {
                // Vorder- und Rückseite: beide Kantenlinien sichtbar (gläserner Würfel)
                for (int side = 0; side < 2; side++) {
                    float th = side == 0 ? max(tn, 0.0) : tf;
                    if (th > sceneDist) continue;
                    vec3 e = vec3(s) - abs(ro + rd * th);
                    float mn = min(e.x, min(e.y, e.z)), mx = max(e.x, max(e.y, e.z));
                    float mid = e.x + e.y + e.z - mn - mx;       // Abstand zur nächsten Kante
                    float edge = exp(-mid * mid * 140.0 / (s * s));
                    col += c * edge * (side == 0 ? 2.6 : 1.1);
                }
                col += c * 0.06 + vec3(0.02, 0.0, 0.05);       // dunkler Kristallkörper
            }
        }
        // Halo r = 2.4 s, Gewicht 0.22 → unter 1/1000 ab ~5.6 s
        if (rayNear(P, s * 5.7, camW, dir, sceneDist)) col += c * pointGlow(P, camW, dir, sceneDist, s * 2.4) * 0.22;
        vec4 bound = arenaCache(COMET_SAMPLES, row);
        if (!rayNear(bound.xyz, bound.w, camW, dir, sceneDist)) continue;
        // Kometenschweif als Lichtlinie mit rollendem Muster
        col += trailStreak(row, COMET_SAMPLES, c, 0.75 * s, 0.075 * s, 0.75, 5.0, camW, dir, sceneDist, t);
    }
    return col;
}

// ---------------------------------------------------------------- Marmorsäulen: Ornament, das von unten aufsteigt
vec3 pillarOrnament(vec3 wp, vec3 nW, float t) {
    if (abs(nW.y) > 0.5) return vec3(0.0);                // nur Seitenflächen
    float u = abs(nW.x) > 0.5 ? fract(wp.z) : fract(wp.x); // Position quer über die Säulenfläche
    if (abs(nW.x) > 0.5 ? nW.x < 0.0 : nW.z > 0.0) u = 1.0 - u;
    // Fuß der Säule: Arena-Boden (y 101) oder Tribüne – grob die nächste Blockebene darunter
    float v = wp.y - 101.0;
    if (v < 0.0 || v > 12.0) return vec3(0.0);
    vec3 ice = vec3(0.45, 0.8, 1.0), white = vec3(1.0);
    float fw = max(fwidth(v), 1e-3);
    vec3 col = vec3(0.0);
    // Sockelband: zwei Ringlinien + Zickzack dazwischen
    float ringA = 1.0 - clamp(abs(v - 0.12) / (fw * 1.5), 0.0, 1.0);
    float ringB = 1.0 - clamp(abs(v - 1.15) / (fw * 1.5), 0.0, 1.0);
    float zig = abs(fract(u * 2.0) - 0.5) * 1.6 + 0.25;  // Zickzack zwischen 0.25 und 1.05
    float zz = (1.0 - clamp(abs(v - zig) / (fw * 1.8), 0.0, 1.0)) * step(v, 1.15) * step(0.12, v);
    col += ice * (ringA + ringB) * 1.4 + white * zz * 1.1;
    // Kanneluren: senkrechte Rillen ab dem Sockel, mit aufsteigenden Energie-Impulsen
    if (v > 1.15) {
        float fwu = max(fwidth(u), 1e-3);
        float fl = 0.0;
        for (int i = 0; i < 3; i++) {
            float x = 0.22 + float(i) * 0.28;
            float line = 1.0 - clamp(abs(u - x) / (fwu * 1.3), 0.0, 1.0);
            float pulse = pow(fract(v * 0.22 - t * 0.55 + float(i) * 0.33), 10.0);
            fl += line * (0.25 + 1.6 * pulse);
        }
        col += mix(ice, white, 0.3) * fl * exp(-(v - 1.15) * 0.28);
    }
    // weiches Licht vom Fuß, nach oben ausklingend
    col += ice * exp(-v * 1.1) * 0.35 * (0.8 + 0.2 * sin(t * 1.5 + wp.x + wp.z));
    return col;
}

// ---------------------------------------------------------------- End-Arena: Kristallstrahlen und Ender-Himmel
// Vier Strahlen von den Turmkristallen (Arena.TOWER / TOWER_TOP) zur Mitte, mit nahtlos laufendem Muster
vec3 endBeams(vec3 camW, vec3 dir, float sceneDist, float t) {
    const vec3 TARGET = vec3(0.5, 116.5, 0.5);
    if (!rayNear(vec3(0.5, 119.0, 0.5), 45.0, camW, dir, sceneDist)) return vec3(0.0);
    vec3 col = vec3(0.0);
    for (int i = 0; i < 4; i++) {
        vec3 a = vec3(0.5 + ((i & 1) == 0 ? -29.0 : 29.0), 124.0, 0.5 + ((i & 2) == 0 ? -29.0 : 29.0));
        vec3 seg = raySegment(a, TARGET, camW, dir);
        if (seg.z > 0.0 && seg.z < sceneDist && seg.x < 1.6) {
            float roll = 0.6 + 0.4 * sin(seg.y * 60.0 - t * 9.0);
            float pulse = exp(-pow(fract(seg.y * 2.0 - t * 0.7 + float(i) * 0.25) - 0.5, 2.0) * 90.0);
            col += vec3(0.85, 0.45, 1.0) * exp(-seg.x * seg.x / 0.05) * (0.5 * roll + 1.3 * pulse);
            col += vec3(0.6, 0.3, 1.0) * exp(-seg.x * seg.x / 0.5) * 0.12;
        }
        col += vec3(1.0, 0.7, 1.0) * pointGlow(a, camW, dir, sceneDist, 1.6) * 0.5 * (0.8 + 0.2 * sin(t * 2.6 + float(i)));
    }
    col += vec3(1.0, 0.8, 1.0) * pointGlow(TARGET, camW, dir, sceneDist, 1.3) * 0.9;
    return col;
}

// Ender-Himmel im Pixelraster: ziehende Nebelschleier und blinkende Sterne
vec3 endSky(vec3 dir, float t) {
    vec3 ad = abs(dir);
    float m = max(ad.x, max(ad.y, ad.z));
    vec2 uv = m == ad.y ? dir.xz / ad.y : m == ad.x ? dir.zy / ad.x : dir.xy / ad.z;   // Würfelflächen, ohne Pol-Verzerrung
    float face = m == ad.y ? sign(dir.y) : m == ad.x ? 2.0 + sign(dir.x) : 5.0 + sign(dir.z);
    vec3 d = floor(dir * 48.0) / 48.0;
    float n = sin(d.x * 5.0 + t * 0.06 + 2.0 * sin(d.z * 3.0 - t * 0.04)) * sin(d.z * 4.0 - t * 0.05 + 1.7 * sin(d.y * 5.0))
            + 0.5 * sin(d.x * 11.0 - d.y * 9.0 + t * 0.09);
    vec3 col = mix(vec3(0.25, 0.1, 0.7), vec3(0.9, 0.2, 0.7), clamp(n, 0.0, 1.0)) * smoothstep(0.05, 1.2, n) * 0.3;
    vec2 cell = floor(uv * 70.0);
    float h = hash12(cell + face * 37.0);
    if (h > 0.985) col += vec3(0.9, 0.8, 1.0) * (0.35 + 0.65 * abs(sin(t * (0.5 + h * 1.5) + h * 400.0)));
    return col;
}

vec3 arena(vec3 camW, vec3 dir, float sceneDist, bool hasSurface, bool isSky, vec3 wp, vec3 nW, float edge, int mat) {
    // Lava- und End-Insel: dieselben Effekte, einfach um die Insel verschoben
    int side = arenaSideAt(camW);
    camW.x -= arenaOffsetX(side); wp.x -= arenaOffsetX(side);
    vec3 rel = camW - ARENA;
    if (length(rel.xz) > 90.0 || abs(rel.y) > 70.0) return vec3(0.0);
    float t = frameTimeCounter;
    vec3 col = vec3(0.0);
#if defined(FX_ARENA_AURA) || defined(FX_ARENA_ORBS)
    col += crystalAura(camW, dir, sceneDist, t);
#endif
#ifdef FX_ARENA_COMETS
    col += cometBlocks(camW, dir, sceneDist, t);
#endif
#ifdef FX_ARENA_ARCS
    col += padArcs(camW, dir, sceneDist, t);
#endif
#ifdef FX_ARENA_SHAFT
    col += shaftFx(camW, dir, sceneDist, t);
#endif
    if (hasSurface) {
        col += arenaSurface(wp, nW, t, mat == 2 ? 0.0 : edge);   // Glas bleibt Vanilla
        // Säulen-Ornament sitzt jetzt pixelgenau in der Textur (gbuffers_terrain), nicht mehr als Overlay
    }
#ifdef FX_ARENA_BEAMS
    if (side == 2) col += endBeams(camW, dir, sceneDist, t);
#endif
#ifdef FX_ARENA_SKY
    if (isSky) col += side == 2 ? endSky(dir, t) : aurora(dir, t);
#endif
    return arenaFxPalette(col, side);
}
