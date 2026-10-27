# boss_part.gd
#
# One damageable piece of a multi-part boss (e.g. the badger's head and each
# arm in enemies/boss_badger.tscn). Each part has its own health, takes hits
# from player bullets like any enemy (it's in the "enemies" group), and hurts
# the player on contact - but it doesn't move on its own. Its parent boss node
# (see boss_badger.gd) moves all the parts together as one unit.
#
# Differences from a normal BaseEnemy:
#   - no shooting / diving / anchor-following / off-screen reset
#   - ramming it with the ship hurts the player but does NOT kill the part
#   - can't be absorbed (no get_enemy_type())
#   - dies with a short fade-out instead of vanishing instantly
#   - draws a small health bar (show_health_bar) while it's damaged
extends "res://enemies/base_enemy.gd"
class_name BossPart

@export var show_health_bar: bool = true
# Where the bar is drawn, relative to this part's center.
@export var health_bar_offset: Vector2 = Vector2(0, 40)
@export var health_bar_width: float = 30.0
@export var death_fade_time: float = 0.4


func custom_ready():
	can_shoot = false
	can_dive = false
	follow_anchor_enabled = false
	health_changed.connect(func(_c, _m): queue_redraw())


func start(_pos: Vector2) -> void:
	# Positioned by the parent boss, not by BaseEnemy's drop-in entrance.
	pass


func handle_boundaries():
	# The parent boss handles where the part is - never reset it.
	pass


func explode():
	# PlayerHealth calls explode() directly when the ship rams an enemy. A
	# boss part shrugs that off (the player still takes the contact damage) -
	# only running out of health kills it, which goes through die() first and
	# sets is_alive = false.
	if is_alive:
		return
	current_speed = 0
	set_deferred("monitorable", false)
	set_deferred("monitoring", false)
	died.emit(score_value)
	queue_redraw()
	# Fade the sprite (not `modulate`, which the hit flash also uses) and
	# shrink a little, then remove.
	var spr := get_node_or_null("Sprite2D") as Sprite2D
	var tw := create_tween().set_parallel(true)
	if spr:
		tw.tween_property(spr, "modulate", Color(1, 1, 1, 0), death_fade_time)
	tw.tween_property(self, "scale", scale * 0.7, death_fade_time)
	await tw.finished
	queue_free()


func _draw() -> void:
	if not show_health_bar or not is_alive or current_health >= max_health:
		return
	var h := 3.0
	var top_left := health_bar_offset - Vector2(health_bar_width * 0.5, h * 0.5)
	draw_rect(Rect2(top_left - Vector2(1, 1), Vector2(health_bar_width + 2, h + 2)), Color(0, 0, 0, 0.7))
	var pct: float = clamp(get_health_percentage(), 0.0, 1.0)
	var col := Color(0.35, 0.95, 0.4) if pct > 0.5 else (Color(1.0, 0.8, 0.2) if pct > 0.25 else Color(1.0, 0.3, 0.25))
	draw_rect(Rect2(top_left, Vector2(health_bar_width * pct, h)), col)
