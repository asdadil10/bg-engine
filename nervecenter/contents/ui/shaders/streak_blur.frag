// streak_blur.frag  —  Anamorphic Streak: Pass 2 — Horizontal Lorentzian Blur
//
// Samples the 4×-downsampled threshold output with 17 paired bilinear taps,
// Lorentzian (Cauchy) falloff weights, spaced at 2-texel stride on the
// downsampled buffer — equivalent to 8-texel stride on the original image.
// This gives an effective streak length of 17 × 8 × (step in px) without
// needing 80+ texture fetches on the full-res image.
//
// "Bilinear pairing": each tap samples at a half-pixel offset to exploit
// hardware bilinear interpolation, effectively doubling the blur coverage
// per tap at no extra cost (2 samples per fetch).
//
// Params:
//   p0.y  spread  — streak half-length in full-resolution pixels (4–64)
//   p0.x  threshold — passed through, not used here
//
// The input texture is downsampled 4×, so texel stride = (spread/4) / 17 texels
// across the downsampled width.

#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4  qt_Matrix;
    float qt_Opacity;
    vec2  u_resolution;   // downsampled resolution
    vec2  u_texelSize;    // 1/u_resolution
    vec4  p0;
    vec4  p1;
    vec4  p2;
    vec4  p3;
    vec4  c0;
    vec4  c1;
    vec4  c2;
};

layout(binding = 1) uniform sampler2D source;   // 4× downsampled threshold output

void main() {
    // Streak half-length in downsampled texels
    // p0.y is full-res pixels; divide by 4 for downsample factor, then by 17 taps
    float halfLen = (p0.y / 4.0) * u_texelSize.x;
    float sigma   = halfLen * 0.5;   // Lorentzian half-width

    vec3  color  = vec3(0.0);
    float totalW = 0.0;

    // 17 paired bilinear taps from -8 to +8 in tap units
    for (int i = 0; i < 17; i++) {
        float k  = float(i) - 8.0;

        // Bilinear pairing: sample at k+0.5 texel offset to use hardware interp
        float offset = (k + 0.5) * halfLen / 8.0;

        // Lorentzian weight: w = 1 / (1 + (k/sigma)^2)
        float s = k / max(sigma * 8.0, 0.0001);
        float w = 1.0 / (1.0 + s * s);

        vec2  uv = qt_TexCoord0 + vec2(offset, 0.0);
        color   += texture(source, uv).rgb * w;
        totalW  += w;
    }

    color /= max(totalW, 0.0001);
    fragColor = vec4(color, 1.0) * qt_Opacity;
}
