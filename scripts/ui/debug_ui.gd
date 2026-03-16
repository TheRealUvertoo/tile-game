extends Control

## Debug UI for real-time shader parameter tweaking.
## Press TAB to toggle visibility. Panel blocks mouse when visible.

@onready var panel: PanelContainer = $Panel
var outline_mat: ShaderMaterial
var palette_mat: ShaderMaterial

func _ready() -> void:
	visible = true
	panel.visible = false

	# Style the panel
	panel.custom_minimum_size = Vector2(420, 0)
	panel.position = Vector2(10, 10)

	# Add a dark background style
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.12, 0.92)
	style.border_color = Color(0.4, 0.4, 0.45, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)

	# Find outline material (on OutlineQuad)
	var outline_quad = get_tree().root.find_child("OutlineQuad", true, false)
	if outline_quad and outline_quad is MeshInstance3D:
		outline_mat = outline_quad.material_override as ShaderMaterial

	# Find palette material (on PaletteRect)
	var palette_rect = get_tree().root.find_child("PaletteRect", true, false)
	if palette_rect and palette_rect is ColorRect:
		palette_mat = palette_rect.material as ShaderMaterial

	_build_ui()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_TAB:
		panel.visible = !panel.visible
		# Block/unblock mouse on the parent Control
		mouse_filter = Control.MOUSE_FILTER_STOP if panel.visible else Control.MOUSE_FILTER_IGNORE
		get_viewport().set_input_as_handled()

func _build_ui() -> void:
	var vbox = panel.get_node("VBox")
	vbox.add_theme_constant_override("separation", 6)

	_add_header(vbox, "SHADER DEBUG  [TAB to toggle]")
	_add_separator(vbox)

	# --- OUTLINE ---
	_add_header(vbox, "OUTLINE")

	if outline_mat:
		_add_slider(vbox, "Crease Threshold", 0.001, 1.0,
			outline_mat.get_shader_parameter("crease_threshold"),
			func(v): outline_mat.set_shader_parameter("crease_threshold", v))

		_add_slider(vbox, "Silhouette Threshold", 0.001, 2.0,
			outline_mat.get_shader_parameter("silhouette_threshold"),
			func(v): outline_mat.set_shader_parameter("silhouette_threshold", v))

		_add_slider(vbox, "Line Width", 1.0, 5.0,
			outline_mat.get_shader_parameter("line_width"),
			func(v): outline_mat.set_shader_parameter("line_width", v))

		_add_slider(vbox, "Lit Blend", 0.0, 1.0,
			outline_mat.get_shader_parameter("lit_blend"),
			func(v): outline_mat.set_shader_parameter("lit_blend", v))

		_add_color_picker(vbox, "Shadow Color",
			outline_mat.get_shader_parameter("outline_color_shadow"),
			func(c): outline_mat.set_shader_parameter("outline_color_shadow", c))

		_add_color_picker(vbox, "Lit Color",
			outline_mat.get_shader_parameter("outline_color_lit"),
			func(c): outline_mat.set_shader_parameter("outline_color_lit", c))
	else:
		_add_label(vbox, "  (!) OutlineQuad not found")

	_add_separator(vbox)

	# --- PALETTE ---
	_add_header(vbox, "PALETTE QUANTIZATION")

	if palette_mat:
		_add_toggle(vbox, "Enabled",
			palette_mat.get_shader_parameter("enabled"),
			func(v): palette_mat.set_shader_parameter("enabled", v))

		_add_slider(vbox, "Palette Size", 2, 64,
			palette_mat.get_shader_parameter("palette_size"),
			func(v): palette_mat.set_shader_parameter("palette_size", int(v)))
	else:
		_add_label(vbox, "  (!) PaletteRect not found")

	_add_separator(vbox)

	# --- VIEWPORT ---
	_add_header(vbox, "VIEWPORT")
	var svc = get_tree().root.find_child("SubViewportContainer", true, false)
	if svc and svc is SubViewportContainer:
		_add_slider(vbox, "Pixel Scale (shrink)", 1, 8,
			svc.stretch_shrink,
			func(v): svc.stretch_shrink = int(v))

func _add_header(parent: Control, text: String) -> void:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	parent.add_child(label)

func _add_label(parent: Control, text: String) -> void:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.7, 0.5, 0.5))
	parent.add_child(label)

func _add_separator(parent: Control) -> void:
	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	parent.add_child(sep)

func _add_slider(parent: Control, label_text: String, min_val: float, max_val: float, current: Variant, callback: Callable) -> void:
	var hbox = HBoxContainer.new()

	var label = Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 170
	label.add_theme_font_size_override("font_size", 14)
	hbox.add_child(label)

	var slider = HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.step = (max_val - min_val) / 500.0
	slider.value = float(current) if current != null else min_val
	slider.custom_minimum_size.x = 160
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(slider)

	var value_label = Label.new()
	value_label.text = "%.3f" % slider.value
	value_label.custom_minimum_size.x = 55
	value_label.add_theme_font_size_override("font_size", 13)
	value_label.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6))
	hbox.add_child(value_label)

	slider.value_changed.connect(func(v):
		callback.call(v)
		value_label.text = "%.3f" % v
	)

	parent.add_child(hbox)

func _add_toggle(parent: Control, label_text: String, current: Variant, callback: Callable) -> void:
	var check = CheckBox.new()
	check.text = label_text
	check.button_pressed = bool(current) if current != null else true
	check.add_theme_font_size_override("font_size", 14)
	check.toggled.connect(func(v): callback.call(v))
	parent.add_child(check)

func _add_color_picker(parent: Control, label_text: String, current: Variant, callback: Callable) -> void:
	var hbox = HBoxContainer.new()

	var label = Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 170
	label.add_theme_font_size_override("font_size", 14)
	hbox.add_child(label)

	var btn = ColorPickerButton.new()
	btn.color = current if current != null else Color.BLACK
	btn.custom_minimum_size = Vector2(100, 28)
	btn.color_changed.connect(func(c): callback.call(c))
	hbox.add_child(btn)

	parent.add_child(hbox)
