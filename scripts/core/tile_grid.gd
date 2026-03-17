class_name TileGrid
extends Node3D

## Hex grid for Dorfromantik-style tile placement.
## Pointy-top hexagons, axial coordinates (q, r).
## Validates edge matching between adjacent tiles.

## Single tile scene (shader handles visuals)
const TILE_SCENE: PackedScene = preload("res://scenes/tiles/hex_tile.tscn")

## Tower decoration models (placed on fortress-edged tiles)
var _tower_scenes: Array[PackedScene] = []

var placed_tiles: Dictionary = {}      ## Vector2i -> CellData
var valid_positions: Dictionary = {}   ## Vector2i -> true (adjacent to placed)
var _visuals: Dictionary = {}          ## Vector2i -> Node3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	# Load tower scenes
	for i: int in range(1, 4):
		var path := "res://assets/crocotile/wieza-%d.gltf" % i
		if ResourceLoader.exists(path):
			_tower_scenes.append(load(path) as PackedScene)


func grid_to_world(cell: Vector2i) -> Vector3:
	return CellData.hex_to_world(cell)


func world_to_grid(world_pos: Vector3) -> Vector2i:
	return CellData.world_to_hex(world_pos)


func get_neighbors(cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for dir: int in range(6):
		var neighbor := cell + CellData.DIRECTIONS[dir]
		if placed_tiles.has(neighbor):
			result.append(neighbor)
	return result


func is_valid_position(cell: Vector2i) -> bool:
	return valid_positions.has(cell) and not placed_tiles.has(cell)


## Check if a tile can be placed at cell.
## Rules: cell must be empty and adjacent to at least one existing tile.
## Edge matching is NOT required — mismatched edges are allowed but score no bonus.
func is_valid_tile_placement(cell: Vector2i, rotated_edges: Array[int]) -> bool:
	if placed_tiles.has(cell):
		return false

	# First tile can go anywhere
	if placed_tiles.is_empty():
		return true

	for dir: int in range(6):
		var npos := cell + CellData.DIRECTIONS[dir]
		if placed_tiles.has(npos):
			return true

	return false


## Legacy compat for slot markers (adjacency check without edge data).
func is_valid_group_placement(cells: Array[Vector2i]) -> bool:
	if cells.is_empty():
		return false
	var cell: Vector2i = cells[0]
	if placed_tiles.has(cell):
		return false
	if placed_tiles.is_empty():
		return true
	for dir: int in range(6):
		if placed_tiles.has(cell + CellData.DIRECTIONS[dir]):
			return true
	return false


## Place a starting tile at a given cell.
func place_starting_tile(tile: CellData, cell: Vector2i = Vector2i.ZERO) -> void:
	_place_tile_internal(cell, tile)


## Place a tile from a group. Returns true on success.
func try_place_group(pivot: Vector2i, group: TileGroup) -> bool:
	var rotated_edges := group.get_rotated_edges()
	if not is_valid_tile_placement(pivot, rotated_edges):
		return false

	var tile := CellData.make(rotated_edges)
	_place_tile_internal(pivot, tile)

	var cells: Array[Vector2i] = [pivot]
	var tiles: Array[CellData] = [tile]
	SignalBus.group_placed.emit(cells, tiles)
	return true


func get_valid_positions_array() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	result.assign(valid_positions.keys())
	return result


func get_visual(cell: Vector2i) -> Node3D:
	return _visuals.get(cell)


func _place_tile_internal(cell: Vector2i, tile: CellData, _delay: float = 0.0) -> void:
	placed_tiles[cell] = tile
	valid_positions.erase(cell)

	var visual: Node3D = TILE_SCENE.instantiate()

	# Set deterministic seed
	if visual is TileBase:
		(visual as TileBase)._scatter_seed = cell.x * 73856093 ^ cell.y * 19349663

	add_child(visual)
	visual.position = grid_to_world(cell)
	_visuals[cell] = visual

	# Set shader edge parameters
	_set_tile_shader(visual, tile)

	# Spawn decorations based on terrain
	_spawn_decorations(visual, tile, cell)

	# Appear animation
	if visual is TileBase:
		(visual as TileBase).play_appear_animation(_delay)

	# Update valid positions (6 hex neighbors)
	for dir: int in range(6):
		var neighbor := cell + CellData.DIRECTIONS[dir]
		if not placed_tiles.has(neighbor):
			valid_positions[neighbor] = true


## Set shader uniforms for edge types on a tile visual.
func _set_tile_shader(visual: Node3D, tile: CellData) -> void:
	var mesh_inst := _find_tile_mesh(visual)
	if mesh_inst == null:
		return

	var mat: ShaderMaterial = null
	if mesh_inst.mesh and mesh_inst.mesh.get_surface_count() > 0:
		var surf_mat := mesh_inst.mesh.surface_get_material(0)
		if surf_mat is ShaderMaterial:
			# Duplicate mesh + material per instance
			mesh_inst.mesh = mesh_inst.mesh.duplicate()
			mat = (surf_mat as ShaderMaterial).duplicate()
			mesh_inst.mesh.surface_set_material(0, mat)

	if mat == null:
		return

	# Set 6 edge uniforms
	mat.set_shader_parameter("edge_0", tile.edges[0])  # E
	mat.set_shader_parameter("edge_1", tile.edges[1])  # NE
	mat.set_shader_parameter("edge_2", tile.edges[2])  # NW
	mat.set_shader_parameter("edge_3", tile.edges[3])  # W
	mat.set_shader_parameter("edge_4", tile.edges[4])  # SW
	mat.set_shader_parameter("edge_5", tile.edges[5])  # SE
	mat.set_shader_parameter("tile_color", CellData.BASE_COLOR)


func _find_tile_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		return node as MeshInstance3D
	for child: Node in node.get_children():
		var result := _find_tile_mesh(child)
		if result != null:
			return result
	return null


## Spawn 3D decorations on the tile based on terrain edges.
func _spawn_decorations(visual: Node3D, tile: CellData, cell: Vector2i) -> void:
	if _tower_scenes.is_empty():
		return

	# Count fortress edges
	var fortress_count := 0
	for dir: int in range(6):
		if tile.edges[dir] == CellData.TerrainType.FORTRESS:
			fortress_count += 1

	if fortress_count == 0:
		return

	# Deterministic seed per cell
	_rng.seed = (cell.x * 73856093 ^ cell.y * 19349663) & 0x7FFFFFFF

	# Number of towers: 1-3 based on fortress edge count
	var num_towers := clampi(ceili(float(fortress_count) / 2.0), 1, 3)

	var hex_r := CellData.HEX_SIZE * 0.3  # Keep towers within inner area
	for i: int in range(num_towers):
		var tower_scene: PackedScene = _tower_scenes[_rng.randi() % _tower_scenes.size()]
		var tower: Node3D = tower_scene.instantiate()

		# Random position within hex (offset from center toward fortress edges)
		var angle := _rng.randf() * TAU
		var dist := _rng.randf() * hex_r
		var offset := Vector3(cos(angle) * dist, 0.03, sin(angle) * dist)

		# Small random scale (0.04 - 0.07 — tiny towers on tile)
		var s := _rng.randf_range(0.04, 0.07)
		tower.scale = Vector3(s, s, s)

		# Random Y rotation
		tower.rotation.y = _rng.randf() * TAU

		tower.position = offset
		visual.add_child(tower)
