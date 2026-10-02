shader_type spatial;
// Rain puddle (T-004): a flat, irregular, glossy film on the floor with the same rippled-mirror recipe as
// the water. A top-down camera rarely catches a real reflection, so the film adds a soft sky sheen that
// follows the ripple, a wet bright rim and expanding drop rings; the light() pass adds glints from the sun,
// lamps and headlights. Visual only.
render_mode blend_mix,depth_draw_never,cull_back,shadows_disabled;
uniform bool night = false;
varying vec4 seed;
varying vec3 world;
float hash(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p){
	vec2 i = floor(p), f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
void vertex(){seed=INSTANCE_CUSTOM;world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
	vec2 p=UV*2.0-1.0;
	float a=atan(p.y,p.x);
	// Wobbly outline from three low harmonics with per-puddle phases.
	float edge=.78+.1*sin(a*3.0+seed.x*6.28)+.06*sin(a*5.0+seed.y*6.28)+.04*sin(a*2.0+seed.z*6.28);
	float r=length(p);
	float body=1.0-smoothstep(edge-.18,edge,r);
	if(body<=.01)discard;
	float rim=smoothstep(edge-.3,edge-.12,r)*(1.0-smoothstep(edge-.12,edge,r));
	float t=fract(TIME*.55+seed.x);
	float ring=(1.0-smoothstep(0.0,.05,abs(r-t*edge*.8)))*(1.0-t);
	float h=noise(world.xz*5.0+vec2(TIME*.2,-TIME*.15));
	float hx=noise(world.xz*5.0+vec2(.05,0.0)+vec2(TIME*.2,-TIME*.15))-h;
	float hz=noise(world.xz*5.0+vec2(0.0,.05)+vec2(TIME*.2,-TIME*.15))-h;
	NORMAL=normalize((VIEW_MATRIX*vec4(normalize(vec3(-hx*4.0,1.0,-hz*4.0)),0.0)).xyz);
	vec3 sky=night ? vec3(.22,.28,.4) : vec3(.72,.8,.9);
	float sheen=.3+.5*smoothstep(-1.0,1.0,p.x*.6-p.y*.8)+.3*h;
	ALBEDO=vec3(.08,.1,.12);
	EMISSION=sky*(.16*sheen+.22*rim+.2*ring);
	ROUGHNESS=.04;SPECULAR=.9;
	ALPHA=body*.66;
}
void light(){
	DIFFUSE_LIGHT+=clamp(dot(NORMAL,LIGHT),0.0,1.0)*ATTENUATION*LIGHT_COLOR/PI;
	vec3 r=reflect(-LIGHT,NORMAL);
	SPECULAR_LIGHT+=pow(clamp(dot(r,VIEW),0.0,1.0),70.0)*2.5*ATTENUATION*LIGHT_COLOR;
}
