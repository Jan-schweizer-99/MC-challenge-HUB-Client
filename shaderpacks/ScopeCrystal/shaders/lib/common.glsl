// Gemeinsame Funktionen und Einstellungen
uniform float arenaLavaMix;

// Challenge-Hub (Welt "pvp", Boden y = 100) – gleiche Werte wie Hub.java (HX, HY, HZ, HR, RING)
const vec3 HUB = vec3(0.0, 100.0, -455.0);
const float HUB_R = 23.0;
// Seitenplaetze (Seiten.java): World Sanctum mit Sockeln und Ready-Ring, Arcade
const vec3 CHAL = vec3(-79.5, 101.0, -454.5);
const vec3 ARCADE = vec3(80.5, 101.0, -454.5);
const float CHAL_RING = 15.0;

// Zwei Inseln in Sichtweite (Welt pvp): Kristall bei x 0, Lava-Zwilling bei x 120.
// Jeder Client zeigt nur die Insel, auf der die Kamera gerade ist → Portalwechsel ohne sichtbaren Sprung.
const float TWIN_X = 120.0;
const float TWIN_SPLIT = 60.0;
// End-Arena: dritte Insel ohne Portal, gleiche Werte wie Arena.END_X / TOWER
const float END_X = -600.0;
// Insel an einer Weltposition: 0 Eis, 1 Lava, 2 End
int arenaSideAt(vec3 p) {
    if (abs(p.x - END_X) < 150.0 && abs(p.z) < 200.0) return 2;
    return p.x > TWIN_SPLIT ? 1 : 0;
}
float arenaOffsetX(int side) { return side == 2 ? END_X : side == 1 ? TWIN_X : 0.0; }
#ifdef PVP_WORLD
#include "/lib/fx_options.glsl"
#include "/lib/portal_scene.glsl"
#include "/lib/arena_fx_palette.glsl"
#endif

#define AO_STRENGTH 0.65
#define AO_RADIUS 0.6
#define SSR_STEPS 40

// Shader-Optionen (Optionen > Shaderpacks > ScopeCrystal). Standard = Vanilla-Look.
#define REFLECTIONS 0 // [0 1 2 3] Spiegelungen: 0 aus, 1 niedrig (Wasser/Glas), 2 mittel (+ glänzende Blöcke), 3 hoch
//#define FULLBRIGHT // Fullbright an/aus (Taste im Shader-Menue-Mod)
#define FULLBRIGHT_MODE 1 // [1 2] Fullbright-Art: 1 Hoehlen (dunkle Stellen aufgehellt, Licht bleibt sichtbar), 2 voll (alles taghell)

// Lightmap colour with the fullbright option applied
vec3 fullbright(vec3 light) {
#ifdef FULLBRIGHT
#if FULLBRIGHT_MODE == 2
    return vec3(1.0);
#else
    return max(light, vec3(0.65));
#endif
#else
    return light;
#endif
}
#define GLASS_STYLE 0 // [0 1 2] Glas: 0 Vanilla, 1 klar (durchgehende Scheiben), 2 fancy (+ Glanzstreifen)

int decodeMat(float a) { return int(a * 8.0 + 0.5) - 1; }   // -1 = Himmel/keine Daten
float encodeMat(int m) { return float(m + 1) / 8.0; }

float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}
