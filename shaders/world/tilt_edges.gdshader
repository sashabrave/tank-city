shader_type canvas_item;
render_mode unshaded;
uniform sampler2D scene_texture : hint_screen_texture, filter_linear_mipmap;
void fragment() {
 float edge=smoothstep(.27,.50,abs(SCREEN_UV.y-.5));
 vec4 sharp=textureLod(scene_texture,SCREEN_UV,0.0);
 vec4 soft=textureLod(scene_texture,SCREEN_UV,edge*2.6);
 COLOR=vec4(mix(sharp.rgb,soft.rgb,edge*.72),1.0);
}
