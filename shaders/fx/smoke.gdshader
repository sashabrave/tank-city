shader_type spatial;
// Toon-lit smoke: follows the scene sun and the style's fill colour; opaque scissor, no sorting.
render_mode diffuse_toon,specular_disabled,cull_back;
#include "res://shaders/fx/puff.gdshaderinc"
void vertex(){local=VERTEX*2.0;VERTEX+=NORMAL*puff_offset(local);}
void fragment(){
 float facing=clamp(dot(NORMAL,VIEW),0.0,1.0);
 ALBEDO=tint.rgb;
 ROUGHNESS=1.0;
 RIM=.35;RIM_TINT=.2;
 ALPHA=puff_mask(local)*.45+facing*.7;
 ALPHA_SCISSOR_THRESHOLD=mix(.12,1.15,progress);
}
