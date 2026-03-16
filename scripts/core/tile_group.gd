class_name TileGroup
extends RefCounted

## A single tile with 4 edges, Carcassonne-style.
## Rotation rotates edges around the tile.

var edges: Array[int] = [0, 0, 0, 0]  ## Template edges [E, N, W, S]
var rotation: int = 0  ## 0-3 (multiples of 90 degrees CW)
var template_name: String = ""


## Get edges after applying rotation.
## CW rotation: N->E, E->S, S->W, W->N
## In our order (E=0,N=1,W=2,S=3): rotated[i] = template[(i + rotation) % 4]
func get_rotated_edges() -> Array[int]:
	var result: Array[int] = []
	for i: int in range(4):
		result.append(edges[(i + rotation) % 4])
	return result


## Rotate 90 degrees clockwise.
func rotate_cw() -> void:
	rotation = (rotation + 1) % 4


## Always single tile at origin.
func get_rotated_offsets() -> Array[Vector2i]:
	return [Vector2i(0, 0)]


## Get cell positions for placement at pivot.
func get_cell_positions(pivot: Vector2i) -> Array[Vector2i]:
	return [pivot]


## Get placement data for tile_grid.
func get_placement_data(pivot: Vector2i) -> Array[Dictionary]:
	return [{ cell = pivot, edges = get_rotated_edges() }]


## Number of tiles in this group (always 1 for Carcassonne-style).
func member_count() -> int:
	return 1
