// ascii.frag  —  NerveCenter Technical ASCII Art Shader
//
// Migrated to standardized UBO (p0..p3, c0..c2) for compatibility with
// NerveShaderLayer.qml wrapper and the registry.
//
// Params:
//   u_charSize (via p0.xy) — char cell size in pixels (default 8x12)
//   c0         — density ramp color (accent, e.g. cyan)
//   c1         — edge contour color (highlight, e.g. magenta)
//
// Algorithm:
//   1. Compute Sobel gradient per character cell (5 luma samples).
//   2. High-gradient cells → directional contour runes (|, /, \, -) in c1.
//   3. Low-gradient cells → 12-level density ramp in c0.
//   4. Sub-pixel atlas UV lookup into 16-glyph texture strip.
//   5. Cathode scanline etching inside glyph pixel area.
//   6. Transparent gap between glyphs so underlying blur is visible.
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
    // p0.x = char width (px), p0.y = char height (px)
    vec4  p0;
    vec4  p1;
    vec4  p2;
    vec4  p3;
    vec4  c0;   // density / fill colour (accent)
    vec4  c1;   // edge contour colour (highlight)
    vec4  c2;
};

layout(binding = 1) uniform sampler2D source;
layout(binding = 2) uniform sampler2D asciiAtlas;   // 16-glyph horizontal strip

float luma(vec2 uv) {
    return dot(texture(source, uv).rgb, vec3(0.299, 0.587, 0.114));
}

void main() {
    vec2 charSize = vec2(max(p0.x, 2.0), max(p0.y, 2.0));
    vec2 totalChars = floor(u_resolution / charSize);
    if (totalChars.x <= 0.0 || totalChars.y <= 0.0) { fragColor = vec4(0.0); return; }

    vec2 charCoord    = floor(qt_TexCoord0 * totalChars);
    vec2 cellCenterUV = (charCoord + 0.5) / totalChars;
    vec2 stepUV       = 1.0 / totalChars;

    // 5 luma samples for Sobel (centre + 4 neighbours)
    float lumaC = luma(cellCenterUV);
    float lumaL = luma(cellCenterUV - vec2(stepUV.x, 0.0));
    float lumaR = luma(cellCenterUV + vec2(stepUV.x, 0.0));
    float lumaT = luma(cellCenterUV - vec2(0.0, stepUV.y));
    float lumaB = luma(cellCenterUV + vec2(0.0, stepUV.y));

    float dX = lumaR - lumaL;
    float dY = lumaB - lumaT;
    // Divide by 2 for reasonable [0,1] range
    float edgeMag = length(vec2(dX, dY)) * 0.5;

    float glyphIndex = 0.0;
    vec4  glyphColor = c0;

    if (edgeMag > 0.12) {
        // Edge contour: pick directional rune and use highlight colour
        float blend = smoothstep(0.12, 0.35, edgeMag);
        glyphColor  = mix(c0, c1, blend);

        float absDX = abs(dX);
        float absDY = abs(dY);
        if (absDY > absDX * 1.8) {
            glyphIndex = 4.0;    // '-'  horizontal edge
        } else if (absDX > absDY * 1.8) {
            glyphIndex = 8.0;    // '|'  vertical edge
        } else if ((dX > 0.0 && dY > 0.0) || (dX < 0.0 && dY < 0.0)) {
            glyphIndex = 9.0;    // '/'  diagonal
        } else {
            glyphIndex = 10.0;   // '\'  anti-diagonal
        }
    } else {
        // Density ramp: 12 levels across luminance
        float q = clamp(lumaC, 0.0, 0.999);
        if      (q < 0.05) glyphIndex =  0.0;
        else if (q < 0.12) glyphIndex =  1.0;
        else if (q < 0.20) glyphIndex =  2.0;
        else if (q < 0.28) glyphIndex =  3.0;
        else if (q < 0.36) glyphIndex =  5.0;
        else if (q < 0.44) glyphIndex =  6.0;
        else if (q < 0.52) glyphIndex =  7.0;
        else if (q < 0.62) glyphIndex = 11.0;
        else if (q < 0.72) glyphIndex = 12.0;
        else if (q < 0.82) glyphIndex = 13.0;
        else if (q < 0.92) glyphIndex = 14.0;
        else               glyphIndex = 15.0;
    }

    // Sub-pixel position within character cell
    vec2 localUV   = fract(qt_TexCoord0 * totalChars);
    vec2 atlasUV   = vec2((glyphIndex + localUV.x) / 16.0, localUV.y);
    float glyphA   = texture(asciiAtlas, atlasUV).a;

    // Cathode scanline etching — low-frequency cosine inside each glyph cell
    float scanline = 0.85 + 0.15 * cos(localUV.y * 6.28318 * 6.0);
    glyphA *= scanline;

    // Transparent between glyphs — lets underlying blur/glass show through
    fragColor = glyphColor * glyphA * qt_Opacity;
}
