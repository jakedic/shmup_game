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

func _ready():
	# Set yellow enemy specific properties
	max_health = 3  # Yellow enemies have 3 health
	current_health = max_health
	bullet_scene = preload("res://enemy_bullets/enemy_bullet.tscn")
	multi_shot=true
	shot_count=3
	shot_spread=60
	
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
