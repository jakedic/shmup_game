# stats.gd
# Autoload this as "Stats" (Project Settings -> Autoload).
#
# Layered stat system:
#   default_stats          -> immutable baseline, never written to at runtime
#   progression_overrides  -> permanent deltas earned across levels/sessions
#   level_modifiers        -> named, stackable changes that persist for the
#                              current level only (e.g. power-bubble power-ups).
#                              Cleared with clear_level_modifiers() whenever a
#                              level starts (see BaseLevel.new_game()).
#   active_modifiers       -> named, stackable, TEMPORARY changes (absorb/transform)
#   current_stats          -> resolved cache that gameplay code actually reads
#
# current = default, then progression, then level modifiers, then each active
# modifier, applied in the order each was added. Removing a modifier just
# erases its entry and recomputes — no manual "undo the math" step required
# anywhere.
extends Node

signal stats_changed(category: String)
signal powerup_collected(powerup_id: String)

const CATEGORIES = ["player", "bullet", "bubble", "pollen"]

# ===== TIER 1: DEFAULT =====
# Never mutate this dictionary at runtime. If you want to tweak a base value,
# change it here — everything downstream recomputes automatically.
var default_stats: Dictionary = {
	"player": {
		"speed": 150.0,
		"acceleration": 10.0,
		"deceleration": 10.0,
		"max_shield": 10,
		"shield_regen_rate": 0.0,
		"shield_regen_delay": 3.0,
		"shoot_cooldown": 0.25,
		"absorb_cooldown": 2.0,
		"dash_speed": 400.0,
		"dash_duration": 0.15,
		"dash_cooldown": 0.5,
		"can_multi_shoot": false,
		"shot_count": 1,
		"shot_spread": 30.0,
		# dash "curve" knobs used by the transform forms
		"spin_speed": 0.0,
		"circle_radius": 0.0,
		"circle_speed": 0.0,
		"steering_influence": 5.0,
		"dash_damage_amount": 1,
		# yellow form's charge shot
		"charge_shot_duration": 1.0,     # seconds held to fully charge
		"charge_flash_interval": 0.15,   # blink speed while charging (pre-full-charge)
		# categorical / boolean examples
		"dash_invincible": false,
		"dash_damages_enemies": false,
		# yellow power-up: secondary "pollen shot" fire (see
		# player/player_powerups.gd + player/player_pollen_shot.gd) - off
		# unless granted by a power bubble this level.
		"has_pollen_shot": false,
	},
	"bullet": {
		"speed": 250.0,
		"damage": 1,
		"pierce_count": 0,
		"can_pierce": false,
		"max_distance": 125.0,
		"homing_enabled": false,
		"homing_strength": 1.0,
	},
	"bubble": {
		"speed": 100.0,
		"damage": 1,
		"travel_distance": 50.0,
		"lifetime": 30.0,
		"hit_points": 3,
	},
	# Weak, slow, wiggling secondary-fire bullets fired in pairs from the
	# left/right of the ship while "has_pollen_shot" is active (see
	# player/player_pollen_shot.gd). Completely independent of the "bullet"
	# category used for the player's normal shot.
	"pollen": {
		"speed": 90.0,
		"damage": 1,
		"cooldown": 0.35,
		"max_distance": 220.0,
		"wiggle_amplitude": 10.0,   # how far side-to-side it drifts, in px
		"wiggle_frequency": 6.0,    # how fast it wiggles, in radians/sec
	},
}

# ===== TIER 2: PROGRESSION =====
# Only ever contains keys that DIFFER from default. Small, diff-friendly,
# easy to save/load (see save/load helpers at bottom).
var progression_overrides: Dictionary = {
	"player": {},
	"bullet": {},
	"bubble": {},
	"pollen": {},
}

# ===== TIER 3: LEVEL MODIFIERS (persist for the current level, stackable, named) =====
# Same shape as active_modifiers below, but these are NOT tied to a
# transformation's lifetime - they stick around (e.g. power-bubble power-ups)
# until clear_level_modifiers() is called at the start of a new level/run.
# mod_name -> { category -> { stat_key -> {"op": "set"|"add"|"mult", "value": x} } }
var level_modifiers: Dictionary = {}

# IDs of power-ups collected so far this level, in collection order. Handy
# for UI or debugging; add_powerup() keeps this in sync with level_modifiers.
var collected_powerups: Array = []

# ===== TIER 4: MODIFIERS (temporary, stackable, named) =====
# mod_name -> { category -> { stat_key -> {"op": "set"|"add"|"mult", "value": x} } }
var active_modifiers: Dictionary = {}

# ===== TIER 5: CURRENT (resolved cache) =====
var current_stats: Dictionary = {}


func _ready():
	recompute_all()


# ---------- Recompute ----------

func recompute_all():
	for category in CATEGORIES:
		recompute(category)


func recompute(category: String):
	var result: Dictionary = default_stats[category].duplicate()

	for key in progression_overrides[category]:
		result[key] = progression_overrides[category][key]

	# Level modifiers (power-ups picked up this level) apply next, in
	# insertion order, then active modifiers (transformations etc.) on top -
	# so a transformation can still temporarily override a power-up's effect
	# without losing it once the transformation ends.
	for mod_name in level_modifiers:
		var level_mods: Dictionary = level_modifiers[mod_name].get(category, {})
		for key in level_mods:
			result[key] = _apply_op(result.get(key), level_mods[key])

	# Modifiers apply in insertion order, so if you ever stack two at once
	# (e.g. transform + a temporary powerup) the order they were added matters.
	for mod_name in active_modifiers:
		var mods: Dictionary = active_modifiers[mod_name].get(category, {})
		for key in mods:
			result[key] = _apply_op(result.get(key), mods[key])

	current_stats[category] = result
	stats_changed.emit(category)


func _apply_op(base_value, op: Dictionary):
	match op.get("op", "set"):
		"add":
			return base_value + op.value
		"mult":
			return base_value * op.value
		_: # "set"
			return op.value


# ---------- Public read API ----------

func get_stat(category: String, key: String):
	return current_stats.get(category, {}).get(key)

func get_category(category: String) -> Dictionary:
	return current_stats.get(category, {})


# ---------- Progression (permanent, persists across levels) ----------

func set_progression_stat(category: String, key: String, value):
	progression_overrides[category][key] = value
	recompute(category)

func clear_progression():
	for category in CATEGORIES:
		progression_overrides[category] = {}
	recompute_all()


# ---------- Level modifiers (persist for the current level, e.g. power-bubble power-ups) ----------

func add_level_modifier(mod_name: String, modifiers: Dictionary):
	level_modifiers[mod_name] = modifiers
	for category in modifiers:
		recompute(category)

func remove_level_modifier(mod_name: String):
	if not level_modifiers.has(mod_name):
		return
	var affected_categories = level_modifiers[mod_name].keys()
	level_modifiers.erase(mod_name)
	for category in affected_categories:
		recompute(category)

func has_level_modifier(mod_name: String) -> bool:
	return level_modifiers.has(mod_name)

func clear_level_modifiers():
	"""Call at the start of every new level/run (see BaseLevel.new_game())
	so power-ups collected in a previous level don't carry over."""
	var affected_categories = {}
	for mod_name in level_modifiers:
		for category in level_modifiers[mod_name]:
			affected_categories[category] = true
	level_modifiers.clear()
	collected_powerups.clear()
	for category in affected_categories:
		recompute(category)

func add_powerup(powerup_id: String, modifiers: Dictionary):
	"""Convenience wrapper around add_level_modifier() for power-ups granted
	by power bubbles. Each call gets its own unique internal modifier name
	(so collecting the same power-up twice stacks rather than overwriting),
	while collected_powerups keeps the plain ids for UI/debugging."""
	var unique_mod_name = "powerup_%s_%d" % [powerup_id, collected_powerups.size()]
	collected_powerups.append(powerup_id)
	add_level_modifier(unique_mod_name, modifiers)
	powerup_collected.emit(powerup_id)


# ---------- Modifiers (temporary, e.g. absorb transformations) ----------

func add_modifier(mod_name: String, modifiers: Dictionary):
	active_modifiers[mod_name] = modifiers
	for category in modifiers:
		recompute(category)

func remove_modifier(mod_name: String):
	if not active_modifiers.has(mod_name):
		return
	var affected_categories = active_modifiers[mod_name].keys()
	active_modifiers.erase(mod_name)
	for category in affected_categories:
		recompute(category)

func has_modifier(mod_name: String) -> bool:
	return active_modifiers.has(mod_name)

func clear_all_modifiers():
	var all_categories = {}
	for mod_name in active_modifiers:
		for category in active_modifiers[mod_name]:
			all_categories[category] = true
	active_modifiers.clear()
	for category in all_categories:
		recompute(category)


# ---------- Save / load progression between sessions (optional) ----------

func save_progression(path: String = "user://progression.save"):
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(progression_overrides))
	file.close()

func load_progression(path: String = "user://progression.save"):
	if not FileAccess.file_exists(path):
		return
	var file = FileAccess.open(path, FileAccess.READ)
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(data) == TYPE_DICTIONARY:
		progression_overrides = data
		recompute_all()
