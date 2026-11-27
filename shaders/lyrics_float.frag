#version 450

// DMS's lyrics_fill.frag, plus the word being sung floats up and brightens; the previous word settles back.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 restColor;
    vec4 fillColor;
    float edge;
    float feather;
    float rtl;
    float lift;
    float rise;
    vec2 current;
    vec2 previous;
} ubuf;

layout(binding = 1) uniform sampler2D source;

float inside(vec2 span, float x) {
    return step(span.x, x) * step(x, span.y);
}

void main() {
    float x = mix(qt_TexCoord0.x, 1.0 - qt_TexCoord0.x, ubuf.rtl);
    float up = ubuf.rise * inside(ubuf.current, x) + (1.0 - ubuf.rise) * inside(ubuf.previous, x);
    float lit = 1.0 - smoothstep(ubuf.edge, ubuf.edge + ubuf.feather, x);
    vec4 color = mix(ubuf.restColor, ubuf.fillColor, lit);
    color.rgb = mix(color.rgb, vec3(color.a), 0.18 * ubuf.rise * inside(ubuf.current, x));
    vec2 uv = vec2(qt_TexCoord0.x, qt_TexCoord0.y + ubuf.lift * up);
    fragColor = color * texture(source, uv).a * ubuf.qt_Opacity;
}
