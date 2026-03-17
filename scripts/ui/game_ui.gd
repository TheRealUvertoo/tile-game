extends Control

## Game UI: score, stack counter, turn counter, terrain legend, game over.

var _score_label: Label
var _stack_label: Label
var _turn_label: Label
var _game_over_panel: PanelContainer
var _last_stack_count: int = -1


func _ready() -> void:
	_build_hud()
	_build_terrain_legend()

	SignalBus.score_earned.connect(_on_score_earned)
	SignalBus.stack_changed.connect(_on_stack_changed)
	SignalBus.game_ended.connect(_on_game_ended)


func _build_hud() -> void:
	var vbox := VBoxContainer.new()
	vbox.position = Vector2(32, 32)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 8)
	add_child(vbox)

	_score_label = Label.new()
	_score_label.text = "Punkty: 0"
	_score_label.add_theme_font_size_override("font_size", 42)
	_score_label.add_theme_color_override("font_color", Color(1, 0.95, 0.8))
	_score_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_score_label.add_theme_constant_override("outline_size", 6)
	_score_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_score_label)

	_stack_label = Label.new()
	_stack_label.text = "Kafelki: 40"
	_stack_label.add_theme_font_size_override("font_size", 28)
	_stack_label.add_theme_color_override("font_color", Color(0.85, 0.8, 0.6))
	_stack_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_stack_label.add_theme_constant_override("outline_size", 5)
	_stack_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_stack_label)

	_turn_label = Label.new()
	_turn_label.text = "Tura: 1"
	_turn_label.add_theme_font_size_override("font_size", 22)
	_turn_label.add_theme_color_override("font_color", Color(0.7, 0.65, 0.5))
	_turn_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_turn_label.add_theme_constant_override("outline_size", 4)
	_turn_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_turn_label)


func _build_terrain_legend() -> void:
	var legend := VBoxContainer.new()
	legend.anchor_left = 0.0
	legend.anchor_top = 1.0
	legend.anchor_bottom = 1.0
	legend.offset_left = 32
	legend.offset_top = -230
	legend.offset_bottom = -32
	legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	legend.add_theme_constant_override("separation", 6)
	add_child(legend)

	var header := Label.new()
	header.text = "Tereny:"
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", Color(0.7, 0.65, 0.5, 0.6))
	header.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	header.add_theme_constant_override("outline_size", 3)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	legend.add_child(header)

	for terrain_type: int in range(4):
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 8)
		legend.add_child(row)

		var swatch := ColorRect.new()
		swatch.custom_minimum_size = Vector2(16, 16)
		swatch.color = CellData.TERRAIN_COLORS[terrain_type]
		swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(swatch)

		var name_label := Label.new()
		name_label.text = CellData.TERRAIN_NAMES[terrain_type]
		name_label.add_theme_font_size_override("font_size", 16)
		name_label.add_theme_color_override("font_color", Color(0.7, 0.65, 0.5, 0.5))
		name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		name_label.add_theme_constant_override("outline_size", 2)
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(name_label)

	# Rotation hint
	var hint := Label.new()
	hint.text = "R = Obróć kafelek"
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.3))
	hint.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	hint.add_theme_constant_override("outline_size", 2)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	legend.add_child(hint)


func update_turn(turn: int) -> void:
	_turn_label.text = "Tura: %d" % turn
	var tw := create_tween()
	_turn_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	tw.tween_property(_turn_label, "scale", Vector2(1.1, 1.1), 0.08)
	tw.tween_property(_turn_label, "scale", Vector2.ONE, 0.12)
	tw.tween_callback(func() -> void:
		_turn_label.add_theme_color_override("font_color", Color(0.7, 0.65, 0.5))
	)


# --- Signal handlers ---

func _on_score_earned(total: int, _delta: int, _result: TileScoring.ScoringResult) -> void:
	_score_label.text = "Punkty: %d" % total


func _on_stack_changed(remaining: int) -> void:
	_last_stack_count = remaining
	_stack_label.text = "Kafelki: %d" % remaining

	if remaining <= 5:
		_stack_label.add_theme_color_override("font_color", Color(1, 0.3, 0.2))
	elif remaining <= 10:
		_stack_label.add_theme_color_override("font_color", Color(1, 0.6, 0.3))
	else:
		_stack_label.add_theme_color_override("font_color", Color(0.85, 0.8, 0.6))


func _on_game_ended(final_score: int) -> void:
	if _game_over_panel != null:
		return

	_game_over_panel = PanelContainer.new()
	_game_over_panel.set_anchors_preset(Control.PRESET_CENTER)
	_game_over_panel.custom_minimum_size = Vector2(500, 280)
	_game_over_panel.position -= Vector2(250, 140)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.08, 0.92)
	style.border_color = Color(1, 0.9, 0.6, 0.6)
	style.set_border_width_all(3)
	style.set_corner_radius_all(16)
	style.set_content_margin_all(32)
	_game_over_panel.add_theme_stylebox_override("panel", style)
	add_child(_game_over_panel)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	_game_over_panel.add_child(vbox)

	var title := Label.new()
	title.text = "Koniec Gry"
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(1, 0.95, 0.8))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var score_lbl := Label.new()
	score_lbl.text = "Wynik: %d" % final_score
	score_lbl.add_theme_font_size_override("font_size", 34)
	score_lbl.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(score_lbl)

	var hint := Label.new()
	hint.text = "Naciśnij F5, aby zagrać ponownie"
	hint.add_theme_font_size_override("font_size", 20)
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.55))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hint)

	# Panel appear animation
	_game_over_panel.modulate.a = 0.0
	_game_over_panel.scale = Vector2(0.8, 0.8)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_game_over_panel, "modulate:a", 1.0, 0.3)
	tween.tween_property(_game_over_panel, "scale", Vector2.ONE, 0.3) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
