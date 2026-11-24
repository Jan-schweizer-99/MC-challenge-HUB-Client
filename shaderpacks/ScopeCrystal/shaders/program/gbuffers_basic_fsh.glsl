
in vec4 glcolor;

layout(location = 0) out vec4 outColor;

void main() {
    if (glcolor.a < 0.01) discard;
    outColor = glcolor;
}
