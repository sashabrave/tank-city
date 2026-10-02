shader_type spatial;
// Ruined apartment blocks on the route map: one box per building block, windows drawn by position instead of
// separate meshes. Panel (khrushchyovka) or brick walls, dark window grid, some windows burnt out, soot
// streaks above burnt ones, a flat lighter roof. Object-space coordinates keep windows fixed to the wall.
render_mode diffuse_burley;
uniform vec3 wall : source_color = vec3(0.62, 0.62, 0.58);
uniform vec3 window_color : source_color = vec3(0.16, 0.18, 0.19);
uniform vec2 window_grid = vec2(0.42, 0.36); // spacing along the wall / per floor, in model units
uniform float brick = 0.0;                  // 1 = brick courses instead of panels
uniform float burnt = 0.25;                 // share of burnt windows
uniform float seed = 0.0;
varying vec3 local_pos;
varying vec3 local_normal;
float hash(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7)) + seed * 17.3) * 43758.5453); }
void vertex(){
	local_pos = VERTEX * vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	local_normal = NORMAL;
}
void fragment(){
	vec3 color = wall;
	if (abs(local_normal.y) > 0.5){
		ALBEDO = wall * 0.82;
		ROUGHNESS = 0.95;
	} else {
		float along = abs(local_normal.x) > 0.5 ? local_pos.z : local_pos.x;
		vec2 cell = vec2(along, local_pos.y) / window_grid;
		vec2 f = fract(cell);
		vec2 id = floor(cell);
		// Panel seams or brick courses.
		float seam = brick > 0.5 ? step(0.9, fract(local_pos.y * 9.0)) * 0.08 : (step(0.97, f.x) + step(0.96, f.y)) * 0.1;
		color *= 1.0 - seam;
		float window = step(0.28, f.x) * step(f.x, 0.72) * step(0.3, f.y) * step(f.y, 0.78) * step(0.5, local_pos.y);
		float dead = step(1.0 - burnt, hash(id));
		vec3 glass = mix(window_color, vec3(0.03), dead);
		color = mix(color, glass, window);
		// Soot above burnt windows.
		float soot = dead * step(0.28, f.x) * step(f.x, 0.72) * smoothstep(1.25, 0.78, f.y) * step(0.78, f.y);
		color *= 1.0 - soot * 0.55;
		ALBEDO = color;
		ROUGHNESS = 0.9;
	}
}
