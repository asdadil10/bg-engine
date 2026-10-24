// streak_thresh.frag  —  Anamorphic Streak: Pass 1 — Luma Threshold & Gain
//
// Extracts bright pixels above threshold and scales them by LDR gain.
// Renders into a 4× horizontally downsampled FBO (set by compositor).
//
// Uses scalar luma thresholding so the colour hue is preserved without fringing.
//
// Params:
//   p0.x  threshold  (0.5 – 0.98)
//   p0.z  ldrGain    (1.0 – 5.0) — boosts faint highlights on standard 8-bit wallpapers
//   c0    tint        — streak colour to mix into highlights

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

layout(binding = 1) uniform sampler2D source;

void main() {
    vec4 src  = texture(source, qt_TexCoord0);
    float luma = dot(src.rgb, vec3(0.299, 0.587, 0.114));

    // Soft knee: smoothstep instead of hard cutoff to avoid ringing at threshold
    float knee = 0.05;
    float t = smoothstep(p0.x - knee, p0.x + knee, luma);

    // Preserve colour, scale by excess brightness above threshold + gain
    vec3 bright = src.rgb * t * p0.z;

    // Mix in tint colour on highlighted areas
    bright = mix(bright, bright * c0.rgb, t * 0.4);

    fragColor = vec4(bright, t) * qt_Opacity;
}
