shader_type spatial;
// Stylized water for terrain cells. Ripples and waves use world coordinates, so neighbouring cells form
// one seamless surface. Cheap: a few sines per pixel, no textures, no screen reads.
render_mode cull_back;
uniform vec3 deep : source_color = vec3(0.16, 0.33, 0.4);
uniform vec3 shallow : source_color = vec3(0.3, 0.55, 0.6);
uniform vec3 foam : source_color = vec3(0.86, 0.93, 0.93);
uniform float wave_height = 0.012;
varying vec3 world;
float ripple(vec2 p, float t){
	return sin(p.x * 5.1 + t * 1.3 + sin(p.y * 3.7 + t) * 0.8) * 0.5 + sin(p.y * 6.3 - t * 1.1 + sin(p.x * 2.9 - t * 0.7)) * 0.5;
}
void vertex(){
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (VERTEX.y > 0.0){
		VERTEX.y += ripple(world.xz, TIME) * wave_height / max(0.001, MODEL_MATRIX[1].y);
	}
}
void fragment(){
	float t = TIME;
	float r = ripple(world.xz * 1.6, t * 1.2);
	float lines = smoothstep(0.82, 0.97, abs(sin(world.x * 3.2 + world.z * 2.1 + r * 1.4 + t * 0.9)));
	vec3 color = mix(deep, shallow, 0.5 + 0.35 * r);
	color = mix(color, foam, lines * 0.35);
	float sparkle = pow(max(0.0, sin(world.x * 11.0 + t * 2.3) * sin(world.z * 9.0 - t * 1.9)), 12.0);
	ALBEDO = color + foam * sparkle * 0.5;
	ROUGHNESS = 0.18;
	METALLIC = 0.0;
	SPECULAR = 0.7;
	RIM = 0.35;
	RIM_TINT = 0.6;
}
