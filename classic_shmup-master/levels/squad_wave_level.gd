# squad_wave_level.gd
# Shared machinery for any level built as a numbered list of waves, with a
# boss fight as the final wave. levels/yellow_level.gd and
# levels/dylan_level.gd are both built on this - their own files only need to
# say WHAT spawns in each wave, not HOW waves get run.
#
# HOW TO BUILD A LEVEL ON TOP OF THIS: a wave is just a function - write one
# function per wave (any name; this file's convention is _wave_1, _wave_2,
# ...), each calling spawn_squad_wave()/spawn_solo_wave()/spawn_drift_wave()/
# spawn_hive_wave() (see below) for whatever should appear in that wave, then
# set `waves` to an array of those functions (bare, no parentheses - GDScript
# turns a bare method reference into a Callable) in the subclass's own
# _ready(), along with `boss_scene` and `fallback_enemy`, then call
# super._ready(). Everything else - running each wave in order, waiting for
# it to clear before starting the next, running the boss fight, spawning
# "add" squads while the boss is retreated - is handled here, once, instead
# of being copy-pasted into every level. Example:
#
#     func _wave_1() -> void:
#         spawn_solo_wave({"enemy": ENEMY_BEE, "start_side": Side.LEFT, "start_percent": 0.3, "end_side": Side.RIGHT, "end_percent": 0.3})
#
#     func _wave_boss() -> void:
#         _spawn_boss_wave()
#
#     func _ready() -> void:
#         waves = [_wave_1, _wave_boss]
#         boss_scene = SOME_BOSS_SCENE
#         fallback_enemy = SOME_ENEMY_SCENE
#         super._ready()
#
# A wave function can call more than one spawn_*_wave() to send multiple
# things down at once (stagger them with each call's own "start_delay" if you
# want them entering one after another instead of all together), and since
# it's a real function you can put whatever other logic you want in there too
# - a comment, a loop, a random choice between a few layouts, anything.
#
# EACH spawn_*_wave() function below takes ONE labeled config Dictionary -
# every field is named right at the call site, so a wave function reads
# clearly without needing to check a function signature for what argument 3
# means. Fields shared by every pattern:
#   enemy         - which enemy/scene fills this spawn (an .tscn preload,
#                    e.g. ENEMY_BEE or ASTROID_MEDIUM)
#   start_delay   - OPTIONAL - seconds to wait before THIS spawn starts, so
#                    multiple spawn_*_wave() calls in the same wave function
#                    can stagger their entrances (try 0.0, 1.5, 3.0, ...)
#                    instead of all starting at once. Leave it out for 0.0
#                    (starts right away). Every pattern below supports this
#                    the same way.
#
# SIDE + PERCENT: rather than picking exact screen coordinates,
# spawn_squad_wave()/spawn_solo_wave()/spawn_drift_wave() describe where
# their enemy starts and ends as a screen edge (Side.LEFT/RIGHT/TOP/BOTTOM)
# plus how far along that edge (0.0-1.0). For LEFT/RIGHT, 0.0 is the top of
# that edge and 1.0 is the bottom; for TOP/BOTTOM, 0.0 is the left end and
# 1.0 is the right end. LANE_LEFT/LANE_CENTER/LANE_RIGHT (below) are handy
# percent values for the common lanes, whichever side they're used on.
# _side_point() turns a side+percent into the actual off-screen world
# position (a little past the edge, via OFFSCREEN_MARGIN, so nothing pops
# in/out right at the boundary).
#
# ----- spawn_squad_wave(config) - see enemies/yellow_squad.gd -----
# A group that flies in, circles, then departs and loops one at a time.
#   start_side/start_percent - defaults to the top edge, centered
#   end_side/end_percent     - where a departed member is eventually removed;
#                              defaults to the bottom edge, at the same
#                              percent as the start (so a squad that only
#                              sets start_percent falls straight down that
#                              lane)
#   circle_progress          - OPTIONAL - how far along the start->end line
#                              (0.0-1.0) the squad stops to circle. Leave it
#                              out for DEFAULT_CIRCLE_PROGRESS.
#   circle_hold_interval     - OPTIONAL - how many seconds THIS squad holds
#                              its circle formation before departing (see
#                              enemies/yellow_squad.gd's own export of the
#                              same name for the default)
#   drift                    - OPTIONAL - sideways drift a member picks up
#                              once it's traveling solo after its own
#                              departure loop (see NO_DRIFT/DRIFT_LEFT/
#                              DRIFT_RIGHT below, or any px/s value)
#   squad_size               - OPTIONAL - how many enemies fly in this squad.
#                              Leave it out for DEFAULT_SQUAD_SIZE.
#
# ----- spawn_solo_wave(config) - see enemies/yellow_solo.gd -----
# One enemy flying a straight line, same wobble/loop as a squad member, on
# its own.
#   start_side/start_percent - defaults to the left edge, centered
#   end_side/end_percent     - defaults to the right edge, centered
#
# ----- spawn_drift_wave(config) - see enemies/astroid_enemy.gd -----
# One enemy that just drifts in a straight line and spins - no shooting, no
# diving, no formation. Originally built for the astroid enemies, but works
# for any enemy scene with a launch(start, end, speed) method.
#   start_side/start_percent - defaults to the top edge, centered
#   end_side/end_percent     - sets its direction (it keeps traveling
#                              straight past this point - it doesn't stop or
#                              get removed there). Defaults to the bottom
#                              edge, at the same percent as the start.
#   speed                    - OPTIONAL - how fast it travels, px/s. Leave it
#                              out for DEFAULT_DRIFT_SPEED.
#
# ----- spawn_hive_wave(config) - see enemies/hive_solo.gd -----
# One enemy playing its own stop-jitter-fire dance. Always enters from the
# top edge - there's no start_side/end_side for this one, just how far
# across the top it is and how far down it pauses.
#   x_percent   - OPTIONAL - 0.0-1.0 fraction of the way across the top edge.
#                 Leave it out for LANE_CENTER.
#   pause_y     - OPTIONAL - how far down the screen (px) it pauses to dance.
#                 Leave it out for 60.0.
#
# ---------------------------------------------------------------------------
# HOW TO ADD A NEW PATTERN (a new enemy with its own movement/abilities):
#   Write a `spawn_<name>_wave(config: Dictionary) -> void` function below,
#   next to the others - pull whatever fields your pattern needs out of
#   `config` with `.get("field", default)`, same as the existing ones do, and
#   use `_side_point()` if it needs edge-based placement. Then call it
#   directly from whichever wave function wants it - `spawn_<name>_wave({...})`
#   - same as any of the existing ones. There's no dispatch table or wave
#   format to update: a wave function just calls the spawn functions it
#   wants, so a brand new pattern is usable the instant its function exists.
#   If the new pattern's actual movement is complex enough to need its own
#   state machine (like a squad's circle-then-loop, or the hive's
#   stop-and-dance), give it its own controller script (see
#   enemies/yellow_squad.gd/yellow_solo.gd/hive_solo.gd for the pattern: a
#   Node2D that owns the enemy instance(s), sets `squad_controlled = true` on
#   each one so base_enemy.gd's own movement stays out of the way, and relays
#   an `enemy_died` signal so BaseLevel's scoring still works) - simple
#   straight-line movement like "drift" doesn't need one, it can just drive
#   the enemy's own position directly (see enemies/astroid_enemy.gd).
# ---------------------------------------------------------------------------
class_name SquadWaveLevel
extends BaseLevel

# ---------------------------------------------------------------------------
# SIDE - which edge of the screen a spawn starts or ends just off of - see
# SIDE + PERCENT above and _side_point() below.
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

# How many enemies fly in a squad when its config doesn't say otherwise (see
# the `squad_size` field in spawn_squad_wave()'s comment above).
const DEFAULT_SQUAD_SIZE := 4

# How far along its start->end line a squad circles when its config doesn't
# say otherwise (see the `circle_progress` field above).
const DEFAULT_CIRCLE_PROGRESS := 0.35

# How fast a spawn_drift_wave() entry travels, in px/s, when its config
# doesn't say otherwise (see the `speed` field above).
const DEFAULT_DRIFT_SPEED := 20.0

# Seconds between the boss's two "add" squads starting to move when it
# retreats offscreen mid-fight (see _on_boss_retreat_started()) - kept
# separate from `waves` since these squads belong to the boss fight, not a
# numbered wave.
const BOSS_ADD_STAGGER_DELAY := 1.5

# ---- Subclass configuration - set these in _ready(), before calling super._ready() ----
var waves: Array[Callable] = []   # this level's wave functions, in order - see the header comment above
var boss_scene: PackedScene       # spawned by whichever wave function calls _spawn_boss_wave()
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
# set to this wave's index (0-based) by the time it's called. Just calls
# whichever function `waves[current_wave]` is - see the header comment above
# for how a subclass builds that array.
func spawn_enemies() -> void:
	if current_wave >= waves.size():
		# Shouldn't happen - max_waves is set from waves.size() above - but
		# fall back to a single center squad rather than spawning nothing.
		push_error("%s: wave %d has no function in `waves`!" % [scene_file_path, current_wave])
		spawn_squad_wave({"enemy": fallback_enemy, "start_percent": LANE_CENTER})
		return

	waves[current_wave].call()


func spawn_squad_wave(config: Dictionary) -> BeeSquad:
	"""Spawn a "squad" (see enemies/yellow_squad.gd) via BaseLevel.spawn_squad()
	(shared with any other level that wants squad-based enemies), from a
	labeled config - see spawn_squad_wave(config)'s field list in the header
	comment above. circle_hold_interval is only overridden here if `config`
	actually specifies one, otherwise the squad just keeps
	enemies/yellow_squad.gd's own export default."""
	var start_percent: float = config.get("start_percent", LANE_CENTER)
	var start_pos: Vector2 = _side_point(config.get("start_side", Side.TOP), start_percent)
	var end_pos: Vector2 = _side_point(config.get("end_side", Side.BOTTOM), config.get("end_percent", start_percent))
	var squad := spawn_squad(
		config.get("enemy", fallback_enemy),
		start_pos,
		end_pos,
		config.get("start_delay", 0.0),
		config.get("circle_progress", DEFAULT_CIRCLE_PROGRESS),
		config.get("drift", NO_DRIFT),
		config.get("squad_size", DEFAULT_SQUAD_SIZE),
	)
	if config.has("circle_hold_interval"):
		squad.circle_hold_interval = config["circle_hold_interval"]
	return squad


func spawn_solo_wave(config: Dictionary) -> BeeSolo:
	"""Spawn a "solo" (see enemies/yellow_solo.gd) via BaseLevel.spawn_solo()
	(shared with any other level that wants solo bee-style enemies), from a
	labeled config - see spawn_solo_wave(config)'s field list in the header
	comment above."""
	var start_pos: Vector2 = _side_point(config.get("start_side", Side.LEFT), config.get("start_percent", LANE_CENTER))
	var end_pos: Vector2 = _side_point(config.get("end_side", Side.RIGHT), config.get("end_percent", LANE_CENTER))
	return spawn_solo(
		config.get("enemy", fallback_enemy),
		start_pos,
		end_pos,
		config.get("start_delay", 0.0),
	)


func spawn_drift_wave(config: Dictionary) -> void:
	"""Spawn a "drift" enemy (see enemies/astroid_enemy.gd) via
	BaseLevel.spawn_astroid() (originally built for the astroid enemies, but
	works for any enemy scene with a launch(start, end, speed) method), from
	a labeled config - see spawn_drift_wave(config)'s field list in the
	header comment above. start_delay works differently here than for a
	squad/solo (which park onscreen-ready and delay their own movement) - a
	drift entry has no "parked" state, so a delayed one simply isn't spawned
	at all until its delay elapses."""
	var start_percent: float = config.get("start_percent", LANE_CENTER)
	var start_pos: Vector2 = _side_point(config.get("start_side", Side.TOP), start_percent)
	var end_pos: Vector2 = _side_point(config.get("end_side", Side.BOTTOM), config.get("end_percent", start_percent))
	var astroid_config := {
		"scene": config.get("enemy"),
		"start": start_pos,
		"end": end_pos,
		"speed": config.get("speed", DEFAULT_DRIFT_SPEED),
	}
	var start_delay: float = config.get("start_delay", 0.0)
	if start_delay <= 0.0:
		spawn_astroid(astroid_config)
	else:
		get_tree().create_timer(start_delay).timeout.connect(func(): spawn_astroid(astroid_config))


func spawn_hive_wave(config: Dictionary) -> void:
	"""Spawn a "hive" enemy (see enemies/hive_solo.gd's stop-jitter-fire
	dance) via BaseLevel.spawn_hive_solo(), from a labeled config - see
	spawn_hive_wave(config)'s field list in the header comment above. Always
	enters from the top edge - there's no start_side/end_side for this
	pattern, just how far across the top it is (x_percent) and how far down
	the screen it pauses (pause_y)."""
	spawn_hive_solo(
		config.get("enemy", fallback_enemy),
		config.get("x_percent", LANE_CENTER),
		config.get("pause_y", 60.0),
		config.get("start_delay", 0.0),
	)


func _spawn_boss_wave() -> void:
	"""Call this from whichever wave function is the level's boss wave (see
	the header comment's example). spawn_boss() (BaseLevel) hands back a
	plain Node since it works for any boss scene - only connect
	retreat_started if this particular boss actually has it, so this stays
	usable for a boss scene that doesn't."""
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
