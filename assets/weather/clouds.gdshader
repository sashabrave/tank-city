shader_type canvas_item;
render_mode unshaded;
uniform float elapsed=0.0;
uniform float coverage=0.08;
uniform float opacity=0.28;
uniform float drift_speed=0.012;
uniform float cycle_seconds=65.0;
uniform float minimum_activity=0.18;
uniform float seed_offset=0.0;
float puff(vec2 p){
 float a=exp(-dot(p*vec2(1.0,1.8),p*vec2(1.0,1.8))*3.0);
 vec2 q=p-vec2(.35,-.14);a+=exp(-dot(q*vec2(1.8,2.0),q*vec2(1.8,2.0))*3.0)*.7;
 q=p+vec2(.35,.03);a+=exp(-dot(q*vec2(1.6,2.0),q*vec2(1.6,2.0))*3.0)*.65;
 return smoothstep(.12,.85,a);
}
void fragment(){
 float activity=mix(minimum_activity,1.0,pow(.5+.5*sin(elapsed*6.283185/cycle_seconds+seed_offset),2.0));
 float depth=coverage*.5*activity;
 float clouds=0.0;
 for(int edge=0;edge<2;edge++){
  float y=edge==0?UV.y:1.0-UV.y;
  if(y>=depth){continue;}
  float x=UV.x+elapsed*drift_speed*(edge==0?1.0:-.75)+seed_offset+float(edge)*.31;
  vec2 p=vec2(fract(x*1.8)-.5,y/max(depth,.001));
  clouds=max(clouds,puff(p*vec2(1.5,.65))* (1.0-smoothstep(.65,1.0,y/max(depth,.001))));
 }
 COLOR=vec4(vec3(.94,.955,.91),clouds*opacity);
}
