shader_type spatial;
// Grid ambient occlusion: a flat strip along a wall edge that multiplies the floor colour.
// The strip's local +Z points at the wall (floor_ao.gd): darkest right at the wall, fading to fully clear
// well before the far edge. Inner corners overlap two strips. Multiplying keeps the surface hue; the shade
// leans slightly cool, so contact shadows read cold but never grey or black.
render_mode unshaded, blend_mul, depth_draw_never, cull_disabled, shadows_disabled;
uniform float strength = 0.38;
uniform float depth = 0.34;
uniform vec3 shade : source_color = vec3(0.62, 0.64, 0.74);
varying float to_wall;
varying float along;
void vertex(){
	to_wall = clamp(VERTEX.z / depth + 0.5, 0.0, 1.0);
	along = VERTEX.x + 0.5;
}
void fragment(){
	float t = smoothstep(0.0, 1.0, to_wall);
	float k = t * t * t * strength * smoothstep(0.0, 0.12, along) * smoothstep(1.0, 0.88, along);
	ALBEDO = mix(vec3(1.0), shade, k);
}
