class_name RuinsManager
extends Node

## Spawns ruins on the hex map. Discovered when any tile is placed adjacent.
## Discovered ruins yield artifacts (bonus points, extra tiles, etc.)

@export var initial_ruins: int = 5
@export var max_ruins: int = 8
@export var spawn_distance_min: int = 5
@export var spawn_distance_max: int = 10
@export var spawn_chance: float = 0.25
@export var spawn_every_n_turns: int = 3

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

	# Check if any placed tile is adjacent to an undiscovered ruin
	_check_discovery(cells)

	# Periodically spawn new ruins
	if _placement_count % spawn_every_n_turns == 0:
		if _ruins.size() < max_ruins:
			_try_spawn_ruin()
	elif _rng.randf() < spawn_chance and _ruins.size() < max_ruins:
		_try_spawn_ruin()


func _check_discovery(placed_cells: Array[Vector2i]) -> void:
	for cell: Vector2i in placed_cells:
		for dir: int in range(6):
			var neighbor := cell + CellData.DIRECTIONS[dir]
			if not _ruins.has(neighbor):
				continue

			var ruin_data: Dictionary = _ruins[neighbor]
			if ruin_data.discovered:
				continue

			_discover_ruin(neighbor)


func _discover_ruin(cell: Vector2i) -> void:
	var ruin_data: Dictionary = _ruins[cell]
	ruin_data.discovered = true

	var artifact := _roll_artifact()

	# Discovered ruin becomes wasteland tile matching neighbor edges
	var wasteland_edges: Array[int] = [0, 0, 0, 0, 0, 0]
	for dir: int in range(6):
		var npos := cell + CellData.DIRECTIONS[dir]
		if _grid.placed_tiles.has(npos):
			var ntile: CellData = _grid.placed_tiles[npos]
			wasteland_edges[dir] = ntile.edges[CellData.opposite_dir(dir)]
	var tile := CellData.make(wasteland_edges)
	_grid.placed_tiles[cell] = tile
	_grid.valid_positions.erase(cell)

	# Update valid positions around the discovered ruin
	for dir: int in range(6):
		var neighbor := cell + CellData.DIRECTIONS[dir]
		if not _grid.placed_tiles.has(neighbor):
			_grid.valid_positions[neighbor] = true

	# Update shader on existing visual
	var visual: Node3D = ruin_data.visual
	if visual != null:
		_grid._set_tile_shader(visual, tile)
		_animate_discovery(visual)

	# Emit discovery signal (if connected)
	if SignalBus.has_signal("ruin_discovered"):
		SignalBus.ruin_discovered.emit(cell, artifact.name as String, artifact.points as int, artifact.groups as int)


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
	var attempts := 30
	for i: int in range(attempts):
		var angle := _rng.randf() * TAU
		var dist := _rng.randi_range(spawn_distance_min, spawn_distance_max)
		var cell := Vector2i(
			roundi(cos(angle) * float(dist)),
			roundi(sin(angle) * float(dist))
		)

		if _grid.placed_tiles.has(cell):
			continue
		if _ruins.has(cell):
			continue

		_spawn_ruin_at(cell)
		return


func _spawn_ruin_at(cell: Vector2i) -> void:
	var visual: Node3D = TileGrid.TILE_SCENE.instantiate()
	if visual is TileBase:
		(visual as TileBase)._animation_played = true

	_grid.add_child(visual)
	visual.position = _grid.grid_to_world(cell)

	# All wasteland edges for ruin placeholder
	var ruin_edges: Array[int] = [0, 0, 0, 0, 0, 0]
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

	# Block placement
	_grid.placed_tiles[cell] = CellData.make(ruin_edges)
	_grid.valid_positions.erase(cell)


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
	for child: Node in visual.get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).material_overlay = null

	var tw := _grid.create_tween()
	tw.tween_property(visual, "scale", Vector3(1.2, 1.3, 1.2), 0.15) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(visual, "scale", Vector3.ONE, 0.2) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func is_ruin(cell: Vector2i) -> bool:
	return _ruins.has(cell)


func is_undiscovered_ruin(cell: Vector2i) -> bool:
	return _ruins.has(cell) and not (_ruins[cell] as Dictionary).discovered
