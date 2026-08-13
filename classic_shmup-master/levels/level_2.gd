# level_2.gd
extends BaseLevel

var enemy_yellow = preload("res://Enemies/enemy_yellow.tscn")
var enemy_red = preload("res://Enemies/enemy_red.tscn")

func _ready():
	# Set up level-specific data (same enemies/wave count as level 1)
	enemy_scenes = [enemy_yellow, enemy_red]
	max_waves = 2  # Same wave count as level 1

	# Call parent _ready after setting up level-specific data
	super._ready()

# Optional: Override spawn pattern for this specific level
func spawn_enemies():
	super.spawn_enemies()  # Use parent's implementation

# This is the one difference from level 1: once all of this level's waves
# are cleared, send the player back to the home/title screen instead of
# trying to advance to a level 3.
func change_levels():
	get_tree().change_scene_to_file("res://levels/title_screen.tscn")
