# empty.gd
# A blank level: the player, HUD, background, and pause menu all work, but
# nothing spawns and the level never ends on its own. Use it as a sandbox or
# as a starting point for a new level.
extends BaseLevel

func _ready():
	enemy_scenes = []
	max_waves = 1

	super._ready()

# No enemies.
func spawn_enemies():
	pass

# BaseLevel normally ends the wave (and the level) as soon as no enemies are
# left. With nothing to spawn that would happen instantly, so stay put.
func handle_wave_completion():
	pass
