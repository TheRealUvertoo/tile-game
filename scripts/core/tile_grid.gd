class_name TileGrid
extends Node3D

## Square grid for Carcassonne-style tile placement.
## Validates edge matching between adjacent tiles.

@export_group("Grid")
@export var tile_size: float = 1.0

@export_group("Animation")
@export var tile_stagger: float = 0.0  ## No stagger for single tiles

## Single tile scene for all tiles (shader handles visuals)
const TILE_SCENE: PackedScene = preload("res://scenes/tiles/desert_tile.tscn")

var placed_tiles: Dictionary = {}      ## Vector2i -> CellData
var valid_positions: Dictionary = {}   ## Vector2i -> true (adjacent to placed)
var _visuals: Dictionary = {}          ## Vector2i -> Node3D


func grid_to_world(cell: Vector2i) -> Vector3:
	return Vector3(float(cell.x) * tile_size, 0.0, float(cell.y) * tile_size)


func world_to_grid(world_pos: Vector3) -> Vector2i:
	return Vector2i(roundi(world_pos.x / tile_size), roundi(world_pos.z / tile_size))


func get_neighbors(cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for dir: int in range(4):
		var neighbor := cell + CellData.DIRECTIONS[dir]
		if placed_tiles.has(neighbor):
			result.append(neighbor)
	return result


func is_valid_position(cell: Vector2i) -> bool:
	return valid_positions.has(cell) and not placed_tiles.has(cell)


## Check if a tile with given edges can be placed at cell.
## Rules: cell must be empty, adjacent to existing tile, ALL touching edges must match.
func is_valid_tile_placement(cell: Vector2i, rotated_edges: Array[int]) -> bool:
	if placed_tiles.has(cell):
		return false

	# First tile can go anywhere
	if placed_tiles.is_empty():
		return true

	var has_neighbor := false
	for dir: int in range(4):
		var npos := cell + CellData.DIRECTIONS[dir]
		if not placed_tiles.has(npos):
			continue
		has_neighbor = true

		# Edge matching: my edge must equal neighbor's opposite edge
		var ntile: CellData = placed_tiles[npos]
		var my_edge: int = rotated_edges[dir]
		var their_edge: int = ntile.edges[CellData.opposite_dir(dir)]
		if my_edge != their_edge:
			return false

	return has_neighbor


## Legacy compatibility — used by slot markers for basic adjacency check.
func is_valid_group_placement(cells: Array[Vector2i]) -> bool:
	if cells.is_empty():
		return false
	# For Carcassonne, we can't check without edge data.
	# Return true if cell is empty and adjacent (edge check done separately).
	var cell: Vector2i = cells[0]
	if placed_tiles.has(cell):
		return false
	if placed_tiles.is_empty():
		return true
	for dir: int in range(4):
		if placed_tiles.has(cell + CellData.DIRECTIONS[dir]):
			return true
	return false


## Place the starting tile at origin.
func place_starting_tile(tile: CellData) -> void:
	_place_tile_internal(Vector2i.ZERO, tile)


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

	# Appear animation
	if visual is TileBase:
		(visual as TileBase).play_appear_animation(_delay)

	# Update valid positions
	for dir: int in range(4):
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

	mat.set_shader_parameter("edge_e", tile.edges[0])
	mat.set_shader_parameter("edge_n", tile.edges[1])
	mat.set_shader_parameter("edge_w", tile.edges[2])
	mat.set_shader_parameter("edge_s", tile.edges[3])
	mat.set_shader_parameter("tile_color", CellData.BASE_COLOR)


func _find_tile_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		return node as MeshInstance3D
	for child: Node in node.get_children():
		var result := _find_tile_mesh(child)
		if result != null:
			return result
	return null
