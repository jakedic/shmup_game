# yellow_enemy.gd
extends BaseEnemy
class_name YellowEnemy

# ===== DIVE: SIDE-TO-SIDE WAVE =====
@export var dive_wobble_amplitude: float = 20.0   # how far side to side, px
@export var dive_wobble_frequency: float = 4.0    # oscillations per second - lower = slower swing

# ===== DIVE: LOOP-DE-LOOP =====
# Deterministic - always loops after `loop_interval` seconds of zig-zagging,
# no rantdomness.
@export var loop_interval: float = 2.0    # seconds of zig-zag between loops
@export var loop_duration: float = 1.55   # seconds to complete one full loop
@export var loop_radius: float = 26.0     # size of the loop, px

# ===== FACING =====
# The sprite's unrotated art faces "down" (toward the player). rotation is
# derived every frame from actual movement direction, so it works the same
# way for the wave and the loop without separate rotation logic per mode.
@export var facing_min_speed: float = 1.0  # below this speed (px/s), keep last facing instead of jittering

var is_diving: bool = false
var dive_time: float = 0.0
var dive_origin_x: float = 0.0

var dive_mode: String = "zigzag"  # "zigzag" or "loop"
var zigzag_time: float = 0.0
var loop_time: float = 0.0
var loop_start_pos: Vector2 = Vector2.ZERO

var last_position: Vector2 = Vector2.ZERO

# ===== SHOOTING =====
@export var shot_charge_duration: float = 1.5      # brief telegraph before any shot, seconds
@export var dive_shot_extra_pause: float = 0.0     # ADDED on top of the above if diving when it fires
@export var charge_flash_color: Color = Color(0.008, 0.0, 1.0, 1.0)  # stark magenta for now - easy to confirm; tune to taste once working
@export var charge_flash_blink_interval: float = 0.05

var is_charging_shot: bool = false
var charge_freeze_pos: Vector2 = Vector2.ZERO

# True only while the CURRENT charge is the one holding a dive frozen (i.e.
# it began while is_diving was already true). Needed because is_diving can
# flip from false to true *during* a charge that started before any dive was
# happening (shooting and diving are on independent timers) - see
# _charge_and_fire() for why re-checking is_diving alone at the end of a
# charge is not safe.
var _charge_froze_dive: bool = false

func _ready():
	# Set yellow enemy specific properties
	max_health = 1  # Yellow enemies have 3 health
	current_health = max_health
	bullet_scene = preload("res://enemy_bullets/enemy_bullet.tscn")
	multi_shot = false
	shot_count = 1
	bullet_damage = 4     # powerful - well above the base_enemy default of 1
	bullet_speed = 450.0  # fast - well above the base_enemy default of 150
	
	add_to_group("enemy")
	
	# Set yellow color
	#modulate = Color.YELLOW

# Optional: Override take_damage for yellow enemy specific behavior
'''func take_damage(damage_amount: int = 1):
	# Yellow enemies take less damage? Or have special effect?
	# For example: yellow enemies flash yellow when hit
	var original_modulate = modulate
	modulate = Color(1, 1, 0.5)  # Brighter yellow
	await get_tree().create_timer(0.1).timeout
	modulate = original_modulate
	
	# Call parent take_damage
	return super.take_damage(damage_amount)'''

func custom_start(pos: Vector2):
	"""Called every time this enemy (re)spawns - make sure a fresh dive
	always starts the wobble timer from zero."""
	is_diving = false
	dive_time = 0.0
	dive_mode = "zigzag"
	rotation = 0.0

func custom_dive():
	"""base_enemy.initiate_dive() calls this once, right when the dive
	begins (current_speed is already set for the straight-down fall)."""
	is_diving = true
	dive_time = 0.0
	dive_origin_x = position.x
	dive_mode = "zigzag"
	zigzag_time = 0.0
	last_position = position

func custom_process(delta: float):
	"""Called every frame after base_enemy already applied the vertical
	fall for this frame. Alternates between the sine-wave zig-zag and a
	loop-de-loop on a fixed schedule, then faces the sprite toward
	wherever it actually just moved."""
	if not is_diving:
		return
	
	if is_charging_shot and _charge_froze_dive:
		# Hold perfectly still while winding up a shot - same technique as
		# the loop's suspended-descent, override whatever base_enemy's
		# per-frame fall just added this frame. Gated on _charge_froze_dive
		# (not just is_charging_shot) because a charge that started before
		# this dive began never captured a valid charge_freeze_pos - see
		# _charge_and_fire().
		position = charge_freeze_pos
		return
	
	dive_time += delta
	
	if dive_mode == "loop":
		_process_loop(delta)
	else:
		_process_zigzag(delta)
	
	_update_facing(delta)

func _process_zigzag(delta: float):
	zigzag_time += delta
	if zigzag_time >= loop_interval:
		_start_loop()
		return  # the loop itself starts next frame
	
	# Simple single sine wave, back and forth around the dive's starting x.
	position.x = dive_origin_x + sin(dive_time * dive_wobble_frequency) * dive_wobble_amplitude
	
	# Keep it from wobbling off the sides of the screen
	position.x = clamp(position.x, 8, screensize.x - 8)

func _start_loop():
	dive_mode = "loop"
	loop_time = 0.0
	loop_start_pos = position

func _process_loop(delta: float):
	loop_time += delta
	var t = loop_time / loop_duration
	if t >= 1.0:
		_end_loop()
		return
	
	# Pure vertical-loop parametric curve, no descent added - the enemy's
	# downward movement is fully suspended for the duration of the loop.
	# Starts and ends at the same local offset (0,0), so it stitches back
	# into the zig-zag cleanly.
	var angle = t * TAU
	var offset = Vector2(sin(angle), 1.0 - cos(angle)) * loop_radius
	position = loop_start_pos + offset

func _end_loop():
	dive_mode = "zigzag"
	dive_origin_x = position.x  # re-center the wave on wherever the loop ended
	dive_time = 0.0             # fresh wave phase so it doesn't jump
	zigzag_time = 0.0

func _update_facing(delta: float):
	"""Point the sprite the way it's actually moving this frame. Default
	art faces down (rotation 0), so we offset the velocity angle by -90deg
	(Vector2.DOWN's own angle) to line the two up."""
	var velocity = (position - last_position) / delta
	if velocity.length() >= facing_min_speed:
		rotation = velocity.angle() - Vector2.DOWN.angle()
	last_position = position

func get_enemy_type():
	return 'yellow'

func shoot():
	"""Override base_enemy.shoot(): telegraph with a flash before firing,
	pausing (and freezing in place) longer if currently mid-dive."""
	
	if is_charging_shot:
		return  # already winding up, don't stack another
	_charge_and_fire()

func _charge_and_fire():
	is_charging_shot = true
	var charge_time = shot_charge_duration

	# Remember the dive-fall speed so it can be restored after charging -
	# NOT just visually frozen. custom_process() re-pins `position` to
	# charge_freeze_pos every frame while charging, but base_enemy's own
	# _process() still runs position.y += current_speed * delta BEFORE
	# that override happens each frame. Left alone, that hidden y growth
	# eventually crosses base_enemy's off-screen-bottom check mid-charge
	# and triggers a reset_position()/respawn - which is what was causing
	# the enemy to suddenly snap back to its original spawn slot (often a
	# side/corner of the formation) once the charge ended. Zeroing
	# current_speed here stops that hidden accumulation at the source.
	var frozen_speed = current_speed

	# Capture whether THIS charge is the one pausing an in-progress dive, and
	# use that same flag (not a fresh is_diving check) when the charge ends.
	# Shooting and diving run on independent timers, so a charge can start
	# while the enemy is still calmly sitting in formation (is_diving false,
	# frozen_speed correctly 0) and only *become* a diving enemy partway
	# through the charge, once the dive timer separately fires. If the
	# restore below re-checked is_diving instead of remembering this, it
	# would see "is_diving = true" at the end and slam the freshly-started
	# dive's real speed back down to the stale frozen_speed (0) it captured
	# before the dive even began - leaving the enemy marked as diving but
	# never actually falling again: stuck in place (often near the top of
	# the screen, right where it started diving) forever, since it can never
	# reach the bottom-of-screen check that would let it respawn and rejoin
	# the formation.
	_charge_froze_dive = is_diving

	if is_diving:
		charge_time += dive_shot_extra_pause
		rotation = 0
		charge_freeze_pos = position  # freeze the dive in place while charging
		current_speed = 0

	_start_charge_flash(charge_time)

	await get_tree().create_timer(charge_time).timeout

	is_charging_shot = false
	if _charge_froze_dive:
		current_speed = frozen_speed  # resume falling at the same speed as before
	_charge_froze_dive = false
	if not is_instance_valid(self) or not is_alive:
		return
	shoot_single()

func _start_charge_flash(duration: float):
	"""Pulse modulate between the normal color and charge_flash_color for
	`duration` seconds using a Tween, as a telegraph that a shot is coming."""
	var home_color = enemy_color
	var pulse_time = charge_flash_blink_interval * 0.5
	
	var tween = create_tween()
	tween.set_loops()  # repeats until killed below
	tween.tween_property(self, "modulate", charge_flash_color, pulse_time)
	tween.tween_property(self, "modulate", home_color, pulse_time)
	
	get_tree().create_timer(duration).timeout.connect(func():
		if is_instance_valid(tween):
			tween.kill()
		if is_instance_valid(self):
			modulate = home_color
	)

func custom_bullet_launch(bullet: Node2D):
	"""base_enemy already added the bullet to the tree and called start()
	by the time this fires - which means the bullet's own _ready() has
	already run and overwritten whatever create_bullet() set (both
	bullet.gd and enemy_bullet.gd hardcode their own speed/damage in
	_ready()). Reapply our stronger values here, after _ready(), so the
	"powerful and fast" stats actually stick."""
	if bullet.has_method("set_damage"):
		bullet.set_damage(bullet_damage)
	if bullet.has_method("set_speed"):
		bullet.set_speed(bullet_speed)
