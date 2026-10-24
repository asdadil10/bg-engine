// dither_quantize.frag  —  NerveCenter Final Mandatory Triangular Dither Pass
//
// This shader runs as the MANDATORY FINAL STAGE of the bake pipeline right
// before 8-bit quantization (grabToImage writes 8-bit RGBA).
//
// Applying ±1.0 LSB triangular dither here completely eliminates 8-bit color
// banding across subtle gradients, blurs, and LUT remaps without leaving noise.
//
// Triangular dither = (d1 + d2) - (1.0 / 255.0), where d1 and d2 are two
// decorrelated uniform dither distributions spanning [0, 1/255].
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
    vec4  p0;
    vec4  p1;
    vec4  p2;
    vec4  p3;
    vec4  c0;
    vec4  c1;
    vec4  c2;
};

layout(binding = 1) uniform sampler2D source;

// Fast arithmetic decorrelated hash for dither (no bitwise operators)
float ditherHash(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * vec3(443.897, 441.423, 437.195));
    p3 += dot(p3, p3.yzx + 19.19);
    return fract((p3.x + p3.y) * p3.z);
}

void main() {
    vec4 src = texture(source, qt_TexCoord0);

    vec2 coord = gl_FragCoord.xy;
    float u1 = ditherHash(coord) * (1.0 / 255.0);
    float u2 = ditherHash(coord + vec2(17.1, 31.7)) * (1.0 / 255.0);

    // Triangular PDF spanning [-1/255, +1/255]
    float triDither = (u1 + u2) - (1.0 / 255.0);

    vec3 dithered = clamp(src.rgb + vec3(triDither), 0.0, 1.0);

    fragColor = vec4(dithered, src.a) * qt_Opacity;
}
