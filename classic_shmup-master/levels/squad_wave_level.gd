# squad_wave_level.gd
# Shared machinery for any level built as a numbered list of waves, each wave
# sending down one or more squads of enemies (see enemies/yellow_squad.gd),
# with a boss fight as the final wave. levels/yellow_level.gd and
# levels/dylan_level.gd are both built on this - their own files only need to
# say WHAT spawns in each wave, not HOW waves get run.
#
# HOW TO BUILD A LEVEL ON TOP OF THIS: in the subclass's own _ready(), set
# `waves`, `boss_scene`, and `fallback_enemy` (see the var declarations
# below), then call super._ready(). Everything else - spawning each wave,
# running the boss fight, spawning "add" squads while the boss is retreated -
# is handled here, once, instead of being copy-pasted into every level.
#
# THE WAVES FORMAT: `waves` is an Array, one entry per wave, played top to
# bottom. Each entry is a Dictionary - either a list of squads, or the boss
# marker:
#
#     {"squads": [
#         {"enemy": SOME_ENEMY_SCENE, "lane": LANE_CENTER, "start_delay": 0.0, "drift": NO_DRIFT},
#     ]}
#
#     {"is_boss_wave": true}   # only ever the LAST entry in `waves`
#
# Each entry in a "squads" list is one squad, described by:
#   enemy       - which enemy scene fills this squad's ranks
#   lane        - where on screen it flies down, as a fraction of screen
#                 width (see LANE_LEFT/LANE_CENTER/LANE_RIGHT below, or any
#                 number from 0.0 = far left edge to 1.0 = far right edge)
#   start_delay - seconds to wait before THIS squad starts its dive, so
#                 squads in the same wave stagger their entrances (try
#                 0.0, 1.5, 3.0, ...) instead of all diving at once
#   drift       - sideways drift while diving in (see NO_DRIFT/DRIFT_LEFT/
#                 DRIFT_RIGHT below, or any px/s value; 0 stays vertical)
#   squad_size  - OPTIONAL - how many enemies fly in this squad. Leave it
#                 out to get DEFAULT_SQUAD_SIZE.
#
# A wave with more than one squad sends them all down in the same wave
# (staggered by each squad's own start_delay), so the player faces multiple
# squads at once.
class_name SquadWaveLevel
extends BaseLevel

# ---------------------------------------------------------------------------
# LANES - where on screen a squad flies down, as a fraction of the screen's
# width. LANE_LEFT/CENTER/RIGHT cover the common spots; any number from 0.0
# (far left edge) to 1.0 (far right edge) also works for a custom spot.
# ---------------------------------------------------------------------------
const LANE_LEFT := 0.25
const LANE_CENTER := 0.5
const LANE_RIGHT := 0.75

# ---------------------------------------------------------------------------
# DRIFT - sideways drift, in px/s, while a squad dives in, instead of flying
# straight down.
# ---------------------------------------------------------------------------
const NO_DRIFT := 0.0
const DRIFT_LEFT := -35.0
const DRIFT_RIGHT := 35.0

# How many enemies fly in a squad when its wave entry doesn't say otherwise
# (see the `squad_size` field in the WAVES FORMAT comment above).
const DEFAULT_SQUAD_SIZE := 4

# Seconds between the boss's two "add" squads starting their dive when it
# retreats offscreen mid-fight (see _on_boss_retreat_started()) - kept
# separate from `waves` since these squads belong to the boss fight, not a
# numbered wave.
const BOSS_ADD_STAGGER_DELAY := 1.5

# ---- Subclass configuration - set these in _ready(), before calling super._ready() ----
var waves: Array = []             # this level's wave list - see the WAVES FORMAT comment above
var boss_scene: PackedScene       # spawned for the {"is_boss_wave": true} entry
var fallback_enemy: PackedScene   # used if a wave is missing, and for the boss's "add" squads


func _ready() -> void:
	max_waves = waves.size()  # stays correct automatically if you add/remove waves
	super._ready()


# Called once per wave by base_level.gd (via new_game() for wave 1, then
# handle_wave_completion() for each wave after), with current_wave already
# set to this wave's index (0-based) by the time it's called.
func spawn_enemies() -> void:
	if current_wave >= waves.size():
		# Shouldn't happen - max_waves is set from waves.size() above - but
		# fall back to a single center squad rather than spawning nothing.
		push_error("%s: wave %d has no entry in `waves`!" % [scene_file_path, current_wave])
		_spawn_squad_for_wave_entry({"enemy": fallback_enemy, "lane": LANE_CENTER})
		return

	var wave_entry: Dictionary = waves[current_wave]
	if wave_entry.get("is_boss_wave", false):
		_spawn_boss_wave()
		return

	for squad_entry in wave_entry.get("squads", []):
		_spawn_squad_for_wave_entry(squad_entry)


func _spawn_squad_for_wave_entry(squad_entry: Dictionary) -> YellowSquad:
	"""Turn one squad entry from `waves` into an actual squad in the level,
	via BaseLevel.spawn_squad() (shared with any other level that wants
	squad-based enemies)."""
	var screen_width: float = get_viewport_rect().size.x
	var lane_fraction: float = squad_entry.get("lane", LANE_CENTER)
	var lane_x: float = screen_width * lane_fraction
	return spawn_squad(
		squad_entry.get("enemy", fallback_enemy),
		lane_x,
		squad_entry.get("start_delay", 0.0),
		squad_entry.get("drift", NO_DRIFT),
		Vector2.ZERO,
		squad_entry.get("squad_size", DEFAULT_SQUAD_SIZE),
	)


func _spawn_boss_wave() -> void:
	# spawn_boss() (BaseLevel) hands back a plain Node since it works for any
	# boss scene - only connect retreat_started if this particular boss
	# actually has it, so this stays usable for a boss scene that doesn't.
	var screen_width: float = get_viewport_rect().size.x
	var boss := spawn_boss(boss_scene, Vector2(screen_width / 2.0, 90.0))
	if boss and boss.has_signal("retreat_started"):
		boss.retreat_started.connect(_on_boss_retreat_started)


# Fires each time the boss crosses a retreat health threshold (see
# yellow_miniboss.gd's custom_take_damage()/retreat_started) and goes
# invincible/offscreen. Spawns two squads as "adds" - the SAME squad
# behavior the normal waves above use, just not listed in `waves` since
# they're tied to the boss fight rather than a numbered wave. Once every add
# is dead, BaseLevel.resolve_boss_add_death() (wired up below) automatically
# calls resume_after_adds() on the boss so it comes back down.
func _on_boss_retreat_started() -> void:
	var screen_width: float = get_viewport_rect().size.x
	var left_squad := spawn_squad(fallback_enemy, screen_width * LANE_LEFT, 0.0, DRIFT_RIGHT)
	var right_squad := spawn_squad(fallback_enemy, screen_width * LANE_RIGHT, BOSS_ADD_STAGGER_DELAY, DRIFT_LEFT)
	start_boss_add_wave(left_squad.squad_size + right_squad.squad_size)
	left_squad.enemy_died.connect(resolve_boss_add_death)
	right_squad.enemy_died.connect(resolve_boss_add_death)
