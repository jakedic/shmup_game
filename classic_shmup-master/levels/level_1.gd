# level_1.gd
extends BaseLevel

var enemy_yellow = preload("res://Enemies/enemy_yellow.tscn")
var enemy_red = preload("res://Enemies/enemy_red.tscn")

func _ready():
	# Set up level-specific data
	enemy_scenes = [enemy_yellow, enemy_red]
	level_paths = {
		"next_level": "res://levels/level_2.tscn"
	}
	max_waves = 2  # This level only has 2 waves
	
	# Call parent _ready after setting up level-specific data
	super._ready()

# Optional: Override spawn pattern for this specific level
func spawn_enemies():
	# You could override with a custom pattern, or use default
	super.spawn_enemies()  # Use parent's implementation
