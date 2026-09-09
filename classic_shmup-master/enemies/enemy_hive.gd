# enemy_hive.gd
extends BaseEnemy
class_name HiveEnemy

# ===== FACING =====
# Same convention as enemies/enemy_yellow.gd's BeeEnemy - the sprite's
# unrotated art faces "down", and rotation is derived every frame from
# actual movement direction. enemies/hive_solo.gd drives this enemy's
# position along its own custom dog-leg path and calls _update_facing()
# itself every frame (same way enemies/yellow_solo.gd does for a BeeEnemy),
# so this class doesn't need any dive/zigzag movement of its own right now -
# just health, facing, and the standard death/explosion handling it already
# gets for free from base_enemy.gd.
@export var facing_min_speed: float = 1.0  # below this speed (px/s), keep last facing instead of jittering

var last_position: Vector2 = Vector2.ZERO


func _ready():
	# Set hive enemy specific properties
	max_health = 3   # tougher than a bee enemy's 1 health
	current_health = max_health
	bullet_scene = preload("res://enemy_bullets/enemy_bullet.tscn")

	add_to_group("enemy")


func custom_start(pos: Vector2):
	"""Called every time this enemy (re)spawns - make sure facing starts
	clean and last_position is seeded so the very first _update_facing()
	call doesn't see a bogus jump from (0,0)."""
	rotation = 0.0
	last_position = pos


func get_enemy_type():
	return 'hive'


func _update_facing(delta: float):
	"""Point the sprite the way it's actually moving this frame - identical
	rotation math to enemies/enemy_yellow.gd's BeeEnemy._update_facing(), so
	an external path controller (enemies/hive_solo.gd) can drive this
	enemy's facing the same way enemies/yellow_solo.gd already does for a
	BeeEnemy."""
	if delta <= 0.0:
		return
	var velocity = (position - last_position) / delta
	if velocity.length() >= facing_min_speed:
		rotation = velocity.angle() - Vector2.DOWN.angle()
	last_position = position
