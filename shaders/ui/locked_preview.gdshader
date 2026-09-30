shader_type canvas_item;

void fragment() {
	vec4 pixel = texture(TEXTURE, UV) * COLOR;
	float luminance = dot(pixel.rgb, vec3(0.2126, 0.7152, 0.0722));
	// Lift dark details into a narrow, pale sage range instead of dimming them.
	vec3 shadow = vec3(0.53, 0.56, 0.51);
	vec3 highlight = vec3(0.76, 0.78, 0.71);
	vec3 muted = mix(shadow, highlight, sqrt(clamp(luminance, 0.0, 1.0)));
	COLOR = vec4(muted, pixel.a * 0.78);
}
