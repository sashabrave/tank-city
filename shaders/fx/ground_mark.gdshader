shader_type spatial;
// Flat ground quad: kind 0 = expanding dust ring, kind 1 = soft scorch mark.
render_mode unshaded,cull_disabled,depth_draw_never,shadows_disabled;
instance uniform float progress = 0.0;
instance uniform vec4 tint : source_color = vec4(1.0);
instance uniform float seed = 0.0;
uniform int kind = 0;
float hash2(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise2(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);
 return mix(mix(hash2(i),hash2(i+vec2(1,0)),f.x),mix(hash2(i+vec2(0,1)),hash2(i+vec2(1,1)),f.x),f.y);}
void fragment(){
 vec2 p=UV*2.0-1.0;float r=length(p);
 float angle=atan(p.y,p.x);
 float wobble=noise2(vec2(angle*2.5+seed*9.0,seed))*.18;
 if(kind==0){
  float radius=mix(.15,.92,1.0-pow(1.0-progress,2.2));
  float ring=smoothstep(.2,0.0,abs(r+wobble*.5-radius))*(1.0-progress);
  ALBEDO=tint.rgb;ALPHA=ring*.9;
 }else{
  float blob=1.0-smoothstep(.5,.98,r+wobble*1.4);
  float speck=noise2(p*6.0+seed*3.0);
  ALBEDO=tint.rgb*(.8+speck*.3);ALPHA=blob*(.62+speck*.3)*(1.0-progress);
 }
}
