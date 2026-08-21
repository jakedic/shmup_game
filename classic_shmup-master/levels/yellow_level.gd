# yellow_level.gd
# "Yellow Level" - the new first level of a run (see game_progress.gd's
# START_ID override), built to show off the squad-based yellow enemy
# behavior (see enemies/yellow_squad.gd) instead of the old grid-drop spawn.
#
# HOW THIS LEVEL WORKS: each wave sends down one or more "squads" - groups
# of 4 enemies that fly in and attack together as a team (dive down, loop,
# then either circle overhead or fly off, depending on the wave). The very
# last wave is different: instead of a squad, it spawns the end-of-level
# miniboss (see enemies/yellow_miniboss.gd).
#
# ============================================================================
# WANT TO CHANGE WHAT SPAWNS IN EACH WAVE? Scroll down to the WAVES table
# below - that's the only part of this file you should need to touch. Add,
# remove, or edit wave entries there and the level picks it up automatically
# (it even figures out how many waves there are on its own). Everything
# under "LEVEL MACHINERY" runs the fights but doesn't need editing just to
# change what enemies show up or where.
# ============================================================================
extends BaseLevel

# ---------------------------------------------------------------------------
# ENEMIES - the enemy scenes available to use in WAVES below. To add a new
# enemy type to this level, preload its scene here with a friendly name,
# then use that name in a squad entry in WAVES.
# ---------------------------------------------------------------------------
const ENEMY_YELLOW := preload("res://enemies/enemy_yellow.tscn")

# ---------------------------------------------------------------------------
# LANES - where on screen a squad flies down, as a fraction of the screen's
# width. LANE_LEFT/CENTER/RIGHT cover the common spots; you can also use any
# number from 0.0 (far left edge) to 1.0 (far right edge) for a custom spot.
# ---------------------------------------------------------------------------
const LANE_LEFT := 0.25
const LANE_CENTER := 0.5
const LANE_RIGHT := 0.75

# ---------------------------------------------------------------------------
# DRIFT - whether a squad drifts sideways while it dives in, instead of
# flying straight down.
# ---------------------------------------------------------------------------
const NO_DRIFT := 0.0
const DRIFT_LEFT := -35.0
const DRIFT_RIGHT := 35.0

# ---------------------------------------------------------------------------
# WAVES - the level's actual layout. One entry per wave, played top to
# bottom, in order. Every entry is a { } block - either a squads list or a
# boss marker, as shown below.
#
# A normal wave looks like this:
#
#     {"squads": [
#         {"enemy": ENEMY_YELLOW, "lane": LANE_CENTER, "delay": 0.0, "drift": NO_DRIFT},
#     ]}
#
# "squads" is a list of squads - each squad is a set of 4 enemies that fly
# down together:
#
#   enemy  - which enemy flies in this squad (see ENEMIES above)
#   lane   - where it flies down (see LANES above)
#   delay  - seconds to wait before THIS squad starts. Use this so squads in
#            the same wave don't all start at once - try steps like 0.0,
#            1.5, 3.0 so they enter one after another.
#   drift  - sideways drift while diving in (see DRIFT above)
#
# A wave with more than one squad listed sends them all down in the same
# wave (staggered by their own "delay"), so the player faces multiple
# squads at once.
#
# The FINAL wave in this list is always the boss fight - write
# {"boss": true} instead of a squads list for it, exactly like wave 4 below.
# Don't put {"boss": true} anywhere except the very last wave.
# ---------------------------------------------------------------------------
const WAVES: Array = [
	# Wave 1 - a single squad, straight down the middle.
	{"squads": [
		{"enemy": ENEMY_YELLOW, "lane": LANE_CENTER, "delay": 0.0, "drift": NO_DRIFT},
	]},
	# Wave 2 - two squads, one from the left, one from the right.
	{"squads": [
		{"enemy": ENEMY_YELLOW, "lane": LANE_LEFT, "delay": 0.0, "drift": NO_DRIFT},
		{"enemy": ENEMY_YELLOW, "lane": LANE_RIGHT, "delay": 1.5, "drift": NO_DRIFT},
	]},
	# Wave 3 - three squads, each drifting diagonally as they dive.
	{"squads": [
		{"enemy": ENEMY_YELLOW, "lane": LANE_LEFT, "delay": 0.0, "drift": DRIFT_RIGHT},
		{"enemy": ENEMY_YELLOW, "lane": LANE_CENTER, "delay": 1.5, "drift": DRIFT_LEFT},
		{"enemy": ENEMY_YELLOW, "lane": LANE_RIGHT, "delay": 3.0, "drift": DRIFT_RIGHT},
	]},
	# Wave 4 - the end-of-level miniboss (see enemies/yellow_miniboss.gd).
	{"boss": true},
]


# ============================================================================
# LEVEL MACHINERY - reads the WAVES table above and runs the fights. You
# shouldn't need to touch anything below this line just to change what
# spawns in a wave.
# ============================================================================

# Seconds between the boss's two "add" squads starting their dive when it
# retreats offscreen mid-fight (see _on_miniboss_retreat_started() below) -
# kept separate from WAVES since these squads belong to the boss fight, not
# a numbered wave.
const BOSS_ADD_STAGGER_DELAY := 1.5

var yellow_miniboss_scene = preload("res://enemies/yellow_miniboss.tscn")


func _ready():
	enemy_scenes = [ENEMY_YELLOW]
	level_paths = {
		"next_level": "res://levels/level_1.tscn"
	}
	max_waves = WAVES.size()  # stays correct automatically if you add/remove waves above

	# Call parent _ready after setting up level-specific data
	super._ready()


# Override the default grid-drop spawn pattern - called once per wave by
# base_level.gd (via new_game() for wave 1, then handle_wave_completion() for
# each wave after), with current_wave already set to this wave's index
# (0-based) by the time it's called. Just reads that wave straight out of
# WAVES above.
func spawn_enemies() -> void:
	if current_wave >= WAVES.size():
		# Shouldn't happen - max_waves is set from WAVES.size() above - but
		# fall back to a single center squad rather than spawning nothing.
		push_error("Yellow Level: wave %d has no entry in WAVES!" % current_wave)
		_spawn_wave_squad({"enemy": ENEMY_YELLOW, "lane": LANE_CENTER, "delay": 0.0, "drift": NO_DRIFT})
		return

	var wave_data: Dictionary = WAVES[current_wave]

	if wave_data.get("boss", false):
		_spawn_miniboss()
		return

	for squad_data in wave_data.get("squads", []):
		_spawn_wave_squad(squad_data)


func _spawn_wave_squad(squad_data: Dictionary) -> YellowSquad:
	"""Turn one squad entry from WAVES into an actual squad in the level, via
	BaseLevel.spawn_squad() (shared with any other level that wants
	squad-based enemies)."""
	var screen_w: float = get_viewport_rect().size.x
	var lane_fraction: float = squad_data.get("lane", LANE_CENTER)
	var lane_x: float = screen_w * lane_fraction
	return spawn_squad(
		squad_data.get("enemy", ENEMY_YELLOW),
		lane_x,
		squad_data.get("delay", 0.0),
		squad_data.get("drift", NO_DRIFT),
	)


func _spawn_miniboss() -> void:
	# spawn_boss() (BaseLevel) hands back a plain Node since it works for any
	# boss scene - cast to the concrete type here so retreat_started below is
	# a normal, statically-typed signal connection rather than a dynamic one.
	var screen_w: float = get_viewport_rect().size.x
	var boss := spawn_boss(yellow_miniboss_scene, Vector2(screen_w / 2.0, 90.0)) as YellowMiniboss
	if boss:
		boss.retreat_started.connect(_on_miniboss_retreat_started)


# Fires each time the miniboss crosses a retreat health threshold (see
# yellow_miniboss.gd's custom_take_damage()/retreat_started) and goes
# invincible/offscreen. Spawns two squads as "adds" - the SAME squad
# behavior the normal waves above use, just not listed in WAVES since
# they're tied to the boss fight rather than a numbered wave. Once every add
# is dead, BaseLevel.resolve_boss_add_death() (wired up below) automatically
# calls resume_after_adds() on the boss so it comes back down.
func _on_miniboss_retreat_started() -> void:
	var screen_w: float = get_viewport_rect().size.x
	var left_squad := spawn_squad(ENEMY_YELLOW, screen_w * LANE_LEFT, 0.0, DRIFT_RIGHT)
	var right_squad := spawn_squad(ENEMY_YELLOW, screen_w * LANE_RIGHT, BOSS_ADD_STAGGER_DELAY,DRIFT_LEFT)
	start_boss_add_wave(YellowSquad.SQUAD_SIZE * 2)
	left_squad.enemy_died.connect(resolve_boss_add_death)
	right_squad.enemy_died.connect(resolve_boss_add_death)
