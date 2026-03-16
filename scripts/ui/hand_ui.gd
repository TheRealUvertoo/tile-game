class_name HandUI
extends Control

## Bottom-center hand bar — shows HAND_SIZE clickable tile group slots.
## Each slot draws the group shape as colored squares matching terrain colors.

const HAND_SIZE := HandManager.HAND_SIZE

@export_group("Layout")
@export var slot_size := Vector2(140, 140)
@export var slot_gap := 16.0
@export var bottom_margin := 36.0

@export_group("Slot Visuals")
@export var cell_px := 38.0               ## Size of one tile square in the slot
@export var cell_gap := 3.0               ## Gap between tile squares
@export var bg_color := Color(0.12, 0.12, 0.12, 0.75)
@export var bg_color_empty := Color(0.08, 0.08, 0.08, 0.4)
@export var selected_border_color := Color(1.0, 0.92, 0.5, 0.9)
@export var selected_border_width := 4.0
@export var corner_radius := 10.0

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

	# Anchor to bottom-center
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
		slot.cell_px = cell_px
		slot.cell_gap = cell_gap
		slot.bg_color = bg_color
		slot.bg_color_empty = bg_color_empty
		slot.selected_border_color = selected_border_color
		slot.selected_border_width = selected_border_width
		slot.corner_radius = corner_radius
		slot.slot_clicked.connect(_on_slot_clicked)
		slot.slot_right_clicked.connect(_on_slot_right_clicked)
		_container.add_child(slot)
		_slots.append(slot)

	# Swap hint label above hand
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
	# Slide-in animation when full hand is drawn
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
		# Shrink-out animation before clearing
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
		# Brief flash animation on swapped slot
		var slot := _slots[index]
		var tw := create_tween()
		tw.tween_property(slot, "modulate", Color(1, 1, 0.5, 1), 0.1)
		tw.tween_property(slot, "modulate", Color.WHITE, 0.2)


func _on_slot_right_clicked(index: int) -> void:
	if not _swap_available:
		# Shake the slot to indicate swap is used up
		if index >= 0 and index < _slots.size():
			_slots[index].shake()
		return
	SignalBus.hand_slot_swap_requested.emit(index)


func _on_slot_clicked(index: int) -> void:
	SignalBus.hand_slot_clicked.emit(index)


# ── Inner class: single slot panel ─────────────────────────────────────

class _HandSlot extends Control:
	var group: TileGroup = null
	var slot_index: int = 0
	var is_selected: bool = false

	var cell_px: float = 28.0
	var cell_gap: float = 2.0
	var bg_color: Color = Color(0.12, 0.12, 0.12, 0.7)
	var bg_color_empty: Color = Color(0.08, 0.08, 0.08, 0.35)
	var selected_border_color: Color = Color(1.0, 0.92, 0.5, 0.9)
	var selected_border_width: float = 3.0
	var corner_radius: float = 6.0

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

		# Draw group shape
		if group != null:
			var offsets := group.get_rotated_offsets()
			# Find bounding box to center the shape
			var min_off := Vector2(999, 999)
			var max_off := Vector2(-999, -999)
			for off: Vector2i in offsets:
				min_off.x = minf(min_off.x, float(off.x))
				min_off.y = minf(min_off.y, float(off.y))
				max_off.x = maxf(max_off.x, float(off.x))
				max_off.y = maxf(max_off.y, float(off.y))

			var grid_w := (max_off.x - min_off.x + 1) * (cell_px + cell_gap) - cell_gap
			var grid_h := (max_off.y - min_off.y + 1) * (cell_px + cell_gap) - cell_gap
			var origin := Vector2(
				(size.x - grid_w) / 2.0 - min_off.x * (cell_px + cell_gap),
				(size.y - grid_h) / 2.0 - min_off.y * (cell_px + cell_gap),
			)

			for i: int in range(offsets.size()):
				var off := offsets[i]
				var terrain: int = group.terrains[i]
				var color: Color = CellData.TERRAIN_COLORS.get(terrain, Color.WHITE)
				var cell_pos := origin + Vector2(float(off.x), float(off.y)) * (cell_px + cell_gap)
				var cell_rect := Rect2(cell_pos, Vector2(cell_px, cell_px))
				draw_rect(cell_rect, color, true)
				# Subtle border on each cell
				draw_rect(cell_rect, Color(1, 1, 1, 0.15), false, 1.0)

				# River connection indicators (dots on connected edges)
				if terrain == CellData.TerrainType.RIVER and i < group.river_dirs.size():
					var rd: Vector2i = group.river_dirs[i]
					var from_dir := CellData.rotate_dir(rd.x, group.rotation)
					var to_dir := CellData.rotate_dir(rd.y, group.rotation)
					_draw_river_dot(cell_pos, cell_px, from_dir)
					_draw_river_dot(cell_pos, cell_px, to_dir)

			# Quest indicator
			if group.quest != null:
				var star_pos := Vector2(size.x - 24, 8)
				draw_string(ThemeDB.fallback_font, star_pos, "★",
					HORIZONTAL_ALIGNMENT_LEFT, -1, 20,
					Color(1, 0.9, 0.4, 0.9))

		# Selected border
		if is_selected:
			draw_rect(rect, selected_border_color, false, selected_border_width)

	func _draw_river_dot(cell_pos: Vector2, cpx: float, dir: int) -> void:
		if dir < 0:
			return
		var center := cell_pos + Vector2(cpx * 0.5, cpx * 0.5)
		var dot_offset := Vector2.ZERO
		if dir == 0: dot_offset = Vector2(cpx * 0.45, 0)   # E
		elif dir == 1: dot_offset = Vector2(0, -cpx * 0.45) # N
		elif dir == 2: dot_offset = Vector2(-cpx * 0.45, 0) # W
		elif dir == 3: dot_offset = Vector2(0, cpx * 0.45)  # S
		draw_circle(center + dot_offset, 3.0, Color(0.4, 0.7, 1.0, 0.9))
