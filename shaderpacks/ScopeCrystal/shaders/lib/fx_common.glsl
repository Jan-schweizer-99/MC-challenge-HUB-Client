// Gemeinsame Bausteine der Hub- und Arena-Effekte
uniform float frameTimeCounter;

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

mat3 rotY(float a) { float c = cos(a), s = sin(a); return mat3(c, 0, -s, 0, 1, 0, s, 0, c); }
mat3 rotX(float a) { float c = cos(a), s = sin(a); return mat3(1, 0, 0, 0, c, s, 0, -s, c); }
