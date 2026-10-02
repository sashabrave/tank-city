shader_type spatial;
// Floor contact shadow («Глубина света»). Multiplies the floor towards a cool shade that mixes with the surface
// colour and fades smoothly to nothing.
// Cell mode (arena): one quad per floor cell; INSTANCE_CUSTOM.r = side walls (L1 R2 U4 D8), .g = diagonal
// walls (LU1 RU2 LD4 RD8). Sides shade by distance to the wall edge, diagonals by distance to the corner point,
// so strips along a wall join cell to cell and wrap round inner and outer corners (voxel-style AO).
// Box mode (hub): one quad per standing object; INSTANCE_CUSTOM.rg = footprint half size, .ba = quad half size;
// the shade falls off from a rounded rectangle around the footprint.
render_mode unshaded, blend_mul, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform bool boxes = false;
uniform float strength = 0.38;
uniform float depth = 0.34;
uniform vec3 shade : source_color = vec3(0.62, 0.64, 0.74);
varying vec2 p;
varying vec4 data;
void vertex(){
	data = INSTANCE_CUSTOM;
	p = boxes ? VERTEX.xz * 2.0 * data.ba : VERTEX.xz;
}
float bit(float mask, float b){ return mod(floor(mask / b + 0.001), 2.0); }
float fall(float d){ float t = 1.0 - clamp(d / depth, 0.0, 1.0); t = t * t * (3.0 - 2.0 * t); return t * t * t; }
void fragment(){
	float o = 0.0;
	if (boxes){
		vec2 q = abs(p) - data.rg;
		float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0);
		o = fall(max(d, 0.0));
	} else {
		float s = data.r, c = data.g;
		float l = bit(s,1.0)*fall(p.x+.5), r = bit(s,2.0)*fall(.5-p.x), u = bit(s,4.0)*fall(p.y+.5), w = bit(s,8.0)*fall(.5-p.y);
		float a = max(max(l, r), max(u, w));
		float corner = max(max(bit(c,1.0)*fall(length(p-vec2(-.5,-.5))), bit(c,2.0)*fall(length(p-vec2(.5,-.5)))),
			max(bit(c,4.0)*fall(length(p-vec2(-.5,.5))), bit(c,8.0)*fall(length(p-vec2(.5,.5)))));
		// Inner corners deepen a little where two walls meet, without doubling.
		o = max(a, corner) + .35 * min(max(l, r), max(u, w));
	}
	ALBEDO = mix(vec3(1.0), shade, clamp(o, 0.0, 1.0) * strength);
}
