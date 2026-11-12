## "Bullseye" yellow power-up aimer (player/player_powerups.gd -
## yellow_bullseye). While Stats "player"/"has_aimer" is on, a bullseye
## (circle with four lines through it) sits on the nearest enemy straight
## ahead of the ship - the one the main shot would hit if fired now
## (same column as the shot, above the ship, within shot range).
##
## Called every frame from player.gd's _process() as AIMER.update(self).
## The marker lives in GameShell.game_root() so it doesn't spin with the ship.
extends Node2D

const RADIUS := 8.0
const LINE_INNER := 0.4    # tick lines run from RADIUS x this ...
const LINE_OUTER := 1.5    # ... to RADIUS x this (through the circle)
const COLOR := Color(1.0, 0.85, 0.2, 0.95)   # pollen yellow
const SHOT_HALF_WIDTH := 3.0   # half the main bullet's width
const FALLBACK_HALF_WIDTH := 8.0
const SHOT_SPAWN_OFFSET := 8.0  # bullets spawn this far above the ship

var target: Node2D = null

func _ready() -> void:
	z_index = 20

func _process(_delta: float) -> void:
	if is_instance_valid(target):
		global_position = target.global_position
	queue_redraw()

func _draw() -> void:
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 32, COLOR, 1.0, true)
	for dir in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		draw_line(dir * RADIUS * LINE_INNER, dir * RADIUS * LINE_OUTER, COLOR, 1.0, true)


static func update(player: Node2D) -> void:
	var marker = player.get_meta("aimer_marker", null)
	if marker != null and not is_instance_valid(marker):
		marker = null
	var on: bool = bool(Stats.get_stat("player", "has_aimer")) and player.is_alive
	var enemy: Node2D = find_target(player) if on else null
	if enemy == null:
		if marker:
			marker.visible = false
			marker.target = null
		return
	if marker == null:
		marker = (load("res://player/player_aimer.gd") as GDScript).new()
		GameShell.game_root().add_child(marker)
		player.set_meta("aimer_marker", marker)
		player.tree_exiting.connect(func():
			if is_instance_valid(marker):
				marker.queue_free()
		)
	marker.target = enemy
	marker.global_position = enemy.global_position
	marker.visible = true


static func find_target(player: Node2D) -> Node2D:
	"""Nearest enemy the main shot (straight up from the ship) would hit."""
	var origin: Vector2 = player.global_position + Vector2(0, -SHOT_SPAWN_OFFSET)
	var reach: float = float(Stats.get_stat("bullet", "max_distance"))
	var best: Node2D = null
	var best_dy := INF
	for enemy in player.get_tree().get_nodes_in_group("enemies"):
		if not (enemy is Node2D) or not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		if "is_alive" in enemy and not enemy.is_alive:
			continue
		var dy: float = origin.y - enemy.global_position.y
		if dy < -_half_extents(enemy).y or dy > reach:
			continue
		if absf(enemy.global_position.x - origin.x) > _half_extents(enemy).x + SHOT_HALF_WIDTH:
			continue
		if dy < best_dy:
			best_dy = dy
			best = enemy
	return best


static func _half_extents(enemy: Node2D) -> Vector2:
	"""Half width/height of the enemy's hitbox (first CollisionShape2D)."""
	for child in enemy.get_children():
		if child is CollisionShape2D and child.shape and not child.disabled:
			var s: Vector2 = child.global_scale.abs()
			var shape: Shape2D = child.shape
			if shape is RectangleShape2D:
				return shape.size * 0.5 * s
			if shape is CircleShape2D:
				return Vector2(shape.radius, shape.radius) * s
			if shape is CapsuleShape2D:
				return Vector2(shape.radius, shape.height * 0.5) * s
	return Vector2(FALLBACK_HALF_WIDTH, FALLBACK_HALF_WIDTH)
