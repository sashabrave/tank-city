shader_type spatial;
render_mode cull_disabled;
uniform vec4 foliage_color : source_color = vec4(0.4, 0.5, 0.3, 1.0);
instance uniform float wind_offset = 0.0;
// COLOR_0 stores flexibility, phase and frequency per tree, not albedo.
// The roots and rocks have zero flexibility. Maximum crown drift < 0.04 cells.
void vertex() {
	float phase = COLOR.g * 6.2831853 + wind_offset;
	float clock = TIME * (0.52 + COLOR.b * 0.37);
	float drift = 0.026 * COLOR.r;
	VERTEX.x += drift * (sin(clock + phase) + 0.28 * sin(clock * 0.61 + phase * 1.73));
	VERTEX.z += drift * (0.67 * sin(clock * 0.83 + phase * 2.11) + 0.21 * cos(clock * 1.17 + phase));
}
void fragment() {
	ALBEDO = foliage_color.rgb;
	ROUGHNESS = 0.92;
	SPECULAR = 0.2;
}
