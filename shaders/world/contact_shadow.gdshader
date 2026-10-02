shader_type spatial;
// Soft round shadow under a figure: multiplies the floor towards a cool shade, fading to nothing at the rim.
render_mode unshaded, blend_mul, depth_draw_never, cull_disabled, shadows_disabled;
uniform float strength = 0.5;
uniform vec3 shade : source_color = vec3(0.58, 0.6, 0.7);
void fragment(){
	float r = length(UV * 2.0 - 1.0);
	float k = 1.0 - smoothstep(0.15, 1.0, r);
	ALBEDO = mix(vec3(1.0), shade, k * k * strength);
}
