@tool
class_name GrassLayer
extends MultiMeshInstance3D

## Procedural grass layer using MultiMesh.
## Uses BinbunGrass shader system (assets/Grass/).
## Add as child of a tile scene to place grass on top.

@export_group("Grass")
@export var instance_count: int = 2000:
	set(v):
		instance_count = v
		if Engine.is_editor_hint():
			_rebuild()

@export var blade_width: float = 0.1:
	set(v):
		blade_width = v
		if Engine.is_editor_hint():
			_update_quad_size()

@export var blade_height: float = 0.1:
	set(v):
		blade_height = v
		if Engine.is_editor_hint():
			_update_quad_size()

@export var spread: float = 0.5:
	set(v):
		spread = v
		if Engine.is_editor_hint():
			_rebuild()

@export_group("Material")
@export var grass_material: Material:
	set(v):
		grass_material = v
		_apply_material()

@export_group("Appearance")
@export var color_palette: Texture2D:
	set(v):
		color_palette = v
		_set_shader_param("color_gradient", v)

@export var shape_atlas_texture: Texture2D:
	set(v):
		shape_atlas_texture = v
		_set_shader_param("shape_atlas", v)

@export_range(0, 2) var alpha_mode: int = 0:
	set(v):
		alpha_mode = v
		_set_shader_param("alpha_mode", v)

@export_range(0.0, 1.0, 0.01) var alpha_cut_start: float = 0.1:
	set(v):
		alpha_cut_start = v
		_set_shader_param("alpha_cut_start", v)

@export_range(0.0, 1.0, 0.01) var alpha_cut_end: float = 0.9:
	set(v):
		alpha_cut_end = v
		_set_shader_param("alpha_cut_end", v)

@export_range(0.0, 1.0, 0.001) var random_variation: float = 0.002:
	set(v):
		random_variation = v
		_set_shader_param("random_variation", v)

@export_group("Wind")
@export var wind_velocity: Vector2 = Vector2.ZERO:
	set(v):
		wind_velocity = v
		_set_shader_param("wind_velocity", v)

@export_group("Idle Sway")
@export_range(0.0, 1.0, 0.001) var idle_sway_strength: float = 0.05:
	set(v):
		idle_sway_strength = v
		# Idle sway is part of the wind system in the shader

@export_group("Detail")
@export_range(0.0, 1.0, 0.01) var pixel_detail_strength: float = 0.0:
	set(v):
		pixel_detail_strength = v


func _ready() -> void:
	if multimesh == null:
		_rebuild()
	elif grass_material:
		_apply_material()


func _rebuild() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = instance_count

	var quad := QuadMesh.new()
	quad.size = Vector2(blade_width, blade_height)
	quad.subdivide_width = 2
	quad.subdivide_depth = 2
	quad.center_offset = Vector3(0, blade_height * 0.5, 0)
	mm.mesh = quad

	# Scatter instances randomly within spread area
	for i in range(instance_count):
		var t := Transform3D()
		var pos := Vector3(
			randf_range(-spread, spread),
			0.0,
			randf_range(-spread, spread)
		)
		# Random Y rotation
		var angle := randf() * TAU
		t = t.rotated(Vector3.UP, angle)
		# Random scale variation
		var s := randf_range(0.7, 1.3)
		t = t.scaled(Vector3(s, s, s))
		t.origin = pos
		mm.set_instance_transform(i, t)

	multimesh = mm
	_apply_material()


func _update_quad_size() -> void:
	if multimesh and multimesh.mesh is QuadMesh:
		var quad := multimesh.mesh as QuadMesh
		quad.size = Vector2(blade_width, blade_height)
		quad.center_offset = Vector3(0, blade_height * 0.5, 0)


func _apply_material() -> void:
	if grass_material:
		material_override = grass_material


func _set_shader_param(param: String, value: Variant) -> void:
	if material_override is ShaderMaterial:
		(material_override as ShaderMaterial).set_shader_parameter(param, value)
