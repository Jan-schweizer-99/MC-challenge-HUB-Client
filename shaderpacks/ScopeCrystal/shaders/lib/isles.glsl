// Floating islands in the empty corners around the hub. Centres as in live/IslandPlan.java (ISLES). Deliberately not mirrored.
// Always on in the hub area, so everything is bounded: islesSeen (one bit per island, vertex shader), then rayNear per pixel.
// Needs pointGlow/innerGlow/softDepth (fx_common), rayNear/raySegment (arena).
const int IS_GEODE = 0, IS_SHIP = 1, IS_CHERRY = 2, IS_RUIN = 3, IS_WHALE = 4, IS_TREE = 5, IS_GATE = 6, IS_SHROOM = 7, IS_STARS = 8;
const vec4 ISLE[9] = vec4[9](vec4(-63.5, 110.0, -531.5, 31.0), vec4(66.5, 130.0, -533.5, 32.0), vec4(-66.5, 110.0, -369.5, 36.0), vec4(69.5, 102.0, -384.5, 34.0),
    vec4(88.5, 135.5, -333.5, 38.0), vec4(-111.5, 126.0, -561.5, 32.0), vec4(113.5, 114.0, -557.5, 28.0), vec4(49.5, 94.0, -503.5, 23.0), vec4(-113.5, 99.0, -390.5, 25.0));
const vec3 ISLE_TINT[9] = vec3[9](vec3(0.72, 0.38, 1.0), vec3(1.0, 0.62, 0.35), vec3(1.0, 0.55, 0.78), vec3(0.45, 0.85, 1.0),
    vec3(0.35, 0.70, 1.0), vec3(0.45, 1.0, 0.55), vec3(0.85, 0.35, 1.0), vec3(0.20, 0.95, 0.85), vec3(1.0, 0.85, 0.45));

#ifdef ISLES_VERTEX
// One bit per island that may be in view (in front of the camera and not too far)
int islesVisible(mat4 view, vec3 cam) {
    int seen = 0;
    for (int i = 0; i < 9; i++) {
        vec3 v = (view * vec4(ISLE[i].xyz - cam, 0.0)).xyz;
        if (v.z < ISLE[i].w && length(v) < 300.0) seen |= 1 << i;
    }
    return seen;
}
#else
float isleNoise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), f.x), mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), f.x), f.y);
}

// Veins of light climbing the rock, every island with its own rhythm; sparks on top
vec3 isleVeins(int i, vec3 wp, vec3 nW, float t) {
    vec3 g = floor((wp - nW * 0.03) * 16.0) / 16.0;
    float fi = float(i);
    if (abs(nW.y) < 0.6) {
        float side = abs(nW.x) > 0.5 ? g.z : g.x;
        float warp = isleNoise(vec2(side * 0.22 + fi * 7.0, g.y * 0.16)) * 3.2 + isleNoise(vec2(side * 0.7, g.y * 0.5 + fi)) * 0.8;
        float w = abs(fract(side * 0.11 + warp) - 0.5);
        float line = smoothstep(0.045, 0.0, w), soft = exp(-w * 14.0);
        float pulse = pow(0.5 + 0.5 * sin(g.y * 0.42 - t * (0.9 + 0.13 * fi) + warp * 1.7), 3.0);
        return ISLE_TINT[i] * (line * 0.55 + soft * 0.14) * (0.12 + 0.88 * pulse);
    }
    if (nW.y > 0.6) {
        vec2 c = floor(g.xz * 4.0);
        float h = hash12(c + fi * 31.0);
        return h > 0.972 ? ISLE_TINT[i] * pow(0.5 + 0.5 * sin(t * (1.0 + h * 2.0) + h * 700.0), 6.0) * 0.8 : vec3(0.0);
    }
    return vec3(0.0);
}

// Frozen falls flow: streaks, foam and a soft shine
vec3 isleFall(vec3 wp, vec3 nW, vec2 c, vec2 halfSize, float top, float len, float t) {
    vec2 d = abs(wp.xz - c);
    if (d.x > halfSize.x || d.y > halfSize.y || wp.y > top + 1.2 || wp.y < top - len || nW.y < -0.6) return vec3(0.0);
    vec3 g = floor((wp - nW * 0.03) * 16.0) / 16.0;
    float down = top - g.y, side = g.z + g.x * 0.6;
    float a = isleNoise(vec2(side * 2.6, down * 0.32 - t * 1.9)), b = isleNoise(vec2(side * 5.5 + 9.0, down * 0.75 - t * 3.4));
    float streak = smoothstep(0.52, 0.9, a * 0.65 + b * 0.5);
    float foam = smoothstep(0.75, 1.0, b) * 0.5;
    return (vec3(0.25, 0.65, 1.0) * (0.10 + streak * 0.60) + vec3(0.9, 0.97, 1.0) * (streak * streak * 0.45 + foam)) * (1.0 - smoothstep(len * 0.45, len, down));
}

// Little spirits on lopsided paths
vec3 isleSpirits(int i, vec3 camW, vec3 dir, float sceneDist, float t) {
    vec3 col = vec3(0.0);
    float fi = float(i);
    for (int k = 0; k < 3; k++) {
        float fk = float(k), w = t * (0.16 + 0.07 * fk + 0.013 * fi) + fi * 1.9 + fk * 2.3;
        float r = ISLE[i].w * (0.42 + 0.13 * fk + 0.06 * sin(w * 1.7));
        vec3 p = ISLE[i].xyz + vec3(cos(w) * r, (fk - 0.6) * 5.5 + 3.5 * sin(w * 2.3 + fi), sin(w) * r * (0.75 + 0.2 * sin(fi)));
        float blink = 0.6 + 0.4 * sin(t * 3.1 + fk * 2.0 + fi);
        col += mix(ISLE_TINT[i], vec3(1.0), 0.35) * pointGlow(p, camW, dir, sceneDist, 0.20) * 1.2 * blink + ISLE_TINT[i] * pointGlow(p, camW, dir, sceneDist, 1.3) * 0.16 * blink;
    }
    return col;
}

// Threads of light between neighbouring islands
vec3 isleLink(vec3 a, vec3 b, float sag, vec3 ta, vec3 tb, float seed, vec3 camW, vec3 dir, float sceneDist, float t) {
    vec3 mid = (a + b) * 0.5;
    if (!rayNear(mid - vec3(0.0, sag * 0.25, 0.0), length(b - a) * 0.5 + abs(sag) * 0.3 + 2.0, camW, dir, sceneDist)) return vec3(0.0);
    vec3 ctrl = mid + vec3(4.0 * sin(t * 0.3 + seed), -sag + sin(t * 0.5 + seed * 2.0), 4.0 * cos(t * 0.23 + seed)), p = a, col = vec3(0.0);
    for (int k = 1; k <= 6; k++) {
        float u = float(k) / 6.0;
        vec3 q = mix(mix(a, ctrl, u), mix(ctrl, b, u), u), seg = raySegment(p, q, camW, dir);
        if (seg.z > 0.0 && seg.z < sceneDist && seg.x < 2.2) {
            float at = (float(k - 1) + seg.y) / 6.0, run = pow(fract(at * 2.0 - t * 0.22 + seed), 9.0);
            col = max(col, mix(ta, tb, at) * (exp(-seg.x * seg.x / 0.02) * (0.10 + run * 1.3) + exp(-seg.x * seg.x / 0.6) * (0.03 + run * 0.28)));
        }
        p = q;
    }
    return col;
}

// Moon gate: a film of stars in the broken ring
vec3 isleGate(vec3 camW, vec3 dir, float sceneDist, float t) {
    const float yaw = 0.62;
    vec3 c = vec3(113.5, 118.5, -557.5), u = vec3(cos(yaw), 0.0, sin(yaw)), n = vec3(-sin(yaw), 0.0, cos(yaw));
    float dn = dot(dir, n);
    if (abs(dn) < 1e-3) return vec3(0.0);
    float s = dot(c - camW, n) / dn;
    if (s < 0.0 || s > sceneDist) return vec3(0.0);
    vec3 p = camW + dir * s - c;
    vec2 q = vec2(dot(p, u), p.y);
    float r = length(q);
    if (r > 9.4) return vec3(0.0);
    vec2 g = floor(q * 8.0) / 8.0;
    float a = atan(g.y, g.x), rr = length(g);
    float swirl = isleNoise(vec2(a * 1.6 + rr * 0.55 - t * 0.35, rr * 0.5 - t * 0.12)) * 0.6 + isleNoise(vec2(a * 3.2 - rr * 0.9 + t * 0.2, rr * 0.9)) * 0.4;
    float star = step(0.985, hash12(floor(q * 4.0) + 5.0)) * pow(0.5 + 0.5 * sin(t * 2.0 + hash12(floor(q * 4.0)) * 60.0), 4.0);
    vec3 tint = mix(vec3(0.25, 0.10, 0.75), vec3(1.0, 0.40, 0.95), swirl);
    float edge = smoothstep(9.4, 8.8, r);
    return (tint * (0.05 + 0.38 * swirl * swirl) + vec3(1.0, 0.9, 1.0) * star * 0.9 + vec3(0.85, 0.35, 1.0) * exp(-pow((r - 9.0) / 0.35, 2.0)) * 0.35) * edge;
}

// Whale: light bands wandering along the body, stardust behind the tail
const vec3 WHALE_DIR = vec3(-0.6223, 0.0, -0.7828);
vec3 isleWhaleSkin(vec3 wp, vec3 nW, float t) {
    vec3 g = floor((wp - nW * 0.03) * 8.0) / 8.0 - ISLE[IS_WHALE].xyz;
    float l = dot(g, WHALE_DIR), w = g.x * 0.7828 - g.z * 0.6223;
    if (abs(l) > 27.0 || length(g) > 28.0) return vec3(0.0);
    float band = pow(0.5 + 0.5 * sin(l * 0.55 + t * 1.3 + 0.35 * abs(w) + 0.6 * g.y), 8.0);
    float spot = step(0.93, hash12(floor(vec2(l, g.y + w * 0.7) * 2.0))) * (0.5 + 0.5 * sin(t * 1.5 + l * 0.8));
    return vec3(0.25, 0.75, 1.0) * band * 0.38 + vec3(0.6, 1.0, 0.95) * spot * 0.5;
}
vec3 isleWhaleDust(vec3 camW, vec3 dir, float sceneDist, float t) {
    vec3 col = vec3(0.0), back = -WHALE_DIR, side = vec3(0.7828, 0.0, -0.6223);
    for (int k = 0; k < 9; k++) {
        float fk = float(k), u = fract(fk * 0.111 + t * 0.06), w = fk * 2.4;
        vec3 p = ISLE[IS_WHALE].xyz + back * (18.0 + u * 20.0) + side * sin(w + t * 0.4) * (2.0 + 5.0 * u) + vec3(0.0, -1.5 + cos(w * 1.3 + t * 0.5) * (1.5 + 3.0 * u), 0.0);
        col += mix(vec3(0.8, 1.0, 1.0), vec3(0.45, 0.45, 1.0), u) * (pointGlow(p, camW, dir, sceneDist, 0.22) * 1.1 + pointGlow(p, camW, dir, sceneDist, 1.4) * 0.12) * (1.0 - u) * smoothstep(0.0, 0.1, u);
    }
    return col;
}

// The wonder of each island
vec3 isleMagic(int i, vec3 camW, vec3 dir, float sceneDist, bool surf, vec3 wp, vec3 nW, float t) {
    vec3 c = ISLE[i].xyz, col = vec3(0.0);
    if (i == IS_GEODE) {                                                   // heartbeat running up the giant crystals
        float beat = pow(0.5 + 0.5 * sin(t * 1.1), 4.0);
        vec3 seg = raySegment(vec3(-65.5, 109.0, -530.5), vec3(-60.8, 130.0, -533.7), camW, dir);
        if (seg.z > 0.0 && seg.x < 8.0) col += vec3(0.75, 0.40, 1.0) * exp(-seg.x * seg.x / 7.0) * (0.06 + 0.20 * exp(-pow((seg.y - fract(t * 0.35) * 1.3) / 0.14, 2.0)) + 0.06 * beat) * softDepth(seg.z, sceneDist, 5.0);
    } else if (i == IS_SHIP) {                                             // the burner warms the balloon
        float fire = 0.75 + 0.25 * sin(t * 6.0 + sin(t * 2.3) * 3.0);
        col += vec3(1.0, 0.55, 0.22) * innerGlow(vec3(66.5, 137.0, -533.5), camW, dir, sceneDist, 8.5, 9.0) * 0.20 * fire;
        if (surf) { vec3 p = wp - vec3(66.5, 139.5, -533.5); if (abs(p.y) < 9.0 && length(p.xz) < 20.0) col += vec3(1.0, 0.6, 0.3) * 0.16 * fire * smoothstep(9.0, -8.0, p.y); }
    } else if (i == IS_WHALE) {
        if (surf) col += isleWhaleSkin(wp, nW, t);
        col += isleWhaleDust(camW, dir, sceneDist, t);
    } else if (i == IS_GATE) col += isleGate(camW, dir, sceneDist, t);
    else if (i == IS_STARS) {                                              // the telescope sweeps the sky
        vec3 a = vec3(-105.5, 111.5, -390.0), d = normalize(vec3(1.0, 0.72, 0.35 * sin(t * 0.21))), seg = raySegment(a, a + d * 70.0, camW, dir);
        float r = 0.35 + seg.y * 2.6;
        if (seg.z > 0.0 && seg.z < sceneDist && seg.x < r * 3.0) col += vec3(1.0, 0.9, 0.6) * exp(-seg.x * seg.x / (r * r)) * 0.22 * pow(1.0 - seg.y, 1.6);
        col += vec3(1.0, 0.92, 0.7) * pointGlow(a, camW, dir, sceneDist, 1.4) * 0.7;
    } else {                                                               // cherry petals, snow, leaves and spores drift down or up
        float up = i == IS_SHROOM ? 1.0 : -1.0;
        for (int k = 0; k < 7; k++) {
            float fk = float(k), u = fract(fk * 0.143 + t * (0.035 + 0.006 * fk)), w = fk * 2.1 + float(i);
            vec3 p = c + vec3(cos(w + t * 0.15) * ISLE[i].w * (0.15 + 0.065 * fk) + sin(t * 0.7 + w) * 1.5, up * (u - 0.5) * 30.0 + 4.0, sin(w * 1.7 + t * 0.12) * ISLE[i].w * (0.15 + 0.06 * fk));
            col += mix(ISLE_TINT[i], vec3(1.0), 0.4) * pointGlow(p, camW, dir, sceneDist, 0.17) * 0.9 * sin(u * 3.1416);
        }
    }
    return col;
}

vec3 isles(vec3 camW, vec3 dir, float sceneDist, bool surf, vec3 wp, vec3 nW, float t) {
    vec3 col = vec3(0.0);
    for (int i = 0; i < 9; i++) {
        if ((islesSeen >> i & 1) == 0 || !rayNear(ISLE[i].xyz, ISLE[i].w, camW, dir, sceneDist)) continue;
        bool here = surf && dot(wp - ISLE[i].xyz, wp - ISLE[i].xyz) < ISLE[i].w * ISLE[i].w;
#ifdef FX_ISLES_VEINS
        if (here && i != IS_WHALE && !(i == IS_SHIP && wp.y > 116.0)) col += isleVeins(i, wp, nW, t);
#endif
#ifdef FX_ISLES_FALLS
        if (here && i == IS_CHERRY) col += isleFall(wp, nW, vec2(-51.5, -375.5), vec2(4.0, 2.6), 115.0, 31.0, t);
        if (here && i == IS_RUIN) col += isleFall(wp, nW, vec2(54.5, -386.5), vec2(2.6, 2.6), 102.0, 27.0, t);
#endif
#ifdef FX_ISLES_SPIRITS
        col += isleSpirits(i, camW, dir, sceneDist, t);
#endif
#ifdef FX_ISLES_GLOW
        col += ISLE_TINT[i] * innerGlow(ISLE[i].xyz - vec3(0.0, ISLE[i].w * 0.42, 0.0), camW, dir, sceneDist, ISLE[i].w * 0.40, 12.0) * (0.10 + 0.03 * sin(t * 0.6 + float(i) * 1.7));
#endif
#ifdef FX_ISLES_MAGIC
        col += isleMagic(i, camW, dir, sceneDist, surf, wp, nW, t);
#endif
    }
#ifdef FX_ISLES_LINKS
    if ((islesSeen & 33) != 0) col += isleLink(ISLE[0].xyz + vec3(-10.0, -2.0, -4.0), ISLE[5].xyz + vec3(9.0, -6.0, 5.0), 9.0, ISLE_TINT[0], ISLE_TINT[5], 0.1, camW, dir, sceneDist, t);
    if ((islesSeen & 66) != 0) col += isleLink(vec3(70.0, 121.0, -518.0), ISLE[6].xyz + vec3(-7.0, -7.0, 4.0), 13.0, ISLE_TINT[1], ISLE_TINT[6], 0.4, camW, dir, sceneDist, t);
    if ((islesSeen & 130) != 0) col += isleLink(ISLE[7].xyz + vec3(0.0, 10.0, -2.0), vec3(72.0, 106.0, -529.0), -6.0, ISLE_TINT[7], ISLE_TINT[1], 0.7, camW, dir, sceneDist, t);
    if ((islesSeen & 260) != 0) col += isleLink(ISLE[2].xyz + vec3(-11.0, 3.0, -6.0), ISLE[8].xyz + vec3(5.0, 8.0, 4.0), 11.0, ISLE_TINT[2], ISLE_TINT[8], 0.25, camW, dir, sceneDist, t);
    if ((islesSeen & 24) != 0) col += isleLink(ISLE[3].xyz + vec3(2.0, 12.0, 3.0), ISLE[4].xyz + vec3(-4.0, -7.0, -6.0), -7.0, ISLE_TINT[3], ISLE_TINT[4], 0.55, camW, dir, sceneDist, t);
#endif
    return col;
}
#endif
