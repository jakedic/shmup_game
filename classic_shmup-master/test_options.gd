# test_options.gd
#
# Switches for trying out gameplay variations (scripts that use these load
# this file with `const TestOptions := preload("res://test_options.gd")`), toggled from the Test menu
# (levels/test_menu.gd). Gameplay code checks them with e.g.
#     if TestOptions.is_on(TestOptions.BUBBLE_SHOT_EXPLODES): ...
#
# The defaults are the game's normal behavior, so the game plays exactly as
# before unless something is changed in the Test menu. Changes stick for the
# rest of the session (until the game is closed), including after leaving
# the test level.
#
# To add a switch: add an id const, a default in `values`, and a row in
# MENU_ROWS - the Test menu builds its checkboxes from MENU_ROWS.
extends RefCounted

# --- Bubble: shooting it ---
const BUBBLE_SHOT_EXPLODES := "bubble_shot_explodes"   # shot -> pops in a big explosion (normal)
const BUBBLE_SHOT_CHARGES := "bubble_shot_charges"     # shot -> +1 charge (damages enemies for one bounce off the ship), up to 3
const BUBBLE_SHOT_BOUNCES := "bubble_shot_bounces"     # shot -> knocked away from the bullet
const BUBBLE_SHOT_PASSES := "bubble_shot_passes"       # the bullet keeps going through the bubble (after doing any of the above)
# --- Bubble: jumping on it (the landing shockwave reaching it) ---
const BUBBLE_JUMP_CHARGES := "bubble_jump_charges"     # jump -> powered up (normal)
const BUBBLE_JUMP_EXPLODES := "bubble_jump_explodes"   # jump -> pops in a big explosion
const BUBBLE_JUMP_REGAINS := "bubble_jump_regains"     # jump -> pops and you get its transformation back
const BUBBLE_JUMP_SHOCKWAVE := "bubble_jump_shockwave" # jump -> after a short delay the bubble sends out 3 landing-style shockwaves
# --- Bubble: movement ---
const BUBBLE_ENEMY_BOUNCE := "bubble_enemy_bounce"     # bounces off enemies as well as the stage walls
# --- Multiplier / absorbing ---
const ALWAYS_MAX_MULTIPLIER := "always_max_multiplier" # multiplier never drops below 4x
const KILL_POINTS_X4 := "kill_points_x4"               # kills charge the multiplier 4x as much
const ABSORB_ASTROIDS := "absorb_astroids"             # the absorb beam works on astroids, giving the gray form
# --- Sliders (numbers, not on/off) ---
const BUBBLE_SPEED := "bubble_speed"   # 0-10; 5 = normal speed, 0 = doesn't move, 10 = double

static var values := {
	BUBBLE_SHOT_EXPLODES: true,
	BUBBLE_SHOT_CHARGES: false,
	BUBBLE_SHOT_BOUNCES: false,
	BUBBLE_JUMP_CHARGES: true,
	BUBBLE_JUMP_EXPLODES: false,
	BUBBLE_JUMP_REGAINS: false,
	BUBBLE_JUMP_SHOCKWAVE: false,
	BUBBLE_ENEMY_BOUNCE: false,
	ALWAYS_MAX_MULTIPLIER: false,
	KILL_POINTS_X4: false,
	ABSORB_ASTROIDS: false,
	BUBBLE_SPEED: 5,
}

# Test menu layout: a "header" row starts a group, a "slider" row is a number
# changed with Left/Right (min..max), every other row is a checkbox for one
# switch.
const MENU_ROWS := [
	{"header": "BUBBLE - SHOOT IT"},
	{"id": BUBBLE_SHOT_EXPLODES, "name": "Shot: explodes"},
	{"id": BUBBLE_SHOT_CHARGES, "name": "Shot: powers up (1 bounce, x3)"},
	{"id": BUBBLE_SHOT_BOUNCES, "name": "Shot: bounces off bullet"},
	{"id": BUBBLE_SHOT_PASSES, "name": "Shot: bullet passes through"},
	{"header": "BUBBLE - JUMP ON IT"},
	{"id": BUBBLE_JUMP_CHARGES, "name": "Jump: powers up"},
	{"id": BUBBLE_JUMP_EXPLODES, "name": "Jump: pops + explodes"},
	{"id": BUBBLE_JUMP_REGAINS, "name": "Jump: pops, regain its power"},
	{"id": BUBBLE_JUMP_SHOCKWAVE, "name": "Jump: bubble sends 3 shockwaves"},
	{"header": "BUBBLE - MOVEMENT"},
	{"id": BUBBLE_ENEMY_BOUNCE, "name": "Bounces off enemies"},
	{"slider": BUBBLE_SPEED, "name": "Speed", "min": 0, "max": 10},
	{"header": "MULTIPLIER / ABSORB"},
	{"id": ALWAYS_MAX_MULTIPLIER, "name": "Always 4x multiplier"},
	{"id": KILL_POINTS_X4, "name": "Kills charge multiplier x4"},
	{"id": ABSORB_ASTROIDS, "name": "Absorb astroids (gray form)"},
]


static func is_on(id: String) -> bool:
	return bool(values.get(id, false))


static func set_on(id: String, on: bool) -> void:
	values[id] = on


static func toggle(id: String) -> void:
	values[id] = not is_on(id)


## Slider value (e.g. BUBBLE_SPEED).
static func get_value(id: String) -> int:
	return int(values.get(id, 0))


static func set_value(id: String, value: int) -> void:
	values[id] = value


## BUBBLE_SPEED as a multiplier on the bubble's normal speed: 5 -> 1.0,
## 0 -> 0.0 (stands still), 10 -> 2.0.
static func bubble_speed_scale() -> float:
	return get_value(BUBBLE_SPEED) / 5.0
