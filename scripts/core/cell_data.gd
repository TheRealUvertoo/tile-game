class_name CellData
extends RefCounted

## Tile data: single terrain type per grid cell.

enum TerrainType { FOREST, CLEARING, ROCKS, WATER, DESERT, SWAMP, MOUNTAIN, MEADOW, TUNDRA, VILLAGE, RIVER }

## Number of standard terrains available in the deck (excludes WATER which is mystery-only)
const DECK_TERRAIN_COUNT := 10  ## All except WATER

var terrain: int = TerrainType.CLEARING
var quest: QuestData = null  ## Optional attached quest
var river_from: int = -1  ## River connection dir (-1=none, 0=E, 1=N, 2=W, 3=S)
var river_to: int = -1    ## River connection dir (-1=none, 0=E, 1=N, 2=W, 3=S)


## Rotate a cardinal direction index CW by N steps.
## CW rotation: E→S, N→E, W→N, S→W → formula: (dir + 3) % 4
static func rotate_dir(dir: int, steps: int) -> int:
	if dir < 0:
		return dir
	return (dir + 3 * steps) % 4

## 4 cardinal neighbor offsets (square grid): E, N, W, S
const DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0),    # 0 = E
	Vector2i(0, -1),   # 1 = N
	Vector2i(-1, 0),   # 2 = W
	Vector2i(0, 1),    # 3 = S
]

const TERRAIN_NAMES: Array[String] = [
	"Las", "Polana", "Skały", "Woda",
	"Pustynia", "Bagno", "Góry", "Łąka", "Tundra", "Wioska", "Rzeka",
]

const TERRAIN_COLORS: Dictionary = {
	TerrainType.FOREST: Color(0.18, 0.32, 0.13),
	TerrainType.CLEARING: Color(0.42, 0.62, 0.28),
	TerrainType.ROCKS: Color(0.44, 0.40, 0.36),
	TerrainType.WATER: Color(0.15, 0.35, 0.65),
	TerrainType.DESERT: Color(0.72, 0.58, 0.32),
	TerrainType.SWAMP: Color(0.28, 0.38, 0.22),
	TerrainType.MOUNTAIN: Color(0.38, 0.42, 0.52),
	TerrainType.MEADOW: Color(0.65, 0.62, 0.30),
	TerrainType.TUNDRA: Color(0.55, 0.68, 0.75),
	TerrainType.VILLAGE: Color(0.58, 0.38, 0.25),
	TerrainType.RIVER: Color(0.22, 0.45, 0.72),
}


## Cross-terrain interaction bonuses.
## Key = sorted pair "min_max", value = { name, points }
const TERRAIN_INTERACTIONS: Dictionary = {
	"0_1": { name = "Symbioza", points = 5 },        # Las + Polana
	"0_6": { name = "Granica Lasu", points = 4 },    # Las + Góry
	"1_9": { name = "Zagroda", points = 6 },         # Polana + Wioska
	"2_6": { name = "Kamieniołom", points = 5 },     # Skały + Góry
	"6_8": { name = "Szczyt", points = 6 },          # Góry + Tundra
	"7_9": { name = "Przysiółek", points = 5 },      # Łąka + Wioska
	"1_10": { name = "Bród", points = 5 },           # Polana + Rzeka
	"9_10": { name = "Most", points = 7 },           # Wioska + Rzeka
}


## Get interaction between two terrain types (or null if same terrain).
static func get_interaction(terrain_a: int, terrain_b: int) -> Variant:
	if terrain_a == terrain_b:
		return null
	var key := "%d_%d" % [mini(terrain_a, terrain_b), maxi(terrain_a, terrain_b)]
	return TERRAIN_INTERACTIONS.get(key)


## Factory: create a tile with a given terrain type.
static func make(p_terrain: int) -> CellData:
	var t := CellData.new()
	t.terrain = p_terrain
	return t
