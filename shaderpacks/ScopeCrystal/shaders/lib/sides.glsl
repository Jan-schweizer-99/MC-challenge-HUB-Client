// Seitenplätze des Hubs: World Sanctum (links, CHAL) und Arcade (rechts, ARCADE); Werte wie Seiten.java.
// Jede Seite gespiegelt um z = -454.5. Braucht pointGlow/rotY (fx_common), rayNear/raySegment (arena), hubPillars/hubReady (hub).

// Örtliche Richtung: x zeigt zum Hub, y quer (gespiegelt)
vec2 sideLocal(vec2 xz, vec3 c, float dirX) { vec2 q = xz - c.xz; return vec2(q.x * dirX, abs(q.y)); }

// Lichtpulse auf der Brücke, vom Hub zum Platz
vec3 sideBridge(vec3 wp, vec3 nW, vec3 c, float dirX, vec3 tint, float t) {
    vec2 q = sideLocal(wp.xz, c, dirX);
    if (nW.y < 0.9 || q.y > 4.5 || q.x < 18.0 || q.x > 61.0 || wp.y < 100.5 || wp.y > 104.6) return vec3(0.0);
    float ends = smoothstep(18.0, 22.0, q.x) * (1.0 - smoothstep(57.0, 61.0, q.x));
    return tint * (pow(fract((q.x + q.y * 0.8) / 11.0 + t * 0.4), 7.0) * 0.5 + 0.04) * exp(-q.y * q.y * 0.4) * ends;
}

// ------------------------------------------------------------------ World Sanctum
const vec3 WORLD_GREEN = vec3(0.45, 1.0, 0.65);
const vec3 WORLD_BLUE = vec3(0.35, 0.75, 1.0);

// Globus: Atmosphäre und drei umlaufende Satelliten mit Schweif
vec3 worldGlobe(vec3 camW, vec3 dir, float sceneDist, float t) {
    vec3 c = CHAL + vec3(0.0, 20.5, 0.0);
    if (!rayNear(c, 17.0, camW, dir, sceneDist + 14.0)) return vec3(0.0);
    vec3 oc = c - camW;
    float tc = dot(oc, dir), d = sqrt(max(dot(oc, oc) - tc * tc, 0.0));
    vec3 col = vec3(0.0);
    if (tc > 0.0 && tc - 14.0 < sceneDist) {
        float rim = exp(-pow((d - 7.4) / 1.5, 2.0));
        col += mix(WORLD_BLUE, WORLD_GREEN, 0.3 + 0.3 * sin(t * 0.4)) * (rim * 0.30 + exp(-d * d / 60.0) * 0.08) * softDepth(tc, sceneDist, 14.0);
    }
    for (int i = 0; i < 3; i++) {
        float fi = float(i);
        vec3 a = vec3(0.0);
        for (int j = 0; j < 5; j++) {
            float w = t * (0.5 + 0.08 * fi) + fi * 2.1 - float(j) * 0.16, tilt = 0.5 + 0.55 * fi;
            vec3 p = c + vec3(cos(w) * 12.5, sin(w) * 12.5 * sin(tilt) * 0.6, sin(w) * 12.5 * cos(tilt * 0.5));
            float k = 1.0 - float(j) / 5.0;
            col += mix(WORLD_GREEN, vec3(1.0, 0.85, 0.45), fi * 0.5) * (pointGlow(p, camW, dir, sceneDist, 0.16 + 0.16 * k) * 1.1 + pointGlow(p, camW, dir, sceneDist, 0.9) * 0.10) * k * k;
        }
    }
    return col;
}

// Weltentore: wirbelndes Licht im Glas der zehn Bögen
vec3 worldGates(vec3 wp, vec3 nW, float t) {
    vec2 q = sideLocal(wp.xz, CHAL, 1.0);
    float r = length(q), h = wp.y - 101.0;
    if (r < 18.8 || r > 22.4 || h < 0.0 || h > 9.5 || abs(nW.y) > 0.6) return vec3(0.0);
    float g = degrees(atan(q.y, q.x)), k = floor((g - 18.0) / 36.0 + 0.5), da = radians(g - 18.0 - k * 36.0);
    float lat = r * sin(da), arch = length(vec2(lat, max(0.0, h - 4.5) * 1.1));
    if (arch > 3.6) return vec3(0.0);
    vec2 p = vec2(lat, h - 4.0);
    float a = atan(p.y, abs(p.x)), l = length(p);
    float swirl = pow(0.5 + 0.5 * sin(a * 3.0 + l * 2.4 - t * 1.8 + k), 3.0) * (1.0 - smoothstep(2.3, 2.8, arch));
    float edge = exp(-pow((arch - 2.85) / 0.14, 2.0)) * (0.35 + 0.3 * sin(h * 1.4 - t * 2.5));
    vec3 tint = mix(WORLD_BLUE, mod(k, 2.0) < 0.5 ? WORLD_GREEN : vec3(0.75, 0.55, 1.0), 0.6);
    return tint * (swirl * 0.22 + edge * 0.55);
}

vec3 worldFloor(vec3 wp, vec3 nW, float t) {
    vec2 q = sideLocal(wp.xz, CHAL, 1.0);
    float r = length(q);
    vec3 col = sideBridge(wp, nW, CHAL, 1.0, WORLD_GREEN, t);
    if (nW.y < 0.9 || abs(wp.y - 101.0) > 0.2 || r > 25.5) return col;
    float fw = max(fwidth(r), 1e-3), ang = atan(q.y, q.x);
    float d = (r - 22.0) / (0.06 + fw);
    col += WORLD_GREEN * exp(-d * d) * (0.2 + 0.6 * pow(0.5 + 0.5 * cos(ang * 5.0 - t * 1.1), 6.0)) * 0.7;
    float ph = fract(t * 0.12), front = 6.5 + ph * 19.0, dw = r - front;
    col += mix(WORLD_BLUE, WORLD_GREEN, ph) * (dw < 0.0 ? exp(dw / 1.6) : exp(-dw * dw / 0.08)) * smoothstep(0.0, 0.1, ph) * (1.0 - smoothstep(0.5, 1.0, ph)) * 0.18;
    // Adern laufen vom Ring zu jedem Sockel
    float g = degrees(ang), da = radians(g - 18.0 - floor((g - 18.0) / 36.0 + 0.5) * 36.0), lat = abs(r * sin(da));
    col += WORLD_GREEN * exp(-lat * lat / 0.03) * pow(fract(r / 5.0 - t * 0.5), 5.0) * smoothstep(6.5, 7.5, r) * (1.0 - smoothstep(12.0, 13.5, r)) * 0.6;
    return col;
}

// Leuchtsporen steigen aus den Gärten (gespiegelte Paare)
vec3 worldSpores(vec3 camW, vec3 dir, float sceneDist, float t) {
    if (!rayNear(CHAL + vec3(0.0, 7.0, 0.0), 29.0, camW, dir, sceneDist)) return vec3(0.0);
    vec3 col = vec3(0.0);
    for (int i = 0; i < 11; i++) {
        float fi = float(i), a = fi * 0.285 + 0.12 * sin(t * 0.3 + fi), r = 17.5 + 6.5 * sin(fi * 2.7), k = fract(fi * 0.377 + t * 0.035);
        float y = -3.0 + 17.0 * k, tw = (0.4 + 0.6 * pow(0.5 + 0.5 * sin(t * 1.9 + fi * 2.3), 2.0)) * smoothstep(0.0, 0.1, k) * (1.0 - smoothstep(0.85, 1.0, k));
        for (int s = -1; s <= 1; s += 2) {
            vec3 p = CHAL + vec3(cos(a) * r, y, float(s) * sin(a) * r);
            col += mix(WORLD_GREEN, vec3(1.0, 0.95, 0.5), fract(fi * 0.37)) * (pointGlow(p, camW, dir, sceneDist, 0.09) * 1.4 + pointGlow(p, camW, dir, sceneDist, 0.5) * 0.15) * tw;
        }
    }
    return col;
}

vec3 world(vec3 camW, vec3 dir, float sceneDist, bool hasSurface, vec3 wp, vec3 nW) {
    float t = frameTimeCounter;
    vec3 col = vec3(0.0);
#ifdef FX_HUB_PILLARS
    col += hubPillars(camW, dir, sceneDist);
#endif
#ifdef FX_HUB_READY
    col += hubReady(camW, dir, sceneDist, hasSurface, wp, nW);
#endif
#ifdef FX_WORLD_GLOBE
    col += worldGlobe(camW, dir, sceneDist, t);
#endif
#ifdef FX_WORLD_GATES
    if (hasSurface) col += worldGates(wp, nW, t);
#endif
#ifdef FX_WORLD_FLOOR
    if (hasSurface) col += worldFloor(wp, nW, t);
#endif
#ifdef FX_WORLD_SPORES
    col += worldSpores(camW, dir, sceneDist, t);
#endif
    return col;
}

// ------------------------------------------------------------------ Arcade
vec3 candy(float k) { return 0.62 + 0.38 * cos(6.2832 * (k + vec3(0.0, 0.33, 0.67))); }
const vec3 CANDY_PINK = vec3(1.0, 0.45, 0.75);
const vec3 CANDY_BLUE = vec3(0.4, 0.82, 1.0);

// Großer Würfel: Schein, kreisende Lichtkugeln in Bonbonfarben
vec3 arcadeDice(vec3 camW, vec3 dir, float sceneDist, float t) {
    vec3 c = ARCADE + vec3(0.0, 9.5, 0.0);
    if (!rayNear(c, 13.0, camW, dir, sceneDist + 9.0)) return vec3(0.0);
    vec3 col = mix(CANDY_PINK, CANDY_BLUE, 0.5 + 0.5 * sin(t * 0.8)) * innerGlow(c, camW, dir, sceneDist, 5.5, 9.0) * 0.16;
    for (int i = 0; i < 4; i++) {
        float fi = float(i), a = t * 0.7 + fi * 0.7854;
        for (int j = 0; j < 4; j++) {
            float b = a - float(j) * 0.13, k = 1.0 - float(j) / 4.0;
            for (int s = -1; s <= 1; s += 2) {
                vec3 p = c + vec3(cos(b) * 6.6, sin(b * 2.0 + fi) * 2.2, float(s) * sin(b) * 6.6);
                col += candy(fi * 0.25) * pointGlow(p, camW, dir, sceneDist, 0.14 + 0.14 * k) * k * k * 0.9;
            }
        }
    }
    return col;
}

// Glühbirnen-Lauflicht am Zeltrand, gespiegelt von vorn nach hinten
vec3 arcadeBulbs(vec3 camW, vec3 dir, float sceneDist, bool hasSurface, vec3 wp, vec3 nW, float t) {
    vec3 col = vec3(0.0);
    vec2 q = sideLocal(wp.xz, ARCADE, -1.0);
    float r = length(q), h = wp.y - 101.0, ang = atan(q.y, q.x);
    if (hasSurface && r > 23.3 && r < 26.6 && h > 10.5 && h < 12.4) {
        float cell = ang / 3.14159 * 44.0, id = floor(cell), f = fract(cell) - 0.5;
        float on = pow(0.5 + 0.5 * cos(id * 1.5708 - t * 5.0), 4.0);
        col += candy(id * 0.125) * exp(-f * f * 22.0) * exp(-pow((h - 11.5) / 0.5, 2.0)) * (0.15 + 0.85 * on);
    }
    // Streifen im Zeltdach leuchten sanft durch
    if (hasSurface && r < 25.5 && h > 10.5 && h < 32.0) {
        float run = pow(0.5 + 0.5 * cos(ang * 8.0 - r * 0.35 + t * 1.2), 10.0);
        col += mix(CANDY_PINK, CANDY_BLUE, 0.5 + 0.5 * sin(r * 0.4 - t)) * run * 0.10;
    }
    vec3 top = ARCADE + vec3(0.0, 33.0, 0.0);
    col += vec3(1.0, 0.85, 0.4) * (pointGlow(top, camW, dir, sceneDist + 1.0, 0.8) * 0.8 + innerGlow(top, camW, dir, sceneDist, 4.0, 5.0) * 0.18) * (0.7 + 0.3 * sin(t * 3.0));
    return col;
}

// Boden: Felder leuchten nacheinander wie bei einer Tanzfläche
vec3 arcadeFloor(vec3 wp, vec3 nW, float t) {
    vec2 q = sideLocal(wp.xz, ARCADE, -1.0);
    float r = length(q);
    vec3 col = sideBridge(wp, nW, ARCADE, -1.0, CANDY_PINK, t);
    if (nW.y < 0.9 || abs(wp.y - 101.0) > 0.2 || r > 25.5 || r < 5.5) return col;
    float ang = atan(q.y, q.x), seg = floor(ang / 0.3927 + 0.5), ring = r < 10.0 ? 0.0 : r < 21.0 ? 1.0 + floor((r - 10.0) / 3.67) : 4.0;
    float beat = floor(t * 1.6), f = fract(t * 1.6), h = hash12(vec2(seg + beat * 7.0, ring * 13.0 + beat));
    float lit = step(0.72, h) * (1.0 - f) * (1.0 - f);
    float fw = max(fwidth(r), 1e-3);
    col += candy(hash12(vec2(seg, ring + beat))) * lit * 0.30;
    for (int i = 0; i < 2; i++) { float d = (r - (i == 0 ? 10.0 : 21.0)) / (0.06 + fw); col += (i == 0 ? vec3(1.0, 0.8, 0.35) : CANDY_BLUE) * exp(-d * d) * (0.3 + 0.5 * pow(0.5 + 0.5 * cos(ang * 4.0 - t * 2.0), 6.0)); }
    return col;
}

// Konfetti sinkt langsam unter dem Zelt (gespiegelte Paare)
vec3 arcadeConfetti(vec3 camW, vec3 dir, float sceneDist, float t) {
    if (!rayNear(ARCADE + vec3(0.0, 7.0, 0.0), 25.0, camW, dir, sceneDist)) return vec3(0.0);
    vec3 col = vec3(0.0);
    for (int i = 0; i < 12; i++) {
        float fi = float(i), k = fract(fi * 0.381 + t * (0.05 + 0.008 * mod(fi, 3.0))), a = fi * 0.2618 + 0.15 + 0.25 * sin(t * 0.8 + fi * 1.7), r = 6.0 + mod(fi * 5.3, 15.0);
        float fade = smoothstep(0.0, 0.08, k) * (1.0 - smoothstep(0.9, 1.0, k)), flip = 0.35 + 0.65 * abs(sin(t * 3.0 + fi * 2.0));
        for (int s = -1; s <= 1; s += 2)
            col += candy(fi * 0.17) * pointGlow(ARCADE + vec3(-cos(a) * r, 12.5 * (1.0 - k), float(s) * sin(a) * r), camW, dir, sceneDist, 0.10) * fade * flip * 1.3;
    }
    return col;
}

vec3 arcade(vec3 camW, vec3 dir, float sceneDist, bool hasSurface, vec3 wp, vec3 nW) {
    float t = frameTimeCounter;
    vec3 col = vec3(0.0);
#ifdef FX_ARCADE_DICE
    col += arcadeDice(camW, dir, sceneDist, t);
#endif
#ifdef FX_ARCADE_BULBS
    col += arcadeBulbs(camW, dir, sceneDist, hasSurface, wp, nW, t);
#endif
#ifdef FX_ARCADE_FLOOR
    if (hasSurface) col += arcadeFloor(wp, nW, t);
#endif
#ifdef FX_ARCADE_CONFETTI
    col += arcadeConfetti(camW, dir, sceneDist, t);
#endif
    return col;
}
