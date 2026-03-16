class_name CellData
extends RefCounted

## Tile data: Sunscar — fantasy desert landscape with 6 edge types.
## Each tile has 4 edges (E, N, W, S), each edge is one of 6 types.

enum EdgeType { SAND, TRAIL, SETTLEMENT, RUINS, MOUNTAINS, OASIS }

## Edge indices match DIRECTIONS order: E(0), N(1), W(2), S(3)
var edges: Array[int] = [0, 0, 0, 0]

## 4 cardinal neighbor offsets: E, N, W, S
const DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0),    # 0 = E
	Vector2i(0, -1),   # 1 = N
	Vector2i(-1, 0),   # 2 = W
	Vector2i(0, 1),    # 3 = S
]

const EDGE_COLORS: Dictionary = {
	EdgeType.SAND:       Color(0.82, 0.72, 0.48),   # Golden dunes
	EdgeType.TRAIL:      Color(0.50, 0.40, 0.25),   # Caravan path
	EdgeType.SETTLEMENT: Color(0.78, 0.52, 0.30),   # Sandstone walls
	EdgeType.RUINS:      Color(0.55, 0.50, 0.45),   # Weathered stone
	EdgeType.MOUNTAINS:  Color(0.45, 0.40, 0.38),   # Dark rock
	EdgeType.OASIS:      Color(0.30, 0.62, 0.35),   # Lush green
}

const EDGE_NAMES: Array[String] = [
	"Piasek", "Szlak", "Osada", "Ruiny", "Góry", "Oaza"
]

## Base tile color (warm sand)
const BASE_COLOR := Color(0.82, 0.72, 0.48)


static func opposite_dir(dir: int) -> int:
	return (dir + 2) % 4


static func make(template_edges: Array[int]) -> CellData:
	var d := CellData.new()
	d.edges.clear()
	for e: int in template_edges:
		d.edges.append(e)
	return d
