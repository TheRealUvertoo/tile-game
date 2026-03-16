class_name TileBase
extends Node3D

## Attach to tile scene root. Handles:
## 1) Per-sprite billboard (FIXED_Y — always faces camera around Y axis)
## 2) Procedural decoration scattering (via DecorationScatterer children)
## 3) Appear animation: tile rises from ground, then decorations pop up one by one

# ── Appear Animation (edit these in Inspector!) ────────────────────────
@export_group("Appear Animation")

@export_subgroup("Tile Rise")
@export var rise_depth: float = 0.3            ## How far below ground the tile starts
@export var rise_duration: float = 0.3         ## How long the rise takes
@export var rise_ease: Tween.EaseType = Tween.EASE_OUT
@export var rise_trans: Tween.TransitionType = Tween.TRANS_CUBIC

@export_subgroup("Decorations")
@export var deco_delay_after_rise: float = 0.05  ## Delay after tile rises before first decoration
@export var deco_stagger: float = 0.12           ## Delay between each decoration
@export var deco_duration: float = 0.35          ## Each decoration's grow duration
@export var deco_ease: Tween.EaseType = Tween.EASE_OUT
@export var deco_trans: Tween.TransitionType = Tween.TRANS_BACK

# ── Internal state ─────────────────────────────────────────────────────
var _deco_sprites: Array[Dictionary] = []  # [{sprite, orig_pos, orig_scale, orig_modulate}, ...]
var _animation_played := false
var _scatter_seed: int = -1  ## Set externally for deterministic scattering


func _ready() -> void:
	# 1. Run procedural scatterers first (so their sprites exist before we collect)
	_run_scatterers()

	# 2. Collect ALL decoration sprites (manual + procedural) for billboard + animation
	_collect_all_decorations()

	# 3. Set billboard + unshaded on all collected sprites
	for data: Dictionary in _deco_sprites:
		var sprite: Sprite3D = data["sprite"]
		sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		sprite.shaded = false

	# 4. Show or hide based on animation state
	if _animation_played:
		_show_decorations()
	else:
		_hide_decorations()


## Run all DecorationScatterer children to generate procedural sprites.
func _run_scatterers() -> void:
	for child in get_children():
		if child is DecorationScatterer:
			(child as DecorationScatterer).scatter(_scatter_seed)


## Collect sprite data from Decoration_manual and all DecorationScatterer nodes.
func _collect_all_decorations() -> void:
	_deco_sprites.clear()

	# Manual decorations (node named "Decoration_manual" or legacy "Decorations")
	for node_name: String in ["Decoration_manual", "Decorations"]:
		var manual := get_node_or_null(node_name)
		if manual and not (manual is DecorationScatterer):
			_collect_sprites_from(manual)

	# Procedural decorations (all DecorationScatterer children)
	for child in get_children():
		if child is DecorationScatterer:
			_collect_sprites_from(child)


## Recursively collect Sprite3D nodes from a parent for animation tracking.
func _collect_sprites_from(parent: Node) -> void:
	for child in parent.get_children():
		if child is Sprite3D:
			var sprite := child as Sprite3D
			_deco_sprites.append({
				"sprite": sprite,
				"orig_pos": sprite.position,
				"orig_scale": sprite.scale,
				"orig_modulate": sprite.modulate,
			})


## Call this after tile is placed to trigger the reveal animation.
## initial_delay: extra wait before this tile starts (for staggered group placement).
func play_appear_animation(initial_delay: float = 0.0) -> void:
	if _animation_played:
		return
	_animation_played = true

	var tween := create_tween()
	tween.set_parallel(false)

	# ── Optional delay for staggered group placement ──
	if initial_delay > 0.0:
		tween.tween_interval(initial_delay)

	# ── Step 1: Tile rises from below ground ──
	var target_y := position.y
	position.y = target_y - rise_depth
	tween.tween_property(self, "position:y", target_y, rise_duration) \
		.set_ease(rise_ease).set_trans(rise_trans)

	# ── Step 2: Each decoration grows up from ground, one by one ──
	if not _deco_sprites.is_empty():
		tween.tween_interval(deco_delay_after_rise)

		for i: int in range(_deco_sprites.size()):
			var data: Dictionary = _deco_sprites[i]
			var sprite: Sprite3D = data["sprite"]
			var orig_pos: Vector3 = data["orig_pos"]
			var orig_scale: Vector3 = data["orig_scale"]
			var orig_modulate: Color = data["orig_modulate"]

			# Start: at ground level, zero scale
			var ground_pos := Vector3(orig_pos.x, 0.0, orig_pos.z)

			if i > 0:
				tween.tween_interval(deco_stagger)

			tween.tween_property(sprite, "scale", orig_scale, deco_duration) \
				.from(Vector3.ZERO) \
				.set_ease(deco_ease).set_trans(deco_trans)
			tween.parallel().tween_property(sprite, "position", orig_pos, deco_duration) \
				.from(ground_pos) \
				.set_ease(deco_ease).set_trans(deco_trans)
			tween.parallel().tween_property(sprite, "modulate:a", orig_modulate.a, deco_duration * 0.5) \
				.from(0.0)


func _hide_decorations() -> void:
	for data: Dictionary in _deco_sprites:
		var sprite: Sprite3D = data["sprite"]
		sprite.scale = Vector3.ZERO
		sprite.modulate.a = 0.0


## Show decorations at their final position/scale (for preview tiles).
func _show_decorations() -> void:
	for data: Dictionary in _deco_sprites:
		var sprite: Sprite3D = data["sprite"]
		sprite.scale = data["orig_scale"]
		sprite.modulate = data["orig_modulate"]
