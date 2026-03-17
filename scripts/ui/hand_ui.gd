class_name HandUI
extends Control

## Bottom-center hand bar — shows HAND_SIZE clickable hex tile slots.
## Each slot draws a hex with colored edge sectors.

const HAND_SIZE := HandManager.HAND_SIZE

@export_group("Layout")
@export var slot_size := Vector2(140, 140)
@export var slot_gap := 16.0
@export var bottom_margin := 36.0

@export_group("Slot Visuals")
@export var bg_color := Color(0.12, 0.12, 0.12, 0.75)
@export var bg_color_empty := Color(0.08, 0.08, 0.08, 0.4)
@export var selected_border_color := Color(1.0, 0.92, 0.5, 0.9)
@export var selected_border_width := 4.0

var _slots: Array[_HandSlot] = []
var _container: HBoxContainer
var _swap_label: Label
var _swap_available: bool = true


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE

	_container = HBoxContainer.new()
	_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_container.add_theme_constant_override("separation", int(slot_gap))
	_container.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_container)

	_container.anchor_left = 0.5
	_container.anchor_right = 0.5
	_container.anchor_top = 1.0
	_container.anchor_bottom = 1.0
	var total_w := slot_size.x * HAND_SIZE + slot_gap * (HAND_SIZE - 1)
	_container.offset_left = -total_w / 2.0
	_container.offset_right = total_w / 2.0
	_container.offset_top = -(slot_size.y + bottom_margin)
	_container.offset_bottom = -bottom_margin

	for i: int in range(HAND_SIZE):
		var slot := _HandSlot.new()
		slot.slot_index = i
		slot.custom_minimum_size = slot_size
		slot.bg_color = bg_color
		slot.bg_color_empty = bg_color_empty
		slot.selected_border_color = selected_border_color
		slot.selected_border_width = selected_border_width
		slot.slot_clicked.connect(_on_slot_clicked)
		slot.slot_right_clicked.connect(_on_slot_right_clicked)
		_container.add_child(slot)
		_slots.append(slot)

	_swap_label = Label.new()
	_swap_label.text = "PPM = Wymień (1/rękę)"
	_swap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_swap_label.add_theme_font_size_override("font_size", 18)
	_swap_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	_swap_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_swap_label.add_theme_constant_override("outline_size", 3)
	_swap_label.anchor_left = 0.5
	_swap_label.anchor_right = 0.5
	_swap_label.anchor_top = 1.0
	_swap_label.anchor_bottom = 1.0
	_swap_label.offset_left = -140
	_swap_label.offset_right = 140
	_swap_label.offset_top = -(slot_size.y + bottom_margin + 30)
	_swap_label.offset_bottom = -(slot_size.y + bottom_margin + 4)
	add_child(_swap_label)

	SignalBus.hand_changed.connect(_on_hand_changed)
	SignalBus.hand_slot_selected.connect(_on_slot_selected)
	SignalBus.hand_slot_used.connect(_on_slot_used)
	SignalBus.swap_available_changed.connect(_on_swap_available_changed)
	SignalBus.hand_slot_swapped.connect(_on_slot_swapped)


func _on_hand_changed(hand: Array) -> void:
	var is_full_redraw := true
	for i: int in range(mini(hand.size(), _slots.size())):
		if hand[i] != null and _slots[i].group != null:
			is_full_redraw = false
		_slots[i].set_group(hand[i])
		_slots[i].is_selected = false
		_slots[i].queue_redraw()
	if is_full_redraw:
		for i: int in range(_slots.size()):
			if _slots[i].group != null:
				_slots[i].slide_in(float(i) * 0.08)


func _on_slot_selected(index: int) -> void:
	for i: int in range(_slots.size()):
		_slots[i].is_selected = (i == index)
		_slots[i].queue_redraw()


func _on_slot_used(index: int) -> void:
	if index >= 0 and index < _slots.size():
		var slot := _slots[index]
		var tw := create_tween()
		tw.tween_property(slot, "scale", Vector2(0.85, 0.85), 0.08) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tw.tween_callback(func() -> void:
			slot.set_group(null)
			slot.is_selected = false
			slot.queue_redraw()
			slot.scale = Vector2.ONE
		)


func _on_swap_available_changed(available: bool) -> void:
	_swap_available = available
	if _swap_label:
		_swap_label.add_theme_color_override("font_color",
			Color(1, 1, 1, 0.45) if available else Color(1, 1, 1, 0.15))
		_swap_label.text = "PPM = Wymień (1/rękę)" if available else "Wymiana wykorzystana"


func _on_slot_swapped(index: int, _new_group: TileGroup) -> void:
	if index >= 0 and index < _slots.size():
		var slot := _slots[index]
		var tw := create_tween()
		tw.tween_property(slot, "modulate", Color(1, 1, 0.5, 1), 0.1)
		tw.tween_property(slot, "modulate", Color.WHITE, 0.2)


func _on_slot_right_clicked(index: int) -> void:
	if not _swap_available:
		if index >= 0 and index < _slots.size():
			_slots[index].shake()
		return
	SignalBus.hand_slot_swap_requested.emit(index)


func _on_slot_clicked(index: int) -> void:
	SignalBus.hand_slot_clicked.emit(index)


# ── Inner class: single hex slot panel ─────────────────────────────────

class _HandSlot extends Control:
	var group: TileGroup = null
	var slot_index: int = 0
	var is_selected: bool = false

	var bg_color: Color = Color(0.12, 0.12, 0.12, 0.7)
	var bg_color_empty: Color = Color(0.08, 0.08, 0.08, 0.35)
	var selected_border_color: Color = Color(1.0, 0.92, 0.5, 0.9)
	var selected_border_width: float = 3.0

	signal slot_clicked(index: int)
	signal slot_right_clicked(index: int)

	var _hovered: bool = false

	func _ready() -> void:
		mouse_filter = MOUSE_FILTER_STOP
		mouse_entered.connect(_on_mouse_entered)
		mouse_exited.connect(_on_mouse_exited)

	func set_group(g: TileGroup) -> void:
		group = g
		queue_redraw()

	func _on_mouse_entered() -> void:
		_hovered = true
		if group != null:
			var tw := create_tween()
			tw.tween_property(self, "scale", Vector2(1.08, 1.08), 0.1) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	func _on_mouse_exited() -> void:
		_hovered = false
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector2.ONE, 0.1) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	func shake() -> void:
		var tw := create_tween()
		tw.tween_property(self, "position:x", position.x + 6, 0.04)
		tw.tween_property(self, "position:x", position.x - 5, 0.04)
		tw.tween_property(self, "position:x", position.x + 3, 0.04)
		tw.tween_property(self, "position:x", position.x, 0.04)

	func slide_in(delay: float) -> void:
		modulate.a = 0.0
		var orig_y := position.y
		position.y = orig_y + 40
		var tw := create_tween()
		tw.tween_interval(delay)
		tw.set_parallel(true)
		tw.tween_property(self, "modulate:a", 1.0, 0.2)
		tw.tween_property(self, "position:y", orig_y, 0.25) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT and group != null:
				slot_clicked.emit(slot_index)
			elif event.button_index == MOUSE_BUTTON_RIGHT and group != null:
				slot_right_clicked.emit(slot_index)

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)

		# Background
		var bg := bg_color if group != null else bg_color_empty
		draw_rect(rect, bg, true)

		if group != null:
			var rotated := group.get_rotated_edges()
			var hex_radius: float = minf(size.x, size.y) * 0.35
			var center := size * 0.5

			# Draw hex with colored sectors
			_draw_hex_tile(center, hex_radius, rotated)

			# Template name
			var name_pos := Vector2(size.x * 0.5, size.y - 8)
			draw_string(ThemeDB.fallback_font, name_pos, group.template_name,
				HORIZONTAL_ALIGNMENT_CENTER, int(size.x), 11,
				Color(1, 1, 1, 0.4))

		# Selected border
		if is_selected:
			draw_rect(rect, selected_border_color, false, selected_border_width)

	## Draw a hex with 6 colored sectors.
	func _draw_hex_tile(center: Vector2, radius: float, edges: Array[int]) -> void:
		# Pointy-top: vertices at 90° + i*60°
		var verts: Array[Vector2] = []
		for i: int in range(6):
			var angle := PI / 2.0 + float(i) * PI / 3.0
			verts.append(center + Vector2(cos(angle), -sin(angle)) * radius)

		# Draw each sector (triangle from center to edge)
		for i: int in range(6):
			var edge_type: int = edges[i]
			var color: Color = CellData.TERRAIN_COLORS.get(edge_type, Color.WHITE)
			var points: PackedVector2Array = [center, verts[i], verts[(i + 1) % 6]]
			var colors: PackedColorArray = [color, color, color]
			draw_polygon(points, colors)

		# Hex outline
		for i: int in range(6):
			draw_line(verts[i], verts[(i + 1) % 6], Color(1, 1, 1, 0.2), 1.0)

		# Sector divider lines (from center to vertices)
		for i: int in range(6):
			var edge_a: int = edges[i]
			var edge_b: int = edges[(i + 5) % 6]
			if edge_a != edge_b:
				draw_line(center, verts[i], Color(0, 0, 0, 0.15), 1.0)
