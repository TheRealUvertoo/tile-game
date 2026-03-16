class_name TileScoring
extends RefCounted

## Sunscar scoring: edge matching + synergy combos.
## 6 edge types with unique bonuses and cross-type synergies.

# ── Base scoring ──
const BASE_POINTS_PER_MATCH := 3
const FILL_BONUS := 10          ## 3+ neighbors
const SURROUND_BONUS := 20     ## 4 neighbors (filling a hole)

# ── Per-type match bonuses ──
const TRAIL_MATCH_BONUS := 2
const SETTLEMENT_MATCH_BONUS := 3
const RUINS_MATCH_BONUS := 1
const MOUNTAIN_MATCH_BONUS := 2
const OASIS_MATCH_BONUS := 4

# ── Synergy bonuses (cross-type combos) ──
const SETTLEMENT_TRAIL_BONUS := 5       ## "Szlak handlowy" — trade route tile with connected trail
const SETTLEMENT_OASIS_BONUS := 8       ## "Raj kupców" — tile with both settlement + oasis edges
const MOUNTAIN_SETTLEMENT_BONUS := 4    ## "Twierdza" — tile with both mountain + settlement edges
const OASIS_SURROUNDED_BONUS := 15      ## "Rajski ogród" — oasis with 3+ oasis neighbor matches


class ScoringResult:
	var matches: int = 0
	var possible: int = 0
	var points: int = 0
	var is_perfect: bool = false
	var bonus_groups: int = 0
	var synergies: Array[String] = []  ## Names of triggered synergies


## Score a single tile placement.
static func score_placement(cell: Vector2i, tile: CellData, grid: TileGrid) -> ScoringResult:
	var result := ScoringResult.new()
	var oasis_matches := 0

	for dir: int in range(4):
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

			# Per-type match bonus
			match my_edge:
				CellData.EdgeType.TRAIL:
					result.points += TRAIL_MATCH_BONUS
				CellData.EdgeType.SETTLEMENT:
					result.points += SETTLEMENT_MATCH_BONUS
				CellData.EdgeType.RUINS:
					result.points += RUINS_MATCH_BONUS
				CellData.EdgeType.MOUNTAINS:
					result.points += MOUNTAIN_MATCH_BONUS
				CellData.EdgeType.OASIS:
					result.points += OASIS_MATCH_BONUS
					oasis_matches += 1

	# ── Synergy checks ──
	_check_synergies(tile, cell, grid, result, oasis_matches)

	# ── Fill bonuses ──
	if result.possible >= 3:
		result.points += FILL_BONUS
	if result.possible >= 4:
		result.points += SURROUND_BONUS
		result.is_perfect = true
		result.bonus_groups = 1

	return result


## Check cross-type synergies on this tile.
static func _check_synergies(tile: CellData, cell: Vector2i, grid: TileGrid, result: ScoringResult, oasis_matches: int) -> void:
	var has_settlement := false
	var has_trail := false
	var has_mountain := false
	var has_oasis := false

	for dir: int in range(4):
		match tile.edges[dir]:
			CellData.EdgeType.SETTLEMENT: has_settlement = true
			CellData.EdgeType.TRAIL: has_trail = true
			CellData.EdgeType.MOUNTAINS: has_mountain = true
			CellData.EdgeType.OASIS: has_oasis = true

	# Trade route: tile has both settlement + trail, and trail connects
	if has_settlement and has_trail:
		for dir: int in range(4):
			if tile.edges[dir] == CellData.EdgeType.TRAIL:
				var npos := cell + CellData.DIRECTIONS[dir]
				if grid.placed_tiles.has(npos):
					var ntile: CellData = grid.placed_tiles[npos]
					if ntile.edges[CellData.opposite_dir(dir)] == CellData.EdgeType.TRAIL:
						result.points += SETTLEMENT_TRAIL_BONUS
						result.synergies.append("Szlak handlowy")
						break

	# Prosperous city: tile has both settlement + oasis edges
	if has_settlement and has_oasis:
		result.points += SETTLEMENT_OASIS_BONUS
		result.synergies.append("Raj kupców")

	# Fortress: tile has both mountain + settlement edges
	if has_mountain and has_settlement:
		result.points += MOUNTAIN_SETTLEMENT_BONUS
		result.synergies.append("Twierdza")

	# Paradise garden: oasis with 3+ oasis neighbor matches
	if has_oasis and oasis_matches >= 3:
		result.points += OASIS_SURROUNDED_BONUS
		result.synergies.append("Rajski ogród")
		result.bonus_groups += 1
