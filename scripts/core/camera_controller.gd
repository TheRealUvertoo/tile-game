class_name CameraController
extends Camera3D

## Orbit camera — this IS the Camera3D node.
## E/Q = snap-rotate 90°, WASD = pan, Scroll = zoom.
## Fixed pitch angle, smooth zoom, DoF stronger when close.

@export_group("Orbit")
@export var distance: float = 6.0
@export var min_distance: float = 3.0
@export var max_distance: float = 25.0
@export var yaw: float = 0.0
@export var pitch: float = -60.0       ## Base pitch at max zoom out (degrees)
@export var pitch_zoom_shift: float = 10.0  ## Degrees toward horizon when fully zoomed in

@export_group("Snap Rotation")
@export var snap_angle: float = 90.0
@export var snap_duration: float = 0.3
@export var snap_ease: Tween.EaseType = Tween.EASE_IN_OUT
@export var snap_trans: Tween.TransitionType = Tween.TRANS_CUBIC

@export_group("WASD Movement")
@export var move_speed: float = 5.0

@export_group("Pan")
@export var pan_speed: float = 0.01

@export_group("Zoom")
@export var zoom_speed: float = 1.0
@export var fov_default: float = 50.0

@export_group("Smoothing")
@export var move_smoothing: float = 10.0 ## Higher = snappier WASD/pan response
@export var zoom_smoothing: float = 8.0  ## Higher = snappier zoom response

@export_group("Depth of Field")
@export var dof_enabled: bool = false
@export var dof_blur_amount_close: float = 1.0   ## Blur at min zoom (close = more blur)
@export var dof_blur_amount_far: float = 0.0     ## Blur at max zoom (far = less blur)
@export var dof_far_distance_close: float = 3.5   ## DoF distance at min zoom
@export var dof_far_distance_far: float = 30.0    ## DoF distance at max zoom
@export var dof_far_transition: float = 2.0

## Current snap-target yaw. Accessible by other systems for initial sync.
static var current_yaw: float = 0.0
## Current animated yaw (smoothly interpolated). Updated every frame during tween.
static var animated_yaw: float = 0.0

var _target_yaw: float = 0.0
var _current_pitch: float = -60.0
var _pivot := Vector3.ZERO
var _target_pivot := Vector3.ZERO
var _target_distance: float = 6.0
var _is_panning := false
var _snap_tween: Tween
var _cam_attributes: CameraAttributesPractical


## Returns 0.0 (closest) to 1.0 (farthest) based on current zoom distance.
func _get_zoom_t() -> float:
	return inverse_lerp(min_distance, max_distance, distance)


func _ready() -> void:
	fov = fov_default
	_target_yaw = yaw

	# Clamp distance to valid range (inspector may have distance outside min/max)
	distance = clampf(distance, min_distance, max_distance)
	_target_distance = distance

	# Compute initial pitch from zoom position
	_current_pitch = pitch + pitch_zoom_shift * (1.0 - _get_zoom_t())

	CameraController.current_yaw = yaw
	CameraController.animated_yaw = yaw

	# Depth of Field
	_setup_dof()

	_update_camera()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_MIDDLE:
				_is_panning = event.pressed
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed:
					_target_distance = maxf(min_distance, _target_distance - zoom_speed)
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed:
					_target_distance = minf(max_distance, _target_distance + zoom_speed)

	elif event is InputEventMouseMotion:
		if _is_panning:
			var right := global_transform.basis.x
			var forward := Vector3(right.z, 0, -right.x).normalized()
			var pan_factor := pan_speed * distance * 0.1
			_target_pivot -= right * event.relative.x * pan_factor
			_target_pivot -= forward * event.relative.y * pan_factor

	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E:
			_snap_rotate(snap_angle)
		elif event.keycode == KEY_Q:
			_snap_rotate(-snap_angle)


func _process(delta: float) -> void:
	# WASD → update target pivot
	var input_dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_W): input_dir.y += 1.0
	if Input.is_key_pressed(KEY_S): input_dir.y -= 1.0
	if Input.is_key_pressed(KEY_A): input_dir.x -= 1.0
	if Input.is_key_pressed(KEY_D): input_dir.x += 1.0

	if input_dir != Vector2.ZERO:
		input_dir = input_dir.normalized()
		var right := global_transform.basis.x
		var forward := Vector3(right.z, 0, -right.x).normalized()
		var zoom_scale := distance / min_distance  # Faster when zoomed out
		_target_pivot += right * input_dir.x * move_speed * zoom_scale * delta
		_target_pivot += forward * input_dir.y * move_speed * zoom_scale * delta

	# Smooth interpolation
	var smooth_factor := 1.0 - exp(-move_smoothing * delta)
	var zoom_factor := 1.0 - exp(-zoom_smoothing * delta)

	_pivot = _pivot.lerp(_target_pivot, smooth_factor)
	distance = lerpf(distance, _target_distance, zoom_factor)

	# Pitch shifts slightly toward horizon when zoomed in
	_current_pitch = pitch + pitch_zoom_shift * (1.0 - _get_zoom_t())

	# Update DoF based on current zoom
	_update_dof()

	_update_camera()


func _snap_rotate(angle: float) -> void:
	_target_yaw += angle
	CameraController.current_yaw = _target_yaw

	# Emit BEFORE tween — wrapper starts rotating simultaneously with camera
	SignalBus.camera_rotated.emit(_target_yaw)

	if _snap_tween and _snap_tween.is_valid():
		_snap_tween.kill()

	_snap_tween = create_tween()
	_snap_tween.tween_method(_set_yaw_and_update, yaw, _target_yaw, snap_duration) \
		.set_ease(snap_ease).set_trans(snap_trans)


func _set_yaw_and_update(new_yaw: float) -> void:
	yaw = new_yaw
	CameraController.animated_yaw = new_yaw
	_update_camera()


func _update_camera() -> void:
	var pitch_rad := deg_to_rad(_current_pitch)
	var yaw_rad := deg_to_rad(yaw)

	var offset := Vector3(
		cos(pitch_rad) * sin(yaw_rad),
		-sin(pitch_rad),
		cos(pitch_rad) * cos(yaw_rad)
	) * distance

	# Texel snap: reduce pixel swimming during pan
	# Use _target_distance so the snap grid stays stable during zoom transitions
	var vp := get_viewport()
	if vp:
		var vp_h := float(vp.size.y)
		if vp_h > 0.0:
			var texel_size := 2.0 * _target_distance * tan(deg_to_rad(fov * 0.5)) / vp_h
			if texel_size > 0.0:
				_pivot.x = snapped(_pivot.x, texel_size)
				_pivot.z = snapped(_pivot.z, texel_size)

	global_position = _pivot + offset
	look_at(_pivot)


func _setup_dof() -> void:
	if not dof_enabled:
		return
	_cam_attributes = CameraAttributesPractical.new()
	_cam_attributes.dof_blur_far_enabled = true
	_cam_attributes.dof_blur_far_transition = dof_far_transition
	attributes = _cam_attributes
	_update_dof()


func _update_dof() -> void:
	if _cam_attributes == null:
		return
	var t := _get_zoom_t()
	_cam_attributes.dof_blur_far_distance = lerpf(
		dof_far_distance_close, dof_far_distance_far, t)
	_cam_attributes.dof_blur_amount = lerpf(
		dof_blur_amount_close, dof_blur_amount_far, t)
