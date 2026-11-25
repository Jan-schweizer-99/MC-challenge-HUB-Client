// Pass 2: Bildschirm-Reflexionen (SSR) – Wasser, Glas, glänzende Blöcke. Spiegelt auch die Hub-/Arena-Effekte.
#include "/lib/common.glsl"

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D depthtex0;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform vec3 skyColor;
uniform vec3 fogColor;

in vec2 texcoord;

layout(location = 0) out vec4 outColor;

vec3 viewPos(vec2 uv, float depth) {
    vec4 v = gbufferProjectionInverse * vec4(vec3(uv, depth) * 2.0 - 1.0, 1.0);
    return v.xyz / v.w;
}

// Nur die Blicktiefe (z) – zwei statt vier Matrixzeilen, gleiches Ergebnis wie viewPos(...).z
float viewZ(vec2 uv, float depth) {
    vec4 ndc = vec4(vec3(uv, depth) * 2.0 - 1.0, 1.0);
    mat4 m = gbufferProjectionInverse;
    return dot(vec4(m[0][2], m[1][2], m[2][2], m[3][2]), ndc) / dot(vec4(m[0][3], m[1][3], m[2][3], m[3][3]), ndc);
}

vec2 toScreen(vec3 v) {
    vec4 c = gbufferProjection * vec4(v, 1.0);
    return c.xy / c.w * 0.5 + 0.5;
}

bool traceSSR(vec3 start, vec3 r, int steps, float grow, out vec2 hitUv) {
    float stepLen = max(0.15, -start.z * 0.035);
    vec3 p = start + r * stepLen * (0.5 + hash12(gl_FragCoord.xy));
    vec3 prev = start;
    for (int i = 0; i < SSR_STEPS; i++) {
        if (i >= steps) break;
        vec2 uv = toScreen(p);
        if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0 || p.z > -0.05) return false;
        float sz = viewZ(uv, texture(depthtex0, uv).r);
        float diff = sz - p.z;                                   // > 0: Strahl liegt hinter der Szene
        if (diff > 0.0 && diff < stepLen * 3.0 + 0.4) {
            vec3 a = prev, b = p;                                // Binärsuche
            for (int k = 0; k < 5; k++) {
                vec3 m = (a + b) * 0.5;
                vec2 muv = toScreen(m);
                if (viewZ(muv, texture(depthtex0, muv).r) - m.z > 0.0) b = m; else a = m;
            }
            hitUv = toScreen(b);
            return true;
        }
        prev = p;
        stepLen *= grow;
        p += r * stepLen;
    }
    return false;
}

void main() {
    vec3 color = texture(colortex0, texcoord).rgb;
    float depth = texture(depthtex0, texcoord).r;
    vec4 data = texture(colortex1, texcoord);
    int mat = decodeMat(data.a);
#if REFLECTIONS > 0
    // Stufe 1 nur Wasser und Glas (mat 1, 2); ab Stufe 2 auch glänzende Blöcke (mat 3, 4)
    if (depth < 1.0 && mat >= 1 && (REFLECTIONS >= 2 || mat <= 2)) {
        vec3 n = normalize(data.rgb * 2.0 - 1.0);
        vec3 vp = viewPos(texcoord, depth);
        vec3 v = normalize(vp);
        vec3 r = normalize(reflect(v, n));
        float fres = pow(1.0 - clamp(dot(-v, n), 0.0, 1.0), 5.0);
        float strength = mat == 1 ? mix(0.08, 1.0, fres)          // Wasser
                       : mat == 2 ? mix(0.10, 0.85, fres)         // Glas, Eis
                       :            mix(0.06, 0.55, fres);        // glänzende Blöcke
        float sky = texture(colortex2, texcoord).g;               // Himmelslicht: drinnen kein Himmel
        vec3 rW = mat3(gbufferModelViewInverse) * r;
        if (mat >= 3) strength *= smoothstep(-0.6, -0.2, (mat3(gbufferModelViewInverse) * n).y);   // Unterseiten spiegeln nur Rauschen
        vec3 refl = mix(fogColor, skyColor, clamp(rW.y * 1.5 + 0.2, 0.0, 1.0)) * smoothstep(0.3, 0.9, sky);
        vec2 hit;
        // Suchschritte je Stufe: Wasser/Glas bekommen mehr Reichweite als die schwach spiegelnden Blöcke
        bool clear = mat <= 2;
#if REFLECTIONS == 1
        int steps = 16; float grow = 1.25;
#elif REFLECTIONS == 2
        int steps = clear ? 28 : 16; float grow = clear ? 1.15 : 1.25;
#else
        int steps = clear ? SSR_STEPS : 28; float grow = clear ? 1.12 : 1.16;
#endif
        if (traceSSR(vp, r, steps, grow, hit)) {
            vec2 edge = smoothstep(0.0, 0.08, hit) * smoothstep(1.0, 0.92, hit);
            refl = mix(refl, texture(colortex0, hit).rgb, edge.x * edge.y);
        }
        color = mix(color, refl, strength);
    }
#endif
    outColor = vec4(color, 1.0);
}
