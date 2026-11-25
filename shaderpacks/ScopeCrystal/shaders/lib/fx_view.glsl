// Sichtpruefung: je Bereich eine Kiste, die alle seine Effekte enthaelt (mit Reserve).
// 1) composite_vsh prueft einmal je Bild, ob die Kiste im Blickfeld liegt (sonst ganzer Bereich aus, z. B. hinter dem Spieler).
// 2) composite_fsh prueft je Pixel, ob der Blickstrahl die Kiste trifft, bevor ein Block davor liegt.
const int FXV_COUNT = 15;
const int FXV_HUB = 0, FXV_AURORA = 1, FXV_TEMPLE = 2, FXV_BEAM = 3, FXV_LOBBY = 4, FXV_HALL = 5, FXV_HALL_IN = 6, FXV_HALL_TOP = 7, FXV_ARENA = 8, FXV_WORLD = 9, FXV_ARCADE = 10, FXV_BEAM_HALL = 11, FXV_BEAM_WORLD = 12, FXV_BEAM_ARCADE = 13, FXV_HEART = 14;
const vec3 FXV_LO[15] = vec3[15](
    vec3(-28.0, 96.0, -483.0), vec3(-152.0, 124.0, -607.0), vec3(-44.0, 50.0, -388.0), vec3(-11.0, 168.0, -355.0), vec3(-28.0, 85.0, -442.0),
    vec3(-37.0, 98.0, -592.0), vec3(-32.0, 98.0, -587.0), vec3(-37.0, 115.0, -592.0), vec3(-76.0, 66.0, -76.0),
    vec3(-114.0, 92.0, -489.0), vec3(19.0, 92.0, -489.0),
    vec3(-11.0, 130.0, -566.0), vec3(-91.0, 127.0, -466.0), vec3(69.0, 134.0, -466.0),
    vec3(-14.0, 99.0, -469.0));
const vec3 FXV_HI[15] = vec3[15](
    vec3(29.0, 124.0, -427.0), vec3(153.0, 152.0, -302.0), vec3(45.0, 188.0, -299.0), vec3(12.0, 334.0, -332.0), vec3(29.0, 130.0, -350.0),
    vec3(38.0, 148.0, -473.0), vec3(33.0, 142.0, -522.0), vec3(38.0, 148.0, -517.0), vec3(77.0, 205.0, 77.0),
    vec3(-18.0, 142.0, -420.0), vec3(115.0, 142.0, -420.0),
    vec3(12.0, 334.0, -543.0), vec3(-68.0, 334.0, -443.0), vec3(92.0, 334.0, -443.0),
    vec3(15.0, 162.0, -440.0));

// Trifft der Strahl die Kiste vor sceneDist?
bool fxRayBox(int i, vec3 camW, vec3 dir, float sceneDist) {
    vec3 inv = 1.0 / (sign(dir) * max(abs(dir), vec3(1e-6)) + vec3(equal(dir, vec3(0.0))) * 1e-6);
    vec3 a = (FXV_LO[i] - camW) * inv, b = (FXV_HI[i] - camW) * inv;
    vec3 n = min(a, b), f = max(a, b);
    float tn = max(max(n.x, n.y), n.z), tf = min(min(f.x, f.y), f.z);
    return tf >= max(tn, 0.0) && tn < sceneDist + 0.5;
}
