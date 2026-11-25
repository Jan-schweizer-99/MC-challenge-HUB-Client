
out vec2 texcoord;
#ifdef PVP_WORLD
uniform mat4 gbufferModelView;
uniform mat4 gbufferProjection;
uniform vec3 cameraPosition;
#include "/lib/common.glsl"
#include "/lib/fx_view.glsl"
flat out int fxSeen;                                   // ein Bit je Effekt-Bereich im Blickfeld

bool fxInView(int i, mat4 m, vec3 cam) {
    // Kiste ist nur dann sicher unsichtbar, wenn alle Ecken hinter derselben Bildebene liegen
    ivec4 side = ivec4(0); int behind = 0;
    for (int k = 0; k < 8; k++) {
        vec3 corner = mix(FXV_LO[i], FXV_HI[i], vec3(float(k & 1), float(k >> 1 & 1), float(k >> 2 & 1)));
        vec4 c = m * vec4(corner - cam, 1.0);
        side += ivec4(c.x < -c.w, c.x > c.w, c.y < -c.w, c.y > c.w);
        if (c.w <= 0.0) behind++;
    }
    return behind < 8 && side.x < 8 && side.y < 8 && side.z < 8 && side.w < 8;
}

// Gleiche Entfernungen (mit Reserve) wie am Anfang von hub, temple, lobby, hall und arena
bool fxNear(int i, vec3 cam) {
    vec3 c = i <= FXV_AURORA ? vec3(0.0, 100.0, -455.0) : i <= FXV_BEAM ? vec3(0.5, 104.0, -343.5) : i == FXV_LOBBY ? vec3(0.5, 101.0, -399.5)
        : i == FXV_ARENA ? vec3(0.5, 101.0, 0.5) : vec3(0.5, 104.0, -554.5);
    float R = i <= FXV_AURORA ? 175.0 : i <= FXV_BEAM ? 155.0 : i == FXV_LOBBY ? 135.0 : i == FXV_ARENA ? 95.0 : 165.0;
    return length(cam.xz - c.xz) < R && abs(cam.y - c.y) < 130.0;
}
#endif

void main() {
    gl_Position = ftransform();
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
#ifdef PVP_WORLD
    mat4 m = gbufferProjection * gbufferModelView;
    vec3 local = cameraPosition;                        // Arena-Kiste liegt in Insel-Koordinaten
    local.x -= arenaOffsetX(arenaSideAt(cameraPosition));
    fxSeen = 0;
    for (int i = 0; i < FXV_COUNT; i++) if (fxNear(i, i == FXV_ARENA ? local : cameraPosition) && fxInView(i, m, i == FXV_ARENA ? local : cameraPosition)) fxSeen |= 1 << i;
#endif
}
