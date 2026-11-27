#version 450

// DMS's lyrics_fill.frag, plus sung glyphs float: everything behind the fill edge sits lifted, the
// glyphs at the edge rise along a soft ramp, and a faint highlight rides the edge.

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
    float liftEdge;
    float ramp;
} ubuf;

layout(binding = 1) uniform sampler2D source;

void main() {
    float x = mix(qt_TexCoord0.x, 1.0 - qt_TexCoord0.x, ubuf.rtl);
    float d = (x - ubuf.liftEdge) / max(ubuf.ramp, 1e-4);
    float up = 1.0 - smoothstep(-1.0, 0.0, d);
    float shine = exp(-d * d * 2.0) * step(0.0, ubuf.liftEdge);
    vec2 uv = vec2(qt_TexCoord0.x, qt_TexCoord0.y + ubuf.lift * up);
    float lit = 1.0 - smoothstep(ubuf.edge, ubuf.edge + ubuf.feather, x);
    vec4 color = mix(ubuf.restColor, ubuf.fillColor, lit);
    color.rgb = mix(color.rgb, vec3(color.a), 0.16 * shine * step(1e-4, ubuf.lift));
    fragColor = color * texture(source, uv).a * ubuf.qt_Opacity;
}
