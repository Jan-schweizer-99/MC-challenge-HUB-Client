// Boost-Pads im Hub-Bereich: Werte wie Bahn.java, mittig auf der Achse. Lichtring, Pfeile in Flugrichtung, aufsteigende Ringe.
// Gespiegelt um x = 0.5. Braucht raySegment (arena).
vec3 padFx(vec2 yz, float dirZ, vec3 tint, vec3 camW, vec3 dir, float sceneDist, bool hasSurface, vec3 wp, vec3 nW, float t) {
    vec3 c = vec3(0.5, yz), col = vec3(0.0);
    if (hasSurface && abs(wp.y - c.y) < 0.35) {
        vec2 q = vec2(abs(wp.x - c.x), (wp.z - c.z) * dirZ);                // q.y zeigt in Flugrichtung
        float r = length(q);
        if (r < 4.5) {
            float fw = max(fwidth(r), 1e-3);
            col += tint * (exp(-pow((r - 1.45) / (0.05 + fw), 2.0)) * (0.55 + 0.2 * sin(t * 2.4)) + exp(-r * r / 3.0) * 0.07);
            float lane = (1.0 - smoothstep(0.55, 0.7, q.x)) * smoothstep(1.6, 2.0, q.y) * (1.0 - smoothstep(2.8, 4.0, q.y));
            col += tint * lane * smoothstep(0.6, 0.9, fract((q.y + q.x * 0.9) * 1.1 - t * 1.4)) * 0.40;
        }
    }
    vec3 seg = raySegment(c, c + vec3(0.0, 2.6, 0.0), camW, dir);
    if (seg.z > 0.0 && seg.z < sceneDist && seg.x < 2.4) {
        float ring = exp(-pow(fract(seg.y * 1.6 - t * 0.8) - 0.5, 2.0) * 40.0);
        col += tint * exp(-seg.x * seg.x / 1.1) * (0.03 + 0.12 * ring) * (1.0 - seg.y);
    }
    return col;
}
