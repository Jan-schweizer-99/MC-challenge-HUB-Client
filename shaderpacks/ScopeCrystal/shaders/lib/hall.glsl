// Hall of Fame (Welt pvp): Werte wie Halle.java (Mitte x 0.5 / z C + 0.5, Boden-Oberseite y 104, Krone ab y 119).
// Alles spiegelbildlich zu x = 0.5. Braucht pointGlow (fx_common), rayNear und raySegment (arena).
const vec3 HALL = vec3(0.5, 104.0, -554.5);
const vec3 HALL_GOLD = vec3(1.0, 0.76, 0.30);
const vec3 HALL_ICE = vec3(0.45, 0.85, 1.0);

// Winkel von vorn (+z, 0) nach hinten (pi), links und rechts gleich
float hallAngle(vec2 q) { return atan(abs(q.x), q.y); }

// Pokal: goldener Schein, Lichtpunkte steigen in zwei gespiegelten Spiralen um ihn auf
vec3 hallTrophy(vec3 camW, vec3 dir, float sceneDist, float t) {
    if (!rayNear(HALL + vec3(0.0, 13.0, 0.0), 24.0, camW, dir, sceneDist)) return vec3(0.0);
    vec3 col = vec3(0.0);
    vec3 seg = raySegment(HALL + vec3(0.0, 2.0, 0.0), HALL + vec3(0.0, 17.0, 0.0), camW, dir);
    if (seg.z > 0.0 && seg.z - 9.0 < sceneDist) col += HALL_GOLD * exp(-seg.x * seg.x / 9.0) * (0.12 + 0.04 * sin(t * 1.4)) * softDepth(seg.z, sceneDist, 9.0);
    col += vec3(0.7, 0.9, 1.0) * innerGlow(HALL + vec3(0.0, 24.5, 0.0), camW, dir, sceneDist, 4.2, 7.0) * (0.22 + 0.08 * sin(t * 1.9));
    for (int i = 0; i < 7; i++) {
        float fi = float(i), k = fract(fi / 7.0 + t * 0.07), a = k * 9.0 + t * 0.3;
        float r = mix(5.2, 2.0, smoothstep(0.55, 1.0, k)), fade = smoothstep(0.0, 0.1, k) * (1.0 - smoothstep(0.85, 1.0, k));
        for (int s = -1; s <= 1; s += 2) {
            vec3 p = HALL + vec3(float(s) * sin(a) * r, 2.0 + k * 22.0, cos(a) * r);
            col += HALL_GOLD * (pointGlow(p, camW, dir, sceneDist, 0.14) * 1.4 + pointGlow(p, camW, dir, sceneDist, 0.7) * 0.18) * fade;
        }
    }
    return col;
}

// Krone: Lichtlauf im Goldband, Zackenspitzen funkeln nacheinander von vorn nach hinten
vec3 hallCrown(vec3 camW, vec3 dir, float sceneDist, bool hasSurface, vec3 wp, vec3 nW, float t) {
    if (!rayNear(HALL + vec3(0.0, 22.0, 0.0), 33.0, camW, dir, sceneDist)) return vec3(0.0);
    vec3 col = vec3(0.0);
    for (int k = 0; k <= 8; k++) {
        float a = float(k) * 0.392699, b = pow(0.5 + 0.5 * cos(a * 2.0 - t * 1.1), 5.0);
        for (int s = -1; s <= 1; s += 2) {
            if (s < 0 && (k == 0 || k == 8)) continue;
            vec3 p = HALL + vec3(float(s) * sin(a) * 25.5, 29.6, cos(a) * 25.5);
            col += mix(HALL_GOLD, vec3(1.0), 0.4) * (pointGlow(p, camW, dir, sceneDist + 1.0, 0.55) * (0.25 + b) + pointGlow(p, camW, dir, sceneDist + 1.0, 2.2) * 0.22 * b);
        }
    }
    vec2 q = wp.xz - HALL.xz;
    float r = length(q), h = wp.y - HALL.y;
    if (hasSurface && abs(nW.y) < 0.5 && r > 23.5 && r < 27.5 && h > 15.8 && h < 30.0) {
        float ang = hallAngle(q), run = pow(0.5 + 0.5 * cos(ang * 3.0 - t * 1.3), 8.0);
        float band = exp(-pow((h - 17.0) / 0.9, 2.0));
        float sheen = pow(0.5 + 0.5 * sin(ang * 14.0 + h * 0.8 - t * 1.7), 18.0);
        col += HALL_GOLD * (band * run * 0.45 + sheen * 0.16 * smoothstep(17.0, 19.0, h));
    }
    return col;
}

// Strahlenkranz über der Krone: goldene Strahlen öffnen sich nach außen
vec3 hallBurst(vec3 camW, vec3 dir, float sceneDist, float t) {
    float y = HALL.y + 37.0 + 0.5 * sin(t * 0.6);
    if (abs(dir.y) < 0.012) return vec3(0.0);
    float d = (y - camW.y) / dir.y;
    if (d <= 0.0 || d > sceneDist) return vec3(0.0);
    vec2 q = (camW + dir * d).xz - HALL.xz;
    float r = length(q);
    if (r > 34.0 || r < 4.0) return vec3(0.0);
    float ang = hallAngle(q), fw = max(d / max(abs(dir.y), 0.05) * 0.0012, 0.02);
    float ring = exp(-pow((r - 11.0) / (0.10 + fw), 2.0)) + 0.6 * exp(-pow((r - 12.2) / (0.06 + fw), 2.0));
    float ray = pow(abs(cos(ang * 8.0)), 26.0) + 0.5 * pow(abs(cos(ang * 8.0 + 1.5708)), 60.0);
    float len = smoothstep(12.0, 14.0, r) * (1.0 - smoothstep(18.0, 33.0, r));
    float flow = 0.55 + 0.45 * sin(r * 0.9 - t * 2.4);
    float lamp = step(0.5, fract(ang * 16.0 / 3.14159)) * exp(-pow((r - 11.6) / 0.35, 2.0)) * 0.35;
    return HALL_GOLD * (ring * 0.6 + ray * len * flow * 0.34 + lamp) + HALL_ICE * exp(-pow(r - 11.0, 2.0) / 6.0) * 0.06;
}

// Nischen: Lichtkegel von oben auf die Statuen und Lichtlauf in den goldenen Rahmen
vec3 hallNiches(vec3 camW, vec3 dir, float sceneDist, bool hasSurface, vec3 wp, vec3 nW, float t) {
    vec3 col = vec3(0.0);
    if (rayNear(HALL + vec3(0.0, 5.0, 0.0), 27.0, camW, dir, sceneDist)) {
        for (int k = 1; k <= 8; k++) {
            float a = float(k) * 0.392699;
            for (int s = -1; s <= 1; s += 2) {
                if (s < 0 && k == 8) continue;
                vec3 top = HALL + vec3(float(s) * sin(a) * 22.7, 7.6, cos(a) * 22.7);
                if (!rayNear(top - vec3(0.0, 3.2, 0.0), 4.6, camW, dir, sceneDist)) continue;
                vec3 seg = raySegment(top, top - vec3(0.0, 6.4, 0.0), camW, dir);
                if (seg.z <= 0.0 || seg.z > sceneDist + 1.2) continue;
                float w = mix(0.35, 1.5, seg.y);
                col += mix(vec3(1.0), k == 8 ? HALL_GOLD : HALL_ICE, 0.65) * exp(-seg.x * seg.x / (w * w)) * (1.0 - seg.y * 0.75) * 0.17;
            }
        }
    }
    vec2 q = wp.xz - HALL.xz;
    float r = length(q), h = wp.y - HALL.y;
    if (hasSurface && h > 0.0 && h < 10.0 && r > 18.5 && r < 22.5 && abs(nW.y) < 0.5) {
        float g = hallAngle(q) / 0.392699, kk = floor(g + 0.5);
        if (kk >= 1.0) {
            float u = abs(r * sin((g - kk) * 0.392699)), arch = length(vec2(u, max(0.0, h - 5.0)));
            float path = h < 5.0 ? h : 5.0 + atan(h - 5.0, max(u, 0.01)) * 3.3;
            float line = exp(-pow((arch - 3.35) / 0.28, 2.0)), run = pow(0.5 + 0.5 * cos(path * 0.7 - t * 2.2 + kk), 8.0);
            col += HALL_GOLD * line * (0.05 + 0.4 * run);
        }
    }
    return col;
}

// Boden: Lichtkreise auf den Goldringen, Wellen vom Pokal nach außen
vec3 hallFloor(vec3 wp, vec3 nW, float t) {
    vec2 q = wp.xz - HALL.xz;
    float r = length(q);
    if (nW.y < 0.9 || abs(wp.y - HALL.y) > 0.2 || r > 31.0) return vec3(0.0);
    float fw = max(fwidth(r), 1e-3), ang = hallAngle(q);
    vec3 col = vec3(0.0);
    for (int i = 0; i < 3; i++) {
        float d = (r - (10.0 + 9.0 * float(i))) / (0.06 + fw);
        col += HALL_GOLD * exp(-d * d) * (0.2 + 0.6 * pow(0.5 + 0.5 * cos(ang * 4.0 - t * (1.0 + 0.3 * float(i))), 6.0)) * 0.7;
    }
    float ph = fract(t * 0.12), front = 8.0 + ph * 22.0, dw = r - front;
    col += HALL_GOLD * (dw < 0.0 ? exp(dw / 1.6) : exp(-dw * dw / 0.08)) * smoothstep(0.0, 0.1, ph) * (1.0 - smoothstep(0.5, 1.0, ph)) * 0.16;
    float star = pow(abs(cos(ang * 8.0)), 30.0) * smoothstep(8.0, 10.0, r) * (1.0 - smoothstep(13.0, 18.0, r));
    return col + HALL_ICE * star * (0.10 + 0.05 * sin(t * 1.5 - r));
}

// Goldstaub, der langsam durch die Halle sinkt (gespiegelte Paare)
vec3 hallDust(vec3 camW, vec3 dir, float sceneDist, float t) {
    if (!rayNear(HALL + vec3(0.0, 9.0, 0.0), 24.0, camW, dir, sceneDist)) return vec3(0.0);
    vec3 col = vec3(0.0);
    for (int i = 0; i < 12; i++) {
        float fi = float(i), a = fi * 0.2618 + 0.15 + 0.1 * sin(t * 0.3 + fi), r = 9.0 + mod(fi * 4.3, 10.5);
        float k = fract(fi * 0.381 + t * (0.03 + 0.004 * mod(fi, 3.0))), y = 17.0 * (1.0 - k);
        float tw = (0.4 + 0.6 * pow(0.5 + 0.5 * sin(t * 2.3 + fi * 2.1), 2.0)) * smoothstep(0.0, 0.08, k) * (1.0 - smoothstep(0.9, 1.0, k));
        for (int s = -1; s <= 1; s += 2)
            col += HALL_GOLD * pointGlow(HALL + vec3(float(s) * sin(a) * r, y, cos(a) * r), camW, dir, sceneDist, 0.09) * tw * 1.5;
    }
    return col;
}

// Walk of Fame: Lichtpulse laufen vom Hub zur Halle, Funken in Texturpixeln auf dem Gold
vec3 hallWalk(vec3 wp, vec3 nW, float t) {
    float x = abs(wp.x - HALL.x), z = wp.z - HALL.z;
    if (nW.y < 0.9 || x > 5.0 || z < 8.0 || z > 78.0 || wp.y < 100.5 || wp.y > 104.6) return vec3(0.0);
    float ends = smoothstep(8.0, 12.0, z) * (1.0 - smoothstep(72.0, 78.0, z));
    float pulse = pow(fract((-z + x * 0.8) / 11.0 - t * 0.4), 7.0);
    vec2 p = vec2(x, wp.z) * 16.0, cell = floor(p);
    float size = max(length(dFdx(p)), length(dFdy(p))), h = hash12(cell);
    float spark = step(0.993, h) * pow(0.5 + 0.5 * sin(t * (1.0 + 1.6 * fract(h * 911.0)) + h * 4000.0), 8.0) * (1.0 - smoothstep(0.6, 1.6, size));
    return (HALL_GOLD * (pulse * 0.5 + 0.04) * exp(-x * x * 0.35) + vec3(1.0, 0.9, 0.6) * spark * 0.5) * ends;
}

vec3 hall(vec3 camW, vec3 dir, float sceneDist, bool hasSurface, vec3 wp, vec3 nW) {
    vec3 rel = camW - HALL;
    if (length(rel.xz) > 160.0 || abs(rel.y) > 120.0) return vec3(0.0);
    float t = frameTimeCounter;
    vec3 col = vec3(0.0);
    bool inside = fxSee(FXV_HALL_IN, camW, dir, sceneDist), top = fxSee(FXV_HALL_TOP, camW, dir, sceneDist);
#ifdef FX_HALL_TROPHY
    if (inside) col += hallTrophy(camW, dir, sceneDist, t);
#endif
#ifdef FX_HALL_CROWN
    if (top) col += hallCrown(camW, dir, sceneDist, hasSurface, wp, nW, t);
#endif
#ifdef FX_HALL_BURST
    if (top) col += hallBurst(camW, dir, sceneDist, t);
#endif
#ifdef FX_HALL_NICHES
    if (inside) col += hallNiches(camW, dir, sceneDist, hasSurface, wp, nW, t);
#endif
#ifdef FX_HALL_DUST
    if (inside) col += hallDust(camW, dir, sceneDist, t);
#endif
#ifdef FX_HALL_FLOOR
    if (hasSurface) col += hallFloor(wp, nW, t);
#endif
#ifdef FX_HALL_WALK
    if (hasSurface) col += hallWalk(wp, nW, t);
#endif
    return col;
}
