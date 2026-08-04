# stats.gd
# Autoload this as "Stats" (Project Settings -> Autoload).
#
# Layered stat system:
#   default_stats          -> immutable baseline, never written to at runtime
#   progression_overrides  -> permanent deltas earned across levels/sessions
#   active_modifiers       -> named, stackable, TEMPORARY changes (absorb/transform)
#   current_stats          -> resolved cache that gameplay code actually reads
#
# current = default, then progression applied on top, then each active modifier
# applied in the order it was added. Removing a modifier just erases its entry
# and recomputes — no manual "undo the math" step required anywhere.
extends Node

signal stats_changed(category: String)

const CATEGORIES = ["player", "bullet", "bubble"]

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
}

# ===== TIER 2: PROGRESSION =====
# Only ever contains keys that DIFFER from default. Small, diff-friendly,
# easy to save/load (see save/load helpers at bottom).
var progression_overrides: Dictionary = {
	"player": {},
	"bullet": {},
	"bubble": {},
}

# ===== TIER 3: MODIFIERS (temporary, stackable, named) =====
# mod_name -> { category -> { stat_key -> {"op": "set"|"add"|"mult", "value": x} } }
var active_modifiers: Dictionary = {}

# ===== TIER 4: CURRENT (resolved cache) =====
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
