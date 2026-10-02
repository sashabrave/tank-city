shader_type spatial;
// Grid ambient occlusion: a flat strip along a wall edge that multiplies the floor colour.
// UV.y = 0 at the wall, 1 a little into the cell; inner corners overlap two strips and get darker.
render_mode unshaded, blend_mul, depth_draw_never, cull_disabled, shadows_disabled;
uniform float strength = 0.55;
// Multiplying by a neutral-warm shade darkens the floor but keeps its own hue (no grey or blue cast).
uniform vec3 shade : source_color = vec3(0.6, 0.56, 0.52);
void fragment() {
	float t = 1.0 - smoothstep(0.0, 1.0, UV.y);
	float along = smoothstep(0.0, 0.18, UV.x) * smoothstep(1.0, 0.82, UV.x);
	float k = t * t * strength * mix(0.55, 1.0, along);
	ALBEDO = mix(vec3(1.0), shade, k);
}
