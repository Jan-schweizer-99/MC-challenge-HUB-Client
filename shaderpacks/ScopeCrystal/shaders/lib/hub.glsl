// Challenge-Hub (Welt pvp, Boden y = 100): Polarlicht, grosses blaues Pixel-Herz (schwebt bei der Ankunft von oben ein), Lichtwellen auf dem Eisboden,
// Lichtsaeulen ueber den 10 Sockeln, Schneeglitzern. Keine Portale.
// Koordinaten muessen zu Hub.java passen (HX, HY, HZ, HR, RING). Braucht pointGlow/rotY aus fx_common.glsl.

// Pixel-Herz wie im Server-Icon: 13 x 12, je Zelle 2 Bit (0 leer, 1 Umriss, 2 Rot, 3 Glanz), Zeile 0 = oben
const int HEART[12] = int[12](1376592, 6964900, 27941565, 27962029, 27634025, 27634025, 6990500, 1747600, 436800, 108800, 25600, 4096);

int heartCell(ivec3 v) {
    if (v.x < 0 || v.x > 12 || v.y < 0 || v.y > 11 || v.z < 0 || v.z > 2) return 0;
    return (HEART[11 - v.y] >> (v.x * 2)) & 3;
}

vec3 heartColor(int c) {
    if (c == 1) return vec3(0.02, 0.07, 0.24);
    if (c == 2) return vec3(0.10, 0.42, 1.00);
    return vec3(0.78, 0.95, 1.0);
}

// Ankunft (7 s): 0-3,2 s schwebt es in Spiralen herab und setzt sich Wuerfel fuer Wuerfel zusammen, dann federt es nach,
// eine Lichtwelle laeuft ueber den Boden, danach schlaegt es ruhig.
// Alles, was je Bild gleich ist, rechnet composite_vsh einmal (heartA..heartC).
const float HEART_LAND = 3.2;
flat in vec4 heartA;                    // Mitte, Bloecke pro Voxel
flat in vec4 heartB;                    // Sinken e, Sekunden seit Landung, Herzschlag, Zusammenbau
flat in vec4 heartC;                    // Drehung cos/sin, Sichtbarkeit, Landeblitz

// Lichtwelle ueber den Boden, wenn das Herz landet
vec3 hubHeartWave(vec3 wp, vec3 nW) {
    float after = heartB.y;
    if (after <= 0.0 || after > 2.2 || nW.y < 0.9 || abs(wp.y - HUB.y - 1.0) > 0.2) return vec3(0.0);
    float rr = length(wp.xz - HUB.xz - vec2(0.5)), d = rr - after * 13.0;
    if (rr > HUB_R + 1.0) return vec3(0.0);
    return vec3(0.35, 0.70, 1.0) * ((d < 0.0 ? exp(d / 2.0) : exp(-d * d / 0.15)) * 0.8 + 0.25 * exp(-after * 2.2 - rr / 6.0)) * (1.0 - smoothstep(1.0, 2.2, after));
}

vec3 hubHeart(vec3 camW, vec3 dir, float sceneDist) {
    float t = frameTimeCounter, e = heartB.x, rest = 1.0 - e, after = heartB.y, beat = heartB.z, assemble = heartB.w;
    vec3 center = heartA.xyz, rested = HUB + vec3(0.5, 17.0, 0.5);
    float S = heartA.w, show = heartC.z, flash = heartC.w, p = e * HEART_LAND + after;
    vec3 ice = vec3(0.35, 0.70, 1.0), col = vec3(0.0);
    // Lichtspur ueber dem Herz und zwei gegenlaeufige Funkenspiralen, solange es sinkt
    vec2 o2 = rested.xz - camW.xz;
    float dd = max(dot(dir.xz, dir.xz), 1e-5), tv = dot(o2, dir.xz) / dd;
    if (rest > 0.001 && tv > 0.0 && tv < sceneDist) {
        vec3 q = camW + dir * tv;
        float d2 = dot(q.xz - rested.xz, q.xz - rested.xz), up = q.y - center.y;
        float tail = up > 0.0 ? exp(-up / 9.0) : exp(up / 1.5);
        col += ice * (exp(-d2 / 0.25) * 0.8 + exp(-d2 / 6.0) * 0.22) * tail * show * rest * (0.8 + 0.2 * sin(up * 2.0 + t * 9.0));
    }
    if (e < 1.0 || after < 1.2) for (int i = 0; i < 8; i++) {
        float k = float(i) / 8.0, a = p * 3.4 - k * 4.2, rad = mix(1.5, 8.5, e) * (1.0 - 0.5 * k);
        float fade = (1.0 - k) * show * (1.0 - smoothstep(0.2, 1.2, after));
        for (int s = -1; s <= 1; s += 2) {
            vec3 sp = center + vec3(float(s) * sin(a) * rad, 10.0 * k - 1.0 + 2.0 * rest, cos(a) * rad);
            col += mix(ice, vec3(1.0), 0.35) * (pointGlow(sp, camW, dir, sceneDist, 0.22) * 1.3 + pointGlow(sp, camW, dir, sceneDist, 1.0) * 0.18) * fade;
        }
    }
    col += vec3(0.30, 0.65, 1.0) * innerGlow(center, camW, dir, sceneDist, 4.2, 8.0) * (0.20 + 0.14 * beat + 0.7 * flash) * show;

    mat3 rot = mat3(heartC.x, 0.0, -heartC.y, 0.0, 1.0, 0.0, heartC.y, 0.0, heartC.x);
    vec3 o = rot * (camW - center) / S + vec3(6.5, 6.0, 1.5);
    vec3 d = rot * dir;
    d = sign(d) * max(abs(d), vec3(1e-5));
    vec3 inv = 1.0 / d;
    vec3 t0 = -o * inv, t1 = (vec3(13.0, 12.0, 3.0) - o) * inv;
    vec3 tmin = min(t0, t1), tmax = max(t0, t1);
    float tn = max(max(tmin.x, tmin.y), max(tmin.z, 0.0));
    float tf = min(min(tmax.x, tmax.y), tmax.z);
    float limit = sceneDist / S;
    if (tn < tf && tn <= limit && show > 0.0) {
    vec3 pv = o + d * (tn + 1e-3);
    ivec3 v = ivec3(floor(pv));
    ivec3 stp = ivec3(sign(d));
    vec3 tDelta = abs(inv);
    vec3 tMax = (vec3(v) + max(vec3(stp), vec3(0.0)) - o) * inv;
    int axis = tmin.x > tmin.y ? (tmin.x > tmin.z ? 0 : 2) : (tmin.y > tmin.z ? 1 : 2);
    float tc = tn;
    for (int i = 0; i < 40; i++) {
        if (tc > tf || tc > limit) break;
        int c = heartCell(v);
        float need = 0.55 * float(v.y) / 12.0 + 0.45 * hash12(vec2(abs(float(v.x) - 6.0) + 13.0 * float(v.z), float(v.y)));   // von unten nach oben
        if (c != 0 && need < assemble) {
            float shade = axis == 1 ? (stp.y < 0 ? 1.0 : 0.6) : (axis == 0 ? 0.78 : 0.92);
            vec3 f = fract(o + d * tc);
            vec3 g = min(f, 1.0 - f);
            float ex = axis == 0 ? 1.0 : g.x, ey = axis == 1 ? 1.0 : g.y, ez = axis == 2 ? 1.0 : g.z;
            float frost = 1.0 - smoothstep(0.04, 0.1, min(min(ex, ey), ez));   // eisblaue Pixelkanten
            float fresh = 1.0 - smoothstep(0.0, 0.10, assemble - need);        // frisch gesetzte Wuerfel gluehen
            float sheen = pow(0.5 + 0.5 * sin(float(v.x) * 0.5 + float(v.y) * 0.45 - t * 1.6), 12.0);   // Glanz wandert schraeg
            vec3 body = heartColor(c) * shade * (1.30 + 0.25 * beat) + vec3(0.35, 0.65, 1.0) * sheen * 0.35 * step(1.5, float(c));
            col += body + vec3(0.55, 0.88, 1.0) * (frost * 0.6 + fresh * 0.9 * step(e, 0.999) + flash * 0.5);
            break;
        }
        if (tMax.x < tMax.y && tMax.x < tMax.z) { tc = tMax.x; tMax.x += tDelta.x; v.x += stp.x; axis = 0; }
        else if (tMax.y < tMax.z) { tc = tMax.y; tMax.y += tDelta.y; v.y += stp.y; axis = 1; }
        else { tc = tMax.z; tMax.z += tDelta.z; v.z += stp.z; axis = 2; }
    }
    }
    return col;
}

// Polarlicht-Vorhaenge ueber dem Hub, im 1-Block-Pixelraster
vec3 hubAurora(vec3 camW, vec3 dir, float sceneDist) {
    if (dir.y < 0.03) return vec3(0.0);
    float t = frameTimeCounter;
    float y0 = HUB.y + 26.0, y1 = HUB.y + 50.0;
    float ta = max((y0 - camW.y) / dir.y, 0.0), tb = min((y1 - camW.y) / dir.y, sceneDist);
    if (tb <= ta) return vec3(0.0);
    const int N = 20;
    float dt = (tb - ta) / float(N);
    float jitter = hash12(gl_FragCoord.xy);
    vec3 col = vec3(0.0);
    for (int i = 0; i < N; i++) {
        vec3 p = camW + dir * (ta + dt * (float(i) + jitter));
        vec2 q = floor(p.xz - HUB.xz);
        float rq = length(q);
        if (rq > 150.0) continue;
        float h = (p.y - y0) / (y1 - y0);
        float wave = q.x * 0.05 + 1.6 * sin(q.y * 0.025 + t * 0.12) + 0.6 * sin(q.y * 0.07 - t * 0.2);
        float band = abs(fract(wave * 0.5 + t * 0.03) - 0.5);
        float curtain = exp(-band * band * 180.0);
        float flick = 0.6 + 0.4 * sin(t * 1.7 + hash12(floor(q * 0.25)) * 6.283);
        float vert = smoothstep(0.0, 0.12, h) * pow(1.0 - h, 1.6);
        vec3 c = mix(vec3(0.30, 1.0, 0.85), vec3(0.45, 0.70, 1.0), h);
        c = mix(c, vec3(0.85, 0.55, 1.0), smoothstep(0.65, 1.0, h));
        col += c * curtain * flick * vert * (1.0 - rq / 150.0);
    }
    return min(col * dt * 0.06, vec3(1.2));
}

// Runde Lichtwellen + Blockgitter auf der Oberseite des Eisbodens (y = 101)
vec3 hubFloor(vec3 wp, vec3 nW) {
    vec3 rel = wp - HUB;
    float rr = length(rel.xz - vec2(0.5));
    if (rr > HUB_R + 0.5 || nW.y < 0.9 || rel.y < 0.5 || rel.y > 1.5) return vec3(0.0);
    float t = frameTimeCounter;
    vec2 cell = floor(wp.xz);
    // Zwei weiche Kreiswellen: feine helle Front, dahinter langer Nachglanz; starten sanft in der Mitte
    // und verklingen vor dem Rand. Kantenglaettung ueber die Pixelbreite, auch bei flachem Blick.
    float fr = max(fwidth(rr), 1e-3);
    vec3 waves = vec3(0.0);
    for (int i = 0; i < 2; i++) {
        float ph = fract(t * 0.14 + float(i) * 0.5);
        float front = HUB_R * (1.0 - (1.0 - ph) * (1.0 - ph) * 0.75 - (1.0 - ph) * 0.25);   // laeuft schnell los, wird ruhiger
        float d = rr - front;
        float lw = 0.07 + fr;
        float line = exp(-d * d / (lw * lw)) * min(1.0, 0.09 / lw + 0.25);
        float trail = d < 0.0 ? exp(d / 2.2) : exp(-d * d / (0.12 + fr * fr));
        float fade = smoothstep(0.0, 0.08, ph) * (1.0 - smoothstep(0.55, 1.0, ph));
        waves += (vec3(0.85, 0.97, 1.0) * line * 0.55 + vec3(0.30, 0.72, 1.0) * trail * 0.16) * fade;
    }
    vec3 fw = max(fwidth(wp), vec3(1e-4));
    vec2 d1 = abs(fract(wp.xz - 0.5) - 0.5) / fw.xz;
    float line = max(1.0 - clamp(d1.x - 0.5, 0.0, 1.0), 1.0 - clamp(d1.y - 0.5, 0.0, 1.0));
#ifdef FX_HUB_ROUND
    line = 0.0;                                                             // kein Blockgitter, nur feine Funken
    vec2 px = floor(vec2(abs(wp.x - 0.5), wp.z) * 16.0);
    float h = hash12(px);
    float twinkle = step(0.9975, h) * pow(0.5 + 0.5 * sin(t * (1.0 + 2.0 * fract(h * 713.0)) + h * 5000.0), 6.0) * (1.0 - smoothstep(0.03, 0.09, fr));
#else
    float twinkle = step(0.985, hash12(cell + vec2(floor(t * 2.0))));
#endif
    return vec3(0.45, 0.85, 1.0) * (line * 0.07) + waves + vec3(0.9, 0.97, 1.0) * twinkle * 0.35;
}

// Weiche Lichtsaeulen ueber den 10 Sockeln (gleiche Winkel wie Hub.slotPos)
vec3 hubPillars(vec3 camW, vec3 dir, float sceneDist) {
    vec3 col = vec3(0.0);
    float t = frameTimeCounter;
    float dd = max(dot(dir.xz, dir.xz), 1e-5);
    for (int s = 0; s < 10; s++) {
        float a = radians(18.0 + float(s) * 36.0);
        vec2 pos = CHAL.xz + vec2(cos(a), sin(a)) * CHAL_RING;
        float tt = dot(pos - camW.xz, dir.xz) / dd;
        if (tt < 0.0 || tt > sceneDist) continue;
        vec3 q = camW + dir * tt;
        float y = q.y - HUB.y;
        if (y < 6.0 || y > 16.0) continue;
        float d2 = dot(q.xz - pos, q.xz - pos);
        float fade = smoothstep(6.0, 7.5, y) * (1.0 - smoothstep(11.0, 16.0, y));
        float shimmer = 0.7 + 0.3 * sin(t * 2.0 + float(s) * 1.3 + y * 0.8);
        col += vec3(0.55, 0.9, 1.0) * exp(-d2 / 0.05) * fade * shimmer * 0.5;
    }
    return col;
}

// Schneeglitzern: einzelne helle Punkte, die langsam um die Mitte sinken
vec3 hubSnow(vec3 camW, vec3 dir, float sceneDist) {
    vec3 col = vec3(0.0);
    float t = frameTimeCounter;
    for (int i = 0; i < 16; i++) {
        float fi = float(i);
        float a = t * (0.12 + 0.01 * fi) + fi * 0.3927;
        float rad = 4.0 + mod(fi * 3.7, 15.0);
        float y = 14.0 - mod(t * (0.6 + 0.05 * fi) + fi * 2.3, 13.0);
        vec3 p = HUB + vec3(0.5 + cos(a) * rad, y, 0.5 + sin(a) * rad);
        col += vec3(0.85, 0.95, 1.0) * pointGlow(p, camW, dir, sceneDist, 0.07) * 1.2;
    }
    return col;
}

// Ready-Ring um die Mitte: ruhiges Leuchten, füllt sich mit den Spielern, beim Countdown läuft er von vorn nach hinten voll
vec3 hubReady(vec3 camW, vec3 dir, float sceneDist, bool hasSurface, vec3 wp, vec3 nW) {
    float n = hubReadySignal(), t = frameTimeCounter;
    float fill = n >= 10.0 ? (n - 10.0) / 90.0 : 0.0, team = n > 0.0 && n < 10.0 ? n / 9.0 : 0.0;
    vec3 base = n >= 10.0 ? vec3(0.3, 1.0, 0.6) : vec3(0.4, 0.8, 1.0);
    vec3 col = vec3(0.0);
    vec2 c = CHAL.xz;                                                       // im World Sanctum, vorn = zum Hub (+x)
    if (hasSurface && nW.y > 0.9 && abs(wp.y - HUB.y - 1.0) < 0.2) {
        vec2 q = wp.xz - c;
        float r = length(q), fw = max(fwidth(r), 1e-3), ang = atan(abs(q.y), q.x) / 3.14159;
        float line = exp(-pow((r - 5.85) / (0.09 + fw), 2.0));
        float done = n >= 10.0 ? 1.0 - smoothstep(fill - 0.01, fill + 0.01, ang) : 0.0;
        col += base * line * (0.25 + 0.12 * sin(t * 1.6) + 0.6 * team + 1.1 * done);
        if (r < 5.85) col += base * (exp((r - 5.85) / 1.2) * (0.05 + 0.16 * team + 0.22 * done) + (n >= 10.0 ? 0.10 * fill * (0.6 + 0.4 * sin(t * 9.0 - r * 2.0)) : 0.0));
    }
    if (n <= 0.0) return col;
    // Lichtwand über dem Ring
    vec2 o = camW.xz - c;
    float a = dot(dir.xz, dir.xz), b = dot(o, dir.xz), e = b * b - a * (dot(o, o) - 34.2);
    if (e <= 0.0 || a < 1e-6) return col;
    float s = sqrt(e);
    for (int i = 0; i < 2; i++) {
        float d = (i == 0 ? -b - s : -b + s) / a;
        if (d <= 0.0 || d > sceneDist) continue;
        vec3 p = camW + dir * d;
        float h = p.y - HUB.y - 1.0, top = n >= 10.0 ? 1.0 + 3.0 * fill : 0.7;
        if (h < 0.0 || h > top) continue;
        vec2 q = p.xz - c;
        float ang = atan(abs(q.y), q.x) / 3.14159;
        float on = n >= 10.0 ? 1.0 - smoothstep(fill - 0.02, fill + 0.02, ang) : team;
        col += base * pow(1.0 - h / top, 2.0) * (0.75 + 0.25 * sin(ang * 40.0 - t * 3.0)) * on * (n >= 10.0 ? 0.38 : 0.2);
    }
    return col;
}

vec3 hub(vec3 camW, vec3 dir, float sceneDist, bool hasSurface, vec3 wp, vec3 nW) {
    vec3 rel = camW - HUB;
    if (max(abs(rel.x), abs(rel.z)) > 120.0 || abs(rel.y) > 80.0) return vec3(0.0);
    vec3 col = vec3(0.0);
#ifdef FX_HUB_AURORA
    if (fxSee(FXV_AURORA, camW, dir, sceneDist)) col += hubAurora(camW, dir, sceneDist);
#endif
#ifdef FX_HUB_HEART
    if ((fxSeen >> FXV_HEART & 1) != 0) {
        vec3 toC = heartA.xyz - camW;                       // gelandet: nur Pixel nahe am Herz, im Anflug auch die Spur
        float along = dot(toC, dir), off = dot(toC, toC) - along * along;
        bool hit = heartB.y > 1.2 ? along > 0.0 && off < 82.0 && along - 10.0 < sceneDist : fxRayBox(FXV_HEART, camW, dir, sceneDist);
        if (hit) col += hubHeart(camW, dir, sceneDist);
    }
#endif
    if (!fxSee(FXV_HUB, camW, dir, sceneDist)) return col;
#ifdef FX_HUB_HEART
    if (hasSurface) col += hubHeartWave(wp, nW);
#endif
#ifdef FX_HUB_SNOW
    col += hubSnow(camW, dir, sceneDist);
#endif
#ifdef FX_HUB_FLOOR
    if (hasSurface) col += hubFloor(wp, nW);
#endif
    return col;
}
