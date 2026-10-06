shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
// Hold point (T-335): the captured share of the area fills clockwise as a pie sector; the rest breathes
// very slowly so the zone reads as «stand here». The outline is the ground ring drawn separately.
uniform vec4 tint : source_color = vec4(0.93, 0.80, 0.55, 1.0);
uniform float ratio = 0.0;
uniform float paused = 0.0;
void fragment(){
	vec2 p = UV*2.0-1.0;
	float r = length(p);
	if (r > 0.97) discard;
	float a = fract(atan(p.x, -p.y)/6.2831853 + 1.0);
	float filled = step(a, ratio);
	float breathe = 0.5 + 0.5*sin(TIME*1.3);   // ~5 s per slow blink
	float alpha = filled*(0.34 - 0.12*paused) + (1.0-filled)*(0.04 + 0.08*breathe);
	alpha *= smoothstep(0.97, 0.92, r);
	ALBEDO = tint.rgb;
	ALPHA = alpha;
}
