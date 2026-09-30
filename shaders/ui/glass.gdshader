shader_type canvas_item;
// Frosted glass for interface panels: the screen behind is sampled from its mipmaps (cheap blur),
// tinted with the panel colour and lit by a soft top sheen. The stylebox alpha keeps rounded corners.
uniform sampler2D screen:hint_screen_texture,filter_linear_mipmap;
uniform float blur=3.5;
uniform float tint=0.52;
uniform float sheen=0.05;
uniform float panel_height=300.0;
varying vec2 local;
void vertex(){local=VERTEX;}
void fragment(){
	vec2 step_uv=SCREEN_PIXEL_SIZE*exp2(blur)*.6;
	vec3 sum=vec3(0.0);
	for(int x=-1;x<=1;x++)for(int y=-1;y<=1;y++)sum+=textureLod(screen,SCREEN_UV+vec2(float(x),float(y))*step_uv,blur).rgb;
	vec3 behind=sum/9.0*0.78;
	vec3 color=mix(behind,COLOR.rgb,tint);
	color+=sheen*(1.0-clamp(local.y/panel_height,0.0,1.0));
	COLOR=vec4(color,COLOR.a);
}
