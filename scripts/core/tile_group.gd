class_name TileGroup
extends RefCounted

## A group of 1-3 tiles placed together.
## Each member has a grid offset from the pivot (0,0) and a terrain type.
## Rotation rotates all offsets around the pivot in 90° increments.

## Shape definitions: arrays of (x,y) offsets relative to pivot (0,0).
enum Shape { DUO_LINE, TRIO_LINE, TRIO_TRIANGLE, TRIO_ANGLE, SINGLE }

const SHAPE_OFFSETS: Dictionary = {
	Shape.DUO_LINE: [Vector2i(0, 0), Vector2i(1, 0)],
	Shape.TRIO_LINE: [Vector2i(-1, 0), Vector2i(0, 0), Vector2i(1, 0)],
	Shape.TRIO_TRIANGLE: [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)],
	Shape.TRIO_ANGLE: [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, -1)],
	Shape.SINGLE: [Vector2i(0, 0)],
}

var shape: int = Shape.DUO_LINE
var terrains: Array[int] = []  ## Terrain per member (same order as offsets)
var rotation: int = 0  ## 0-3 (multiples of 90 degrees CW)
var quest: QuestData = null  ## Optional quest attached to this group
## River connection dirs per member: Vector2i(from_dir, to_dir), -1 = not a river
var river_dirs: Array[Vector2i] = []


## Rotate grid offset by 90 degrees CW, N times.
## Single CW step: (x, y) -> (-y, x)
static func rotate_offset(offset: Vector2i, steps: int) -> Vector2i:
	var x := offset.x
	var y := offset.y
	for i in range(steps % 4):
		var new_x := -y
		var new_y := x
		x = new_x
		y = new_y
	return Vector2i(x, y)


## Returns all offsets with current rotation applied.
func get_rotated_offsets() -> Array[Vector2i]:
	var base_offsets: Array = SHAPE_OFFSETS[shape]
	var result: Array[Vector2i] = []
	for offset in base_offsets:
		result.append(rotate_offset(offset, rotation))
	return result


## Returns absolute cell positions given a pivot cell.
func get_cell_positions(pivot: Vector2i) -> Array[Vector2i]:
	var offsets := get_rotated_offsets()
	var result: Array[Vector2i] = []
	for offset in offsets:
		result.append(pivot + offset)
	return result


## Returns array of {cell: Vector2i, terrain: int} for each member.
func get_placement_data(pivot: Vector2i) -> Array[Dictionary]:
	var offsets := get_rotated_offsets()
	var result: Array[Dictionary] = []
	for i in range(offsets.size()):
		result.append({
			cell = pivot + offsets[i],
			terrain = terrains[i],
		})
	return result


func rotate_cw() -> void:
	rotation = (rotation + 1) % 4


func rotate_ccw() -> void:
	rotation = (rotation + 3) % 4


func member_count() -> int:
	return terrains.size()


## Returns the index of the pivot member (the one at offset 0,0 after rotation).
func pivot_index() -> int:
	var offsets := get_rotated_offsets()
	for i in range(offsets.size()):
		if offsets[i] == Vector2i.ZERO:
			return i
	return 0  # Fallback


## Factory: create a group with given shape and terrains.
static func make(p_shape: int, p_terrains: Array[int]) -> TileGroup:
	var g := TileGroup.new()
	g.shape = p_shape
	g.terrains = p_terrains
	return g
