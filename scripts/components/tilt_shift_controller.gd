class_name TiltShiftController
extends ColorRect

## Drives tilt-shift blur strength based on camera zoom distance.
## Attach to the TiltShift ColorRect.

@export var enabled: bool = true
@export var camera_path: NodePath
@export var blur_at_min_zoom: float = 4.0   ## Blur when fully zoomed in
@export var blur_at_max_zoom: float = 0.0   ## Blur when fully zoomed out
@export var focal_center_close: float = 0.5  ## Focal band center when close
@export var focal_center_far: float = 0.45   ## Focal band center when far
@export var focal_width_close: float = 0.1   ## Narrow sharp band when close
@export var focal_width_far: float = 0.3     ## Wide sharp band when far

var _camera: CameraController
var _shader_mat: ShaderMaterial


func _ready() -> void:
	_camera = get_node(camera_path) as CameraController
	_shader_mat = material as ShaderMaterial


func _process(_delta: float) -> void:
	if not enabled or _camera == null or _shader_mat == null:
		return

	var zoom_t := inverse_lerp(
		_camera.min_distance, _camera.max_distance, _camera.distance)

	# zoom_t: 0 = close, 1 = far
	_shader_mat.set_shader_parameter("blur_strength",
		lerpf(blur_at_min_zoom, blur_at_max_zoom, zoom_t))
	_shader_mat.set_shader_parameter("focal_center",
		lerpf(focal_center_close, focal_center_far, zoom_t))
	_shader_mat.set_shader_parameter("focal_width",
		lerpf(focal_width_close, focal_width_far, zoom_t))
