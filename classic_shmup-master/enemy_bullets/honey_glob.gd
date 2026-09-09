# honey_glob.gd
# Placeholder bullet for the hive enemy's honey-spread attack (see
# enemies/hive_solo.gd's header comment). A "glob of honey" drawn as a plain
# filled circle (a Polygon2D built in code, in _build_glob_shape() below)
# rather than a real art asset, per the request to use a simple placeholder
# shape here for now. Swapping in real art later just means adding a
# Sprite2D with the actual texture to enemy_bullets/honey_glob.tscn (and
# removing/skipping _build_glob_shape()) - nothing else about this bullet's
# behavior depends on how it's drawn.
extends EnemyBullet
class_name HoneyGlobBullet

const GLOB_RADIUS := 5.0
const GLOB_SEGMENTS := 10
const GLOB_COLOR := Color(0.85, 0.55, 0.05, 1.0)  # honey amber


func _ready():
	# Slow moving, as asked - well below any other enemy bullet's speed
	# (enemy_bullets/enemy_bullet.gd's YellowEnemyBullet is 150).
	speed = 55.0
	damage = 1
	max_distance = 400.0
	pierce_count = 0
	homing_enabled = false
	bounce_count = 0

	add_to_group("enemy_bullet")
	_build_glob_shape()


func _build_glob_shape() -> void:
	if has_node("Glob"):
		return  # already built (e.g. a scene edit added a real sprite instead)
	var glob := Polygon2D.new()
	glob.name = "Glob"
	glob.color = GLOB_COLOR
	var points := PackedVector2Array()
	for i in range(GLOB_SEGMENTS):
		var glob_angle: float = TAU * float(i) / float(GLOB_SEGMENTS)
		points.append(Vector2(cos(glob_angle), sin(glob_angle)) * GLOB_RADIUS)
	glob.polygon = points
	add_child(glob)
