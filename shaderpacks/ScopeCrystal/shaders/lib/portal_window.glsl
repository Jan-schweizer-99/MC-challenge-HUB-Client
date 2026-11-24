// Spatial preview of the opposite arena's static blocks, inside the crystal shaft.
// Geometry mirrors Arena.java (Y=100, radius=26, crystalLayout); no previous images.
#include "/lib/arena_materials.glsl"

int portalBlockRole(ivec3 b) {
    ivec2 p = b.xz;
    float r = length(vec2(p));
    if (b.y == 103 && p == ivec2(0)) return 12;  // luminous beacon core
    if (b.y == 102 && all(lessThanEqual(abs(p), ivec2(2))))
        return all(lessThanEqual(abs(p), ivec2(1))) ? 11 : 10;
    if (b.y == 101 && dot(vec2(p), vec2(p)) <= 18.0)
        return any(equal(abs(p), ivec2(4))) ? 9 : 0;

    // Same single-layer closed frame as Arena.java crystalLayout().
    if (b.y == 109 && max(abs(b.x), abs(b.z)) == 3) {
        bool corner = abs(b.x) == 3 && abs(b.z) == 3;
        return corner ? 7 : (b.x + b.z) % 3 == 0 ? 6 : 5;
    }
    // Four diagonal cover columns (round(cos(45 degrees) * 13) = 9).
    ivec2 column = ivec2(p.x >= 0 ? 9 : -9, p.y >= 0 ? 9 : -9);
    ivec2 delta = p - column;
    if (all(greaterThanEqual(delta, ivec2(0))) && all(lessThanEqual(delta, ivec2(1)))) {
        if (b.y >= 101 && b.y <= 103) return 2;
        if (b.y == 104) return 6;
        if (b.y == 105 && all(equal(delta, ivec2(0)))) return 2;
        if (b.y == 105 && all(equal(delta, ivec2(1)))) return 5;
    }
    // Low cover on the four axes.
    bool wall = (abs(b.x) == 9 && abs(b.z) <= 2) || (abs(b.z) == 9 && abs(b.x) <= 2);
    if (wall && b.y == 101) return 9;
    if (wall && b.y == 102) return min(abs(b.x), abs(b.z)) == 2 ? 8 : 5;
    if (r > 26.0 && r <= 27.5 && b.y >= 100 && b.y <= 106) {
        float deg = degrees(atan(float(b.z), float(b.x))) + 180.0;
        bool pillar = abs(floor(deg / 11.25 + 0.5) * 11.25 - deg) < 1.8;
        if (pillar) return 8;
        if (b.y <= 101 || b.y == 106) return 9;
        return (b.y + int(deg / 11.25)) % 3 == 0 ? 6 : 5;
    }
    if (r > 27.5 && r <= 34.0) {
        int row = int(r - 27.5);
        int top = 107 + row;
        if (b.y >= 100 && b.y <= top) return row % 2 == 0 && b.y == top ? 0 : 1;
        if (row % 2 == 0 && b.y == top + 1) {
            float deg = degrees(atan(float(b.z), float(b.x))) + 180.0;
            return int(deg / 7.5) % 2 == 0 ? 16 : 15;
        }
    }
    if (b.y != 100 || r > 26.0) return -1;
    if ((abs(b.x) == 15 && b.z == 0) || (abs(b.z) == 15 && b.x == 0)) return 12;
    float angle = atan(float(b.z), float(b.x));
    if (r >= 19.0 && r < 20.5) return 4;
    if (abs(sin(4.0 * angle)) < 0.09 && r > 5.0 && r < 25.0) return 5;
    if (int(r) % 6 == 0) return 2;
    if ((b.x * 7 + b.z * 13) % 23 == 0 && r > 6.0) return 3;
    return (int((degrees(angle) + 180.0) / 15.0) + int(r / 3.0)) % 2 == 0 ? 0 : 1;
}

vec3 portalFloorColor(vec3 hit, int side, int level, float t) {
    float r = length(hit.xz - vec2(0.5));
    float ringDist = min(min(abs(r - 6.5), abs(r - 12.5)), min(abs(r - 18.5), abs(r - 24.5)));
    float trench = smoothstep(18.96, 19.04, r) * (1.0 - smoothstep(20.46, 20.54, r));
    float ring = (1.0 - smoothstep(0.46, 0.54, ringDist)) * (1.0 - trench);
    ivec2 block = ivec2(floor(hit.xz));
    float angle = degrees(atan(float(block.y), float(block.x))) + 180.0;
    int stoneRole = (int(angle / 15.0) + int(length(vec2(block)) / 3.0)) % 2;
    vec3 stone = arenaSideTexture(stoneRole, side, hit.xz, level, t).rgb;
    vec3 magma = arenaSideTexture(2, side, hit.xz, level, t).rgb;
    vec3 lava = arenaSideTexture(4, side, hit.xz, level, t).rgb;
    return stone * (1.0 - ring - trench) * 0.8 + magma * ring + lava * trench;
}

vec3 portalTrace(vec3 origin, vec3 direction, int side, int level, float t) {
    vec3 ray = mix(vec3(-1.0), vec3(1.0), step(vec3(0.0), direction)) * max(abs(direction), vec3(1e-5));
    vec3 inv = 1.0 / ray;
    ivec3 cell = ivec3(floor(origin));
    ivec3 advance = ivec3(sign(ray));
    vec3 next = (vec3(cell) + step(vec3(0.0), ray) - origin) * inv;
    vec3 stride = abs(inv);
    vec3 normal = vec3(0.0, -sign(ray.y), 0.0);
    vec3 sum = vec3(0.0);
    float transmission = 1.0;
    float distance = 0.0;
    for (int i = 0; i < 80; i++) {
        if (cell.y < 100 || cell.y > 117 || any(greaterThan(abs(cell.xz), ivec2(36))) || distance > 48.0) break;
        int role = portalBlockRole(cell);
        if (role >= 0) {
            vec3 hit = origin + ray * (distance + 0.001);
            vec2 uv = abs(normal.y) > 0.5 ? hit.xz : abs(normal.x) > 0.5 ? vec2(hit.z, -hit.y) : vec2(hit.x, -hit.y);
            int texRole = role == 8 && abs(normal.y) > 0.5 ? 17 : role;
            vec3 tex = arenaSideTexture(texRole, side, uv, level, t).rgb;
            bool glass = role >= 5 && role <= 7;
            if (cell.y == 100 && (role == 0 || role == 1 || role == 2 || role == 4)) {
                tex = portalFloorColor(hit, side, level, t);
                glass = false;
            }
            float shade = 0.55 + 0.35 * max(normal.y, 0.0) + 0.1 * abs(normal.z);
            if (role == 3 || role == 12 || (side == 1 && (role == 2 || role == 4))) shade = 1.15;
            if (glass) {
                sum += tex * transmission * 0.24;
                transmission *= 0.76;
            } else return sum + tex * shade * transmission;
        }
        if (next.x <= next.y && next.x <= next.z) {
            distance = next.x; next.x += stride.x; cell.x += advance.x;
            normal = vec3(-float(advance.x), 0.0, 0.0);
        } else if (next.y <= next.z) {
            distance = next.y; next.y += stride.y; cell.y += advance.y;
            normal = vec3(0.0, -float(advance.y), 0.0);
        } else {
            distance = next.z; next.z += stride.z; cell.z += advance.z;
            normal = vec3(0.0, 0.0, -float(advance.z));
        }
    }
    vec3 sky = side == 1 ? vec3(0.055, 0.012, 0.025) : vec3(0.025, 0.055, 0.12);
    return sum + sky * transmission;
}

// One horizontal, zero-thickness surface, front normal +Y.
// The underside is deliberately culled; no side faces or volume are rendered.
vec4 crystalOpeningPortal(vec3 camW, vec3 direction, float sceneDist, float t) {
    const float planeY = 110.0;
    const float halfSize = 2.5;
    if (!arenaPaletteRegion(camW) || camW.y <= planeY + 0.002 || direction.y >= -1e-5)
        return vec4(0.0, 0.0, 0.0, 0.0);
    float travel = (planeY - camW.y) / direction.y;
    if (travel <= 0.002 || travel > sceneDist + 0.06) return vec4(0.0, 0.0, 0.0, 0.0);
    vec3 entry = arenaLocal(camW) + direction * travel;
    vec2 q = abs(entry.xz - vec2(0.5));
    if (max(q.x, q.y) >= halfSize) return vec4(0.0, 0.0, 0.0, 0.0);
    int target = camW.x > TWIN_SPLIT ? 0 : 1;
    vec3 color = portalTrace(entry + direction * 0.005, direction, target, arenaTextureLevel(entry.xz), t);
    // Native-pixel seam connects the plane directly to the block frame.
    float edge = halfSize - max(q.x, q.y);
    vec3 rim = target == 1 ? vec3(0.55, 0.9, 1.15) : vec3(1.05, 0.45, 0.12);
    color = mix(color, rim, edge < 0.0625 ? 0.4 : 0.0);
    return vec4(color, 1.0);
}
