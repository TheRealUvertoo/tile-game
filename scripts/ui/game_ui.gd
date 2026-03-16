extends Control

## Game UI: score, stack counter, quest cards, combo indicator, turn counter, game over.

var _score_label: Label
var _stack_label: Label
var _turn_label: Label
var _quest_vbox: VBoxContainer
var _quest_header: Label
var _completed_label: Label
var _quest_entries: Dictionary = {}  ## QuestData → { container, label, progress }
var _game_over_panel: PanelContainer
var _completed_count: int = 0
var _last_stack_count: int = -1


func _ready() -> void:
	_build_hud()
	_build_quest_panel()

	SignalBus.score_earned.connect(_on_score_earned)
	SignalBus.stack_changed.connect(_on_stack_changed)
	SignalBus.quest_started.connect(_on_quest_started)
	SignalBus.quest_progressed.connect(_on_quest_progressed)
	SignalBus.quest_completed.connect(_on_quest_completed)
	SignalBus.game_ended.connect(_on_game_ended)
	SignalBus.mystery_tile_discovered.connect(_on_mystery_discovered)


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
	_stack_label.text = "Kafelki: 30"
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

	# Interaction legend (bottom-left) — scrollable for many entries
	var legend_scroll := ScrollContainer.new()
	legend_scroll.anchor_left = 0.0
	legend_scroll.anchor_top = 1.0
	legend_scroll.anchor_bottom = 1.0
	legend_scroll.offset_left = 32
	legend_scroll.offset_top = -360
	legend_scroll.offset_bottom = -32
	legend_scroll.custom_minimum_size.x = 320
	legend_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	legend_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(legend_scroll)

	var legend := VBoxContainer.new()
	legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	legend.add_theme_constant_override("separation", 2)
	legend_scroll.add_child(legend)

	for key: String in CellData.TERRAIN_INTERACTIONS:
		var info: Dictionary = CellData.TERRAIN_INTERACTIONS[key]
		var parts := key.split("_")
		var t1 := int(parts[0])
		var t2 := int(parts[1])
		var hint := Label.new()
		hint.text = "%s + %s = %s (+%d)" % [
			CellData.TERRAIN_NAMES[t1], CellData.TERRAIN_NAMES[t2],
			info.name, info.points
		]
		hint.add_theme_font_size_override("font_size", 13)
		hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.55, 0.55))
		hint.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		hint.add_theme_constant_override("outline_size", 2)
		hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		legend.add_child(hint)


func _build_quest_panel() -> void:
	_quest_vbox = VBoxContainer.new()
	_quest_vbox.anchor_left = 1.0
	_quest_vbox.anchor_right = 1.0
	_quest_vbox.offset_left = -420
	_quest_vbox.offset_right = -32
	_quest_vbox.offset_top = 32
	_quest_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quest_vbox.add_theme_constant_override("separation", 14)
	add_child(_quest_vbox)

	_quest_header = Label.new()
	_quest_header.text = "Zadania"
	_quest_header.add_theme_font_size_override("font_size", 30)
	_quest_header.add_theme_color_override("font_color", Color(1, 0.9, 0.6))
	_quest_header.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_quest_header.add_theme_constant_override("outline_size", 6)
	_quest_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_quest_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quest_vbox.add_child(_quest_header)

	_completed_label = Label.new()
	_completed_label.text = ""
	_completed_label.add_theme_font_size_override("font_size", 18)
	_completed_label.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
	_completed_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_completed_label.add_theme_constant_override("outline_size", 3)
	_completed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_completed_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quest_vbox.add_child(_completed_label)


func update_turn(turn: int) -> void:
	_turn_label.text = "Tura: %d" % turn
	# Subtle pulse on turn change
	var tw := create_tween()
	_turn_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	tw.tween_property(_turn_label, "scale", Vector2(1.1, 1.1), 0.08)
	tw.tween_property(_turn_label, "scale", Vector2.ONE, 0.12)
	tw.tween_callback(func() -> void:
		_turn_label.add_theme_color_override("font_color", Color(0.7, 0.65, 0.5))
	)


# --- Signal handlers ---

func _on_score_earned(total: int, _delta: int, _result) -> void:
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


func _on_quest_started(quest: QuestData) -> void:
	var container := VBoxContainer.new()
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var terrain_color: Color = CellData.TERRAIN_COLORS[quest.terrain_type]

	var name_label := Label.new()
	name_label.text = "★ " + quest.display_text
	name_label.add_theme_font_size_override("font_size", 24)
	name_label.add_theme_color_override("font_color", terrain_color.lightened(0.5))
	name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	name_label.add_theme_constant_override("outline_size", 5)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(name_label)

	var progress_label := Label.new()
	progress_label.text = "(0 / %d)" % quest.target_group_size
	progress_label.add_theme_font_size_override("font_size", 20)
	progress_label.add_theme_color_override("font_color", Color(0.7, 0.65, 0.5))
	progress_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	progress_label.add_theme_constant_override("outline_size", 4)
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	progress_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(progress_label)

	var reward_label := Label.new()
	var reward_text := "+%d kafelki" % quest.tile_reward
	if quest.score_reward > 0:
		reward_text += "  +%d pkt" % quest.score_reward
	reward_label.text = reward_text
	reward_label.add_theme_font_size_override("font_size", 17)
	reward_label.add_theme_color_override("font_color", Color(0.55, 0.5, 0.4))
	reward_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	reward_label.add_theme_constant_override("outline_size", 3)
	reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	reward_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(reward_label)

	_quest_vbox.add_child(container)
	_quest_entries[quest] = { container = container, label = name_label, progress = progress_label }

	# Slide-in animation
	container.modulate.a = 0.0
	container.position.x = 50
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(container, "modulate:a", 1.0, 0.3)
	tween.tween_property(container, "position:x", 0.0, 0.3) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)


func _on_quest_progressed(quest: QuestData, progress: int) -> void:
	if not _quest_entries.has(quest):
		return
	var entry: Dictionary = _quest_entries[quest]
	var progress_label: Label = entry.progress
	progress_label.text = "(%d / %d)" % [progress, quest.target_group_size]

	var ratio := clampf(float(progress) / float(quest.target_group_size), 0.0, 1.0)
	var col := Color(0.7, 0.65, 0.5).lerp(Color(0.4, 1.0, 0.5), ratio)
	progress_label.add_theme_color_override("font_color", col)

	if ratio > 0.0:
		var tween := create_tween()
		tween.tween_property(progress_label, "scale", Vector2(1.1, 1.1), 0.08)
		tween.tween_property(progress_label, "scale", Vector2.ONE, 0.1)


func _on_quest_completed(quest: QuestData) -> void:
	_completed_count += 1

	if _quest_entries.has(quest):
		var entry: Dictionary = _quest_entries[quest]
		var progress_label: Label = entry.progress
		progress_label.text = "Ukończono!"
		progress_label.add_theme_color_override("font_color", Color(0.4, 1, 0.5))

		var name_label: Label = entry.label
		name_label.add_theme_color_override("font_color", Color(0.4, 1, 0.5))

		var container: VBoxContainer = entry.container
		var tween := create_tween()
		tween.tween_interval(1.5)
		tween.set_parallel(true)
		tween.tween_property(container, "modulate:a", 0.0, 0.5)
		tween.tween_property(container, "position:x", 50.0, 0.5)
		tween.chain().tween_callback(func() -> void:
			if is_instance_valid(container):
				container.queue_free()
			_quest_entries.erase(quest)
		)

	_completed_label.text = "Ukończono zadań: %d" % _completed_count


func _on_mystery_discovered(_cell: Vector2i, _terrain: int, _points: int) -> void:
	pass  # Score update is handled by _on_score_earned


func _on_game_ended(final_score: int) -> void:
	if _game_over_panel != null:
		return

	_game_over_panel = PanelContainer.new()
	_game_over_panel.set_anchors_preset(Control.PRESET_CENTER)
	_game_over_panel.custom_minimum_size = Vector2(500, 320)
	_game_over_panel.position -= Vector2(250, 160)

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

	var completed := Label.new()
	completed.text = "Zadania: %d ukończonych" % _completed_count
	completed.add_theme_font_size_override("font_size", 24)
	completed.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
	completed.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(completed)

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
