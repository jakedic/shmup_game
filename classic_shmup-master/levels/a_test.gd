# a_test.gd
#
# Scratch/test level for trying out new enemies. Right now it shows off the
# flower enemy (enemies/flower_enemy.gd) and the flower squad
# (enemies/flower_squad.gd). Waves alternate: a flower squad, then a batch of
# solo flowers, then a squad again, and so on - a new wave drops in every
# time the last one is gone (shot or drifted off the bottom), so you can keep
# watching as long as you like. Pause -> Quit to leave.
extends BaseLevel

const FLOWER = preload("res://enemies/flower_enemy.tscn")

func _ready():
	level_paths = {
		"next_level": "res://levels/test_menu.tscn"
	}
	max_waves = 999  # keep dropping new waves
	super._ready()

func spawn_enemies():
	if current_wave % 2 == 0:
		_spawn_squad_wave()
	else:
		_spawn_solo_wave()

func _spawn_squad_wave():
	# Three flowers in a synced column, front flower starting just above
	# the screen at the center.
	spawn_flower_squad({"scene": FLOWER, "start": Vector2(120, -20)})

func _spawn_solo_wave():
	# Flowers start at different heights above the screen so they float in
	# one after another instead of all at once.
	spawn_flower({"scene": FLOWER, "start": Vector2(60, -20)})
	spawn_flower({"scene": FLOWER, "start": Vector2(180, -90)})
	spawn_flower({"scene": FLOWER, "start": Vector2(120, -160)})
	# Example of tweaking one flower's motion: wider, slower, lazier swing.
	spawn_flower({"scene": FLOWER, "start": Vector2(90, -240), "sway_width": 55.0, "sway_time": 3.5, "fall_speed": 20.0})
	# ...and a quicker, tighter one.
	spawn_flower({"scene": FLOWER, "start": Vector2(170, -300), "sway_width": 22.0, "sway_time": 1.6, "fall_speed": 40.0})
