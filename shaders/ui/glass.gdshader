shader_type canvas_item;
// Frosted glass for interface panels. The screen behind is read once per canvas layer (Godot copies it
// with mipmaps); each panel takes a 12-tap Poisson disc between two mip levels — a soft, round blur
// without the square steps of a single level. Vibrancy lifts the saturation of what shows through,
// a faint grain hides banding, a soft top sheen gives the pane thickness. Stylebox alpha keeps the corners.
uniform sampler2D screen:hint_screen_texture,filter_linear_mipmap;
uniform float blur=3.6;
uniform float tint=0.5;
uniform float vibrancy=1.28;
uniform float sheen=0.05;
uniform float grain=0.012;
uniform float panel_height=300.0;
varying vec2 local;
const vec2 DISC[12]=vec2[](vec2(-.326,-.406),vec2(-.840,-.074),vec2(-.696,.457),vec2(-.203,.621),vec2(.962,-.195),vec2(.473,-.480),
	vec2(.519,.767),vec2(.185,-.893),vec2(.507,.064),vec2(.896,.412),vec2(-.322,-.933),vec2(-.792,-.598));
void vertex(){local=VERTEX;}
vec3 sample_disc(vec2 uv,float lod,vec2 radius){
	vec3 sum=textureLod(screen,uv,lod).rgb;
	for(int i=0;i<12;i++)sum+=textureLod(screen,uv+DISC[i]*radius,lod).rgb;
	return sum/13.0;
}
void fragment(){
	vec2 radius=SCREEN_PIXEL_SIZE*exp2(blur)*1.1;
	vec3 behind=mix(sample_disc(SCREEN_UV,blur-.5,radius*.7),sample_disc(SCREEN_UV,blur+.5,radius*1.3),.5);
	float luma=dot(behind,vec3(.299,.587,.114));
	behind=mix(vec3(luma),behind,vibrancy)*.8;
	vec3 color=mix(behind,COLOR.rgb,tint);
	color+=sheen*(1.0-clamp(local.y/panel_height,0.0,1.0));
	float n=fract(sin(dot(FRAGCOORD.xy,vec2(12.9898,78.233)))*43758.5453);
	color+=(n-.5)*grain;
	COLOR=vec4(color,COLOR.a);
}
