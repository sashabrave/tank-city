shader_type spatial;
// Juicy stylized water (T-004). World-space ripples make neighbouring cells one surface. Cheap: value noise
// in a few taps per pixel, no textures, no screen reads. A rippled normal plus a mirror-like surface lets the
// engine reflect the sky; the light() pass adds sun (or moon) glints that dance on the ripples, and a soft
// fake sky sheen keeps the reflection visible from the near-top-down camera.
render_mode cull_back;
uniform vec3 deep : source_color = vec3(0.12, 0.30, 0.38);
uniform vec3 shallow : source_color = vec3(0.30, 0.58, 0.62);
uniform vec3 sky_tint : source_color = vec3(0.70, 0.82, 0.95);
uniform float wave_height = 0.012;
uniform float ripple_scale = 2.4;
uniform float glint = 0.7;
varying vec3 world;
float hash(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p){
	vec2 i = floor(p), f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
// Two layers drifting against each other: soft swell plus fine chop.
float height(vec2 p, float t){
	return noise(p * ripple_scale + vec2(t * 0.35, t * 0.12)) * 0.6 + noise(p * ripple_scale * 2.3 - vec2(t * 0.18, t * 0.42)) * 0.4;
}
void vertex(){
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (VERTEX.y > 0.0){
		VERTEX.y += (height(world.xz, TIME) - 0.5) * wave_height * 2.0 / max(0.001, MODEL_MATRIX[1].y);
	}
}
void fragment(){
	float t = TIME;
	vec2 p = world.xz;
	float e = 0.04;
	float h = height(p, t);
	float hx = height(p + vec2(e, 0.0), t) - h;
	float hz = height(p + vec2(0.0, e), t) - h;
	vec3 n = normalize(vec3(-hx * 9.0, 1.0, -hz * 9.0));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fresnel = pow(1.0 - facing, 3.0);
	// Clean, even body colour (0.7.2): no noise blotches or foam specks — the ripples live only in the
	// normal, so they show as moving reflections and glints, not as a painted pattern.
	ALBEDO = mix(shallow, deep, 0.55) * 0.8;
	// Fake sky sheen: brighter at grazing angles.
	EMISSION = sky_tint * (0.06 + 0.22 * fresnel);
	ROUGHNESS = 0.06;
	METALLIC = 0.0;
	SPECULAR = 0.65;
}
void light(){
	DIFFUSE_LIGHT += clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION * LIGHT_COLOR / PI;
	// Sharp glints of the sun or moon on the ripples.
	vec3 r = reflect(-LIGHT, NORMAL);
	float s = pow(clamp(dot(r, VIEW), 0.0, 1.0), 90.0);
	SPECULAR_LIGHT += s * glint * 3.0 * ATTENUATION * LIGHT_COLOR;
}
