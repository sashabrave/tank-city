shader_type spatial;
// Projectile trail: additive streak, bright at the head (local -Z), fading to the tail.
render_mode unshaded,blend_add,cull_disabled,depth_draw_never,shadows_disabled;
uniform vec4 color : source_color = vec4(1.0,.8,.45,1.0);
uniform float energy = 1.0;
uniform float flicker = 0.0;
varying float along;
varying vec2 across;
void vertex(){along=VERTEX.z+.5;across=VERTEX.xy*2.0;}
void fragment(){
 float tail=pow(clamp(1.0-along,0.0,1.0),1.7);
 float core=1.0-smoothstep(.2,1.0,length(across));
 float wobble=1.0-flicker*.35*(.5+.5*sin(TIME*55.0+along*14.0));
 ALBEDO=color.rgb*tail*(.35+core*.9)*energy*wobble;
}
