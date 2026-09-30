// Shared lumpy puff: cheap 3D value noise, per-instance progress drives a scissor dissolve.
instance uniform float progress = 0.0;
instance uniform vec4 tint : source_color = vec4(1.0);
instance uniform float seed = 0.0;
varying vec3 local;
float hash3(vec3 p){p=fract(p*.3183099+.1);p*=17.0;return fract(p.x*p.y*p.z*(p.x+p.y+p.z));}
float noise3(vec3 x){
 vec3 i=floor(x);vec3 f=fract(x);f=f*f*(3.0-2.0*f);
 return mix(mix(mix(hash3(i),hash3(i+vec3(1,0,0)),f.x),mix(hash3(i+vec3(0,1,0)),hash3(i+vec3(1,1,0)),f.x),f.y),
            mix(mix(hash3(i+vec3(0,0,1)),hash3(i+vec3(1,0,1)),f.x),mix(hash3(i+vec3(0,1,1)),hash3(i+vec3(1,1,1)),f.x),f.y),f.z);
}
// Call as: local=VERTEX*2.0; VERTEX+=NORMAL*puff_offset(local);
float puff_offset(vec3 p){return (noise3(p*2.0+seed*7.3)-.45)*.26;}
float puff_mask(vec3 p){
 return noise3(p*3.0+seed*13.1)*.68+noise3(p*6.5-seed*5.7)*.32;
}
