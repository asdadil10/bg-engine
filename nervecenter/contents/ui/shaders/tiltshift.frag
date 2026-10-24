// tiltshift.frag  —  NerveCenter Tilt-Shift Radial Bokeh Focus Mask
//
// Creates simulated depth-of-field: sharp translucency at panel center
// (where telemetry metrics sit) transitioning into deep bokeh blur towards
// the panel borders.
//
// Highlights are boosted (p0.w brightBoost) to produce authentic bokeh
// circles from LDR wallpapers.
//
// Standard UBO params:
//   p0.x  innerRadius  – normalized radius of sharp focus zone (0.0 – 0.8)
//   p0.y  outerRadius  – normalized radius where max blur is reached (0.1 – 1.0)
//   p0.z  maxBlur      – maximum blur radius in pixels (2.0 – 20.0)
//   p0.w  brightBoost  – highlight curve boost for bokeh discs (1.0 – 4.0)
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
    vec4  p0;  // .x innerRadius, .y outerRadius, .z maxBlur, .w brightBoost
    vec4  p1;
    vec4  p2;
    vec4  p3;
    vec4  c0;
    vec4  c1;
    vec4  c2;
};

layout(binding = 1) uniform sampler2D source;

// 9-tap rotated Poisson disc
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
    0.28,
    0.11, 0.11, 0.11, 0.11,
    0.07, 0.07, 0.07, 0.07
);

void main() {
    // Distance from panel center (aspect-corrected)
    vec2 centerOffset = qt_TexCoord0 - vec2(0.5, 0.5);
    float dist = length(centerOffset) * 2.0; // 0 at center, ~1.4 at corners

    // Circle of confusion factor (0 at center, 1 at perimeter)
    float coc = smoothstep(p0.x, max(p0.y, p0.x + 0.01), dist);

    float currentBlur = coc * p0.z;
    vec2 offset = u_texelSize * currentBlur;

    vec3 color = vec3(0.0);
    float totalW = 0.0;

    for (int i = 0; i < 9; i++) {
        vec2 uv = qt_TexCoord0 + DISC[i] * offset;
        vec3 s = texture(source, uv).rgb;

        // Bright-pass boost for authentic bokeh specular highlights
        float luma = dot(s, vec3(0.299, 0.587, 0.114));
        float boost = 1.0 + pow(luma, 3.0) * (p0.w - 1.0) * coc;
        vec3 boosted = s * boost;

        float w = W[i];
        color += boosted * w;
        totalW += w;
    }
    color /= totalW;

    fragColor = vec4(color, 1.0) * qt_Opacity;
}
