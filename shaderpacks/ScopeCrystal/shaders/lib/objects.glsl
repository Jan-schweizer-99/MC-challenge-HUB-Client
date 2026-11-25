// Voxel-Objekte: je Ort eins (objects_spec.glsl). Schweben bei der Ankunft in Spiralen von oben ein, setzen sich Wuerfel fuer Wuerfel
// zusammen, federn nach, schicken eine Lichtwelle ueber den Boden und leben dann ruhig weiter. Deckend, mit eigener Tiefe.
// Alles, was je Bild gleich ist, rechnet composite_vsh einmal: Platz 0 = Hub-Herz, Platz 1 = naechstes Gebaeude, Platz 2 = Lobby-Schwerter.
flat in vec4 obA[3];                    // Mitte, Bloecke pro Voxel
flat in vec4 obB[3];                    // Sinken e, Sekunden seit Landung, Herzschlag, Zusammenbau
flat in vec4 obC[3];                    // Drehung cos/sin, Sichtbarkeit, Landeblitz
flat in int obT[3];                     // Objekt, -1 = keins

// Pixel-Herz wie im Server-Icon: 13 x 12, je Zelle 2 Bit (0 leer, 1 Umriss, 2 Blau, 3 Glanz), Zeile 0 = oben
const int HEART[12] = int[12](1376592, 6964900, 27941565, 27962029, 27634025, 27634025, 6990500, 1747600, 436800, 108800, 25600, 4096);
const float CUP[13] = float[13](2.9, 2.4, 1.4, 0.8, 0.8, 1.3, 2.0, 2.7, 3.2, 3.4, 3.5, 3.6, 3.9);

ivec3 objDims(int p) { return p == 0 ? ivec3(13, 12, 3) : p == 1 ? ivec3(15, 15, 3) : p == 3 ? ivec3(13, 14, 13) : p == 4 ? ivec3(15) : ivec3(7); }
vec3 objTint(int p) { return p == 0 ? vec3(0.35, 0.70, 1.0) : p == 1 ? vec3(0.55, 0.65, 1.0) : p == 3 ? vec3(1.0, 0.76, 0.3) : p == 4 ? vec3(0.4, 1.0, 0.65) : vec3(1.0, 0.5, 0.78); }

bool objSword(ivec3 v, out int c) {                        // ein Schwert auf der Diagonale: Griff unten links, Spitze oben rechts
    int d = abs(v.x - v.y), s = v.x + v.y;
    c = 0;
    if (s < 2) c = d == 0 ? 3 : 0;                         // Knauf
    else if (s < 8) c = d <= 1 && s % 2 == 0 ? 4 : d == 0 ? 4 : 0;
    else if (s <= 10) c = d <= 3 ? 3 : 0;                  // Parierstange
    else c = d == 0 ? 2 : d <= 2 && s < 26 ? 1 : 0;
    return c != 0;
}

// Material einer Zelle, 0 = leer
int objCell(int p, ivec3 v) {
    ivec3 n = objDims(p);
    if (any(lessThan(v, ivec3(0))) || any(greaterThanEqual(v, n))) return 0;
    if (p == 0) return (HEART[11 - v.y] >> (v.x * 2)) & 3;
    if (p == 1) {
        int a, b;
        bool A = v.z >= 1 && objSword(v, a), B = v.z <= 1 && objSword(ivec3(14 - v.x, v.yz), b);
        return A ? a : B ? b : 0;
    }
    if (p == 3) {
        ivec3 q = v - ivec3(6, 0, 6);
        float r = length(vec2(q.xz));
        if (v.y < 13 && r <= CUP[v.y] && !(v.y >= 9 && r < CUP[v.y] - 1.2)) return v.y == 1 ? 2 : v.y == 10 && r > 3.0 && (q.x == 0 || q.z == 0) ? 3 : v.y == 12 ? 4 : 1;
        if (v.y == 9 && r < 2.4) return 5;                 // Licht im Kelch
        int ax = abs(q.x);
        if (q.z == 0 && ((ax == 6 && v.y >= 9 && v.y <= 12) || (ax == 5 || ax == 4) && (v.y == 8 || v.y == 13))) return 1;
        return 0;
    }
    if (p == 4) {
        vec3 q = vec3(v) - 7.0;
        float d = length(q);
        if (d >= 7.2 || d < 5.6) return 0;
        float w = sin(q.x * 0.62 + 1.3) + sin(q.z * 0.75 + q.y * 0.4) + 0.8 * sin(q.y * 0.66 - q.x * 0.35 + 0.8);
        return abs(q.y / d) > 0.86 ? 5 : w > 1.7 ? 5 : w > 1.2 ? 4 : w > 0.1 ? 3 : w > -0.3 ? 2 : 1;
    }
    ivec3 q = v - 3, a = abs(q);                           // Wuerfel mit runden Ecken
    int faces = int(a.x == 3) + int(a.y == 3) + int(a.z == 3);
    if (faces == 0) return 5;
    if (faces == 3) return 0;
    if (faces == 2) return 2;
    ivec2 f = a.x == 3 ? q.yz : a.y == 3 ? q.xz : q.xy;
    ivec2 g = abs(f);
    int eye = q.y == 3 ? 1 : q.y == -3 ? 6 : q.x == 3 ? 2 : q.x == -3 ? 5 : q.z == 3 ? 3 : 4;
    bool corner = g == ivec2(2), pip = (eye % 2 == 1 && f == ivec2(0)) || (eye >= 4 && corner) || (eye == 2 || eye == 3) && corner && f.x == f.y || eye == 6 && g == ivec2(2, 0);
    return pip ? 6 + eye : 1;
}

vec3 objColor(int p, int c, vec3 v, float t) {
    if (p == 0) return c == 1 ? vec3(0.02, 0.07, 0.24) : c == 2 ? vec3(0.10, 0.42, 1.0) : vec3(0.78, 0.95, 1.0);
    if (p == 1) return c == 1 ? vec3(0.28, 0.72, 0.90) : c == 2 ? vec3(0.85, 1.0, 1.0) : c == 3 ? vec3(0.62, 0.40, 1.0) : vec3(0.24, 0.15, 0.40);
    if (p == 3) return c == 1 ? mix(vec3(0.95, 0.62, 0.12), vec3(1.0, 0.82, 0.30), hash12(v.xz * 1.7 + v.y)) : c == 2 ? vec3(0.92, 0.90, 0.88) : c == 3 ? vec3(0.35, 0.95, 1.0) : c == 4 ? vec3(1.0, 0.93, 0.55) : vec3(1.0, 1.0, 0.85) * 1.3;
    if (p == 4) return c == 1 ? vec3(0.05, 0.22, 0.70) : c == 2 ? vec3(0.10, 0.52, 0.92) : c == 3 ? vec3(0.18, 0.62, 0.24) : c == 4 ? vec3(0.50, 0.47, 0.36) : vec3(0.95, 0.98, 1.0);
    if (c == 1) return vec3(0.66, 0.65, 0.74);
    if (c == 2) return mix(vec3(0.25, 0.65, 1.0), vec3(1.0, 0.45, 0.75), 0.5 + 0.5 * sin(t * 0.9 + v.x * 0.5 + v.y * 0.4));
    return 0.55 + 0.45 * cos(6.2832 * (float(c) * 0.16 + t * 0.12 + vec3(0.0, 0.33, 0.67)));
}

// Lichtwelle ueber den Boden, wenn ein Objekt landet
vec3 objWave(int i, vec3 wp, vec3 nW) {
    int p = obT[i];
    float after = obB[i].y;
    if (p < 0 || after <= 0.0 || after > 2.2 || nW.y < 0.9 || abs(wp.y - objGround(p)) > 0.2) return vec3(0.0);
    float rr = length(wp.xz - obA[i].xz), d = rr - after * 13.0;
    if (rr > 27.0) return vec3(0.0);
    return objTint(p) * ((d < 0.0 ? exp(d / 2.0) : exp(-d * d / 0.15)) * 0.8 + 0.25 * exp(-after * 2.2 - rr / 6.0)) * (1.0 - smoothstep(1.0, 2.2, after));
}

// Licht um ein Objekt: Schein, Spur und Funkenspiralen waehrend des Sinkens
vec3 objGlow(int i, vec3 camW, vec3 dir, float sceneDist) {
    int p = obT[i];
    float e = obB[i].x, rest = 1.0 - e, after = obB[i].y, show = obC[i].z, t = frameTimeCounter;
    vec3 center = obA[i].xyz, tint = objTint(p), col = tint * innerGlow(center, camW, dir, sceneDist, 5.0, 8.0) * (0.14 + 0.12 * obB[i].z + 0.7 * obC[i].w) * show;
    if (after > 1.2) return col;
    float dd = max(dot(dir.xz, dir.xz), 1e-5), tv = dot(center.xz - camW.xz, dir.xz) / dd;
    if (rest > 0.001 && tv > 0.0 && tv < sceneDist) {
        vec3 q = camW + dir * tv;
        float d2 = dot(q.xz - center.xz, q.xz - center.xz), up = q.y - center.y;
        col += tint * (exp(-d2 / 0.25) * 0.8 + exp(-d2 / 6.0) * 0.22) * (up > 0.0 ? exp(-up / 9.0) : exp(up / 1.5)) * show * rest * (0.8 + 0.2 * sin(up * 2.0 + t * 9.0));
    }
    for (int j = 0; j < 8; j++) {
        float k = float(j) / 8.0, a = (e * OBJ_LAND + after) * 3.4 - k * 4.2, rad = mix(1.5, 8.5, e) * (1.0 - 0.5 * k), fade = (1.0 - k) * show * (1.0 - smoothstep(0.2, 1.2, after));
        for (int s = -1; s <= 1; s += 2) {
            vec3 sp = center + vec3(float(s) * sin(a) * rad, 10.0 * k - 1.0 + 2.0 * rest, cos(a) * rad);
            col += mix(tint, vec3(1.0), 0.35) * (pointGlow(sp, camW, dir, sceneDist, 0.22) * 1.3 + pointGlow(sp, camW, dir, sceneDist, 1.0) * 0.18) * fade;
        }
    }
    return col;
}

// Strahl gegen das Objekt: Farbe und Entfernung, hit < 0 = daneben
vec3 objTrace(int i, vec3 camW, vec3 dir, float sceneDist, out float hit) {
    hit = -1.0;
    int p = obT[i];
    vec3 center = obA[i].xyz, n = vec3(objDims(p));
    float S = obA[i].w, e = obB[i].x, beat = obB[i].z, assemble = obB[i].w, flash = obC[i].w, t = frameTimeCounter;
    vec3 toC = center - camW;
    float along = dot(toC, dir), R = length(n) * 0.5 * S;
    if (obC[i].z <= 0.0 || along < -R || along - R > sceneDist || dot(toC, toC) - along * along > R * R) return vec3(0.0);
    mat3 rot = mat3(obC[i].x, 0.0, -obC[i].y, 0.0, 1.0, 0.0, obC[i].y, 0.0, obC[i].x);
    if (p == 5) rot = rotX(t * 0.45) * rot;                                          // der Wuerfel taumelt
    if (p == 4) rot = rotX(0.35) * rot;                                              // Erdachse schraeg
    vec3 o = rot * (camW - center) / S + n * 0.5, d = rot * dir;
    d = sign(d) * max(abs(d), vec3(1e-5)) + vec3(equal(d, vec3(0.0))) * 1e-5;
    vec3 inv = 1.0 / d, t0 = -o * inv, t1 = (n - o) * inv, tmin = min(t0, t1), tmax = max(t0, t1);
    float tn = max(max(tmin.x, tmin.y), max(tmin.z, 0.0)), tf = min(min(tmax.x, tmax.y), tmax.z), limit = sceneDist / S;
    vec3 col = vec3(0.0);
    if (tn < tf && tn <= limit) {
        ivec3 v = ivec3(floor(o + d * (tn + 1e-3))), stp = ivec3(sign(d));
        vec3 tDelta = abs(inv), tMax = (vec3(v) + max(vec3(stp), vec3(0.0)) - o) * inv;
        int axis = tmin.x > tmin.y ? (tmin.x > tmin.z ? 0 : 2) : (tmin.y > tmin.z ? 1 : 2);
        float tc = tn;
        for (int k = 0; k < 44; k++) {
            if (tc > tf || tc > limit) break;
            float need = 0.55 * float(v.y) / n.y + 0.45 * hash12(vec2(abs(float(v.x) - n.x * 0.5 + 0.5) + 13.0 * float(v.z), float(v.y)));   // von unten nach oben
            int c = need < assemble ? objCell(p, v) : 0;
            if (c != 0) {
                vec3 f = fract(o + d * tc), g = min(f, 1.0 - f), nl = axis == 0 ? vec3(-stp.x, 0, 0) : axis == 1 ? vec3(0, -stp.y, 0) : vec3(0, 0, -stp.z);
                vec3 nw = nl * rot;                                                  // Normale im Raum: von oben beleuchtet
                float shade = 0.70 + 0.30 * nw.y + 0.10 * abs(nw.x);
                float ex = axis == 0 ? 1.0 : g.x, ey = axis == 1 ? 1.0 : g.y, ez = axis == 2 ? 1.0 : g.z;
                float edge = 1.0 - smoothstep(0.04, 0.10, min(min(ex, ey), ez));
                float fresh = (1.0 - smoothstep(0.0, 0.10, assemble - need)) * step(e, 0.999);
                float sheen = pow(0.5 + 0.5 * sin(float(v.x) * 0.5 + float(v.y) * 0.45 + float(v.z) * 0.4 - t * 1.6), 12.0);
                vec3 tint = objTint(p);
                col = objColor(p, c, vec3(v), t) * shade * (1.18 + 0.25 * beat) + mix(tint, vec3(1.0), 0.4) * sheen * (p == 4 ? 0.12 : 0.30);
                col += mix(tint, vec3(1.0), 0.45) * (edge * (p == 0 ? 0.55 : 0.22) + fresh * 0.9 + flash * 0.4);
                hit = tc * S;
                break;
            }
            if (tMax.x < tMax.y && tMax.x < tMax.z) { tc = tMax.x; tMax.x += tDelta.x; v.x += stp.x; axis = 0; }
            else if (tMax.y < tMax.z) { tc = tMax.y; tMax.y += tDelta.y; v.y += stp.y; axis = 1; }
            else { tc = tMax.z; tMax.z += tDelta.z; v.z += stp.z; axis = 2; }
        }
    }
    return col;
}
