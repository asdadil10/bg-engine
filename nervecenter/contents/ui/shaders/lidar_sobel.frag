// lidar_sobel.frag  —  NerveCenter LiDAR / Sobel Wireframe Extractor
//
// Extracts edge contours from backdrop image.
// Negative space is TRANSPARENT (alpha = edgeAlpha) so underlying
// glass blur and wallpaper are visible between wireframe contours.
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
    vec4  p0;   // .x preBlur, .y threshold, .z thickness, .w bgDarken
    vec4  p1;
    vec4  p2;
    vec4  p3;
    vec4  c0;   // edge colour
    vec4  c1;
    vec4  c2;
};

layout(binding = 1) uniform sampler2D source;

float luma(vec2 uv) {
    vec4 c = texture(source, uv);
    return dot(c.rgb, vec3(0.299, 0.587, 0.114));
}

// 3-tap box pre-blur in one axis
float lumaBlurred(vec2 uv, vec2 step) {
    float r = max(p0.x, 1.0);
    return (luma(uv - step * r) + luma(uv) + luma(uv + step * r)) * (1.0 / 3.0);
}

void main() {
    vec2 ts = u_texelSize * max(p0.z, 1.0);

    // Pre-blurred luma at the 8 Sobel neighbours
    float tl = lumaBlurred(qt_TexCoord0 + vec2(-ts.x, -ts.y), u_texelSize);
    float tc = lumaBlurred(qt_TexCoord0 + vec2( 0.0,  -ts.y), u_texelSize);
    float tr = lumaBlurred(qt_TexCoord0 + vec2( ts.x, -ts.y), u_texelSize);
    float ml = lumaBlurred(qt_TexCoord0 + vec2(-ts.x,  0.0 ), u_texelSize);
    float mr = lumaBlurred(qt_TexCoord0 + vec2( ts.x,  0.0 ), u_texelSize);
    float bl = lumaBlurred(qt_TexCoord0 + vec2(-ts.x,  ts.y), u_texelSize);
    float bc = lumaBlurred(qt_TexCoord0 + vec2( 0.0,   ts.y), u_texelSize);
    float br = lumaBlurred(qt_TexCoord0 + vec2( ts.x,  ts.y), u_texelSize);

    // Sobel gradients normalized by 4
    float Gx = (-tl - 2.0*ml - bl + tr + 2.0*mr + br) * 0.25;
    float Gy = (-tl - 2.0*tc - tr + bl + 2.0*bc + br) * 0.25;
    float mag = sqrt(Gx*Gx + Gy*Gy);

    // Anti-aliased edge mask
    float thresh = max(p0.y, 0.05);
    float edgeAlpha = smoothstep(thresh - 0.04, thresh + 0.04, mag);

    // Output glowing vector edge lines with transparent space between edges
    float a = clamp(edgeAlpha * c0.a, 0.0, 1.0);
    fragColor = vec4(c0.rgb * a, a) * qt_Opacity;
}
