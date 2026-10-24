// blend.frag  —  NerveCenter Universal Ping-Pong Blend Stage (v2 Mathematical Fix)
// Modes: 0=Normal, 1=Additive, 2=Screen, 3=Multiply, 4=Overlay
//
// Key correctness fixes:
//  - Both base and layer are premultiplied in Qt Quick: unpremultiply both before mode math
//  - If base is transparent (base.a < 0.001), blend modes gracefully fall back to copy
//  - Non-Normal modes gated by layer.a so transparent areas never black out base
//  - Porter-Duff alpha union (not max) for exact alpha compositing
//  - Uses float arithmetic for mode selection (GLES 100 safe)
//  - No textureSize(), no fwidth(), no integer bit ops — GLES 100 safe

#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4  qt_Matrix;
    float qt_Opacity;
    vec2  u_resolution;
    vec2  u_texelSize;
    // p0.x = mode  (0:Normal, 1:Additive, 2:Screen, 3:Multiply, 4:Overlay)
    // p0.y = layer opacity (0.0 – 1.0)
    vec4  p0;
    vec4  p1;
    vec4  p2;
    vec4  p3;
    vec4  c0;
    vec4  c1;
    vec4  c2;
};

layout(binding = 1) uniform sampler2D u_baseTex;   // ping-pong accumulator
layout(binding = 2) uniform sampler2D u_layerTex;  // this layer's output

void main() {
    vec4 base  = texture(u_baseTex,  qt_TexCoord0);
    vec4 layer = texture(u_layerTex, qt_TexCoord0);

    // 1. Unpremultiply both inputs
    vec3 b = (base.a  > 0.001) ? (base.rgb  / base.a)  : vec3(0.0);
    vec3 l = (layer.a > 0.001) ? (layer.rgb / layer.a) : vec3(0.0);
    float a = clamp(layer.a * p0.y, 0.0, 1.0);

    // 2. Compute candidate modes in straight-color space
    float mode = p0.x;

    vec3 bNormal   = l;
    vec3 bAdd      = b + l;
    vec3 bScreen   = 1.0 - (1.0 - b) * (1.0 - l);
    vec3 bMultiply = b * l;
    vec3 bOverlay  = mix(2.0 * b * l,
                         1.0 - 2.0 * (1.0 - b) * (1.0 - l),
                         step(0.5, b));

    // Selection via step weights (GLES 100 compatible)
    float wN  = step(-0.5, mode) * step(mode,  0.5);
    float wA  = step( 0.5, mode) * step(mode,  1.5);
    float wSc = step( 1.5, mode) * step(mode,  2.5);
    float wM  = step( 2.5, mode) * step(mode,  3.5);
    float wOv = step( 3.5, mode);

    vec3 blended = bNormal   * wN
                 + bAdd      * wA
                 + bScreen   * wSc
                 + bMultiply * wM
                 + bOverlay  * wOv;

    // If base is empty, fall back to pure layer copy
    blended = mix(l, blended, step(0.001, base.a));

    // 3. Alpha-gated composite in straight space
    vec3 outRgb = mix(b, blended, a);

    // 4. Exact Porter-Duff alpha union
    float outA = clamp(base.a + a * (1.0 - base.a), 0.0, 1.0);

    // 5. Premultiply output to match Qt Quick internal texture format
    fragColor = vec4(outRgb * outA, outA) * qt_Opacity;
}
