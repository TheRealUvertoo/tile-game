class_name QuestManager
extends Node

## Dorfromantik-style quest manager.
## Always keeps N active quests. Quests come from placed groups (~20%)
## and are auto-generated to fill slots when too few are active.
## Quests anchor to the tile being placed (not overlapping existing tiles).

const MAX_ACTIVE_QUESTS := 2  ## Keep it calm — max 2 quests at once
const AUTO_QUEST_DELAY := 5.0  ## Longer delay before auto-generating quests

var _active_quests: Array[Dictionary] = []  ## Each: { cell: Vector2i, quest: QuestData }
var _pending_quests: Array[QuestData] = []  ## Auto-quests waiting for a matching tile placement
var _quest_cells: Dictionary = {}  ## Vector2i → true — cells with quest indicators (no overlap)
var _completed_count: int = 0
var _grid: TileGrid
var _rng := RandomNumberGenerator.new()


func set_grid(grid: TileGrid) -> void:
	_grid = grid


func _ready() -> void:
	_rng.randomize()
	SignalBus.group_placed.connect(_on_group_placed)


func _on_group_placed(cells: Array, tiles: Array) -> void:
	if _grid == null:
		return

	# Register new quests from placed tiles (deck-attached quests)
	for i in range(cells.size()):
		var tile: CellData = tiles[i]
		if tile.quest != null and _active_quests.size() < MAX_ACTIVE_QUESTS:
			var already_registered := false
			for entry: Dictionary in _active_quests:
				if entry.quest == tile.quest:
					already_registered = true
					break
			if not already_registered:
				var cell: Vector2i = cells[i]
				_active_quests.append({ cell = cell, quest = tile.quest })
				_quest_cells[cell] = true
				SignalBus.quest_started.emit(tile.quest)

	# Try to anchor pending quests to newly placed tiles
	var still_pending: Array[QuestData] = []
	for quest: QuestData in _pending_quests:
		var anchored := false
		for i in range(cells.size()):
			var tile: CellData = tiles[i]
			var cell: Vector2i = cells[i]
			if tile.terrain == quest.terrain_type and not _quest_cells.has(cell):
				_active_quests.append({ cell = cell, quest = quest })
				_quest_cells[cell] = true
				SignalBus.quest_started.emit(quest)
				anchored = true
				break
		if not anchored:
			still_pending.append(quest)
	_pending_quests = still_pending

	# Check all active quests
	var completed: Array = []
	for entry: Dictionary in _active_quests:
		var quest: QuestData = entry.quest
		var group_size := GroupTracker.get_group_size(
			quest.terrain_type, entry.cell, _grid
		)
		SignalBus.quest_progressed.emit(quest, group_size)
		if group_size >= quest.target_group_size:
			completed.append(entry)

	for entry: Dictionary in completed:
		_active_quests.erase(entry)
		_quest_cells.erase(entry.cell)
		_completed_count += 1
		SignalBus.quest_completed.emit(entry.quest)

	# Auto-fill quest slots after a delay
	var total_quests := _active_quests.size() + _pending_quests.size()
	if total_quests < MAX_ACTIVE_QUESTS:
		get_tree().create_timer(AUTO_QUEST_DELAY).timeout.connect(_try_auto_quest)


func _try_auto_quest() -> void:
	var total_quests := _active_quests.size() + _pending_quests.size()
	if total_quests >= MAX_ACTIVE_QUESTS:
		return
	if _grid == null or _grid.placed_tiles.is_empty():
		return

	# Pick a random terrain that exists on the map
	var terrain_counts: Dictionary = {}
	for cell: Vector2i in _grid.placed_tiles:
		var tile: CellData = _grid.placed_tiles[cell]
		if not terrain_counts.has(tile.terrain):
			terrain_counts[tile.terrain] = 0
		terrain_counts[tile.terrain] += 1

	if terrain_counts.is_empty():
		return

	# Pick terrain with some tiles already placed (interesting target)
	var terrains: Array = terrain_counts.keys()
	var terrain: int = terrains[_rng.randi_range(0, terrains.size() - 1)]
	# Target = current largest group + 3-8 more (achievable but challenging)
	var largest_group := _find_largest_group(terrain)
	var target := largest_group + _rng.randi_range(3, 8)
	target = maxi(target, 5)  # Minimum target of 5

	# Don't create a quest that's already trivially complete
	if largest_group >= target:
		target = largest_group + _rng.randi_range(3, 6)

	# Don't duplicate existing quest terrains if possible
	var active_terrains: Dictionary = {}
	for entry: Dictionary in _active_quests:
		var q: QuestData = entry.quest
		active_terrains[q.terrain_type] = true
	for q: QuestData in _pending_quests:
		active_terrains[q.terrain_type] = true
	if active_terrains.has(terrain) and terrains.size() > 1:
		# Try a different terrain
		for t: int in terrains:
			if not active_terrains.has(t):
				terrain = t
				largest_group = _find_largest_group(terrain)
				target = largest_group + _rng.randi_range(3, 8)
				target = maxi(target, 5)
				break

	var quest := QuestData.new()
	quest.quest_id = StringName("auto_%s_%d" % [CellData.TERRAIN_NAMES[terrain].to_lower(), target])
	quest.terrain_type = terrain as CellData.TerrainType
	quest.target_group_size = target
	quest.tile_reward = ceili(float(target) / 4.0)
	quest.score_reward = target * 8

	# Anchor to an existing cell of this terrain (Dorfromantik-style: always visible)
	var anchor_cell := _find_anchor_cell(terrain)
	if anchor_cell != Vector2i(-99999, -99999):
		_active_quests.append({ cell = anchor_cell, quest = quest })
		_quest_cells[anchor_cell] = true
		SignalBus.quest_started.emit(quest)
	else:
		# Fallback: queue as pending if somehow no cell found
		_pending_quests.append(quest)


## Find a cell of the given terrain to anchor a quest on (prefer non-quest cells).
func _find_anchor_cell(terrain: int) -> Vector2i:
	var candidates: Array[Vector2i] = []
	for cell: Vector2i in _grid.placed_tiles:
		var tile: CellData = _grid.placed_tiles[cell]
		if tile.terrain == terrain and not _quest_cells.has(cell):
			candidates.append(cell)
	if candidates.is_empty():
		return Vector2i(-99999, -99999)
	# Pick a random candidate from the largest group
	return candidates[_rng.randi_range(0, candidates.size() - 1)]


func _find_largest_group(terrain: int) -> int:
	var visited: Dictionary = {}
	var largest := 0
	for cell: Vector2i in _grid.placed_tiles:
		if visited.has(cell):
			continue
		var tile: CellData = _grid.placed_tiles[cell]
		if tile.terrain != terrain:
			continue
		var cells := GroupTracker.get_group_cells(terrain, cell, _grid)
		for c: Vector2i in cells:
			visited[c] = true
		largest = maxi(largest, cells.size())
	return largest


func get_active_quests() -> Array[Dictionary]:
	return _active_quests


func get_completed_count() -> int:
	return _completed_count
