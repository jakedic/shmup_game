# boss_cigar.gd
#
# The badger's cigar, spat out of its mouth once only the head is left (see
# enemies/boss_badger.gd). A slow projectile with LIGHT homing: it turns a
# little toward the player as it flies, but can't turn sharply, and stops
# homing for good once it has passed the player - so dodging sideways makes
# it miss and drift off screen.
#
# It's an enemy, not a bullet:
#   - shoot it 3 times (max_health) to destroy it
#   - absorb it to get the gray transformation, with the bonus that your
#     shots lightly home in on the nearest enemy while it lasts (see
#     PlayerTransformations.transform_gray())
#   - touching it hurts like touching any enemy
#
# Drawn in code (tube + blue band + glowing red tip) to match the cigar in
# the badger art, which is baked into the head sprite and can't be cut out.
extends "res://enemies/base_enemy.gd"

@export var travel_speed: float = 45.0        # px/s - slow on purpose
@export var turn_rate_deg: float = 40.0       # max degrees/second it can turn toward the player (light homing)
@export var homing_time: float = 4.0          # stops homing after this many seconds even if it hasn't passed the player
@export var offscreen_despawn_margin: float = 24.0

const BODY_LENGTH := 15.0
const BODY_THICK := 5.0
const BODY_COLOR := Color(0.72, 0.69, 0.8)
const BAND_COLOR := Color(0.33, 0.52, 0.69)
const OUTLINE_COLOR := Color(0.05, 0.05, 0.08)
const TIP_COLOR := Color(1.0, 0.1, 0.12)

var _dir := Vector2.DOWN
var _homing := true
var _homing_left := 0.0
var _launched := false
var _t := 0.0


func custom_ready():
	can_shoot = false
	can_dive = false
	follow_anchor_enabled = false


func launch(start_pos: Vector2, direction: Vector2) -> void:
	position = start_pos
	_dir = direction.normalized() if direction.length() > 0.0 else Vector2.DOWN
	rotation = _dir.angle()
	_homing_left = homing_time
	_launched = true


func start(pos: Vector2) -> void:
	# Fallback for the generic start(pos) spawn pattern - just fly down.
	launch(pos, Vector2.DOWN)


func custom_process(delta: float):
	if not _launched:
		return
	_t += delta
	if _homing:
		_steer(delta)
	position += _dir * travel_speed * delta
	rotation = _dir.angle()
	queue_redraw()


func _steer(delta: float) -> void:
	_homing_left -= delta
	var player = get_tree().get_first_node_in_group("player")
	if _homing_left <= 0.0 or not (player is Node2D) or not player.is_alive:
		_homing = false
		return
	var to_player: Vector2 = player.global_position - global_position
	# Once it's gone past the player it gives up and just keeps going.
	if to_player.dot(_dir) <= 0.0:
		_homing = false
		return
	var max_turn := deg_to_rad(turn_rate_deg) * delta
	var angle_diff := _dir.angle_to(to_player)
	_dir = _dir.rotated(clampf(angle_diff, -max_turn, max_turn))


func handle_boundaries():
	# Missed - quietly leave once it's off screen (no score, no explosion).
	if not _launched:
		return
	var m := offscreen_despawn_margin
	if position.x < -m or position.x > screensize.x + m or position.y < -m or position.y > screensize.y + m:
		is_alive = false
		queue_free()


func die(context: Dictionary = {}):
	# The absorb beam kills enemies outright with die() while they still
	# have health left (shots bring health to 0 first). Use that to flag the
	# homing version of the gray transformation for the absorb that's about
	# to land - PlayerTransformations.transform_gray() picks it up.
	if is_alive and current_health > 0:
		var player = get_tree().get_first_node_in_group("player")
		if player:
			player.set_meta("gray_homing_next", true)
	super.die(context)


func get_enemy_type():
	# Absorbing the cigar -> gray transformation (the homing version, see die()).
	return 'gray'


func _draw() -> void:
	# Drawn pointing along +x; the node's rotation aims it. Lit end leads.
	var half_l := BODY_LENGTH * 0.5
	var half_t := BODY_THICK * 0.5
	var body := Rect2(Vector2(-half_l, -half_t), Vector2(BODY_LENGTH, BODY_THICK))
	draw_rect(body.grow(0.8), OUTLINE_COLOR)
	draw_rect(body, BODY_COLOR)
	draw_rect(Rect2(Vector2(-half_l + BODY_LENGTH * 0.3, -half_t), Vector2(BODY_LENGTH * 0.18, BODY_THICK)), BAND_COLOR)
	# Glowing, flickering tip.
	var glow_a: float = 0.35 + 0.2 * sin(_t * 14.0)
	draw_circle(Vector2(half_l + 0.5, 0), 4.5, Color(TIP_COLOR, glow_a * 0.6))
	draw_circle(Vector2(half_l + 0.5, 0), 3.0, Color(TIP_COLOR, glow_a))
	draw_circle(Vector2(half_l, 0), half_t + 0.6, OUTLINE_COLOR)
	draw_circle(Vector2(half_l, 0), half_t - 0.2, TIP_COLOR)
