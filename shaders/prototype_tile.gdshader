shader_type spatial;

// Prototype Tile Shader
// Simple colored tile with terrain pattern overlay

uniform vec4 tile_color : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform int terrain_type : hint_range(0, 10, 1) = 0;
// 0=Forest, 1=Clearing, 2=Rocks, 3=Water, 4=Desert, 5=Swamp,
// 6=Mountain, 7=Meadow, 8=Tundra, 9=Village, 10=River

// River connection directions (-1 = none, 0=E, 1=N, 2=W, 3=S)
uniform int river_dir_a : hint_range(-1, 3, 1) = -1;
uniform int river_dir_b : hint_range(-1, 3, 1) = -1;

// Pattern
uniform float pattern_scale : hint_range(1.0, 20.0, 0.1) = 6.0;
uniform float pattern_opacity : hint_range(0.0, 1.0, 0.01) = 0.25;

// Surface
uniform float roughness : hint_range(0.0, 1.0, 0.01) = 0.85;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

// ── Terrain patterns ──────────────────────────────────────────────────

float forest_pattern(vec2 p) {
	// Triangles (trees) — pointing up
	vec2 cell = fract(p) - 0.5;
	float tri = max(abs(cell.x) * 1.5 + cell.y * 0.8, -cell.y * 0.6 - 0.1);
	return 1.0 - smoothstep(0.0, 0.06, tri);
}

float clearing_pattern(vec2 p) {
	// Circles (open meadow dots)
	vec2 cell = fract(p) - 0.5;
	float d = length(cell);
	return 1.0 - smoothstep(0.15, 0.2, d);
}

float rocks_pattern(vec2 p) {
	// Diamonds/rhombus (crystal/rock shapes)
	vec2 cell = fract(p) - 0.5;
	float d = abs(cell.x) + abs(cell.y);
	return 1.0 - smoothstep(0.2, 0.26, d);
}

float water_pattern(vec2 p) {
	// Horizontal wave lines
	float wave = sin(p.x * 3.0 + p.y * 1.5) * 0.5 + 0.5;
	wave *= sin(p.x * 1.2 - p.y * 2.0 + 1.5) * 0.4 + 0.6;
	return smoothstep(0.35, 0.5, wave);
}

float desert_pattern(vec2 p) {
	// Wavy dunes — horizontal sine ripples
	float dune = sin(p.y * 2.5 + sin(p.x * 1.8) * 0.6) * 0.5 + 0.5;
	return smoothstep(0.4, 0.6, dune);
}

float swamp_pattern(vec2 p) {
	// Blobs/puddles — large irregular circles
	vec2 cell = fract(p * 0.8) - 0.5;
	float d = length(cell + vec2(sin(p.y * 3.0) * 0.1, cos(p.x * 2.5) * 0.1));
	return 1.0 - smoothstep(0.18, 0.28, d);
}

float mountain_pattern(vec2 p) {
	// Jagged peaks — zigzag lines
	float zigzag = abs(fract(p.x * 0.5) - 0.5) * 2.0;
	float peak = abs(fract(p.y + zigzag * 0.4) - 0.5);
	return 1.0 - smoothstep(0.1, 0.18, peak);
}

float meadow_pattern(vec2 p) {
	// Small crosses/flowers
	vec2 cell = fract(p) - 0.5;
	float cross_h = step(abs(cell.y), 0.06) * step(abs(cell.x), 0.18);
	float cross_v = step(abs(cell.x), 0.06) * step(abs(cell.y), 0.18);
	return max(cross_h, cross_v);
}

float tundra_pattern(vec2 p) {
	// Scattered dots — sparse snowflake feel
	vec2 cell = fract(p * 1.2) - 0.5;
	float d = length(cell);
	float dot = 1.0 - smoothstep(0.08, 0.12, d);
	// Second offset layer
	vec2 cell2 = fract(p * 1.2 + vec2(0.37, 0.61)) - 0.5;
	float d2 = length(cell2);
	dot = max(dot, 1.0 - smoothstep(0.05, 0.09, d2));
	return dot;
}

float village_pattern(vec2 p) {
	// Small squares (buildings)
	vec2 cell = fract(p) - 0.5;
	float sq = max(abs(cell.x), abs(cell.y));
	float outer = 1.0 - smoothstep(0.15, 0.2, sq);
	float inner = 1.0 - smoothstep(0.05, 0.1, sq);
	return outer - inner; // Hollow square
}

float river_pattern(vec2 p) {
	// Flowing S-curve lines (like a winding river)
	float curve = sin(p.y * 2.0) * 0.3 + sin(p.y * 0.8 + 1.0) * 0.15;
	float dist = abs(p.x * 0.5 - curve);
	float river_line = 1.0 - smoothstep(0.04, 0.12, dist);
	// Secondary smaller stream
	float curve2 = sin(p.y * 3.0 + 2.0) * 0.15;
	float dist2 = abs(p.x * 0.5 - 0.25 - curve2);
	river_line = max(river_line, (1.0 - smoothstep(0.02, 0.07, dist2)) * 0.6);
	return river_line;
}

float get_pattern(vec2 uv, int type) {
	vec2 p = uv * pattern_scale;
	if (type == 0) return forest_pattern(p);
	if (type == 1) return clearing_pattern(p);
	if (type == 2) return rocks_pattern(p);
	if (type == 3) return water_pattern(p);
	if (type == 4) return desert_pattern(p);
	if (type == 5) return swamp_pattern(p);
	if (type == 6) return mountain_pattern(p);
	if (type == 7) return meadow_pattern(p);
	if (type == 8) return tundra_pattern(p);
	if (type == 9) return village_pattern(p);
	return river_pattern(p);
}

// Get edge center position for a direction (0=E, 1=N, 2=W, 3=S)
vec2 dir_to_edge(int dir) {
	if (dir == 0) return vec2(1.0, 0.5);  // E
	if (dir == 1) return vec2(0.5, 0.0);  // N
	if (dir == 2) return vec2(0.0, 0.5);  // W
	return vec2(0.5, 1.0);                // S
}

// Draw river channel between two edge points
float river_channel(vec2 uv, int dir_a, int dir_b) {
	if (dir_a < 0 || dir_b < 0) return 0.0;

	vec2 a = dir_to_edge(dir_a);
	vec2 b = dir_to_edge(dir_b);
	vec2 center = vec2(0.5, 0.5);

	// Bezier curve through center: p = (1-t)^2*a + 2*(1-t)*t*center + t^2*b
	float min_dist = 999.0;
	for (float t = 0.0; t <= 1.0; t += 0.02) {
		float t1 = 1.0 - t;
		vec2 p = t1 * t1 * a + 2.0 * t1 * t * center + t * t * b;
		min_dist = min(min_dist, length(uv - p));
	}
	// River width with soft edges
	float channel = 1.0 - smoothstep(0.06, 0.14, min_dist);
	return channel;
}

void fragment() {
	vec2 uv = local_pos.xz + 0.5;

	vec3 ln = normalize(NORMAL);
	bool is_top = ln.y > 0.5;

	vec3 base = tile_color.rgb;

	if (is_top) {
		// ── River channel (drawn before pattern for terrain=10) ──
		if (terrain_type == 10 && river_dir_a >= 0 && river_dir_b >= 0) {
			float channel = river_channel(uv, river_dir_a, river_dir_b);
			// Darken river channel and add blue tint
			vec3 river_deep = base * 0.6;
			base = mix(base, river_deep, channel * 0.7);
			// Water shimmer in channel
			float shimmer = sin(uv.x * 20.0 + uv.y * 15.0) * 0.5 + 0.5;
			base = mix(base, base * 1.15, channel * shimmer * 0.3);
		}

		// ── Terrain pattern overlay ──
		float pat = get_pattern(uv, terrain_type);
		vec3 pattern_col = base * 1.3;
		base = mix(base, pattern_col, pat * pattern_opacity);

		// ── Subtle grid line at edges ──
		float dist_e = 1.0 - uv.x;
		float dist_w = uv.x;
		float dist_s = 1.0 - uv.y;
		float dist_n = uv.y;
		float edge_line = min(min(dist_e, dist_w), min(dist_n, dist_s));
		float line_mask = 1.0 - smoothstep(0.0, 0.02, edge_line);
		base *= 1.0 - line_mask * 0.3;
	}

	ALBEDO = clamp(base, 0.0, 1.0);
	ROUGHNESS = roughness;
	SPECULAR = 0.1;
}
