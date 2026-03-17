class_name DecorationScatterer
extends Node3D

## Procedural decoration placement. Reads child Sprite3D nodes as templates,
## removes them, then spawns randomized copies scattered across the tile.
## Attach to a Node3D inside a tile scene (e.g. "Decorations_procedural").

# ── Count ─────────────────────────────────────────────────────────────
@export_group("Count")
@export var min_count: int = 4          ## Minimum decorations to spawn
@export var max_count: int = 10         ## Maximum decorations to spawn

# ── Placement ─────────────────────────────────────────────────────────
@export_group("Placement")
@export var spread: float = 0.40        ## Max XZ distance from center (within hex apothem)
@export var base_height: float = 0.06   ## Y position of sprite base (above tile mesh)
@export var edge_padding: float = 0.05  ## Keep sprites this far from tile edges

# ── Scale ─────────────────────────────────────────────────────────────
@export_group("Scale")
@export var base_scale: float = 1.2     ## Base uniform scale for sprites
@export var scale_variation: float = 0.35  ## ± random scale range (e.g. 0.35 → 0.85-1.55)

# ── Variety ───────────────────────────────────────────────────────────
@export_group("Variety")
@export var flip_chance: float = 0.5    ## Chance to flip sprite horizontally
@export var brightness_min: float = 0.7 ## Darkest modulate value
@export var brightness_max: float = 1.0 ## Brightest modulate value

# ── Tilt (sprite lean toward camera) ──────────────────────────────────
@export_group("Tilt")
@export var tilt_angle_deg: float = 30.0  ## Degrees to tilt sprite toward camera (0 = vertical)

# ── Internal ──────────────────────────────────────────────────────────
var _templates: Array[Dictionary] = []  ## Cached template data
var _scattered: bool = false


func _ready() -> void:
	_collect_templates()


## Collect sprite data from children, then remove original nodes.
func _collect_templates() -> void:
	var to_remove: Array[Node] = []
	for child in get_children():
		if child is Sprite3D:
			var sprite := child as Sprite3D
			_templates.append({
				"texture": sprite.texture,
				"region_enabled": sprite.region_enabled,
				"region_rect": sprite.region_rect,
				"alpha_cut": sprite.alpha_cut,
				"alpha_antialiasing_mode": sprite.alpha_antialiasing_mode,
				"pixel_size": sprite.pixel_size,
			})
			to_remove.append(child)

	# Remove template nodes — they served their purpose
	for node: Node in to_remove:
		node.queue_free()


## Scatter decorations. Call this after the tile is added to the scene.
## seed_value: deterministic seed so same tile always looks the same (use grid position hash).
func scatter(seed_value: int = -1) -> void:
	if _scattered or _templates.is_empty():
		return
	_scattered = true

	var rng := RandomNumberGenerator.new()
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()

	var count := rng.randi_range(min_count, max_count)
	var usable_spread := spread - edge_padding

	for i: int in range(count):
		# Pick random template
		var tmpl: Dictionary = _templates[rng.randi() % _templates.size()]

		var sprite := Sprite3D.new()
		sprite.texture = tmpl["texture"]
		sprite.region_enabled = tmpl["region_enabled"]
		sprite.region_rect = tmpl["region_rect"]
		sprite.alpha_cut = tmpl["alpha_cut"]
		sprite.alpha_antialiasing_mode = tmpl["alpha_antialiasing_mode"]
		sprite.pixel_size = tmpl.get("pixel_size", 0.01)
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
		sprite.shaded = false
		sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y

		# Random position within tile bounds
		var pos_x := rng.randf_range(-usable_spread, usable_spread)
		var pos_z := rng.randf_range(-usable_spread, usable_spread)

		# Scale with variation
		var s := base_scale + rng.randf_range(-scale_variation, scale_variation)
		s = maxf(s, 0.3)  # Never go too small

		# Build transform: tilt sprite forward (around X axis)
		var tilt_rad := deg_to_rad(tilt_angle_deg)
		var tilt_basis := Basis(Vector3.RIGHT, -tilt_rad)

		# Apply uniform scale
		var scaled_basis := tilt_basis.scaled(Vector3(s, s, s))

		# Flip horizontally
		if rng.randf() < flip_chance:
			sprite.flip_h = true

		# Brightness variation
		var brightness := rng.randf_range(brightness_min, brightness_max)
		sprite.modulate = Color(brightness, brightness, brightness, 1.0)

		# Final transform
		sprite.transform = Transform3D(scaled_basis, Vector3(pos_x, base_height, pos_z))

		add_child(sprite)


## Get all spawned sprites (for animation, tinting, etc.)
func get_spawned_sprites() -> Array[Sprite3D]:
	var result: Array[Sprite3D] = []
	for child in get_children():
		if child is Sprite3D:
			result.append(child as Sprite3D)
	return result
