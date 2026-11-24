// Round lava-arena floor, using original 16x16 block pixels and animation frames.
uniform sampler2D lavaFloorAtlas;

bool lavaArenaFloor(vec3 wp, vec3 nW) {
    return nW.y > 0.9 && abs(wp.y - 101.0) < 0.05
        && length(wp.xz - vec2(TWIN_X + 0.5, 0.5)) < 25.9;
}

vec3 lavaFloorTex(int material, int frame, vec2 p, int level) {
    int size = 16 >> level;
    int offset = 32 - (32 >> level);
    ivec2 pixel = ivec2(floor(fract(p) * float(size)));
    return texelFetch(lavaFloorAtlas, ivec2(material * 32 + offset, frame * 16) + pixel, 0).rgb;
}

vec3 roundLavaFloor(vec3 wp, vec3 tint, vec3 light, float t) {
    vec2 p = wp.xz - vec2(TWIN_X + 0.5, 0.5);
    float r = length(p);
    float fw = max(fwidth(r), 1e-3);
    float ringDist = min(min(abs(r - 6.5), abs(r - 12.5)), min(abs(r - 18.5), abs(r - 24.5)));
    float lava = smoothstep(19.0 - fw, 19.0 + fw, r) * (1.0 - smoothstep(20.5 - fw, 20.5 + fw, r));
    float magma = (1.0 - smoothstep(0.5 - fw, 0.5 + fw, ringDist)) * (1.0 - lava);
    float stone = 1.0 - magma - lava;

    // Select a prefiltered mip without atlas bleeding; nearby pixels stay crisp.
    vec2 tile = wp.xz - vec2(TWIN_X, 0.0);
    float footprint = max(length(dFdx(tile)), length(dFdy(tile))) * 16.0;
    int level = int(clamp(floor(log2(max(footprint, 1.0))), 0.0, 4.0));
    vec3 color = vec3(0.0);
    if (stone > 0.0) {
        // Same alternating stone palette as Arena.java, measured at block centers.
        vec2 block = floor(tile);
        float blockR = length(block);
        float deg = degrees(atan(block.y, block.x)) + 180.0;
        int material = int(mod(floor(deg / 15.0) + floor(blockR / 3.0), 2.0));
        color += lavaFloorTex(material, 0, tile, level) * light * stone;
    }
    if (magma > 0.0) {
        float phase = mod(t * 2.5, 3.0);
        int frame = int(floor(phase));
        vec3 tex = mix(lavaFloorTex(2, frame, tile, level), lavaFloorTex(2, (frame + 1) % 3, tile, level), fract(phase));
        color += tex * max(light, vec3(0.35)) * magma;
    }
    if (lava > 0.0) {
        int phase = int(mod(floor(t * 10.0), 38.0));
        int frame = phase <= 19 ? phase : 38 - phase;
        color += lavaFloorTex(3, frame, tile, level) * lava;
    }
    return color * tint;
}
