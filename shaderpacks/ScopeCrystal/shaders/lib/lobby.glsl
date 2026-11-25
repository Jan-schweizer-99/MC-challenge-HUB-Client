// Arena-Lobby (Zwischeninsel, Mitte x 0.5 / z -399.5, Boden-Oberseite y 101) und die beiden Brücken; Werte wie Tempel.java.
// Alles spiegelbildlich zu x = 0.5. Braucht pointGlow (fx_common), rayNear und raySegment (arena).
const vec3 LOBBY = vec3(0.5, 101.0, -399.5);

// Schwebender Kristall: Schein und Lichtpulse von unten nach oben
vec3 lobbyCrystal(vec3 camW, vec3 dir, float sceneDist, float t) {
    vec3 seg = raySegment(LOBBY + vec3(0.0, 11.0, 0.0), LOBBY + vec3(0.0, 22.0, 0.0), camW, dir);
    if (seg.z <= 0.0 || seg.z - 2.2 > sceneDist || seg.x > 7.0) return vec3(0.0);
    float pulse = exp(-pow(fract(seg.y * 1.2 - t * 0.35) - 0.5, 2.0) * 30.0);
    float ends = smoothstep(0.0, 0.1, seg.y) * (1.0 - smoothstep(0.9, 1.0, seg.y));
    return (vec3(0.6, 0.4, 1.0) * exp(-seg.x * seg.x / 5.0) * 0.28 + vec3(0.6, 0.9, 1.0) * exp(-seg.x * seg.x / 3.0) * pulse * 0.4) * (0.4 + 0.6 * ends);
}

// Lichtring über dem Pavillon, gespiegelte Lichtpunkte laufen von vorn nach hinten
vec3 lobbyRing(vec3 camW, vec3 dir, float sceneDist, float t) {
    float y = LOBBY.y + 11.2 + 0.25 * sin(t * 0.9);
    if (abs(dir.y) < 0.02) return vec3(0.0);
    float d = (y - camW.y) / dir.y;
    if (d <= 0.0 || d > sceneDist) return vec3(0.0);
    vec2 q = (camW + dir * d).xz - LOBBY.xz;
    float r = length(q);
    if (abs(r - 8.0) > 2.5) return vec3(0.0);
    float fw = max(d / max(abs(dir.y), 0.05) * 0.0012, 0.02), ang = atan(abs(q.x), -q.y);
    float line = exp(-pow((r - 8.0) / (0.06 + fw), 2.0));
    float run = pow(0.5 + 0.5 * cos(ang * 3.0 - t * 1.6), 10.0);
    return mix(vec3(0.4, 0.85, 1.0), vec3(0.8, 0.5, 1.0), run) * (line * (0.35 + run) + exp(-pow(r - 8.0, 2.0) / 0.8) * (0.05 + 0.15 * run));
}

// Fliegende Würfel mit leuchtenden Kanten wie in der Arena, in gespiegelten Paaren um die Insel
vec3 lobbyCubePos(int i, float t) {
    float fi = float(i), a = t * (0.34 - 0.05 * fi) + fi * 1.9;
    float r = 14.5 + 2.2 * fi + 1.5 * sin(t * 0.3 + fi * 2.0);
    return vec3(sin(a) * r, 17.0 + 3.2 * fi + 2.0 * sin(a * 2.0 + fi * 1.3), -cos(a) * r * 0.85);
}

vec3 lobbyCubes(vec3 camW, vec3 dir, float sceneDist, float t) {
    if (!rayNear(LOBBY + vec3(0.0, 20.0, 0.0), 30.0, camW, dir, sceneDist)) return vec3(0.0);
    vec3 col = vec3(0.0);
    for (int m = 0; m < 2; m++) {
        // zweiter Durchgang: Blickstrahl gespiegelt = exakt gespiegelter Würfel
        vec3 mir = vec3(m == 0 ? 1.0 : -1.0, 1.0, 1.0), o = (camW - LOBBY) * mir, d = dir * mir;
        for (int i = 0; i < 3; i++) {
            vec3 p = lobbyCubePos(i, t);
            if (!rayNear(p, 8.5, o, d, sceneDist)) continue;               // Würfel samt Schweif
            float s = 0.55 + 0.15 * float(i);
            vec3 c = i == 0 ? vec3(0.35, 0.85, 1.0) : i == 1 ? vec3(0.75, 0.5, 1.0) : vec3(0.55, 0.95, 0.95);
            if (rayNear(p, s * 1.74, o, d, sceneDist)) {
                mat3 rot = transpose(rotX(t * (0.8 + 0.2 * float(i))) * rotY(t * 1.1 + float(i) * 2.0));
                vec3 ro = rot * (o - p), rd = rot * d, inv = 1.0 / rd;
                vec3 t0 = (-vec3(s) - ro) * inv, t1 = (vec3(s) - ro) * inv, lo = min(t0, t1), hi = max(t0, t1);
                float tn = max(max(lo.x, lo.y), lo.z), tf = min(min(hi.x, hi.y), hi.z);
                if (tf > max(tn, 0.0) && tn < sceneDist) {
                    for (int side = 0; side < 2; side++) {                 // gläsern: Vorder- und Rückseite
                        float th = side == 0 ? max(tn, 0.0) : tf;
                        if (th > sceneDist) continue;
                        vec3 e = vec3(s) - abs(ro + rd * th);
                        float mn = min(e.x, min(e.y, e.z)), mx = max(e.x, max(e.y, e.z)), mid = e.x + e.y + e.z - mn - mx;
                        col += c * exp(-mid * mid * 140.0 / (s * s)) * (side == 0 ? 2.0 : 0.8);
                    }
                    col += c * 0.05;
                }
            }
            col += c * pointGlow(p, o, d, sceneDist, s * 2.2) * 0.16;
            vec3 a = p;                                                    // Schweif: vier Lichtlinien-Stücke
            float best = 0.0;
            for (int j = 1; j <= 4; j++) {
                vec3 b = lobbyCubePos(i, t - float(j) * 0.22);
                vec3 seg = raySegment(a, b, o, d);
                if (seg.z > 0.0 && seg.z < sceneDist) {
                    float k = (float(j - 1) + seg.y) / 4.0, w = mix(0.6, 0.06, k) * s;
                    best = max(best, exp(-seg.x * seg.x / (w * w)) * (1.0 - k) * (0.7 + 0.3 * sin(k * 16.0 - t * 5.0)));
                }
                a = b;
            }
            col += c * best * 0.6;
        }
    }
    return col;
}

// Boden: Wellen aus der Mitte, Lichtpulse auf den Streifen zu den Brücken und Balkonen
vec3 lobbyFloor(vec3 wp, vec3 nW, float t) {
    vec2 q = wp.xz - LOBBY.xz;
    float ax = abs(q.x);
    if (nW.y < 0.9 || abs(wp.y - LOBBY.y) > 0.2 || ax > 18.0 || abs(q.y) > 10.0) return vec3(0.0);
    float r = length(q), fw = max(fwidth(r), 1e-3);
    vec3 col = vec3(0.0);
    for (int i = 0; i < 2; i++) {
        float d = (r - (i == 0 ? 4.0 : 7.0)) / (0.06 + fw);
        col += mix(vec3(0.75, 0.5, 1.0), vec3(0.4, 0.85, 1.0), float(i)) * exp(-d * d) * (0.35 + 0.25 * sin(t * 1.4 + float(i) * 2.0));
    }
    float ph = fract(t * 0.16), front = 1.5 + ph * 16.0, dw = r - front;
    col += vec3(0.4, 0.75, 1.0) * (dw < 0.0 ? exp(dw / 1.5) : exp(-dw * dw / 0.08)) * smoothstep(0.0, 0.08, ph) * (1.0 - smoothstep(0.55, 1.0, ph)) * 0.2;
    float side = pow(fract(ax / 8.0 - t * 0.4), 7.0) * exp(-q.y * q.y * 0.8) * smoothstep(2.0, 3.5, ax) * (1.0 - smoothstep(13.0, 16.0, ax));
    return col + vec3(0.45, 0.85, 1.0) * side * 0.5;
}

// Tafeln: Lichtlauf auf dem Rahmen, sanfter Schein davor
vec3 lobbyBoards(vec3 camW, vec3 dir, float sceneDist, bool hasSurface, vec3 wp, vec3 nW, float t) {
    vec3 col = vec3(0.0);
    vec2 q = vec2(wp.z - LOBBY.z, wp.y - 104.5);
    if (hasSurface && abs(abs(wp.x - LOBBY.x) - 15.5) < 0.15 && abs(nW.x) > 0.9 && abs(q.x) < 3.5 && abs(q.y) < 2.5) {
        vec2 e = vec2(3.5, 2.5) - abs(q);
        float edge = min(e.x, e.y);
        float ang = atan(abs(q.x), q.y);                                   // oben 0, unten pi, beide Seiten gleich
        float run = pow(0.5 + 0.5 * cos(ang * 2.0 - t * 1.8), 8.0);
        col += mix(vec3(0.35, 0.8, 1.0), vec3(0.8, 0.5, 1.0), run) * exp(-pow((edge - 0.95) / 0.07, 2.0)) * (0.35 + run);
    }
    for (int s = -1; s <= 1; s += 2)
        col += vec3(0.4, 0.7, 1.0) * pointGlow(vec3(LOBBY.x + float(s) * 14.0, 104.5, LOBBY.z), camW, dir, sceneDist, 2.6) * 0.07;
    return col;
}

// Eis am Hub-Ende der Brücke: funkelnde Kristalle und ein kalter Schimmer, der über das Eis zieht
vec3 lobbyFrost(vec3 wp, vec3 nW, float t) {
    float ax = abs(wp.x - LOBBY.x);
    if (wp.z < -434.5 || wp.z > -416.0 || ax > 12.5 || wp.y < 88.0 || wp.y > 112.0) return vec3(0.0);
    float ice = clamp((-417.0 - wp.z) / 13.0, 0.0, 1.0);
    // Funken in Texturpixeln (16 je Block); knapp unter der Oberflaeche abtasten, sonst flackert die Blockgrenze streifig
    vec3 p = (vec3(ax, wp.y, wp.z) - vec3(sign(wp.x - LOBBY.x) * nW.x, nW.y, nW.z) * 0.03) * 16.0;
    vec3 cell = floor(p);
    float h = hash12(cell.xz + cell.y * 17.31);
    float size = max(length(dFdx(p)), length(dFdy(p)));                     // Pixel groesser als ein Funke: ausblenden statt flimmern
    float spark = step(0.988, h) * pow(0.5 + 0.5 * sin(t * (0.8 + 1.4 * fract(h * 911.0)) + h * 4000.0), 8.0) * (1.0 - smoothstep(0.6, 1.6, size));
    float sheen = pow(0.5 + 0.5 * sin(ax * 0.5 + wp.y * 0.7 - wp.z * 0.45 - t * 1.1), 14.0);
    return (vec3(0.85, 0.97, 1.0) * spark * 0.45 + vec3(0.35, 0.7, 1.0) * sheen * 0.10) * ice;
}

// Brücken: Lichtpulse laufen vom Hub über die Insel zum Tempel
vec3 lobbyBridge(vec3 wp, vec3 nW, float t) {
    float x = abs(wp.x - LOBBY.x);
    if (nW.y < 0.9 || x > 2.5 || wp.z < -438.0 || wp.z > -356.0 || wp.y < 100.5 || wp.y > 104.6) return vec3(0.0);
    float pulse = pow(fract((wp.z + x * 0.8) / 9.0 - t * 0.45), 7.0);
    float ends = smoothstep(-438.0, -433.0, wp.z) * (1.0 - smoothstep(-361.0, -356.0, wp.z)) * smoothstep(1.0, 3.0, length(wp.xz - LOBBY.xz));
    return vec3(0.45, 0.85, 1.0) * (pulse * 0.5 + 0.05) * exp(-x * x * 0.45) * ends;
}

vec3 lobby(vec3 camW, vec3 dir, float sceneDist, bool hasSurface, vec3 wp, vec3 nW) {
    vec3 rel = camW - LOBBY;
    if (length(rel.xz) > 130.0 || abs(rel.y) > 100.0) return vec3(0.0);
    float t = frameTimeCounter;
    vec3 col = vec3(0.0);
#ifdef FX_LOBBY_CRYSTAL
    col += lobbyCrystal(camW, dir, sceneDist, t);
#endif
#ifdef FX_LOBBY_RING
    col += lobbyRing(camW, dir, sceneDist, t);
#endif
#ifdef FX_LOBBY_CUBES
    col += lobbyCubes(camW, dir, sceneDist, t);
#endif
#ifdef FX_LOBBY_BOARDS
    col += lobbyBoards(camW, dir, sceneDist, hasSurface, wp, nW, t);
#endif
#ifdef FX_LOBBY_FLOOR
    if (hasSurface) col += lobbyFloor(wp, nW, t);
#endif
#ifdef FX_LOBBY_FROST
    if (hasSurface) col += lobbyFrost(wp, nW, t);
#endif
#ifdef FX_LOBBY_BRIDGE
    if (hasSurface) col += lobbyBridge(wp, nW, t);
#endif
    return col;
}
