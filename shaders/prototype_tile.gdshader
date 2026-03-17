shader_type spatial;

// Sunscar Hex Tile Shader — Isengard theme
// 4 terrain types: Wasteland(0), Forest(1), Fortress(2), Mine(3)
// 6 edges on pointy-top hex: E(0), NE(1), NW(2), W(3), SW(4), SE(5)
//
// Godot CylinderMesh(6 segments) generates vertices at 30°,90°,150°,210°,270°,330°
// = already pointy-top (vertex at 270°=north, 90°=south). NO scene rotation needed.
// Flat edges face: 0°(E), 60°(SE), 120°(SW), 180°(W), 240°(NW), 300°(NE).
// PI/6 offset aligns sector boundaries with vertices (at 30°,90°,...).
// CW angle order from E: E→SE→SW→W→NW→NE.
// Edge index = (6 - cw_sector) % 6 converts CW order to our CCW edge numbering.

uniform vec4 tile_color : source_color = vec4(0.42, 0.38, 0.32, 1.0);

uniform int edge_0 : hint_range(0, 3, 1) = 0;  // E
uniform int edge_1 : hint_range(0, 3, 1) = 0;  // NE
uniform int edge_2 : hint_range(0, 3, 1) = 0;  // NW
uniform int edge_3 : hint_range(0, 3, 1) = 0;  // W
uniform int edge_4 : hint_range(0, 3, 1) = 0;  // SW
uniform int edge_5 : hint_range(0, 3, 1) = 0;  // SE

uniform float roughness_val : hint_range(0.0, 1.0, 0.01) = 0.85;

varying vec3 local_pos;
varying vec3 model_normal;  // Model-space normal (camera-independent)

void vertex() {
	local_pos = VERTEX;
	model_normal = NORMAL;
}

// ── Terrain Colors ──
const vec3 WASTELAND_COLOR = vec3(0.42, 0.38, 0.32);
const vec3 WASTELAND_DARK  = vec3(0.35, 0.31, 0.26);
const vec3 FOREST_COLOR    = vec3(0.20, 0.38, 0.15);
const vec3 FOREST_DARK     = vec3(0.12, 0.25, 0.08);
const vec3 FORTRESS_COLOR  = vec3(0.35, 0.30, 0.28);
const vec3 FORTRESS_WALL   = vec3(0.25, 0.20, 0.18);
const vec3 MINE_COLOR      = vec3(0.55, 0.40, 0.22);
const vec3 MINE_DARK       = vec3(0.40, 0.28, 0.14);

// ── Hex geometry ──
const float HEX_APOTHEM = 0.4330;  // sqrt(3)/2 * 0.5 — matches CylinderMesh radius 0.5 (= HEX_SIZE, edge-to-edge fit)
const float SECTOR_WIDTH = 1.0471975; // PI / 3.0 = 60 degrees
const float HALF_SECTOR = 0.5235988;  // PI / 6.0 = 30 degrees

// Get edge index (0-5) for a mesh-local-space point.
// Accounts for 30° scene rotation so sectors align with world hex directions.
// Returns: 0=E, 1=NE, 2=NW, 3=W, 4=SW, 5=SE
int get_edge_index(vec2 p) {
	float angle = atan(p.y, p.x);
	if (angle < 0.0) angle += TAU;
	// Add PI/6 (30°) to compensate for scene rotation:
	// mesh-local 0° → world 30° (between E and SE), so shifting aligns sector 0 with E
	angle = mod(angle + HALF_SECTOR, TAU);
	// CW sector index: 0=E(0°), 1=SE(60°), 2=SW(120°), 3=W(180°), 4=NW(240°), 5=NE(300°)
	int cw_idx = int(mod(angle / SECTOR_WIDTH, 6.0));
	// Convert CW order to edge index: (6-0)%6=0(E), (6-1)%6=5(SE), (6-2)%6=4(SW), etc.
	return (6 - cw_idx) % 6;
}

// Get the CW sector index (for border calculations). Same angle math, no remap.
int get_cw_sector(vec2 p) {
	float angle = atan(p.y, p.x);
	if (angle < 0.0) angle += TAU;
	angle = mod(angle + HALF_SECTOR, TAU);
	return int(mod(angle / SECTOR_WIDTH, 6.0));
}

// Hex distance: 0 at center, 1 at edge
float hex_dist(vec2 p) {
	float ax = abs(p.x);
	float ay = abs(p.y);
	return max(ax * 0.866025 + ay * 0.5, ay) / HEX_APOTHEM;
}

vec3 get_terrain_color(int terrain) {
	if (terrain == 1) return FOREST_COLOR;
	if (terrain == 2) return FORTRESS_COLOR;
	if (terrain == 3) return MINE_COLOR;
	return WASTELAND_COLOR;
}

vec3 get_terrain_dark(int terrain) {
	if (terrain == 1) return FOREST_DARK;
	if (terrain == 2) return FORTRESS_WALL;
	if (terrain == 3) return MINE_DARK;
	return WASTELAND_DARK;
}

// ── Terrain patterns ──

float forest_pattern(vec2 p) {
	float n1 = sin(p.x * 15.0 + p.y * 8.0) * 0.5 + 0.5;
	float n2 = sin(p.y * 12.0 - p.x * 6.0 + 2.0) * 0.5 + 0.5;
	float dots = 1.0 - smoothstep(0.12, 0.18, length(fract(p * 4.0) - 0.5));
	return mix(n1 * n2, dots, 0.4) * 0.25;
}

float fortress_pattern(vec2 p) {
	vec2 cell = fract(p * 5.0) - 0.5;
	float sq = max(abs(cell.x), abs(cell.y));
	float block = 1.0 - smoothstep(0.32, 0.38, sq);
	float inner = 1.0 - smoothstep(0.08, 0.14, sq);
	return (block - inner) * 0.3;
}

float mine_pattern(vec2 p) {
	float scratch1 = sin(p.x * 20.0 + p.y * 5.0) * 0.5 + 0.5;
	float scratch2 = sin(p.y * 18.0 - p.x * 7.0 + 1.5) * 0.5 + 0.5;
	return scratch1 * scratch2 * 0.2;
}

float wasteland_pattern(vec2 p) {
	vec2 cell = fract(p * 3.0) - 0.5;
	float crack = 1.0 - smoothstep(0.01, 0.04, abs(cell.y));
	return crack * 0.08;
}

void fragment() {
	vec2 p = local_pos.xz;

	// Use MODEL-SPACE normal for face detection (not view-space NORMAL)
	vec3 mn = normalize(model_normal);
	bool is_top = mn.y > 0.5;

	vec3 base = tile_color.rgb;

	if (is_top) {
		// Build edge lookup
		int edges[6];
		edges[0] = edge_0;
		edges[1] = edge_1;
		edges[2] = edge_2;
		edges[3] = edge_3;
		edges[4] = edge_4;
		edges[5] = edge_5;

		float dist = hex_dist(p);
		int edge_idx = get_edge_index(p);
		int edge_type = edges[edge_idx];

		// ── Full terrain fill (no wasteland center blob) ──
		vec3 terrain_col = get_terrain_color(edge_type);
		vec3 terrain_dark = get_terrain_dark(edge_type);

		float pattern = 0.0;
		if (edge_type == 0) pattern = wasteland_pattern(p);
		else if (edge_type == 1) pattern = forest_pattern(p);
		else if (edge_type == 2) pattern = fortress_pattern(p);
		else if (edge_type == 3) pattern = mine_pattern(p);

		// Terrain fills entire sector — slight darkening at center for depth
		vec3 terrain_final = mix(terrain_col, terrain_dark, pattern);
		float center_darken = 1.0 - (1.0 - dist) * 0.08;
		base = terrain_final * center_darken;

		// ── Sector border lines (only where terrains differ) ──
		float angle = atan(p.y, p.x);
		if (angle < 0.0) angle += TAU;
		angle = mod(angle + HALF_SECTOR, TAU);
		float sector_angle = mod(angle, SECTOR_WIDTH);
		float border_dist = min(sector_angle, SECTOR_WIDTH - sector_angle);
		float border_line = 1.0 - smoothstep(0.03, 0.06, border_dist);

		int cw_sector = get_cw_sector(p);
		// CW neighbors: next CW sector and prev CW sector
		int next_cw = (cw_sector + 1) % 6;
		int prev_cw = (cw_sector + 5) % 6;
		// Convert CW indices to edge indices for terrain comparison
		int this_edge = edges[(6 - cw_sector) % 6];
		int next_edge = edges[(6 - next_cw) % 6];
		int prev_edge = edges[(6 - prev_cw) % 6];

		bool near_upper = sector_angle > SECTOR_WIDTH * 0.5;
		bool diff_border = (near_upper && this_edge != next_edge) || (!near_upper && this_edge != prev_edge);
		if (diff_border && dist > 0.15) {
			base = mix(base, vec3(0.0), border_line * 0.35);
		}

		// ── Hex edge outline ──
		float outline = smoothstep(0.88, 0.96, dist);
		base = mix(base, terrain_dark * 0.5, outline * 0.6);

	} else {
		// Side faces — darker version of tile base
		base *= 0.5;
	}

	ALBEDO = clamp(base, 0.0, 1.0);
	ROUGHNESS = roughness_val;
	SPECULAR = 0.1;
}
