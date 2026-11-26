// VR cursor of the Scopemods mod, drawn in the final pass over everything (glass, water, clouds), once per eye.
// The mod writes a 64x1 RGBA8 texture every picture (scope_shadermenu:dynamic/vr_cursor):
//   0  flags (r: 1 trail, 2 arrow, 4 active), point count (g), opacity (b)
//   1..3  colours glow, middle, core (rgb)
//   4  trail width mm (r), head size in fiftieths of the width (g), arrow half size mm (b)
//   5  arrow angles in thirds of a degree: up/down (r), sides (g), shows from (b)
//   6..8  reference position x, y, z as signed 32 bit, 1/256 m (rgba = bytes, big end first)
//   16.. two texels per point: x, y (hi, lo) | z (hi, lo), fade; signed 16 bit, 1/1024 m from the reference
// The arrow picture is the same pixel art as in the mod (textures/vr-arrow.png), tinted like there.

#define VR_CURSOR // VR cursor of the Scopemods mod drawn by the shader, over glass and clouds

#ifdef VR_CURSOR

uniform sampler2D vrCursorData;
uniform sampler2D vrArrowTex;
uniform mat4 gbufferModelView;
uniform mat4 gbufferProjection;
uniform vec3 cameraPosition;
uniform float viewWidth;
uniform float viewHeight;

const int VRC_MAX = 24;

vec4 vrcTexel(int i) { return texelFetch(vrCursorData, ivec2(i, 0), 0); }
ivec4 vrcBytes(int i) { return ivec4(round(vrcTexel(i) * 255.0)); }

float vrcInt32(int i) {
    ivec4 b = vrcBytes(i);
    int v = (b.r << 24) | (b.g << 16) | (b.b << 8) | b.a;          // two's complement in 32 bit
    return float(v);
}

float vrcInt16(int hi, int lo) {
    int v = hi * 256 + lo;
    if (v >= 32768) v -= 65536;
    return float(v);
}

// screen position in pixels (xy), view depth (z, negative in front), pixels per metre at that depth (w)
vec4 vrcProject(vec3 world) {
    vec4 view = gbufferModelView * vec4(world - cameraPosition, 1.0);
    vec4 clip = gbufferProjection * view;
    vec2 px = (clip.xy / clip.w * 0.5 + 0.5) * vec2(viewWidth, viewHeight);
    return vec4(px, view.z, gbufferProjection[1][1] * 0.5 * viewHeight / max(-view.z, 0.01));
}

vec3 vrcColor(int i) { return vrcTexel(i).rgb; }

// soft band: 0 outside, 1 in the core
vec4 vrcShade(float d, float fade, vec3 glow, vec3 mid, vec3 core) {
    float glowA = (1.0 - smoothstep(0.0, 1.0, d)) * 0.35;
    float midA = (1.0 - smoothstep(0.45, 0.65, d)) * 0.45;
    float coreA = 1.0 - smoothstep(0.22, 0.32, d);
    vec3 c = mix(mix(glow, mid, midA / max(glowA + midA, 1e-4)), core, coreA);
    float a = clamp(max(max(glowA, midA), coreA * 0.95), 0.0, 1.0) * (0.15 + 0.85 * fade);
    return vec4(c, a);
}

vec3 vrcTint(float l, vec3 glow, vec3 mid, vec3 core) {
    vec3 dark = glow * 0.35;
    if (l < 0.25) return dark;
    if (l < 0.55) return mix(dark, glow, (l - 0.25) / 0.3);
    if (l < 0.85) return mix(glow, mid, (l - 0.55) / 0.3);
    return mix(mid, core, min(1.0, (l - 0.85) / 0.15));
}

vec3 vrCursor(vec3 color) {
    ivec4 head = vrcBytes(0);
    if ((head.r & 4) == 0) return color;
    int n = min(head.g, VRC_MAX);
    float opacity = float(head.b) / 255.0;
    vec3 glow = vrcColor(1), mid = vrcColor(2), core = vrcColor(3);
    ivec4 p4 = vrcBytes(4), p5 = vrcBytes(5);
    float widthM = float(p4.r) / 1000.0, headSize = float(p4.g) / 50.0, arrowHalf = float(p4.b) / 1000.0;
    vec3 ref = vec3(vrcInt32(6), vrcInt32(7), vrcInt32(8)) / 256.0;
    vec2 frag = gl_FragCoord.xy;

    // ---- trail: distance of this pixel to the band through the points (screen space)
    if ((head.r & 1) != 0 && n >= 1) {
        vec4 best = vec4(0.0);
        vec4 prev = vec4(0.0);
        float prevFade = 0.0;
        for (int i = 0; i < VRC_MAX; i++) {
            if (i >= n) break;
            ivec4 a = vrcBytes(16 + i * 2), b = vrcBytes(17 + i * 2);
            vec3 w = ref + vec3(vrcInt16(a.r, a.g), vrcInt16(a.b, a.a), vrcInt16(b.r, b.g)) / 1024.0;
            float fade = float(b.b) / 255.0;
            vec4 cur = vrcProject(w);
            if (i > 0 && prev.z < -0.05 && cur.z < -0.05) {
                vec2 s = cur.xy - prev.xy;
                float t = clamp(dot(frag - prev.xy, s) / max(dot(s, s), 1e-4), 0.0, 1.0);
                float f = mix(prevFade, fade, t);
                float halfPx = widthM * mix(prev.w, cur.w, t) * (0.25 + 0.75 * f);
                float d = length(frag - (prev.xy + s * t)) / max(halfPx, 0.75);
                if (d < 1.0) { vec4 sh = vrcShade(d, f, glow, mid, core); if (sh.a > best.a) best = sh; }
            }
            prev = cur; prevFade = fade;
        }
        // round head at the newest point
        if (headSize > 0.01 && prev.z < -0.05) {
            float d = length(frag - prev.xy) / max(widthM * prev.w * headSize, 0.75);
            if (d < 1.0) {
                float coreA = 1.0 - smoothstep(0.45, 0.55, d);
                vec4 sh = vec4(mix(mid, core, coreA), max(0.4 * (1.0 - d), coreA * 0.95));
                if (sh.a > best.a) best = sh;
            }
        }
        color = mix(color, best.rgb, best.a * opacity);
    }

    // ---- arrow: near the edge of the view, pointing to the cursor when it is outside
    if ((head.r & 2) != 0 && n >= 1) {
        ivec4 a = vrcBytes(16 + (n - 1) * 2), b = vrcBytes(17 + (n - 1) * 2);
        vec3 w = ref + vec3(vrcInt16(a.r, a.g), vrcInt16(a.b, a.a), vrcInt16(b.r, b.g)) / 1024.0;
        vec3 to = normalize((gbufferModelView * vec4(w - cameraPosition, 1.0)).xyz);
        float angle = acos(clamp(-to.z, -1.0, 1.0));
        float upR = radians(float(p5.r) / 3.0), sideR = radians(float(p5.g) / 3.0), showR = radians(float(p5.b) / 3.0);
        if (angle > showR && length(to.xy) > 1e-4) {
            vec2 dir = normalize(to.xy);                         // towards the cursor in the view plane (y = head up)
            float vert = abs(dir.y), hor = sqrt(max(0.0, 1.0 - vert * vert));
            float off = 1.0 / sqrt(pow(hor / sideR, 2.0) + pow(vert / upR, 2.0));
            vec3 c = vec3(dir * sin(off), -cos(off)) * 1.2;
            vec4 clip = gbufferProjection * vec4(c, 1.0);
            vec2 center = (clip.xy / clip.w * 0.5 + 0.5) * vec2(viewWidth, viewHeight);
            float halfPx = arrowHalf / 1.2 * gbufferProjection[1][1] * 0.5 * viewHeight;
            vec2 up = normalize(vec2(dir.x * gbufferProjection[0][0] * viewWidth, dir.y * gbufferProjection[1][1] * viewHeight));
            vec2 right = vec2(up.y, -up.x);
            vec2 local = vec2(dot(frag - center, right), dot(frag - center, up)) / halfPx;   // -1..1
            if (abs(local.x) < 1.0 && abs(local.y) < 1.0) {
                ivec2 size = textureSize(vrArrowTex, 0);
                ivec2 tc = ivec2(clamp((local.x * 0.5 + 0.5) * float(size.x), 0.0, float(size.x - 1)),
                                 clamp((0.5 - local.y * 0.5) * float(size.y), 0.0, float(size.y - 1)));
                vec4 px = texelFetch(vrArrowTex, tc, 0);
                if (px.a > 0.5) {
                    float l = dot(px.rgb, vec3(0.2126, 0.7152, 0.0722));
                    color = vrcTint(l, glow, mid, core);
                }
            }
        }
    }
    return color;
}
#endif
