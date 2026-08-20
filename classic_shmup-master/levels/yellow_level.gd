# yellow_level.gd
# "Yellow Level" - the new first level of a run (see game_progress.gd's
# START_ID override), built to show off the new squad-based yellow enemy
# behavior in enemies/yellow_squad.gd instead of the old grid-drop spawn.
#
# Four waves. Waves 1-3 each spawn one or more independent YellowSquad
# instances (see _spawn_squad()) - NOT enemy_anchor.position.x, which is
# just the (0,0) sway-offset origin the normal grid enemies add to their own
# start_pos, not a meaningful screen position:
#   Wave 1 - a single squad straight down the middle.
#   Wave 2 - two squads, one about a quarter of the way in from the left
#            edge, one about a quarter of the way in from the right edge.
#   Wave 3 - three squads (quarter / half / three-quarter across the
#            screen), each drifting diagonally during their attack dives
#            (see YellowSquad.diagonal_vx) instead of falling straight down.
# Every wave's squads are staggered in start time (SQUAD_STAGGER_DELAY, see
# YellowSquad.start_delay) so they descend one after another rather than all
# at once.
#
# Wave 4 is the end-of-level miniboss (see enemies/yellow_miniboss.gd) - a
# single 30-health "giant mound of yellow enemies" that periodically retreats
# offscreen and has the level spawn two regular-pattern YellowSquad "adds"
# (see _on_miniboss_retreat_started()/_on_miniboss_add_died()) before coming
# back down for another round, repeating until it's out of health. Because
# base_level.gd's wave-clear check just watches the "enemies" group empty out
# (see its _process()), and the miniboss itself stays in that group (alive,
# just invisible/uncollidable) for the whole retreat/adds cycle, none of that
# back-and-forth is mistaken for the wave being cleared - the wave only ends
# once the boss actually dies.
#
# After the fourth wave is cleared, play continues into the original
# level_1.
extends BaseLevel

const SQUAD_STAGGER_DELAY := 1.5   # seconds between one squad starting its dive and the next
const DIAGONAL_SPEED := 35.0       # px/s of sideways drift during wave 3's attack dives

var enemy_yellow_scene = preload("res://enemies/enemy_yellow.tscn")
var yellow_miniboss_scene = preload("res://enemies/yellow_miniboss.tscn")

# Tracks the live miniboss instance (wave 4) and how many of its current pair
# of add-squad enemies are still alive - see _on_miniboss_retreat_started()
# and _on_miniboss_add_died().
var _current_miniboss: YellowMiniboss = null
var _miniboss_adds_remaining: int = 0

func _ready():
	# Set up level-specific data
	enemy_scenes = [enemy_yellow_scene]
	level_paths = {
		"next_level": "res://levels/level_1.tscn"
	}
	max_waves = 4

	# Call parent _ready after setting up level-specific data
	super._ready()

# Override the default grid-drop spawn pattern - see the class comment above
# for what each wave spawns. base_level.gd calls this once per wave (via
# new_game() for wave 1, then handle_wave_completion() for each wave after),
# with current_wave already set to this wave's index (0-based) by the time
# it's called.
func spawn_enemies():
	var screen_w: float = get_viewport_rect().size.x
	match current_wave:
		0:
			_spawn_squad(screen_w / 2.0, 0.0)
		1:
			_spawn_squad(screen_w * 0.25, 0.0)
			_spawn_squad(screen_w * 0.75, SQUAD_STAGGER_DELAY)
		2:
			_spawn_squad(screen_w * 0.25, 0.0, DIAGONAL_SPEED)
			_spawn_squad(screen_w * 0.5, SQUAD_STAGGER_DELAY, -DIAGONAL_SPEED)
			_spawn_squad(screen_w * 0.75, SQUAD_STAGGER_DELAY * 2.0, DIAGONAL_SPEED)
		3:
			_spawn_miniboss()
		_:
			# Shouldn't happen with max_waves = 4, but fall back to a single
			# center squad rather than spawning nothing.
			_spawn_squad(screen_w / 2.0, 0.0)

func _spawn_squad(lane_x: float, start_delay: float, diagonal_vx: float = 0.0) -> YellowSquad:
	var squad := YellowSquad.new()
	squad.enemy_scene = enemy_yellow_scene
	squad.lane_x = lane_x
	squad.circle_center = Vector2(lane_x, 70.0)
	squad.start_delay = start_delay
	squad.diagonal_vx = diagonal_vx
	squad.enemy_died.connect(_on_enemy_died)
	add_child(squad)
	return squad

func _spawn_miniboss() -> void:
	var boss: YellowMiniboss = yellow_miniboss_scene.instantiate()
	add_child(boss)
	boss.died.connect(_on_enemy_died)
	boss.retreat_started.connect(_on_miniboss_retreat_started)
	_current_miniboss = boss
	var screen_w: float = get_viewport_rect().size.x
	boss.start(Vector2(screen_w / 2.0, 90.0))

# Fires each time the miniboss crosses a retreat health threshold (see
# yellow_miniboss.gd's custom_take_damage()/retreat_started) and goes
# invincible/offscreen. Spawns the same two quarter/three-quarter lanes as
# wave 2, but with diagonal_vx left at its 0.0 default - "their regular
# pattern", not wave 3's diagonal dive - and counts their deaths separately
# from the normal score-only _on_enemy_died() hookup so resume_after_adds()
# can be called the instant both squads are gone.
func _on_miniboss_retreat_started() -> void:
	var screen_w: float = get_viewport_rect().size.x
	_miniboss_adds_remaining = YellowSquad.SQUAD_SIZE * 2
	var left_squad := _spawn_squad(screen_w * 0.25, 0.0)
	var right_squad := _spawn_squad(screen_w * 0.75, SQUAD_STAGGER_DELAY)
	left_squad.enemy_died.connect(_on_miniboss_add_died)
	right_squad.enemy_died.connect(_on_miniboss_add_died)

func _on_miniboss_add_died(_value: int) -> void:
	_miniboss_adds_remaining -= 1
	if _miniboss_adds_remaining <= 0 and is_instance_valid(_current_miniboss):
		_current_miniboss.resume_after_adds()
