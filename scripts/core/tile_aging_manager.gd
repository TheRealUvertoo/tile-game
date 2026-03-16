class_name TileAgingManager
extends Node

## Manages tile aging: some tiles grow taller after X turns.
## A "turn" = all 3 hand slots used (full hand cycle).
## Aging tiles do a bounce animation (jump up, come back taller).

@export var age_chance: float = 0.3  ## Chance per tile per turn to age
@export var max_age: int = 3  ## Max number of times a tile can age
@export var height_per_age: float = 0.04  ## Extra Y height per age level
@export var bounce_height: float = 0.25  ## How high the tile jumps during aging
@export var bounce_duration: float = 0.4  ## Total bounce animation time
@export var stagger_range: float = 0.3  ## Random delay stagger between tiles

## Only natural terrains can age (grow over time)
const AGEABLE_TERRAINS: Array[int] = [
	CellData.TerrainType.FOREST,
	CellData.TerrainType.CLEARING,
	CellData.TerrainType.SWAMP,
	CellData.TerrainType.MEADOW,
]

var _grid: TileGrid
var _tile_ages: Dictionary = {}  ## Vector2i → int (age count)
var _rng := RandomNumberGenerator.new()


func set_grid(grid: TileGrid) -> void:
	_grid = grid


func _ready() -> void:
	_rng.randomize()
	SignalBus.group_placed.connect(_on_group_placed)


func _on_group_placed(cells: Array[Vector2i], _tiles: Array[CellData]) -> void:
	# Register newly placed tiles at age 0
	for cell: Vector2i in cells:
		if not _tile_ages.has(cell):
			_tile_ages[cell] = 0


## Called by Main when a full turn completes (all 3 hand slots used).
func on_turn_complete() -> void:
	if _grid == null:
		return

	# Collect eligible tiles (not merged, below max age, natural terrain only)
	var eligible: Array[Vector2i] = []
	for cell: Vector2i in _tile_ages:
		if _tile_ages[cell] >= max_age:
			continue
		if _grid.merged_tiles.has(cell):
			continue
		if not _grid._visuals.has(cell):
			continue
		var tile: CellData = _grid.placed_tiles.get(cell)
		if tile == null or not AGEABLE_TERRAINS.has(tile.terrain):
			continue
		eligible.append(cell)

	if eligible.is_empty():
		return

	# Pick random subset to age
	var to_age: Array[Vector2i] = []
	for cell: Vector2i in eligible:
		if _rng.randf() < age_chance:
			to_age.append(cell)

	# Animate aging with stagger
	for i in range(to_age.size()):
		var cell: Vector2i = to_age[i]
		var delay := _rng.randf_range(0.0, stagger_range)
		_age_tile(cell, delay)


func _age_tile(cell: Vector2i, delay: float) -> void:
	var visual: Node3D = _grid._visuals.get(cell)
	if visual == null:
		return

	_tile_ages[cell] += 1
	var new_age: int = _tile_ages[cell]
	var target_y: float = new_age * height_per_age

	# Bounce animation: current pos → jump up → land at new height
	var current_y: float = visual.position.y
	var jump_y: float = current_y + bounce_height
	var land_y: float = target_y

	var tween := _grid.create_tween()
	tween.tween_interval(delay)

	# Jump up (fast)
	tween.tween_property(visual, "position:y", jump_y, bounce_duration * 0.35) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	# Come down to new height (with bounce)
	tween.tween_property(visual, "position:y", land_y, bounce_duration * 0.65) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)

	# Scale the mesh slightly taller
	var mesh := _find_tile_mesh(visual)
	if mesh and mesh.mesh is BoxMesh:
		var box: BoxMesh = mesh.mesh
		# Duplicate mesh so we don't affect other tiles sharing it
		if not visual.has_meta("mesh_duped"):
			box = box.duplicate()
			mesh.mesh = box
			visual.set_meta("mesh_duped", true)
		var new_height: float = 0.06 + new_age * height_per_age
		tween.parallel().tween_property(box, "size:y", new_height, bounce_duration) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)


func _find_tile_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		return node as MeshInstance3D
	for child in node.get_children():
		var result := _find_tile_mesh(child)
		if result != null:
			return result
	return null


func get_tile_age(cell: Vector2i) -> int:
	return _tile_ages.get(cell, 0)
