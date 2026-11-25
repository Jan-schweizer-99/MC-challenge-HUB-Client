// Arena-Tempel (Welt pvp): Werte wie Tempel.java (Mitte x 0.5 / z C + 0.5, Etagen 13 hoch, Eingangsboden Oberseite y 104).
// Alles spiegelbildlich zu x = 0.5. Braucht pointGlow (fx_common) sowie rayNear und raySegment (arena).
const vec3 TEMPLE = vec3(0.5, 104.0, -343.5);

// Blickstrahl durch senkrechten Zylinder um die Tempelmitte: Entfernungen (nah, fern), -1 = kein Treffer
vec2 templeCyl(vec3 camW, vec3 dir, float R) {
    vec2 o = camW.xz - TEMPLE.xz;
    float a = dot(dir.xz, dir.xz), b = dot(o, dir.xz), c = dot(o, o) - R * R;
    float disc = b * b - a * c;
    if (disc <= 0.0 || a < 1e-6) return vec2(-1.0);
    float s = sqrt(disc);
    return vec2(-b - s, -b + s) / a;
}

// Winkel von vorn (0) nach hinten (pi), links und rechts gleich
float templeAngle(vec2 q) { return atan(abs(q.x), -q.y); }

// Kristallsäule im Schacht: weicher Schein, Lichtpulse steigen auf
vec3 templeCrystal(vec3 camW, vec3 dir, float sceneDist, float t) {
    vec3 a = vec3(TEMPLE.x, 78.0, TEMPLE.z), b = vec3(TEMPLE.x, 151.0, TEMPLE.z);
    vec3 seg = raySegment(a, b, camW, dir);
    if (seg.z <= 0.0 || seg.z - 2.6 > sceneDist || seg.x > 9.0) return vec3(0.0);
    float pulse = exp(-pow(fract(seg.y * 4.0 - t * 0.22) - 0.5, 2.0) * 55.0);
    vec3 col = vec3(0.55, 0.35, 1.0) * exp(-seg.x * seg.x / 7.0) * (0.20 + 0.06 * sin(t * 1.3));
    return col + vec3(0.6, 0.9, 1.0) * exp(-seg.x * seg.x / 5.0) * pulse * 0.45;
}

// Zwei gespiegelte Lichtbänder winden sich um die Säule nach oben
vec3 templeHelix(vec3 camW, vec3 dir, float sceneDist, float t) {
    vec2 hit = templeCyl(camW, dir, 5.5);
    vec3 col = vec3(0.0);
    for (int i = 0; i < 2; i++) {
        float d = i == 0 ? hit.x : hit.y;
        if (d <= 0.0 || d > sceneDist) continue;
        vec3 p = camW + dir * d;
        if (p.y < 78.0 || p.y > 156.0) continue;
        vec2 q = p.xz - TEMPLE.xz;
        float fade = smoothstep(78.0, 84.0, p.y) * (1.0 - smoothstep(146.0, 156.0, p.y));
        for (int k = 0; k < 2; k++) {
            float ang = atan(k == 0 ? q.x : -q.x, -q.y);
            float off = (p.y - 78.0) * 0.2416 - t * 0.55 - ang;             // eine Umdrehung je zwei Etagen
            float w = (fract(off / 6.28319 + 0.5) - 0.5) * 6.28319 * 5.5;
            float line = exp(-w * w / 0.05) + 0.22 * exp(-w * w / 1.0);
            float flow = 0.65 + 0.35 * sin(p.y * 0.9 - t * 4.0);
            col += mix(vec3(0.35, 0.85, 1.0), vec3(0.8, 0.45, 1.0), smoothstep(84.0, 150.0, p.y)) * line * flow * fade * 0.6;
        }
    }
    return col;
}

// Lichtstrahl aus der Kuppelspitze in den Himmel
vec3 templeBeam(vec3 camW, vec3 dir, float sceneDist, float t) {
    vec3 a = vec3(TEMPLE.x, 171.0, TEMPLE.z), b = vec3(TEMPLE.x, 330.0, TEMPLE.z);
    vec3 seg = raySegment(a, b, camW, dir);
    if (seg.z <= 0.0 || seg.z > sceneDist || seg.x > 9.0) return vec3(0.0);
    float fade = pow(1.0 - seg.y, 1.5) * smoothstep(0.0, 0.02, seg.y);
    float roll = 0.75 + 0.25 * sin(seg.y * 70.0 - t * 5.0);
    return (vec3(0.75, 0.95, 1.0) * exp(-seg.x * seg.x / 0.35) * 0.9 * roll + vec3(0.4, 0.55, 1.0) * exp(-seg.x * seg.x / 8.0) * 0.28) * fade;
}

// Runenringe, die über der Kuppel schweben
vec3 templeHalo(vec3 camW, vec3 dir, float sceneDist, float t) {
    vec3 col = vec3(0.0);
    for (int i = 0; i < 2; i++) {
        float y = (i == 0 ? 168.0 : 177.0) + 0.6 * sin(t * 0.7 + float(i) * 2.0);
        if (abs(dir.y) < 0.015) continue;
        float d = (y - camW.y) / dir.y;
        if (d <= 0.0 || d > sceneDist) continue;
        vec2 q = (camW + dir * d).xz - TEMPLE.xz;
        float r = length(q), R = i == 0 ? 19.0 : 12.0;
        if (abs(r - R) > 4.0) continue;
        float fw = max(d / max(abs(dir.y), 0.05) * 0.0012, 0.02), ang = templeAngle(q);
        float dir2 = i == 0 ? 1.0 : -1.0;
        float lines = exp(-pow((abs(r - R) - 1.3) / (0.07 + fw), 2.0)) + 0.5 * exp(-pow((r - R) / (0.05 + fw), 2.0));
        float cell = fract(ang * (i == 0 ? 7.0 : 5.0) / 3.14159 * 2.0 - dir2 * t * 0.18);
        float rune = step(abs(r - R), 0.95) * (smoothstep(0.10, 0.06, abs(cell - 0.5)) + smoothstep(0.05, 0.02, abs(abs(cell - 0.5) - 0.25)) * step(abs(r - R), 0.5));
        col += mix(vec3(0.45, 0.85, 1.0), vec3(0.75, 0.5, 1.0), float(i)) * (lines * 0.75 + rune * 0.5 + exp(-pow(r - R, 2.0) / 2.5) * 0.06) * (0.85 + 0.15 * sin(t * 1.5));
    }
    return col;
}

// Lichtvorhang, der vom Rand der schwebenden Insel nach unten fällt
vec3 templeFalls(vec3 camW, vec3 dir, float sceneDist, float t) {
    vec2 hit = templeCyl(camW, dir, 34.6);
    vec3 col = vec3(0.0);
    for (int i = 0; i < 2; i++) {
        float d = i == 0 ? hit.x : hit.y;
        if (d <= 0.0 || d > sceneDist) continue;
        vec3 p = camW + dir * d;
        if (p.y > 99.0 || p.y < 58.0) continue;
        float u = templeAngle(p.xz - TEMPLE.xz) * 34.6 / 0.8, cell = floor(u), h = hash12(vec2(cell, 7.0));
        if (h < 0.45) continue;
        float x = abs(fract(u) - 0.5);
        float strand = exp(-x * x * 40.0);
        float drop = pow(fract(p.y * 0.035 * (0.7 + 0.6 * h) + t * (0.22 + 0.2 * h) + h * 13.0), 7.0);
        float len = 14.0 + 26.0 * h;
        float fade = smoothstep(99.0 - len, 99.0, p.y);
        col += mix(vec3(0.35, 0.8, 1.0), vec3(0.65, 0.45, 1.0), h) * strand * (0.10 + 0.9 * drop) * fade * 0.5;
    }
    return col;
}

// Glühwürmchen zwischen Säulen und Ranken (paarweise gespiegelt)
vec3 templeFireflies(vec3 camW, vec3 dir, float sceneDist, float t) {
    if (!rayNear(TEMPLE + vec3(0.0, 8.0, 0.0), 42.0, camW, dir, sceneDist)) return vec3(0.0);
    vec3 col = vec3(0.0);
    for (int i = 0; i < 10; i++) {
        float fi = float(i);
        float a = 0.25 + fi * 0.29 + 0.18 * sin(t * 0.23 + fi * 1.7), r = 25.5 + 5.0 * sin(t * 0.17 + fi * 2.3);
        float y = 103.0 + mod(fi * 4.7, 13.0) + 1.5 * sin(t * 0.6 + fi * 1.1) - 1.0;
        float blink = 0.35 + 0.65 * pow(0.5 + 0.5 * sin(t * 1.6 + fi * 2.9), 2.0);
        for (int s = -1; s <= 1; s += 2) {
            vec3 p = vec3(TEMPLE.x + float(s) * sin(a) * r, y, TEMPLE.z - cos(a) * r);
            col += vec3(1.0, 0.78, 0.32) * (pointGlow(p, camW, dir, sceneDist, 0.09) * 1.5 + pointGlow(p, camW, dir, sceneDist, 0.45) * 0.22) * blink;
        }
    }
    return col;
}

// Böden: Lichtkreise auf den Eisringen, weiche Wellen aus der Mitte – auf jeder Etage
vec3 templeFloor(vec3 wp, vec3 nW, float t) {
    if (nW.y < 0.9) return vec3(0.0);
    float ly = wp.y - TEMPLE.y, lvl = floor(ly / 13.0 + 0.5);
    if (abs(lvl) > 2.0 || abs(ly - lvl * 13.0) > 0.3) return vec3(0.0);
    vec2 q = wp.xz - TEMPLE.xz;
    float r = length(q), lim = lvl == 0.0 ? 29.3 : 20.4;
    if (r > lim) return vec3(0.0);
    float fw = max(fwidth(r), 1e-3), ang = templeAngle(q);
    vec3 col = vec3(0.0);
    for (int i = 0; i < 3; i++) {
        float R = 13.0 + 3.0 * float(i), d = (r - R) / (0.06 + fw);
        float run = 0.35 + 0.65 * pow(0.5 + 0.5 * cos(ang * 2.0 - t * (0.9 + 0.25 * float(i)) + lvl), 6.0);
        col += mix(vec3(0.4, 0.85, 1.0), vec3(0.75, 0.5, 1.0), float(i) * 0.5) * exp(-d * d) * run * 0.6;
    }
    float ph = fract(t * 0.11 + lvl * 0.23), front = 9.0 + ph * (lim - 9.0), dw = r - front;
    float wave = (dw < 0.0 ? exp(dw / 1.8) : exp(-dw * dw / 0.1)) * smoothstep(0.0, 0.1, ph) * (1.0 - smoothstep(0.6, 1.0, ph));
    return col + vec3(0.35, 0.65, 1.0) * wave * 0.16;
}

// Aufzüge: Lichtsäulen über den Plattformen, Ringe steigen auf
vec3 templeLifts(vec3 camW, vec3 dir, float sceneDist, float t) {
    vec3 col = vec3(0.0);
    for (int s = -1; s <= 1; s += 2) {
        vec3 a = vec3(TEMPLE.x + float(s) * 11.0, 78.0, TEMPLE.z - 11.0), b = vec3(a.x, 142.0, a.z);
        vec3 seg = raySegment(a, b, camW, dir);
        if (seg.z <= 0.0 || seg.z > sceneDist || seg.x > 3.5) continue;
        float h = mod(seg.y * 64.0, 13.0);                                   // Höhe über dem Etagenboden
        float fade = exp(-h * 0.28);
        float ring = exp(-pow(mod(h - t * 2.2, 3.0) - 1.5, 2.0) * 5.0);
        col += vec3(0.55, 0.8, 1.0) * exp(-seg.x * seg.x / 0.9) * (0.16 + 0.35 * ring) * fade;
        col += vec3(0.7, 0.5, 1.0) * exp(-seg.x * seg.x / 3.0) * 0.07 * fade;
    }
    return col;
}

vec3 temple(vec3 camW, vec3 dir, float sceneDist, bool hasSurface, vec3 wp, vec3 nW) {
    vec3 rel = camW - TEMPLE;
    if (length(rel.xz) > 150.0 || abs(rel.y) > 120.0) return vec3(0.0);
    float t = frameTimeCounter;
    vec3 col = vec3(0.0);
#ifdef FX_TEMPLE_CRYSTAL
    col += templeCrystal(camW, dir, sceneDist, t);
#endif
#ifdef FX_TEMPLE_HELIX
    col += templeHelix(camW, dir, sceneDist, t);
#endif
#ifdef FX_TEMPLE_BEAM
    col += templeBeam(camW, dir, sceneDist, t);
#endif
#ifdef FX_TEMPLE_HALO
    col += templeHalo(camW, dir, sceneDist, t);
#endif
#ifdef FX_TEMPLE_FALLS
    col += templeFalls(camW, dir, sceneDist, t);
#endif
#ifdef FX_TEMPLE_LIFTS
    col += templeLifts(camW, dir, sceneDist, t);
#endif
#ifdef FX_TEMPLE_FIREFLIES
    col += templeFireflies(camW, dir, sceneDist, t);
#endif
#ifdef FX_TEMPLE_FLOOR
    if (hasSurface) col += templeFloor(wp, nW, t);
#endif
    return col;
}
