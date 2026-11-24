// Showcase-Room: alles hier wird in WELTKOORDINATEN gezeichnet.
// camW = Kamera in Weltkoordinaten, dir = Blickstrahl, sceneDist = Abstand zum nächsten Block (Verdeckung)

uniform float frameTimeCounter;

// ---------------------------------------------------------------- Ziffern (3x5-Pixelschrift)
int fontBits(int d) {
    const int F[10] = int[10](31599, 9362, 29671, 29391, 23497, 31183, 31215, 29257, 31727, 31695);
    return F[clamp(d, 0, 9)];
}

float glyph(int d, vec2 p) {                      // p in [0,1]², y = 0 oben
    if (p.x < 0.0 || p.x >= 1.0 || p.y < 0.0 || p.y >= 1.0) return 0.0;
    int x = int(p.x * 3.0), y = int(p.y * 5.0);
    return float((fontBits(d) >> ((4 - y) * 3 + (2 - x))) & 1);
}

// Zahl schreiben: p = lokale Position (Blöcke), cw = Zeichenbreite
float printInt(int v, vec2 p, float cw) {
    float ch = cw * 5.0 / 3.0;
    if (p.y < 0.0 || p.y > ch) return 0.0;
    int n = abs(v);
    int digits = n >= 10000 ? 5 : n >= 1000 ? 4 : n >= 100 ? 3 : n >= 10 ? 2 : 1;
    float adv = cw * 1.4;
    int idx = int(floor(p.x / adv));
    float off = (v < 0) ? 1.0 : 0.0;
    if (v < 0 && idx == 0) {                       // Minus
        vec2 q = vec2(fract(p.x / adv) * adv / cw, p.y / ch);
        return (q.x < 1.0 && abs(q.y - 0.5) < 0.1) ? 1.0 : 0.0;
    }
    int di = idx - int(off);
    if (di < 0 || di >= digits) return 0.0;
    int pw = 1;
    for (int i = 0; i < digits - 1 - di; i++) pw *= 10;
    int d = (n / pw) % 10;
    vec2 q = vec2((p.x - float(idx) * adv) / cw, p.y / ch);
    return glyph(d, q);
}

// ---------------------------------------------------------------- Weltgitter auf allen Flächen im Raum
vec3 worldGrid(vec3 wp, vec3 nW) {
    vec3 rel = wp - SHOWCASE;
    if (max(abs(rel.x - 0.5), abs(rel.z - 0.5)) > SHOWCASE_R || rel.y < -2.0 || rel.y > 40.0) return vec3(0.0);
    vec3 an = abs(nW);
    vec3 fw = max(fwidth(wp), vec3(1e-4));
    vec3 d1 = abs(fract(wp - 0.5) - 0.5) / fw;                 // jede Blockkante
    vec3 d4 = abs(fract(wp / 4.0 - 0.5) - 0.5) * 4.0 / fw;     // alle 4 Blöcke
    vec3 l1 = (1.0 - clamp(d1 - 0.5, 0.0, 1.0)) * (1.0 - an);
    vec3 l4 = (1.0 - clamp(d4 - 1.0, 0.0, 1.0)) * (1.0 - an);
    float pulse = 0.6 + 0.4 * sin(frameTimeCounter * 2.0 - length(rel.xz) * 0.5);
    vec3 col = vec3(0.0);
    col += vec3(1.0, 0.25, 0.3) * (l1.x * 0.12 + l4.x * 0.55 * pulse);   // x = const: rot
    col += vec3(0.3, 1.0, 0.45) * (l1.y * 0.12 + l4.y * 0.55 * pulse);  // y = const: grün
    col += vec3(0.3, 0.55, 1.0) * (l1.z * 0.12 + l4.z * 0.55 * pulse);  // z = const: blau
    // Koordinaten auf den Boden schreiben (alle 8 Blöcke)
    if (nW.y > 0.9) {
        vec2 cell = floor(wp.xz / 8.0) * 8.0;
        vec2 lp = wp.xz - cell - vec2(0.6);
        float tx = printInt(int(cell.x), vec2(lp.x, lp.y), 0.32);
        float tz = printInt(int(cell.y), vec2(lp.x, lp.y - 0.75), 0.32);
        col += vec3(1.0, 0.35, 0.4) * tx * 1.6 + vec3(0.4, 0.6, 1.0) * tz * 1.6;
        // Kreuz am Messpunkt
        vec2 c = abs(wp.xz - cell);
        col += vec3(1.0) * (step(c.x, 0.04) + step(c.y, 0.04)) * step(max(c.x, c.y), 0.35) * 0.8;
    }
    return col;
}

// ---------------------------------------------------------------- Leuchtkugeln mit Schweif und Richtungsvektor
const int ORBS = 6;
const int TRAIL = 28;

vec3 orbPos(int i, float t) {
    float fi = float(i);
    vec3 c = SHOWCASE + vec3(0.5, 6.0, 0.5);
    float a = t * (0.32 + 0.06 * fi) + fi * 1.047;
    float r = 8.0 + 2.0 * sin(t * 0.27 + fi * 1.7);
    return c + vec3(sin(a) * r, 3.0 * sin(t * (0.45 + 0.09 * fi) + fi * 2.1), cos(a * 1.25 + fi) * r);
}

vec3 orbColor(int i) {
    vec3 cols[6] = vec3[6](vec3(1.0, 0.3, 0.85), vec3(0.3, 0.8, 1.0), vec3(0.4, 1.0, 0.6),
                           vec3(1.0, 0.75, 0.3), vec3(0.65, 0.4, 1.0), vec3(1.0, 0.4, 0.35));
    return cols[i];
}

// Leuchten eines Punkts entlang des Blickstrahls (verdeckt, wenn hinter einem Block)
float pointGlow(vec3 p, vec3 camW, vec3 dir, float sceneDist, float radius) {
    vec3 oc = p - camW;
    float tc = dot(oc, dir);
    if (tc < 0.0 || tc > sceneDist) return 0.0;
    float d2 = dot(oc, oc) - tc * tc;
    return exp(-d2 / (radius * radius));
}

vec3 orbs(vec3 camW, vec3 dir, float sceneDist) {
    float t = frameTimeCounter;
    vec3 col = vec3(0.0);
    for (int i = 0; i < ORBS; i++) {
        vec3 c = orbColor(i);
        vec3 head = orbPos(i, t);
        // Schnelltest: Strahl weit weg von der ganzen Bahn → überspringen
        col += c * pointGlow(head, camW, dir, sceneDist, 0.28) * 3.0;            // Kern
        col += c * pointGlow(head, camW, dir, sceneDist, 1.1) * 0.35;            // Halo
        for (int j = 1; j < TRAIL; j++) {                                        // Schweif
            float k = float(j) / float(TRAIL);
            vec3 p = orbPos(i, t - float(j) * 0.045);
            col += c * pointGlow(p, camW, dir, sceneDist, 0.22 * (1.0 - k) + 0.03) * (1.0 - k) * 0.9;
        }
        vec3 vel = normalize(orbPos(i, t + 0.02) - head);                          // Richtungsvektor
        for (int j = 1; j <= 10; j++) {
            vec3 p = head + vel * (float(j) * 0.22);
            col += vec3(1.0) * pointGlow(p, camW, dir, sceneDist, 0.05) * 0.8;
        }
        vec3 tip = head + vel * 2.3;
        vec3 side = normalize(cross(vel, vec3(0.0, 1.0, 0.0))) * 0.25;
        for (int j = 0; j <= 4; j++) {                                           // Pfeilspitze
            float s = float(j) / 4.0;
            col += vec3(1.0) * pointGlow(mix(tip, tip - vel * 0.45 + side, s), camW, dir, sceneDist, 0.05) * 0.8;
            col += vec3(1.0) * pointGlow(mix(tip, tip - vel * 0.45 - side, s), camW, dir, sceneDist, 0.05) * 0.8;
        }
    }
    return col;
}

// ---------------------------------------------------------------- Raymarching-Geometrie: rotierender Kristallrahmen
mat3 rotY(float a) { float c = cos(a), s = sin(a); return mat3(c, 0, -s, 0, 1, 0, s, 0, c); }
mat3 rotX(float a) { float c = cos(a), s = sin(a); return mat3(1, 0, 0, 0, c, s, 0, -s, c); }

float sdBoxFrame(vec3 p, vec3 b, float e) {
    p = abs(p) - b;
    vec3 q = abs(p + e) - e;
    return min(min(
        length(max(vec3(p.x, q.y, q.z), 0.0)) + min(max(p.x, max(q.y, q.z)), 0.0),
        length(max(vec3(q.x, p.y, q.z), 0.0)) + min(max(q.x, max(p.y, q.z)), 0.0)),
        length(max(vec3(q.x, q.y, p.z), 0.0)) + min(max(q.x, max(q.y, p.z)), 0.0));
}

float sdOcta(vec3 p, float s) { p = abs(p); return (p.x + p.y + p.z - s) * 0.57735027; }

float geoSdf(vec3 p) {
    float t = frameTimeCounter;
    vec3 q = rotX(t * 0.31) * rotY(t * 0.47) * p;
    float frame = sdBoxFrame(q, vec3(2.6), 0.09);
    vec3 r = rotY(-t * 0.8) * rotX(t * 0.5) * p;
    float octa = abs(sdOcta(r, 1.7)) - 0.04;
    return min(frame, octa);
}

vec3 geometry(vec3 camW, vec3 dir, float sceneDist) {
    vec3 center = SHOWCASE + vec3(0.5, 14.0, 0.5);
    vec3 oc = camW - center;
    float b = dot(oc, dir), c = dot(oc, oc) - 25.0;            // Begrenzungskugel r = 5
    float h = b * b - c;
    if (h < 0.0) return vec3(0.0);
    float t = max(-b - sqrt(h), 0.0), tEnd = min(-b + sqrt(h), sceneDist);
    float glow = 0.0;
    for (int i = 0; i < 64 && t < tEnd; i++) {
        vec3 p = camW + dir * t - center;
        float d = geoSdf(p);
        glow += 0.012 / (0.02 + d * d * 4.0);
        if (d < 0.002) {
            vec2 e = vec2(0.002, 0.0);
            vec3 n = normalize(vec3(geoSdf(p + e.xyy) - geoSdf(p - e.xyy), geoSdf(p + e.yxy) - geoSdf(p - e.yxy), geoSdf(p + e.yyx) - geoSdf(p - e.yyx)));
            float fres = pow(1.0 - abs(dot(n, dir)), 2.0);
            vec3 base = mix(vec3(0.3, 0.85, 1.0), vec3(1.0, 0.35, 0.9), 0.5 + 0.5 * sin(frameTimeCounter + p.y * 1.5));
            return base * (0.6 + 1.6 * fres) + base * glow * 0.15;
        }
        t += d * 0.9;
    }
    return vec3(0.55, 0.6, 1.0) * glow * 0.12;
}

// Alles zusammen; nur rechnen, wenn die Kamera in der Nähe des Raums ist
vec3 showcase(vec3 camW, vec3 dir, float sceneDist, bool hasSurface, vec3 wp, vec3 nW) {
    vec3 rel = camW - SHOWCASE;
    if (max(abs(rel.x), abs(rel.z)) > 80.0 || abs(rel.y) > 60.0) return vec3(0.0);
    vec3 col = orbs(camW, dir, sceneDist) + geometry(camW, dir, sceneDist);
    if (hasSurface) col += worldGrid(wp, nW);
    return col;
}
