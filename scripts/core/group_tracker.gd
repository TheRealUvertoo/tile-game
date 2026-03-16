class_name GroupTracker
extends RefCounted

## Tracks contiguous terrain groups via BFS flood-fill.
## A group is connected through adjacent tiles with the same terrain type.


## Returns the number of tiles in the contiguous terrain group
## starting from start_cell, connected through same-terrain adjacency.
static func get_group_size(terrain: int, start_cell: Vector2i, grid: TileGrid) -> int:
	if not grid.placed_tiles.has(start_cell):
		return 0

	var start_tile: CellData = grid.placed_tiles[start_cell]
	if start_tile.terrain != terrain:
		return 0

	var visited := {}
	var queue: Array[Vector2i] = [start_cell]
	visited[start_cell] = true
	var count := 0

	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		var tile: CellData = grid.placed_tiles.get(current)
		if tile == null or tile.terrain != terrain:
			continue

		count += 1

		for dir in range(4):
			var neighbor_cell := current + CellData.DIRECTIONS[dir]
			if visited.has(neighbor_cell):
				continue
			if not grid.placed_tiles.has(neighbor_cell):
				continue
			var neighbor_tile: CellData = grid.placed_tiles[neighbor_cell]
			if neighbor_tile.terrain == terrain:
				visited[neighbor_cell] = true
				queue.append(neighbor_cell)

	return count


## Returns all cells in the contiguous terrain group starting from start_cell.
static func get_group_cells(terrain: int, start_cell: Vector2i, grid: TileGrid) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not grid.placed_tiles.has(start_cell):
		return result

	var start_tile: CellData = grid.placed_tiles[start_cell]
	if start_tile.terrain != terrain:
		return result

	var visited := {}
	var queue: Array[Vector2i] = [start_cell]
	visited[start_cell] = true

	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		var tile: CellData = grid.placed_tiles.get(current)
		if tile == null or tile.terrain != terrain:
			continue

		result.append(current)

		for dir in range(4):
			var neighbor_cell := current + CellData.DIRECTIONS[dir]
			if visited.has(neighbor_cell):
				continue
			if not grid.placed_tiles.has(neighbor_cell):
				continue
			var neighbor_tile: CellData = grid.placed_tiles[neighbor_cell]
			if neighbor_tile.terrain == terrain:
				visited[neighbor_cell] = true
				queue.append(neighbor_cell)

	return result
