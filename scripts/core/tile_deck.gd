class_name TileDeck
extends RefCounted

## Sunscar tile generator — 6 edge types, template-based.
## Edges: 0=Sand, 1=Trail, 2=Settlement, 3=Ruins, 4=Mountains, 5=Oasis

const DEFAULT_STARTING_GROUPS := 40

var _remaining: int = DEFAULT_STARTING_GROUPS
var _rng := RandomNumberGenerator.new()

## Template pool — edges are [E, N, W, S]
## Weight controlled by repetition.
const TEMPLATES: Array[Dictionary] = [
	# ── Pure sand (filler, common) ──
	{ edges = [0, 0, 0, 0], name = "Wydma" },
	{ edges = [0, 0, 0, 0], name = "Wydma" },
	{ edges = [0, 0, 0, 0], name = "Wydma" },
	{ edges = [0, 0, 0, 0], name = "Wydma" },

	# ── Trail tiles (caravan routes, common) ──
	{ edges = [0, 1, 0, 1], name = "Szlak prosty" },      # N-S
	{ edges = [0, 1, 0, 1], name = "Szlak prosty" },
	{ edges = [0, 1, 0, 1], name = "Szlak prosty" },
	{ edges = [1, 0, 1, 0], name = "Szlak prosty" },      # E-W
	{ edges = [1, 1, 0, 0], name = "Szlak zakręt" },      # E-N
	{ edges = [1, 1, 0, 0], name = "Szlak zakręt" },
	{ edges = [1, 0, 0, 1], name = "Szlak zakręt" },      # E-S
	{ edges = [0, 1, 1, 0], name = "Szlak zakręt" },      # N-W
	{ edges = [1, 1, 0, 1], name = "Rozwidlenie" },       # E-N-S
	{ edges = [1, 1, 1, 1], name = "Skrzyżowanie" },      # All 4

	# ── Settlement tiles (sandstone cities) ──
	{ edges = [0, 2, 0, 0], name = "Mury" },               # N only
	{ edges = [0, 2, 0, 0], name = "Mury" },
	{ edges = [2, 2, 0, 0], name = "Narożnik" },           # E-N
	{ edges = [2, 2, 0, 0], name = "Narożnik" },
	{ edges = [2, 2, 2, 0], name = "Twierdza" },           # E-N-W
	{ edges = [2, 2, 2, 2], name = "Cytadela" },           # All 4

	# ── Settlement + Trail (gates, trade) ──
	{ edges = [0, 2, 0, 1], name = "Brama" },              # N settlement, S trail
	{ edges = [0, 2, 0, 1], name = "Brama" },
	{ edges = [1, 2, 1, 0], name = "Trakt handlowy" },     # E-W trail, N settlement
	{ edges = [2, 2, 1, 0], name = "Brama narożna" },      # E-N settlement, W trail

	# ── Mountains (rocky formations) ──
	{ edges = [0, 4, 0, 0], name = "Klif" },               # N only
	{ edges = [0, 4, 0, 0], name = "Klif" },
	{ edges = [4, 4, 0, 0], name = "Wąwóz" },             # E-N
	{ edges = [4, 4, 0, 0], name = "Wąwóz" },
	{ edges = [4, 4, 4, 0], name = "Pasmo" },              # E-N-W
	{ edges = [4, 4, 4, 4], name = "Szczyt" },             # All 4

	# ── Mountains + Trail (mountain passes) ──
	{ edges = [1, 4, 1, 0], name = "Przełęcz" },           # E-W trail, N mountains
	{ edges = [0, 4, 0, 1], name = "Przełęcz" },           # N mountains, S trail
	{ edges = [4, 4, 1, 0], name = "Górska brama" },       # E-N mountains, W trail

	# ── Mountains + Settlement (fortresses) ──
	{ edges = [2, 4, 0, 0], name = "Twierdza górska" },    # E settlement, N mountains
	{ edges = [4, 2, 0, 0], name = "Twierdza górska" },    # E mountains, N settlement

	# ── Oasis tiles (rare, valuable) ──
	{ edges = [0, 5, 0, 0], name = "Oaza" },               # N only
	{ edges = [5, 0, 5, 0], name = "Oaza podwójna" },      # E-W
	{ edges = [0, 5, 0, 5], name = "Oaza podwójna" },      # N-S

	# ── Oasis + Trail (caravan stops) ──
	{ edges = [1, 5, 0, 0], name = "Postój karawany" },    # E trail, N oasis
	{ edges = [0, 5, 0, 1], name = "Postój karawany" },    # N oasis, S trail

	# ── Oasis + Settlement (prosperous cities) ──
	{ edges = [2, 5, 0, 0], name = "Raj kupców" },         # E settlement, N oasis
	{ edges = [5, 2, 0, 0], name = "Raj kupców" },         # E oasis, N settlement
]


func _init(starting_groups: int = DEFAULT_STARTING_GROUPS) -> void:
	_remaining = starting_groups
	_rng.randomize()


func draw() -> TileGroup:
	if _remaining <= 0:
		return null
	_remaining -= 1
	return _generate_random_tile()


func add_groups(count: int) -> void:
	_remaining += count


func groups_remaining() -> int:
	return _remaining


func _generate_random_tile() -> TileGroup:
	var template: Dictionary = TEMPLATES[_rng.randi_range(0, TEMPLATES.size() - 1)]
	var group := TileGroup.new()
	var src: Array = template.edges
	group.edges.clear()
	for e in src:
		group.edges.append(e as int)
	group.template_name = template.name as String
	group.rotation = _rng.randi_range(0, 3)
	return group
