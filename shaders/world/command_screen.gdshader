shader_type spatial;
// Hub command screen: a small military dashboard drawn in code. Header with blinking status, a contour
// map with a radar sweep, route and pulsing targets, a tank blueprint with a turning turret and dimension
// lines, then telemetry bars, an oscilloscope and a scrolling log. Alert (news waiting): a glowing blue
// screen with an envelope on top of the dimmed dashboard.
// The screen plane faces -Z in the model while the camera looks from +Z, so U is mirrored here.
render_mode unshaded, cull_disabled;
uniform bool alert = false;
uniform vec3 idle_ink = vec3(0.20, 0.62, 0.50);
uniform vec3 warm_ink = vec3(0.95, 0.62, 0.25);
const vec2 SIZE = vec2(1.08, 2.0); // screen in model units, y grows downward
const float MAP_K = 0.98 / 0.76;
const float BLUEPRINT_K = 0.98 / 0.44;

float hash(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float box(vec2 p, vec2 a, vec2 b){ return step(a.x, p.x) * step(p.x, b.x) * step(a.y, p.y) * step(p.y, b.y); }
// Outline of a rectangle, width w.
float frame(vec2 p, vec2 a, vec2 b, float w){ return box(p, a, b) - box(p, a + w, b - w); }
// Panels are not square: k stretches x so circles stay round (k = panel width / height).
float ring(vec2 p, vec2 c, float r, float w, float k){ vec2 d = (p - c) * vec2(k, 1.0); return smoothstep(w, 0.0, abs(length(d) - r)); }
float segment(vec2 p, vec2 a, vec2 b, float w){
	vec2 pa = p - a, ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return smoothstep(w, 0.0, length(pa - ba * h));
}
float dashed(vec2 p, vec2 a, vec2 b, float w, float count, float shift){
	vec2 ba = b - a;
	float h = clamp(dot(p - a, ba) / dot(ba, ba), 0.0, 1.0);
	return segment(p, a, b, w) * step(0.45, fract(h * count - shift));
}

// Contour map with a sweeping radar, a dashed route and blinking targets. Local coordinates 0..1.
vec2 map_panel(vec2 m, float t){
	float h = sin(m.x * 9.0 + sin(m.y * 6.0) * 1.8) + sin(m.y * 11.0 - m.x * 3.0) * 0.8 + sin((m.x + m.y) * 17.0) * 0.25;
	float contour = smoothstep(0.465, 0.495, abs(fract(h * 1.4) - 0.5)) * 0.4;
	vec2 g = abs(fract(m * 8.0) - 0.5);
	float grid = step(0.47, max(g.x, g.y)) * 0.12;
	float ink = max(contour, grid);
	// Radar sweep from the outpost (lower left), with a fading tail.
	vec2 base = vec2(0.22, 0.78);
	vec2 d = (m - base) * vec2(MAP_K, 1.0);
	float angle = atan(d.y, d.x);
	float sweep = fract((angle - t * 1.3) / 6.2831853);
	float reach = step(length(d), 0.85);
	ink = max(ink, reach * pow(1.0 - sweep, 28.0) * 0.5 + reach * smoothstep(0.004, 0.0, 1.0 - sweep) * 0.4);
	ink = max(ink, ring(m, base, 0.3, 0.006, MAP_K) * 0.4 + ring(m, base, 0.6, 0.006, MAP_K) * 0.3);
	float warm = 0.0;
	// Route from the outpost towards the targets, marching dashes.
	ink = max(ink, dashed(m, base, vec2(0.5, 0.45), 0.008, 9.0, t * 0.8));
	ink = max(ink, dashed(m, vec2(0.5, 0.45), vec2(0.78, 0.2), 0.008, 9.0, t * 0.8));
	// Three targets: crosshair, pulsing ring when the sweep passes.
	for (float i = 0.0; i < 3.0; i++){
		vec2 c = vec2(0.45 + 0.17 * i + 0.03 * sin(t * 0.3 + i), 0.18 + 0.2 * hash(vec2(i, 4.0)));
		float lit = pow(1.0 - fract((atan(c.y - base.y, (c.x - base.x) * MAP_K) - t * 1.3) / 6.2831853), 3.0);
		float cross = segment(m, c - vec2(0.05, 0.0), c + vec2(0.05, 0.0), 0.005) + segment(m, c - vec2(0.0, 0.05), c + vec2(0.0, 0.05), 0.005);
		warm = max(warm, clamp(cross, 0.0, 1.0) * (0.45 + 0.55 * lit) + ring(m, c, 0.03 + 0.04 * fract(t * 0.7 + i * 0.33), 0.006, MAP_K) * (1.0 - fract(t * 0.7 + i * 0.33)));
	}
	// Outpost square.
	ink = max(ink, frame(m, base - 0.03, base + 0.03, 0.008));
	return vec2(ink, warm);
}

// Tank blueprint: hull, tracks with road wheels, a turret that slowly traverses, dimension lines.
float blueprint(vec2 b, float t){
	vec2 g = abs(fract(b * vec2(12.0, 8.0)) - 0.5);
	float ink = step(0.46, max(g.x, g.y)) * 0.1;
	ink = max(ink, frame(b, vec2(0.14, 0.42), vec2(0.86, 0.66), 0.01));               // hull
	ink = max(ink, frame(b, vec2(0.10, 0.62), vec2(0.90, 0.82), 0.01) * 0.8);         // track
	for (float i = 0.0; i < 6.0; i++){ ink = max(ink, ring(b, vec2(0.2 + i * 0.12, 0.72), 0.09, 0.012, BLUEPRINT_K)); }
	vec2 turret = vec2(0.47, 0.36);
	ink = max(ink, ring(b, turret, 0.2, 0.014, BLUEPRINT_K));
	float traverse = sin(t * 0.4) * 0.5;
	vec2 dir = vec2(cos(traverse), sin(traverse) * 0.35);
	ink = max(ink, segment(b, turret + dir * 0.09, turret + dir * 0.42, 0.014));        // barrel
	// Dimension lines with ticks, drawn on with a slow cycle.
	float draw = fract(t * 0.12);
	ink = max(ink, segment(b, vec2(0.14, 0.9), vec2(0.14 + 0.72 * min(1.0, draw * 2.0), 0.9), 0.004) * 0.7);
	ink = max(ink, (segment(b, vec2(0.14, 0.87), vec2(0.14, 0.93), 0.004) + segment(b, vec2(0.86, 0.87), vec2(0.86, 0.93), 0.004)) * 0.7);
	ink = max(ink, segment(b, vec2(0.95, 0.24), vec2(0.95, 0.82), 0.004) * 0.6);
	return ink;
}

// Telemetry: bar graph, an oscilloscope trace and a scrolling log of text-like blocks.
vec2 telemetry(vec2 q, float t){
	float ink = 0.0; float warm = 0.0;
	// Bars (top part of the panel).
	if (q.y < 0.38){
		float column = floor(q.x * 10.0);
		float level = 0.35 + 0.45 * hash(vec2(column, floor(t * 0.8))) * (0.7 + 0.3 * sin(t * 2.0 + column));
		float inside = step(0.18, fract(q.x * 10.0)) * step(fract(q.x * 10.0), 0.82);
		float bar = inside * step(0.36 - level * 0.32, q.y) * step(q.y, 0.36);
		ink = max(ink, bar * 0.7);
		warm = max(warm, bar * step(0.62, level) * 0.6);
	}
	// Oscilloscope.
	float wave = 0.5 + 0.06 * sin(q.x * 28.0 - t * 4.0) + 0.03 * sin(q.x * 71.0 + t * 7.0);
	ink = max(ink, smoothstep(0.012, 0.0, abs(q.y - wave)) * 0.9);
	// Log lines scrolling up.
	if (q.y > 0.62){
		float row = floor((q.y - 0.62) * 22.0 + t * 1.5);
		float inside_row = step(0.35, fract((q.y - 0.62) * 22.0 + t * 1.5));
		float length_ = 0.3 + 0.65 * hash(vec2(row, 2.0));
		float words = step(0.18, fract(q.x * (9.0 + 5.0 * hash(vec2(row, 5.0)))));
		ink = max(ink, inside_row * words * step(q.x, length_) * 0.5);
		warm = max(warm, inside_row * step(q.x, 0.05) * step(0.8, hash(vec2(row, 9.0))));
	}
	return vec2(ink, warm);
}

void fragment(){
	vec2 uv = vec2(1.0 - UV.x, UV.y);
	vec2 s = uv * SIZE;          // screen units
	float t = TIME;
	float ink = 0.0; float warm = 0.0;
	// Header: title bar, blinking status lamp, clock-like ticking blocks.
	ink = max(ink, frame(s, vec2(0.05, 0.05), vec2(1.03, 0.17), 0.006) * 0.8);
	ink = max(ink, box(s, vec2(0.09, 0.09), vec2(0.5, 0.13)) * 0.55);
	warm = max(warm, box(s, vec2(0.93, 0.085), vec2(0.985, 0.135)) * step(0.5, fract(t * 0.9)));
	for (float i = 0.0; i < 4.0; i++){ ink = max(ink, box(s, vec2(0.58 + i * 0.075, 0.095), vec2(0.63 + i * 0.075, 0.125)) * step(i, mod(floor(t * 2.0), 5.0))); }
	// Map panel.
	vec2 a = vec2(0.05, 0.22), b = vec2(1.03, 0.98);
	ink = max(ink, frame(s, a, b, 0.006) * 0.8);
	if (box(s, a, b) > 0.0){ vec2 m = map_panel((s - a) / (b - a), t); ink = max(ink, m.x); warm = max(warm, m.y); }
	// Blueprint panel.
	a = vec2(0.05, 1.03); b = vec2(1.03, 1.47);
	ink = max(ink, frame(s, a, b, 0.006) * 0.8);
	if (box(s, a, b) > 0.0){ ink = max(ink, blueprint((s - a) / (b - a), t)); }
	// Telemetry panel.
	a = vec2(0.05, 1.52); b = vec2(1.03, 1.95);
	ink = max(ink, frame(s, a, b, 0.006) * 0.8);
	if (box(s, a, b) > 0.0){ vec2 q = telemetry((s - a) / (b - a), t); ink = max(ink, q.x); warm = max(warm, q.y); }
	float scan = 0.88 + 0.12 * sin(uv.y * 320.0 + t * 3.0);
	float flicker = 0.97 + 0.03 * hash(vec2(floor(t * 24.0), 1.0));
	vec3 dashboard = vec3(0.012, 0.022, 0.02) + (idle_ink * ink + warm_ink * warm) * scan * flicker;
	if (alert){
		// News: a big envelope icon on a glowing blue screen over the dimmed dashboard, gently pulsing.
		vec2 q = s - SIZE * 0.5;  // screen units, centred; y grows downward
		vec2 e = vec2(0.4, 0.27);
		float outline = box(q, -e, e) - box(q, -e + 0.04, e - 0.04);
		// Flap from the top corners down to the centre.
		float flap = segment(q, vec2(-e.x + 0.02, -e.y + 0.02), vec2(0.0, 0.04), 0.03) + segment(q, vec2(e.x - 0.02, -e.y + 0.02), vec2(0.0, 0.04), 0.03);
		float icon = clamp(outline + flap, 0.0, 1.0);
		float pulse = 0.8 + 0.2 * sin(t * 3.0);
		vec3 screen = vec3(0.04, 0.14, 0.3) + vec3(0.1, 0.25, 0.45) * ink * 0.35;
		ALBEDO = mix(screen, vec3(0.75, 0.9, 1.0), icon) * pulse * scan;
		EMISSION = ALBEDO * 0.6;
	} else {
		ALBEDO = dashboard;
		EMISSION = (idle_ink * ink + warm_ink * warm) * 0.25;
	}
}
