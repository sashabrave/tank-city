shader_type spatial;
// Sniper sight: bright core with soft pulses travelling toward the target and a slight flicker.
render_mode unshaded,blend_add,cull_disabled,depth_draw_never,shadows_disabled;
uniform vec4 color : source_color = vec4(1.0,.15,.25,1.0);
uniform float energy = 1.0;
uniform float halo = 0.0;
varying float along;
void vertex(){along=VERTEX.z;}
void fragment(){
 float pulses=.5+.5*sin(along*10.0-TIME*16.0);
 float flicker=.92+.08*sin(TIME*37.0)*sin(TIME*23.0);
 float strength=(halo>.5 ? .22+.18*pow(pulses,2.0) : .75+.45*pow(pulses,3.0))*flicker*energy;
 ALBEDO=color.rgb*strength;
}
