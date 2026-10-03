extends Sprite2D
class_name PlayerShadow

## Drop shadow under the player ship - only shown while the ship is in the
## air during a dash jump (hidden on the ground).
##
## Mirrors the "Ship" Sprite2D every frame (texture, frame, rotation, recoil
## position, form swaps) and draws it as a flat, semi-transparent silhouette
## offset down/right. Because the game background is black, a true black
## shadow would be invisible - so the silhouette is a dim, cool slate-blue
## that reads as "shadow" against black + stars without competing with the
## ship itself.
##
## The shader writes COLOR directly and ignores the incoming vertex color,
## so the player's hit/heal/dash modulate flashes (red, green, blue tint)
## don't bleed into the shadow. player.hide() on death still hides it,
## since it's a child of the Player node.

## Silhouette color. Alpha controls overall strength - lower = subtler.
@export var shadow_color: Color = Color(0.32, 0.40, 0.62, 0.38)
## Offset from the ship in the Player's local units (Player is scaled 0.4,
## so (8, 22) is roughly 3 x 9 screen pixels).
@export var shadow_offset: Vector2 = Vector2(8, 22)
## Shadow size relative to the ship - slightly smaller sells the "height".
@export var size_factor: float = 0.85
## How the shadow reacts at the top of a dash jump (Player.jump_height = 1):
## offset multiplier, size multiplier, and opacity multiplier. Ship further
## "up" -> shadow further away, a bit smaller and fainter.
@export var jump_offset_mult: float = 2.0
@export var jump_size_mult: float = 0.8
@export var jump_alpha_mult: float = 0.6
## Name of the sibling sprite to follow.
@export var target_path: NodePath = ^"../Ship"

const SHADER_CODE := """
shader_type canvas_item;
uniform vec4 shadow_color : source_color;
void fragment() {
	float a = texture(TEXTURE, UV).a;
	COLOR = vec4(shadow_color.rgb, a * shadow_color.a);
}
"""

var _target: Sprite2D
var _mat: ShaderMaterial

func _ready() -> void:
	_target = get_node_or_null(target_path) as Sprite2D
	var shader := Shader.new()
	shader.code = SHADER_CODE
	_mat = ShaderMaterial.new()
	_mat.shader = shader
	material = _mat
	_apply_color()
	_sync()

func _process(_delta: float) -> void:
	_sync()

func _apply_color() -> void:
	if _mat:
		_mat.set_shader_parameter("shadow_color", shadow_color)

func _sync() -> void:
	if not is_instance_valid(_target):
		visible = false
		return
	# Only show the shadow while the ship is in the air (dash jump).
	var p = get_parent()
	var airborne: bool = p is Player and p.is_dashing
	visible = _target.visible and airborne
	if not visible:
		return

	# Copy whatever the ship is currently showing (form swaps change
	# texture/hframes, movement changes frame, dash changes rotation).
	if texture != _target.texture:
		texture = _target.texture
	hframes = _target.hframes
	vframes = _target.vframes
	frame = _target.frame
	region_enabled = _target.region_enabled
	region_rect = _target.region_rect
	centered = _target.centered
	offset = _target.offset
	flip_h = _target.flip_h
	flip_v = _target.flip_v

	rotation = _target.rotation

	# During a dash jump the Ship sprite itself is scaled up, so size the
	# shadow off the ship's normal (grounded) scale instead - the shadow
	# should get smaller as the ship goes up, not bigger.
	var h: float = 0.0
	var base_scale: Vector2 = _target.scale
	if p is Player:
		h = p.jump_height
		if p.ship_base_scale != Vector2.ZERO:
			base_scale = p.ship_base_scale
	scale = base_scale * size_factor * lerpf(1.0, jump_size_mult, h)
	position = _target.position + shadow_offset * lerpf(1.0, jump_offset_mult, h)
	if _mat:
		var c := shadow_color
		c.a *= lerpf(1.0, jump_alpha_mult, h)
		_mat.set_shader_parameter("shadow_color", c)
