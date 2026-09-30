shader_type spatial;
// Light pillar above a reward chest: additive, fades upward and toward the silhouette edge.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 tint : source_color = vec4(1.0, 0.84, 0.42, 1.0);
uniform float strength = 0.55;
void fragment(){
	float up = 1.0 - UV.y;                       // CylinderMesh: UV.y = 0 at the top
	float fade = pow(clamp(1.0 - up, 0.0, 1.0), 1.6);
	float edge = pow(abs(dot(NORMAL, VIEW)), 1.5);
	float drift = 0.85 + 0.15 * sin(TIME * 1.7 + up * 9.0);
	ALBEDO = tint.rgb;
	ALPHA = clamp(fade * edge * strength * drift, 0.0, 1.0);
}
