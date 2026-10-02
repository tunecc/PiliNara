#version 320 es
precision highp float;
uniform sampler2D uTexture;
uniform vec2 uTextureSize;
uniform float uSharpness;
in vec2 uv;
out vec4 color;
void main() {
    vec2 stepSize = 1.0 / uTextureSize;
    vec3 b = texture(uTexture, uv - vec2(0, stepSize.y)).rgb;
    vec3 d = texture(uTexture, uv - vec2(stepSize.x, 0)).rgb;
    vec3 e = texture(uTexture, uv).rgb;
    vec3 f = texture(uTexture, uv + vec2(stepSize.x, 0)).rgb;
    vec3 h = texture(uTexture, uv + vec2(0, stepSize.y)).rgb;
    vec3 minimum = min(min(b, d), min(f, h));
    vec3 maximum = max(max(b, d), max(f, h));
    vec3 hitMin = min(minimum, e) / max(4.0 * maximum, vec3(1e-5));
    vec3 hitMax = (vec3(1.0) - max(maximum, e)) / min(4.0 * minimum - vec3(4.0), vec3(-1e-5));
    vec3 lobes = max(-hitMin, hitMax);
    float lobe = max(-0.1875, min(max(lobes.r, max(lobes.g, lobes.b)), 0.0)) * exp2(-clamp(uSharpness, 0.0, 2.0));
    color = vec4(clamp((lobe*(b+d+f+h)+e)/(4.0*lobe+1.0), 0.0, 1.0), 1.0);
}
