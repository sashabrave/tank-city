shader_type spatial;
// Rain puddle: a flat, irregular, glossy film on the floor. A top-down camera rarely catches a real
// specular glint, so the film fakes a sky reflection (cool sheen, brighter towards one side), a wet
// bright rim and a slow ripple, on top of low roughness for lamps and headlights. Visual only.
render_mode blend_mix,depth_draw_never,cull_back,shadows_disabled;
uniform bool night = false;
varying vec4 seed;
void vertex(){seed=INSTANCE_CUSTOM;}
void fragment(){
 vec2 p=UV*2.0-1.0;
 float a=atan(p.y,p.x);
 // Wobbly outline from three low harmonics with per-puddle phases.
 float edge=.78+.1*sin(a*3.0+seed.x*6.28)+.06*sin(a*5.0+seed.y*6.28)+.04*sin(a*2.0+seed.z*6.28);
 float r=length(p);
 float body=1.0-smoothstep(edge-.18,edge,r);
 if(body<=.01)discard;
 float rim=smoothstep(edge-.3,edge-.12,r)*(1.0-smoothstep(edge-.12,edge,r));
 float t=fract(TIME*.55+seed.x);
 float ring=(1.0-smoothstep(0.0,.05,abs(r-t*edge*.8)))*(1.0-t);
 vec3 sky=night ? vec3(.22,.28,.4) : vec3(.72,.8,.9);
 float sheen=.35+.65*smoothstep(-1.0,1.0,p.x*.6-p.y*.8);  // sky brighter towards the top of the view
 ALBEDO=vec3(.1,.12,.14);
 EMISSION=sky*(.16*sheen+.22*rim+.18*ring);
 ROUGHNESS=.05;SPECULAR=.9;
 ALPHA=body*.62;
}
