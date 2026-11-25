// Boost-Pads im Hub-Bereich: Werte wie Bahn.java. Lichtring am Boden, laufende Pfeile in Flugrichtung, aufsteigende Ringe.
// Gespiegelt um x = 0.5. Braucht raySegment (arena).
vec3 padFx(vec3 c, float dirZ, vec3 tint, vec3 camW, vec3 dir, float sceneDist, bool hasSurface, vec3 wp, vec3 nW, float t) {
    vec3 col = vec3(0.0);
    if (hasSurface && nW.y > 0.9 && abs(wp.y - c.y) < 0.35) {
        vec2 q = vec2(abs(wp.x - 0.5) - c.x, (wp.z - c.z) * dirZ);          // q.y zeigt in Flugrichtung
        float r = length(q);
        if (r < 5.0) {
            float fw = max(fwidth(r), 1e-3);
            col += tint * (exp(-pow((r - 1.35) / (0.06 + fw), 2.0)) * (0.5 + 0.2 * sin(t * 3.0)) + exp(-r * r / 2.2) * 0.12);
            float v = q.y - 1.6 - abs(q.x) * -0.9, lane = step(abs(q.x), 0.75) * smoothstep(1.4, 1.9, q.y) * (1.0 - smoothstep(3.0, 4.4, q.y));
            col += tint * lane * smoothstep(0.62, 0.9, fract(v * 1.1 - t * 1.6)) * 0.45;
        }
    }
    for (int s = -1; s <= 1; s += 2) {
        vec3 a = vec3(0.5 + float(s) * c.x, c.y, c.z);
        vec3 seg = raySegment(a, a + vec3(0.0, 3.2, 0.0), camW, dir);
        if (seg.z <= 0.0 || seg.z > sceneDist || seg.x > 2.2) continue;
        float ring = exp(-pow(fract(seg.y * 2.0 - t * 1.1) - 0.5, 2.0) * 40.0), fade = 1.0 - seg.y;
        col += tint * exp(-seg.x * seg.x / 0.8) * (0.05 + 0.20 * ring) * fade;
    }
    return col;
}
