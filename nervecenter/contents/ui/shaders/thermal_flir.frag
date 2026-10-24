// thermal_flir.frag  —  NerveCenter Thermal FLIR Reconnaissance Shader
//
// Maps backdrop luminance through military Ironbow thermal LUT.
// Uses 0.50 alpha so underlying glass blur and panels remain readable.
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
    vec4  p0;   // .x = gain, .y = invert (0 or 1)
    vec4  p1;
    vec4  p2;
    vec4  p3;
    vec4  c0;
    vec4  c1;
    vec4  c2;
};

layout(binding = 1) uniform sampler2D source;
layout(binding = 2) uniform sampler2D u_lutTex;  // 256x1 Ironbow palette

void main() {
    vec4 src = texture(source, qt_TexCoord0);
    float luma = dot(src.rgb, vec3(0.299, 0.587, 0.114));

    // Apply gain and optional invert
    float gain = max(p0.x, 0.5);
    float t = clamp(luma * gain, 0.0, 1.0);
    t = mix(t, 1.0 - t, p0.y);

    // Half-texel-offset LUT sampling (linear, clamp-to-edge)
    float lutU = (t * 255.0 + 0.5) / 256.0;
    vec3 thermal = texture(u_lutTex, vec2(lutU, 0.5)).rgb;

    // Translucent HUD infrared tint (0.50 opacity)
    float a = 0.50;
    fragColor = vec4(thermal * a, a) * qt_Opacity;
}
