class_name TileGroup
extends RefCounted

## Single hex tile with 6 edges and rotation.
## Rotation is in 60° CW increments (0-5).
## Edge order: E(0), NE(1), NW(2), W(3), SW(4), SE(5)

var edges: Array[int] = [0, 0, 0, 0, 0, 0]
var rotation: int = 0
var template_name: String = ""


## Get edges after applying current rotation.
## CW rotation by N steps: rotated[i] = edges[(i - N + 6) % 6]
func get_rotated_edges() -> Array[int]:
	var result: Array[int] = []
	for i: int in range(6):
		result.append(edges[(i - rotation + 6) % 6])
	return result


## Rotate 60° clockwise.
func rotate_cw() -> void:
	rotation = (rotation + 1) % 6


## Always a single hex tile.
func get_rotated_offsets() -> Array[Vector2i]:
	return [Vector2i(0, 0)]


func get_cell_positions(pivot: Vector2i) -> Array[Vector2i]:
	return [pivot]


func get_placement_data(pivot: Vector2i) -> Array[Dictionary]:
	return [{ cell = pivot, edges = get_rotated_edges() }]


func member_count() -> int:
	return 1
