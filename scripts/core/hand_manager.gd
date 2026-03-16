class_name HandManager
extends Node

## Manages a hand of HAND_SIZE tile groups. Player picks one at a time.
## When all slots are used, a new hand is drawn from the deck.

const HAND_SIZE := 3

var _deck: TileDeck
var _hand: Array[TileGroup] = []  # TileGroup or null (used slot)
var _selected_index: int = -1
var _swap_used: bool = false  ## One swap allowed per hand


func init(deck: TileDeck) -> void:
	_deck = deck
	SignalBus.hand_slot_clicked.connect(_on_slot_clicked)
	SignalBus.hand_slot_swap_requested.connect(_on_slot_swap_requested)
	SignalBus.group_placed.connect(_on_group_placed)


## Draw a fresh hand of HAND_SIZE groups from the deck.
func draw_hand() -> void:
	_hand.clear()
	_selected_index = -1
	_swap_used = false
	SignalBus.swap_available_changed.emit(true)
	for i: int in range(HAND_SIZE):
		var group := _deck.draw()
		_hand.append(group)  # null if deck is empty
	SignalBus.hand_changed.emit(_hand.duplicate())


## Select a slot by index — activates the group for placement.
func select(index: int) -> void:
	if index < 0 or index >= _hand.size():
		return
	if _hand[index] == null:
		return
	_selected_index = index
	SignalBus.hand_slot_selected.emit(index)
	SignalBus.group_selected.emit(_hand[index])


## Returns the current hand (may contain nulls for used slots).
func get_hand() -> Array[TileGroup]:
	return _hand


## Returns selected slot index (-1 if none).
func selected_index() -> int:
	return _selected_index


## True if any non-null slot remains in hand.
func has_remaining() -> bool:
	for entry in _hand:
		if entry != null:
			return true
	return false


## Swap a slot: discard current group, draw a new one. Costs 1 from deck.
func swap_slot(index: int) -> void:
	if _swap_used:
		return
	if index < 0 or index >= _hand.size():
		return
	if _hand[index] == null:
		return
	if _deck.groups_remaining() <= 0:
		return
	# Discard old group and draw replacement (costs 1 extra from deck)
	var new_group := _deck.draw()
	_hand[index] = new_group
	_swap_used = true
	_selected_index = -1
	SignalBus.swap_available_changed.emit(false)
	SignalBus.hand_slot_swapped.emit(index, new_group)
	SignalBus.hand_changed.emit(_hand.duplicate())
	SignalBus.stack_changed.emit(_deck.groups_remaining())


## True if swap is still available this hand.
func can_swap() -> bool:
	return not _swap_used and _deck.groups_remaining() > 0


func _on_slot_swap_requested(index: int) -> void:
	swap_slot(index)


func _on_slot_clicked(index: int) -> void:
	select(index)


func _on_group_placed(_cells: Array, _tiles: Array) -> void:
	if _selected_index < 0 or _selected_index >= _hand.size():
		return
	_hand[_selected_index] = null
	SignalBus.hand_slot_used.emit(_selected_index)
	_selected_index = -1

	# Check if hand is empty — draw new hand if deck has groups
	if not has_remaining() and _deck.groups_remaining() > 0:
		get_tree().create_timer(0.15).timeout.connect(draw_hand)
