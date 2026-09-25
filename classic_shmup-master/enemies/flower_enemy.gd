# flower_enemy.gd
#
# A flower that floats down the screen like a falling leaf: it swings side to
# side in a gentle pendulum arc while it descends, spinning as it goes,
# tilting into each swing and rising slightly at the end of every arc. After a few swings it stops in
# the middle of an arc and charges up - the flower spins faster and faster
# while a thin red aiming line (from Flower_Charge.png) points straight down -
# then fires a laser straight down (beam from Flower_Lazer.png) that hurts the
# player, still spinning at full speed. Once the laser ends it goes back to
# floating (the spin winds back down to normal), and fires again after another
# few swings. It quietly disappears once it falls past the bottom of the
# screen.
#
# HOW TO SPAWN ONE FROM LEVEL CODE:
#
#     spawn_flower({"scene": FLOWER, "start": Vector2(120, -30)})
#
# (spawn_flower() lives on levels/base_level.gd, so every level has it.) See
# levels/a_test.gd for a working example, and the exports below for
# everything you can tweak per-flower.
extends "res://enemies/base_enemy.gd"
class_name FlowerEnemy

# ===== LEAF MOTION (tweak these to change how it floats) =====
@export var fall_speed: float = 28.0        # how fast it sinks, pixels/second
@export var sway_width: float = 36.0        # how far it swings left/right of its center line, pixels
@export var sway_time: float = 2.6          # seconds for one full left-right-left swing
@export var arc_lift: float = 10.0           # how much it rises at each end of a swing, pixels
@export var tilt_deg: float = 50.0          # how far it tilts into each swing, degrees
# Pendulum feel: relative speed through the middle of a swing vs. at the
# ends. The flower (sideways AND falling) whooshes through the middle and
# hangs for a moment at each end. Only the ratio matters - it's normalized
# so sway_time and the average fall_speed stay exactly the same. Set both
# to 1.0 for the old even speed.
@export var swing_pace_center: float = 1.5
@export var swing_pace_ends: float = 0.6
@export var spin_speed_deg: float = 120.0   # how fast it spins while falling, degrees/second (direction is random per flower)

# ===== LASER ATTACK =====
@export var swings_before_fire: float = 2.0     # full back-and-forth swings between laser attacks (only used when attack_heights is empty)
# Where to fire, as fractions of the screen height (0 = top, 1 = bottom),
# e.g. [0.2, 0.5]. Each one is used once, in order: the flower fires as it
# passes through the middle of its first swing after reaching that height.
# Leave empty to fire every swings_before_fire swings instead.
@export var attack_heights: Array = []
@export var charge_time: float = 0.9            # seconds charging before the laser fires
@export var charge_spin_max_deg: float = 1080.0 # spin speed the flower winds up to by the end of the charge (and keeps while firing), degrees/second
@export var spin_down_time: float = 0.8         # seconds to slow back to normal spin after the laser ends
@export var laser_time: float = 1.0             # seconds the laser stays on
@export var laser_damage: int = 1               # damage per hit
@export var laser_damage_interval: float = 0.4  # while the player stays in the beam, hit again this often (seconds)
@export var laser_hitbox_width: float = 6.0     # width of the damaging part of the beam, pixels
# Only starts an attack while it's comfortably on screen (not still above
# the top edge, and not so low the beam would barely exist).
@export var fire_min_y: float = 16.0
@export var fire_max_y_ratio: float = 0.75      # fraction of screen height

@export var normal_texture: Texture2D
@export var charge_texture: Texture2D
@export var laser_texture: Texture2D

# ===== START DELAY =====
# Seconds to wait (hidden, at its start point) before it starts falling. Lets
# a level stagger entrances instead of placing flowers higher up. The flower
# still counts as an enemy while it waits, so its wave won't end early.
@export var start_delay: float = 0.0

# ===== OFF-SCREEN DESPAWN =====
# How far past the bottom edge it can fall before it's removed (no score).
@export var offscreen_despawn_margin: float = 48.0

# Where things sit in the source art (all three Flower*.png files share the
# same 2732x2048 canvas and layout). The flower Sprite2D shows CROP_*; the
# beam/charge-line sprites below it reuse a vertical slice of pure beam from
# the same art and stretch it down to the bottom of the screen.
const CROP_CENTER := Vector2(1413.5, 1029.5)   # center of the Sprite2D region_rect
const CROP_BOTTOM := 1432.0                    # bottom edge of that region_rect
const LASER_SLICE := Rect2(1280, 1432, 280, 600)   # beam slice in Flower_Lazer.png
const CHARGE_SLICE := Rect2(1404, 1432, 20, 600)   # red aiming line slice in Flower_Charge.png
const CHARGE_LINE_TOP := 1054.0                    # where the red line starts in Flower_Charge.png (just under the flower's center)
const BEAM_TOP := 1040.0                           # where the laser starts in Flower_Lazer.png (the flower's center)

enum FlowerState { FLOATING, CHARGING, FIRING }
var _state: FlowerState = FlowerState.FLOATING

var _is_floating: bool = false
var _center_x: float = 0.0     # the invisible line it swings back and forth across
var _base_y: float = 0.0       # its "falling" height before the arc lift is added
var _phase: float = 0.0        # where it is in its swing, radians
var _swing_since_fire: float = 0.0  # radians of swing since the last attack
var _next_attack: int = 0           # index into attack_heights
var _state_timer: float = 0.0
var _spin_angle: float = 0.0       # accumulated spin, radians (tilt is added on top)
var _spin_dir: float = 1.0         # 1 = clockwise, -1 = counter-clockwise
var _spin_speed_now: float = 0.0   # current falling spin speed, deg/s (eases back to spin_speed_deg after an attack)
var _delay_left: float = 0.0       # start_delay countdown (see launch())
var _squad_driven: bool = false    # true when a FlowerSquad is moving this flower (see join_squad())
var _charge_ramp_time: float = 0.0 # how long the charge spin takes to wind up to full speed
var _hold_charge: bool = false     # squad-controlled charge: keep charging until fire_now() is called
var _damage_cooldown: float = 0.0

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _beam: Sprite2D = $Beam
@onready var _charge_line: Sprite2D = $ChargeLine
@onready var _laser_hitbox: Area2D = $LaserHitbox
@onready var _laser_shape: CollisionShape2D = $LaserHitbox/CollisionShape2D

func custom_ready():
	# Flowers don't shoot bullets, dive, or follow the bobbing enemy anchor -
	# the laser below is their only attack.
	can_shoot = false
	can_dive = false
	follow_anchor_enabled = false
	# Own shape per flower (a shape shared through the .tscn would be resized
	# by every flower at once).
	_laser_shape.shape = RectangleShape2D.new()
	_set_attack_visuals(FlowerState.FLOATING)

func launch(start_pos: Vector2, overrides: Dictionary = {}) -> void:
	"""Normal way to spawn a flower - places it at start_pos and starts it
	floating immediately (no spawn-in animation). `overrides` can set any of
	the exports above for just this flower, e.g.
	{"fall_speed": 40.0, "sway_width": 20.0, "swings_before_fire": 3.0}."""
	for key in overrides:
		if key in self:
			set(key, overrides[key])
	_center_x = start_pos.x
	_base_y = start_pos.y
	# Random starting point in the swing so a group of flowers doesn't move
	# in perfect lockstep.
	_phase = randf() * TAU
	_spin_angle = randf() * TAU
	_spin_dir = 1.0 if randf() < 0.5 else -1.0
	_spin_speed_now = spin_speed_deg
	_apply_leaf_position()
	_is_floating = true
	_delay_left = start_delay
	if _delay_left > 0.0:
		visible = false

static func swing_pace(phase: float, center: float, ends: float) -> float:
	"""Speed multiplier at this point in the swing: `center` in the middle
	(phase = multiple of PI), `ends` at the far ends, easing between them.
	Divided by sqrt(center * ends), which works out so a full swing still
	takes exactly sway_time and the average fall speed is unchanged - it
	also keeps every quarter-swing the same length, which the squad's
	attack timing relies on (see enemies/flower_squad.gd)."""
	var c = max(center, 0.05)
	var e = max(ends, 0.05)
	var k = cos(phase)
	return (e + (c - e) * k * k) / sqrt(c * e)

# ===== SQUAD SUPPORT (used by enemies/flower_squad.gd) =====

func join_squad(overrides: Dictionary, spin_angle: float, spin_dir: float) -> void:
	"""Hand this flower over to a FlowerSquad: the squad sets its position
	every frame (set_squad_pose()) and tells it when to charge
	(begin_charge()) and fire (fire_now()). The flower still handles its own spin, charge and
	laser. Every member gets the same spin so the squad stays in sync."""
	for key in overrides:
		if key in self:
			set(key, overrides[key])
	_squad_driven = true
	_spin_angle = spin_angle
	_spin_dir = spin_dir
	_spin_speed_now = spin_speed_deg
	_is_floating = true

func set_squad_pose(pos: Vector2, swing: float) -> void:
	"""Squad moves this flower. `swing` is -1..1 (where it is in the
	side-to-side sway) and drives the leaf tilt, same as a solo flower."""
	position = pos
	if _state == FlowerState.FLOATING:
		rotation = _spin_angle + deg_to_rad(-tilt_deg * swing)

func begin_charge(ramp_time: float) -> void:
	"""Squad: start charging now. The spin winds up to full speed over
	ramp_time seconds, and the flower keeps charging until the squad calls
	fire_now() - so flowers that start charging at different moments can
	all fire together."""
	if is_alive and _state == FlowerState.FLOATING:
		_enter_state(FlowerState.CHARGING)
		_state_timer = ramp_time
		_charge_ramp_time = ramp_time
		_hold_charge = true

func fire_now() -> void:
	"""Squad: stop charging and fire the laser (runs for laser_time, then
	the flower goes back to floating on its own)."""
	if is_alive and _state == FlowerState.CHARGING:
		_hold_charge = false
		_enter_state(FlowerState.FIRING)

func is_attacking() -> bool:
	return _state != FlowerState.FLOATING

func start(pos: Vector2) -> void:
	"""Fallback for the generic `e.start(pos)` spawn pattern used elsewhere
	in the project - just floats down from pos with the default settings."""
	if not is_alive:
		return
	launch(pos)

func custom_process(delta: float):
	if not _is_floating or not is_alive:
		return
	if _delay_left > 0.0:
		_delay_left -= delta
		if _delay_left <= 0.0:
			visible = true
		return
	match _state:
		FlowerState.FLOATING:
			_process_floating(delta)
		FlowerState.CHARGING:
			_process_charging(delta)
		FlowerState.FIRING:
			_process_firing(delta)

func _process_floating(delta: float) -> void:
	var spin_down_rate = abs(charge_spin_max_deg - spin_speed_deg) / max(spin_down_time, 0.01)
	_spin_speed_now = move_toward(_spin_speed_now, spin_speed_deg, spin_down_rate * delta)
	_spin_angle = fmod(_spin_angle + deg_to_rad(_spin_speed_now) * _spin_dir * delta, TAU)

	# In a squad, the squad moves this flower and decides when it attacks
	# (see enemies/flower_squad.gd) - this flower only keeps spinning.
	if _squad_driven:
		return

	var pace = swing_pace(_phase, swing_pace_center, swing_pace_ends)
	var step = TAU / max(sway_time, 0.1) * delta * pace
	var old_phase = _phase
	_phase += step
	_swing_since_fire += step
	_base_y += fall_speed * delta * pace

	# Ready to attack? Stop exactly as it passes through the middle of a
	# swing (phase = a multiple of PI), where it's upright and at the bottom
	# of its arc - so the laser points straight down.
	var crossed_middle = floor(_phase / PI) != floor(old_phase / PI)
	if crossed_middle and _ready_to_fire():
		_phase = floor(_phase / PI) * PI
		_apply_leaf_position()
		_enter_state(FlowerState.CHARGING)
		return

	_apply_leaf_position()

func _process_charging(delta: float) -> void:
	"""Only the flower art (the Sprite2D) spins here - the enemy itself stays
	upright so the aiming line and laser point straight down. The spin winds
	up from the normal falling speed to charge_spin_max_deg, easing in so it
	really whips around right before it fires."""
	_state_timer -= delta
	var t = clamp(1.0 - _state_timer / max(_charge_ramp_time, 0.01), 0.0, 1.0)
	var speed = lerp(spin_speed_deg, charge_spin_max_deg, t * t)
	_sprite.rotation = fmod(_sprite.rotation + deg_to_rad(speed) * _spin_dir * delta, TAU)
	# A squad-held charge waits for the squad's fire_now() instead.
	if _state_timer <= 0.0 and not _hold_charge:
		_enter_state(FlowerState.FIRING)

func _process_firing(delta: float) -> void:
	_state_timer -= delta
	# Keep whipping the flower art around at full speed while the beam
	# (a separate, non-spinning sprite) fires straight down.
	_sprite.rotation = fmod(_sprite.rotation + deg_to_rad(charge_spin_max_deg) * _spin_dir * delta, TAU)
	_damage_cooldown -= delta
	if _damage_cooldown <= 0.0:
		for area in _laser_hitbox.get_overlapping_areas():
			if area.name == "Player" and area.has_method("take_damage"):
				area.take_damage(laser_damage)
				_damage_cooldown = laser_damage_interval
				break
	if _state_timer <= 0.0:
		_enter_state(FlowerState.FLOATING)

func _ready_to_fire() -> bool:
	"""Solo flowers only. Height-based if attack_heights is set, otherwise
	every swings_before_fire swings."""
	if attack_heights.is_empty():
		return _swing_since_fire >= swings_before_fire * TAU and _can_fire_here()
	if _next_attack >= attack_heights.size():
		return false  # used up every attack height - just floats from here on
	var target_y = max(fire_min_y, float(attack_heights[_next_attack]) * screensize.y)
	if position.y >= target_y and position.y <= screensize.y:
		_next_attack += 1
		return true
	return false

func _can_fire_here() -> bool:
	return position.y >= fire_min_y and position.y <= screensize.y * fire_max_y_ratio

func _enter_state(new_state: FlowerState) -> void:
	_state = new_state
	match new_state:
		FlowerState.CHARGING:
			_state_timer = charge_time
			_charge_ramp_time = charge_time
			_hold_charge = false
			# Hand the current spin over to the flower art so it keeps
			# turning seamlessly, while the enemy itself (and the aiming
			# line/laser attached to it) goes perfectly upright.
			_sprite.rotation = rotation
			rotation = 0.0
			_spin_angle = 0.0
		FlowerState.FIRING:
			_state_timer = laser_time
			_damage_cooldown = 0.0
		FlowerState.FLOATING:
			_swing_since_fire = 0.0
			# Hand the spin back from the flower art to the whole enemy,
			# starting at full speed and easing down (see _process_floating()).
			if _sprite.rotation != 0.0:
				_spin_angle = _sprite.rotation
				rotation = _spin_angle
				_sprite.rotation = 0.0
				_spin_speed_now = charge_spin_max_deg
	_set_attack_visuals(new_state)

func _set_attack_visuals(state: FlowerState) -> void:
	"""Swap the flower art and show/hide/size the beam for the given state."""
	match state:
		FlowerState.FLOATING:
			if normal_texture:
				_sprite.texture = normal_texture
		FlowerState.CHARGING:
			# The spinning flower uses the normal art - the red aiming line
			# is drawn separately (ChargeLine) so it doesn't spin with it.
			if normal_texture:
				_sprite.texture = normal_texture
		FlowerState.FIRING:
			# Spinning flower keeps the normal art; the beam is drawn
			# separately (Beam) so it doesn't spin with it.
			if normal_texture:
				_sprite.texture = normal_texture

	_charge_line.visible = state == FlowerState.CHARGING
	_beam.visible = state == FlowerState.FIRING
	_laser_shape.set_deferred("disabled", state != FlowerState.FIRING)
	if state == FlowerState.CHARGING or state == FlowerState.FIRING:
		_layout_beam()

func _layout_beam() -> void:
	"""Stretch the beam + charge line from the bottom of the flower art down
	past the bottom of the screen, and size the laser hitbox to match. Uses
	the flower Sprite2D's scale, so resizing the flower in the .tscn keeps
	everything lined up automatically."""
	var s = _sprite.scale.x
	var top_y = (CROP_BOTTOM - CROP_CENTER.y) * s   # just under the flower art
	var length = max(screensize.y + 16.0 - (position.y + top_y), 1.0)

	# The beam starts at the flower's center and is drawn on top of it.
	var beam_top_y = (BEAM_TOP - CROP_CENTER.y) * s
	_beam.texture = laser_texture
	_beam.region_rect = LASER_SLICE
	_beam.position = Vector2((LASER_SLICE.position.x - CROP_CENTER.x) * s, beam_top_y)
	_beam.scale = Vector2(s, (length + top_y - beam_top_y) / LASER_SLICE.size.y)

	# The aiming line starts just under the flower's center (like in
	# Flower_Charge.png) and is drawn on top of the spinning flower.
	var line_top_y = (CHARGE_LINE_TOP - CROP_CENTER.y) * s
	var line_length = length + (top_y - line_top_y)
	_charge_line.texture = charge_texture
	_charge_line.region_rect = CHARGE_SLICE
	_charge_line.position = Vector2((CHARGE_SLICE.position.x - CROP_CENTER.x) * s, line_top_y)
	_charge_line.scale = Vector2(s, line_length / CHARGE_SLICE.size.y)

	# Hitbox covers the whole beam, from the flower's center down.
	var rect := _laser_shape.shape as RectangleShape2D
	var hit_length = length + top_y
	rect.size = Vector2(laser_hitbox_width, hit_length)
	_laser_shape.position = Vector2(0.0, hit_length / 2.0)

func _apply_leaf_position() -> void:
	var swing = sin(_phase)  # -1 (far left) .. 1 (far right)
	position.x = _center_x + sway_width * swing
	# Pendulum arc: highest at either end of the swing, lowest in the middle.
	position.y = _base_y - arc_lift * swing * swing
	# Spin, plus a tilt into the swing like a leaf rocking on the air.
	rotation = _spin_angle + deg_to_rad(-tilt_deg * swing)

func custom_die():
	# Shut the laser off immediately if it's killed mid-attack.
	_beam.visible = false
	_charge_line.visible = false
	_laser_shape.set_deferred("disabled", true)

func handle_boundaries():
	"""Override base_enemy.gd's version (which resets diving enemies back to
	the top) - a flower that's floated past the bottom just disappears."""
	if not _is_floating:
		return
	if position.y > screensize.y + offscreen_despawn_margin:
		is_alive = false
		queue_free()
