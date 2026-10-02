shader_type spatial;
// Soft visible beam of a spotlight (T-058): faint in clear air, denser at night and in fog. A slow drift of
// dust specks and a fade towards the far end keep it alive and soft. Unshaded, additive-looking, cheap.
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 tint : source_color = vec4(1.0,.84,.58,1.0);
uniform float density = .012;
// Depth fade: where the cone meets the floor or a wall it melts away instead of cutting a hard outline.
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform float soft_depth = 1.2;
varying vec3 local;
void vertex(){local=VERTEX;}
float hash(vec3 p){return fract(sin(dot(p,vec3(12.9898,78.233,37.719)))*43758.5453);}
void fragment(){
	// Soft silhouette: the cone fades to nothing toward its grazing outline, so no hard edge reads.
	float facing=clamp(abs(dot(normalize(NORMAL),normalize(VIEW))),0.0,1.0);
	float edge=smoothstep(.15,.9,facing);edge*=edge;
	float along=UV.y;
	float fade=smoothstep(0.0,.18,along)*(1.0-smoothstep(.65,1.0,along));
	vec3 cell=floor(local*vec3(14.0,14.0,14.0)+vec3(0.0,TIME*.6,TIME*.25));
	float dust=step(.997,hash(cell));
	float scene=texture(depth_tex,SCREEN_UV).r;
	vec4 world=INV_PROJECTION_MATRIX*vec4(SCREEN_UV*2.0-1.0,scene,1.0);world.xyz/=world.w;
	float touch=smoothstep(0.0,soft_depth,VERTEX.z-world.z);
	ALBEDO=tint.rgb;
	ALPHA=clamp(density*edge*fade*touch*(1.0+dust*3.0),0.0,1.0);
}
