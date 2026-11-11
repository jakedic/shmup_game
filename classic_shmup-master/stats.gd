# stats.gd
# Autoload this as "Stats" (Project Settings -> Autoload).
#
# Layered stat system:
#   default_stats          -> immutable baseline, never written to at runtime
#   progression_overrides  -> permanent deltas earned across levels/sessions
#   run_modifiers          -> named, stackable changes that persist across
#                              every level for the rest of the current
#                              overworld run (the power-ups the player
#                              specifically CHOSE to keep at the end of a
#                              level - see choose_run_powerup() /
#                              powerup_choice_popup.gd). Cleared with
#                              clear_run_modifiers() whenever a run starts or
#                              resets (see GameProgress.start_new_run() /
#                              reset_run()) - i.e. they go away on a loss.
#   leveled power-ups       -> power-ups with LEVELS (see "POWER-UP LEVELS"
#                              in player/player_powerups.gd). Not stacked
#                              copies: each id has a level, and only that
#                              level's stats apply. Level = run levels +
#                              this level's pickups, capped at the max. See
#                              get_powerup_level() / add_leveled_powerup().
#   level_modifiers         -> named, stackable changes that persist for the
#                              current level only (every power-up earned this
#                              level, whether or not it's later chosen to
#                              carry forward). Cleared with
#                              clear_level_modifiers() whenever a level starts
#                              (see BaseLevel.new_game()).
#   active_modifiers        -> named, stackable, TEMPORARY changes (absorb/transform)
#   current_stats           -> resolved cache that gameplay code actually reads
#
# current = default, then progression, then run modifiers, then leveled
# power-ups, then level modifiers, then each active modifier, applied in the order each was added.
# Removing a modifier just erases its entry and recomputes — no manual "undo
# the math" step required anywhere.
extends Node

signal stats_changed(category: String)
signal powerup_collected(powerup_id: String)
signal currency_changed(new_amount: int)
# Fired whenever any leveled power-up's level changes (gained, or cleared at
# the start of a level/run). The side-panel power-up list listens to this.
signal powerup_levels_changed

const CATEGORIES = ["player", "bullet", "bubble", "pollen", "pollen_puff"]

# ===== TIER 1: DEFAULT =====
# Never mutate this dictionary at runtime. If you want to tweak a base value,
# change it here — everything downstream recomputes automatically.
var default_stats: Dictionary = {
	"player": {
		"speed": 150.0,
		"acceleration": 10.0,
		"deceleration": 10.0,
		"max_shield": 20,
		"shield_regen_rate": 0.0,
		"shield_regen_delay": 3.0,
		"shoot_cooldown": 0.25,
		"absorb_cooldown": 2.0,
		# Dash is a "jump" (ship scales up then down - see
		# PlayerMovement._start_jump()). While airborne the ship passes
		# over enemy bullets and enemy ships (see start_dash() /
		# PlayerHealth.is_invincible()). Distance travelled is roughly
		# dash_speed x dash_duration (100 x 0.8 = ~80px, on a 240x320
		# screen) - lower dash_speed for a shorter hop.
		"dash_speed": 100.0,
		"dash_duration": 0.8,
		# Seconds after landing before the player can jump again (the side
		# panel's Jump meter shows this refilling).
		"dash_cooldown": 1.5,
		# Seconds the ship stays frozen in place right after landing a jump
		# (see PlayerMovement._begin_landing_pause()). 0 = no pause.
		"landing_pause_duration": 0.25,
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
		# How long (seconds) the player keeps dash_invincible's damage
		# immunity to BOTH enemy bullets and enemy ships after the dash
		# itself ends - see PlayerMovement.on_dash_end() /
		# PlayerHealth.is_invincible(). 0 = no lingering grace period, the
		# default (immunity ends the instant the dash does). Only meaningful
		# alongside dash_invincible = true.
		"post_dash_invincibility_duration": 0.0,
		# Invulnerability power-ups (yellow pool, see player_powerups.gd).
		# All use PlayerHealth.grant_intangible() (blue blink, no damage):
		#   landing_invincibility       - Safe Landing: seconds after a jump lands
		#   bubble_bounce_invincibility - Bubble Guard: seconds after a bubble
		#                                 paddle-bounces off the ship
		# 0 = power-up not owned.
		"landing_invincibility": 0.0,
		"bubble_bounce_invincibility": 0.0,
		# Seconds of blinking invulnerability after taking a hit
		# (PlayerHealth.start_hit_invincibility()). Raised by Second Wind.
		"hit_invincibility_duration": 1.0,
		# Stinger power-up (player/player_stinger.gd): sting enemies you touch
		# while invulnerable, jump cooldown pauses meanwhile, and every
		# invulnerability lasts invincibility_mult x as long (2 / 2.5 / 3).
		"has_stinger": false,
		"invincibility_mult": 1.0,
		# yellow power-up: secondary "pollen shot" fire (see
		# player/player_powerups.gd + player/player_pollen_shot.gd) - off
		# unless granted by a power bubble this level.
		"has_pollen_shot": false,
		# Damage the dash-jump landing shockwave deals to each enemy it
		# touches (player/landing_shockwave.gd), and how far it reaches in
		# play-area px. Raised by the gray Heavy Landing / Wide Impact
		# power-ups.
		"jump_damage": 3.0,
		"jump_shockwave_radius": 30.0,
		# Flat damage taken off every hit the player takes (gray Plating
		# power-up). A hit always does at least PlayerHealth.ARMOR_MIN_DAMAGE.
		"armor": 0,
		# Multiplier on the score each kill is worth (on top of the score
		# multiplier). Raised by the gray Bounty Hunter power-up.
		"kill_score_mult": 1.0,
	},
	"bullet": {
		"speed": 250.0,
		"damage": 1,
		"pierce_count": 0,
		"can_pierce": false,
		# gray_penetration power-up: how many enemies the main shot passes
		# through even when they survive the hit (see bullets/bullet.gd).
		"penetration_count": 0,
		"max_distance": 125.0,
		"homing_enabled": false,
		"homing_strength": 1.2,   # max turn rate, radians/second (see bullets/bullet.gd update_homing())
		# Status-effect infliction for the player's PRIMARY shot (see
		# bullets/bullet.gd - same generic status_effect_name/status_effect_chance
		# plumbing the pollen shot uses). Empty/0 by default - normal bullets
		# don't inflict anything unless a power-up sets these.
		"status_effect_name": "",
		"status_effect_chance": 0.0,
		# If true, a bullet won't try to inflict its status effect on the
		# very first enemy it hits - only on enemies hit afterward via
		# piercing.
		"status_effect_skip_first_hit": false,
		# Cross-Pollination power-up (see yellow_piercing_pollen in
		# player/player_powerups.gd): once this bullet hits its first enemy
		# this level, release a cone-shaped burst of pollen that continues on
		# past that enemy. Each other enemy caught in the cone independently
		# rolls pollen_cone_chance to become pollinated (see bullets/bullet.gd
		# _release_pollen_cone()). Off by default - only pollen_cone_enabled
		# turns this on.
		"pollen_cone_enabled": false,
		"pollen_cone_chance": 0.0,
		"pollen_cone_range": 60.0,
		"pollen_cone_angle_degrees": 70.0,
	},
	"bubble": {
		"speed": 70.0,   # was 100 (-30%)
		"damage": 1,
		"travel_distance": 50.0,
		"lifetime": 3600.0,  # 1 hour - effectively never times out; bubbles only pop when shot
		"hit_points": 3,
		# If true, popping a power bubble (player bullet hits it) no longer
		# damages enemies caught in the pop explosion - it guarantees the
		# "pollinated" status on all of them instead. See bullets/bubble.gd
		# create_pop_damage() and the yellow_bubble_pollen_pop power-up.
		"pop_applies_pollination": false,
		# If true, the bubble shot launches from behind the player instead of
		# in front of them - see the gray_bubble_behind power-up and
		# player_absorption.gd's launch_bubble().
		"launch_behind": false,
		# Damage a charged bubble (blue outline - landing-shockwave or shot
		# charged) deals to each enemy it passes through. Was the constant
		# SHOCKWAVE_CHARGE_DAMAGE in bubble.gd; raised by gray Charged Shell.
		"charged_damage": 1.0,
		# Multiplier on the explosion when you jump on a bubble and pop it
		# (bubble.gd JUMP_POP_DAMAGE_MULT x bubble damage = 5 normally).
		# Raised by gray Pop Blast.
		"jump_pop_damage_mult": 1.0,
		# Most shot charges a bubble can hold (each bullet that hits it adds
		# one - see bubble.gd on_shockwave_hit()). Raised by the gray
		# Capacitor power-up. Was the constant SHOT_CHARGE_MAX.
		"shot_charge_max": 3,
	},
	# Weak, slow, wiggling secondary-fire bullets fired in pairs from the
	# left/right of the ship while "has_pollen_shot" is active (see
	# player/player_pollen_shot.gd). Completely independent of the "bullet"
	# category used for the player's normal shot.
	"pollen": {
		"speed": 90.0,
		"damage": 0.1,            # per ball, averaged (1 ball in 10 does 1) - see PlayerPollenShot._spawn_one()
		"cooldown": 0.5,          # seconds between pairs (was 0.35 - lowered fire rate 2026-11-11)
		"max_distance": 220.0,
		"wiggle_amplitude": 10.0,   # how far side-to-side it drifts, in px
		"wiggle_frequency": 6.0,    # how fast it wiggles, in radians/sec
		# Chance (0.0-1.0) per enemy hit to inflict the "pollinated" status
		# effect (see status_effects/pollinated_status.gd).
		"status_effect_chance": 0.2,
		# Unused since the 2026-11-11 pollination rework (pollinated
		# enemies no longer explode on death, and the Blast Radius power-up
		# that raised this was removed).
		"chain_explosion_radius": 40.0,
		# Pollen residue power-ups (see status_effects/pollen_residue.gd).
		# 0 = power-up not owned; otherwise a multiplier on how long the
		# residue lasts (1 / 1.25 / 1.5 at levels 1 / 2 / 3).
		#   trail_duration_mult    - Pollen Trail (player/player_pollen_trail.gd)
		#   jump_pop_residue_mult  - Pollen Pop (bubble.gd create_pop_damage())
		#   jump_residue_mult      - Pollen Leap (player_movement.gd - residue
		#                            at jump takeoff + landing, radius = the
		#                            jump shockwave radius)
		"trail_duration_mult": 0.0,
		"jump_pop_residue_mult": 0.0,
		"jump_residue_mult": 0.0,
		# Pollination bounce (status_effects/pollinated_status.gd):
		#   bounce_radius_mult - multiplier on the bounce search radius
		#                        (normally 50% of the bubble pop radius).
		#                        Raised by the Wide Bloom power-up.
		#   extra_bounce_shots - how many ADDITIONAL shots fly out to other
		#                        enemies in range when a bounce happens.
		#                        Raised by the Pollen Split power-up.
		"bounce_radius_mult": 1.0,
		"extra_bounce_shots": 0,
	},
	# Larger, slow "pollen puff" fired straight from the ship when the
	# player releases the yellow form's charge shot BEFORE it's fully
	# charged (see player/player_charge_shot.gd - _fire_pollen_puff()).
	# Completely independent of "bullet" (the fully-charged shot) and
	# "pollen" (the wiggling secondary-fire power-up balls) - a
	# consolation prize for an early release, not a weaker version of
	# either of those.
	"pollen_puff": {
		"speed": 45.0,          # slow - about half of the secondary pollen shot's speed
		"damage": 0,            # never deals damage, purely a pollination tool
		"max_distance": 260.0,
		"pulse_amplitude": 0.25,  # how much it swells/shrinks, as a fraction of base size
		"pulse_frequency": 3.0,   # how fast it pulses, in radians/sec
		# 100% chance to inflict "pollinated" (see
		# status_effects/pollinated_status.gd) - unlike the 20% chance on
		# the wiggling secondary-fire pollen balls, this always lands.
		"status_effect_chance": 1.0,
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
	"pollen_puff": {},
}

# ===== TIER 3: RUN MODIFIERS (persist across every level for the rest of the run, stackable, named) =====
# Same shape as level_modifiers below, but these survive scene changes
# between levels - they're the power-ups the player specifically chose to
# keep (see choose_run_powerup()). Cleared via clear_run_modifiers() when
# GameProgress starts or resets a run (fresh Start press, or a loss).
# mod_name -> { category -> { stat_key -> {"op": "set"|"add"|"mult", "value": x} } }
var run_modifiers: Dictionary = {}

# IDs of every power-up the player has chosen to carry forward this run, in
# the order chosen. Handy for UI/debugging; choose_run_powerup() keeps this
# in sync with run_modifiers.
var chosen_run_powerups: Array = []

# ===== CURRENCY (same lifetime as run_modifiers - persists across every =====
# ===== level for the rest of the run, wiped on a loss/fresh run)        =====
# Earned from level score (see BaseLevel.change_levels() -> Stats.add_currency())
# and spent at the overworld shop (see levels/shop.gd) at a flat cost per
# ability. Cleared via clear_currency() alongside clear_run_modifiers()
# whenever GameProgress starts or resets a run.
var currency: int = 0

func add_currency(amount: int) -> void:
	if amount <= 0:
		return
	currency += amount
	currency_changed.emit(currency)

func spend_currency(amount: int) -> bool:
	"""Attempts to spend `amount` currency. Returns false (and spends
	nothing) if the player can't afford it."""
	if amount <= 0 or currency < amount:
		return false
	currency -= amount
	currency_changed.emit(currency)
	return true

func clear_currency() -> void:
	currency = 0
	currency_changed.emit(currency)

# ===== LEVELED POWER-UPS (see player/player_powerups.gd "POWER-UP LEVELS") =====
# power-up id -> how many levels the player keeps for the RUN (end-of-level
# choice, shop, Test menu). Wiped by clear_run_modifiers().
var leveled_run_levels: Dictionary = {}
# power-up id -> how many levels the player picked up THIS LEVEL (power
# bubbles, the test pause menu). Wiped by clear_level_modifiers().
var leveled_level_levels: Dictionary = {}


func get_run_powerup_level(powerup_id: String) -> int:
	"""Levels of this power-up kept for the run (ignores this level's
	pickups), capped at its max level."""
	return mini(int(leveled_run_levels.get(powerup_id, 0)), PlayerPowerUps.get_max_level_for_id(powerup_id))


func get_powerup_level(powerup_id: String) -> int:
	"""The level of this power-up that's active right now: run levels plus
	this level's pickups, capped at its max level. 0 = don't have it."""
	var total := int(leveled_run_levels.get(powerup_id, 0)) + int(leveled_level_levels.get(powerup_id, 0))
	return mini(total, PlayerPowerUps.get_max_level_for_id(powerup_id))


func add_leveled_powerup(powerup_id: String, for_run: bool) -> void:
	"""Raise a leveled power-up by one level - for the rest of the run
	(for_run = true) or just this level. Use PlayerPowerUps.grant_for_run()
	/ grant_for_level() rather than calling this directly.

	A this-level pickup also logs the id in collected_powerups (so it's
	offered at the end of the level) and emits powerup_collected (which pops
	up the info screen) - even when already at max level, so the player
	still sees "MAX"."""
	var max_level := PlayerPowerUps.get_max_level_for_id(powerup_id)
	if for_run:
		leveled_run_levels[powerup_id] = mini(int(leveled_run_levels.get(powerup_id, 0)) + 1, max_level)
		chosen_run_powerups.append(powerup_id)
	else:
		if get_powerup_level(powerup_id) < max_level:
			leveled_level_levels[powerup_id] = int(leveled_level_levels.get(powerup_id, 0)) + 1
			collected_powerups.append(powerup_id)
	recompute_all()
	powerup_levels_changed.emit()
	if not for_run:
		powerup_collected.emit(powerup_id)


func set_leveled_powerup_level(powerup_id: String, level: int) -> void:
	"""TEST TOOL (the pause menu's Test: Power-ups picker): put a leveled
	power-up at exactly `level` (1..max) right now, up or down, instead of
	+1. Uses this level's pickups to make up the difference over the run
	level (lowering the run level if it's above `level`). Pops up the info
	screen like a normal pickup. Use PlayerPowerUps.set_level_for_test()."""
	var max_level := PlayerPowerUps.get_max_level_for_id(powerup_id)
	level = clampi(level, 1, max_level)
	var run_level := int(leveled_run_levels.get(powerup_id, 0))
	if run_level > level:
		leveled_run_levels[powerup_id] = level
		run_level = level
	leveled_level_levels[powerup_id] = level - run_level
	if not collected_powerups.has(powerup_id):
		collected_powerups.append(powerup_id)
	recompute_all()
	powerup_levels_changed.emit()
	powerup_collected.emit(powerup_id)


func remove_powerup_completely(powerup_id: String) -> void:
	"""TEST TOOL (Test: Power-ups picker, SET = NONE / REMOVE): take a
	power-up away entirely - its level (run and this level) for leveled
	power-ups, every stacked copy (run and this level) for plain ones. Use
	PlayerPowerUps.remove_for_test()."""
	leveled_run_levels.erase(powerup_id)
	leveled_level_levels.erase(powerup_id)
	for mod_name in level_modifiers.keys():
		if String(mod_name).begins_with("powerup_%s_" % powerup_id):
			level_modifiers.erase(mod_name)
	for mod_name in run_modifiers.keys():
		if String(mod_name).begins_with("run_powerup_%s_" % powerup_id):
			run_modifiers.erase(mod_name)
	while collected_powerups.has(powerup_id):
		collected_powerups.erase(powerup_id)
	while chosen_run_powerups.has(powerup_id):
		chosen_run_powerups.erase(powerup_id)
	recompute_all()
	powerup_levels_changed.emit()


func count_powerup_copies(powerup_id: String) -> int:
	"""How many stacked copies of a plain (non-leveled) power-up the player
	has right now, run + this level. Used by the test picker's HAVE column."""
	var n := 0
	for mod_name in level_modifiers:
		if String(mod_name).begins_with("powerup_%s_" % powerup_id):
			n += 1
	for mod_name in run_modifiers:
		if String(mod_name).begins_with("run_powerup_%s_" % powerup_id):
			n += 1
	return n


func _apply_leveled_powerups(category: String, result: Dictionary) -> void:
	var ids := {}
	for id in leveled_run_levels:
		ids[id] = true
	for id in leveled_level_levels:
		ids[id] = true
	for id in ids:
		var level_stats: Dictionary = PlayerPowerUps.get_level_stats(id, get_powerup_level(id))
		var mods: Dictionary = level_stats.get(category, {})
		for key in mods:
			result[key] = _apply_op(result.get(key), mods[key])


# ===== TIER 4: LEVEL MODIFIERS (persist for the current level, stackable, named) =====
# Same shape as active_modifiers below, but these are NOT tied to a
# transformation's lifetime - they stick around (e.g. power-bubble power-ups)
# until clear_level_modifiers() is called at the start of a new level/run.
# mod_name -> { category -> { stat_key -> {"op": "set"|"add"|"mult", "value": x} } }
var level_modifiers: Dictionary = {}

# IDs of power-ups collected so far this level, in collection order. Handy
# for UI or debugging; add_powerup() keeps this in sync with level_modifiers.
var collected_powerups: Array = []

# ===== TIER 5: MODIFIERS (temporary, stackable, named) =====
# mod_name -> { category -> { stat_key -> {"op": "set"|"add"|"mult", "value": x} } }
var active_modifiers: Dictionary = {}

# ===== TIER 6: CURRENT (resolved cache) =====
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

	# Run modifiers (power-ups chosen at the end of a previous level, kept
	# for the rest of this run) apply next, so they act as this run's
	# baseline before anything from the current level layers on top.
	for mod_name in run_modifiers:
		var run_mods: Dictionary = run_modifiers[mod_name].get(category, {})
		for key in run_mods:
			result[key] = _apply_op(result.get(key), run_mods[key])

	# Leveled power-ups (one entry per id at its current level) next.
	_apply_leveled_powerups(category, result)

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


# ---------- Run modifiers (persist across levels for the rest of the run, e.g. a chosen power-up) ----------

func add_run_modifier(mod_name: String, modifiers: Dictionary):
	run_modifiers[mod_name] = modifiers
	for category in modifiers:
		recompute(category)

func remove_run_modifier(mod_name: String):
	if not run_modifiers.has(mod_name):
		return
	var affected_categories = run_modifiers[mod_name].keys()
	run_modifiers.erase(mod_name)
	for category in affected_categories:
		recompute(category)

func has_run_modifier(mod_name: String) -> bool:
	return run_modifiers.has(mod_name)

func clear_run_modifiers():
	"""Call whenever a run starts or resets (see GameProgress.start_new_run()
	/ reset_run()) so power-ups chosen in a previous run don't carry over -
	losing a run should wipe these out, unlike level_modifiers which reset
	on every single level regardless of win/loss."""
	var affected_categories = {}
	for mod_name in run_modifiers:
		for category in run_modifiers[mod_name]:
			affected_categories[category] = true
	run_modifiers.clear()
	chosen_run_powerups.clear()
	var had_leveled := not leveled_run_levels.is_empty()
	leveled_run_levels.clear()
	if had_leveled:
		recompute_all()
		powerup_levels_changed.emit()
	else:
		for category in affected_categories:
			recompute(category)

func choose_run_powerup(powerup_id: String, modifiers: Dictionary):
	"""Called when the player picks a power-up (from PowerupChoicePopup, at
	the end of a level) to carry forward for the rest of the run. Adds it as
	a run modifier - separate from level_modifiers, which resets every
	single level regardless of what's chosen."""
	var unique_mod_name = "run_powerup_%s_%d" % [powerup_id, chosen_run_powerups.size()]
	chosen_run_powerups.append(powerup_id)
	add_run_modifier(unique_mod_name, modifiers)


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
	var had_leveled := not leveled_level_levels.is_empty()
	leveled_level_levels.clear()
	if had_leveled:
		recompute_all()
		powerup_levels_changed.emit()
	else:
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
