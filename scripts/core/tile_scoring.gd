class_name TileScoring
extends RefCounted

## Sunscar hex scoring — Dorfromantik-style.
## Points for matching edges + group size bonuses.

const BASE_POINTS_PER_MATCH := 5
const FOREST_MATCH_BONUS := 2
const FORTRESS_MATCH_BONUS := 3
const MINE_MATCH_BONUS := 2
const FILL_BONUS := 15          ## 5+ neighbors
const SURROUND_BONUS := 30     ## All 6 matched


class ScoringResult:
	var matches: int = 0
	var possible: int = 0
	var points: int = 0
	var is_perfect: bool = false
	var bonus_groups: int = 0
	var synergies: Array[String] = []


## Score a single hex tile placement.
static func score_placement(cell: Vector2i, tile: CellData, grid: TileGrid) -> ScoringResult:
	var result := ScoringResult.new()

	for dir: int in range(6):
		var npos := cell + CellData.DIRECTIONS[dir]
		if not grid.placed_tiles.has(npos):
			continue

		result.possible += 1
		var ntile: CellData = grid.placed_tiles[npos]
		var my_edge: int = tile.edges[dir]
		var their_edge: int = ntile.edges[CellData.opposite_dir(dir)]

		if my_edge == their_edge:
			result.matches += 1
			result.points += BASE_POINTS_PER_MATCH

			match my_edge:
				CellData.TerrainType.FOREST:
					result.points += FOREST_MATCH_BONUS
				CellData.TerrainType.FORTRESS:
					result.points += FORTRESS_MATCH_BONUS
				CellData.TerrainType.MINE:
					result.points += MINE_MATCH_BONUS

	if result.possible >= 5:
		result.points += FILL_BONUS
		result.synergies.append("Otoczenie")
	if result.possible >= 6 and result.matches >= 6:
		result.points += SURROUND_BONUS
		result.is_perfect = true
		result.bonus_groups = 2
		result.synergies.append("Idealne!")
	elif result.matches >= 4:
		result.bonus_groups = 1

	return result
