# a_test.gd
#
# Scratch/test level for trying out new enemies. Right now it shows off the
# flower enemy (enemies/flower_enemy.gd) and the flower squad
# (enemies/flower_squad.gd). Built the same way as Yellow/Dylan Level - one
# function per wave, each spawn a labeled config (see
# levels/squad_wave_level.gd's header comment for every field). Unlike those
# levels, the waves here loop forever (squad, solos, squad, solos, ...) so
# you can keep watching as long as you like. Pause -> Quit to leave.
extends SquadWaveLevel

const FLOWER := preload("res://enemies/flower_enemy.tscn")


# Wave 1 - one flower squad down the middle, firing at the top of the screen
# and again about 40% of the way down.
func _wave_1() -> void:
	spawn_flower_squad_wave({"enemy": FLOWER, "start_percent": LANE_CENTER, "attack_heights": [0.0,0.2, 0.4]})


# Wave 2 - solo flowers dropping in one after another. The first three
# choose exactly where they fire with attack_heights; the last two use the
# default (fire every couple of swings).
func _wave_2() -> void:
	spawn_flower_wave({"enemy": FLOWER, "start_percent": LANE_LEFT, "attack_heights": [0.15, 0.5]})
	spawn_flower_wave({"enemy": FLOWER, "start_percent": LANE_RIGHT, "start_delay": 2.5, "attack_heights": [0.3]})
	spawn_flower_wave({"enemy": FLOWER, "start_percent": LANE_CENTER, "start_delay": 5.0, "attack_heights": [0.1, 0.35, 0.6]})
	# Example of tweaking one flower's motion: wider, slower, lazier swing.
	spawn_flower_wave({"enemy": FLOWER, "start_percent": 0.35, "start_delay": 8.0, "sway_width": 55.0, "sway_time": 3.5, "fall_speed": 20.0})
	# ...and a quicker, tighter one.
	spawn_flower_wave({"enemy": FLOWER, "start_percent": 0.7, "start_delay": 10.0, "sway_width": 22.0, "sway_time": 1.6, "fall_speed": 40.0})


func _ready() -> void:
	level_paths = {
		"next_level": "res://levels/test_menu.tscn"
	}
	waves = [_wave_1, _wave_2]
	fallback_enemy = FLOWER
	super._ready()
	max_waves = 999  # keep looping the waves (see spawn_enemies() below)


func spawn_enemies() -> void:
	# Loop through `waves` forever instead of ending after the last one.
	waves[current_wave % waves.size()].call()
