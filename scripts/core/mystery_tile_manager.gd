class_name MysteryTileManager
extends Node

## Spawns special "mystery" tiles far from the player (5-10 tiles away).
## Max 2 active at once, all GRAY while hidden.
## When the player places adjacent tiles, the mystery tile is discovered
## and revealed with a unique terrain-colored flash.

@export var discover_points: int = 20
@export var spawn_chance: float = 0.35  ## Chance per placement to spawn
@export var max_mystery_tiles: int = 2
@export var min_distance: int = 5  ## Min Manhattan distance from nearest placed tile
@export var max_distance: int = 10  ## Max Manhattan distance

const MYSTERY_GRAY := Color(0.55, 0.55, 0.55, 0.75)

## Bright reveal colors per terrain — shown briefly on discovery
const REVEAL_COLORS: Array[Color] = [
	Color(0.2, 0.75, 0.3, 1.0),   # Forest — vivid green
	Color(0.55, 0.9, 0.35, 1.0),  # Clearing — bright lime
	Color(0.65, 0.5, 0.35, 1.0),  # Rocks — warm brown
	Color(0.2, 0.55, 1.0, 1.0),   # Water — vivid blue
	Color(0.9, 0.75, 0.4, 1.0),   # Desert — bright sand
	Color(0.4, 0.6, 0.3, 1.0),    # Swamp — murky green
	Color(0.55, 0.6, 0.75, 1.0),  # Mountain — cool slate
	Color(0.85, 0.8, 0.4, 1.0),   # Meadow — golden
	Color(0.7, 0.85, 0.95, 1.0),  # Tundra — icy
	Color(0.75, 0.5, 0.35, 1.0),  # Village — terracotta
	Color(0.3, 0.6, 0.9, 1.0),    # River — bright blue
]

const WATER_CHANCE := 0.25  ## 25% chance mystery tile reveals as Water

var _grid: TileGrid
var _mystery_cells: Dictionary = {}  ## Vector2i → true
var _mystery_visuals: Dictionary = {}  ## Vector2i → Node3D
var _rng := RandomNumberGenerator.new()


func set_grid(grid: TileGrid) -> void:
	_grid = grid


func _ready() -> void:
	_rng.randomize()
	SignalBus.group_placed.connect(_on_group_placed)


func _on_group_placed(cells: Array[Vector2i], _tiles: Array[CellData]) -> void:
	if _grid == null:
		return

	# Check if any placed tile is adjacent to a mystery tile → discover it
	for cell: Vector2i in cells:
		for dir in range(4):
			var neighbor := cell + CellData.DIRECTIONS[dir]
			if _mystery_cells.has(neighbor):
				_discover_tile(neighbor)

	# Maybe spawn a new mystery tile
	if _mystery_cells.size() < max_mystery_tiles and _rng.randf() < spawn_chance:
		_try_spawn_mystery_tile()


func _try_spawn_mystery_tile() -> void:
	# BFS outward from all placed tiles to find cells at distance 5-10
	var candidates: Array[Vector2i] = []
	var visited: Dictionary = {}
	var queue: Array[Dictionary] = []

	for cell: Vector2i in _grid.placed_tiles:
		visited[cell] = true
		queue.append({ cell = cell, dist = 0 })

	var head := 0
	while head < queue.size():
		var entry: Dictionary = queue[head]
		head += 1
		var cell: Vector2i = entry.cell
		var dist: int = entry.dist

		if dist >= max_distance:
			continue

		for dir in range(4):
			var neighbor: Vector2i = cell + CellData.DIRECTIONS[dir]
			if visited.has(neighbor):
				continue
			visited[neighbor] = true
			var ndist := dist + 1
			queue.append({ cell = neighbor, dist = ndist })

			if ndist >= min_distance and ndist <= max_distance:
				if not _grid.placed_tiles.has(neighbor) and not _mystery_cells.has(neighbor):
					candidates.append(neighbor)

	if candidates.is_empty():
		return

	var chosen := candidates[_rng.randi_range(0, candidates.size() - 1)]
	_spawn_mystery_at(chosen)


func _spawn_mystery_at(cell: Vector2i) -> void:
	_mystery_cells[cell] = true
	_grid.valid_positions.erase(cell)

	var visual := Node3D.new()
	var mesh_inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.85, 0.06, 0.85)
	mesh_inst.mesh = box

	var mat := StandardMaterial3D.new()
	mat.albedo_color = MYSTERY_GRAY
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = Color(0.55, 0.55, 0.55)
	mat.emission_energy_multiplier = 0.5
	mesh_inst.material_override = mat
	visual.add_child(mesh_inst)

	# "?" label — gray/white to match the mysterious look
	var label := Label3D.new()
	label.text = "?"
	label.font_size = 72
	label.position = Vector3(0, 0.08, 0)
	label.rotation.x = -PI / 2.0
	label.modulate = Color(0.85, 0.85, 0.85, 0.9)
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.no_depth_test = true
	label.outline_size = 4
	label.outline_modulate = Color(0, 0, 0, 0.5)
	visual.add_child(label)

	_grid.add_child(visual)
	visual.position = _grid.grid_to_world(cell)
	_mystery_visuals[cell] = visual

	# Appear: scale from zero with bounce
	visual.scale = Vector3.ZERO
	var tween := _grid.create_tween()
	tween.tween_property(visual, "scale", Vector3(1.1, 1.1, 1.1), 0.2) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(visual, "scale", Vector3.ONE, 0.15) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)

	# Idle pulse animation
	var pulse_tween := _grid.create_tween()
	pulse_tween.set_loops()
	pulse_tween.tween_property(mat, "emission_energy_multiplier", 1.2, 1.0) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	pulse_tween.tween_property(mat, "emission_energy_multiplier", 0.3, 1.0) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	visual.set_meta("pulse_tween", pulse_tween)

	SignalBus.mystery_tile_spawned.emit(cell)


func _discover_tile(cell: Vector2i) -> void:
	if not _mystery_cells.has(cell):
		return

	_mystery_cells.erase(cell)

	# Reveal: 25% chance Water (exclusive to mystery tiles), 75% random standard terrain
	var terrain: int
	if _rng.randf() < WATER_CHANCE:
		terrain = CellData.TerrainType.WATER
	else:
		var t := _rng.randi_range(0, CellData.DECK_TERRAIN_COUNT - 1)
		if t >= CellData.TerrainType.WATER:
			t += 1  # Skip WATER
		terrain = t
	var reveal_color: Color = REVEAL_COLORS[terrain] if terrain < REVEAL_COLORS.size() else Color.WHITE

	# Flash the mystery visual to the reveal color, then shrink away
	var visual: Node3D = _mystery_visuals.get(cell)
	if visual:
		if visual.has_meta("pulse_tween"):
			var pt: Tween = visual.get_meta("pulse_tween")
			if pt.is_valid():
				pt.kill()

		# Flash to terrain color before disappearing
		var mesh_inst: MeshInstance3D = visual.get_child(0) as MeshInstance3D
		if mesh_inst and mesh_inst.material_override is StandardMaterial3D:
			var mat: StandardMaterial3D = mesh_inst.material_override as StandardMaterial3D
			mat.albedo_color = Color(reveal_color.r, reveal_color.g, reveal_color.b, 0.95)
			mat.emission = Color(reveal_color.r, reveal_color.g, reveal_color.b)
			mat.emission_energy_multiplier = 2.0

		# Flash the "?" label to terrain color too
		if visual.get_child_count() > 1:
			var label: Label3D = visual.get_child(1) as Label3D
			if label:
				label.modulate = Color(reveal_color.r * 1.3, reveal_color.g * 1.3, reveal_color.b * 1.3, 1.0)

		var tween := _grid.create_tween()
		tween.tween_property(visual, "scale", Vector3(1.4, 1.4, 1.4), 0.12) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(visual, "scale", Vector3.ZERO, 0.2) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
		tween.tween_callback(visual.queue_free)
		_mystery_visuals.erase(cell)

	var tile := CellData.make(terrain)
	_grid.placed_tiles[cell] = tile
	_grid.valid_positions.erase(cell)

	for dir in range(4):
		var neighbor := cell + CellData.DIRECTIONS[dir]
		if not _grid.placed_tiles.has(neighbor) and not _mystery_cells.has(neighbor):
			_grid.valid_positions[neighbor] = true

	# Spawn tile visual
	var scene: PackedScene = TileGrid.TILE_SCENES.get(terrain)
	var tile_visual: Node3D = scene.instantiate() if scene else Node3D.new()

	if tile_visual is TileBase:
		(tile_visual as TileBase)._scatter_seed = cell.x * 73856093 ^ cell.y * 19349663

	_grid.add_child(tile_visual)
	tile_visual.position = _grid.grid_to_world(cell)
	_grid._visuals[cell] = tile_visual

	if tile_visual is TileBase:
		(tile_visual as TileBase).play_appear_animation(0.0)

	# Water gives bonus discovery points (rare terrain reward)
	var points := discover_points
	if terrain == CellData.TerrainType.WATER:
		points += 10
	SignalBus.mystery_tile_discovered.emit(cell, terrain, points)


func is_mystery(cell: Vector2i) -> bool:
	return _mystery_cells.has(cell)


func spawn_initial(count: int) -> void:
	for i in range(count):
		if _mystery_cells.size() >= max_mystery_tiles:
			break
		_try_spawn_mystery_tile()
