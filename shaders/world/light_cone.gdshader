shader_type spatial;
// Soft visible beam of a spotlight (T-058): faint in clear air, denser at night and in fog. A slow drift of
// dust specks and a fade towards the far end keep it alive and soft. Unshaded, additive-looking, cheap.
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 tint : source_color = vec4(1.0,.84,.58,1.0);
uniform float density = .012;
varying vec3 local;
void vertex(){local=VERTEX;}
float hash(vec3 p){return fract(sin(dot(p,vec3(12.9898,78.233,37.719)))*43758.5453);}
void fragment(){
	float edge=pow(clamp(abs(dot(normalize(NORMAL),normalize(VIEW))),0.0,1.0),.7);
	float along=UV.y;
	float fade=smoothstep(0.0,.18,along)*(1.0-smoothstep(.65,1.0,along));
	vec3 cell=floor(local*vec3(14.0,14.0,14.0)+vec3(0.0,TIME*.6,TIME*.25));
	float dust=step(.997,hash(cell));
	ALBEDO=tint.rgb;
	ALPHA=clamp(density*edge*fade*(1.0+dust*3.0),0.0,1.0);
}
