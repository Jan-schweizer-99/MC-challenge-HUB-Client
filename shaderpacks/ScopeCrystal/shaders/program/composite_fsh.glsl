// Pass 1: optionaler Vanilla-Nebel am Sichtweitenrand (alle Welten); in Welt pvp zusaetzlich Hub-/Arena-Effekte

// Shader-Option (Optionen > Shaderpacks > ScopeCrystal): standardmaessig AUS = klare Sicht bis zum Rand
//#define VANILLA_FOG // Vanilla-Nebel am Rand der Sichtweite

#include "/lib/common.glsl"
#ifdef PVP_WORLD
#include "/lib/fx_common.glsl"
#include "/lib/fx_view.glsl"
flat in int fxSeen;
flat in float fxAct[6];
#include "/lib/places.glsl"
#include "/lib/objects_spec.glsl"
#include "/lib/objects.glsl"
bool fxSee(int i, vec3 camW, vec3 dir, float sceneDist) { return (fxSeen >> i & 1) != 0 && fxRayBox(i, camW, dir, sceneDist); }
#include "/lib/hub.glsl"
#include "/lib/arena.glsl"
#include "/lib/pads.glsl"
#include "/lib/temple.glsl"
#include "/lib/lobby.glsl"
#include "/lib/hall.glsl"
#include "/lib/sides.glsl"
#include "/lib/beams.glsl"
#include "/lib/sky.glsl"
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
    float ft = frameTimeCounter;
    bool objHit = false;
    if (cameraPosition.z < -200.0) {                        // Voxel-Objekte zuerst: deckend, alles dahinter bleibt verdeckt
        for (int i = 0; i < 3; i++) if (obT[i] >= 0) {
            float h;
            vec3 oc = objTrace(i, camW, dir, sceneDist, h);
            if (h > 0.0) { color = oc; sceneDist = h; objHit = true; surf = false; }
        }
        for (int i = 0; i < 3; i++) if (obT[i] >= 0) {
            color += objGlow(i, camW, dir, sceneDist);
            if (surf) color += objWave(i, wp, nW);
        }
    }
    color += skyBeams(camW, dir, sceneDist, ft);
    if (cameraPosition.z < -200.0) {
        if (fxAct[PL_HUB] > 0.002) {
            vec3 fx = hub(camW, dir, sceneDist, surf, wp, nW);
#ifdef FX_HUB_PADS
            if (fxSee(FXV_HUB, camW, dir, sceneDist)) {
                fx += padFx(vec3(-9.0, 101.0, -454.5), vec2(-1.0, 0.0), vec3(0.45, 1.0, 0.65), camW, dir, sceneDist, surf, wp, nW, ft);
                fx += padFx(vec3(10.0, 101.0, -454.5), vec2(1.0, 0.0), vec3(1.0, 0.5, 0.78), camW, dir, sceneDist, surf, wp, nW, ft);
                fx += padFx(vec3(0.5, 101.0, -445.0), vec2(0.0, 1.0), vec3(0.50, 0.60, 1.0), camW, dir, sceneDist, surf, wp, nW, ft);
                fx += padFx(vec3(0.5, 101.0, -464.0), vec2(0.0, -1.0), vec3(1.0, 0.75, 0.25), camW, dir, sceneDist, surf, wp, nW, ft);
            }
#endif
            color += fx * placeShow(PL_HUB, fxAct[PL_HUB], surf, wp) + placeFront(PL_HUB, fxAct[PL_HUB], surf, wp, nW);
        }
        if (fxAct[PL_LOBBY] > 0.002) {
            vec3 fx = vec3(0.0);
            if (fxSee(FXV_LOBBY, camW, dir, sceneDist)) {
                fx += lobby(camW, dir, sceneDist, surf, wp, nW);
#ifdef FX_HUB_PADS
                fx += padFx(vec3(0.5, 101.0, -403.5), vec2(0.0, -1.0), vec3(0.35, 0.8, 1.0), camW, dir, sceneDist, surf, wp, nW, ft);
                fx += padFx(vec3(0.5, 101.0, -395.5), vec2(0.0, 1.0), vec3(0.75, 0.5, 1.0), camW, dir, sceneDist, surf, wp, nW, ft);
#endif
            }
            color += fx * placeShow(PL_LOBBY, fxAct[PL_LOBBY], surf, wp) + placeFront(PL_LOBBY, fxAct[PL_LOBBY], surf, wp, nW);
        }
        if (fxAct[PL_TEMPLE] > 0.002) {
            vec3 fx = vec3(0.0);
            if (fxSee(FXV_TEMPLE, camW, dir, sceneDist)) {
                fx += temple(camW, dir, sceneDist, surf, wp, nW);
#ifdef FX_HUB_PADS
                fx += padFx(vec3(0.5, 101.0, -379.5), vec2(0.0, -1.0), vec3(0.50, 0.60, 1.0), camW, dir, sceneDist, surf, wp, nW, ft);
#endif
            }
            color += fx * placeShow(PL_TEMPLE, fxAct[PL_TEMPLE], surf, wp) + placeFront(PL_TEMPLE, fxAct[PL_TEMPLE], surf, wp, nW);
        }
        if (fxAct[PL_HALL] > 0.002) {
            vec3 fx = vec3(0.0);
            if (fxSee(FXV_HALL, camW, dir, sceneDist)) {
                fx += hall(camW, dir, sceneDist, surf, wp, nW);
#ifdef FX_HUB_PADS
                fx += padFx(vec3(0.5, 104.0, -525.0), vec2(0.0, 1.0), vec3(0.35, 0.8, 1.0), camW, dir, sceneDist, surf, wp, nW, ft);
#endif
            }
            color += fx * placeShow(PL_HALL, fxAct[PL_HALL], surf, wp) + placeFront(PL_HALL, fxAct[PL_HALL], surf, wp, nW);
        }
        if (fxAct[PL_WORLD] > 0.002) {
            vec3 fx = vec3(0.0);
            if (fxSee(FXV_WORLD, camW, dir, sceneDist)) {
                fx += world(camW, dir, sceneDist, surf, wp, nW);
#ifdef FX_HUB_PADS
                fx += padFx(vec3(-52.5, 101.0, -454.5), vec2(1.0, 0.0), vec3(0.35, 0.8, 1.0), camW, dir, sceneDist, surf, wp, nW, ft);
#endif
            }
            color += fx * placeShow(PL_WORLD, fxAct[PL_WORLD], surf, wp) + placeFront(PL_WORLD, fxAct[PL_WORLD], surf, wp, nW);
        }
        if (fxAct[PL_ARCADE] > 0.002) {
            vec3 fx = vec3(0.0);
            if (fxSee(FXV_ARCADE, camW, dir, sceneDist)) {
                fx += arcade(camW, dir, sceneDist, surf, wp, nW);
#ifdef FX_HUB_PADS
                fx += padFx(vec3(53.5, 101.0, -454.5), vec2(-1.0, 0.0), vec3(0.35, 0.8, 1.0), camW, dir, sceneDist, surf, wp, nW, ft);
#endif
            }
            color += fx * placeShow(PL_ARCADE, fxAct[PL_ARCADE], surf, wp) + placeFront(PL_ARCADE, fxAct[PL_ARCADE], surf, wp, nW);
        }
    }
    vec3 effectCamera = camW, effectWorld = wp;
    if (portalSceneCamera(cameraPosition)) {
        float viewSide = portalPixelSide(wp, camW, cameraPosition);
        float offset = (viewSide - portalPhysicalSide(cameraPosition)) * TWIN_X;
        effectCamera.x += offset; effectWorld.x += offset;
    }
#ifdef FX_HUB_SKY
    if (objHit) {}
    else if (depth0 >= 1.0) color += skyZones(dir, frameTimeCounter, arenaSideAt(effectCamera));
    else if (mat < 0 && wp.y > 185.0 && wp.y < 202.0 && sceneDist > 40.0) color += skyZones(dir, frameTimeCounter, arenaSideAt(effectCamera)) * 0.45;   // Wolken
#endif
    float edge = 0.0;
#if FXM_EDGES > 0
    // Kanten (4 Extra-Abtastungen) braucht nur das Lauflicht an Tribüne und Mauer
    vec3 edgeLocal = effectWorld;
    int edgeSide = arenaSideAt(effectCamera);
    edgeLocal.x -= arenaOffsetX(edgeSide);
    float edgeR = length(edgeLocal.xz - vec2(0.5));
    bool nearTribune = edgeR > 24.5 && edgeR < 36.0 && edgeLocal.y > 99.0 && edgeLocal.y < 118.0;
    if (surf && nearTribune && fxOn(FXM_EDGES, edgeSide)) edge = edgeMask(texcoord, n, vp.z, mat);
#endif
    color += arena(effectCamera, dir, sceneDist, surf, depth0 >= 1.0, effectWorld, nW, edge, mat);
#endif
    outColor = vec4(color, 1.0);
}
