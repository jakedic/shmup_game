extends Sprite2D
class_name AbsorbReadyOutline

## Flashing white border around the ship, shown while an absorb is
## available (score multiplier at 4x, absorb off cooldown, default form -
## see PlayerAbsorption.is_absorb_ready()). Pairs with the "hit the button"
## prompt GameShell shows in the side panel at the same time.
##
## Works like the old drop shadow did: mirrors the "Ship" Sprite2D every
## frame (texture, frame, rotation, recoil, jump scale) and sits just before
## it in player.tscn so it draws behind the ship. The shader grows the
## ship's silhouette outward by outline_width texels and keeps only the
## ring, so it reads as a border hugging the frog. It writes COLOR directly,
## so the player's hit/dash tint flashes don't bleed into it.

## Border thickness in the ship texture's own pixels. The ship is drawn at
## ~0.1 scale (0.25 x the Player's 0.4), so 10 texels ~ 1 play-area px.
## Keep it under ~35: the art has ~38px of empty margin around each frame.
@export var outline_width: float = 10.0
@export var outline_color: Color = Color(1, 1, 1, 1)
## Flashes per second, and the dimmest the border gets between flashes.
@export var flash_rate: float = 3.0
@export var min_alpha: float = 0.15
@export var target_path: NodePath = ^"../Ship"

const SHADER_CODE := """
shader_type canvas_item;
uniform vec4 outline_color : source_color = vec4(1.0);
uniform float width = 10.0;
void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE * width;
	float a = 0.0;
	for (int i = 0; i < 16; i++) {
		float ang = 6.2831853 * float(i) / 16.0;
		vec2 d = vec2(cos(ang), sin(ang));
		a = max(a, texture(TEXTURE, UV + d * px).a);
		a = max(a, texture(TEXTURE, UV + d * px * 0.5).a);
	}
	// Ring only: drop whatever the ship itself already covers.
	float inside = texture(TEXTURE, UV).a;
	a = clamp(a - inside, 0.0, 1.0);
	COLOR = vec4(outline_color.rgb, outline_color.a * a);
}
"""

var _target: Sprite2D
var _mat: ShaderMaterial
var _t := 0.0


func _ready() -> void:
	_target = get_node_or_null(target_path) as Sprite2D
	var shader := Shader.new()
	shader.code = SHADER_CODE
	_mat = ShaderMaterial.new()
	_mat.shader = shader
	_mat.set_shader_parameter("width", outline_width)
	material = _mat
	visible = false


func _process(delta: float) -> void:
	var p = get_parent()
	var show_it: bool = is_instance_valid(_target) and _target.visible \
		and p is Player and PlayerAbsorption.is_absorb_ready(p)
	if not show_it:
		visible = false
		_t = 0.0
		return
	visible = true
	_t += delta
	_sync()
	# Sharp-ish white flash: mostly bright, quick dips.
	var wave := 0.5 + 0.5 * cos(_t * TAU * flash_rate)
	var c := outline_color
	c.a *= lerpf(min_alpha, 1.0, sqrt(wave))
	_mat.set_shader_parameter("outline_color", c)


func _sync() -> void:
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
	scale = _target.scale
	position = _target.position
