#ifndef ARENA_FX_PALETTE
#define ARENA_FX_PALETTE
// Additional light follows the visible arena: ice/cyan/white, ember/orange or ender violet.
// Native block colours remain intact. No texture fetches or extra effect passes.
int arenaFxSide(vec3 world) {
    int side = arenaSideAt(world);
    return side == 2 || portalSceneCamera(world) ? side : 0;
}
vec3 arenaFxPalette(vec3 light, int side) {
    float peak = max(light.r, max(light.g, light.b));
    vec3 unit = light / max(peak, 0.000001);
    float neutral = min(unit.r, min(unit.g, unit.b));
    float core = neutral * neutral * neutral * neutral;
    vec3 tint;
    if (side == 2) {
        // End: violet to magenta, pale ender core
        float glow = clamp(unit.r + 0.35 * unit.g - 0.3 * unit.b, 0.0, 1.0);
        tint = mix(vec3(0.36, 0.1, 1.0), vec3(1.0, 0.2, 0.86), glow);
        tint = mix(tint, vec3(0.95, 0.84, 1.0), core * 0.8);
    } else if (side == 1) {
        float amber = clamp(unit.r + 0.5 * unit.g - 0.5 * unit.b, 0.0, 1.0);
        tint = mix(vec3(1.0, 0.075, 0.008), vec3(1.0, 0.44, 0.025), amber);
        tint = mix(tint, vec3(1.0, 0.78, 0.4), core * 0.55);
    } else {
        float frost = clamp(unit.b - 0.6 * unit.r + 0.2 * unit.g, 0.0, 1.0);
        tint = mix(vec3(0.12, 0.44, 1.0), vec3(0.18, 0.88, 1.0), frost);
        tint = mix(tint, vec3(0.88, 0.98, 1.0), core * 0.9);
    }
    // Keep luminance and animation strength: colour styling adds no brightness.
    const vec3 luma = vec3(0.2126, 0.7152, 0.0722);
    return tint * (dot(light, luma) / dot(tint, luma));
}
#endif
