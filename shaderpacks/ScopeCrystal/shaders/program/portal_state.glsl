#include "/lib/common.glsl"
#include "/lib/arena_paths.glsl"
#include "/lib/places.glsl"
#include "/lib/objects_spec.glsl"
uniform float frameTimeCounter;
uniform vec3 cameraPosition;
uniform mat4 gbufferModelViewInverse;
uniform float frameTime;
layout(location = 0) out vec4 outState;
void main() {
    // Alles ausser den zwei Zustands-Texeln: Bahnen der Arena-Effekte fuer diesen Frame
    ivec2 px = ivec2(gl_FragCoord.xy);
    if (px.y == 0 && px.x >= 2 && px.x <= 7) {              // Voxel-Objekte: Sekunden seit der Ankunft je Ort (hoch beim Dasein, schnell runter beim Gehen)
        int p = px.x - 2;
        vec4 h = texelFetch(colortex4, px, 0);
        float s = abs(h.w - 2611.0) < 0.1 ? h.x : 0.0;
        bool here = objOn(p) && length(cameraPosition.xz - placeCenter(p).xz) < objRange(p);
        s = clamp(s + min(frameTime, 0.1) * (here ? 1.0 : -2.0), 0.0, OBJ_FULL);
        outState = vec4(s, 0.0, 0.0, 2611.0);
        return;
    }
    if (px.y > 0 || px.x > 1) { outState = arenaCacheTexel(px, frameTimeCounter); return; }
    vec4 old = texelFetch(colortex4, ivec2(0, 0), 0);
    vec4 memory = texelFetch(colortex4, ivec2(1, 0), 0);
    vec3 eye = cameraPosition + gbufferModelViewInverse[3].xyz;
    vec3 local = portalSceneLocal(eye);
    float physical = portalPhysicalSide(cameraPosition);
    bool active = portalSceneCamera(cameraPosition);
    bool valid = abs(old.w - 1907.0) < 0.1 && memory.w > 0.5;
    bool acknowledged = valid && abs(old.y - physical) > 0.5;
    float home = valid && !acknowledged ? old.x : physical;
    float pending = valid ? memory.z : 0.0;
    bool wasLocked = valid && memory.w > 1.5;
    bool armed = valid ? !wasLocked : abs(eye.y - PORTAL_Y) > 0.25;
    if (wasLocked && (abs(eye.y - PORTAL_Y) > 0.25 || length(local.xz - vec2(0.5)) > 5.2)) armed = true;
    if (valid && !acknowledged && active && !wasLocked && armed) {
        float dy = eye.y - old.z;
        if (abs(dy) > 1e-7) {
            float u = (PORTAL_Y - old.z) / dy;
            vec2 hit = mix(memory.xy, local.xz, u);
            bool shortMove = length(vec3(local.x - memory.x, dy, local.z - memory.y)) < 8.0;
            if (u > 0.0 && u <= 1.0 && shortMove && portalOpeningCell(hit)) { home = 1.0 - home; armed = false; }
        }
    }
    if (!active) home = physical;
    pending = abs(home - physical) > 0.5 ? pending + max(frameTime, 0.0) : 0.0;
    if (pending > 2.0) { home = physical; pending = 0.0; }
    outState = int(gl_FragCoord.x) == 0 ? vec4(home, physical, eye.y, 1907.0)
        : vec4(local.xz, pending, active ? (armed ? 1.0 : 2.0) : 0.0);
}
