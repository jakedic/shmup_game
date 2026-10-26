# bomb_ring_formation.gd
#
# Moves a bomb-ring formation (see BaseLevel.spawn_bomb_ring()): a bomb in
# the middle and a tight ring of armored astroids around it. The whole thing
# slides straight down to stop_y, then stays put forever with the astroids
# slowly orbiting the bomb, until everything in it is destroyed.
# With keep_moving on it never stops: it keeps falling at fall_speed and
# quietly removes itself (no explosion) once it's fully below despawn_y.
#
# The members are ordinary enemies parented to the level (so the level's wave
# tracking, scoring and bullets treat them normally) - this node just sets
# their positions every frame. They're marked squad_controlled so their own
# movement code stays out of the way.
extends Node2D

var center := Vector2.ZERO
var stop_y := 100.0
var fall_speed := 30.0
var radius := 36.0
var orbit_speed := deg_to_rad(20.0)   # radians/s
var keep_moving := false   # true = ignore stop_y, fall off the bottom of the screen
var despawn_y := 400.0     # keep_moving only - center y past which the ring is removed
var astroids: Array = []
var bomb: Node2D = null

var _angle := 0.0


func _ready() -> void:
	# Lets levels check whether any bomb ring is still alive, e.g.
	# get_tree().get_nodes_in_group("bomb_rings").is_empty().
	add_to_group("bomb_rings")


func _process(delta: float) -> void:
	if keep_moving:
		center.y += fall_speed * delta
		if center.y > despawn_y:
			_despawn()
			return
	elif center.y < stop_y:
		center.y = minf(center.y + fall_speed * delta, stop_y)
	_angle += orbit_speed * delta

	var any_left := false
	var n := astroids.size()
	for i in n:
		var a = astroids[i]
		if not is_instance_valid(a):
			continue
		any_left = true
		# Fixed slots around the ring - a destroyed astroid leaves a gap
		# rather than the others closing ranks.
		a.position = center + Vector2.from_angle(_angle + TAU * i / n) * radius
		a.rotation += delta * 0.8
	if is_instance_valid(bomb):
		any_left = true
		bomb.position = center

	if not any_left:
		queue_free()


# keep_moving rings: off the bottom of the screen - remove every member
# without dying (no bomb blast, no score), then the formation itself.
func _despawn() -> void:
	for a in astroids:
		if is_instance_valid(a):
			a.queue_free()
	if is_instance_valid(bomb):
		bomb.queue_free()
	queue_free()
