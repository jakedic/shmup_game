# pollen_residue.gd
## A patch of pollen left on the field when the yellow form's fully charged
## shot flies through one of its own pollen puffs (see
## bullets/bullet_pollen_puff.gd - _burst()).
##
## Any enemy that passes through the patch gets ONE roll (per patch) at
## POLLINATE_CHANCE to become pollinated. The patch lasts DURATION seconds,
## fading out over the last FADE_TIME, then disappears.
##
## Also left by the Pollen Trail (player/player_pollen_trail.gd) and Pollen
## Pop (bubble.gd create_pop_damage()) power-ups and Cross-Pollination.
## Whoever spawns one can set `radius` and `duration` BEFORE adding it to the
## tree; otherwise RADIUS / DURATION are used.
##
## Loaded with preload() rather than a class_name, so nothing else needs to
## know about it.
extends Node2D

const RADIUS := 26.0
const DURATION := 2.5
const FADE_TIME := 0.5
const POLLINATE_CHANCE := 0.5
const COLOR := Color(1.0, 0.85, 0.2)
const SPECK_COUNT := 22

var radius := RADIUS
var duration := DURATION
var show_outline := true   # the trail turns this off so it reads as one smear, not a chain of rings
var _t := 0.0
var _rolled := {}          # enemy instance id -> true (each enemy rolls once)
var _specks: Array = []    # [Vector2 offset, float size] for the drawing


func _ready() -> void:
	# Pollen Haven (player/player_pollen_haven.gd) finds patches by group.
	add_to_group("pollen_residue")
	# Bigger patches get more specks so they look as dense as small ones.
	var count := maxi(int(SPECK_COUNT * (radius / RADIUS) * (radius / RADIUS)), 6)
	for i in mini(count, 200):
		var ang := randf() * TAU
		var dist := sqrt(randf()) * radius
		_specks.append([Vector2(cos(ang), sin(ang)) * dist, randf_range(0.8, 1.8)])


func _process(delta: float) -> void:
	_t += delta
	if _t >= duration:
		queue_free()
		return
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		if "is_alive" in enemy and not enemy.is_alive:
			continue
		var id := enemy.get_instance_id()
		if _rolled.has(id):
			continue
		if global_position.distance_to(enemy.global_position) > radius:
			continue
		_rolled[id] = true
		if not enemy.has_method("apply_status_effect") or not enemy.has_method("has_status_effect"):
			continue
		if enemy.has_status_effect(StatusEffects.POLLINATED):
			continue
		if randf() < POLLINATE_CHANCE:
			enemy.apply_status_effect(StatusEffects.POLLINATED, {})
	queue_redraw()


func _draw() -> void:
	var fade := clampf((duration - _t) / FADE_TIME, 0.0, 1.0)
	draw_circle(Vector2.ZERO, radius, Color(COLOR, 0.12 * fade))
	if show_outline:
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(COLOR, 0.3 * fade), 1.0)
	for s in _specks:
		# Gentle twinkle so it reads as drifting pollen, not a flat decal.
		var tw := 0.6 + 0.4 * sin(_t * 4.0 + s[0].x)
		draw_circle(s[0], s[1], Color(COLOR, 0.75 * fade * tw))
