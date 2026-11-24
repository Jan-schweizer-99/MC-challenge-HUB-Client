// Gemeinsame Funktionen und Einstellungen
uniform float arenaLavaMix;

// Challenge-Hub (Welt "pvp", Boden y = 100) – gleiche Werte wie Hub.java (HX, HY, HZ, HR, RING)
const vec3 HUB = vec3(-20000.0, 100.0, -20000.0);
const float HUB_R = 23.0;
const float HUB_RING = 14.0;

// Zwei Inseln in Sichtweite (Welt pvp): Kristall bei x 0, Lava-Zwilling bei x 120.
// Jeder Client zeigt nur die Insel, auf der die Kamera gerade ist → Portalwechsel ohne sichtbaren Sprung.
const float TWIN_X = 120.0;
const float TWIN_SPLIT = 60.0;
#ifdef PVP_WORLD
#include "/lib/portal_scene.glsl"
#include "/lib/arena_fx_palette.glsl"
#endif

#define AO_STRENGTH 0.65
#define AO_RADIUS 0.6
#define SSR_STEPS 40

// Shader-Optionen (Optionen > Shaderpacks > ScopeCrystal). Standard = Vanilla-Look.
#define REFLECTIONS 0 // [0 1 2 3] Spiegelungen: 0 aus, 1 niedrig (Wasser/Glas), 2 mittel (+ glänzende Blöcke), 3 hoch
#define GLASS_STYLE 0 // [0 1 2] Glas: 0 Vanilla, 1 klar (durchgehende Scheiben), 2 fancy (+ Glanzstreifen)

int decodeMat(float a) { return int(a * 8.0 + 0.5) - 1; }   // -1 = Himmel/keine Daten
float encodeMat(int m) { return float(m + 1) / 8.0; }

float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}
