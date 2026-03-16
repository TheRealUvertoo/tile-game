@tool
class_name SpriteTint
extends Sprite3D

## Adds brightness/tint controls to a Sprite3D via sprite_tint.gdshader.
## All parameters are tweakable in the inspector and update live in editor.

@export_group("Tint")
@export_range(0.0, 2.0, 0.01) var brightness: float = 1.0:
	set(v):
		brightness = v
		_update_shader_param("brightness", v)

@export var tint_color: Color = Color.WHITE:
	set(v):
		tint_color = v
		_update_shader_param("tint_color", v)

@export_range(0.0, 1.0, 0.01) var alpha_scissor: float = 0.5:
	set(v):
		alpha_scissor = v
		_update_shader_param("alpha_scissor", v)

var _shader_mat: ShaderMaterial

func _ready() -> void:
	_ensure_material()
	_apply_all_params()

func _ensure_material() -> void:
	if material_override is ShaderMaterial:
		_shader_mat = material_override as ShaderMaterial
		return

	# Auto-create ShaderMaterial with sprite_tint shader
	var shader = load("res://shaders/sprite_tint.gdshader") as Shader
	if shader == null:
		push_warning("SpriteTint: sprite_tint.gdshader not found")
		return

	_shader_mat = ShaderMaterial.new()
	_shader_mat.shader = shader
	material_override = _shader_mat

func _apply_all_params() -> void:
	if _shader_mat == null:
		return
	# Sprite3D auto-binds its texture to "texture_albedo" uniform
	_shader_mat.set_shader_parameter("brightness", brightness)
	_shader_mat.set_shader_parameter("tint_color", tint_color)
	_shader_mat.set_shader_parameter("alpha_scissor", alpha_scissor)

func _update_shader_param(param: String, value: Variant) -> void:
	if _shader_mat == null and is_node_ready():
		_ensure_material()
	if _shader_mat:
		_shader_mat.set_shader_parameter(param, value)
