// SDR to HDR Tone Mapping Shader
// Converts SDR (Rec.709) content to HDR (Rec.2020 PQ) color space
// Based on BT.2087 inverse tone mapping
// Ported from feice11/PiliPlus-SDR2HDR

precision mediump float;

uniform sampler2D tex;
varying vec2 texCoord;

// Rec.709 to linear RGB
vec3 rec709ToLinear(vec3 c) {
    return mix(
        c / 4.5,
        pow((c + 0.055) / 1.055, vec3(2.4)),
        step(0.081, c)
    );
}

// Linear RGB to Rec.2020 PQ (HDR10)
vec3 linearToPQ(vec3 c) {
    const float m1 = 0.1593017578125;
    const float m2 = 78.84375;
    const float c1 = 0.8359375;
    const float c2 = 18.8515625;
    const float c3 = 18.6875;
    
    vec3 cm = pow(c, vec3(m1));
    return pow((c1 + c2 * cm) / (1.0 + c3 * cm), vec3(m2));
}

// Inverse tone mapping: expand SDR luminance range
vec3 inverseToneMap(vec3 c) {
    float lum = dot(c, vec3(0.2126, 0.7152, 0.0722));
    float expandedLum = lum / (1.0 - lum * 0.5);
    expandedLum = clamp(expandedLum, 0.0, 10.0);
    
    if (lum > 0.001) {
        return c * (expandedLum / lum);
    }
    return c;
}

void main() {
    vec4 color = texture2D(tex, texCoord);
    
    // Step 1: Decode from Rec.709 gamma to linear
    vec3 linear = rec709ToLinear(color.rgb);
    
    // Step 2: Apply inverse tone mapping to expand dynamic range
    vec3 expanded = inverseToneMap(linear);
    
    // Step 3: Encode to PQ (HDR10 transfer function)
    vec3 pq = linearToPQ(expanded);
    
    gl_FragColor = vec4(pq, color.a);
}
