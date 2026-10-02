#version 320 es
precision highp float;
uniform sampler2D uTexture;
uniform vec2 uInputSize;
uniform vec2 uOutputSize;
uniform float uSharpness;
in vec2 uv;
out vec4 color;
vec3 tap(vec2 coord) { return texture(uTexture, coord).rgb; }
float luma(vec3 c) { return c.g + 0.5 * (c.r + c.b); }
void accumulateDirection(inout vec2 dir, inout float edge, vec2 weight, float a, float b, float c_, float d, float e) {
    float w = weight.x * weight.y;
    float dx0 = d - c_; float dx1 = c_ - b;
    float dy0 = e - c_; float dy1 = c_ - a;
    dir += vec2(d - b, e - a) * w;
    edge += (pow(clamp(abs(d - b) / max(max(abs(dx0), abs(dx1)), 1e-5), 0.0, 1.0), 2.0) +
        pow(clamp(abs(e - a) / max(max(abs(dy0), abs(dy1)), 1e-5), 0.0, 1.0), 2.0)) * w;
}
void main() {
    vec2 position = uv * uInputSize - 0.5;
    vec2 base = floor(position);
    vec2 fraction = position - base;
    vec3 b=tap((base+vec2(0,-1)+0.5)/uInputSize), c=tap((base+vec2(1,-1)+0.5)/uInputSize);
    vec3 e=tap((base+vec2(-1,0)+0.5)/uInputSize), f=tap((base+vec2(0,0)+0.5)/uInputSize);
    vec3 g=tap((base+vec2(1,0)+0.5)/uInputSize), h=tap((base+vec2(2,0)+0.5)/uInputSize);
    vec3 i=tap((base+vec2(-1,1)+0.5)/uInputSize), j=tap((base+vec2(0,1)+0.5)/uInputSize);
    vec3 k=tap((base+vec2(1,1)+0.5)/uInputSize), l=tap((base+vec2(2,1)+0.5)/uInputSize);
    vec3 n=tap((base+vec2(0,2)+0.5)/uInputSize), o=tap((base+vec2(1,2)+0.5)/uInputSize);
    vec2 direction=vec2(0.0); float edge=0.0;
    accumulateDirection(direction,edge,vec2(1.0-fraction.x,1.0-fraction.y),luma(b),luma(e),luma(f),luma(g),luma(j));
    accumulateDirection(direction,edge,vec2(fraction.x,1.0-fraction.y),luma(c),luma(f),luma(g),luma(h),luma(k));
    accumulateDirection(direction,edge,vec2(1.0-fraction.x,fraction.y),luma(f),luma(i),luma(j),luma(k),luma(n));
    accumulateDirection(direction,edge,vec2(fraction.x,fraction.y),luma(g),luma(j),luma(k),luma(l),luma(o));
    float magnitude=dot(direction,direction);
    direction=magnitude < 0.0000305 ? vec2(1.0,0.0) : normalize(direction);
    edge=pow(clamp(edge*0.5,0.0,1.0),2.0);
    float stretch=(dot(direction,direction))/max(max(abs(direction.x),abs(direction.y)),1e-5);
    vec2 length=vec2(mix(1.0,stretch,edge),mix(1.0,0.5,edge));
    float lobe=mix(0.5,0.21,edge), clipPoint=1.0/lobe;
    vec3 min4=min(min(f,g),min(j,k)), max4=max(max(f,g),max(j,k));
    vec3 sum=vec3(0.0); float sumWeight=0.0;
    #define ADD_TAP(offset, sample) { vec2 rotated = vec2(dot(offset, direction), dot(offset, vec2(-direction.y, direction.x))) * length; float distance2 = min(dot(rotated, rotated), clipPoint); float base2 = 0.4 * distance2 - 1.0; float window = lobe * distance2 - 1.0; float weight = (1.5625 * base2 * base2 - 0.5625) * window * window; sum += sample * weight; sumWeight += weight; }
    ADD_TAP(vec2(0,-1)-fraction, b); ADD_TAP(vec2(1,-1)-fraction, c);
    ADD_TAP(vec2(-1,0)-fraction, e); ADD_TAP(vec2(0,0)-fraction, f);
    ADD_TAP(vec2(1,0)-fraction, g); ADD_TAP(vec2(2,0)-fraction, h);
    ADD_TAP(vec2(-1,1)-fraction, i); ADD_TAP(vec2(0,1)-fraction, j);
    ADD_TAP(vec2(1,1)-fraction, k); ADD_TAP(vec2(2,1)-fraction, l);
    ADD_TAP(vec2(0,2)-fraction, n); ADD_TAP(vec2(1,2)-fraction, o);
    #undef ADD_TAP
    color=vec4(clamp(sum/max(sumWeight,1e-5),min4,max4),1.0);
}
