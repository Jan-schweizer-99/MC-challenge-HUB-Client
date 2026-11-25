#ifndef ARENA_PATHS
#define ARENA_PATHS
// Bahnen der Arena-Effekte (Kristall-Kugeln, Kometen, Jumppad-Bögen).
// Werden EINMAL pro Frame im begin-Pass in colortex4 vorberechnet (arenaCacheTexel)
// und im composite nur noch gelesen – statt für jedes Pixel hunderte sin/cos/pow.
//
// colortex4-Layout (36 × 28, RGBA32F), Zeile 27 = Gruppen-Hüllkugeln (Batching):
//   Zeile 0, x 0..1         Portal-Zustand (portal_state.glsl), x 2 Ankunftszeit fuer das Hub-Herz
//   Zeilen 1..8             Kristall-Kugel i: x 0..17 Positionen (Kopf + Schweif), x 18 Hüllkugel
//   Zeilen 9..14            Komet i:          x 0..25 Positionen (Kopf + Schweif), x 26 Hüllkugel
//   Zeilen 15..26           Jumppad-Bogen k:  x 0..22 Röhrenpunkte, x 23..28 Partikel (w = fade),
//                                             x 29..34 Partikel-Schweif, x 35 Hüllkugel

const int ORB_COUNT = 6;
const int ORB_SAMPLES = 5;           // Stuetzpunkte: Kopf + 4 -> 4 Lichtlinien-Stuecke pro Schweif
const float ORB_DT = 0.1375;         // Zeitabstand der Stuetzpunkte (Schweif ~0.55 s lang)
const int COMET_COUNT = 4;
const int COMET_SAMPLES = 6;         // Kopf + 5 -> 5 Lichtlinien-Stuecke
const float COMET_DT = 0.135;        // Schweif ~0.68 s lang
const int ARC_COUNT = 12;
const int ARC_SEG = 14;              // Roehre: 14 Kurvenstuecke
const int ARC_PARTICLES = 4;         // Lichtpulse, die durch die Roehre wandern (kein Partikel mehr)
const int CACHE_ORB_ROW = 1;
const int CACHE_COMET_ROW = 9;
const int CACHE_ARC_ROW = 15;
const int CACHE_ARC_PART = 23;
const int CACHE_ARC_TAIL = 29;
const int CACHE_ARC_BOUND = 35;
const int CACHE_GROUP_ROW = 27;      // Gruppen-Hüllkugeln: x 0..3 Bögen je Himmelsrichtung, x 4 alle Kometen

// Kugeln, die den schwebenden Riesenkristall umkreisen
vec3 crystalOrbPos(int i, float t) {
    float fi = float(i);
    vec3 c = vec3(0.5, 109.5, 0.5);
    float a = t * (0.55 + 0.05 * fi) * (i % 2 == 0 ? 1.0 : -1.0) + fi * 0.785;
    float r = 6.0 + 1.2 * sin(t * 0.4 + fi);
    float tilt = 0.35 * sin(fi * 1.3);
    return c + vec3(cos(a) * r, sin(a * 2.0 + fi) * 2.2 + sin(a) * r * tilt, sin(a) * r);
}

vec3 cometPos(int i, float t) {
    float fi = float(i);
    float a = t * (0.32 + 0.07 * fi) * (i % 2 == 0 ? 1.0 : -1.0) + fi * 1.9;
    float rx = 30.0 + 8.0 * sin(fi * 2.3), rz = 22.0 + 10.0 * cos(fi * 1.7);
    float h = 123.0 + 6.0 * sin(fi * 1.1) + 3.0 * sin(t * 0.45 + fi);
    return vec3(cos(a) * rx + 0.5, h + sin(a * 2.0 + fi) * 3.5, sin(a) * rz + 0.5);
}

float cometHalfSize(int i) { return 0.6 + 0.3 * float(i % 3); }

// Minecraft-Physik pro Tick: erst bewegen, dann vy = (vy - 0.08) * 0.98, horizontal * 0.91 (Luft).
vec3 arcPos(vec3 start, vec2 dirH, float vh, float vy0, float n) {
    float h = vh * (1.0 - pow(0.91, n)) / 0.09;
    float y = (vy0 + 3.92) * (1.0 - pow(0.98, n)) / 0.02 - 3.92 * n;
    return start + vec3(dirH.x * h, y, dirH.y * h);
}

// Bogen k = Achse * 3 + Typ (0: Mitte → Kristall, 1: grün → Tribüne, 2: ocker → zurück in die Arena)
void arcParams(int k, out vec3 start, out vec2 dirH, out float vh, out float vy0, out float ticks, out float seed) {
    vec2 axes[4] = vec2[4](vec2(1.0, 0.0), vec2(-1.0, 0.0), vec2(0.0, 1.0), vec2(0.0, -1.0));
    vec2 a = axes[k / 3];
    int type = k % 3;
    if (type == 0) {
        vec2 c0 = vec2(0.5) + a * 15.0;
        start = vec3(c0.x, 101.5, c0.y); dirH = -a; vh = 1.2; vy0 = 1.6; ticks = 30.0; seed = 0.0;
    } else if (type == 1) {
        vec2 c1 = vec2(0.5) + a * 23.0;
        start = vec3(c1.x, 101.5, c1.y); dirH = a; vh = 0.72; vy0 = 2.1; ticks = 44.0; seed = 0.3;
    } else {
        vec2 d = vec2(a.x - a.y, a.x + a.y) * 0.7071067812;
        vec2 c2 = floor(d * 31.0 + vec2(0.5)) + vec2(0.5);
        start = vec3(c2.x, 111.5, c2.y); dirH = -normalize(c2 - vec2(0.5)); vh = 1.05; vy0 = 0.9; ticks = 30.0; seed = 0.6;
    }
}

vec3 arcColor(int k) {
    int type = k % 3;
    return type == 0 ? vec3(0.45, 0.85, 1.0) : type == 1 ? vec3(0.45, 1.0, 0.55) : vec3(1.0, 0.7, 0.3);
}

// Hüllkugel eines Bogens: Start, Ende und analytischer Scheitelpunkt, plus Röhre und Puls-Leuchten
vec4 arcBound(int k) {
    vec3 start; vec2 dirH; float vh, vy0, ticks, seed;
    arcParams(k, start, dirH, vh, vy0, ticks, seed);
    vec3 end = arcPos(start, dirH, vh, vy0, ticks);
    float peakTick = clamp(log(3.92 * 0.02 / ((vy0 + 3.92) * -log(0.98))) / log(0.98), 0.0, ticks);
    vec3 peak = arcPos(start, dirH, vh, vy0, peakTick);
    vec3 lo = min(start, end), hi = max(max(start, end), peak);
    return vec4((lo + hi) * 0.5, length((hi - lo) * 0.5) + 1.5);
}

// Ein Texel des Caches berechnen (läuft im begin-Pass, nur 36 × 28 Pixel pro Frame)
vec4 arenaCacheTexel(ivec2 px, float t) {
    int x = px.x, y = px.y;
    if (y >= CACHE_ORB_ROW && y < CACHE_ORB_ROW + ORB_COUNT) {
        int i = y - CACHE_ORB_ROW;
        if (x < ORB_SAMPLES) return vec4(crystalOrbPos(i, t - float(x) * ORB_DT), 1.0);
        if (x == ORB_SAMPLES) {
            vec3 lo = vec3(1e9), hi = vec3(-1e9);
            for (int j = 0; j < ORB_SAMPLES; j++) {
                vec3 p = crystalOrbPos(i, t - float(j) * ORB_DT);
                lo = min(lo, p); hi = max(hi, p);
            }
            // + Reichweite des breitesten Leuchtens (Halo r 0.9 → unter 1/1000 ab ~2.2 Blöcken)
            return vec4((lo + hi) * 0.5, length(hi - lo) * 0.5 + 2.3);
        }
        return vec4(0.0);
    }
    if (y >= CACHE_COMET_ROW && y < CACHE_COMET_ROW + COMET_COUNT) {
        int i = y - CACHE_COMET_ROW;
        if (x < COMET_SAMPLES) return vec4(cometPos(i, t - float(x) * COMET_DT), 1.0);
        if (x == COMET_SAMPLES) {
            vec3 lo = vec3(1e9), hi = vec3(-1e9);
            for (int j = 0; j < COMET_SAMPLES; j++) {
                vec3 p = cometPos(i, t - float(j) * COMET_DT);
                lo = min(lo, p); hi = max(hi, p);
            }
            // Schweif-Leuchten: Radius bis 0.9 bei Gewicht 0.75 → unter 1/1000 ab ~2.4 Blöcken
            return vec4((lo + hi) * 0.5, length(hi - lo) * 0.5 + 2.5);
        }
        return vec4(0.0);
    }
    if (y >= CACHE_ARC_ROW && y < CACHE_ARC_ROW + ARC_COUNT) {
        int k = y - CACHE_ARC_ROW;
        vec3 start; vec2 dirH; float vh, vy0, ticks, seed;
        arcParams(k, start, dirH, vh, vy0, ticks, seed);
        if (x <= ARC_SEG) return vec4(arcPos(start, dirH, vh, vy0, ticks * float(x) / float(ARC_SEG)), 1.0);
        if (x == CACHE_ARC_BOUND) return arcBound(k);
        return vec4(0.0);
    }
    if (y == CACHE_GROUP_ROW) {
        // Batching: eine Hüllkugel pro Gruppe – ein Test entscheidet für mehrere Effekte auf einmal
        if (x < 4) {                                          // 3 Bögen einer Himmelsrichtung
            vec4 b0 = arcBound(x * 3), b1 = arcBound(x * 3 + 1), b2 = arcBound(x * 3 + 2);
            vec3 c = (b0.xyz + b1.xyz + b2.xyz) / 3.0;
            float R = max(length(b0.xyz - c) + b0.w, max(length(b1.xyz - c) + b1.w, length(b2.xyz - c) + b2.w));
            return vec4(c, R);
        }
        if (x == 4) {                                         // alle Kometen samt Schweif und Halo
            vec3 lo = vec3(1e9), hi = vec3(-1e9);
            for (int i = 0; i < COMET_COUNT; i++) for (int j = 0; j < COMET_SAMPLES; j++) {
                vec3 p = cometPos(i, t - float(j) * COMET_DT);
                lo = min(lo, p); hi = max(hi, p);
            }
            return vec4((lo + hi) * 0.5, length(hi - lo) * 0.5 + 7.0);   // Halo bis 5.7 × 1.2
        }
    }
    return vec4(0.0);
}
#endif
