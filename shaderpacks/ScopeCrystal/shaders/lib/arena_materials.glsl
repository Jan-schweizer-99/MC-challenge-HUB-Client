#ifndef ARENA_MATERIALS_GLSL
#define ARENA_MATERIALS_GLSL
uniform sampler2D arenaPaletteAtlas;
float arenaBlendWeight() { return smoothstep(0.02, 0.98, arenaLavaMix); }
vec3 arenaLocal(vec3 p) { p.x -= arenaOffsetX(arenaSideAt(p)); return p; }
bool arenaPaletteRegion(vec3 p) {
    p = arenaLocal(p);
    return length(p.xz - vec2(0.5)) < 90.0 && abs(p.y - 101.0) < 70.0;
}
bool arenaPaletteChanging(vec3 p) { return false; }

int arenaTextureLevel(vec2 uv) {
    float footprint = max(length(dFdx(uv)), length(dFdy(uv))) * 16.0;
    return int(clamp(floor(log2(max(footprint, 1.0))), 0.0, 4.0));
}
vec4 arenaTexel(int role, int side, int frame, vec2 uv, int level) {
    int size = 16 >> level;
    int offset = 32 - (32 >> level);
    ivec2 pixel = ivec2(floor(fract(uv) * float(size)));
    return texelFetch(arenaPaletteAtlas, ivec2((side == 2 ? 36 + role : role * 2 + side) * 32 + offset, frame * 16) + pixel, 0);
}
vec4 arenaSideTexture(int role, int side, vec2 uv, int level, float t) {
    if (side == 1 && role == 2) {
        float phase = mod(t * 2.5, 3.0);
        int frame = int(floor(phase));
        return mix(arenaTexel(role, side, frame, uv, level), arenaTexel(role, side, (frame + 1) % 3, uv, level), fract(phase));
    }
    if (side == 1 && role == 4) {
        int phase = int(mod(floor(t * 10.0), 38.0));
        return arenaTexel(role, side, phase <= 19 ? phase : 38 - phase, uv, level);
    }
    return arenaTexel(role, side, 0, uv, level);
}
vec4 arenaPairedTexture(int role, vec2 uv, int level, float t) {
    float blend = arenaBlendWeight();
    if (blend <= 0.0) return arenaSideTexture(role, 0, uv, level, t);
    if (blend >= 1.0) return arenaSideTexture(role, 1, uv, level, t);
    return mix(arenaSideTexture(role, 0, uv, level, t), arenaSideTexture(role, 1, uv, level, t), blend);
}
#endif
