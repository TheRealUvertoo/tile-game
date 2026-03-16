class_name TileGrid
extends Node3D

## Square grid using (x, y) coordinates.
## Supports group placement (2-3 tiles at once).

@export_group("Grid")
@export var tile_size: float = 1.0  ## Distance from center to corner

@export_group("Animation")
@export var tile_stagger: float = 0.35  ## Delay between each tile in a group
@export var merge_shrink_duration: float = 0.25  ## Old tiles shrink time
@export var merge_appear_delay: float = 0.3     ## Delay before merged tile appears

## Preloaded tile scenes — one per terrain type. Edit these in the editor.
const TILE_SCENES: Dictionary = {
	CellData.TerrainType.FOREST: preload("res://scenes/tiles/forest_tile.tscn"),
	CellData.TerrainType.CLEARING: preload("res://scenes/tiles/clearing_tile.tscn"),
	CellData.TerrainType.ROCKS: preload("res://scenes/tiles/rocks_tile.tscn"),
	CellData.TerrainType.WATER: preload("res://scenes/tiles/water_tile.tscn"),
	CellData.TerrainType.DESERT: preload("res://scenes/tiles/desert_tile.tscn"),
	CellData.TerrainType.SWAMP: preload("res://scenes/tiles/swamp_tile.tscn"),
	CellData.TerrainType.MOUNTAIN: preload("res://scenes/tiles/mountain_tile.tscn"),
	CellData.TerrainType.MEADOW: preload("res://scenes/tiles/meadow_tile.tscn"),
	CellData.TerrainType.TUNDRA: preload("res://scenes/tiles/tundra_tile.tscn"),
	CellData.TerrainType.VILLAGE: preload("res://scenes/tiles/village_tile.tscn"),
	CellData.TerrainType.RIVER: preload("res://scenes/tiles/river_tile.tscn"),
}

const MERGED_TILE_SCENES: Dictionary = {
	CellData.TerrainType.FOREST: preload("res://scenes/tiles/merged_forest_tile.tscn"),
	CellData.TerrainType.CLEARING: preload("res://scenes/tiles/merged_clearing_tile.tscn"),
	CellData.TerrainType.ROCKS: preload("res://scenes/tiles/merged_rocks_tile.tscn"),
	CellData.TerrainType.WATER: preload("res://scenes/tiles/merged_water_tile.tscn"),
	CellData.TerrainType.DESERT: preload("res://scenes/tiles/merged_desert_tile.tscn"),
	CellData.TerrainType.SWAMP: preload("res://scenes/tiles/merged_swamp_tile.tscn"),
	CellData.TerrainType.MOUNTAIN: preload("res://scenes/tiles/merged_mountain_tile.tscn"),
	CellData.TerrainType.MEADOW: preload("res://scenes/tiles/merged_meadow_tile.tscn"),
	CellData.TerrainType.TUNDRA: preload("res://scenes/tiles/merged_tundra_tile.tscn"),
	CellData.TerrainType.VILLAGE: preload("res://scenes/tiles/merged_village_tile.tscn"),
	CellData.TerrainType.RIVER: preload("res://scenes/tiles/merged_river_tile.tscn"),
}

## The 4 offsets within a 2×2 block relative to anchor (top-left).
const MERGE_OFFSETS: Array[Vector2i] = [
	Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1),
]

var placed_tiles: Dictionary = {}      ## Vector2i(x,y) -> CellData
var valid_positions: Dictionary = {}   ## Vector2i(x,y) -> true
var merged_tiles: Dictionary = {}      ## Vector2i(x,y) -> Vector2i (cell -> anchor)
var _visuals: Dictionary = {}          ## Vector2i(x,y) -> Node3D
var _merged_visuals: Dictionary = {}   ## Vector2i(anchor) -> Node3D


func grid_to_world(cell: Vector2i) -> Vector3:
	return Vector3(float(cell.x) * tile_size, 0.0, float(cell.y) * tile_size)


func world_to_grid(world_pos: Vector3) -> Vector2i:
	return Vector2i(roundi(world_pos.x / tile_size), roundi(world_pos.z / tile_size))


func get_neighbors(cell: Vector2i) -> Array[Vector2i]:
	## Returns occupied neighbor positions.
	var result: Array[Vector2i] = []
	for dir in range(4):
		var neighbor := cell + CellData.DIRECTIONS[dir]
		if placed_tiles.has(neighbor):
			result.append(neighbor)
	return result


func is_valid_position(cell: Vector2i) -> bool:
	return valid_positions.has(cell) and not placed_tiles.has(cell)


## Check if all cells in the group can be placed.
## All must be empty, and at least one must be adjacent to an existing tile
## (or it's the first placement and placed_tiles is empty).
func is_valid_group_placement(cells: Array[Vector2i]) -> bool:
	var has_adjacency := placed_tiles.is_empty()
	for cell in cells:
		if placed_tiles.has(cell):
			return false
		if not has_adjacency:
			for dir in range(4):
				var neighbor := cell + CellData.DIRECTIONS[dir]
				if placed_tiles.has(neighbor):
					has_adjacency = true
					break
	return has_adjacency


func place_starting_tile(tile: CellData) -> void:
	_place_tile_internal(Vector2i.ZERO, tile)


## Place a group of tiles at once. Returns true on success.
func try_place_group(pivot: Vector2i, group: TileGroup) -> bool:
	var placement_data := group.get_placement_data(pivot)
	var cells: Array[Vector2i] = []
	for entry in placement_data:
		cells.append(entry.cell)

	if not is_valid_group_placement(cells):
		return false

	var tiles: Array[CellData] = []
	var tile_index := 0
	for entry in placement_data:
		var tile := CellData.make(entry.terrain)
		tile.quest = group.quest  # All tiles in group share the quest reference
		# Apply rotated river connections
		if tile.terrain == CellData.TerrainType.RIVER and tile_index < group.river_dirs.size():
			var rd: Vector2i = group.river_dirs[tile_index]
			tile.river_from = CellData.rotate_dir(rd.x, group.rotation)
			tile.river_to = CellData.rotate_dir(rd.y, group.rotation)
		_place_tile_internal(entry.cell, tile, float(tile_index) * tile_stagger)
		tiles.append(tile)
		tile_index += 1

	SignalBus.group_placed.emit(cells, tiles)
	_check_merges(cells)
	return true


func get_valid_positions_array() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	result.assign(valid_positions.keys())
	return result


func get_visual(cell: Vector2i) -> Node3D:
	if _visuals.has(cell):
		return _visuals[cell]
	if merged_tiles.has(cell):
		return _merged_visuals.get(merged_tiles[cell])
	return null


func is_merged(cell: Vector2i) -> bool:
	return merged_tiles.has(cell)


func get_merge_anchor(cell: Vector2i) -> Vector2i:
	return merged_tiles.get(cell, Vector2i(-99999, -99999))


func _place_tile_internal(cell: Vector2i, tile: CellData, delay: float = 0.0) -> void:
	placed_tiles[cell] = tile
	valid_positions.erase(cell)

	var scene: PackedScene = TILE_SCENES.get(tile.terrain)
	var visual: Node3D = scene.instantiate() if scene else Node3D.new()

	# Set deterministic scatter seed before add_child (TileBase._ready uses it)
	if visual is TileBase:
		(visual as TileBase)._scatter_seed = cell.x * 73856093 ^ cell.y * 19349663

	add_child(visual)
	visual.position = grid_to_world(cell)
	_visuals[cell] = visual

	# Tile rise + decoration appear animation (handled by TileBase)
	if visual is TileBase:
		(visual as TileBase).play_appear_animation(delay)

	# Update valid positions (4 neighbors)
	for dir in range(4):
		var neighbor := cell + CellData.DIRECTIONS[dir]
		if not placed_tiles.has(neighbor):
			valid_positions[neighbor] = true


# ---- Tile Merging (2×2 same-terrain → big tile) ----

## Check if newly placed cells complete any 2×2 same-terrain square.
func _check_merges(new_cells: Array[Vector2i]) -> void:
	var checked: Dictionary = {}  # Avoid checking same top-left twice
	for cell: Vector2i in new_cells:
		# Each cell can be part of 4 possible 2×2 squares
		for offset: Vector2i in [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(-1, -1)]:
			var tl := cell + offset
			if checked.has(tl):
				continue
			checked[tl] = true
			_try_merge_at(tl)


## Try to form a 2×2 merge with top-left at `tl`.
func _try_merge_at(tl: Vector2i) -> void:
	var cells: Array[Vector2i] = []
	for off: Vector2i in MERGE_OFFSETS:
		cells.append(tl + off)

	# All 4 must exist, same terrain, not already merged, not river (rivers form chains)
	if not placed_tiles.has(cells[0]):
		return
	var terrain: int = (placed_tiles[cells[0]] as CellData).terrain

	# Rivers should never merge — they form chains, not blocks
	if terrain == CellData.TerrainType.RIVER:
		return

	for cell: Vector2i in cells:
		if not placed_tiles.has(cell):
			return
		if (placed_tiles[cell] as CellData).terrain != terrain:
			return
		if merged_tiles.has(cell):
			return

	_execute_merge(tl, cells, terrain)


## Perform the merge: destroy 4 old visuals, spawn 1 merged visual.
func _execute_merge(anchor: Vector2i, cells: Array[Vector2i], terrain: int) -> void:
	# 1. Record merge mapping
	for cell: Vector2i in cells:
		merged_tiles[cell] = anchor

	# 2. Shrink & destroy old visuals
	for cell: Vector2i in cells:
		var old_visual: Node3D = _visuals.get(cell)
		if old_visual:
			var tween := create_tween()
			tween.tween_property(old_visual, "scale", Vector3.ZERO, merge_shrink_duration) \
				.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
			tween.tween_callback(old_visual.queue_free)
			_visuals.erase(cell)

	# 3. Spawn merged visual after shrink delay
	var merged_scene: PackedScene = MERGED_TILE_SCENES.get(terrain)
	if merged_scene == null:
		return
	var merged_visual: Node3D = merged_scene.instantiate()
	add_child(merged_visual)

	# Center of 2×2 block = anchor + (0.5, 0, 0.5) in grid units
	var center := grid_to_world(anchor) + Vector3(tile_size * 0.5, 0.0, tile_size * 0.5)
	merged_visual.position = center
	_merged_visuals[anchor] = merged_visual

	# Play appear animation with delay matching shrink
	if merged_visual is TileBase:
		(merged_visual as TileBase).play_appear_animation(merge_appear_delay)

	# 4. Emit signal
	SignalBus.tiles_merged.emit(cells, terrain)
