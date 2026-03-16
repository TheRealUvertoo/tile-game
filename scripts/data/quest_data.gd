class_name QuestData
extends Resource

## Quest definition attached to tiles.
## "Build a [terrain] group of [target_group_size]+"

@export var quest_id: StringName = &""
@export var terrain_type: CellData.TerrainType = CellData.TerrainType.FOREST
@export var target_group_size: int = 10
@export var tile_reward: int = 5
@export var score_reward: int = 50

var display_text: String:
	get:
		return "%s — grupa %d+" % [
			CellData.TERRAIN_NAMES[terrain_type],
			target_group_size
		]
