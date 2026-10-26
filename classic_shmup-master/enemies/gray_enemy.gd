# gray_enemy.gd
#
# "Greyed out" versions of the regular enemies (bee, hive, flower). They look
# like the originals drawn in greyscale, but have none of their behavior - no
# squads, dives, shooting or lasers. They just drift slowly straight down the
# screen. Absorbing one gives the player the gray transformation
# (PlayerTransformations.transform_gray: 1.5x speed, 1.5x damage), and that
# form's bubbles grant gray power-ups (see PlayerPowerUps.get_powerups_for_enemy_type).
#
# Each gray scene (gray_bee.tscn, gray_hive.tscn, gray_flower.tscn) INHERITS
# its original enemy's scene - same sprite, hitbox, idle animation and death
# explosion - and only swaps the root script for this one. So if the original
# art changes, the gray version follows automatically.
#
# Built on astroid_enemy.gd, which already does exactly "travel in a straight
# line, quietly despawn off-screen" - so spawn these with spawn_drift_wave()
# like an astroid (they also fall back to drifting straight down at
# default_travel_speed if spawned with a plain start(pos)).
extends "res://enemies/astroid_enemy.gd"
class_name GrayEnemy

# Default drift speed (px/s) when spawned without one. "Slow" on purpose.
const GRAY_DRIFT_SPEED := 20.0

# Greyscale shader - also set directly on each gray_*.tscn's Sprite2D so it
# shows in the editor. Applied here too as a safety net for any extra sprites.
const GRAYSCALE_SHADER := preload("res://enemies/grayscale.gdshader")


func custom_ready():
	super.custom_ready()   # astroid: no shooting, diving or anchor-following
	# No spin - these slide down upright.
	rotation_speed_min_deg = 0.0
	rotation_speed_max_deg = 0.0
	default_travel_speed = GRAY_DRIFT_SPEED
	split_scene = null
	_apply_greyscale()
	_strip_original_attacks()


func _apply_greyscale() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = GRAYSCALE_SHADER
	for c in get_children():
		if (c is Sprite2D or c is AnimatedSprite2D) and c.material == null:
			c.material = mat


func _strip_original_attacks() -> void:
	# The flower scene carries its laser beam/charge-line sprites and laser
	# hitbox. They're hidden/off by default and only the flower's own script
	# ever turns them on, but remove them so nothing can hit the player.
	for n in ["Beam", "ChargeLine", "LaserHitbox"]:
		var node := get_node_or_null(n)
		if node:
			node.queue_free()


func get_enemy_type():
	# Absorbing any gray enemy -> PlayerTransformations.transform_gray.
	return 'gray'
