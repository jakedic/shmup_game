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

# No change_levels() override here anymore - BaseLevel.change_levels()
# already handles this correctly: when launched from the overworld it
# reports the win back to GameProgress, and when played standalone (no
# level_paths["next_level"] set, and no level_3.tscn) it falls back to the
# title screen on its own.
