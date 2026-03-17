class_name TileDeck
extends RefCounted

## Sunscar hex tile generator — 4 terrain types, Dorfromantik-style templates.
## Terrains: 0=Wasteland, 1=Forest, 2=Fortress, 3=Mine
## Edges: [E, NE, NW, W, SW, SE] — 6 edges per hex

const DEFAULT_STARTING_GROUPS := 40

var _remaining: int = DEFAULT_STARTING_GROUPS
var _rng := RandomNumberGenerator.new()

## W=Wasteland(0), F=Forest(1), X=Fortress(2), M=Mine(3)
const TEMPLATES: Array[Dictionary] = [
	# ── Pure terrain (all 6 edges same) ──
	{ edges = [0,0,0,0,0,0], name = "Pustkowia" },
	{ edges = [0,0,0,0,0,0], name = "Pustkowia" },
	{ edges = [0,0,0,0,0,0], name = "Pustkowia" },
	{ edges = [1,1,1,1,1,1], name = "Gęsty bór" },
	{ edges = [1,1,1,1,1,1], name = "Gęsty bór" },
	{ edges = [2,2,2,2,2,2], name = "Cytadela" },
	{ edges = [3,3,3,3,3,3], name = "Wielka kopalnia" },

	# ── Half tiles (3+3 split) ──
	{ edges = [1,1,1,0,0,0], name = "Skraj lasu" },
	{ edges = [1,1,1,0,0,0], name = "Skraj lasu" },
	{ edges = [1,1,1,0,0,0], name = "Skraj lasu" },
	{ edges = [2,2,2,0,0,0], name = "Mury" },
	{ edges = [2,2,2,0,0,0], name = "Mury" },
	{ edges = [3,3,3,0,0,0], name = "Wyrobisko" },
	{ edges = [3,3,3,0,0,0], name = "Wyrobisko" },

	# ── Wedge (2 adjacent edges) ──
	{ edges = [1,1,0,0,0,0], name = "Zagajnik" },
	{ edges = [1,1,0,0,0,0], name = "Zagajnik" },
	{ edges = [1,1,0,0,0,0], name = "Zagajnik" },
	{ edges = [2,2,0,0,0,0], name = "Wieża" },
	{ edges = [2,2,0,0,0,0], name = "Wieża" },
	{ edges = [3,3,0,0,0,0], name = "Szyb" },
	{ edges = [3,3,0,0,0,0], name = "Szyb" },

	# ── Single edge ──
	{ edges = [1,0,0,0,0,0], name = "Samotne drzewo" },
	{ edges = [1,0,0,0,0,0], name = "Samotne drzewo" },
	{ edges = [2,0,0,0,0,0], name = "Strażnica" },
	{ edges = [2,0,0,0,0,0], name = "Strażnica" },
	{ edges = [3,0,0,0,0,0], name = "Odkrywka" },
	{ edges = [3,0,0,0,0,0], name = "Odkrywka" },

	# ── Opposite pairs ──
	{ edges = [1,0,0,1,0,0], name = "Przesieka" },
	{ edges = [1,0,0,1,0,0], name = "Przesieka" },
	{ edges = [2,0,0,2,0,0], name = "Bastiony" },
	{ edges = [3,0,0,3,0,0], name = "Dwa szyby" },

	# ── Mixed: Forest + Fortress ──
	{ edges = [1,1,1,2,2,2], name = "Leśna twierdza" },
	{ edges = [1,1,1,2,2,2], name = "Leśna twierdza" },
	{ edges = [1,1,0,2,0,0], name = "Fort przy borze" },

	# ── Mixed: Forest + Mine ──
	{ edges = [1,1,1,3,3,3], name = "Wyręb" },
	{ edges = [1,1,1,3,3,3], name = "Wyręb" },
	{ edges = [1,1,0,3,0,0], name = "Tartak" },

	# ── Mixed: Fortress + Mine ──
	{ edges = [2,2,2,3,3,3], name = "Kuźnia" },
	{ edges = [2,2,2,3,3,3], name = "Kuźnia" },
	{ edges = [2,2,0,3,0,0], name = "Zbrojownia" },

	# ── 4 edges + 2 wasteland ──
	{ edges = [1,1,1,1,0,0], name = "Gaj" },
	{ edges = [1,1,1,1,0,0], name = "Gaj" },
	{ edges = [2,2,2,2,0,0], name = "Warownia" },
	{ edges = [3,3,3,3,0,0], name = "Kamieniołom" },

	# ── 5 edges + 1 gap ──
	{ edges = [1,1,1,1,1,0], name = "Polana" },
	{ edges = [2,2,2,2,2,0], name = "Oblężenie" },

	# ── Three-way split ──
	{ edges = [1,1,2,2,3,3], name = "Rozdroże" },
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
	group.rotation = _rng.randi_range(0, 5)
	return group
