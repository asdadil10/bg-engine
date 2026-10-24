// prism_blur.frag  —  NerveCenter Optical Chromatic Dispersion Blur
// Migrated to standardized UBO: p0.x = blurRadius, p0.y = dispersion, c0 = glassTint
//
// 9-tap Poisson-disc kernel with per-channel RGB offset for chromatic separation.
// Each channel samples at a slightly different radial offset, simulating wavelength
// dispersion through thick optical glass.  Output alpha = 0.9 so base panel
// background colour bleeds through at 10%.
//
// GLES 100 safe: no textureSize, no fwidth, constant loop bounds.

#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4  qt_Matrix;
    float qt_Opacity;
    vec2  u_resolution;
    vec2  u_texelSize;   // 1.0 / u_resolution, pre-computed on QML side
    // p0.x = blur radius (pixels), p0.y = chromatic dispersion (pixels)
    vec4  p0;
    vec4  p1;
    vec4  p2;
    vec4  p3;
    vec4  c0;   // glass tint colour
    vec4  c1;
    vec4  c2;
};

layout(binding = 1) uniform sampler2D source;

// 9-tap rotated Poisson disc (unit circle), balanced weights
const vec2 DISC[9] = vec2[](
    vec2( 0.000,  0.000),
    vec2( 1.000,  0.000),
    vec2(-1.000,  0.000),
    vec2( 0.000,  1.000),
    vec2( 0.000, -1.000),
    vec2( 0.707,  0.707),
    vec2(-0.707,  0.707),
    vec2( 0.707, -0.707),
    vec2(-0.707, -0.707)
);
const float W[9] = float[](
    0.2500,
    0.1000, 0.1000, 0.1000, 0.1000,
    0.0625, 0.0625, 0.0625, 0.0625
);

void main() {
    vec2 offset = u_texelSize * p0.x;
    vec2 disp   = u_texelSize * p0.y;

    vec3 color = vec3(0.0);
    float totalW = 0.0;

    for (int i = 0; i < 9; i++) {
        vec2 d  = DISC[i];
        vec2 uv = qt_TexCoord0 + d * offset;
        float w = W[i];

        // Chromatic split: R shifted +disp, B shifted -disp along kernel direction
        float r = texture(source, uv + d * disp).r;
        float g = texture(source, uv).g;
        float b = texture(source, uv - d * disp).b;

        color  += vec3(r, g, b) * w;
        totalW += w;
    }
    color /= totalW;

    // Subtle accent-tinted frosted glass look
    vec3 tinted = mix(color, c0.rgb, 0.08);

    // Alpha 0.9 — lets base panel fill colour show faintly at edges
    fragColor = vec4(tinted, 0.92) * qt_Opacity;
}
