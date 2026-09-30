shader_type canvas_item;
render_mode unshaded;
// Screen-space aerial haze for the fixed top-down camera: no depth or screen reads.
uniform vec4 haze_color : source_color = vec4(.89,.91,.94,1.0);
uniform float amount = .3;
void fragment() {
 float far=pow(1.0-smoothstep(.0,.55,SCREEN_UV.y),1.6);
 vec2 edge=abs(SCREEN_UV-.5)*2.0;
 float corner=smoothstep(.75,1.4,length(edge))*.35;
 COLOR=vec4(haze_color.rgb,clamp(far*amount+corner*amount,0.0,1.0));
}
