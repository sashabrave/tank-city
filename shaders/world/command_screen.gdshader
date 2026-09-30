shader_type spatial;
// Hub command screen. Idle: nearly black, abstract maps / dossiers / tables page past at random.
// Alert (news waiting): the whole screen glows turquoise.
render_mode unshaded;
uniform bool alert = false;
uniform vec3 idle_ink = vec3(0.18, 0.42, 0.36);
uniform vec3 alert_ink = vec3(0.35, 1.0, 0.92);
float hash(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float box(vec2 p, vec2 a, vec2 b){ return step(a.x, p.x) * step(p.x, b.x) * step(a.y, p.y) * step(p.y, b.y); }
void fragment(){
	vec2 uv = UV;
	float page = floor(TIME / 2.6 + hash(vec2(floor(TIME / 7.0), 3.0)) * 0.6);
	float kind = floor(hash(vec2(page, 1.7)) * 3.0);      // 0 map, 1 dossier, 2 table
	float slide = clamp(fract(TIME / 2.6) * 6.0, 0.0, 1.0); // quick page turn, then hold
	vec2 p = uv + vec2(0.0, (1.0 - slide) * 0.35);
	float ink = 0.0;
	if (kind < 0.5){
		// map: contour lines, a route and a few unit marks
		float h = sin(p.x * 11.0 + sin(p.y * 7.0 + page) * 2.0) + sin(p.y * 13.0 + page * 1.7);
		ink = smoothstep(0.08, 0.0, abs(fract(h * 1.6) - 0.5) - 0.42) * 0.55;
		ink = max(ink, smoothstep(0.012, 0.0, abs(p.x - 0.5 - 0.18 * sin(p.y * 6.0 + page))));
		for (float i = 0.0; i < 4.0; i++){
			vec2 c = vec2(hash(vec2(page, i)), hash(vec2(i, page))) * 0.7 + 0.15;
			ink = max(ink, box(p, c - 0.025, c + 0.025));
		}
	} else if (kind < 1.5){
		// dossier: photo block, title bar, text lines
		ink = box(p, vec2(0.12, 0.08), vec2(0.42, 0.34)) * 0.8;
		ink = max(ink, box(p, vec2(0.5, 0.1), vec2(0.88, 0.14)));
		float line = step(0.5, fract(p.y * 18.0)) * box(p, vec2(0.12, 0.42), vec2(0.88, 0.94));
		ink = max(ink, line * step(hash(vec2(floor(p.y * 18.0), page)) * 0.7, p.x < 0.12 ? 0.0 : 1.0 - (p.x - 0.12) * 0.9) * 0.6);
	} else {
		// table: grid and bars
		vec2 g = fract(p * vec2(4.0, 12.0));
		ink = (step(0.93, g.x) + step(0.9, g.y)) * 0.35;
		float bar = hash(vec2(floor(p.y * 12.0), page));
		ink = max(ink, box(p, vec2(0.28, 0.0), vec2(0.28 + bar * 0.6, 1.0)) * step(0.3, g.y) * step(g.y, 0.75) * 0.7);
	}
	float scan = 0.85 + 0.15 * sin(uv.y * 240.0 + TIME * 3.0);
	vec3 base = alert ? vec3(0.05, 0.32, 0.3) : vec3(0.015, 0.02, 0.02);
	vec3 ink_color = alert ? alert_ink : idle_ink;
	float pulse = alert ? 0.85 + 0.15 * sin(TIME * 4.0) : 1.0;
	ALBEDO = (base + ink_color * ink * scan) * pulse;
}
