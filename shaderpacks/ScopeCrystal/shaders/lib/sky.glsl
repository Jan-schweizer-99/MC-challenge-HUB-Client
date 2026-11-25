// Himmel der Hub-Welt: Farbe je nach Ort des Spielers (Hub, Insel, Tempel, Hall of Fame, Arenen), fliessend gemischt.
// skyPosZ ist die geglaettete Kameraposition (shaders.properties), damit auch Teleports weich ueberblenden.
uniform float skyPosZ, skyPosX;

// Farben: Horizont, Zenit und Schleier je Ort
void skyPalette(int side, out vec3 low, out vec3 high, out vec3 veil) {
    float z = clamp(skyPosZ, -580.0, 0.0);
    float a = smoothstep(-230.0, -120.0, z), q = min(z, -325.0);
    vec4 w = exp(-pow((vec4(q) - vec4(-455.0, -400.0, -335.0, -562.0)) / vec4(34.0, 20.0, 34.0, 42.0), vec4(2.0)));
    w /= max(dot(w, vec4(1.0)), 1e-4);
    // Hub: Eisblau | Insel: Blauviolett | Tempel: Amethyst | Hall of Fame: Gold
    low = w.x * vec3(0.04, 0.27, 0.38) + w.y * vec3(0.13, 0.21, 0.44) + w.z * vec3(0.25, 0.14, 0.48) + w.w * vec3(0.60, 0.34, 0.08);
    high = w.x * vec3(0.01, 0.05, 0.15) + w.y * vec3(0.03, 0.04, 0.16) + w.z * vec3(0.06, 0.02, 0.18) + w.w * vec3(0.17, 0.07, 0.03);
    veil = w.x * vec3(0.20, 0.75, 0.80) + w.y * vec3(0.45, 0.55, 1.00) + w.z * vec3(0.75, 0.45, 1.00) + w.w * vec3(1.00, 0.70, 0.25);
    // Seitenplaetze: links Smaragd (World Sanctum), rechts Bonbonrosa (Arcade)
    float sx = skyPosX - 0.5, sw = smoothstep(26.0, 62.0, abs(sx)) * smoothstep(70.0, 40.0, abs(skyPosZ + 454.5));
    low = mix(low, sx < 0.0 ? vec3(0.04, 0.34, 0.27) : vec3(0.50, 0.15, 0.36), sw);
    high = mix(high, sx < 0.0 ? vec3(0.01, 0.07, 0.11) : vec3(0.10, 0.03, 0.17), sw);
    veil = mix(veil, sx < 0.0 ? vec3(0.45, 1.0, 0.65) : vec3(1.0, 0.65, 0.85), sw);
    // Arenen nach ihrer Blockpalette: Eis, Lava, End
    vec3 aLow = side == 2 ? vec3(0.34, 0.09, 0.45) : side == 1 ? vec3(0.58, 0.15, 0.02) : vec3(0.07, 0.29, 0.50);
    vec3 aHigh = side == 2 ? vec3(0.09, 0.02, 0.15) : side == 1 ? vec3(0.15, 0.02, 0.01) : vec3(0.01, 0.06, 0.18);
    vec3 aVeil = side == 2 ? vec3(0.95, 0.35, 0.90) : side == 1 ? vec3(1.00, 0.42, 0.08) : vec3(0.45, 0.85, 1.00);
    low = mix(low, aLow, a); high = mix(high, aHigh, a); veil = mix(veil, aVeil, a);
}

vec3 skyZones(vec3 dir, float t, int side) {
    vec3 low, high, veil;
    skyPalette(side, low, high, veil);
    float up = max(dir.y, 0.0), g = exp(-up * 3.0);
    vec3 col = mix(high, low, g);
    if (dir.y < 0.0) col = mix(low, high * 0.5, smoothstep(0.0, 0.55, -dir.y));
    // zwei weiche Lichtbaender um den Horizont; nur cos(k * Winkel): links und rechts gleich, ohne Naht
    vec3 d = floor(dir * 96.0) / 96.0;
    float az = atan(d.x, d.z);
    for (int i = 0; i < 2; i++) {
        float fi = float(i), k = 2.0 + fi;
        float y = 0.16 + 0.17 * fi + 0.045 * cos(az * k) * sin(t * 0.11 + fi) + 0.03 * cos(az * (k + 3.0)) * sin(t * 0.07 + 2.0 * fi);
        float soft = d.y > y ? 0.16 : 0.035;                                  // unten scharfe Kante, nach oben auslaufend
        float strength = 0.55 + 0.45 * cos(az * (k + 1.0)) * cos(t * 0.09 + fi * 1.7);
        col += veil * exp(-pow((d.y - y) / soft, 2.0)) * strength * (0.085 - 0.03 * fi);
    }
    return max(col + (hash12(gl_FragCoord.xy) - 0.5) / 255.0, 0.0);          // Rauschen gegen Farbstufen
}
