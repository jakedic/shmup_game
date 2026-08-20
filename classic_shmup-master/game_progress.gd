# game_progress.gd
# Autoload this as "GameProgress" (Project Settings -> Autoload).
#
# Tracks the player's run through the space overworld: a small directed
# graph of "planet" nodes the player travels between, playing a level at
# each one. See levels/overworld.gd for the map/visuals and the input that
# lets the player choose a path once a level is beaten.
#
# Graph shape:
#   layer 0        -> 1 node  (the start planet)
#   layers 1 - 5    -> 3 nodes each (the branching layers)
#   layer 6        -> 1 node  (the final/end planet)
#
# Every node in a branching layer shares the same trio of children in the
# next layer - no matter which of the 3 nodes you're standing on, you
# always choose from the same 3 next planets.
#
# The 3rd branching layer (LAYERS[SHOP_LAYER_INDEX], nodes 7/8/9) is all
# shops instead of levels - see is_shop_node() / levels/shop.gd.
extends Node

const START_ID := 0
const END_ID := 16

const LAYERS := [
	[0],
	[1, 2, 3],
	[4, 5, 6],
	[7, 8, 9],
	[10, 11, 12],
	[13, 14, 15],
	[16],
]

# For now every non-shop node just alternates between the two levels that
# exist.
const LEVEL_SCENES := [
	"res://levels/level_1.tscn",
	"res://levels/level_2.tscn",
]

# Which branching layer (an index into LAYERS) is all shops. See
# is_shop_node() / levels/shop.gd.
const SHOP_LAYER_INDEX := 3
const SHOP_SCENE := "res://levels/shop.tscn"

# The very first node of every run always plays Yellow Level instead of
# whatever LEVEL_SCENES' alternating pattern would otherwise assign it (see
# _build_graph() below) - it's the showcase level for the new squad-based
# yellow enemy behavior (see enemies/yellow_squad.gd).
const YELLOW_LEVEL_SCENE := "res://levels/yellow_level.tscn"

# node id -> array of node ids it can lead to.
var _children: Dictionary = {}

# node id -> which level scene playing that node loads (meaningless for shop
# nodes - see is_shop_node()/SHOP_SCENE instead).
var _level_scenes: Dictionary = {}

# The node ids the player has actually completed this run, in order
# travelled (e.g. [0, 2, 4, ...]). Used by the overworld to draw the
# travelled path. Empty until the start node is beaten.
var path_history: Array = []

# -1 means "the player hasn't completed any node yet this run" (only true
# right at the start, before the first node is played).
var current_node_id: int = -1

# The node id whose level/shop is currently loaded/being played. Set by
# select_and_play(), consumed by on_level_won()/on_level_lost().
var pending_node_id: int = -1

# True from the moment the player presses Start on the title screen until
# they either win the final node or lose a level (at which point the run
# resets and this goes false again).
var run_active: bool = false


func _ready() -> void:
	_build_graph()


func _build_graph() -> void:
	for layer_index in range(LAYERS.size() - 1):
		var layer: Array = LAYERS[layer_index]
		var next_layer: Array = LAYERS[layer_index + 1]
		for node_id in layer:
			_children[node_id] = next_layer.duplicate()
	_children[END_ID] = []

	for layer in LAYERS:
		for node_id in layer:
			_level_scenes[node_id] = LEVEL_SCENES[node_id % LEVEL_SCENES.size()]

	# Override just the start node so the first level of every run is Yellow
	# Level - everything else keeps the normal alternating assignment above.
	_level_scenes[START_ID] = YELLOW_LEVEL_SCENE


# ---------- Run lifecycle ----------

func start_new_run() -> void:
	current_node_id = -1
	pending_node_id = -1
	path_history.clear()
	run_active = true
	# A fresh run always starts with no carried-forward power-ups or shop
	# currency, even if the player quit out mid-run last time without losing.
	Stats.clear_run_modifiers()
	Stats.clear_currency()


func reset_run() -> void:
	current_node_id = -1
	pending_node_id = -1
	path_history.clear()
	run_active = false
	# Losing wipes out any power-ups chosen to carry forward this run, and
	# any unspent shop currency - only a completed level's choice/currency
	# survives, and only until the run itself ends.
	Stats.clear_run_modifiers()
	Stats.clear_currency()


func is_active() -> bool:
	return run_active


# ---------- Map data ----------

func get_layer_of(node_id: int) -> int:
	for i in range(LAYERS.size()):
		if LAYERS[i].has(node_id):
			return i
	return -1


func get_next_nodes(node_id: int) -> Array:
	return _children.get(node_id, [])


func get_level_scene(node_id: int) -> String:
	return _level_scenes.get(node_id, LEVEL_SCENES[0])


func is_shop_node(node_id: int) -> bool:
	"""True for every node in the shop layer (see SHOP_LAYER_INDEX) -
	select_and_play() sends these to SHOP_SCENE instead of a level, and
	levels/overworld.gd draws them with a different icon."""
	return LAYERS[SHOP_LAYER_INDEX].has(node_id)


# The node(s) the player may currently choose to travel to & play. A single
# entry means there's no real choice yet (the very first node, or the
# forced final approach to the end node); three entries means an actual
# branch decision.
func get_available_nodes() -> Array:
	if current_node_id == -1:
		return [START_ID]
	return get_next_nodes(current_node_id)


func has_won_run() -> bool:
	return current_node_id == END_ID


# ---------- Choosing & playing a node ----------

func select_and_play(node_id: int) -> void:
	pending_node_id = node_id
	if is_shop_node(node_id):
		get_tree().change_scene_to_file(SHOP_SCENE)
	else:
		get_tree().change_scene_to_file(get_level_scene(node_id))


# ---------- Level/shop outcome hooks ----------
# on_level_won() is called both from base_level.gd (a level was cleared) and
# from levels/shop.gd (the player left the shop) - either way, the pending
# node is now "completed" and the player goes back to the overworld to pick
# their next stop.

func on_level_won() -> void:
	current_node_id = pending_node_id
	pending_node_id = -1
	if not path_history.has(current_node_id):
		path_history.append(current_node_id)
	get_tree().change_scene_to_file("res://levels/overworld.tscn")


func on_level_lost() -> void:
	reset_run()
	get_tree().change_scene_to_file("res://levels/title_screen.tscn")
