// Orts-Trigger: Nur der Ort, an dem der Spieler gerade ist, rechnet seine Effekte (composite_vsh bestimmt fxAct einmal je Bild).
// Kommt man näher, läuft eine Lichtkugel von der Mitte nach außen und baut die Effekte auf. Die Himmelsstrahlen bleiben immer an.
const int PL_HUB = 0, PL_LOBBY = 1, PL_TEMPLE = 2, PL_HALL = 3, PL_WORLD = 4, PL_ARCADE = 5;

vec3 placeCenter(int p) {
    return p == PL_HUB ? vec3(0.5, 101.0, -454.5) : p == PL_LOBBY ? vec3(0.5, 101.0, -399.5) : p == PL_TEMPLE ? vec3(0.5, 104.0, -343.5)
        : p == PL_HALL ? vec3(0.5, 104.0, -554.5) : p == PL_WORLD ? CHAL : ARCADE;
}
// Reichweite des Aufbaus, voll an ab / aus ab (Abstand des Spielers zur Mitte)
vec3 placeRange(int p) {
    return p == PL_HUB ? vec3(62.0, 31.0, 46.0) : p == PL_LOBBY ? vec3(36.0, 16.0, 31.0) : p == PL_TEMPLE ? vec3(88.0, 38.0, 52.0)
        : p == PL_HALL ? vec3(72.0, 42.0, 60.0) : vec3(74.0, 33.0, 47.0);
}
vec3 placeTint(int p) {
    return p == PL_HUB ? vec3(0.4, 0.8, 1.0) : p == PL_LOBBY ? vec3(0.55, 0.65, 1.0) : p == PL_TEMPLE ? vec3(0.75, 0.5, 1.0)
        : p == PL_HALL ? vec3(1.0, 0.76, 0.3) : p == PL_WORLD ? vec3(0.45, 1.0, 0.65) : vec3(1.0, 0.5, 0.78);
}

// Anteil eines Pixels, der schon aufgebaut ist: Flächen nach Abstand zur Mitte, Himmel nach Gesamtstand
float placeShow(int p, float act, bool hasSurface, vec3 wp) {
    if (act >= 0.999) return 1.0;
    if (!hasSurface) return act * act;
    float front = act * placeRange(p).x;
    return smoothstep(0.0, 7.0, front - length(wp - placeCenter(p)));
}

// Leuchtende Front der Aufbau-Kugel, im Pixelraster
vec3 placeFront(int p, float act, bool hasSurface, vec3 wp, vec3 nW) {
    if (!hasSurface || act <= 0.002 || act >= 0.999) return vec3(0.0);
    vec3 g = floor((wp - nW * 0.03) * 8.0) / 8.0;
    float d = length(wp - placeCenter(p)) - act * placeRange(p).x;
    if (abs(d) > 9.0) return vec3(0.0);
    float line = exp(-d * d / 0.12), tail = d < 0.0 ? exp(d / 2.2) : exp(-d * d / 0.4);
    float cell = step(0.80, hash12(g.xz * 3.1 + g.y * 7.7)) * (d < 0.0 ? exp(d / 3.5) : 0.0);
    return placeTint(p) * (line * 0.9 + tail * 0.18 + cell * 0.45) * smoothstep(0.0, 0.08, act) * (1.0 - smoothstep(0.85, 1.0, act));
}
