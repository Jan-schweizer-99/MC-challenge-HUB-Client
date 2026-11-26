// Ausgabe: Vanilla-Bild bleibt unveraendert (alle Werte <= 1).
// Nur wo Arena-Effekte Licht ueber 1 addieren, wird farbtreu zu Weiss hin abgefangen statt hart abgeschnitten.

uniform sampler2D colortex0;

#include "/lib/vr_cursor.glsl"

in vec2 texcoord;

layout(location = 0) out vec4 outColor;

void main() {
    vec3 c = texture(colortex0, texcoord).rgb;
    float peak = max(c.r, max(c.g, c.b));
    if (peak > 1.0) {
        float over = 1.0 - 1.0 / peak;                 // 0 bei 1, gegen 1 bei sehr hell
        c = mix(c / peak, vec3(1.0), over * 0.6);
    }
    c = clamp(c, 0.0, 1.0);
#ifdef VR_CURSOR
    c = vrCursor(c);
#endif
    outColor = vec4(c, 1.0);
}
