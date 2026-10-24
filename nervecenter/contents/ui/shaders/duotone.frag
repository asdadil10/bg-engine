// duotone.frag  —  NerveCenter Duotone Atmospheric Harmonizer
//
// Remaps backdrop luminance through a 3-stop piecewise palette to force any
// wallpaper into the active NerveCenter accent palette.
//
// The 3-stop gradient:
//   c2.rgb  — Void / Shadow colour (e.g. #08090d deep navy)
//   c1.rgb  — Primary Accent colour (e.g. #00f0ff cyan)
//   c0.rgb  — Highlight colour (e.g. #ff007f magenta)
//
// Params:
//   p0.x  contrast  – luminance gamma before gradient lookup (0.5–2.0, default 1.0)
//
// GLES 100 safe.

#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4  qt_Matrix;
    float qt_Opacity;
    vec2  u_resolution;
    vec2  u_texelSize;
    vec4  p0;   // .x = contrast
    vec4  p1;
    vec4  p2;
    vec4  p3;
    vec4  c0;   // Highlight colour
    vec4  c1;   // Accent / midpoint colour
    vec4  c2;   // Void / shadow colour
};

layout(binding = 1) uniform sampler2D source;

void main() {
    vec4 src  = texture(source, qt_TexCoord0);
    float luma = dot(src.rgb, vec3(0.299, 0.587, 0.114));

    // Contrast (power) remapping in [0,1]
    float t = clamp(pow(luma, 1.0 / max(p0.x, 0.01)), 0.0, 1.0);

    // Piecewise 3-stop gradient: c2 (shadow) -> c1 (accent) -> c0 (highlight)
    vec3 mapped = t < 0.5 ? mix(c2.rgb, c1.rgb, t * 2.0) : mix(c1.rgb, c0.rgb, (t - 0.5) * 2.0);

    fragColor = vec4(mapped, 1.0) * qt_Opacity;
}
