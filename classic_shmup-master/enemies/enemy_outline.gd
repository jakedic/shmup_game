extends Node2D
class_name EnemyOutline

## A solid-color border hugging an enemy's sprite. It's the visual half of
## the "outline modifiers" system: an outline tells the player the enemy has
## some extra attribute. Right now that's only armor (gray, see
## BaseEnemy.set_armor()), but any future outline type can reuse this node
## with its own color/width.
##
## How it draws: the enemy's sprite is stamped as a flat-colored silhouette
## several times, nudged `width` play-area pixels in every direction, behind
## the real sprite. That leaves a clean ring of `width` px around the art.
## Doing it this way (instead of a texture-sampling shader like
## player/absorb_ready_outline.gd) means it works even when the sprite's
## region_rect is cropped tight to the art with no transparent margin, which
## the astroid sprites are.
##
## It's a child of the enemy, so it spins/moves with it for free. It ignores
## the enemy's modulate color (damage flash, tint), so the border always reads
## as its own color - only the enemy's alpha carries over, so it fades along
## with the enemy.

## Border color.
@export var outline_color: Color = Color(0.62, 0.62, 0.66, 1.0)
## Border thickness in play-area pixels (the 240x320 game screen).
@export var width: float = 1.0
## The sprite to outline. Empty = the enemy's first Sprite2D/AnimatedSprite2D.
@export var target_path: NodePath

const SHADER_CODE := """
shader_type canvas_item;
uniform vec4 outline_color : source_color = vec4(1.0);
void fragment() {
	COLOR = vec4(outline_color.rgb, outline_color.a * texture(TEXTURE, UV).a);
}
"""

# Brief white flash when a hit is fully blocked (see flash()).
const FLASH_COLOR := Color(1, 1, 1, 1)
const FLASH_TIME := 0.08

var _target: Node2D
var _mat: ShaderMaterial
var _offsets: Array[Vector2] = []
var _flash_left := 0.0


func _ready() -> void:
	var shader := Shader.new()
	shader.code = SHADER_CODE
	_mat = ShaderMaterial.new()
	_mat.shader = shader
	material = _mat
	_find_target()
	_build_offsets()


## Change the color/thickness after the outline already exists.
func configure(color: Color, new_width: float) -> void:
	outline_color = color
	width = new_width
	_build_offsets()
	queue_redraw()


## Quick white blink - used when armor soaks a whole hit, so the player can
## see the shot connected but did nothing.
func flash() -> void:
	_flash_left = FLASH_TIME


func _find_target() -> void:
	if not target_path.is_empty():
		_target = get_node_or_null(target_path) as Node2D
	if _target == null:
		for c in get_parent().get_children():
			if c is Sprite2D or c is AnimatedSprite2D:
				_target = c
				break
	# Draw behind the sprite: sit just before it among the enemy's children.
	if _target and _target.get_parent() == get_parent():
		get_parent().move_child.call_deferred(self, _target.get_index())


func _build_offsets() -> void:
	# Every pixel offset within `width` of the center (a filled circle minus
	# the middle), so a 2px border is round rather than a square smear.
	_offsets.clear()
	var r := int(ceil(width))
	var reach := width + 0.25
	for x in range(-r, r + 1):
		for y in range(-r, r + 1):
			if x == 0 and y == 0:
				continue
			if Vector2(x, y).length() <= reach:
				_offsets.append(Vector2(x, y))


func _process(delta: float) -> void:
	if _flash_left > 0.0:
		_flash_left -= delta
	var c := FLASH_COLOR if _flash_left > 0.0 else outline_color
	var p := get_parent() as CanvasItem
	if p:
		c.a *= p.modulate.a
	_mat.set_shader_parameter("outline_color", c)
	visible = is_instance_valid(_target) and _target.visible
	queue_redraw()


func _draw() -> void:
	if not is_instance_valid(_target):
		return
	var tex: Texture2D
	var src := Rect2()
	var centered := true
	var sprite_offset := Vector2.ZERO
	var flip := Vector2.ONE

	if _target is Sprite2D:
		var s := _target as Sprite2D
		tex = s.texture
		if tex == null:
			return
		src = s.region_rect if s.region_enabled else Rect2(Vector2.ZERO, tex.get_size())
		if s.hframes > 1 or s.vframes > 1:
			var cell := src.size / Vector2(s.hframes, s.vframes)
			src = Rect2(src.position + cell * Vector2(s.frame % s.hframes, s.frame / s.hframes), cell)
		centered = s.centered
		sprite_offset = s.offset
		flip = Vector2(-1 if s.flip_h else 1, -1 if s.flip_v else 1)
	elif _target is AnimatedSprite2D:
		var a := _target as AnimatedSprite2D
		if a.sprite_frames == null:
			return
		tex = a.sprite_frames.get_frame_texture(a.animation, a.frame)
		if tex == null:
			return
		src = Rect2(Vector2.ZERO, tex.get_size())
		centered = a.centered
		sprite_offset = a.offset
		flip = Vector2(-1 if a.flip_h else 1, -1 if a.flip_v else 1)
	else:
		return

	var dest := Rect2(sprite_offset - (src.size * 0.5 if centered else Vector2.ZERO), src.size)
	for off in _offsets:
		draw_set_transform(_target.position + off, _target.rotation, _target.scale * flip)
		draw_texture_rect_region(tex, dest, src)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
