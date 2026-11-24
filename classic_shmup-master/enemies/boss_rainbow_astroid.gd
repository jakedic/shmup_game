# boss_rainbow_astroid.gd
#
# The rainbow astroid boss: a rainbow-colored medium astroid (the Core, a
# BossPart - see boss_part.gd) with a ring of small astroids circling it.
# The small astroids are normal small astroids (enemies/astroid_small.tscn):
# each one can be shot down on its own, and only the Core's health matters
# for beating the boss.
#
# THE FIGHT (a loop until the Core dies):
#   1. Wait idle_time seconds (4.5), floating and circling.
#   2. Charge: a border appears around the Core (and a thin one around each
#      small ring astroid) and flicks between orange, yellow, blue and white,
#      slowing down until it lands on one, then blinks. The ring astroids
#      keep that color while they do the move.
#        ORANGE - the ring astroids grow (halfway between small and medium),
#                 their health doubles, they fly up off the top of the screen
#                 into a line (each keeps its own lane, so any you shot down
#                 earlier leave a gap), then the line falls slowly.
#        YELLOW - the ring spins faster and faster, then every astroid flies
#                 out from the boss in a curving spiral until it leaves the
#                 screen.
#        BLUE   - the ring astroids get armor (blue outline) and pull in
#                 tight, then the whole boss swings down through where the
#                 player is, out to the side, and back again. Afterwards the
#                 armored astroids drift away. Only the small astroids show
#                 blue during the swing - the boss's own border goes away.
#        WHITE  - the boss rises to the top of the screen, turning so it's
#                 long top-to-bottom, and follows the player's x - but where
#                 the player WAS a moment ago (white_track_delay), not where
#                 they are now. While it charges, the ring astroids pull in
#                 and disappear into it; then it fires them back out straight
#                 down, one after another, rapid fire, still following just
#                 behind.
#   3. After flash_moves_before_storm (2) of those, the next move is the
#      STORM instead: the boss flies up off the top of the screen (can't be
#      hit) while small astroids, gray ships and the odd golden astroid rain
#      down - same mix as the tutorial's absorb drops - then it comes back.
#   4. After every move, the ring refills (one new small astroid per empty
#      spot), then back to step 1.
# The same color is never picked twice in a row. The Core slowly rotates
# while it's idle and while the border is flicking; it holds still from the
# moment it lands on a move until that move is done.
#
# HOW TO SPAWN FROM A LEVEL:
#
#     var boss = preload("res://enemies/boss_rainbow_astroid.tscn").instantiate()
#     add_child(boss)
#     boss.start()        # or boss.start(Vector2(x, y)) to pick where it hovers
#
# It drops in from the top, wires its score into the level, and spawns its
# own ring and storm drops. The level's normal "all enemies gone" wave check
# ends the wave once it's beaten (or listen for `defeated`).
#
# Everything is tweakable through the exports below (select the
# BossRainbowAstroid root in boss_rainbow_astroid.tscn). The Core's health is
# on the Core node.
extends Node2D
class_name BossRainbowAstroid

const AstroidSmallScene := preload("res://enemies/astroid_small.tscn")
const AstroidGoldenScene := preload("res://enemies/astroid_golden.tscn")
const GrayBeeScene := preload("res://enemies/gray_bee.tscn")
const GrayHiveScene := preload("res://enemies/gray_hive.tscn")
const GrayFlowerScene := preload("res://enemies/gray_flower.tscn")
const EnemyOutlineScript := preload("res://enemies/enemy_outline.gd")

signal defeated   # the Core is down and its death animation has finished

# Index = the move it stands for, and the border color it lands on.
enum RainbowMove { ORANGE_WALL, YELLOW_SPIRAL, BLUE_SWING, WHITE_BARRAGE, STORM }
const MOVE_COLORS := [
	Color(1.0, 0.55, 0.1, 1.0),    # orange
	Color(1.0, 0.85, 0.2, 1.0),    # yellow
	Color(0.3, 0.6, 1.0, 1.0),     # blue (same as the armor outline - BaseEnemy.ARMOR_OUTLINE_COLOR)
	Color(1.0, 1.0, 1.0, 1.0),     # white
]
const COLOR_MOVE_COUNT := 4   # how many of the moves above are color moves (everything but STORM)

# ===== ENTRANCE / FLOATING =====
@export var entry_time: float = 2.0           # seconds to drop in from the top
@export var hover_y: float = 80.0             # where it hovers (px from the top), centered sideways
@export var float_amplitude: Vector2 = Vector2(50.0, 5.0)   # idle drift around the hover point
@export var float_speed: Vector2 = Vector2(0.6, 1.3)        # radians/second

# ===== RING =====
@export var orbit_count: int = 8              # small astroids in a full ring
@export var orbit_radius: float = 52.0        # px from the Core's center
@export var orbit_speed: float = 1.2          # radians/second
@export var core_spin_speed: float = 0.4     # how fast the big rainbow astroid slowly turns between moves (radians/second)
@export var ring_spin: float = 2.0            # how fast each ring astroid spins on its own (radians/second)
@export var respawn_time: float = 0.5         # seconds for a refilled ring astroid to grow in

# ===== TIMING =====
@export var idle_time: float = 4.5            # seconds between moves before it starts charging (was 3)
@export var flash_moves_before_storm: int = 2 # color moves in a row, then a storm

# ===== CHARGE (color-flicking border) =====
@export var charge_time: float = 1.8          # at least this long flicking before it lands
@export var charge_flick_start: float = 0.06  # seconds per color at the start
@export var charge_flick_growth: float = 1.15 # each flick lasts this much longer (slows down)
@export var border_width: float = 2.0
@export var ring_border_width: float = 1.0   # border on each small ring astroid (same colors as the boss's)

# ===== ORANGE: grow + line falling from the top =====
@export var orange_grow_scale: float = 3.0       # 3x a small = halfway between small and medium
@export var orange_health_mult: int = 2
@export var orange_line_y: float = -28.0         # where the line forms (just above the screen)
@export var orange_gather_time: float = 1.2      # seconds to fly up into the line
@export var orange_hold_time: float = 0.4        # pause in line before falling
@export var orange_fall_speed: float = 35.0      # px/s (was 22)

# ===== YELLOW: spin up + curved spiral outward =====
@export var yellow_spin_up_time: float = 0.8
@export var yellow_spin_speed: float = 5.0    # ring speed right before release (radians/second)
@export var yellow_out_speed: float = 75.0    # px/s outward
@export var yellow_turn_speed: float = 2.2    # radians/second they keep curving while flying out

# ===== BLUE: armor + tight ring + swing at the player =====
@export var blue_armor: int = 1               # 1 = normal shots do nothing (jump landings still hurt)
@export var blue_radius: float = 40.0         # how tight the ring pulls in
@export var blue_tighten_time: float = 0.6
@export var blue_swings: int = 2              # out through the player and back
@export var blue_swing_time: float = 2.4      # seconds per swing (was 1.4 - slower = easier to dodge)
@export var blue_swing_pause: float = 0.6     # seconds it waits between swings (was 0.25)
@export var blue_side_offset: float = 80.0    # each swing ends at least this far to the side
@export var blue_release_speed: float = 50.0  # px/s the armored astroids drift away afterwards

# ===== WHITE: rise to the top, follow just behind the player, rapid fire =====
@export var white_hover_y: float = 40.0         # how far down from the top it sits (stays on screen)
@export var white_rise_time: float = 0.8        # also how long it takes to turn long top-to-bottom
@export var white_absorb_time: float = 0.8      # seconds for the ring astroids to pull into the boss
@export var white_muzzle_offset: float = 40.0   # shots come out this far below the boss's center (its bottom end)
@export var white_track_delay: float = 0.35     # follows where the player was this many seconds ago
@export var white_track_smoothing: float = 6.0  # higher = sticks closer to that spot
@export var white_charge_time: float = 1.5      # seconds of charging (and following) before it fires
@export var white_charge_spin: float = 3.5      # ring speed while charging (radians/second)
@export var white_fire_interval: float = 0.18   # seconds between shots
@export var white_shot_speed: float = 200.0     # px/s straight down
@export var white_after_fire_time: float = 0.5  # keeps following this long after the last shot

# ===== STORM =====
@export var storm_rise_time: float = 1.0
@export var storm_time: float = 10.0
@export var storm_interval: float = 0.7       # seconds between drops
@export var storm_small_chance: float = 0.65  # small astroid
@export var storm_ship_chance: float = 0.30   # gray bee / hive / flower - whatever's left is a golden astroid
@export var storm_min_lane_gap: float = 0.15  # a drop never lands right on top of the one before it

@onready var core = $Core

var _screen: Vector2
var _home: Vector2
var _t := 0.0
var _floating := false
var _hittable := true
var _defeated := false
var _ring: Array = []            # one entry per ring spot: the astroid there, or null
var _orbit_angle := 0.0
var _cur_orbit_speed := 0.0
var _cur_orbit_radius := 0.0
var _spirals: Array = []         # yellow-move astroids flying out: {node, origin, angle, radius}
var _held: Array = []            # red-move astroids flying into the line (not circling, not falling yet)
var _border = null               # EnemyOutline while charging / doing a color move
var _core_spinning := true      # slow idle rotation on/off (see core_spin_speed)
var _core_rot := 0.0             # the Core art's current rotation (radians)
var _stored: Array = []          # white move: ring astroids pulled inside the boss, waiting to be fired
var _tracking := false           # white move: following where the player was a moment ago
var _player_trail: Array = []    # white move: [time, player x] samples, oldest first


func _ready() -> void:
	_screen = get_viewport_rect().size
	_ring.resize(orbit_count)
	_cur_orbit_speed = orbit_speed
	_cur_orbit_radius = orbit_radius
	core.died.connect(_on_core_died)


func start(hover_pos: Vector2 = Vector2(-1, -1)) -> void:
	if hover_pos.x < 0.0:
		hover_pos = Vector2(_screen.x * 0.5, hover_y)
	_home = hover_pos
	_setup_in_level()
	position = Vector2(_home.x, -orbit_radius - 40.0)
	_set_hittable(false)
	for i in orbit_count:
		_spawn_ring_astroid(i, false)
	var tw := create_tween()
	tw.tween_property(self, "position", _home, entry_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tw.finished
	if not _fighting():
		return
	_set_hittable(true)
	_t = 0.0
	_floating = true
	_run_fight()


func _setup_in_level() -> void:
	var level = get_parent()
	if level == null:
		return
	if level.has_method("_on_enemy_died") and not core.died.is_connected(level._on_enemy_died):
		core.died.connect(level._on_enemy_died)
	if level.has_method("note_spawn"):
		level.note_spawn(0.0)


# ============================================================
# MAIN LOOP
# ============================================================

func _run_fight() -> void:
	var color_moves := 0
	var last_move := -1
	while _fighting():
		_core_spinning = true
		await _wait(idle_time)
		if not _fighting():
			return
		if color_moves >= flash_moves_before_storm:
			color_moves = 0
			_core_spinning = false
			await _move_storm()
		else:
			var move := randi() % COLOR_MOVE_COUNT
			while move == last_move:
				move = randi() % COLOR_MOVE_COUNT
			last_move = move
			color_moves += 1
			await _charge(move)
			if not _fighting():
				return
			match move:
				RainbowMove.ORANGE_WALL:
					await _move_orange()
				RainbowMove.YELLOW_SPIRAL:
					await _move_yellow()
				RainbowMove.BLUE_SWING:
					await _move_blue()
				RainbowMove.WHITE_BARRAGE:
					await _move_white()
			_clear_border()
		if not _fighting():
			return
		await _refill_ring()


func _fighting() -> bool:
	return is_inside_tree() and not _defeated and is_instance_valid(core) and core.is_alive


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, false).timeout   # pause-aware


# ============================================================
# PER FRAME
# ============================================================

func _process(delta: float) -> void:
	# The Core can be removed WITHOUT dying - e.g. when the player dies the
	# level deletes everything in the "enemies" group. Nothing left to run.
	if not _defeated and not is_instance_valid(core):
		queue_free()
		return
	if _defeated:
		if not is_instance_valid(core):
			defeated.emit()
			queue_free()
		return

	_t += delta
	if _core_spinning:
		_set_core_rotation(_core_rot + core_spin_speed * delta)
	if _tracking:
		_process_tracking(delta)
	elif _floating:
		var target := _home + Vector2(sin(_t * float_speed.x) * float_amplitude.x, sin(_t * float_speed.y) * float_amplitude.y)
		position = position.lerp(target, 1.0 - exp(-4.0 * delta))   # eases back after a move instead of snapping

	_orbit_angle += _cur_orbit_speed * delta
	for i in _ring.size():
		var a = _ring[i]
		if not _alive(a):
			_ring[i] = null
			continue
		a.position = _ring_point(i)
		a.rotation += ring_spin * delta

	_update_spirals(delta)


## Turns the Core's art and hitbox (not the Core node itself, so its health
## bar stays put above it). The charge border follows the art automatically.
func _set_core_rotation(r: float) -> void:
	_core_rot = r
	if not is_instance_valid(core):
		return
	for n in ["Sprite2D", "CollisionPolygon2D"]:
		var node := core.get_node_or_null(n) as Node2D
		if node:
			node.rotation = r


func _ring_point(i: int) -> Vector2:
	return position + Vector2.from_angle(_orbit_angle + TAU * i / orbit_count) * _cur_orbit_radius


func _alive(a) -> bool:
	return is_instance_valid(a) and a.is_alive and not a.is_queued_for_deletion()


# ============================================================
# RING
# ============================================================

func _spawn_ring_astroid(i: int, grow_in: bool) -> void:
	var level = get_parent()
	var a = AstroidSmallScene.instantiate()
	a.squad_controlled = true   # this script moves it, not its own drift code
	level.add_child(a)
	a.position = _ring_point(i)
	if level.has_method("_on_enemy_died"):
		a.died.connect(level._on_enemy_died)
	if grow_in:
		a.scale = Vector2.ONE * 0.1
		a.create_tween().tween_property(a, "scale", Vector2.ONE, respawn_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if not _hittable:
		_set_node_hittable(a, false)
	_ring[i] = a


## Puts a fresh small astroid in every empty spot of the ring.
func _refill_ring() -> void:
	var any := false
	for i in _ring.size():
		if not _alive(_ring[i]):
			_spawn_ring_astroid(i, true)
			any = true
	if any:
		await _wait(respawn_time)


## The ring astroids still circling, as [spot index, astroid] pairs.
func _ring_members() -> Array:
	var out: Array = []
	for i in _ring.size():
		if _alive(_ring[i]):
			out.append([i, _ring[i]])
	return out


## Lets a ring astroid go: it drifts off in a straight line on its own
## (normal astroid behavior - removed once it leaves the screen).
func _release(a, direction: Vector2, speed: float) -> void:
	a.squad_controlled = false
	a.launch(a.position, a.position + direction, speed)


func _set_hittable(on: bool) -> void:
	_hittable = on
	_set_node_hittable(core, on)
	for pair in _ring_members():
		_set_node_hittable(pair[1], on)


## Off = bullets, the absorb beam and the ship pass straight through. Uses
## the plain is_invincible flag (not set_invincible()) so nothing flashes.
func _set_node_hittable(node, on: bool) -> void:
	node.set_deferred("monitorable", on)
	node.set_deferred("monitoring", on)
	node.is_invincible = not on


# ============================================================
# CHARGE - border flicks between colors, slows down, lands on `move`
# ============================================================

func _charge(move: int) -> void:
	_clear_border()
	_border = EnemyOutlineScript.new()
	_border.name = "ChargeBorder"
	_border.width = border_width
	var idx := randi() % COLOR_MOVE_COUNT
	_border.outline_color = MOVE_COLORS[idx]
	core.add_child(_border)

	_add_ring_borders(MOVE_COLORS[idx])

	var elapsed := 0.0
	var step := charge_flick_start
	while elapsed < charge_time or idx != move:
		idx = (idx + 1) % COLOR_MOVE_COUNT
		_border.configure(MOVE_COLORS[idx], border_width)
		_set_ring_borders(MOVE_COLORS[idx], ring_border_width)
		core.position = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))   # little rattle while it charges
		await _wait(step)
		if not _fighting():
			return
		elapsed += step
		step *= charge_flick_growth
	core.position = Vector2.ZERO
	_core_spinning = false   # picked a move - hold still until it's done

	# Landed - blink it so it's clear which one it picked.
	var off: Color = MOVE_COLORS[move]
	off.a = 0.0   # blink = border off, then on (works for white too)
	for _k in 3:
		_border.configure(off, border_width + 0.5)
		_set_ring_borders(off, ring_border_width)
		await _wait(0.07)
		if not _fighting():
			return
		_border.configure(MOVE_COLORS[move], border_width + 0.5)
		_set_ring_borders(MOVE_COLORS[move], ring_border_width)
		await _wait(0.13)
		if not _fighting():
			return


func _clear_border() -> void:
	if is_instance_valid(_border):
		_border.queue_free()
	_border = null
	if is_instance_valid(core):
		core.position = Vector2.ZERO
	# Astroids that left the ring during the move (the orange line, the yellow
	# spirals, the white shots) keep their colored border until they're gone - only the ones
	# still circling lose it.
	for pair in _ring_members():
		_remove_ring_border(pair[1])


# --- Matching borders on the small ring astroids ---

const RING_BORDER_NAME := "ChargeBorder"

func _add_ring_borders(color: Color) -> void:
	for pair in _ring_members():
		var a = pair[1]
		if a.get_node_or_null(RING_BORDER_NAME):
			continue
		var b = EnemyOutlineScript.new()
		b.name = RING_BORDER_NAME
		b.width = ring_border_width
		b.outline_color = color
		a.add_child(b)


func _set_ring_borders(color: Color, width: float) -> void:
	for pair in _ring_members():
		var b = pair[1].get_node_or_null(RING_BORDER_NAME)
		if b:
			b.configure(color, width)


func _remove_ring_border(a) -> void:
	var b = a.get_node_or_null(RING_BORDER_NAME)
	if b:
		a.remove_child(b)   # out right away, so an outline added next (armor) lands in the right spot
		b.queue_free()


# ============================================================
# ORANGE - grow, double health, line up above the screen, fall slowly
# ============================================================

func _move_orange() -> void:
	var lane_width := _screen.x / orbit_count
	for pair in _ring_members():
		var i: int = pair[0]
		var a = pair[1]
		_ring[i] = null   # no longer circling - this function moves it now
		_held.append(a)
		a.max_health *= orange_health_mult
		a.current_health *= orange_health_mult
		a.explosion_diameter = 40.0
		var target := Vector2((i + 0.5) * lane_width, orange_line_y)
		var tw = a.create_tween().set_parallel(true)
		tw.tween_property(a, "scale", Vector2.ONE * orange_grow_scale, orange_gather_time * 0.5)
		tw.tween_property(a, "position", target, orange_gather_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _wait(orange_gather_time + orange_hold_time)
	if not is_inside_tree():
		return
	# Every grown astroid still alive falls together. (Runs even if the boss
	# just died - _on_core_died() already destroyed them in that case.)
	for a in _held:
		if _alive(a):
			_release(a, Vector2.DOWN, orange_fall_speed)
	_held.clear()


# ============================================================
# YELLOW - spin up, then spiral outward off the screen
# ============================================================

func _move_yellow() -> void:
	var tw := create_tween()
	tw.tween_property(self, "_cur_orbit_speed", yellow_spin_speed, yellow_spin_up_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	if not _fighting():
		return
	for pair in _ring_members():
		var i: int = pair[0]
		_ring[i] = null
		_spirals.append({
			"node": pair[1],
			"origin": position,
			"angle": _orbit_angle + TAU * i / orbit_count,
			"radius": _cur_orbit_radius,
		})
	_cur_orbit_speed = orbit_speed
	await _wait(0.6)


func _update_spirals(delta: float) -> void:
	var margin := 40.0
	for s in _spirals.duplicate():
		var a = s["node"]
		if not _alive(a):
			_spirals.erase(s)
			continue
		s["radius"] += yellow_out_speed * delta
		s["angle"] += yellow_turn_speed * delta
		a.position = s["origin"] + Vector2.from_angle(s["angle"]) * s["radius"]
		a.rotation += ring_spin * 2.0 * delta
		if a.position.x < -margin or a.position.x > _screen.x + margin \
				or a.position.y < -margin or a.position.y > _screen.y + margin:
			_spirals.erase(s)
			a.is_alive = false
			a.queue_free()   # left the screen - quietly gone, no score


# ============================================================
# BLUE - armor, tight ring, swing down through the player and back
# ============================================================

func _move_blue() -> void:
	# Only the small astroids show blue during this move - the boss's own
	# charge border goes away.
	if is_instance_valid(_border):
		_border.queue_free()
	_border = null
	for pair in _ring_members():
		_remove_ring_border(pair[1])   # the blue armor outline takes over
		pair[1].set_armor(blue_armor)
	var tw := create_tween()
	tw.tween_property(self, "_cur_orbit_radius", blue_radius, blue_tighten_time)
	await tw.finished
	if not _fighting():
		return

	_floating = false
	for s in blue_swings:
		var from := position
		var player_pos := _player_position()
		var to: Vector2
		if s == blue_swings - 1:
			to = _home   # last swing comes back home
		else:
			to = Vector2(clampf(player_pos.x + (player_pos.x - from.x), 40.0, _screen.x - 40.0), hover_y)
		if absf(to.x - from.x) < blue_side_offset:
			to.x = from.x + (blue_side_offset if from.x < _screen.x * 0.5 else -blue_side_offset)
		# Curve that passes right through where the player is halfway along.
		var ctrl := player_pos * 2.0 - (from + to) * 0.5
		var swing := create_tween()
		var step := swing.tween_method(_set_swing_position.bind(from, ctrl, to), 0.0, 1.0, blue_swing_time)
		step.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await swing.finished
		if not _fighting():
			return
		await _wait(blue_swing_pause)
		if not _fighting():
			return

	# Armored astroids drift away, ring goes back to normal size.
	for pair in _ring_members():
		_ring[pair[0]] = null
		var dir: Vector2 = (pair[1].position - position).normalized()
		_release(pair[1], dir, blue_release_speed)
	_cur_orbit_radius = orbit_radius
	_floating = true


func _player_position() -> Vector2:
	var p = get_tree().get_first_node_in_group("player")
	var pos := Vector2(_screen.x * 0.5, _screen.y * 0.8)
	if p is Node2D and is_instance_valid(p):
		pos = p.position
	pos.y = minf(pos.y, _screen.y - 30.0)   # never swing the boss off the bottom
	return pos


## Tween callback for the blue swing - `t` goes 0 -> 1 along the curve.
func _set_swing_position(t: float, from: Vector2, ctrl: Vector2, to: Vector2) -> void:
	position = _bezier(from, ctrl, to, t)


func _bezier(a: Vector2, c: Vector2, b: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return a * u * u + c * 2.0 * u * t + b * t * t


# ============================================================
# WHITE - rise to the top, follow just behind the player, rapid fire
# ============================================================

func _move_white() -> void:
	_floating = false
	# Rise to the top and turn long top-to-bottom at the same time. The art
	# is wider than it is tall, so "long" = a quarter turn from flat -
	# whichever quarter turn is closest to how it's sitting now.
	var vertical := _core_rot + wrapf(PI * 0.5 - _core_rot, -PI * 0.5, PI * 0.5)
	var up := create_tween().set_parallel(true)
	up.tween_property(self, "position:y", white_hover_y, white_rise_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	up.tween_method(_set_core_rotation, _core_rot, vertical, white_rise_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await up.finished
	if not _fighting():
		return

	# Charge: start following, the ring spins up and pulls into the boss,
	# and each astroid disappears inside it.
	_player_trail.clear()
	_tracking = true
	var pull := create_tween().set_parallel(true)
	pull.tween_property(self, "_cur_orbit_speed", white_charge_spin, white_absorb_time)
	pull.tween_property(self, "_cur_orbit_radius", 0.0, white_absorb_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	for pair in _ring_members():
		pair[1].create_tween().tween_property(pair[1], "scale", Vector2.ONE * 0.3, white_absorb_time)
	var elapsed := 0.0
	var absorbed := false
	while elapsed < white_charge_time:
		if not absorbed and elapsed >= white_absorb_time:
			absorbed = true
			_store_ring()
		core.position = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
		await _wait(0.05)
		if not _fighting():
			_tracking = false
			return
		elapsed += 0.05
	if not absorbed:
		_store_ring()
	core.position = Vector2.ZERO

	# Fire: one stored astroid at a time, out of the bottom of the boss.
	while not _stored.is_empty():
		var a = _stored.pop_front()
		if not is_instance_valid(a):
			continue
		a.position = position + Vector2(0.0, white_muzzle_offset)
		a.scale = Vector2.ONE
		a.visible = true
		_set_node_hittable(a, true)
		_release(a, Vector2.DOWN, white_shot_speed)
		await _wait(white_fire_interval)
		if not _fighting():
			_tracking = false
			return

	await _wait(white_after_fire_time)
	_tracking = false
	_cur_orbit_speed = orbit_speed
	_cur_orbit_radius = orbit_radius
	_floating = true   # eases back down to the hover point


## White move: every astroid still in the ring goes inside the boss - hidden
## and can't be hit until it's fired back out.
func _store_ring() -> void:
	for pair in _ring_members():
		var a = pair[1]
		_ring[pair[0]] = null
		a.visible = false
		_set_node_hittable(a, false)
		_stored.append(a)


## Follows the player's x from white_track_delay seconds ago, staying at
## white_hover_y.
func _process_tracking(delta: float) -> void:
	var p = get_tree().get_first_node_in_group("player")
	if p is Node2D and is_instance_valid(p):
		_player_trail.append([_t, p.position.x])
	# Drop samples older than we need (keep one just past the delay).
	while _player_trail.size() > 1 and _player_trail[1][0] <= _t - white_track_delay:
		_player_trail.pop_front()
	if _player_trail.is_empty():
		return
	var target_x: float = clampf(_player_trail[0][1], 20.0, _screen.x - 20.0)
	position.x = lerpf(position.x, target_x, 1.0 - exp(-white_track_smoothing * delta))
	position.y = white_hover_y


# ============================================================
# STORM - boss leaves up top, drops rain down, boss comes back
# ============================================================

func _move_storm() -> void:
	_floating = false
	_set_hittable(false)
	var up := create_tween()
	up.tween_property(self, "position", Vector2(position.x, -orbit_radius - 60.0), storm_rise_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await up.finished
	if not _fighting():
		return

	var elapsed := 0.0
	var last_lane := -1.0
	while elapsed < storm_time:
		last_lane = _storm_drop(last_lane)
		await _wait(storm_interval)
		if not _fighting():
			return
		elapsed += storm_interval

	var down := create_tween()
	down.tween_property(self, "position", _home, entry_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await down.finished
	if not _fighting():
		return
	_set_hittable(true)
	_t = 0.0
	_floating = true


## One storm drop straight down a random lane - a small astroid, a gray ship
## (bee, hive or flower) or a golden astroid. Returns the lane it used.
func _storm_drop(last_lane: float) -> float:
	var lane := randf_range(0.1, 0.9)
	while last_lane >= 0.0 and absf(lane - last_lane) < storm_min_lane_gap:
		lane = randf_range(0.1, 0.9)
	var scene: PackedScene
	var speed := 45.0
	var roll := randf()
	if roll < storm_small_chance:
		scene = AstroidSmallScene
	elif roll < storm_small_chance + storm_ship_chance:
		match randi() % 3:
			0:
				scene = GrayBeeScene
				speed = 30.0
			1:
				scene = GrayHiveScene
				speed = 25.0
			_:
				scene = GrayFlowerScene
				speed = 20.0
	else:
		scene = AstroidGoldenScene
		speed = 35.0
	var level = get_parent()
	if level.has_method("spawn_drift_wave"):
		level.spawn_drift_wave({"enemy": scene, "start_percent": lane, "speed": speed})
	else:
		var e = scene.instantiate()
		level.add_child(e)
		var x := _screen.x * lane
		e.launch(Vector2(x, -20.0), Vector2(x, _screen.y), speed)
	return lane


# ============================================================
# DEFEAT
# ============================================================

func _on_core_died(_value: int) -> void:
	_defeated = true
	_floating = false
	_clear_border()
	# Everything still attached to the boss goes with it.
	for pair in _ring_members():
		pair[1].die()
	for s in _spirals:
		if _alive(s["node"]):
			s["node"].die()
	_spirals.clear()
	for a in _held:
		if _alive(a):
			a.die()
	_held.clear()
	for a in _stored:
		if _alive(a):
			a.position = position
			a.visible = true
			a.die()
	_stored.clear()
