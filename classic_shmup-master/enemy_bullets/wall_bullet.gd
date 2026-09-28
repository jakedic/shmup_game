# wall_bullet.gd
# The hive enemy's "wall" projectile (see enemies/hive_solo.gd): a wide, thin
# bar that travels broadside-first, rotated so its long edge is always
# perpendicular to its direction of travel. Drawn as a code-built Polygon2D
# placeholder; swap in real art by adding a Sprite2D to wall_bullet.tscn.
#
# Walls BLOCK player bullets: any player bullet that touches a wall is
# destroyed, while the wall itself is untouched and keeps travelling (see
# handle_player_bullet_collision below). This ignores the global
# Bullet.bullet_vs_bullet_collision_enabled switch on purpose - walls always
# block. Bubbles aren't in the "player_bullet" group, so they're unaffected.
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


func handle_player_bullet_collision(area: Area2D):
	# Wall survives; the player's bullet is absorbed.
	if is_queued_for_deletion() or area.is_queued_for_deletion():
		return
	area.queue_free()


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
