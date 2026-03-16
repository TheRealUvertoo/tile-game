extends Node

## Central signal hub. Modules emit/connect here instead of
## directly referencing each other.
## Signals are emitted from external scripts, hence the warning suppression.

# Camera
@warning_ignore("unused_signal")
signal camera_rotated(yaw_degrees: float)

# --- Game Signals ---

# Tile group lifecycle
@warning_ignore("unused_signal")
signal group_selected(group: TileGroup)
@warning_ignore("unused_signal")
signal group_placed(cells: Array[Vector2i], tiles: Array[CellData])

# Scoring
@warning_ignore("unused_signal")
signal score_earned(total: int, delta: int, result: TileScoring.ScoringResult)

# Deck & game state
@warning_ignore("unused_signal")
signal stack_changed(remaining: int)
@warning_ignore("unused_signal")
signal game_ended(final_score: int)

# Ruins discovery
@warning_ignore("unused_signal")
signal ruin_spawned(cell: Vector2i)
@warning_ignore("unused_signal")
signal ruin_discovered(cell: Vector2i, artifact_name: String, bonus_points: int, bonus_groups: int)

# --- Hand System ---
@warning_ignore("unused_signal")
signal hand_changed(hand: Array[TileGroup])
@warning_ignore("unused_signal")
signal hand_slot_selected(index: int)
@warning_ignore("unused_signal")
signal hand_slot_used(index: int)
@warning_ignore("unused_signal")
signal hand_slot_clicked(index: int)
@warning_ignore("unused_signal")
signal hand_slot_swap_requested(index: int)
@warning_ignore("unused_signal")
signal hand_slot_swapped(index: int, new_group: TileGroup)
@warning_ignore("unused_signal")
signal swap_available_changed(available: bool)
