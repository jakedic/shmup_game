# boss_badger.gd
#
# First boss: the badger. A floating head with two arms hovering beside it.
# The three pieces move together as one unit, but each is its own BossPart
# (see boss_part.gd) with its own health:
#   - kill an arm  -> that arm fades out, the rest keeps going
#   - kill the head -> the whole boss dies (any arms left die with it)
#
# ATTACKS
#   Eye lasers - whenever the player moves under the head (its line of
#       sight), the head stops drifting, charges for a moment (shakes, red
#       aiming lines from both eyes), then fires a laser out of each eye
#       straight down. Same idea as the flower enemy's laser, reusing its art.
#   Conveyor clap - every arm_attack_interval seconds the arms fly out onto
#       the conveyor belts on either side, ride them down until they reach
#       the player's height, pause, then slam together in the middle. Where
#       they meet, a shockwave ring bursts out and expands off screen - jump
#       over it! (enemies/boss_shockwave.gd).
#   Belt punch (only one arm left, replaces the clap) - same ride down the
#       belt, but the lone arm flies straight across and punches the OTHER
#       belt. A shockwave bursts out from where it hits, and one bee flies
#       out of that belt across to the far side.
#   Belt shake - alternates with the clap/punch. The arms grab the belts and
#       shake them; each shaken belt throws off 2 bees (flying across the
#       screen) and a row of honey walls (the hive enemy's walls). With one
#       arm left, only that arm's belt gets shaken - so half as much.
#   Laser sweep (only the head left) - every sweep_interval seconds the head
#       moves to the left edge, charges, then fires both eye lasers
#       continuously while gliding to the right edge. Jump over the beams!
#   Cigar (only the head left) - between sweeps it spits its cigar at the
#       player every cigar_interval seconds (enemies/boss_cigar.gd).
#
# Health and the arms' resting positions are set on each part in
# boss_badger.tscn. Attack timings/speeds are the exports below - select the
# BossBadger root in boss_badger.tscn to tweak them.
#
# HOW TO SPAWN FROM A LEVEL - this is all a level needs:
#
#     var boss = preload("res://enemies/boss_badger.tscn").instantiate()
#     add_child(boss)
#     boss.start()        # or boss.start(Vector2(x, y)) to pick where it hovers
#
# The boss sets up everything else itself (see _setup_in_level()): it
# builds the conveyor-belt arena (levels/boss_arena.gd) and slides it in as
# it rises, wires each part's score into the level, and spawns its own
# bees / cigars through the level. Listen for `defeated` if the level needs
# to know when it's beaten (the level's normal "all enemies gone" wave check
# also works). See levels/a_test.gd for a working example.
extends Node2D
class_name BossBadger

# Loaded by path (not by class name) so these work even before the editor has
# registered the class_names.
const BossPartScript := preload("res://enemies/boss_part.gd")
const ShockwaveScript := preload("res://enemies/boss_shockwave.gd")
const LASER_TEXTURE := preload("res://Art assets/Player assets and transformations/Flower_Lazer.png")
const CHARGE_TEXTURE := preload("res://Art assets/Player assets and transformations/Flower_Charge.png")
# Same beam / aiming-line slices of the flower art that flower_enemy.gd uses.
const LASER_SLICE := Rect2(1280, 1432, 280, 600)
const CHARGE_SLICE := Rect2(1404, 1432, 20, 600)
const WALL_SCENE := preload("res://enemy_bullets/wall_bullet.tscn")   # the hive's honey wall
const BEE_SCENE := preload("res://enemies/enemy_yellow.tscn")
const CIGAR_SCENE := preload("res://enemies/boss_cigar.tscn")
const BossArenaScript := preload("res://levels/boss_arena.gd")

signal defeated   # head is down and every part has finished dying

# ===== MOVEMENT =====
# Entrance: rises up out of space at the hover point - starts tiny and dark
# (far below the play area) and grows to full size. Can't be hit, and
# doesn't hurt on contact, until it has fully risen.
@export var entry_time: float = 2.5
@export var entry_start_scale: float = 0.15
# Where it hovers when start() is called without a position: centered
# horizontally, this many px down from the top.
@export var hover_y: float = 80.0

# ===== ARENA (conveyor belts) =====
# The boss brings its own arena: if the level doesn't already have one, it
# builds the belts and slides them down from the top of the screen while it
# rises. If one already exists (e.g. a second boss in the same level) it's
# reused as-is.
@export var build_arena: bool = true
@export var belt_scroll_speed: float = 15.0      # px/s the belts run normally (0 = still)
@export var belts_drop_in: bool = true           # slide in from the top during the entrance (false = already there)
# Idle float around the hover point (whole unit together).
# x = 58 lets the head reach right up to the conveyor belts on both sides.
@export var float_amplitude: Vector2 = Vector2(58.0, 5.0)
@export var float_speed: Vector2 = Vector2(0.55, 1.3)   # radians/second
# Tiny extra bob on each arm so they look like they're hovering, not glued
# to the head. Set to 0 for perfectly rigid arms.
@export var arm_bob: float = 1.5

# ===== EYE LASERS =====
# Where the eyes are, relative to the head's center (px).
@export var eye_offsets: Array[Vector2] = [Vector2(-14, 2), Vector2(14, 2)]
# How far left/right of the head's center the player counts as "in sight".
@export var sight_half_width: float = 22.0
@export var laser_charge_time: float = 0.8     # seconds of warning before it fires
@export var laser_fire_time: float = 1.0       # seconds the beams stay on
@export var laser_cooldown: float = 10.0       # seconds after firing before it can charge again
@export var laser_damage: int = 1
@export var laser_damage_interval: float = 0.4 # standing in a beam hits again this often
@export var laser_width: float = 8.0           # how wide each beam looks, px
@export var laser_hitbox_width: float = 5.0    # how wide each beam hurts, px

# ===== CONVEYOR CLAP (arms) =====
@export var first_arm_attack_delay: float = 4.0  # seconds after the boss arrives
@export var arm_attack_interval: float = 7.0     # seconds between clap attacks
@export var arm_to_belt_speed: float = 170.0     # flying out onto the belts, px/s
@export var arm_ride_speed: float = 70.0         # riding down the belts, px/s (belts speed up to match)
@export var arm_windup_time: float = 0.45        # pause at the player's height before clapping
@export var arm_clap_speed: float = 280.0        # slamming together, px/s
@export var arm_return_speed: float = 140.0      # flying back beside the head, px/s
@export var arm_meet_gap: float = 20.0           # how far from the middle each arm stops when they meet
@export var arm_turn_time: float = 0.3           # seconds to turn back upright after the clap
@export var shockwave_damage: int = 2
@export var shockwave_speed: float = 55.0        # how fast the ring grows, px/s

# ===== BELT PUNCH (one arm left) =====
@export var punch_dig_in: float = 14.0           # how far past the belt's edge the arm's center stops, px (bigger = punches deeper)
@export var punch_bee_count: int = 1

# ===== BELT SHAKE (arms) =====
# Alternates with the clap/punch: clap, shake, clap, shake...
@export var shake_grab_drop: float = 55.0        # how far below the head the arms grab the belts, px
@export var shake_time: float = 1.3              # seconds of shaking before things fly off
@export var shake_strength: float = 2.5          # how hard the arms + belts rattle, px
@export var shake_bees_per_belt: int = 2         # 4 total with both arms, 2 with one
@export var shake_walls_per_belt: int = 3        # honey walls thrown off each shaken belt
@export var shake_wall_angle_deg: float = 12.0   # walls angle slightly down/up so they're not all flat
@export var belt_bee_stagger: float = 0.35       # seconds between bees leaving the same belt

# ===== LASER SWEEP (only the head left) =====
@export var sweep_first_delay: float = 2.0       # seconds after the last arm dies
@export var sweep_interval: float = 5.0          # seconds between sweeps
@export var sweep_charge_time: float = 1.0       # warning before the sweep starts firing
@export var sweep_speed: float = 90.0            # px/s the head glides while firing
@export var sweep_reposition_speed: float = 120.0  # px/s moving to the start point / back to drifting

# ===== CIGAR (only the head left) =====
# Spits its cigar at the player: slow, light homing, can miss. Shoot it 3
# times or absorb it for a homing gray form (see enemies/boss_cigar.gd).
@export var cigar_first_delay: float = 1.5       # seconds after the last arm dies
@export var cigar_interval: float = 4.0          # seconds between cigars
@export var cigar_mouth_offset: Vector2 = Vector2(18, 16)   # where the cigar is in the art, relative to the head's center

@onready var head: BossPartScript = $Head
@onready var left_arm: BossPartScript = $LeftArm
@onready var right_arm: BossPartScript = $RightArm

enum BadgerEyeState { READY, CHARGING, FIRING, COOLDOWN }
enum BadgerClapPhase { IDLE, TO_BELT, RIDE, WINDUP, CLAP, RETURN, SHAKE_GRAB, SHAKE }
enum BadgerSweepPhase { IDLE, TO_START, CHARGE, FIRE, BACK }

var _home := Vector2.ZERO
var _floating := false
var _t := 0.0          # drives the arm bob
var _float_t := 0.0    # drives the drift; paused while the eyes are attacking
var _arm_rest := {}    # boss part -> its resting position in the scene
var _is_defeated := false
var _screen := Vector2.ZERO

# Eye lasers
var _eye_state: BadgerEyeState = BadgerEyeState.READY
var _eye_timer := 0.0
var _laser_hit_cooldown := 0.0
var _beams: Array[Sprite2D] = []
var _aim_lines: Array[Sprite2D] = []
var _laser_box: Area2D
var _laser_shapes: Array[CollisionShape2D] = []

# Conveyor clap
var _clap_phase: BadgerClapPhase = BadgerClapPhase.IDLE
var _clap_timer := 0.0
var _clap_y := 0.0
var _next_move_is_shake := false   # arm moves alternate: clap/punch, then shake
var _arm_side := {}      # arm -> -1 (rides the left belt) or 1 (right belt)
var _arm_rest_rot := {}  # arm -> its resting art rotation (jet pointing up)
var _arm_turn := {}      # arm -> 0 (resting, jet up) .. 1 (turned sideways, jet pointing out)
var _belt_speed_before := 0.0

# Laser sweep (head alone)
var _head_alone := false
var _sweep_phase: BadgerSweepPhase = BadgerSweepPhase.IDLE
var _sweep_timer := 0.0
var _sweep_hit_cooldown := 0.0
var _cigar_timer := 0.0


func _ready() -> void:
	_screen = get_viewport_rect().size
	for arm in [left_arm, right_arm]:
		_arm_rest[arm] = arm.position
		_arm_side[arm] = -1 if arm.position.x < 0.0 else 1
		_arm_rest_rot[arm] = (arm.get_node("Sprite2D") as Node2D).rotation
		_arm_turn[arm] = 0.0
	head.died.connect(_on_head_died)
	_build_eye_lasers()
	_clap_timer = first_arm_attack_delay


func get_parts() -> Array:
	var parts: Array = []
	for p in [head, left_arm, right_arm]:
		if is_instance_valid(p):
			parts.append(p)
	return parts


func start(hover_pos: Vector2 = Vector2(-1, -1)) -> void:
	if hover_pos.x < 0.0:
		hover_pos = Vector2(_screen.x * 0.5, hover_y)
	_setup_in_level()
	_home = hover_pos
	position = hover_pos
	_set_hittable(false)
	scale = Vector2.ONE * entry_start_scale
	modulate = Color(0.15, 0.15, 0.25, 0.0)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "scale", Vector2.ONE, entry_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(self, "modulate", Color.WHITE, entry_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw.finished
	_set_hittable(true)
	_float_t = 0.0
	_floating = true


func _setup_in_level() -> void:
	"""Everything a level would otherwise have to do by hand: score for each
	part, tell the level an enemy has spawned, and build / bring in the
	conveyor-belt arena."""
	var level = get_parent()
	if level == null:
		return
	if level.has_method("_on_enemy_died"):
		for part in get_parts():
			if not part.died.is_connected(level._on_enemy_died):
				part.died.connect(level._on_enemy_died)
	if level.has_method("note_spawn"):
		level.note_spawn(0.0)

	if not build_arena or _get_arena() != null:
		return
	var arena = BossArenaScript.new()
	arena.scroll_speed = belt_scroll_speed
	arena.start_hidden = belts_drop_in
	level.add_child(arena)
	# Draw the belts just above the level's scrolling background, under the
	# player, enemies and bullets.
	var bg = level.get_node_or_null("Background")
	level.move_child(arena, bg.get_index() + 1 if bg else 0)
	if belts_drop_in:
		arena.play_intro(entry_time)


func _set_hittable(on: bool) -> void:
	"""Off during the entrance: bullets, the absorb beam and the ship all
	pass straight through (no collisions), and anything that damages by
	distance (e.g. the landing shockwave) is ignored too. Uses the parts'
	plain is_invincible flag, not set_invincible(), so they don't flash."""
	for part in get_parts():
		part.set_deferred("monitorable", on)
		part.set_deferred("monitoring", on)
		part.is_invincible = not on


func _process(delta: float) -> void:
	_t += delta
	# The head can be removed WITHOUT dying - e.g. when the player dies, the
	# level deletes everything in the "enemies" group (base_level.gd's
	# _on_player_died()), which takes the head and arms but not this root
	# node. Nothing is left to run, so tidy up and go.
	# (A normal head kill sets _is_defeated first and is handled below.)
	if not _is_defeated and (not is_instance_valid(head) or head.is_queued_for_deletion()):
		_restore_belts()
		queue_free()
		return
	if _is_defeated:
		if get_parts().is_empty():
			_restore_belts()
			defeated.emit()
			queue_free()
		return

	if _floating:
		# Last part standing? Once any eye laser in progress has finished,
		# the head switches to its laser sweep.
		if not _head_alone and _living_arms().is_empty() \
				and _eye_state != BadgerEyeState.CHARGING and _eye_state != BadgerEyeState.FIRING:
			_head_alone = true
			_clap_phase = BadgerClapPhase.IDLE
			_restore_belts()
			_eye_state = BadgerEyeState.READY
			_set_eye_visuals(BadgerEyeState.READY)
			_sweep_phase = BadgerSweepPhase.IDLE
			_sweep_timer = sweep_first_delay
			_cigar_timer = cigar_first_delay
		if _head_alone:
			_process_sweep(delta)
			_process_cigar(delta)
		else:
			if _eye_state != BadgerEyeState.CHARGING and _eye_state != BadgerEyeState.FIRING:
				_float_t += delta
			position = _float_position()
			_process_eyes(delta)
			_process_clap(delta)

	# Arms resting beside the head bob gently. Arms out on an attack are
	# moved by _process_clap() instead.
	if _clap_phase == BadgerClapPhase.IDLE:
		var i := 0
		for arm in _arm_rest:
			if _arm_alive(arm):
				arm.position = _arm_rest[arm] + Vector2(0, sin(_t * 2.2 + i * PI) * arm_bob)
			i += 1


func _float_position() -> Vector2:
	return _home + Vector2(sin(_float_t * float_speed.x) * float_amplitude.x,
			sin(_float_t * float_speed.y) * float_amplitude.y)


func _on_head_died(_value: int) -> void:
	# Head down = boss down. Take any arms that are still up with it.
	_is_defeated = true
	_set_eye_visuals(BadgerEyeState.READY)
	for arm in [left_arm, right_arm]:
		if _arm_alive(arm):
			arm.die()


func _get_player() -> Node2D:
	var p = get_tree().get_first_node_in_group("player")
	if p is Player and p.is_alive:
		return p
	return null


func _arm_alive(arm) -> bool:
	return is_instance_valid(arm) and arm.is_alive


# ============================================================
# EYE LASERS
# ============================================================

func _build_eye_lasers() -> void:
	# Beams + aiming lines are children of the head so they move with it and
	# vanish with it.
	_laser_box = Area2D.new()
	_laser_box.name = "EyeLaserHitbox"
	_laser_box.collision_layer = 0
	_laser_box.collision_mask = 1     # the player
	_laser_box.monitorable = false
	head.add_child(_laser_box)
	for eye in eye_offsets:
		var line := Sprite2D.new()
		line.texture = CHARGE_TEXTURE
		line.region_enabled = true
		line.region_rect = CHARGE_SLICE
		line.centered = false
		line.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		head.add_child(line)
		_aim_lines.append(line)

		var beam := Sprite2D.new()
		beam.texture = LASER_TEXTURE
		beam.region_enabled = true
		beam.region_rect = LASER_SLICE
		beam.centered = false
		beam.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		head.add_child(beam)
		_beams.append(beam)

		var shape := CollisionShape2D.new()
		shape.shape = RectangleShape2D.new()
		_laser_box.add_child(shape)
		_laser_shapes.append(shape)
	_set_eye_visuals(BadgerEyeState.READY)


func _process_eyes(delta: float) -> void:
	if not _arm_alive(head):
		return
	_eye_timer -= delta
	match _eye_state:
		BadgerEyeState.READY:
			if _player_in_sight():
				_enter_eye_state(BadgerEyeState.CHARGING)
		BadgerEyeState.CHARGING:
			_layout_lasers()
			_charge_shake(1.0 - clampf(_eye_timer / maxf(laser_charge_time, 0.01), 0.0, 1.0))
			if _eye_timer <= 0.0:
				_enter_eye_state(BadgerEyeState.FIRING)
		BadgerEyeState.FIRING:
			_layout_lasers()
			_laser_hit_cooldown -= delta
			if _laser_hit_cooldown <= 0.0:
				for area in _laser_box.get_overlapping_areas():
					if area is Player:
						(area as Player).take_damage(laser_damage)
						_laser_hit_cooldown = laser_damage_interval
						break
			if _eye_timer <= 0.0:
				_enter_eye_state(BadgerEyeState.COOLDOWN)
		BadgerEyeState.COOLDOWN:
			if _eye_timer <= 0.0:
				_enter_eye_state(BadgerEyeState.READY)


func _charge_shake(t: float) -> void:
	"""Shake + redden the head while it charges. t = 0..1 through the charge."""
	var spr := head.get_node("Sprite2D") as Sprite2D
	spr.position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * (0.4 + t)
	spr.self_modulate = Color(1, 1, 1).lerp(Color(1, 0.55, 0.55), t)


func _player_in_sight() -> bool:
	var player := _get_player()
	if player == null:
		return false
	var hp := head.global_position
	return player.global_position.y > hp.y and absf(player.global_position.x - hp.x) <= sight_half_width


func _enter_eye_state(state: BadgerEyeState) -> void:
	_eye_state = state
	match state:
		BadgerEyeState.CHARGING:
			_eye_timer = laser_charge_time
		BadgerEyeState.FIRING:
			_eye_timer = laser_fire_time
			_laser_hit_cooldown = 0.0
			GameShell.shake_screen(0.15, 1.5)
		BadgerEyeState.COOLDOWN:
			_eye_timer = laser_cooldown
	_set_eye_visuals(state)


func _set_eye_visuals(state: BadgerEyeState) -> void:
	for line in _aim_lines:
		if is_instance_valid(line):
			line.visible = state == BadgerEyeState.CHARGING
	for beam in _beams:
		if is_instance_valid(beam):
			beam.visible = state == BadgerEyeState.FIRING
	for shape in _laser_shapes:
		if is_instance_valid(shape):
			shape.set_deferred("disabled", state != BadgerEyeState.FIRING)
	if state != BadgerEyeState.CHARGING and is_instance_valid(head):
		var spr := head.get_node_or_null("Sprite2D") as Sprite2D
		if spr:
			spr.position = Vector2.ZERO
			spr.self_modulate = Color.WHITE
	if state == BadgerEyeState.CHARGING or state == BadgerEyeState.FIRING:
		_layout_lasers()


func _layout_lasers() -> void:
	"""Stretch each eye's beam / aiming line from the eye to just past the
	bottom of the screen, and size its hitbox to match."""
	for i in eye_offsets.size():
		var eye: Vector2 = eye_offsets[i]
		var length: float = maxf(_screen.y + 16.0 - (head.global_position.y + eye.y), 1.0)
		var beam := _beams[i]
		beam.scale = Vector2(laser_width / LASER_SLICE.size.x, length / LASER_SLICE.size.y)
		beam.position = Vector2(eye.x - laser_width * 0.5, eye.y)
		var line := _aim_lines[i]
		var line_w := 1.2
		line.scale = Vector2(line_w / CHARGE_SLICE.size.x, length / CHARGE_SLICE.size.y)
		line.position = Vector2(eye.x - line_w * 0.5, eye.y)
		var rect := _laser_shapes[i].shape as RectangleShape2D
		rect.size = Vector2(laser_hitbox_width, length)
		_laser_shapes[i].position = Vector2(eye.x, eye.y + length * 0.5)


# ============================================================
# CONVEYOR CLAP
# ============================================================

func _process_clap(delta: float) -> void:
	var arms := _living_arms()
	if arms.is_empty():
		if _clap_phase != BadgerClapPhase.IDLE:
			_clap_phase = BadgerClapPhase.IDLE
			_restore_belts()
		return

	match _clap_phase:
		BadgerClapPhase.IDLE:
			_clap_timer -= delta
			if _clap_timer <= 0.0:
				if _next_move_is_shake:
					_clap_y = clampf(global_position.y + shake_grab_drop, 40.0, _screen.y - 40.0)
					_clap_phase = BadgerClapPhase.SHAKE_GRAB
				else:
					_clap_phase = BadgerClapPhase.TO_BELT
				_next_move_is_shake = not _next_move_is_shake

		BadgerClapPhase.SHAKE_GRAB:
			# Fly out and grab the belts, claws turned toward them.
			var all_there := true
			for arm in arms:
				var target := Vector2(_belt_x(_arm_side[arm]), _clap_y)
				if not _move_arm(arm, target, arm_to_belt_speed * delta):
					all_there = false
				_set_arm_turn(arm, move_toward(float(_arm_turn[arm]), -1.0, delta / maxf(arm_turn_time, 0.01)))
			if all_there:
				for arm in arms:
					_set_arm_turn(arm, -1.0)
				var arena = _get_arena()
				if arena and arena.has_method("shake_side"):
					for arm in arms:
						arena.shake_side(_arm_side[arm], shake_time, shake_strength)
				_clap_phase = BadgerClapPhase.SHAKE
				_clap_timer = shake_time

		BadgerClapPhase.SHAKE:
			_clap_timer -= delta
			for arm in arms:
				arm.global_position = Vector2(_belt_x(_arm_side[arm]), _clap_y) \
						+ Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_strength
			if _clap_timer <= 0.0:
				for arm in arms:
					_shake_off_belt(_arm_side[arm])
				GameShell.shake_screen(0.3, 2.5)
				_clap_phase = BadgerClapPhase.RETURN

		BadgerClapPhase.TO_BELT:
			# Fly sideways out onto the belts, staying at the same height.
			var all_there := true
			for arm in arms:
				var target := Vector2(_belt_x(_arm_side[arm]), arm.global_position.y)
				if not _move_arm(arm, target, arm_to_belt_speed * delta):
					all_there = false
			if all_there:
				_clap_phase = BadgerClapPhase.RIDE
				_speed_up_belts()

		BadgerClapPhase.RIDE:
			# Ride the belts down until level with the player (or near the
			# bottom if the player is somehow lower than that).
			var player := _get_player()
			var target_y: float = _screen.y - 24.0
			if player:
				target_y = minf(player.global_position.y, target_y)
			var reached := false
			for arm in arms:
				# Set the whole screen position (not just y) every frame - the arms
				# are children of the drifting boss, so otherwise they'd slide
				# sideways with the head instead of staying on the belt.
				arm.global_position = Vector2(_belt_x(_arm_side[arm]), arm.global_position.y + arm_ride_speed * delta)
				if arm.global_position.y >= target_y:
					reached = true
			if reached:
				_clap_y = arms[0].global_position.y
				for arm in arms:
					arm.global_position = Vector2(_belt_x(_arm_side[arm]), _clap_y)
				_restore_belts()
				_clap_phase = BadgerClapPhase.WINDUP
				_clap_timer = arm_windup_time

		BadgerClapPhase.WINDUP:
			# Brief pause with a shiver so the player sees it coming.
			# The arms also turn to face each other: fists toward the middle,
			# jets pointing out left and right.
			_clap_timer -= delta
			var turn: float = 1.0 - clampf(_clap_timer / maxf(arm_windup_time, 0.01), 0.0, 1.0)
			for arm in arms:
				arm.global_position = Vector2(_belt_x(_arm_side[arm]) + randf_range(-1, 1), _clap_y)
				_set_arm_turn(arm, turn)
			if _clap_timer <= 0.0:
				for arm in arms:
					_set_arm_turn(arm, 1.0)
				_clap_phase = BadgerClapPhase.CLAP

		BadgerClapPhase.CLAP:
			if arms.size() == 1:
				# Lone arm: punch straight across into the other belt.
				var arm = arms[0]
				var hit_side: int = -int(_arm_side[arm])
				var target := Vector2(_belt_edge_x(hit_side) - hit_side * punch_dig_in, _clap_y)
				if _move_arm(arm, target, arm_clap_speed * delta):
					_belt_burst(hit_side, _clap_y)
					_clap_phase = BadgerClapPhase.RETURN
			else:
				var mid := _screen.x * 0.5
				var all_met := true
				for arm in arms:
					# The two arms stop just either side of the middle.
					var target := Vector2(mid + _arm_side[arm] * arm_meet_gap, _clap_y)
					if not _move_arm(arm, target, arm_clap_speed * delta):
						all_met = false
				if all_met:
					_release_shockwave(Vector2(mid, _clap_y))
					_clap_phase = BadgerClapPhase.RETURN

		BadgerClapPhase.RETURN:
			var all_home := true
			for arm in arms:
				var home: Vector2 = global_position + _arm_rest[arm]
				if not _move_arm(arm, home, arm_return_speed * delta):
					all_home = false
				# Turn back upright (jet pointing up) on the way home.
				_set_arm_turn(arm, move_toward(float(_arm_turn[arm]), 0.0, delta / maxf(arm_turn_time, 0.01)))
			if all_home:
				for arm in arms:
					arm.position = _arm_rest[arm]
					_set_arm_turn(arm, 0.0)
				_clap_phase = BadgerClapPhase.IDLE
				_clap_timer = arm_attack_interval


func _set_arm_turn(arm: Node2D, amount: float) -> void:
	"""0 = resting pose (jet up). 1 = turned a quarter turn so the jet points
	out to the arm's side (left belt arm: jet left, right belt arm: jet
	right) and the fist points at the other arm. Turns the art and hitbox
	together."""
	_arm_turn[arm] = amount
	var rot: float = _arm_rest_rot[arm] + _arm_side[arm] * PI * 0.5 * amount
	for child_name in ["Sprite2D", "CollisionPolygon2D"]:
		var n := arm.get_node_or_null(child_name) as Node2D
		if n:
			n.rotation = rot


func _living_arms() -> Array:
	var out: Array = []
	for arm in [left_arm, right_arm]:
		if _arm_alive(arm):
			out.append(arm)
	return out


func _move_arm(arm: Node2D, target: Vector2, step: float) -> bool:
	"""Move an arm toward a screen position. True once it's there."""
	arm.global_position = arm.global_position.move_toward(target, step)
	return arm.global_position.distance_to(target) < 0.5


func _get_arena() -> Node:
	return get_tree().get_first_node_in_group("arena_bounds")


func _belt_x(side: int) -> float:
	"""Middle of the left (-1) or right (1) conveyor belt, in screen px."""
	var wall := 26.0
	var arena = _get_arena()
	if arena and arena.has_method("get_inner_x_limits"):
		wall = arena.get_inner_x_limits().x
	return wall * 0.5 if side < 0 else _screen.x - wall * 0.5


func _belt_edge_x(side: int) -> float:
	"""Inner (play-area) edge of the left (-1) or right (1) belt, in screen px."""
	var wall := 26.0
	var arena = _get_arena()
	if arena and arena.has_method("get_inner_x_limits"):
		wall = arena.get_inner_x_limits().x
	return wall if side < 0 else _screen.x - wall


func _belt_burst(side: int, y: float) -> void:
	"""The lone arm just punched the belt on `side` at height y: a shockwave
	bursts out from the impact (jump it, same as the clap's) and a bee flies
	out of the belt across to the far side."""
	var hit_point := Vector2(_belt_edge_x(side), y)
	_release_shockwave(hit_point)
	var arena = _get_arena()
	if arena and arena.has_method("shake_side"):
		arena.shake_side(side, 0.3, 2.0)
	for i in punch_bee_count:
		_spawn_belt_bee(side, y + randf_range(-20.0, 20.0), i * belt_bee_stagger)


func _shake_off_belt(side: int) -> void:
	"""A shaken belt throws off shake_walls_per_belt honey walls (spread down
	its length, flying across the screen) and shake_bees_per_belt bees."""
	var edge := _belt_edge_x(side)
	var out := Vector2(-side, 0)   # away from the belt
	var tilt := deg_to_rad(shake_wall_angle_deg)
	var n := maxi(shake_walls_per_belt, 1)
	for i in n:
		# Spread down the belt; the two belts are offset half a step so their
		# walls don't line up and collide in the middle.
		var step := (_screen.y - 80.0) / n
		var y: float = 40.0 + step * (i + (0.25 if side < 0 else 0.75))
		var dir := out.rotated(randf_range(-tilt, tilt))
		var wall := WALL_SCENE.instantiate()
		GameShell.game_root().add_child(wall)
		wall.start(Vector2(edge, y), dir)
	for i in shake_bees_per_belt:
		_spawn_belt_bee(side, randf_range(50.0, _screen.y * 0.6), i * belt_bee_stagger)


func _spawn_belt_bee(side: int, y: float, delay: float) -> void:
	"""One bee comes out of the belt on `side` at height y and flies across
	(roughly - it weaves) to just off the far side of the screen. Spawned
	through the level so it scores and counts as an enemy like any other."""
	var level = get_parent()
	if level == null or not level.has_method("spawn_solo"):
		return
	var start_y := clampf(y, 30.0, _screen.y - 30.0)
	var end_y := clampf(start_y + randf_range(-30.0, 30.0), 20.0, _screen.y - 20.0)
	var far_x: float = _screen.x + 40.0 if side < 0 else -40.0
	level.spawn_solo(BEE_SCENE, Vector2(_belt_x(side), start_y), Vector2(far_x, end_y), delay)


func _speed_up_belts() -> void:
	# The belts visibly speed up to carry the arms down.
	var arena = _get_arena()
	if arena and "scroll_speed" in arena:
		_belt_speed_before = arena.scroll_speed
		arena.scroll_speed = arm_ride_speed


func _restore_belts() -> void:
	var arena = _get_arena()
	if arena and "scroll_speed" in arena and arena.scroll_speed == arm_ride_speed:
		arena.scroll_speed = _belt_speed_before


func _release_shockwave(at: Vector2) -> void:
	var wave = ShockwaveScript.new()
	wave.damage = shockwave_damage
	wave.expand_speed = shockwave_speed
	wave.position = at
	get_parent().add_child(wave)
	GameShell.shake_screen(0.25, 3.0)


# ============================================================
# LASER SWEEP (only the head left)
# ============================================================

func _process_sweep(delta: float) -> void:
	match _sweep_phase:
		BadgerSweepPhase.IDLE:
			# Drift as normal until the next sweep.
			_float_t += delta
			position = _float_position()
			_sweep_timer -= delta
			if _sweep_timer <= 0.0:
				_sweep_phase = BadgerSweepPhase.TO_START

		BadgerSweepPhase.TO_START:
			var start := Vector2(_sweep_start_x(), _home.y)
			position = position.move_toward(start, sweep_reposition_speed * delta)
			if position.distance_to(start) < 0.5:
				_sweep_phase = BadgerSweepPhase.CHARGE
				_sweep_timer = sweep_charge_time
				_set_eye_visuals(BadgerEyeState.CHARGING)

		BadgerSweepPhase.CHARGE:
			_sweep_timer -= delta
			_layout_lasers()
			_charge_shake(1.0 - clampf(_sweep_timer / maxf(sweep_charge_time, 0.01), 0.0, 1.0))
			if _sweep_timer <= 0.0:
				_sweep_phase = BadgerSweepPhase.FIRE
				_sweep_hit_cooldown = 0.0
				_set_eye_visuals(BadgerEyeState.FIRING)
				GameShell.shake_screen(0.15, 1.5)

		BadgerSweepPhase.FIRE:
			position.x += sweep_speed * delta
			_layout_lasers()
			_sweep_hit_cooldown -= delta
			if _sweep_hit_cooldown <= 0.0:
				for area in _laser_box.get_overlapping_areas():
					# Mid-jump (or the grace right after landing) the beams
					# pass underneath - that's how you dodge this one.
					if area is Player and not PlayerHealth.is_invincible(area as Player):
						(area as Player).take_damage(laser_damage)
						_sweep_hit_cooldown = laser_damage_interval
						break
			if position.x >= _sweep_end_x():
				_set_eye_visuals(BadgerEyeState.READY)
				_sweep_phase = BadgerSweepPhase.BACK

		BadgerSweepPhase.BACK:
			var back := _float_position()
			position = position.move_toward(back, sweep_reposition_speed * delta)
			if position.distance_to(back) < 0.5:
				_sweep_phase = BadgerSweepPhase.IDLE
				_sweep_timer = sweep_interval


func _sweep_start_x() -> float:
	"""Head x where the leading (rightmost) beam sits at the left belt's edge,
	so the sweep covers the whole play area."""
	var lead := 0.0
	for eye in eye_offsets:
		lead = maxf(lead, eye.x)
	return _belt_edge_x(-1) - lead


func _sweep_end_x() -> float:
	"""Head x where the trailing (leftmost) beam reaches the right belt's edge."""
	var trail := 0.0
	for eye in eye_offsets:
		trail = minf(trail, eye.x)
	return _belt_edge_x(1) - trail


# ============================================================
# CIGAR (only the head left)
# ============================================================

func _process_cigar(delta: float) -> void:
	# Only between sweeps, so it never stacks on top of the laser.
	if _sweep_phase != BadgerSweepPhase.IDLE:
		return
	_cigar_timer -= delta
	if _cigar_timer > 0.0:
		return
	_cigar_timer = cigar_interval
	var player := _get_player()
	var from := head.global_position + cigar_mouth_offset
	var dir := Vector2.DOWN
	if player:
		dir = (player.global_position - from).normalized()
	var cigar = CIGAR_SCENE.instantiate()
	var level = get_parent()
	level.add_child(cigar)
	cigar.launch(from, dir)
	if level.has_method("_on_enemy_died"):
		cigar.died.connect(level._on_enemy_died)
