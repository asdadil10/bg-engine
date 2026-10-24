// halftone.frag  —  NerveCenter Halftone Dot Screen
//
// 45°-rotated monochrome halftone raster in pixel space.
// Transparent between dots so underlying glass blur and wallpaper show through.
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
    vec4  p0;   // .x = cellSize (px), .y = dot opacity
    vec4  p1;
    vec4  p2;
    vec4  p3;
    vec4  c0;   // dot colour
    vec4  c1;
    vec4  c2;
};

layout(binding = 1) uniform sampler2D source;

const float SIN45 = 0.70710678;
const float COS45 = 0.70710678;

void main() {
    float cell = max(p0.x, 2.0);

    // Fragment in pixel space
    vec2 frag = vec2(gl_FragCoord.x, u_resolution.y - gl_FragCoord.y);

    // Rotate 45° in pixel space
    vec2 rot = vec2(
        COS45 * frag.x - SIN45 * frag.y,
        SIN45 * frag.x + COS45 * frag.y
    );

    // Cell origin and centre in rotated space
    vec2 cellOrigin = floor(rot / cell) * cell;
    vec2 rotCentre  = cellOrigin + vec2(cell * 0.5);

    // Rotate centre BACK to screen pixel space
    vec2 screenCentre = vec2(
         COS45 * rotCentre.x + SIN45 * rotCentre.y,
        -SIN45 * rotCentre.x + COS45 * rotCentre.y
    );

    // Sample source at cell centre
    vec2 centreUV  = screenCentre / u_resolution;
    centreUV.y     = 1.0 - centreUV.y;
    centreUV       = clamp(centreUV, vec2(0.0), vec2(1.0));
    vec4 cellColor = texture(source, centreUV);
    float luma     = dot(cellColor.rgb, vec3(0.299, 0.587, 0.114));

    // Dot radius: dark areas get bigger dots
    float maxRadius = cell * SIN45 * 0.5;
    float dotRadius = (1.0 - luma) * maxRadius;

    // Distance from rotated cell centre
    float dist = length(rot - rotCentre);

    // AA mask for the dot
    float mask = 1.0 - smoothstep(dotRadius - 0.75, dotRadius + 0.75, dist);

    // Output transparent between dots!
    float a = clamp(mask * c0.a * 0.70, 0.0, 1.0);
    fragColor = vec4(c0.rgb * a, a) * qt_Opacity;
}
