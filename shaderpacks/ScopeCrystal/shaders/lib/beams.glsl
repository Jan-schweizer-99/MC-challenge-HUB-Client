// Himmelsstrahlen der vier Orte (Arena-Tempel, Hall of Fame, World Sanctum, Arcade): immer sichtbar, auch von weitem.
// Braucht raySegment (arena).
vec3 skyBeam(vec3 a, vec3 tint, vec3 glow, vec3 camW, vec3 dir, float sceneDist, float t) {
    vec3 seg = raySegment(a, vec3(a.x, 330.0, a.z), camW, dir);
    if (seg.z <= 0.0 || seg.z > sceneDist || seg.x > 9.0) return vec3(0.0);
    float fade = pow(1.0 - seg.y, 1.5) * smoothstep(0.0, 0.02, seg.y);
    float roll = 0.75 + 0.25 * sin(seg.y * 70.0 - t * 5.0);
    return (tint * exp(-seg.x * seg.x / 0.35) * 0.9 * roll + glow * exp(-seg.x * seg.x / 8.0) * 0.28) * fade;
}

vec3 skyBeams(vec3 camW, vec3 dir, float sceneDist, float t) {
    vec3 col = vec3(0.0);
#ifdef FX_TEMPLE_BEAM
    if (fxSee(FXV_BEAM, camW, dir, sceneDist)) col += skyBeam(vec3(0.5, 171.0, -343.5), vec3(0.75, 0.95, 1.0), vec3(0.4, 0.55, 1.0), camW, dir, sceneDist, t);
#endif
#ifdef FX_HALL_BEAM
    if (fxSee(FXV_BEAM_HALL, camW, dir, sceneDist)) col += skyBeam(vec3(0.5, 134.0, -554.5), vec3(1.0, 0.88, 0.55), vec3(1.0, 0.62, 0.15), camW, dir, sceneDist, t);
#endif
#ifdef FX_WORLD_BEAM
    if (fxSee(FXV_BEAM_WORLD, camW, dir, sceneDist)) col += skyBeam(vec3(CHAL.x, 131.0, CHAL.z), vec3(0.75, 1.0, 0.85), vec3(0.2, 0.95, 0.55), camW, dir, sceneDist, t);
#endif
#ifdef FX_ARCADE_BEAM
    if (fxSee(FXV_BEAM_ARCADE, camW, dir, sceneDist)) col += skyBeam(vec3(ARCADE.x, 137.5, ARCADE.z), vec3(1.0, 0.8, 0.92), vec3(1.0, 0.35, 0.7), camW, dir, sceneDist, t);
#endif
    return col;
}
