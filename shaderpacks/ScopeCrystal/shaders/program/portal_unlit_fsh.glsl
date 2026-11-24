#define PORTAL_BEACON
#include "/lib/common.glsl"
uniform sampler2D gtexture;
uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;
in vec2 texcoord;
in vec4 glcolor;
in vec3 worldPos;
layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outData;
layout(location = 2) out vec4 outLight;
void main() {
    if (!portalFragmentVisible(worldPos, cameraPosition + gbufferModelViewInverse[3].xyz, cameraPosition)) discard;
    vec4 c = texture(gtexture, texcoord) * glcolor;
    if (c.a < 0.01) discard;
    outColor = c;
    outData = vec4(0.0, 0.0, 0.0, 0.0);
    outLight = vec4(0.0, 1.0, 0.0, 1.0);
}
