# level_0.gd
#
# (Moved here from levels/a_test.gd on 2026-11-06 - a_test is now for small
# one-off tests.)
#
# Practice run of the tutorial: the same waves as levels/tutorial.gd (it
# reuses them - edit a wave there and it changes here too), but with no
# dialogue, no tutorial cards, no missions and nothing that holds the level
# up. Every ability is on from the start, and it plays straight through to
# the end without ever stopping to wait for the player.
#
# Waves played (see _ready()):
#   intro (dodging), 1 (jump walls + ring), 2 (shooting), 3 (mixed drops to
#   absorb), 6 (final exam), then the rainbow astroid boss
#   (enemies/boss_rainbow_astroid.tscn)
# Left out: 3b (the green target bubbles), 5a-5c (the bubble-power missions)
# and 7 (the outro, which is only dialogue).
#
# How it gets there, by switching off pieces of TutorialLevel:
#   - talk() / ask() / say() / show_info() do nothing
#   - begin_challenge() does nothing, so there's no right-panel mission and
#     no wave ever repeats
#   - wave 3 sends its drops for PRACTICE_MIXED_DROP_SECONDS instead of
#     waiting for an absorb
#   - nothing stops partway down the screen and waits to be shot
#
# On top of the waves, every SHIP_DROP_INTERVAL seconds one ship comes down
# the screen (see SHIP DROPS below): a random gray bee, hive or flower, or -
# COLORED_SHIP_CHANCE of the time - the full-color version with all its
# normal behavior (bee dive, hive stop-and-fire, flower laser). The drops stop
# once the boss arrives (it has its own drops), so the level can end once
# it's beaten.
#
# The badger boss test that used to live here is now levels/boss_test.gd.
extends TutorialLevel

# How long wave 3 sends its drops for.
const PRACTICE_MIXED_DROP_SECONDS := 21.0
# The boss comes in this many seconds after wave 6's last spawn (or sooner if
# the screen is cleared first).
const BOSS_ARRIVAL_GAP := 6.0
const BOSS_RAINBOW_ASTROID := preload("res://enemies/boss_rainbow_astroid.tscn")


func _ready() -> void:
	super._ready()   # TutorialLevel's setup (health refills, signal hookups, next_level)
	# Swap in the practice wave list. Waves don't start until the start
	# button, so replacing the list here is safe.
	waves = [_wave_intro, _wave_1, _wave_2, _wave_3, _wave_6_then_boss, _wave_boss]
	max_waves = waves.size()


## Wave 6 as usual, but with a timer on the end. Without it, wave 6 only ends
## once the screen is empty - and the ship drops would keep that from
## happening.
func _wave_6_then_boss() -> void:
	await _wave_6()
	next_wave_after_last_spawn(BOSS_ARRIVAL_GAP)


## Last wave: the rainbow astroid boss. The level ends once it (and anything
## it left on screen) is gone.
func _wave_boss() -> void:
	var boss = BOSS_RAINBOW_ASTROID.instantiate()
	add_child(boss)
	boss.start()


# --- Everything on, no dialogue, no missions ---

func _set_abilities(_can_shoot: bool, _can_jump: bool, _can_absorb: bool) -> void:
	if player:
		player.shoot_enabled = true
		player.jump_enabled = true
		player.absorb_enabled = true


func talk(_lines, _options: Dictionary = {}) -> void:
	pass


func ask(_text: String, _choices: Array, _options: Dictionary = {}) -> int:
	return 0


func say(_text: String, _options: Dictionary = {}) -> void:
	pass


func show_info(_config: Dictionary) -> void:
	pass


func begin_challenge(_config: Dictionary) -> void:
	pass   # no missions - _challenge stays empty, so waves never repeat


func show_challenge() -> void:
	pass


# --- No stopgaps ---

## Nothing parks partway down the screen waiting to be shot.
func spawn_drift_wave(config: Dictionary) -> void:
	var c := config.duplicate()
	c.erase("stop_percent")
	super.spawn_drift_wave(c)


func _mixed_drops_time_limit() -> float:
	return PRACTICE_MIXED_DROP_SECONDS


# --- SHIP DROPS ---

const SHIP_DROP_INTERVAL := 10.0     # seconds between ships
const COLORED_SHIP_CHANCE := 0.10    # chance a ship is the full-color version instead of gray
const SHIP_DROP_LANE_MIN := 0.15     # how far across the top edge a ship can come in (0-1)
const SHIP_DROP_LANE_MAX := 0.85

enum ShipKind { BEE, HIVE, FLOWER }


## Called by BaseLevel.new_game() once the start button is pressed.
func game_started():   # no return type, to match BaseLevel's
	super.game_started()
	_ship_drop_loop()


func _ship_drop_loop() -> void:
	while is_inside_tree() and playing:
		await wait(SHIP_DROP_INTERVAL)   # pause-aware
		if not is_inside_tree() or not playing or _last_wave_done():
			return
		_drop_random_ship()


## True once the final wave (the boss) has started - no more drops after
## that, or the screen would never empty and the level would never end.
func _last_wave_done() -> bool:
	return current_wave >= max_waves - 1 and not _wave_running and _pending_spawns <= 0


func _drop_random_ship() -> void:
	var kind: int = [ShipKind.BEE, ShipKind.HIVE, ShipKind.FLOWER].pick_random()
	var lane := randf_range(SHIP_DROP_LANE_MIN, SHIP_DROP_LANE_MAX)
	if randf() < COLORED_SHIP_CHANCE:
		_drop_colored_ship(kind, lane)
	else:
		_drop_gray_ship(kind, lane)


## Gray ships just drift straight down (same speeds as the tutorial's).
func _drop_gray_ship(kind: int, lane: float) -> void:
	match kind:
		ShipKind.BEE:
			spawn_drift_wave({"enemy": GRAY_BEE, "start_side": Side.TOP, "start_percent": lane, "end_side": Side.BOTTOM, "end_percent": lane, "speed": 30})
		ShipKind.HIVE:
			spawn_drift_wave({"enemy": GRAY_HIVE, "start_side": Side.TOP, "start_percent": lane, "end_side": Side.BOTTOM, "end_percent": lane, "speed": 25})
		ShipKind.FLOWER:
			spawn_drift_wave({"enemy": GRAY_FLOWER, "start_side": Side.TOP, "start_percent": lane, "end_side": Side.BOTTOM, "end_percent": lane, "speed": 20})


## Full-color ships use their normal spawn patterns, so they keep all their
## behavior: the bee's dive and loop, the hive's stop-shake-fire, the
## flower's swaying fall and laser.
func _drop_colored_ship(kind: int, lane: float) -> void:
	match kind:
		ShipKind.BEE:
			spawn_solo_wave({"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": lane, "end_side": Side.BOTTOM, "end_percent": lane})
		ShipKind.HIVE:
			spawn_hive_wave({"enemy": ENEMY_HIVE, "start_side": Side.TOP, "start_percent": lane, "end_side": Side.BOTTOM, "end_percent": lane})
		ShipKind.FLOWER:
			spawn_flower_wave({"enemy": FLOWER, "start_percent": lane})
