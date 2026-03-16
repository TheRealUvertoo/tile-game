class_name TileScoring
extends RefCounted

## Adjacency-based scorer for square grid tiles.
## +10 per adjacent neighbor with same terrain, +30 bonus if all 4 neighbors match.
## Cross-terrain interactions give smaller bonuses (defined in CellData).
## Merged tiles (2x2) count as 1 neighbor regardless of how many cells touch.

const POINTS_PER_MATCH := 10
const PERFECT_BONUS := 30
const PERFECT_GROUP_REWARD := 1  ## Bonus groups for perfect cell
const RIVER_MATCH_BONUS := 5     ## Extra points per river-river connection (on top of normal)
const RIVER_ISOLATION_PENALTY := -5  ## Penalty if river has no river neighbors


class ScoringResult:
	var matches: int = 0
	var possible: int = 0  ## Number of occupied neighbors
	var points: int = 0
	var is_perfect: bool = false
	var bonus_groups: int = 0
	var interactions: Array[Dictionary] = []  ## [{ name, points, cell }]


## Score a single cell placement based on same-terrain adjacency + cross-terrain interactions.
static func score_cell(cell: Vector2i, tile: CellData, grid: TileGrid) -> ScoringResult:
	var result := ScoringResult.new()
	var seen_anchors: Dictionary = {}

	for dir in range(4):
		var neighbor_pos := cell + CellData.DIRECTIONS[dir]
		if not grid.placed_tiles.has(neighbor_pos):
			continue

		# Deduplicate merged tile neighbors
		if grid.merged_tiles.has(neighbor_pos):
			var anchor: Vector2i = grid.merged_tiles[neighbor_pos]
			if seen_anchors.has(anchor):
				continue
			seen_anchors[anchor] = true

		result.possible += 1

		var neighbor_tile: CellData = grid.placed_tiles[neighbor_pos]
		if tile.terrain == neighbor_tile.terrain:
			result.matches += 1
		else:
			# Cross-terrain interaction bonus
			var interaction: Variant = CellData.get_interaction(tile.terrain, neighbor_tile.terrain)
			if interaction != null:
				var info: Dictionary = interaction
				result.points += info.points
				result.interactions.append({
					name = info.name,
					points = info.points,
					cell = neighbor_pos,
				})

	result.points += result.matches * POINTS_PER_MATCH

	# River bonus: extra points only for properly connected river neighbors
	if tile.terrain == CellData.TerrainType.RIVER:
		var connected_rivers := 0
		for dir: int in range(4):
			var npos := cell + CellData.DIRECTIONS[dir]
			if not grid.placed_tiles.has(npos):
				continue
			var ntile: CellData = grid.placed_tiles[npos]
			if ntile.terrain != CellData.TerrainType.RIVER:
				continue
			# Check if connections align: this tile has a connection facing dir,
			# and neighbor has a connection facing back (opposite dir)
			var opposite := (dir + 2) % 4
			var this_connects := (tile.river_from == dir or tile.river_to == dir)
			var neighbor_connects := (ntile.river_from == opposite or ntile.river_to == opposite)
			if this_connects and neighbor_connects:
				connected_rivers += 1
		if connected_rivers > 0:
			result.points += connected_rivers * RIVER_MATCH_BONUS
		elif result.possible > 0:
			result.points += RIVER_ISOLATION_PENALTY

	# Perfect = fully surrounded AND all neighbors are same terrain
	if result.matches == result.possible and result.possible == 4:
		result.is_perfect = true
		result.points += PERFECT_BONUS
		result.bonus_groups = PERFECT_GROUP_REWARD

	return result


## Score an entire group placement. Sums scores for each cell in group.
static func score_group(cells: Array[Vector2i], tiles: Array[CellData], grid: TileGrid) -> ScoringResult:
	var total := ScoringResult.new()

	for i in range(cells.size()):
		var cell_result := score_cell(cells[i], tiles[i], grid)
		total.matches += cell_result.matches
		total.possible += cell_result.possible
		total.points += cell_result.points
		total.bonus_groups += cell_result.bonus_groups
		total.interactions.append_array(cell_result.interactions)
		if cell_result.is_perfect:
			total.is_perfect = true

	return total
