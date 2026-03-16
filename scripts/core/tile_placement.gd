class_name TilePlacement
extends Node3D

## Handles Carcassonne-style tile placement: hover preview, R-key rotation, LMB place.

var grid: TileGrid
var camera: Camera3D
var current_group: TileGroup
var hovered_cell: Vector2i = Vector2i(99999, 99999)

@export_group("Preview")
@export var preview_lift: float = 0.02
@export var invalid_tint: Color = Color(1.0, 0.3, 0.3, 0.6)

@export_group("Slot Markers")
@export var marker_y_offset: float = 0.005
@export var valid_color: Color = Color(0.3, 1.0, 0.3, 0.35)
@export var neutral_color: Color = Color(1.0, 1.0, 1.0, 0.12)

var _preview: Node3D = null
var _slot_markers: Dictionary = {}
var _shared_marker_mesh: ArrayMesh
var _mat_neutral: StandardMaterial3D
var _mat_valid: StandardMaterial3D
var _invalid_overlay: StandardMaterial3D
var _ground_plane := Plane(Vector3.UP, 0)
var _last_tint_valid: int = -1


func _ready() -> void:
	_mat_neutral = _make_unshaded_mat(neutral_color)
	_mat_valid = _make_unshaded_mat(valid_color)
	SignalBus.group_selected.connect(_on_group_selected)


func _process(_delta: float) -> void:
	_update_hover()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_try_place()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_R:
		_rotate_group()


func _on_group_selected(group: TileGroup) -> void:
	current_group = group
	_last_tint_valid = -1
	_rebuild_preview()
	_update_preview()
	refresh_slot_markers()


func _rotate_group() -> void:
	if current_group == null:
		return
	current_group.rotate_cw()
	_last_tint_valid = -1
	_rebuild_preview()
	_update_preview()
	_update_all_marker_colors()


func _update_hover() -> void:
	if current_group == null or camera == null or grid == null:
		return
	var mouse_pos := get_viewport().get_mouse_position()
	var origin := camera.project_ray_origin(mouse_pos)
	var dir := camera.project_ray_normal(mouse_pos)
	var intersection: Variant = _ground_plane.intersects_ray(origin, dir)
	if intersection == null:
		return
	var new_cell := grid.world_to_grid(intersection as Vector3)
	if new_cell != hovered_cell:
		hovered_cell = new_cell
		_update_preview()
		_update_all_marker_colors()


func _update_preview() -> void:
	if current_group == null or _preview == null:
		_hide_preview()
		return

	_preview.visible = true
	_preview.position = grid.grid_to_world(hovered_cell)
	_preview.position.y = preview_lift

	var rotated_edges := current_group.get_rotated_edges()
	var is_valid := grid.is_valid_tile_placement(hovered_cell, rotated_edges)

	var tint_state := 1 if is_valid else 0
	if tint_state != _last_tint_valid:
		_last_tint_valid = tint_state
		_tint_recursive(_preview, is_valid)


func _hide_preview() -> void:
	if _preview != null:
		_preview.visible = false
	_last_tint_valid = -1


func _try_place() -> void:
	if current_group == null:
		return
	var rotated_edges := current_group.get_rotated_edges()
	if not grid.is_valid_tile_placement(hovered_cell, rotated_edges):
		return
	if grid.try_place_group(hovered_cell, current_group):
		current_group = null
		_hide_preview()
		refresh_slot_markers()


func _rebuild_preview() -> void:
	if _preview != null:
		_preview.queue_free()
		_preview = null

	if current_group == null:
		return

	var node: Node3D = TileGrid.TILE_SCENE.instantiate()
	node.visible = false
	if node is TileBase:
		(node as TileBase)._animation_played = true
	add_child(node)
	_preview = node

	# Set edge shader on preview
	var rotated_edges := current_group.get_rotated_edges()
	var mesh_inst := _find_mesh(node)
	if mesh_inst != null and mesh_inst.mesh and mesh_inst.mesh.get_surface_count() > 0:
		var surf_mat := mesh_inst.mesh.surface_get_material(0)
		if surf_mat is ShaderMaterial:
			mesh_inst.mesh = mesh_inst.mesh.duplicate()
			var mat := (surf_mat as ShaderMaterial).duplicate()
			mesh_inst.mesh.surface_set_material(0, mat)
			mat.set_shader_parameter("edge_e", rotated_edges[0])
			mat.set_shader_parameter("edge_n", rotated_edges[1])
			mat.set_shader_parameter("edge_w", rotated_edges[2])
			mat.set_shader_parameter("edge_s", rotated_edges[3])
			mat.set_shader_parameter("tile_color", CellData.BASE_COLOR)


func _find_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		return node as MeshInstance3D
	for child: Node in node.get_children():
		var result := _find_mesh(child)
		if result != null:
			return result
	return null


# ---- Slot markers ----

func refresh_slot_markers() -> void:
	var current_valid := grid.valid_positions
	var to_remove: Array[Vector2i] = []
	for pos: Vector2i in _slot_markers:
		if not current_valid.has(pos):
			to_remove.append(pos)
	for pos: Vector2i in to_remove:
		(_slot_markers[pos] as MeshInstance3D).queue_free()
		_slot_markers.erase(pos)
	for pos: Vector2i in current_valid:
		if not _slot_markers.has(pos):
			_slot_markers[pos] = _create_marker(pos)
	_update_all_marker_colors()


func _create_marker(cell: Vector2i) -> MeshInstance3D:
	if _shared_marker_mesh == null:
		_shared_marker_mesh = _build_marker_mesh()
	var mi := MeshInstance3D.new()
	mi.mesh = _shared_marker_mesh
	mi.position = grid.grid_to_world(cell)
	mi.position.y = marker_y_offset
	mi.material_override = _mat_neutral
	add_child(mi)
	return mi


func _build_marker_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_color(Color.WHITE)
	st.set_normal(Vector3.UP)
	var half := (grid.tile_size if grid else 1.0) * 0.5
	st.add_vertex(Vector3(half, 0.0, -half))
	st.add_vertex(Vector3(half, 0.0, half))
	st.add_vertex(Vector3(-half, 0.0, half))
	st.add_vertex(Vector3(half, 0.0, -half))
	st.add_vertex(Vector3(-half, 0.0, half))
	st.add_vertex(Vector3(-half, 0.0, -half))
	return st.commit()


func _update_all_marker_colors() -> void:
	if current_group == null:
		for cell: Vector2i in _slot_markers:
			(_slot_markers[cell] as MeshInstance3D).material_override = _mat_neutral
		return

	var rotated_edges := current_group.get_rotated_edges()
	var is_valid := grid.is_valid_tile_placement(hovered_cell, rotated_edges)

	for cell: Vector2i in _slot_markers:
		var mat: StandardMaterial3D
		if cell == hovered_cell and is_valid:
			mat = _mat_valid
		else:
			mat = _mat_neutral
		(_slot_markers[cell] as MeshInstance3D).material_override = mat


static func _make_unshaded_mat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	return mat


func _get_invalid_overlay() -> StandardMaterial3D:
	if _invalid_overlay == null:
		_invalid_overlay = StandardMaterial3D.new()
		_invalid_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_invalid_overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_invalid_overlay.albedo_color = invalid_tint
		_invalid_overlay.no_depth_test = true
	return _invalid_overlay


func _tint_recursive(node: Node, is_valid: bool) -> void:
	if node is Sprite3D:
		(node as Sprite3D).modulate = Color.WHITE if is_valid else invalid_tint
	elif node is MeshInstance3D:
		(node as MeshInstance3D).material_overlay = null if is_valid else _get_invalid_overlay()
	for child: Node in node.get_children():
		_tint_recursive(child, is_valid)
