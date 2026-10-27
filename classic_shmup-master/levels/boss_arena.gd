# boss_arena.gd
#
# The boss arena walls: the "Boss arena left/right" art down both sides of the
# play area, tiled top-to-bottom so they fill the whole screen. Touching a
# wall hurts the player (and nudges them back out toward the middle). Jumping
# / dashing over a wall is safe - landing inside it isn't.
#
# HOW TO USE FROM A LEVEL:
#
#     var arena := BossArena.new()
#     add_child(arena)
#     move_child(arena, $Background.get_index() + 1)   # draw over the background, under everything else
#
# ENTRANCE: set start_hidden = true before add_child() and the belts start
# off above the screen, then call play_intro(seconds) to have them slide down
# from the top until they reach the bottom. The hurtbox only covers the part
# of each belt that's actually come down so far.
#
# Bubbles bounce off the walls' inner edges instead of the screen edges while
# an arena is in the level (see get_inner_x_limits() and bubble.gd's
# _bounce_off_walls()).
extends Node2D
class_name BossArena

const LEFT_TEXTURE := preload("res://Art assets/Boss arena left.png")
const RIGHT_TEXTURE := preload("res://Art assets/boss arena right.png")
# Where each wall's art sits on its 2048x2048 sheet (the rest is transparent).
const LEFT_REGION := Rect2(0, 0, 272, 2048)
const RIGHT_REGION := Rect2(754, 0, 272, 2028)

# How wide each wall is on screen (play area is 240 px wide). The art is
# scaled to fit this width and repeated down the screen.
@export var wall_width: float = 26.0
# Shield damage when the player touches a wall (enemy ship contact is 4).
@export var contact_damage: int = 2
# How far (px) the player gets shoved back toward the middle on a hit.
@export var knockback: float = 14.0
# Lets the hurtbox sit slightly inside the art so grazing the very edge of the
# rail doesn't count.
@export var hurtbox_inset: float = 2.0
# Pixels/second the wall art scrolls downward (0 = still). Makes it feel like
# the arena is flying forward.
@export var scroll_speed: float = 0.0
# Start with the belts pulled up off the top of the screen (see play_intro()).
@export var start_hidden: bool = false

var _screen: Vector2
var _tile_rows: Array[Node2D] = []   # [left_tiles, right_tiles]
var _tile_heights: Array[float] = []
var _scroll := 0.0
var _hurtboxes: Array[Area2D] = []
var _hurt_shapes: Array[CollisionShape2D] = []
var _tile_counts: Array[int] = []
# 0 = belts fully up off the top of the screen, 1 = all the way down (normal).
var _drop := 1.0
var _drop_tween: Tween


func _ready() -> void:
	add_to_group("arena_bounds")
	_screen = get_viewport_rect().size
	_build_side(LEFT_TEXTURE, LEFT_REGION, 0.0, true)
	_build_side(RIGHT_TEXTURE, RIGHT_REGION, _screen.x - wall_width, false)
	if start_hidden:
		_drop = 0.0
	_update_belts()


## Slide the belts down from the top of the screen over `seconds`. Await it
## to wait until the barrier is fully formed.
func play_intro(seconds: float = 2.5) -> void:
	if is_instance_valid(_drop_tween):
		_drop_tween.kill()
	_drop = 0.0
	_drop_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_drop_tween.tween_property(self, "_drop", 1.0, seconds)
	await _drop_tween.finished


## x range the play space actually has between the walls - used by bubbles
## (and anything else that wants to bounce/clamp to the arena).
func get_inner_x_limits() -> Vector2:
	return Vector2(wall_width, _screen.x - wall_width)


func _build_side(tex: Texture2D, region: Rect2, left_x: float, is_left: bool) -> void:
	var s: float = wall_width / region.size.x
	var tile_h: float = region.size.y * s
	var tiles := Node2D.new()
	tiles.name = "LeftWall" if is_left else "RightWall"
	add_child(tiles)
	# One extra tile so scrolling never shows a gap.
	var count: int = int(ceil(_screen.y / tile_h)) + 1
	for i in count:
		var spr := Sprite2D.new()
		spr.texture = tex
		spr.region_enabled = true
		spr.region_rect = region
		spr.centered = false
		spr.scale = Vector2(s, s)
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		spr.position = Vector2(left_x, i * tile_h)
		tiles.add_child(spr)
	_tile_rows.append(tiles)
	_tile_heights.append(tile_h)
	_tile_counts.append(count)

	# Hurtbox: watches for the player's Area2D (layer 1). Not in the "enemies"
	# group, so it never counts toward a wave or gets hit by bullets.
	var box := Area2D.new()
	box.name = tiles.name + "Hurtbox"
	box.collision_layer = 0
	box.collision_mask = 1
	box.monitorable = false
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	var w: float = wall_width - hurtbox_inset
	rect.size = Vector2(w, _screen.y + 64.0)
	shape.shape = rect
	# Inset only on the inner (play-area) side.
	var cx: float = left_x + w * 0.5 if is_left else left_x + hurtbox_inset + w * 0.5
	shape.position = Vector2(cx, _screen.y * 0.5)
	box.add_child(shape)
	add_child(box)
	_hurtboxes.append(box)
	_hurt_shapes.append(shape)


func _process(delta: float) -> void:
	_scroll += scroll_speed * delta
	_update_belts()


func _update_belts() -> void:
	for i in _tile_rows.size():
		var h: float = _tile_heights[i]
		var full_h: float = _tile_counts[i] * h
		# fposmod (not fmod) so a negative speed (scrolling up) wraps cleanly too.
		var y: float = fposmod(_scroll, h) - h
		# Entrance: shift the whole strip up by however much hasn't dropped yet.
		y -= full_h * (1.0 - _drop)
		_tile_rows[i].position.y = y
		# Hurtbox covers only the part of the belt that's on screen so far.
		var bottom: float = minf(y + full_h, _screen.y + 32.0)
		var shape := _hurt_shapes[i]
		var rect := shape.shape as RectangleShape2D
		if bottom <= 0.0:
			shape.disabled = true
			continue
		shape.disabled = false
		rect.size.y = bottom + 32.0
		shape.position.y = (bottom - 32.0) * 0.5


func _physics_process(_delta: float) -> void:
	# Checked every frame (not just on area_entered) so standing in a wall, or
	# landing a jump inside one, keeps hurting once hit i-frames run out.
	for box in _hurtboxes:
		for area in box.get_overlapping_areas():
			if area is Player:
				_hurt_player(area as Player)


func _hurt_player(player: Player) -> void:
	if not player.is_alive or PlayerHealth.is_invincible(player):
		return   # mid-jump, post-jump grace, or still blinking from a hit
	PlayerHealth.take_damage(player, contact_damage)
	# Shove them back toward the middle so they're not left sitting in it.
	var limits := get_inner_x_limits()
	var target_x: float = player.position.x
	if player.position.x < _screen.x * 0.5:
		target_x = max(player.position.x, limits.x) + knockback
	else:
		target_x = min(player.position.x, limits.y) - knockback
	var tw := player.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(player, "position:x", target_x, 0.15)
