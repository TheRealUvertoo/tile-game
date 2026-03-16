class_name GroundPlane
extends MeshInstance3D

## Large ground plane beneath the tiles.
## Simple colored plane — prototype version.

@export_group("Appearance")
@export var ground_color: Color = Color(0.75, 0.72, 0.65):
	set(v):
		ground_color = v
		_update_material()

@export_range(0.0, 1.0, 0.01) var roughness: float = 0.9:
	set(v):
		roughness = v
		_update_material()

@export_group("Size")
@export var plane_size: Vector2 = Vector2(100, 100):
	set(v):
		plane_size = v
		_update_mesh_size()

@export var y_offset: float = -0.01:
	set(v):
		y_offset = v
		position.y = y_offset

var _mat: StandardMaterial3D


func _ready() -> void:
	if mesh == null:
		mesh = PlaneMesh.new()
	_update_mesh_size()
	_ensure_material()
	position.y = y_offset


func _ensure_material() -> void:
	if material_override is StandardMaterial3D:
		_mat = material_override as StandardMaterial3D
	else:
		_mat = StandardMaterial3D.new()
		material_override = _mat
	_update_material()


func _update_material() -> void:
	if _mat == null:
		return
	_mat.albedo_color = ground_color
	_mat.roughness = roughness


func _update_mesh_size() -> void:
	if mesh is PlaneMesh:
		(mesh as PlaneMesh).size = plane_size
