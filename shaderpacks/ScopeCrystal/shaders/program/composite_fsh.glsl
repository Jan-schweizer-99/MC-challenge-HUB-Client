// Pass 1: optionaler Vanilla-Nebel am Sichtweitenrand (alle Welten); in Welt pvp zusaetzlich Showcase-/Hub-/Arena-Effekte

// Shader-Option (Optionen > Shaderpacks > ScopeCrystal): standardmaessig AUS = klare Sicht bis zum Rand
//#define VANILLA_FOG // Vanilla-Nebel am Rand der Sichtweite

#include "/lib/common.glsl"
#ifdef PVP_WORLD
#include "/lib/showcase.glsl"
#include "/lib/hub.glsl"
#include "/lib/arena.glsl"
#endif


uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;
uniform vec3 fogColor;
uniform float viewWidth;
uniform float viewHeight;
uniform float far;

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

// Outline: echte Geometriekanten im Bild finden (Sprung in Normale oder Tiefe zu den Nachbarpixeln)
float edgeMask(vec2 uv, vec3 n0, float z0, int mat0) {
    vec2 px = 1.5 / vec2(viewWidth, viewHeight);
    vec2 offs[4] = vec2[4](vec2(px.x, 0.0), vec2(-px.x, 0.0), vec2(0.0, px.y), vec2(0.0, -px.y));
    float e = 0.0;
    for (int i = 0; i < 4; i++) {
        vec2 q = uv + offs[i];
        vec4 d = texture(colortex1, q);
        vec3 n = d.rgb * 2.0 - 1.0;
        float z = viewZ(q, texture(depthtex0, q).r);
        e = max(e, smoothstep(0.3, 0.8, length(n - n0)));
        e = max(e, smoothstep(0.04, 0.12, abs(z - z0) / max(-z0, 1.0)));
    }
    return e;
}

float ssao(vec3 vp, vec3 n) {
    float noise = hash12(gl_FragCoord.xy);
    float occ = 0.0;
    const int N = 12;
    vec3 t = normalize(cross(n, abs(n.y) < 0.99 ? vec3(0, 1, 0) : vec3(1, 0, 0)));
    vec3 bt = cross(n, t);
    for (int i = 0; i < N; i++) {
        float fi = (float(i) + noise) / float(N);
        float a = fi * 37.7 + noise * 6.283;
        float r = sqrt(fi);
        vec3 hemi = normalize(t * cos(a) * r + bt * sin(a) * r + n * sqrt(max(0.0, 1.0 - r * r)) + n * 0.15);
        vec3 s = vp + hemi * AO_RADIUS * (0.3 + 0.7 * fi * fi);
        vec4 clip = gbufferProjection * vec4(s, 1.0);
        vec2 uv = clip.xy / clip.w * 0.5 + 0.5;
        if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) continue;
        float sd = viewZ(uv, texture(depthtex1, uv).r);
        float range = smoothstep(0.0, 1.0, AO_RADIUS / max(abs(vp.z - sd), 1e-3));
        occ += (sd >= s.z + 0.03 ? 1.0 : 0.0) * range;
    }
    return 1.0 - AO_STRENGTH * occ / float(N);
}

void main() {
    vec3 color = texture(colortex0, texcoord).rgb;
    float depth0 = texture(depthtex0, texcoord).r;
    float depth1 = texture(depthtex1, texcoord).r;
    vec4 data = texture(colortex1, texcoord);
    int mat = decodeMat(data.a);
    vec3 n = normalize(data.rgb * 2.0 - 1.0);

    // Vanilla-Look: keine zusaetzliche Umgebungsverdeckung (Vanilla-AO steckt schon in den Blockfarben)

    // Weltkoordinaten dieses Pixels
    vec3 vp = viewPos(texcoord, depth0);
    vec3 camW = cameraPosition + gbufferModelViewInverse[3].xyz;
    vec3 wp = cameraPosition + (gbufferModelViewInverse * vec4(vp, 1.0)).xyz;
    vec3 dir = normalize(wp - camW);
    float sceneDist = depth0 < 1.0 ? length(wp - camW) : 1e5;
    vec3 nW = mat3(gbufferModelViewInverse) * n;

    // Nebel wie Vanilla: nur ein schmaler Rand am Ende der Sichtweite (Start = far - clamp(far/10, 4, 64)),
    // zylindrischer Abstand (waagrecht bzw. senkrecht), linear – nicht mehr ab 75 % der Sichtweite
#ifdef VANILLA_FOG
    if (depth0 < 1.0) {
        vec3 rel = wp - camW;
        float fogDist = max(length(rel.xz), abs(rel.y));
        float fogStart = far - clamp(far / 10.0, 4.0, 64.0);
        color = mix(color, fogColor, clamp((fogDist - fogStart) / max(far - fogStart, 1.0), 0.0, 1.0));
    }
#endif

#ifdef PVP_WORLD
    bool surf = depth0 < 1.0 && mat >= 0;
    color += showcase(camW, dir, sceneDist, surf, wp, nW);
    color += hub(camW, dir, sceneDist, surf, wp, nW);
    vec3 effectCamera = camW, effectWorld = wp;
    if (portalSceneCamera(cameraPosition)) {
        float viewSide = portalPixelSide(wp, camW, cameraPosition);
        float offset = (viewSide - portalPhysicalSide(cameraPosition)) * TWIN_X;
        effectCamera.x += offset; effectWorld.x += offset;
    }
    // Kanten (4 Extra-Abtastungen) braucht nur das Lauflicht an Tribüne und Mauer
    vec3 edgeLocal = effectWorld;
    if (effectCamera.x > TWIN_SPLIT) edgeLocal.x -= TWIN_X;
    float edgeR = length(edgeLocal.xz - vec2(0.5));
    bool nearTribune = edgeR > 24.5 && edgeR < 36.0 && edgeLocal.y > 99.0 && edgeLocal.y < 118.0;
    float edge = surf && nearTribune ? edgeMask(texcoord, n, vp.z, mat) : 0.0;
    color += arena(effectCamera, dir, sceneDist, surf, depth0 >= 1.0, effectWorld, nW, edge, mat);
#endif
    outColor = vec4(color, 1.0);
}
