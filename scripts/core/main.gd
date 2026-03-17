extends Node3D

## Main game controller — Dorfromantik-style hex tile placement.
## Isengard theme: build orc landscape with wasteland, forest, fortress, mine.

const STARTING_GROUPS := 40

@onready var grid: TileGrid = $TileGrid
@onready var placement: TilePlacement = $TilePlacement
@onready var camera_rig: CameraController = $CameraController
@onready var ui: Control = $UI

var _deck: TileDeck
var _hand_manager: HandManager
var _hand_ui: HandUI
var _score: int = 0
var _turn: int = 1
var _placements_this_turn: int = 0
var _game_over: bool = false
var _next_milestone: int = 100
const MILESTONE_STEP := 100
const MILESTONE_BONUS_GROUPS := 2
var _preview_label: Label3D
var _last_preview_cell: Vector2i = Vector2i(99999, 99999)


func _ready() -> void:
	_deck = TileDeck.new(STARTING_GROUPS)

	# Hand manager
	_hand_manager = HandManager.new()
	_hand_manager.name = "HandManager"
	add_child(_hand_manager)
	_hand_manager.init(_deck)

	# Hand UI
	_hand_ui = HandUI.new()
	_hand_ui.name = "HandUI"
	_hand_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(_hand_ui)

	placement.grid = grid
	placement.camera = camera_rig

	# Connect signals
	SignalBus.group_placed.connect(_on_group_placed)

	# Place starting tile: all wasteland (easy to connect to anything)
	var start_edges: Array[int] = [0, 0, 0, 0, 0, 0]
	var start_tile := CellData.make(start_edges)
	grid.place_starting_tile(start_tile)
	placement.refresh_slot_markers()

	# Score preview label
	_preview_label = Label3D.new()
	_preview_label.font_size = 28
	_preview_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_preview_label.no_depth_test = true
	_preview_label.outline_size = 5
	_preview_label.outline_modulate = Color(0, 0, 0, 0.7)
	_preview_label.visible = false
	add_child(_preview_label)

	_hand_manager.draw_hand()
	SignalBus.stack_changed.emit(_deck.groups_remaining())


func _process(_delta: float) -> void:
	_update_score_preview()


func _on_group_placed(cells: Array[Vector2i], tiles: Array[CellData]) -> void:
	if _game_over:
		return

	if not cells.is_empty():
		var result := TileScoring.score_placement(cells[0], tiles[0], grid)
		_score += result.points
		SignalBus.score_earned.emit(_score, result.points, result)

		if result.points >= 3:
			_spawn_3d_score_text(cells[0], result)

		if result.bonus_groups > 0:
			_deck.add_groups(result.bonus_groups)

	_check_milestone()
	SignalBus.stack_changed.emit(_deck.groups_remaining())

	# Squish animation
	for cell: Vector2i in cells:
		_squish_tile(cell)

	_preview_label.visible = false

	# Track turns (3 placements = 1 turn)
	_placements_this_turn += 1
	if _placements_this_turn >= 3:
		_placements_this_turn = 0
		_turn += 1
		if ui.has_method("update_turn"):
			ui.update_turn(_turn)

	# Game over check
	if _deck.groups_remaining() <= 0 and not _hand_manager.has_remaining():
		_game_over = true
		get_tree().create_timer(0.8).timeout.connect(func() -> void:
			SignalBus.game_ended.emit(_score)
		)


func _check_milestone() -> void:
	while _score >= _next_milestone:
		_deck.add_groups(MILESTONE_BONUS_GROUPS)
		SignalBus.stack_changed.emit(_deck.groups_remaining())
		_next_milestone += MILESTONE_STEP


func _squish_tile(cell: Vector2i) -> void:
	var visual := grid.get_visual(cell)
	if visual == null:
		return
	var tween := create_tween()
	tween.tween_property(visual, "scale", Vector3(1.08, 0.85, 1.08), 0.08) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(visual, "scale", Vector3(0.95, 1.1, 0.95), 0.1) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(visual, "scale", Vector3.ONE, 0.12) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)


func _spawn_3d_score_text(cell: Vector2i, result: TileScoring.ScoringResult) -> void:
	var label := Label3D.new()
	label.text = "+%d" % result.points
	if not result.synergies.is_empty():
		label.text += " " + " | ".join(result.synergies)
	if result.is_perfect:
		label.modulate = Color(1, 0.9, 0.3, 0.8)
	elif not result.synergies.is_empty():
		label.modulate = Color(0.5, 1.0, 0.7, 0.8)
	else:
		label.modulate = Color(1, 1, 0.85, 0.8)
	label.font_size = 24
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.outline_size = 4
	label.outline_modulate = Color(0, 0, 0, 0.5)

	add_child(label)
	var world_pos := grid.grid_to_world(cell)
	label.position = world_pos + Vector3(0, 0.3, 0)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", world_pos.y + 0.8, 1.0) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(label, "modulate:a", 0.0, 1.0) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.chain().tween_callback(label.queue_free)


func _update_score_preview() -> void:
	if _game_over or placement.current_group == null:
		_preview_label.visible = false
		_last_preview_cell = Vector2i(99999, 99999)
		return

	var cell := placement.hovered_cell
	if cell == _last_preview_cell:
		return
	_last_preview_cell = cell

	var rotated_edges := placement.current_group.get_rotated_edges()
	if not grid.is_valid_tile_placement(cell, rotated_edges):
		_preview_label.visible = false
		return

	var preview_tile := CellData.make(rotated_edges)
	var result := TileScoring.score_placement(cell, preview_tile, grid)

	if result.points <= 0:
		_preview_label.visible = false
		return

	_preview_label.visible = true
	_preview_label.text = "+%d" % result.points
	if not result.synergies.is_empty():
		_preview_label.text += " " + " | ".join(result.synergies)
	if result.is_perfect:
		_preview_label.modulate = Color(1, 0.9, 0.3, 0.7)
	elif not result.synergies.is_empty():
		_preview_label.modulate = Color(0.5, 1.0, 0.7, 0.7)
	else:
		_preview_label.modulate = Color(1, 1, 0.8, 0.7)

	var world_pos := grid.grid_to_world(cell)
	_preview_label.position = world_pos + Vector3(0, 0.6, 0)
