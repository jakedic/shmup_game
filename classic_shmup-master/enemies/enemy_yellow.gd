# yellow_enemy.gd
extends BaseEnemy
class_name YellowEnemy

func _ready():
	# Set yellow enemy specific properties
	max_health = 3  # Yellow enemies have 3 health
	current_health = max_health
	bullet_scene = preload("res://bullets/enemy_bullet.tscn")
	
	# Set yellow color
	modulate = Color.YELLOW

# Optional: Override take_damage for yellow enemy specific behavior

	
func get_enemy_type():
	return 1
