shader_type spatial;

// Sunscar Tile Shader
// 6 edge types: Sand(0), Trail(1), Settlement(2), Ruins(3), Mountains(4), Oasis(5)

uniform vec4 tile_color : source_color = vec4(0.82, 0.72, 0.48, 1.0);

uniform int edge_e : hint_range(0, 5, 1) = 0;
uniform int edge_n : hint_range(0, 5, 1) = 0;
uniform int edge_w : hint_range(0, 5, 1) = 0;
uniform int edge_s : hint_range(0, 5, 1) = 0;

uniform float roughness : hint_range(0.0, 1.0, 0.01) = 0.85;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

// ── Colors ──
const vec3 SAND_COLOR       = vec3(0.82, 0.72, 0.48);
const vec3 TRAIL_COLOR      = vec3(0.50, 0.40, 0.25);
const vec3 SETTLEMENT_COLOR = vec3(0.78, 0.52, 0.30);
const vec3 SETTLEMENT_WALL  = vec3(0.60, 0.38, 0.22);
const vec3 RUINS_COLOR      = vec3(0.55, 0.50, 0.45);
const vec3 RUINS_DARK       = vec3(0.40, 0.36, 0.32);
const vec3 MOUNTAIN_COLOR   = vec3(0.45, 0.40, 0.38);
const vec3 MOUNTAIN_PEAK    = vec3(0.55, 0.52, 0.48);
const vec3 OASIS_COLOR      = vec3(0.30, 0.62, 0.35);
const vec3 OASIS_WATER      = vec3(0.25, 0.45, 0.55);

// ── Trail: band from edge to center ──
float trail_band(vec2 uv, int dir) {
	float hw = 0.1;
	float d = 999.0;
	if (dir == 0) { // E
		d = (uv.x > 0.5) ? abs(uv.y - 0.5) : 999.0;
		if (length(uv - vec2(0.5)) < hw + 0.02) d = min(d, abs(uv.y - 0.5));
	}
	if (dir == 1) { // N
		d = (uv.y < 0.5) ? abs(uv.x - 0.5) : 999.0;
		if (length(uv - vec2(0.5)) < hw + 0.02) d = min(d, abs(uv.x - 0.5));
	}
	if (dir == 2) { // W
		d = (uv.x < 0.5) ? abs(uv.y - 0.5) : 999.0;
		if (length(uv - vec2(0.5)) < hw + 0.02) d = min(d, abs(uv.y - 0.5));
	}
	if (dir == 3) { // S
		d = (uv.y > 0.5) ? abs(uv.x - 0.5) : 999.0;
		if (length(uv - vec2(0.5)) < hw + 0.02) d = min(d, abs(uv.x - 0.5));
	}
	return 1.0 - smoothstep(hw - 0.02, hw + 0.02, d);
}

// ── Edge fill: fills from edge inward ──
float edge_fill(vec2 uv, int dir, float depth) {
	if (dir == 0) return smoothstep(depth, depth - 0.03, 1.0 - uv.x);
	if (dir == 1) return smoothstep(depth, depth - 0.03, uv.y);
	if (dir == 2) return smoothstep(depth, depth - 0.03, uv.x);
	return smoothstep(depth, depth - 0.03, 1.0 - uv.y);
}

// ── Wall line at inner border ──
float wall_line(vec2 uv, int dir, float pos) {
	float w = 0.025;
	float d = 999.0;
	if (dir == 0) d = abs((1.0 - uv.x) - pos);
	if (dir == 1) d = abs(uv.y - pos);
	if (dir == 2) d = abs(uv.x - pos);
	if (dir == 3) d = abs((1.0 - uv.y) - pos);
	return 1.0 - smoothstep(w - 0.01, w + 0.01, d);
}

// ── Dune pattern ──
float dune_pattern(vec2 uv) {
	float wave = sin(uv.x * 12.0 + sin(uv.y * 8.0) * 0.5) * 0.5 + 0.5;
	wave *= sin(uv.y * 6.0 + uv.x * 3.0 + 1.5) * 0.4 + 0.6;
	return wave * 0.08;
}

// ── Mountain zigzag pattern ──
float mountain_pattern(vec2 uv) {
	float zigzag = abs(fract(uv.x * 4.0) - 0.5) * 2.0;
	float peak = smoothstep(0.3, 0.7, zigzag) * smoothstep(0.0, 0.3, 1.0 - uv.y);
	return peak;
}

// ── Ruins cracked pattern ──
float ruins_pattern(vec2 uv) {
	vec2 cell = fract(uv * 3.0) - 0.5;
	float crack_h = 1.0 - smoothstep(0.01, 0.04, abs(cell.y));
	float crack_v = 1.0 - smoothstep(0.01, 0.04, abs(cell.x));
	return max(crack_h * 0.5, crack_v * 0.3);
}

// ── Oasis organic pattern (leaves/water) ──
float oasis_pattern(vec2 uv) {
	float circle = 1.0 - smoothstep(0.08, 0.14, length(fract(uv * 3.0) - 0.5));
	float wave = sin(uv.x * 20.0 + uv.y * 10.0) * 0.5 + 0.5;
	return mix(circle * 0.4, wave * 0.2, 0.5);
}

void fragment() {
	vec2 uv = local_pos.xz + 0.5;
	vec3 ln = normalize(NORMAL);
	bool is_top = ln.y > 0.5;

	vec3 base = tile_color.rgb;

	if (is_top) {
		// Sand dune texture
		base += dune_pattern(uv);

		int edges[4];
		edges[0] = edge_e;
		edges[1] = edge_n;
		edges[2] = edge_w;
		edges[3] = edge_s;

		// ── Layer 1: Settlement fills (background) ──
		float total_settlement = 0.0;
		for (int i = 0; i < 4; i++) {
			if (edges[i] == 2) {
				total_settlement = max(total_settlement, edge_fill(uv, i, 0.35));
			}
		}
		base = mix(base, SETTLEMENT_COLOR, total_settlement * 0.85);

		// Settlement walls
		float total_swall = 0.0;
		for (int i = 0; i < 4; i++) {
			if (edges[i] == 2) {
				total_swall = max(total_swall, wall_line(uv, i, 0.33));
			}
		}
		base = mix(base, SETTLEMENT_WALL, total_swall * 0.7);

		// Settlement building pattern
		if (total_settlement > 0.3) {
			vec2 cell = fract(uv * 5.0) - 0.5;
			float sq = max(abs(cell.x), abs(cell.y));
			float building = 1.0 - smoothstep(0.12, 0.18, sq);
			float inner = 1.0 - smoothstep(0.04, 0.08, sq);
			float pattern = (building - inner) * total_settlement * 0.3;
			base = mix(base, SETTLEMENT_WALL * 0.9, pattern);
		}

		// ── Layer 2: Mountains ──
		float total_mountain = 0.0;
		for (int i = 0; i < 4; i++) {
			if (edges[i] == 4) {
				total_mountain = max(total_mountain, edge_fill(uv, i, 0.38));
			}
		}
		if (total_mountain > 0.0) {
			vec3 mtn = mix(MOUNTAIN_COLOR, MOUNTAIN_PEAK, mountain_pattern(uv));
			base = mix(base, mtn, total_mountain * 0.9);

			// Rocky edge line
			float total_mwall = 0.0;
			for (int i = 0; i < 4; i++) {
				if (edges[i] == 4) {
					total_mwall = max(total_mwall, wall_line(uv, i, 0.36));
				}
			}
			base = mix(base, MOUNTAIN_COLOR * 0.7, total_mwall * 0.5);
		}

		// ── Layer 3: Ruins ──
		float total_ruins = 0.0;
		for (int i = 0; i < 4; i++) {
			if (edges[i] == 3) {
				total_ruins = max(total_ruins, edge_fill(uv, i, 0.32));
			}
		}
		if (total_ruins > 0.0) {
			vec3 ruin_col = mix(RUINS_COLOR, RUINS_DARK, ruins_pattern(uv));
			base = mix(base, ruin_col, total_ruins * 0.8);

			// Broken wall line
			float total_rwall = 0.0;
			for (int i = 0; i < 4; i++) {
				if (edges[i] == 3) {
					float wl = wall_line(uv, i, 0.30);
					// Make it broken/dashed
					float dash = step(0.5, fract(uv.x * 8.0 + uv.y * 8.0));
					total_rwall = max(total_rwall, wl * dash);
				}
			}
			base = mix(base, RUINS_DARK * 0.8, total_rwall * 0.6);
		}

		// ── Layer 4: Oasis ──
		float total_oasis = 0.0;
		for (int i = 0; i < 4; i++) {
			if (edges[i] == 5) {
				total_oasis = max(total_oasis, edge_fill(uv, i, 0.30));
			}
		}
		if (total_oasis > 0.0) {
			float op = oasis_pattern(uv);
			vec3 oasis_col = mix(OASIS_COLOR, OASIS_WATER, op);
			base = mix(base, oasis_col, total_oasis * 0.85);

			// Soft green border (no hard wall — organic)
			for (int i = 0; i < 4; i++) {
				if (edges[i] == 5) {
					float soft_edge = edge_fill(uv, i, 0.28) - edge_fill(uv, i, 0.24);
					base = mix(base, OASIS_COLOR * 1.2, max(soft_edge, 0.0) * 0.4);
				}
			}
		}

		// ── Layer 5: Trail paths (on top of everything) ──
		float total_trail = 0.0;
		for (int i = 0; i < 4; i++) {
			if (edges[i] == 1) {
				total_trail = max(total_trail, trail_band(uv, i));
			}
		}
		base = mix(base, TRAIL_COLOR, total_trail * 0.85);

		// Trail center dot
		bool has_trail = (edge_e == 1 || edge_n == 1 || edge_w == 1 || edge_s == 1);
		if (has_trail) {
			float dot = 1.0 - smoothstep(0.06, 0.1, length(uv - vec2(0.5)));
			base = mix(base, TRAIL_COLOR * 0.8, dot * 0.6);
		}

		// ── Grid lines ──
		float dist_e = 1.0 - uv.x;
		float dist_w = uv.x;
		float dist_s = 1.0 - uv.y;
		float dist_n = uv.y;
		float edge_line = min(min(dist_e, dist_w), min(dist_n, dist_s));
		float line_mask = 1.0 - smoothstep(0.0, 0.02, edge_line);
		base *= 1.0 - line_mask * 0.25;
	} else {
		base *= 0.7;
	}

	ALBEDO = clamp(base, 0.0, 1.0);
	ROUGHNESS = roughness;
	SPECULAR = 0.1;
}
