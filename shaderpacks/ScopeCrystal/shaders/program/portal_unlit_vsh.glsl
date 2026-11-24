#define PORTAL_BEACON
#include "/lib/common.glsl"
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;
out vec2 texcoord;
out vec4 glcolor;
out vec3 worldPos;
void main() {
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    glcolor = gl_Color;
    worldPos = (gbufferModelViewInverse * (gl_ModelViewMatrix * gl_Vertex)).xyz + cameraPosition;
    if (portalSceneCamera(cameraPosition)) {
        vec2 center = vec2(portalPhysicalSide(worldPos) * TWIN_X + 0.5, 0.5);
        vec2 offset = worldPos.xz - center;
        float radius = length(offset);
        if (radius > 0.000001 && radius < 2.0) {
            // MC 26.3 scales beam radii beyond 96m from the physical camera.
            // Undo that scaling for the two aligned central beacons. A core
            // vertex has radius .2; the translucent halo's corner is sqrt(2)*.25.
            bool halo = glcolor.a < 0.5;
            float canonicalRadius = halo ? 0.3535533906 : 0.2;
            float nativeScale = radius / canonicalRadius;
            worldPos.xz = center + offset / nativeScale;
            // The core's native V slope also depends on its widened radius.
            // Keep the scrolling texture continuous across the portal seam.
            if (!halo) texcoord.y += max(worldPos.y - 103.0, 0.0) * 2.5 * (1.0 - 1.0 / nativeScale);
        }
    }
    vec3 aligned = portalProjectPosition(worldPos, cameraPosition);
    gl_Position = gl_ProjectionMatrix * (gbufferModelView * vec4(aligned - cameraPosition, 1.0));
        if (!portalGeometryNeeded(worldPos, cameraPosition + gbufferModelViewInverse[3].xyz, cameraPosition,
                gl_ProjectionMatrix * gbufferModelView)) gl_Position = vec4(2.0, 2.0, 2.0, 1.0);
}
