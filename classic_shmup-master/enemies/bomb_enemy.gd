# bomb_enemy.gd
#
# A bomb: a red circle with 1 health. Shooting it sets it off - it explodes and
# deals blast_damage to EVERY enemy within blast_radius (armor still applies,
# so 5 damage vs. 2 armor = 3).
#
# The blast also hurts the PLAYER if they're inside it - most likely because
# they jumped onto the bomb (the landing shockwave sets it off). The fire
# lingers for player_blast_linger seconds so it outlasts the jump's landing
# invincibility (PlayerMovement.LANDING_GRACE_DURATION, 0.2s): land on a bomb
# and you'll still get burned once the grace runs out. It only ever hits the
# player once per blast.
#
# Doesn't move on its own (squad_controlled) - something else places it, e.g.
# enemies/bomb_ring_formation.gd keeps it in the middle of a ring of armored
# astroids. See BaseLevel.spawn_bomb_ring().
extends "res://enemies/base_enemy.gd"
class_name BombEnemy

@export var blast_radius: float = 50.0
@export var blast_damage: int = 5
@export var bomb_radius: float = 6.0
@export var bomb_color: Color = Color(0.9, 0.12, 0.1)
# Damage to the player if they're inside the blast (same as ramming an enemy).
@export var player_blast_damage: int = 4
# How long the blast stays dangerous to the player. Must be longer than the
# jump's landing invincibility (0.2s) or jumping on a bomb would be free.
@export var player_blast_linger: float = 0.6

var _pulse_t := 0.0


func custom_ready():
	death_explosion = false  # the bomb draws its own blast
	can_shoot = false
	can_dive = false
	follow_anchor_enabled = false
	squad_controlled = true


func custom_process(delta: float):
	_pulse_t += delta
	queue_redraw()


func _draw() -> void:
	# Body, darker rim, little highlight, and a slow pulsing glow so it reads
	# as "volatile".
	var glow := 0.5 + 0.5 * sin(_pulse_t * 5.0)
	draw_circle(Vector2.ZERO, bomb_radius + 2.0, Color(1.0, 0.3, 0.2, 0.25 * glow))
	draw_circle(Vector2.ZERO, bomb_radius, bomb_color.darkened(0.45))
	draw_circle(Vector2.ZERO, bomb_radius - 1.0, bomb_color)
	draw_circle(Vector2(-bomb_radius * 0.35, -bomb_radius * 0.35), bomb_radius * 0.28, Color(1, 0.75, 0.7, 0.9))


func custom_die():
	_blast()


func _blast() -> void:
	var center := global_position
	# Copy first - enemies killed by the blast leave the group as we go.
	var targets: Array = get_tree().get_nodes_in_group("enemy").duplicate()
	for e in targets:
		if e == self or not is_instance_valid(e):
			continue
		if "is_alive" in e and not e.is_alive:
			continue
		if e.global_position.distance_to(center) <= blast_radius and e.has_method("take_damage"):
			e.take_damage(blast_damage)

	var fx := BlastFx.new()
	fx.radius = blast_radius
	fx.player_damage = player_blast_damage
	fx.linger = player_blast_linger
	fx.global_position = center
	get_parent().add_child(fx)


# Expanding, fading ring + flash that shows the blast area, followed by a
# smoldering glow for as long as the blast can still hurt the player.
class BlastFx extends Node2D:
	var radius := 50.0
	var player_damage := 4
	var linger := 0.6       # seconds the blast stays dangerous to the player
	var _t := 0.0
	var _hit_player := false
	const DURATION := 0.35  # the bright expanding ring

	func _ready() -> void:
		z_index = 5

	func _process(delta: float) -> void:
		_t += delta
		if not _hit_player and _t <= linger:
			_try_hurt_player()
		if _t >= maxf(DURATION, linger):
			queue_free()
			return
		queue_redraw()

	func _try_hurt_player() -> void:
		var player = get_tree().get_first_node_in_group("player")
		if player == null or not is_instance_valid(player):
			return
		if "is_alive" in player and not player.is_alive:
			return
		if player.global_position.distance_to(global_position) > radius:
			return
		# Mid-jump / landing grace / just-got-hit: wait it out. The blast
		# keeps checking every frame until `linger` runs out.
		if PlayerHealth.is_invincible(player):
			return
		_hit_player = true
		player.take_damage(player_damage)

	func _draw() -> void:
		if _t < DURATION:
			var k := _t / DURATION
			var r := lerpf(radius * 0.3, radius, sqrt(k))
			var a := 1.0 - k
			draw_circle(Vector2.ZERO, r, Color(1.0, 0.55, 0.15, 0.35 * a))
			draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Color(1.0, 0.9, 0.5, a), 2.0)
		# Smoldering zone - shows the blast is still hot.
		if _t < linger:
			var flicker := 0.75 + 0.25 * sin(_t * 40.0)
			var fade := 1.0 - _t / linger
			draw_circle(Vector2.ZERO, radius, Color(1.0, 0.35, 0.1, 0.18 * fade * flicker))
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(1.0, 0.45, 0.15, 0.5 * fade), 1.0)
