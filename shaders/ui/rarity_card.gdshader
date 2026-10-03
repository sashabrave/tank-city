shader_type canvas_item;
// Run card background (choice_card.minimal): a soft rarity-coloured gradient, a warm pool of light behind the
// icon and, now and then, a faint diagonal glint. Drawn inside the card border with the card's corner radius.
uniform vec4 tint : source_color = vec4(1.0);
uniform float strength = 0.22;
uniform vec2 rect_size = vec2(280.0, 390.0);
uniform float radius = 14.0;
uniform float seed = 0.0;
uniform float motion = 1.0;

float rounded_mask(vec2 p) {
	vec2 half_size = rect_size * 0.5;
	vec2 q = abs(p - half_size) - (half_size - vec2(radius));
	float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
	return clamp(0.5 - d, 0.0, 1.0);
}

void fragment() {
	vec2 p = UV * rect_size;
	// Gradient: richest at the top, fading towards the text.
	float g = mix(strength, strength * 0.18, smoothstep(0.0, 0.85, UV.y));
	// Light pool behind the icon.
	float pool = 1.0 - smoothstep(0.0, 0.42, distance(UV * vec2(1.0, rect_size.y / rect_size.x), vec2(0.5, 0.3 * rect_size.y / rect_size.x)));
	float a = g + pool * strength * 0.55;
	vec3 colour = tint.rgb;
	// Glint: every 7-11 s (per card) a soft band sweeps across in ~0.9 s.
	float period = 7.0 + fract(sin(seed * 12.9898) * 43758.5453) * 4.0;
	float t = mod(TIME + seed * 3.1, period);
	float sweep = t / 0.9;
	float band = 0.0;
	if (motion > 0.5 && sweep < 1.0) {
		float x = (UV.x + UV.y * 0.55) / 1.55;
		band = (1.0 - smoothstep(0.0, 0.09, abs(x - mix(-0.15, 1.15, sweep)))) * sin(sweep * 3.14159);
	}
	colour = mix(colour, vec3(1.0, 0.97, 0.9), band * 0.6);
	a += band * 0.09;
	COLOR = vec4(colour, a * rounded_mask(p));
}
