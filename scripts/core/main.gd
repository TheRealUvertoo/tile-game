extends Node3D

## Main game controller — hand-based tile placement loop.
## Wires TileGrid + TilePlacement + HandManager + QuestManager +
## MysteryTileManager + TileAgingManager.
## Handles scoring, neighbor visuals, quest indicators, combos, juice.

const STARTING_GROUPS := 30  ## Finite deck — quests extend it

@onready var grid: TileGrid = $TileGrid
@onready var placement: TilePlacement = $TilePlacement
@onready var camera_rig: CameraController = $CameraController
@onready var quest_manager: QuestManager = $QuestManager
@onready var ui: Control = $UI

var _deck: TileDeck
var _hand_manager: HandManager
var _hand_ui: HandUI
var _mystery_manager: MysteryTileManager
var _aging_manager: TileAgingManager
var _score: int = 0
var _turn: int = 1
var _placements_this_turn: int = 0
var _quest_indicators: Dictionary = {}  ## QuestData → Label3D
var _game_over: bool = false
var _next_milestone: int = 100  ## Score threshold for next bonus
const MILESTONE_STEP := 100
const MILESTONE_BONUS_GROUPS := 2
var _preview_label: Label3D  ## Hover score preview
var _last_preview_cell: Vector2i = Vector2i(99999, 99999)
var _quest_info_label: Label3D  ## Quest info popup (shown on star click)
var _quest_edge_markers: Array[Node3D] = []  ## Highlighted edge positions
var _active_quest_info: QuestData = null  ## Currently shown quest info


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

	# Mystery tile manager
	_mystery_manager = MysteryTileManager.new()
	_mystery_manager.name = "MysteryTileManager"
	add_child(_mystery_manager)
	_mystery_manager.set_grid(grid)

	# Tile aging manager
	_aging_manager = TileAgingManager.new()
	_aging_manager.name = "TileAgingManager"
	add_child(_aging_manager)
	_aging_manager.set_grid(grid)

	placement.grid = grid
	placement.camera = camera_rig
	quest_manager.set_grid(grid)

	# Connect signals
	SignalBus.group_placed.connect(_on_group_placed)
	SignalBus.tiles_merged.connect(_on_tiles_merged)
	SignalBus.quest_completed.connect(_on_quest_completed)
	SignalBus.quest_started.connect(_on_quest_started)
	SignalBus.mystery_tile_discovered.connect(_on_mystery_discovered)

	# Place starting tile
	var start_tile := CellData.make(CellData.TerrainType.CLEARING)
	grid.place_starting_tile(start_tile)
	_update_tile_neighbors(Vector2i.ZERO)
	placement.refresh_slot_markers()

	# Score preview label (follows cursor)
	_preview_label = Label3D.new()
	_preview_label.font_size = 28
	_preview_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_preview_label.no_depth_test = true
	_preview_label.outline_size = 5
	_preview_label.outline_modulate = Color(0, 0, 0, 0.7)
	_preview_label.visible = false
	add_child(_preview_label)

	_hand_manager.draw_hand()
	_mystery_manager.spawn_initial(2)

	SignalBus.stack_changed.emit(_deck.groups_remaining())


func _process(_delta: float) -> void:
	_update_score_preview()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_try_click_quest_star(mb.position)


func _try_click_quest_star(mouse_pos: Vector2) -> void:
	# Check if click is near any quest star (screen space)
	var clicked_quest: QuestData = null
	var best_dist := 40.0  # Max pixel distance to count as click

	for quest: QuestData in _quest_indicators:
		var label: Label3D = _quest_indicators[quest]
		var screen_pos := camera_rig.unproject_position(label.global_position)
		var dist := mouse_pos.distance_to(screen_pos)
		if dist < best_dist:
			best_dist = dist
			clicked_quest = quest

	if clicked_quest != null:
		if _active_quest_info == clicked_quest:
			_hide_quest_info()
		else:
			_show_quest_info(clicked_quest)
		get_viewport().set_input_as_handled()
	elif _active_quest_info != null:
		_hide_quest_info()


func _show_quest_info(quest: QuestData) -> void:
	_hide_quest_info()
	_active_quest_info = quest

	# Find quest entry for anchor cell
	var anchor := Vector2i.ZERO
	for entry: Dictionary in quest_manager.get_active_quests():
		if entry.quest == quest:
			anchor = entry.cell
			break

	# Show info label above the star
	_quest_info_label = Label3D.new()
	var terrain_name: String = CellData.TERRAIN_NAMES[quest.terrain_type]
	var group_size := GroupTracker.get_group_size(quest.terrain_type, anchor, grid)
	_quest_info_label.text = "%s — grupa %d+\nPostęp: %d / %d\nNagroda: +%d kafelki, +%d pkt" % [
		terrain_name, quest.target_group_size, group_size, quest.target_group_size,
		quest.tile_reward, quest.score_reward
	]
	_quest_info_label.font_size = 18
	_quest_info_label.modulate = Color(1, 1, 0.9, 0.95)
	_quest_info_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_quest_info_label.no_depth_test = true
	_quest_info_label.outline_size = 5
	_quest_info_label.outline_modulate = Color(0, 0, 0, 0.8)
	_quest_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_quest_info_label)

	var star_pos := grid.grid_to_world(anchor)
	_quest_info_label.position = star_pos + Vector3(0, 0.9, 0)

	# Fade in
	_quest_info_label.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_quest_info_label, "modulate:a", 0.95, 0.15)

	# Find and highlight edge positions where this terrain could be placed to grow the group
	var group_cells := GroupTracker.get_group_cells(quest.terrain_type, anchor, grid)
	var edge_positions: Dictionary = {}  # Valid positions adjacent to this group
	for cell: Vector2i in group_cells:
		for dir in range(4):
			var neighbor := cell + CellData.DIRECTIONS[dir]
			if not grid.placed_tiles.has(neighbor) and grid.valid_positions.has(neighbor):
				edge_positions[neighbor] = true

	# Spawn subtle markers at edge positions
	var terrain_color: Color = CellData.TERRAIN_COLORS[quest.terrain_type]
	for pos: Vector2i in edge_positions:
		var marker := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.6, 0.02, 0.6)
		marker.mesh = box

		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(terrain_color.r, terrain_color.g, terrain_color.b, 0.4)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.no_depth_test = true
		marker.material_override = mat
		add_child(marker)
		marker.position = grid.grid_to_world(pos) + Vector3(0, 0.04, 0)
		_quest_edge_markers.append(marker)

		# Gentle pulse
		var pulse := create_tween()
		pulse.set_loops()
		pulse.tween_property(mat, "albedo_color:a", 0.6, 0.6) \
			.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		pulse.tween_property(mat, "albedo_color:a", 0.2, 0.6) \
			.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		marker.set_meta("pulse_tween", pulse)


func _hide_quest_info() -> void:
	_active_quest_info = null
	if _quest_info_label != null and is_instance_valid(_quest_info_label):
		_quest_info_label.queue_free()
		_quest_info_label = null
	for marker: Node3D in _quest_edge_markers:
		if is_instance_valid(marker):
			if marker.has_meta("pulse_tween"):
				var pt: Tween = marker.get_meta("pulse_tween")
				if pt.is_valid():
					pt.kill()
			marker.queue_free()
	_quest_edge_markers.clear()


func _on_group_placed(cells: Array[Vector2i], tiles: Array[CellData]) -> void:
	if _game_over:
		return

	# Hide quest info popup on placement
	_hide_quest_info()

	# Score the placement
	var result := TileScoring.score_group(cells, tiles, grid)
	_score += result.points
	SignalBus.score_earned.emit(_score, result.points, result)

	# Show quiet floating score (only for non-trivial amounts)
	if result.points >= 5 and not cells.is_empty():
		_spawn_3d_score_text(cells[0], result)

	# Bonus groups for perfect placement
	if result.bonus_groups > 0:
		_deck.add_groups(result.bonus_groups)

	# Milestone bonus: every 100 pts = +2 groups (quiet)
	_check_milestone()

	SignalBus.stack_changed.emit(_deck.groups_remaining())

	# Update neighbor visuals
	for cell: Vector2i in cells:
		_update_tile_neighbors(cell)
		for dir in range(4):
			var neighbor := cell + CellData.DIRECTIONS[dir]
			if grid.placed_tiles.has(neighbor):
				_update_tile_neighbors(neighbor)

	# Squish animation on placed tiles (no dust — keep it calm)
	for cell: Vector2i in cells:
		_squish_tile(cell)

	# Hide score preview immediately
	_preview_label.visible = false

	# Pulse connected neighbors
	_pulse_connected_neighbors(cells, tiles)

	# Track turns
	_placements_this_turn += 1
	if _placements_this_turn >= 3:
		_placements_this_turn = 0
		_turn += 1
		if ui.has_method("update_turn"):
			ui.update_turn(_turn)
		_aging_manager.on_turn_complete()

	# Check game over: deck empty AND hand empty
	if _deck.groups_remaining() <= 0 and not _hand_manager.has_remaining():
		_game_over = true
		get_tree().create_timer(0.8).timeout.connect(func() -> void:
			SignalBus.game_ended.emit(_score)
		)


func _on_tiles_merged(cells: Array[Vector2i], _terrain: int) -> void:
	for cell: Vector2i in cells:
		for dir in range(4):
			var neighbor := cell + CellData.DIRECTIONS[dir]
			if grid.placed_tiles.has(neighbor) and not cells.has(neighbor):
				_update_tile_neighbors(neighbor)

	# Merge shockwave ring
	if not cells.is_empty():
		var center := grid.grid_to_world(cells[0]) + Vector3(0.5, 0.05, 0.5)
		_spawn_merge_ring(center)


func _on_quest_started(quest: QuestData) -> void:
	# Find the anchor cell from quest_manager
	for entry: Dictionary in quest_manager.get_active_quests():
		if entry.quest == quest:
			_spawn_quest_indicator(entry.cell, quest)
			break


func _on_quest_completed(quest: QuestData) -> void:
	_deck.add_groups(quest.tile_reward)
	_score += quest.score_reward
	SignalBus.score_earned.emit(_score, quest.score_reward, null)
	SignalBus.stack_changed.emit(_deck.groups_remaining())

	# Remove quest indicator
	_remove_quest_indicator(quest)


func _on_mystery_discovered(cell: Vector2i, terrain: int, points: int) -> void:
	_score += points
	SignalBus.score_earned.emit(_score, points, null)

	_update_tile_neighbors(cell)
	for dir in range(4):
		var neighbor := cell + CellData.DIRECTIONS[dir]
		if grid.placed_tiles.has(neighbor):
			_update_tile_neighbors(neighbor)

	var cells: Array[Vector2i] = [cell]
	grid._check_merges(cells)

	# Discovery flash ring in terrain's reveal color
	var reveal_color: Color = MysteryTileManager.REVEAL_COLORS[terrain] if terrain < MysteryTileManager.REVEAL_COLORS.size() else Color(0.5, 0.8, 1.0)
	_spawn_discover_ring(grid.grid_to_world(cell), reveal_color)


# ── Milestone Bonus ──────────────────────────────────────────────────

func _check_milestone() -> void:
	while _score >= _next_milestone:
		_deck.add_groups(MILESTONE_BONUS_GROUPS)
		SignalBus.stack_changed.emit(_deck.groups_remaining())
		_next_milestone += MILESTONE_STEP


# ── Quest Indicators ─────────────────────────────────────────────────

func _spawn_quest_indicator(cell: Vector2i, quest: QuestData) -> void:
	var label := Label3D.new()
	var terrain_color: Color = CellData.TERRAIN_COLORS[quest.terrain_type]
	label.text = "★"
	label.font_size = 48
	label.modulate = terrain_color.lightened(0.6)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.outline_size = 6
	label.outline_modulate = Color(0, 0, 0, 0.7)

	add_child(label)
	var world_pos := grid.grid_to_world(cell)
	label.position = world_pos + Vector3(0, 0.5, 0)
	_quest_indicators[quest] = label

	# Appear animation: pop in
	label.scale = Vector3.ZERO
	var tween := create_tween()
	tween.tween_property(label, "scale", Vector3(1.2, 1.2, 1.2), 0.2) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(label, "scale", Vector3.ONE, 0.1)

	# Idle bob
	var bob_tween := create_tween()
	bob_tween.set_loops()
	bob_tween.tween_property(label, "position:y", world_pos.y + 0.6, 0.8) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	bob_tween.tween_property(label, "position:y", world_pos.y + 0.4, 0.8) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	label.set_meta("bob_tween", bob_tween)


func _remove_quest_indicator(quest: QuestData) -> void:
	if not _quest_indicators.has(quest):
		return
	var label: Label3D = _quest_indicators[quest]
	if label.has_meta("bob_tween"):
		var bt: Tween = label.get_meta("bob_tween")
		if bt.is_valid():
			bt.kill()
	var tween := create_tween()
	tween.tween_property(label, "scale", Vector3(1.5, 1.5, 1.5), 0.15)
	tween.tween_property(label, "scale", Vector3.ZERO, 0.2) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tween.tween_callback(label.queue_free)
	_quest_indicators.erase(quest)


# ── Juicy Animations ────────────────────────────────────────────────

## Tile squish on placement — overshoot Y scale then settle
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


## Camera micro-shake (just offset, then return)
func _camera_shake(duration: float, intensity: float) -> void:
	if camera_rig == null:
		return
	var original_pos := camera_rig.position
	var tween := create_tween()
	var steps := 6
	for i in range(steps):
		var offset := Vector3(
			randf_range(-intensity, intensity),
			randf_range(-intensity * 0.5, intensity * 0.5),
			randf_range(-intensity, intensity),
		)
		var step_time := duration / float(steps)
		# Fade intensity over time
		var fade := 1.0 - float(i) / float(steps)
		tween.tween_property(camera_rig, "position", original_pos + offset * fade, step_time)
	tween.tween_property(camera_rig, "position", original_pos, duration * 0.15)


## Expanding ring effect at world position (merge celebration)
func _spawn_merge_ring(world_pos: Vector3) -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.05
	torus.outer_radius = 0.15
	ring.mesh = torus

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1, 1, 0.7, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	ring.material_override = mat
	ring.rotation.x = PI / 2.0

	add_child(ring)
	ring.position = world_pos

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector3(8, 8, 8), 0.6) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.6) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.chain().tween_callback(ring.queue_free)


## Discovery flash ring — colored by revealed terrain
func _spawn_discover_ring(world_pos: Vector3, color: Color = Color(0.5, 0.8, 1.0)) -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.03
	torus.outer_radius = 0.1
	ring.mesh = torus

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(color.r, color.g, color.b, 0.9)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	ring.material_override = mat
	ring.rotation.x = PI / 2.0

	add_child(ring)
	ring.position = world_pos + Vector3(0, 0.05, 0)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector3(6, 6, 6), 0.5) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.5) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.chain().tween_callback(ring.queue_free)


# ── Floating Score & Interaction Labels ──────────────────────────────

func _spawn_3d_score_text(cell: Vector2i, result: TileScoring.ScoringResult) -> void:
	var label := Label3D.new()
	label.text = "+%d" % result.points
	label.modulate = Color(1, 1, 0.85, 0.8)
	label.font_size = 24
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.outline_size = 4
	label.outline_modulate = Color(0, 0, 0, 0.5)

	add_child(label)
	var world_pos := grid.grid_to_world(cell)
	label.position = world_pos + Vector3(0, 0.3, 0)

	# Gentle float up and fade
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", world_pos.y + 0.8, 1.0) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(label, "modulate:a", 0.0, 1.0) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.chain().tween_callback(label.queue_free)


## Show small interaction labels between different terrain neighbors
func _spawn_interaction_labels(result: TileScoring.ScoringResult) -> void:
	var seen: Dictionary = {}  # Avoid duplicate labels
	for interaction: Dictionary in result.interactions:
		var cell: Vector2i = interaction.cell
		var key := "%d_%d" % [cell.x, cell.y]
		if seen.has(key):
			continue
		seen[key] = true

		var label := Label3D.new()
		label.text = "%s +%d" % [interaction.name, interaction.points]
		label.font_size = 22
		label.modulate = Color(0.7, 0.9, 1.0, 0.9)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.outline_size = 4
		label.outline_modulate = Color(0, 0, 0, 0.6)

		add_child(label)
		var world_pos := grid.grid_to_world(cell)
		label.position = world_pos + Vector3(0, 0.25, 0)

		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(label, "position:y", world_pos.y + 0.8, 1.0) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(label, "modulate:a", 0.0, 1.0) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tween.chain().tween_callback(label.queue_free)


# ── Neighbor Visuals ────────────────────────────────────────────────

func _update_tile_neighbors(cell: Vector2i) -> void:
	var visual := grid.get_visual(cell)
	if visual == null:
		return

	var mesh_inst := _find_tile_mesh(visual)
	if mesh_inst == null:
		return

	var mat: ShaderMaterial = null
	if mesh_inst.mesh and mesh_inst.mesh.get_surface_count() > 0:
		var surf_mat := mesh_inst.mesh.surface_get_material(0)
		if surf_mat is ShaderMaterial:
			if not mesh_inst.has_meta("mat_duped"):
				mesh_inst.mesh = mesh_inst.mesh.duplicate()
				mat = (surf_mat as ShaderMaterial).duplicate()
				mesh_inst.mesh.surface_set_material(0, mat)
				mesh_inst.set_meta("mat_duped", true)
			else:
				mat = mesh_inst.mesh.surface_get_material(0) as ShaderMaterial

	if mat == null:
		return

	# Set river direction uniforms
	var this_tile: CellData = grid.placed_tiles.get(cell)
	if this_tile != null and this_tile.terrain == CellData.TerrainType.RIVER:
		mat.set_shader_parameter("river_dir_a", this_tile.river_from)
		mat.set_shader_parameter("river_dir_b", this_tile.river_to)


func _find_tile_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		return node as MeshInstance3D
	for child in node.get_children():
		var result := _find_tile_mesh(child)
		if result != null:
			return result
	return null


# ── Score Preview on Hover ──────────────────────────────────────────

func _update_score_preview() -> void:
	if _game_over or placement.current_group == null:
		_preview_label.visible = false
		_last_preview_cell = Vector2i(99999, 99999)
		return

	var cell := placement.hovered_cell
	if cell == _last_preview_cell:
		return
	_last_preview_cell = cell

	var cells := placement.current_group.get_cell_positions(cell)
	if not grid.is_valid_group_placement(cells):
		_preview_label.visible = false
		return

	# Simulate scoring without placing
	var tiles: Array[CellData] = []
	for i: int in range(cells.size()):
		tiles.append(CellData.make(placement.current_group.terrains[i]))
	var result := TileScoring.score_group(cells, tiles, grid)

	if result.points <= 0:
		_preview_label.visible = false
		return

	_preview_label.visible = true
	_preview_label.text = "+%d" % result.points
	if result.is_perfect:
		_preview_label.text += " IDEALNIE!"
		_preview_label.modulate = Color(1, 0.9, 0.3, 0.7)
	elif not result.interactions.is_empty():
		_preview_label.modulate = Color(0.7, 0.9, 1.0, 0.7)
	else:
		_preview_label.modulate = Color(1, 1, 0.8, 0.7)

	var world_pos := grid.grid_to_world(cells[0])
	_preview_label.position = world_pos + Vector3(0, 0.6, 0)


# ── Neighbor Connection Pulse ───────────────────────────────────────

func _pulse_connected_neighbors(cells: Array[Vector2i], tiles: Array[CellData]) -> void:
	for i: int in range(cells.size()):
		var cell := cells[i]
		var tile := tiles[i]
		for dir in range(4):
			var neighbor_pos := cell + CellData.DIRECTIONS[dir]
			if not grid.placed_tiles.has(neighbor_pos):
				continue
			var neighbor_tile: CellData = grid.placed_tiles[neighbor_pos]
			if tile.terrain == neighbor_tile.terrain:
				var visual := grid.get_visual(neighbor_pos)
				if visual != null and not visual.has_meta("pulsing"):
					visual.set_meta("pulsing", true)
					var tw := create_tween()
					tw.tween_property(visual, "scale", Vector3(1.06, 1.06, 1.06), 0.1) \
						.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
					tw.tween_property(visual, "scale", Vector3.ONE, 0.15) \
						.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
					tw.tween_callback(func() -> void:
						if is_instance_valid(visual):
							visual.remove_meta("pulsing")
					)


# ── Place Dust Ring ─────────────────────────────────────────────────

func _spawn_place_dust(cell: Vector2i) -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.02
	torus.outer_radius = 0.08
	ring.mesh = torus

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.9, 0.85, 0.7, 0.6)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	ring.material_override = mat
	ring.rotation.x = PI / 2.0

	add_child(ring)
	ring.position = grid.grid_to_world(cell) + Vector3(0, 0.02, 0)

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector3(5, 5, 5), 0.35) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.35) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.chain().tween_callback(ring.queue_free)


# ── Stack Bonus Popup ───────────────────────────────────────────────

func _spawn_stack_popup(amount: int, world_pos: Vector3) -> void:
	var label := Label3D.new()
	label.text = "+%d groups!" % amount
	label.font_size = 30
	label.modulate = Color(0.5, 1, 0.6)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.outline_size = 5
	label.outline_modulate = Color(0, 0, 0, 0.7)
	add_child(label)
	label.position = world_pos + Vector3(0.3, 0.5, 0)

	label.scale = Vector3(0.4, 0.4, 0.4)
	var tw := create_tween()
	tw.tween_property(label, "scale", Vector3(1.1, 1.1, 1.1), 0.12) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(label, "scale", Vector3.ONE, 0.08)
	tw.set_parallel(true)
	tw.tween_property(label, "position:y", world_pos.y + 1.3, 1.2) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(label, "modulate:a", 0.0, 1.2) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.chain().tween_callback(label.queue_free)
