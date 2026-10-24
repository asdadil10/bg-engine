// streak_comp.frag  —  Anamorphic Streak: Pass 3 — Composite onto Source
//
// Upsamples and additively composites the blurred streak buffer onto the
// original source image.  Additive blending is correct here: streaks should
// only ADD light, never darken.  Bilinear hardware upsampling is free.
//
// Params: (none used beyond standard UBO)

#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4  qt_Matrix;
    float qt_Opacity;
    vec2  u_resolution;
    vec2  u_texelSize;
    vec4  p0;
    vec4  p1;
    vec4  p2;
    vec4  p3;
    vec4  c0;
    vec4  c1;
    vec4  c2;
};

layout(binding = 1) uniform sampler2D source;      // Original wallpaper
layout(binding = 2) uniform sampler2D u_streakTex; // Blurred streak buffer (4× upsampled by hardware)

void main() {
    vec3 base   = texture(source,      qt_TexCoord0).rgb;
    vec3 streak = texture(u_streakTex, qt_TexCoord0).rgb;

    // Additive composite: streaks add light, never subtract
    vec3 result = clamp(base + streak, 0.0, 1.0);

    fragColor = vec4(result, 1.0) * qt_Opacity;
}
