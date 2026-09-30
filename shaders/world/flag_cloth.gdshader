shader_type spatial;
// Exit flag cloth: a travelling wave from the pole (UV.x = 0) to the free edge, paw emblem.
render_mode cull_disabled;
uniform vec4 cloth : source_color = vec4(0.878, 0.412, 0.165, 1.0);
uniform vec4 hoist : source_color = vec4(0.87, 0.84, 0.74, 1.0);
uniform vec4 emblem : source_color = vec4(0.23, 0.25, 0.19, 1.0);
uniform float strength = 1.0;
float wave(vec2 uv, float t){
	return sin(t * 3.1 - uv.x * 6.5) * 0.11 + sin(t * 5.3 - uv.x * 10.0 + uv.y * 2.2) * 0.035;
}
void vertex(){
	float free_edge = UV.x;
	float t = TIME;
	VERTEX.z += wave(UV, t) * free_edge * strength;
	VERTEX.y -= free_edge * free_edge * 0.05;
	// Normal from the analytic slope along the cloth.
	float slope = (wave(UV + vec2(0.02, 0.0), t) - wave(UV, t)) / 0.02 * free_edge * strength;
	NORMAL = normalize(vec3(-slope, 0.0, 1.0));
}
float disc(vec2 p, vec2 c, float r){ return 1.0 - smoothstep(r - 0.012, r + 0.012, distance(p, c)); }
void fragment(){
	vec2 p = vec2(UV.x * 1.7, UV.y);                 // cloth is 1.7:1
	float paw = disc(p, vec2(0.98, 0.58), 0.14);
	paw = max(paw, disc(p, vec2(0.8, 0.33), 0.06));
	paw = max(paw, disc(p, vec2(0.98, 0.25), 0.065));
	paw = max(paw, disc(p, vec2(1.16, 0.33), 0.06));
	vec3 c = mix(cloth.rgb, hoist.rgb, step(UV.x, 0.1));
	c = mix(c, emblem.rgb, paw * step(0.1, UV.x));
	// Soft shading in the folds.
	c *= 0.9 + 0.1 * sin(TIME * 3.1 - UV.x * 6.5);
	ALBEDO = c;
	ROUGHNESS = 0.9;
}
