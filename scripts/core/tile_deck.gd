class_name TileDeck
extends RefCounted

## Random tile group generator with finite stack.
## Draws groups of 2-3 tiles with random shapes and terrains.
## ~20% of groups carry a quest.

const DEFAULT_STARTING_GROUPS := 30
const QUEST_CHANCE := 0.1  ## ~10% of groups carry a quest

var _remaining: int = DEFAULT_STARTING_GROUPS
var _rng := RandomNumberGenerator.new()
var _quest_templates: Array[QuestData] = []

const SHAPE_POOL: Array[int] = [
	TileGroup.Shape.SINGLE,
	TileGroup.Shape.SINGLE,
	TileGroup.Shape.SINGLE,
	TileGroup.Shape.SINGLE,
	TileGroup.Shape.DUO_LINE,
	TileGroup.Shape.DUO_LINE,
	TileGroup.Shape.DUO_LINE,
	TileGroup.Shape.TRIO_LINE,
	TileGroup.Shape.TRIO_ANGLE,
]


func _init(starting_groups: int = DEFAULT_STARTING_GROUPS) -> void:
	_remaining = starting_groups
	_rng.randomize()
	_build_quest_templates()


func draw() -> TileGroup:
	if _remaining <= 0:
		return null
	_remaining -= 1
	return _generate_random_group()


func add_groups(count: int) -> void:
	_remaining += count


func groups_remaining() -> int:
	return _remaining


func _generate_random_group() -> TileGroup:
	var group := TileGroup.new()

	# Random shape
	group.shape = SHAPE_POOL[_rng.randi_range(0, SHAPE_POOL.size() - 1)]

	# Random terrain per member (excludes WATER=3, which is mystery-only)
	var offsets: Array = TileGroup.SHAPE_OFFSETS[group.shape]
	var terrains: Array[int] = []
	var river_dirs: Array[Vector2i] = []
	for i in range(offsets.size()):
		var t := _rng.randi_range(0, CellData.DECK_TERRAIN_COUNT - 1)
		if t >= CellData.TerrainType.WATER:
			t += 1  # Skip WATER (index 3)
		terrains.append(t)
		# River tiles get connection directions (straight or bend)
		if t == CellData.TerrainType.RIVER:
			if _rng.randf() < 0.5:
				river_dirs.append(Vector2i(1, 3))  # N-S straight
			else:
				var bends: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 3), Vector2i(1, 2), Vector2i(2, 3)]
				river_dirs.append(bends[_rng.randi_range(0, bends.size() - 1)])
		else:
			river_dirs.append(Vector2i(-1, -1))
	group.terrains = terrains
	group.river_dirs = river_dirs

	# Random initial rotation
	group.rotation = _rng.randi_range(0, 3)

	# Maybe attach a quest
	if not _quest_templates.is_empty() and _rng.randf() < QUEST_CHANCE:
		group.quest = _quest_templates[_rng.randi_range(0, _quest_templates.size() - 1)]

	return group


func _build_quest_templates() -> void:
	var q1 := QuestData.new()
	q1.quest_id = &"forest_10"
	q1.terrain_type = CellData.TerrainType.FOREST
	q1.target_group_size = 10
	q1.tile_reward = 3
	q1.score_reward = 50
	_quest_templates.append(q1)

	var q2 := QuestData.new()
	q2.quest_id = &"forest_20"
	q2.terrain_type = CellData.TerrainType.FOREST
	q2.target_group_size = 20
	q2.tile_reward = 5
	q2.score_reward = 100
	_quest_templates.append(q2)

	var q3 := QuestData.new()
	q3.quest_id = &"clearing_8"
	q3.terrain_type = CellData.TerrainType.CLEARING
	q3.target_group_size = 8
	q3.tile_reward = 2
	q3.score_reward = 40
	_quest_templates.append(q3)

	var q4 := QuestData.new()
	q4.quest_id = &"rocks_6"
	q4.terrain_type = CellData.TerrainType.ROCKS
	q4.target_group_size = 6
	q4.tile_reward = 3
	q4.score_reward = 60
	_quest_templates.append(q4)

	var q5 := QuestData.new()
	q5.quest_id = &"clearing_15"
	q5.terrain_type = CellData.TerrainType.CLEARING
	q5.target_group_size = 15
	q5.tile_reward = 4
	q5.score_reward = 80
	_quest_templates.append(q5)

	var q6 := QuestData.new()
	q6.quest_id = &"desert_8"
	q6.terrain_type = CellData.TerrainType.DESERT
	q6.target_group_size = 8
	q6.tile_reward = 3
	q6.score_reward = 50
	_quest_templates.append(q6)

	var q7 := QuestData.new()
	q7.quest_id = &"mountain_6"
	q7.terrain_type = CellData.TerrainType.MOUNTAIN
	q7.target_group_size = 6
	q7.tile_reward = 3
	q7.score_reward = 60
	_quest_templates.append(q7)

	var q8 := QuestData.new()
	q8.quest_id = &"village_5"
	q8.terrain_type = CellData.TerrainType.VILLAGE
	q8.target_group_size = 5
	q8.tile_reward = 2
	q8.score_reward = 45
	_quest_templates.append(q8)

	var q9 := QuestData.new()
	q9.quest_id = &"river_6"
	q9.terrain_type = CellData.TerrainType.RIVER
	q9.target_group_size = 6
	q9.tile_reward = 3
	q9.score_reward = 60
	_quest_templates.append(q9)

	var q10 := QuestData.new()
	q10.quest_id = &"swamp_7"
	q10.terrain_type = CellData.TerrainType.SWAMP
	q10.target_group_size = 7
	q10.tile_reward = 3
	q10.score_reward = 50
	_quest_templates.append(q10)

	var q11 := QuestData.new()
	q11.quest_id = &"meadow_8"
	q11.terrain_type = CellData.TerrainType.MEADOW
	q11.target_group_size = 8
	q11.tile_reward = 3
	q11.score_reward = 55
	_quest_templates.append(q11)

	var q12 := QuestData.new()
	q12.quest_id = &"tundra_6"
	q12.terrain_type = CellData.TerrainType.TUNDRA
	q12.target_group_size = 6
	q12.tile_reward = 3
	q12.score_reward = 55
	_quest_templates.append(q12)
