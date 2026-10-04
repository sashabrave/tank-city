shader_type spatial;
// Gadget laser (T-296): a thin red beam, hotter than the sniper sight, that strobes sharply while it burns.
// `age` 0..1 over the beam's life (per instance); `halo` 1 = the soft outer glow, 0 = the hot core.
render_mode unshaded,blend_add,cull_disabled,depth_draw_never,shadows_disabled;
uniform vec4 color : source_color = vec4(1.0,.12,.16,1.0);
uniform float energy = 2.4;
uniform float halo = 0.0;
instance uniform float age = 0.0;
varying float along;
void vertex(){along=VERTEX.z;}
void fragment(){
 // Hard on/off strobe (about 18 Hz), not a soft sine: the beam snaps between full and dim.
 float strobe=step(.45,fract(age*7.0))*.85+.25;
 float pulses=.5+.5*sin(along*24.0-TIME*60.0);
 float fade=1.0-smoothstep(.7,1.0,age);
 float strength=(halo>.5 ? .35+.25*pow(pulses,2.0) : 1.1+.6*pow(pulses,4.0))*strobe*fade*energy;
 vec3 tint=halo>.5 ? color.rgb : mix(color.rgb,vec3(1.0,.85,.8),.35);
 ALBEDO=tint*strength;
}
