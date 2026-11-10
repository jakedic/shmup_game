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

# ===== BIG DEATH (e.g. the badger's head) =====
# Instead of the quick fade: lots of explosions go off across the part while
# it shakes and fades out, then one big final blast.
@export var big_death: bool = false
@export var big_death_time: float = 1.8          # seconds of explosions + fading
@export var big_death_interval: float = 0.09     # seconds between each pop of explosions
@export var big_death_burst: int = 2             # explosions per pop
@export var big_death_explosion_size: Vector2 = Vector2(18, 34)   # random size range, px
@export var big_death_final_size: float = 70.0   # the last big blast, px

var _dying := false


func custom_ready():
	can_shoot = false
	can_dive = false
	follow_anchor_enabled = false
	health_changed.connect(func(_c, _m): queue_redraw())


func start(_pos: Vector2) -> void:
	# Positioned by the parent boss, not by BaseEnemy's drop-in entrance.
	pass


# ===== HIT FLASH =====
# BaseEnemy's flash_damage() remembers the CURRENT color, turns red, then
# restores the remembered color after flash_duration. If a second hit lands
# before that, the "remembered" color is already red - so it restores to red
# and the part stays red for good. Boss parts get hit fast enough for that to
# happen, so they use a simple countdown instead: every hit restarts it, and
# when it runs out the part always goes back to its normal color.
var _flash_left := 0.0


func flash_damage():
	modulate = flash_color
	_flash_left = flash_duration


func custom_process(delta: float):
	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			modulate = enemy_color


func handle_boundaries():
	# The parent boss handles where the part is - never reset it.
	pass


func explode():
	# PlayerHealth calls explode() directly when the ship rams an enemy. A
	# boss part shrugs that off (the player still takes the contact damage) -
	# only running out of health kills it, which goes through die() first and
	# sets is_alive = false.
	if is_alive or _dying:
		return
	_dying = true
	current_speed = 0
	set_deferred("monitorable", false)
	set_deferred("monitoring", false)
	died.emit(score_value)
	queue_redraw()
	if big_death:
		await _big_death_sequence()
		queue_free()
		return
	# Fade the sprite (not `modulate`, which the hit flash also uses) and
	# shrink a little, then remove.
	var spr := get_node_or_null("Sprite2D") as Sprite2D
	var tw := create_tween().set_parallel(true)
	if spr:
		tw.tween_property(spr, "modulate", Color(1, 1, 1, 0), death_fade_time)
	tw.tween_property(self, "scale", scale * 0.7, death_fade_time)
	await tw.finished
	queue_free()


func _big_death_sequence() -> void:
	"""The big finish (used by the badger's head): explosions keep popping
	all over the art while it shakes, flickers and fades out, then one last
	big blast. The part stays in the "enemies" group until this is done, so
	the level doesn't end (or start the next wave) underneath it."""
	_flash_left = 0.0
	modulate = enemy_color
	var spr := get_node_or_null("Sprite2D") as Sprite2D
	# Area the explosions can land in: the sprite's on-screen box, pulled in
	# a bit so they sit on the art rather than its empty corners.
	var half := Vector2(20, 20)
	if spr:
		half = spr.get_rect().size * spr.global_scale.abs() * 0.5 * 0.8
		var tw := create_tween()
		tw.tween_property(spr, "modulate", Color(1, 1, 1, 0), big_death_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	GameShell.shake_screen(big_death_time, 2.0)

	var elapsed := 0.0
	var flick := false
	while elapsed < big_death_time:
		if not is_inside_tree():
			return
		for i in big_death_burst:
			var at := global_position + Vector2(randf_range(-half.x, half.x), randf_range(-half.y, half.y))
			var d := randf_range(big_death_explosion_size.x, big_death_explosion_size.y)
			OneShotAnim.spawn(EXPLOSION_FRAMES, &"explode", at, d / EXPLOSION_SHEET_DIAMETER)
		if spr:
			# Rattle + flicker between white-hot and normal.
			spr.position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 2.0
			flick = not flick
			spr.self_modulate = Color(1.6, 1.4, 1.4) if flick else Color.WHITE
		await get_tree().create_timer(big_death_interval, false).timeout
		elapsed += big_death_interval

	# Final blast in the middle.
	if not is_inside_tree():
		return
	visible = false
	OneShotAnim.spawn(EXPLOSION_FRAMES, &"explode", global_position, big_death_final_size / EXPLOSION_SHEET_DIAMETER)
	GameShell.shake_screen(0.4, 4.0)
	await get_tree().create_timer(0.5, false).timeout


func _draw() -> void:
	if not show_health_bar or not is_alive or current_health >= max_health:
		return
	var h := 3.0
	var top_left := health_bar_offset - Vector2(health_bar_width * 0.5, h * 0.5)
	draw_rect(Rect2(top_left - Vector2(1, 1), Vector2(health_bar_width + 2, h + 2)), Color(0, 0, 0, 0.7))
	var pct: float = clamp(get_health_percentage(), 0.0, 1.0)
	var col := Color(0.35, 0.95, 0.4) if pct > 0.5 else (Color(1.0, 0.8, 0.2) if pct > 0.25 else Color(1.0, 0.3, 0.25))
	draw_rect(Rect2(top_left, Vector2(health_bar_width * pct, h)), col)
