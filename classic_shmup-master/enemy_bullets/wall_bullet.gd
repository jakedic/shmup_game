# wall_bullet.gd
# The hive enemy's "wall" projectile (see enemies/hive_solo.gd): a wide, thin
# bar that travels broadside-first, rotated so its long edge is always
# perpendicular to its direction of travel. Drawn as a code-built Polygon2D
# placeholder; swap in real art by adding a Sprite2D to wall_bullet.tscn.
#
# Player bullets pass through walls rather than destroying them (see
# handle_player_bullet_collision below) - delete that override if walls
# should be shootable.
extends EnemyBullet
class_name WallBullet

const WALL_SIZE := Vector2(24.0, 5.0)   # keep in sync with the collision shape in wall_bullet.tscn
const WALL_COLOR := Color(0.85, 0.55, 0.05, 1.0)  # honey amber, matches the hive theme


func _ready():
	speed = 60.0
	damage = 1
	max_distance = 500.0
	pierce_count = 0
	homing_enabled = false
	bounce_count = 0

	add_to_group("enemy_bullet")
	_build_wall_shape()


func custom_start():
	# Art is wide along x; rotate so that width sits across the direction of travel.
	rotation = direction.angle() - Vector2.DOWN.angle()


func handle_player_bullet_collision(_area: Area2D):
	pass  # walls can't be shot down


func _build_wall_shape() -> void:
	if has_node("Wall"):
		return
	var wall := Polygon2D.new()
	wall.name = "Wall"
	wall.color = WALL_COLOR
	var h := WALL_SIZE / 2.0
	wall.polygon = PackedVector2Array([
		Vector2(-h.x, -h.y), Vector2(h.x, -h.y), Vector2(h.x, h.y), Vector2(-h.x, h.y)
	])
	add_child(wall)
