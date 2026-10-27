# boss_shockwave.gd
#
# The badger's clap shockwave: a ring that bursts out from where the two arms
# meet and keeps expanding until it's completely off screen. It hurts the
# player (once) if the ring passes over them while they're on the ground -
# jump over it to dodge. Looks like the player's landing shockwave
# (player/landing_shockwave.gd), just bigger, angrier and slower.
#
# Spawned by enemies/boss_badger.gd. Add it to the level (not the boss) so
# it stays where it was released:
#
#     var wave = preload("res://enemies/boss_shockwave.gd").new()
#     wave.position = meet_point
#     level.add_child(wave)
extends Node2D

## Shield damage when the ring hits the player.
var damage: int = 2
## How fast the ring grows, px/second (play area is 240x320).
var expand_speed: float = 110.0
## Ring thickness on screen, px.
var ring_width: float = 4.0
## Extra reach so touching the ship's edge counts, not just its center.
var hit_padding: float = 5.0
var ring_color: Color = Color(1.0, 0.55, 0.2, 0.95)

var _radius: float = 0.0
var _max_radius: float = 0.0
var _hit_player := false


func _ready() -> void:
	z_index = 5
	# Grow until the ring has cleared the farthest corner of the screen.
	var size := get_viewport_rect().size
	for corner in [Vector2.ZERO, Vector2(size.x, 0), Vector2(0, size.y), size]:
		_max_radius = max(_max_radius, position.distance_to(corner))
	_max_radius += ring_width + 4.0


func _process(delta: float) -> void:
	_radius += expand_speed * delta
	_check_player()
	queue_redraw()
	if _radius >= _max_radius:
		queue_free()


func _check_player() -> void:
	if _hit_player:
		return
	var player = get_tree().get_first_node_in_group("player")
	if not (player is Player) or not player.is_alive:
		return
	var dist: float = global_position.distance_to(player.global_position)
	if absf(dist - _radius) > ring_width * 0.5 + hit_padding:
		return
	# Mid-jump (or the brief grace right after landing): the ring passes
	# underneath harmlessly.
	if PlayerHealth.is_invincible(player):
		return
	_hit_player = true
	PlayerHealth.take_damage(player, damage)


func _draw() -> void:
	# Fades a little as it grows so the far edge isn't as harsh.
	var c := ring_color
	c.a *= lerpf(1.0, 0.55, clampf(_radius / maxf(_max_radius, 1.0), 0.0, 1.0))
	draw_arc(Vector2.ZERO, maxf(_radius, 1.0), 0.0, TAU, 64, c, ring_width)
	var glow := c
	glow.a *= 0.35
	draw_arc(Vector2.ZERO, maxf(_radius - ring_width, 1.0), 0.0, TAU, 64, glow, 2.0)
	var white := Color(1, 1, 1, c.a * 0.8)
	draw_arc(Vector2.ZERO, maxf(_radius, 1.0), 0.0, TAU, 64, white, 1.0)
