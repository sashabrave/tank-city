shader_type spatial;
// Unshaded fire puff: hot core facing the camera, HDR so the glow picks it up.
render_mode unshaded,cull_back,shadows_disabled;
#include "res://shaders/fx/puff.gdshaderinc"
void vertex(){local=VERTEX*2.0;VERTEX+=NORMAL*puff_offset(local);}
void fragment(){
 float facing=clamp(dot(NORMAL,VIEW),0.0,1.0);
 float core=smoothstep(.35,.95,facing)*(1.0-progress*.9);
 vec3 edge=tint.rgb*vec3(1.0,.72,.5);
 ALBEDO=mix(edge,vec3(1.0,.9,.5),core)*1.12;
 // Silhouette eats inward: centre survives longest, no swiss-cheese holes.
 ALPHA=puff_mask(local)*.4+facing*.8;
 ALPHA_SCISSOR_THRESHOLD=mix(.15,1.2,progress);
}
