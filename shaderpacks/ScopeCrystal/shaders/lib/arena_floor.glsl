#include "/lib/arena_materials.glsl"
bool arenaFloorSurface(vec3 wp, vec3 nW) {
    return nW.y > 0.9 && abs(wp.y - 101.0) < 0.05
        && length(arenaLocal(wp).xz - vec2(0.5)) < 25.9;
}
vec3 roundArenaFloor(vec3 wp, vec3 tint, vec3 light, float t) {
    vec2 tile = arenaLocal(wp).xz;
    float r = length(tile - vec2(0.5));
    float fw = max(fwidth(r), 1e-3);
    float ringDist = min(min(abs(r - 6.5), abs(r - 12.5)), min(abs(r - 18.5), abs(r - 24.5)));
    float trench = smoothstep(19.0 - fw, 19.0 + fw, r) * (1.0 - smoothstep(20.5 - fw, 20.5 + fw, r));
    float ring = (1.0 - smoothstep(0.5 - fw, 0.5 + fw, ringDist)) * (1.0 - trench);
    float stone = 1.0 - ring - trench;
    int level = arenaTextureLevel(tile);
    int side = arenaSideAt(wp);
    float blend = side == 1 ? 1.0 : 0.0;
    float glow = side == 2 ? 0.45 + 0.15 * sin(t * 1.4 + r) : blend;   // crying obsidian glows softly
    vec3 color = vec3(0.0);
    if (stone > 0.0) {
        vec2 block = floor(tile);
        float deg = degrees(atan(block.y, block.x)) + 180.0;
        int role = int(mod(floor(deg / 15.0) + floor(length(block) / 3.0), 2.0));
        color += arenaSideTexture(role, side, tile, level, t).rgb * light * stone;
    }
    if (ring > 0.0) color += arenaSideTexture(2, side, tile, level, t).rgb
        * mix(light, max(light, vec3(0.35)), blend) * ring;
    if (trench > 0.0) color += arenaSideTexture(4, side, tile, level, t).rgb
        * mix(light, vec3(1.0), glow) * trench;
    return color * tint;
}
