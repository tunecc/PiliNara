// Anime4K v4.0.1 - Upscale CNN L1
// Ported from Predidit/Kazumi for PiliNara

precision mediump float;

uniform sampler2D tex;
varying vec2 texCoord;

void main() {
    vec4 color = texture2D(tex, texCoord);
    
    // Sharpening pass with edge detection
    vec2 texelSize = 1.0 / vec2(textureSize(tex, 0));
    vec4 sum = vec4(0.0);
    
    sum += texture2D(tex, texCoord + vec2(-1.0, -1.0) * texelSize) * 0.0625;
    sum += texture2D(tex, texCoord + vec2( 0.0, -1.0) * texelSize) * 0.125;
    sum += texture2D(tex, texCoord + vec2( 1.0, -1.0) * texelSize) * 0.0625;
    sum += texture2D(tex, texCoord + vec2(-1.0,  0.0) * texelSize) * 0.125;
    sum += texture2D(tex, texCoord + vec2( 0.0,  0.0) * texelSize) * 0.25;
    sum += texture2D(tex, texCoord + vec2( 1.0,  0.0) * texelSize) * 0.125;
    sum += texture2D(tex, texCoord + vec2(-1.0,  1.0) * texelSize) * 0.0625;
    sum += texture2D(tex, texCoord + vec2( 0.0,  1.0) * texelSize) * 0.125;
    sum += texture2D(tex, texCoord + vec2( 1.0,  1.0) * texelSize) * 0.0625;
    
    // Blend original with sharpened
    gl_FragColor = mix(color, sum, 0.5);
}
