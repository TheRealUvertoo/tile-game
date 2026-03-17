class_name CellData
extends RefCounted

## Hex tile data: Sunscar/Isengard — 6 edges, 4 terrain types.
## Pointy-top hex with axial coordinates (q, r).
## Edge order: E(0), NE(1), NW(2), W(3), SW(4), SE(5)

enum TerrainType { WASTELAND, FOREST, FORTRESS, MINE }

## 6 edges, one terrain type each
var edges: Array[int] = [0, 0, 0, 0, 0, 0]

## 6 hex neighbor offsets in axial coordinates (pointy-top)
## E, NE, NW, W, SW, SE
const DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0),    # 0 = E
	Vector2i(1, -1),   # 1 = NE
	Vector2i(0, -1),   # 2 = NW
	Vector2i(-1, 0),   # 3 = W
	Vector2i(-1, 1),   # 4 = SW
	Vector2i(0, 1),    # 5 = SE
]

const NUM_EDGES := 6

const TERRAIN_COLORS: Dictionary = {
	TerrainType.WASTELAND: Color(0.42, 0.38, 0.32),   # Scorched earth
	TerrainType.FOREST:    Color(0.20, 0.38, 0.15),   # Dark Fangorn green
	TerrainType.FORTRESS:  Color(0.35, 0.30, 0.28),   # Dark iron/stone
	TerrainType.MINE:      Color(0.55, 0.40, 0.22),   # Excavated brown/orange
}

const TERRAIN_NAMES: Array[String] = [
	"Ugór", "Puszcza", "Warownia", "Kopalnia"
]

## Base tile color (barren wasteland ground)
const BASE_COLOR := Color(0.42, 0.38, 0.32)

## Hex size (outer radius — center to vertex)
const HEX_SIZE := 0.5


## Opposite edge direction (across the hex)
static func opposite_dir(dir: int) -> int:
	return (dir + 3) % 6


## Create a CellData from an edge array.
static func make(template_edges: Array[int]) -> CellData:
	var d := CellData.new()
	d.edges.clear()
	for e: int in template_edges:
		d.edges.append(e)
	return d


## Hex grid to world position (pointy-top, axial coords).
## x = size * (sqrt(3) * q + sqrt(3)/2 * r)
## z = size * (3/2 * r)
static func hex_to_world(cell: Vector2i) -> Vector3:
	var q := float(cell.x)
	var r := float(cell.y)
	var x := HEX_SIZE * (sqrt(3.0) * q + sqrt(3.0) / 2.0 * r)
	var z := HEX_SIZE * (1.5 * r)
	return Vector3(x, 0.0, z)


## World position to nearest hex (axial coords, pointy-top).
static func world_to_hex(world_pos: Vector3) -> Vector2i:
	var q := (sqrt(3.0) / 3.0 * world_pos.x - 1.0 / 3.0 * world_pos.z) / HEX_SIZE
	var r := (2.0 / 3.0 * world_pos.z) / HEX_SIZE
	return _axial_round(q, r)


## Round fractional axial coords to nearest hex.
static func _axial_round(q: float, r: float) -> Vector2i:
	var s := -q - r
	var rq := roundf(q)
	var rr := roundf(r)
	var rs := roundf(s)
	var dq := absf(rq - q)
	var dr := absf(rr - r)
	var ds := absf(rs - s)
	if dq > dr and dq > ds:
		rq = -rr - rs
	elif dr > ds:
		rr = -rq - rs
	return Vector2i(int(rq), int(rr))
