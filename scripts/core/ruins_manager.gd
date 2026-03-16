class_name RuinsManager
extends Node

## Spawns ruins on the map and discovers them when a trail connects to them.
## Discovered ruins yield artifacts (bonus points, extra tiles, etc.)

@export var initial_ruins: int = 5
@export var max_ruins: int = 8
@export var spawn_distance_min: int = 3   ## Min distance from origin for new ruins
@export var spawn_distance_max: int = 8   ## Max distance from origin for new ruins
@export var spawn_chance: float = 0.25    ## Chance to spawn new ruin after placement
@export var spawn_every_n_turns: int = 3  ## Also spawn after N placements

var _grid: TileGrid
var _rng := RandomNumberGenerator.new()

## cell → { discovered: bool, visual: Node3D }
var _ruins: Dictionary = {}
var _placement_count: int = 0


## Artifact table: name, points, groups, weight
const ARTIFACTS: Array[Dictionary] = [
	{ name = "Starożytna mapa", points = 0, groups = 5, weight = 3 },
	{ name = "Złoty skarabeusz", points = 40, groups = 0, weight = 3 },
	{ name = "Obelisk", points = 50, groups = 0, weight = 2 },
	{ name = "Ukryte źródło", points = 20, groups = 2, weight = 3 },
	{ name = "Złoty idol", points = 75, groups = 0, weight = 1 },
	{ name = "Tablice losu", points = 30, groups = 3, weight = 2 },
]


func init(grid: TileGrid) -> void:
	_grid = grid
	_rng.randomize()
	SignalBus.group_placed.connect(_on_group_placed)
	_spawn_initial_ruins()


func _spawn_initial_ruins() -> void:
	for i: int in range(initial_ruins):
		_try_spawn_ruin()


func _on_group_placed(cells: Array[Vector2i], _tiles: Array[CellData]) -> void:
	_placement_count += 1

	# Check if any placed tile has a trail edge touching a ruin
	_check_trail_discovery(cells)

	# Periodically spawn new ruins
	if _placement_count % spawn_every_n_turns == 0:
		if _ruins.size() < max_ruins:
			_try_spawn_ruin()
	elif _rng.randf() < spawn_chance and _ruins.size() < max_ruins:
		_try_spawn_ruin()


func _check_trail_discovery(placed_cells: Array[Vector2i]) -> void:
	for cell: Vector2i in placed_cells:
		if not _grid.placed_tiles.has(cell):
			continue
		var tile: CellData = _grid.placed_tiles[cell]

		for dir: int in range(4):
			# Check if this tile's edge is a trail
			if tile.edges[dir] != CellData.EdgeType.TRAIL:
				continue

			var neighbor := cell + CellData.DIRECTIONS[dir]
			if not _ruins.has(neighbor):
				continue

			var ruin_data: Dictionary = _ruins[neighbor]
			if ruin_data.discovered:
				continue

			# Trail connects to undiscovered ruin — discover it!
			_discover_ruin(neighbor)


func _discover_ruin(cell: Vector2i) -> void:
	var ruin_data: Dictionary = _ruins[cell]
	ruin_data.discovered = true

	# Roll artifact
	var artifact := _roll_artifact()

	# Discovered ruin becomes a sand tile (easy to build around)
	var sand_edges: Array[int] = [
		CellData.EdgeType.SAND, CellData.EdgeType.SAND,
		CellData.EdgeType.SAND, CellData.EdgeType.SAND
	]
	var sand_tile := CellData.make(sand_edges)
	_grid.placed_tiles[cell] = sand_tile
	_grid.valid_positions.erase(cell)

	# Update valid positions around the ruin
	for dir: int in range(4):
		var neighbor := cell + CellData.DIRECTIONS[dir]
		if not _grid.placed_tiles.has(neighbor):
			_grid.valid_positions[neighbor] = true

	# Update visual — change from mystery to discovered (keep ruins look)
	var visual: Node3D = ruin_data.visual
	if visual != null:
		_animate_discovery(visual)
		# Visual stays as ruins appearance (shader unchanged, just remove tint)

	SignalBus.ruin_discovered.emit(cell, artifact.name, artifact.points, artifact.groups)


func _roll_artifact() -> Dictionary:
	var total_weight := 0
	for a: Dictionary in ARTIFACTS:
		total_weight += a.weight as int

	var roll := _rng.randi_range(0, total_weight - 1)
	var cumulative := 0
	for a: Dictionary in ARTIFACTS:
		cumulative += a.weight as int
		if roll < cumulative:
			return a

	return ARTIFACTS[0]


func _try_spawn_ruin() -> void:
	# Find a valid position at distance from existing tiles
	var attempts := 30
	for i: int in range(attempts):
		var angle := _rng.randf() * TAU
		var dist := _rng.randi_range(spawn_distance_min, spawn_distance_max)
		var cell := Vector2i(
			roundi(cos(angle) * float(dist)),
			roundi(sin(angle) * float(dist))
		)

		# Must not be on existing tile or existing ruin
		if _grid.placed_tiles.has(cell):
			continue
		if _ruins.has(cell):
			continue

		_spawn_ruin_at(cell)
		return


func _spawn_ruin_at(cell: Vector2i) -> void:
	# Create a visual (same tile scene but with mystery look)
	var visual: Node3D = TileGrid.TILE_SCENE.instantiate()
	if visual is TileBase:
		(visual as TileBase)._animation_played = true

	_grid.add_child(visual)
	visual.position = _grid.grid_to_world(cell)

	# Set it to look like a mystery ruin (all ruins edges, darkened)
	var ruin_edges: Array[int] = [
		CellData.EdgeType.RUINS, CellData.EdgeType.RUINS,
		CellData.EdgeType.RUINS, CellData.EdgeType.RUINS
	]
	var ruin_tile := CellData.make(ruin_edges)
	_grid._set_tile_shader(visual, ruin_tile)

	# Darken to show it's undiscovered
	_apply_mystery_tint(visual)

	# Appear animation
	visual.scale = Vector3.ZERO
	var tw := _grid.create_tween()
	tw.tween_property(visual, "scale", Vector3.ONE, 0.4) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	_ruins[cell] = { discovered = false, visual = visual }

	# Block this position from normal placement by adding a placeholder tile
	var placeholder := CellData.make(ruin_edges)
	_grid.placed_tiles[cell] = placeholder
	_grid.valid_positions.erase(cell)

	SignalBus.ruin_spawned.emit(cell)


func _apply_mystery_tint(visual: Node3D) -> void:
	for child: Node in visual.get_children():
		if child is MeshInstance3D:
			var mi := child as MeshInstance3D
			var overlay := StandardMaterial3D.new()
			overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			overlay.albedo_color = Color(0.3, 0.3, 0.35, 0.5)
			mi.material_overlay = overlay


func _animate_discovery(visual: Node3D) -> void:
	# Remove mystery tint
	for child: Node in visual.get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).material_overlay = null

	# Discovery animation: flash + scale pop
	var tw := _grid.create_tween()
	tw.tween_property(visual, "scale", Vector3(1.2, 1.3, 1.2), 0.15) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(visual, "scale", Vector3.ONE, 0.2) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


## Check if a cell has an undiscovered ruin (for placement blocking).
func is_ruin(cell: Vector2i) -> bool:
	return _ruins.has(cell)


## Check if a cell has an undiscovered ruin.
func is_undiscovered_ruin(cell: Vector2i) -> bool:
	return _ruins.has(cell) and not (_ruins[cell] as Dictionary).discovered
