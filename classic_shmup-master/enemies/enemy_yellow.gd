# yellow_enemy.gd
extends BaseEnemy
class_name YellowEnemy

func _ready():
	# Set yellow enemy specific properties
	max_health = 3  # Yellow enemies have 3 health
	current_health = max_health
	bullet_scene = preload("res://enemy_bullets/enemy_bullet.tscn")
	
	# Set yellow color
	#modulate = Color.YELLOW

# Optional: Override take_damage for yellow enemy specific behavior
func take_damage(damage_amount: int = 1):
	# Yellow enemies take less damage? Or have special effect?
	# For example: yellow enemies flash yellow when hit
	var original_modulate = modulate
	modulate = Color(1, 1, 0.5)  # Brighter yellow
	await get_tree().create_timer(0.1).timeout
	modulate = original_modulate
	
	# Call parent take_damage
	return super.take_damage(damage_amount)
	
func get_enemy_type():
	return 1
