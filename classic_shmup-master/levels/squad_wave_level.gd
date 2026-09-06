# squad_wave_level.gd
# Shared machinery for any level built as a numbered list of waves, each wave
# sending down one or more squads and/or solo enemies (see
# enemies/yellow_squad.gd and enemies/yellow_solo.gd), with a boss fight as
# the final wave. levels/yellow_level.gd and levels/dylan_level.gd are both
# built on this - their own files only need to say WHAT spawns in each wave,
# not HOW waves get run.
#
# HOW TO BUILD A LEVEL ON TOP OF THIS: in the subclass's own _ready(), set
# `waves`, `boss_scene`, and `fallback_enemy` (see the var declarations
# below), then call super._ready(). Everything else - spawning each wave,
# running the boss fight, spawning "add" squads while the boss is retreated -
# is handled here, once, instead of being copy-pasted into every level.
#
# THE WAVES FORMAT: `waves` is an Array, one entry per wave, played top to
# bottom. Each entry is a Dictionary - a list of squads and/or solo enemies,
# or the boss marker:
#
#     {"squads": [
#         {"enemy": SOME_ENEMY_SCENE, "start_side": Side.TOP, "start_percent": LANE_CENTER, "end_side": Side.BOTTOM, "end_percent": LANE_CENTER},
#     ],
#      "solos": [
#         {"enemy": SOME_ENEMY_SCENE, "start_side": Side.LEFT, "start_percent": 0.3, "end_side": Side.RIGHT, "end_percent": 0.3},
#     ]}
#
#     {"is_boss_wave": true}   # only ever the LAST entry in `waves`
#
# Either "squads" or "solos" (or both) can be left out of a wave entry that
# doesn't need them - a solo-only wave is just {"solos": [...]}.
#
# SIDE + PERCENT: rather than picking exact screen coordinates, both squads
# and solos describe where they start and end as a screen edge (Side.LEFT/
# RIGHT/TOP/BOTTOM) plus how far along that edge (0.0-1.0). For LEFT/RIGHT,
# 0.0 is the top of that edge and 1.0 is the bottom; for TOP/BOTTOM, 0.0 is
# the left end and 1.0 is the right end. LANE_LEFT/LANE_CENTER/LANE_RIGHT
# (below) are handy percent values for the common lanes, whichever side
# they're used on. _side_point() turns a side+percent into the actual
# off-screen world position (a little past the edge, via OFFSCREEN_MARGIN,
# so nothing pops in/out right at the boundary).
#
# Each entry in a "squads" list is one squad (see enemies/yellow_squad.gd for
# the actual behavior - travels in, circles, travels away, loops), described
# by:
#   enemy           - which enemy scene fills this squad's ranks
#   start_side/
#   start_percent   - which edge the squad starts just off of, and how far
#                      along it - see SIDE + PERCENT above. Defaults to the
#                      top edge, centered.
#   end_side/
#   end_percent     - which edge a departed member is eventually removed
#                      just past, and how far along it. Defaults to the
#                      bottom edge, at the same percent as the start (so a
#                      squad that only sets start_percent falls straight down
#                      that lane, same as before this field existed).
#   circle_progress - OPTIONAL - how far along the start->end line (0.0-1.0)
#                      the squad stops to circle. Leave it out to get
#                      DEFAULT_CIRCLE_PROGRESS.
#   circle_hold_interval - OPTIONAL - how many seconds THIS squad holds its
#                      circle formation before departing. A per-squad
#                      setting (see enemies/yellow_squad.gd's own
#                      circle_hold_interval export) - leave it out to get
#                      that export's default (6.0).
#   start_delay     - seconds to wait before THIS squad starts moving, so
#                      squads in the same wave stagger their entrances (try
#                      0.0, 1.5, 3.0, ...) instead of all starting at once
#   drift           - sideways (perpendicular to the start->end line) drift a
#                      member picks up once it's traveling solo after its own
#                      departure loop (see NO_DRIFT/DRIFT_LEFT/DRIFT_RIGHT
#                      below, or any px/s value; 0 keeps it on a straight
#                      line)
#   squad_size      - OPTIONAL - how many enemies fly in this squad. Leave it
#                      out to get DEFAULT_SQUAD_SIZE.
#
# Each entry in a "solos" list is one lone enemy flying in a straight line
# from one point to another (see enemies/yellow_solo.gd - same sine-wave
# wobble and halfway loop-the-loop as a squad member, just on its own,
# typically crossing from one side of the screen to the other rather than
# traveling top to bottom), described by:
#   enemy         - which enemy scene this solo enemy is
#   start_side/
#   start_percent - which edge it starts just off of, and how far along it -
#                   see SIDE + PERCENT above. Defaults to the left edge,
#                   centered.
#   end_side/
#   end_percent   - which edge it's removed just past once it arrives, and
#                   how far along it. Defaults to the right edge, centered.
#   start_delay   - OPTIONAL - seconds to wait before this enemy starts moving,
#                   same purpose as a squad's start_delay above
#
# A wave with more than one squad and/or solo sends them all down in the same
# wave (staggered by each one's own start_delay), so the player faces
# multiple squads/solos at once.
class_name SquadWaveLevel
extends BaseLevel

# ---------------------------------------------------------------------------
# SIDE - which edge of the screen a squad/solo starts or ends just off of -
# see SIDE + PERCENT above and _side_point() below.
# ---------------------------------------------------------------------------
enum Side { LEFT, RIGHT, TOP, BOTTOM }

# How far past the screen edge a side+percent position actually sits, px -
# keeps a spawn/despawn point fully off-screen instead of right on the
# boundary. Sized generously enough to cover a squad's own formation extent:
# while a squad is parked at start_pos (see start_delay), its members are
# already spread circle_radius px away from start_pos in every direction
# (see yellow_squad.gd's _spawn_members()) - too small a margin here left
# the outer members of a parked squad visibly poking onto the screen instead
# of staying hidden until start_delay elapsed. 48px comfortably covers
# yellow_squad.gd's default circle_radius (28px) plus room for the enemy's
# own sprite (16x10px) - bump this further if a squad's circle_radius is
# ever made larger than that default.
const OFFSCREEN_MARGIN := 48.0

# ---------------------------------------------------------------------------
# LANES - common percent values along an edge (see SIDE + PERCENT above).
# Named for the classic top-to-bottom case (a squad falling down the left/
# center/right of the screen), but equally valid as a percent along any
# side. Any number from 0.0 to 1.0 also works for a custom spot.
# ---------------------------------------------------------------------------
const LANE_LEFT := 0.25
const LANE_CENTER := 0.5
const LANE_RIGHT := 0.75

# ---------------------------------------------------------------------------
# DRIFT - sideways drift, in px/s, a squad member picks up once it's
# traveling solo after its own departure loop, instead of continuing in a
# straight line.
# ---------------------------------------------------------------------------
const NO_DRIFT := 0.0
const DRIFT_LEFT := -35.0
const DRIFT_RIGHT := 35.0

# How many enemies fly in a squad when its wave entry doesn't say otherwise
# (see the `squad_size` field in the WAVES FORMAT comment above).
const DEFAULT_SQUAD_SIZE := 4

# How far along its start->end line a squad circles when its wave entry
# doesn't say otherwise (see the `circle_progress` field above).
const DEFAULT_CIRCLE_PROGRESS := 0.35

# Seconds between the boss's two "add" squads starting to move when it
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


func _side_point(side: int, percent: float) -> Vector2:
	"""Turn a Side + percent (see SIDE + PERCENT above) into an actual
	off-screen world position. The point sits OFFSCREEN_MARGIN px outside the
	screen on the given side, not right on the edge, so a squad/solo
	spawning or despawning there is already fully off-screen rather than
	popping in/out right at the boundary."""
	var size: Vector2 = get_viewport_rect().size
	match side:
		Side.LEFT:
			return Vector2(-OFFSCREEN_MARGIN, size.y * percent)
		Side.RIGHT:
			return Vector2(size.x + OFFSCREEN_MARGIN, size.y * percent)
		Side.TOP:
			return Vector2(size.x * percent, -OFFSCREEN_MARGIN)
		Side.BOTTOM:
			return Vector2(size.x * percent, size.y + OFFSCREEN_MARGIN)
		_:
			push_error("%s: _side_point() got unknown side %s" % [scene_file_path, side])
			return Vector2.ZERO


# Called once per wave by base_level.gd (via new_game() for wave 1, then
# handle_wave_completion() for each wave after), with current_wave already
# set to this wave's index (0-based) by the time it's called.
func spawn_enemies() -> void:
	if current_wave >= waves.size():
		# Shouldn't happen - max_waves is set from waves.size() above - but
		# fall back to a single center squad rather than spawning nothing.
		push_error("%s: wave %d has no entry in `waves`!" % [scene_file_path, current_wave])
		_spawn_squad_for_wave_entry({"enemy": fallback_enemy, "start_percent": LANE_CENTER})
		return

	var wave_entry: Dictionary = waves[current_wave]
	if wave_entry.get("is_boss_wave", false):
		_spawn_boss_wave()
		return

	for squad_entry in wave_entry.get("squads", []):
		_spawn_squad_for_wave_entry(squad_entry)
	for solo_entry in wave_entry.get("solos", []):
		_spawn_solo_for_wave_entry(solo_entry)


func _spawn_squad_for_wave_entry(squad_entry: Dictionary) -> BeeSquad:
	"""Turn one squad entry from `waves` into an actual squad in the level,
	via BaseLevel.spawn_squad() (shared with any other level that wants
	squad-based enemies). circle_hold_interval is a per-squad setting (see
	the WAVES FORMAT comment above) - only overridden here if the wave entry
	actually specifies one, otherwise the squad just keeps
	enemies/yellow_squad.gd's own export default."""
	var start_percent: float = squad_entry.get("start_percent", LANE_CENTER)
	var start_pos: Vector2 = _side_point(squad_entry.get("start_side", Side.TOP), start_percent)
	var end_pos: Vector2 = _side_point(squad_entry.get("end_side", Side.BOTTOM), squad_entry.get("end_percent", start_percent))
	var squad := spawn_squad(
		squad_entry.get("enemy", fallback_enemy),
		start_pos,
		end_pos,
		squad_entry.get("start_delay", 0.0),
		squad_entry.get("circle_progress", DEFAULT_CIRCLE_PROGRESS),
		squad_entry.get("drift", NO_DRIFT),
		squad_entry.get("squad_size", DEFAULT_SQUAD_SIZE),
	)
	if squad_entry.has("circle_hold_interval"):
		squad.circle_hold_interval = squad_entry["circle_hold_interval"]
	return squad


func _spawn_solo_for_wave_entry(solo_entry: Dictionary) -> BeeSolo:
	"""Turn one solo entry from `waves` into an actual lone enemy in the
	level, via BaseLevel.spawn_solo() (shared with any other level that
	wants solo bee-style enemies)."""
	var start_pos: Vector2 = _side_point(solo_entry.get("start_side", Side.LEFT), solo_entry.get("start_percent", LANE_CENTER))
	var end_pos: Vector2 = _side_point(solo_entry.get("end_side", Side.RIGHT), solo_entry.get("end_percent", LANE_CENTER))
	return spawn_solo(
		solo_entry.get("enemy", fallback_enemy),
		start_pos,
		end_pos,
		solo_entry.get("start_delay", 0.0),
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
# is GONE - killed, or left to fly off the edge of the screen unkilled -
# BaseLevel.resolve_boss_add_death() (wired up below) automatically calls
# resume_after_adds() on the boss so it comes back down. Deliberately
# connected to each squad's member_gone signal, not enemy_died - enemy_died
# only fires on an actual kill (it's what scores points, wired up separately
# in BaseLevel.spawn_squad()), so wiring resolve_boss_add_death() to it
# instead used to leave the fight stalled forever if the player let an add
# escape off the bottom of the screen instead of killing it.
func _on_boss_retreat_started() -> void:
	var left_squad := spawn_squad(fallback_enemy, _side_point(Side.TOP, LANE_LEFT), _side_point(Side.BOTTOM, LANE_LEFT), 0.0, DEFAULT_CIRCLE_PROGRESS, DRIFT_RIGHT)
	var right_squad := spawn_squad(fallback_enemy, _side_point(Side.TOP, LANE_RIGHT), _side_point(Side.BOTTOM, LANE_RIGHT), BOSS_ADD_STAGGER_DELAY, DEFAULT_CIRCLE_PROGRESS, DRIFT_LEFT)
	start_boss_add_wave(left_squad.squad_size + right_squad.squad_size)
	left_squad.member_gone.connect(resolve_boss_add_death)
	right_squad.member_gone.connect(resolve_boss_add_death)
