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

// screen position in pixels (xy), view depth (z, negative in front), pixels per metre of trail width at that depth (w):
// like the mod, the width grows with the distance (max(0.6, d / 1.6)), so the trail looks the same near and far
vec4 vrcProject(vec3 world) {
    vec4 view = gbufferModelView * vec4(world - cameraPosition, 1.0);
    vec4 clip = gbufferProjection * view;
    vec2 px = (clip.xy / clip.w * 0.5 + 0.5) * vec2(viewWidth, viewHeight);
    float d = max(length(view.xyz), 0.01);
    return vec4(px, view.z, gbufferProjection[1][1] * 0.5 * viewHeight / max(-view.z, 0.01) * max(0.6, d / 1.6));
}

vec3 vrcColor(int i) { return vrcTexel(i).rgb; }

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
    // exactly the look of the mod's gizmo trail: three flat bands (glow 100 % width 22 %, middle 62 % width 35 %,
    // core 30 % width 95 % opacity), thinner and fainter towards the old end, and a head of two discs
    if ((head.r & 1) != 0 && n >= 1) {
        float bestD = 9.0, bestF = 0.0;
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
                if (d < bestD) { bestD = d; bestF = f; }
            }
            prev = cur; prevFade = fade;
        }
        float k = 0.15 + 0.85 * bestF;
        if (bestD < 1.0)  color = mix(color, glow, min(1.0, 0.22 * opacity * k));
        if (bestD < 0.62) color = mix(color, mid, min(1.0, 0.35 * opacity * k));
        if (bestD < 0.3)  color = mix(color, core, min(1.0, 0.95 * opacity * k));
        if (headSize > 0.01 && prev.z < -0.05) {
            float d = length(frag - prev.xy) / max(widthM * prev.w * headSize, 0.75);
            if (d < 1.0) color = mix(color, mid, 0.4 * opacity);
            if (d < 0.5) color = mix(color, core, 0.95 * opacity);
        }
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
            // a flat picture in space, 1.2 m away, facing the eye, like in the mod: cut the view ray of this pixel with it
            vec3 c = vec3(dir * sin(off), -cos(off)) * 1.2;
            vec3 nrm = normalize(c);
            vec3 up3 = vec3(dir, 0.0);
            up3 = normalize(up3 - nrm * dot(up3, nrm));
            vec3 right3 = cross(up3, -nrm);
            // view ray of this pixel straight from the projection (works with any depth convention and the
            // off-centre projections of a headset): at z = -1, ndc = (P00 x + P20 z) / -z  ->  x = (ndc + P20) / P00
            vec2 ndc = frag / vec2(viewWidth, viewHeight) * 2.0 - 1.0;
            vec3 ray = normalize(vec3((ndc.x + gbufferProjection[2][0]) / gbufferProjection[0][0],
                                      (ndc.y + gbufferProjection[2][1]) / gbufferProjection[1][1], -1.0));
            float hitT = dot(c, nrm) / max(dot(ray, nrm), 1e-4);
            vec3 hit = ray * hitT - c;
            vec2 local = vec2(dot(hit, right3), dot(hit, up3)) / arrowHalf;     // -1..1
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
