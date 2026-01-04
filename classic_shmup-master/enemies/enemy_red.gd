# basic_enemy.gd (was enemy.gd)
extends "res://enemies/base_enemy.gd"  # Inherits from base class
class_name RedEnemy

# Override bullet_scene with specific bullet
#@export var bullet_scene: PackedScene = preload("res://enemy_bullet.tscn")
func _ready():
	# Set hframes in code (overrides Inspector)
	max_health = 1  # Yellow enemies have 3 health
	current_health = max_health
	$Sprite2D.hframes = 5
	$Sprite2D.vframes = 1  # Also set vframes if needed
	bullet_scene = preload("res://enemy_bullets/enemy_bullet.tscn")  # Change to your actual bullet
	
'''func _on_shoot_timer_timeout():
	# Call parent's shoot method with our position
	shoot_bullet(position)
	$ShootTimer.wait_time = randf_range(4, 20)
	$ShootTimer.start()'''
	
func get_enemy_type():
	return 2
