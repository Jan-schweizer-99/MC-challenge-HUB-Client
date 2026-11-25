#ifndef LIVE_PORTAL_SCENE
#define LIVE_PORTAL_SCENE
// Two native sets of loaded geometry share one view through a spatial clip mask.
// The two-pixel buffer stores only crossing state, never an old scene image.
uniform sampler2D colortex4;
const float PORTAL_Y = 109.0;
const float PORTAL_R = 4.5;
// Whole Minecraft cells define the aperture, matching Arena.crystalLayout.
uniform int worldTime;
// Arenas without a portal: the server moves the frozen clock of "pvp" from 18000 to 18300 (Arena.TIME_NO_PORTAL).
bool portalEnabled() { return worldTime < 18150 || worldTime > 18450; }
// Ready-Ring im Hub: 0 leer, 1-9 Anteil der Spieler im Ring, 10-100 Countdown (Hub.ringTick)
float hubReadySignal() { int n = worldTime - (portalEnabled() ? 18000 : 18300); return n > 0 && n <= 100 ? float(n) : 0.0; }
bool portalOpeningCell(vec2 localHit) {
    if (!portalEnabled()) return false;
    vec2 cell = floor(localHit);
    return dot(cell, cell) < PORTAL_R * PORTAL_R;
}
bool portalFrontFacing(vec3 eye) {
    // One horizontal plane with normal (0,1,0). No underside portal view.
    if (!portalEnabled()) return false;
    return dot(eye - vec3(0.5, PORTAL_Y, 0.5), vec3(0.0, 1.0, 0.0)) > 0.00001;
}
bool portalFrontInView(vec3 eye, vec3 camera, mat4 viewProjection) {
    if (!portalFrontFacing(eye)) return false;
    // Conservative enclosing square: reject only when the entire aperture is
    // outside one homogeneous frustum plane. Works even close to the surface.
    vec3 origin = vec3(step(TWIN_SPLIT, camera.x) * TWIN_X, PORTAL_Y, 0.0);
    bool left = true, right = true, bottom = true, top = true, nearPlane = true, farPlane = true;
    for (int i = 0; i < 4; ++i) {
        vec2 corner = vec2((i == 0 || i == 1) ? -4.0 : 5.0, (i == 0 || i == 2) ? -4.0 : 5.0);
        vec4 clip = viewProjection * vec4(origin + vec3(corner.x, 0.0, corner.y) - camera, 1.0);
        left = left && clip.x < -clip.w; right = right && clip.x > clip.w;
        bottom = bottom && clip.y < -clip.w; top = top && clip.y > clip.w;
        nearPlane = nearPlane && clip.z < -clip.w; farPlane = farPlane && clip.z > clip.w;
    }
    return !(left || right || bottom || top || nearPlane || farPlane);
}
bool portalSceneCamera(vec3 p) {
    p.x -= step(TWIN_SPLIT, p.x) * TWIN_X;
    return length(p.xz - vec2(0.5)) < 90.0 && abs(p.y - 101.0) < 70.0;
}
bool portalSceneGeometry(vec3 p) {
#ifdef PORTAL_BEACON
    // Native beacon quads extend over 2048 blocks. Every vertex of the same
    // quad needs the same rigid portal translation, including its distant top.
    return p.x > -70.0 && p.x < TWIN_X + 70.0 && abs(p.z) < 90.0;
#else
    return p.x > -70.0 && p.x < TWIN_X + 70.0 && abs(p.z) < 90.0 && p.y > 60.0 && p.y < 150.0;
#endif
}
float portalPhysicalSide(vec3 p) { return step(TWIN_SPLIT, p.x); }
vec3 portalSceneLocal(vec3 p) { p.x -= portalPhysicalSide(p) * TWIN_X; return p; }
float portalViewSide(vec3 camera, vec3 eye) {
    vec4 state = texelFetch(colortex4, ivec2(0, 0), 0);
    vec4 memory = texelFetch(colortex4, ivec2(1, 0), 0);
    float physical = portalPhysicalSide(camera);
    if (abs(state.w - 1907.0) >= 0.1 || !portalSceneCamera(camera) || abs(state.y - physical) > 0.5) return physical;
    float home = state.x;
    // Also cover a camera update occurring after the begin pass: never expose an
    // old-palette frame while the server acknowledgement is still in flight.
    float dy = eye.y - state.z;
    if (memory.w > 0.5 && memory.w < 1.5 && abs(dy) > 1e-7) {
        float u = (PORTAL_Y - state.z) / dy;
        vec3 local = portalSceneLocal(eye);
        vec2 hit = mix(memory.xy, local.xz, u);
        if (u > 0.0 && u <= 1.0 && length(vec3(local.x - memory.x, dy, local.z - memory.y)) < 8.0
            && portalOpeningCell(hit)) home = 1.0 - home;
    }
    return home;
}
vec3 portalProjectPosition(vec3 world, vec3 camera) {
    if (portalSceneCamera(camera) && portalSceneGeometry(world))
        world.x -= (portalPhysicalSide(world) - portalPhysicalSide(camera)) * TWIN_X;
    return world;
}
bool portalRayCrosses(vec3 point, vec3 eye, vec3 camera) {
    if (!portalFrontFacing(eye) || point.y >= PORTAL_Y - 0.00001) return false;
    float u = (PORTAL_Y - eye.y) / (point.y - eye.y);
    vec3 hit = mix(eye, point, u);
    hit.x -= portalPhysicalSide(camera) * TWIN_X;
    return portalOpeningCell(hit.xz);
}
float portalPixelSide(vec3 alignedPoint, vec3 eye, vec3 camera) {
    float home = portalViewSide(camera, eye);
    return portalRayCrosses(alignedPoint, eye, camera) ? 1.0 - home : home;
}
bool portalGeometryNeeded(vec3 world, vec3 eye, vec3 camera, mat4 viewProjection) {
    if (!portalSceneCamera(camera) || !portalSceneGeometry(world)) return true;
    if (abs(portalPhysicalSide(world) - portalViewSide(camera, eye)) < 0.1) return true;
    return portalFrontInView(eye, camera, viewProjection);
}
bool portalFragmentVisible(vec3 world, vec3 eye, vec3 camera) {
    if (!portalSceneCamera(camera) || !portalSceneGeometry(world)) return true;
    vec3 aligned = portalProjectPosition(world, camera);
    return abs(portalPhysicalSide(world) - portalPixelSide(aligned, eye, camera)) < 0.1;
}
#endif
