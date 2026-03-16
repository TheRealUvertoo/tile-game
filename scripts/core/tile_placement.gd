class_name TilePlacement
extends Node3D

## Handles tile group placement: hover preview, R-key rotation, slot markers, LMB place.

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

var _previews: Array[Node3D] = []
var _slot_markers: Dictionary = {}    # Vector2i -> MeshInstance3D
var _shared_marker_mesh: ArrayMesh
var _mat_neutral: StandardMaterial3D
var _mat_valid: StandardMaterial3D
var _invalid_overlay: StandardMaterial3D
var _ground_plane := Plane(Vector3.UP, 0)
var _last_tint_valid: int = -1  # -1 = unset, 0 = invalid, 1 = valid (avoids re-tinting)


func _ready() -> void:
	_mat_neutral = _make_unshaded_mat(neutral_color)
	_mat_valid = _make_unshaded_mat(valid_color)
	SignalBus.group_selected.connect(_on_group_selected)
	SignalBus.mystery_tile_spawned.connect(func(_cell: Vector2i) -> void: refresh_slot_markers())
	SignalBus.mystery_tile_discovered.connect(func(_cell: Vector2i, _t: int, _p: int) -> void: refresh_slot_markers())


func _process(_delta: float) -> void:
	_update_hover()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_try_place()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_R:
		_rotate_group()


# ---- Group lifecycle ----

func _on_group_selected(group: TileGroup) -> void:
	current_group = group
	_last_tint_valid = -1
	_rebuild_previews()
	_update_preview()
	refresh_slot_markers()


func _rotate_group() -> void:
	if current_group == null:
		return
	current_group.rotate_cw()
	_last_tint_valid = -1
	_rebuild_previews()
	_update_preview()
	_update_all_marker_colors()


# ---- Hover & preview ----

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
	if current_group == null:
		_hide_previews()
		return

	var cells := current_group.get_cell_positions(hovered_cell)
	var is_valid := grid.is_valid_group_placement(cells)

	for i: int in range(mini(cells.size(), _previews.size())):
		var node := _previews[i]
		node.visible = true
		node.position = grid.grid_to_world(cells[i])
		node.position.y = preview_lift

	# Only re-tint when validity actually changes
	var tint_state := 1 if is_valid else 0
	if tint_state != _last_tint_valid:
		_last_tint_valid = tint_state
		for node: Node3D in _previews:
			_tint_recursive(node, is_valid)


func _hide_previews() -> void:
	for node: Node3D in _previews:
		node.visible = false
	_last_tint_valid = -1


# ---- Placement ----

func _try_place() -> void:
	if current_group == null:
		return
	var cells := current_group.get_cell_positions(hovered_cell)
	if not grid.is_valid_group_placement(cells):
		return
	if grid.try_place_group(hovered_cell, current_group):
		current_group = null
		_hide_previews()
		refresh_slot_markers()


# ---- Preview construction ----

func _rebuild_previews() -> void:
	for node: Node3D in _previews:
		node.queue_free()
	_previews.clear()

	if current_group == null:
		return

	for i: int in range(current_group.member_count()):
		var terrain: int = current_group.terrains[i]
		var scene: PackedScene = TileGrid.TILE_SCENES.get(terrain)
		var node: Node3D = scene.instantiate() if scene else Node3D.new()
		node.visible = false
		# Set flag BEFORE add_child — _ready() checks this to show decorations
		if node is TileBase:
			(node as TileBase)._animation_played = true
		add_child(node)
		_previews.append(node)


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

	var group_celles := current_group.get_cell_positions(hovered_cell)
	var is_valid := grid.is_valid_group_placement(group_celles)
	var valid_set: Dictionary = {}
	if is_valid:
		for cell: Vector2i in group_celles:
			valid_set[cell] = true

	for cell: Vector2i in _slot_markers:
		(_slot_markers[cell] as MeshInstance3D).material_override = _mat_valid if valid_set.has(cell) else _mat_neutral


# ---- Helpers ----

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
