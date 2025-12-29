# basic_enemy.gd (was enemy.gd)
extends "res://base_enemy.gd"  # Inherits from base class
class_name YellowEnemy

# Override bullet_scene with specific bullet
#@export var bullet_scene: PackedScene = preload("res://enemy_bullet.tscn")

func _on_shoot_timer_timeout():
	# Call parent's shoot method with our position
	shoot_bullet(position)
	$ShootTimer.wait_time = randf_range(4, 20)
	$ShootTimer.start()
	
func get_enemy_type():
	return 1
