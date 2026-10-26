extends RefCounted
class_name PlayerVisuals

## Handles sprite/color visuals that aren't specific to one system:
## applying the base color+texture, swapping the sprite for absorption
## state, and the shoot recoil tween. Called from player.gd as e.g.
## PlayerVisuals.update_sprite(self).

static func apply_visuals(player: Player) -> void:
	"""Apply visual properties like color and texture"""
	player.modulate = player.player_color
	update_sprite(player)

static func update_sprite(player: Player) -> void:
	"""Update ship sprite based on absorption state"""
	var ship = player.get_node("Ship")
	if player.is_absorbing == 1:
		ship.texture = player.yellow_sprite_texture
		ship.hframes = 4
	elif player.is_absorbing == 2:
		var texture = load("res://Mini Pixel Pack 3/Enemies/Lips (16 x 16).png")
		ship.texture = texture
		ship.hframes = 5
	else:
		if ship is Sprite2D:
			ship.hframes = 3
			ship.texture = player.default_sprite_texture

static func animate_recoil(player: Player) -> void:
	"""Play the ship recoil animation when shooting"""
	var tween = player.create_tween().set_parallel(false)
	tween.tween_property(player.get_node("Ship"), "position:y", player.recoil_distance, player.recoil_duration)
	tween.tween_property(player.get_node("Ship"), "position:y", 0, player.recoil_duration * 0.5)

# ===== FORM TINT (gray form) =====
# While the player is in the gray form the ship is drawn in greyscale (same
# shader as the gray enemies). In the last FORM_EXPIRY_WARNING seconds of the
# transformation it flashes between grey and its normal colors, faster and
# faster, to warn that the form is about to run out. Driven every frame from
# player.gd's _process(), so reverting (timer, bubble shot, manual) just
# naturally drops the tint the next frame.

const GRAYSCALE_SHADER := preload("res://enemies/grayscale.gdshader")
const FORM_EXPIRY_WARNING := 3.0      # seconds left when the flashing starts
const FORM_FLASH_SLOW := 0.2          # seconds per grey/normal swap at the start...
const FORM_FLASH_FAST := 0.07         # ...speeding up to this by the very end

static func update_form_tint(player: Player) -> void:
	var ship := player.get_node_or_null("Ship") as CanvasItem
	if ship == null:
		return
	if player.gray_ship_material == null:
		player.gray_ship_material = ShaderMaterial.new()
		player.gray_ship_material.shader = GRAYSCALE_SHADER
	# Never clobber some other material put on the ship by something else.
	if ship.material != null and ship.material != player.gray_ship_material:
		return

	var tinted: bool = player.current_form == "gray"
	if tinted:
		var t: Timer = player.transformation_timer
		if t and not t.is_stopped() and t.time_left <= FORM_EXPIRY_WARNING:
			var left: float = t.time_left
			var k: float = 1.0 - left / FORM_EXPIRY_WARNING   # 0 -> 1 as it runs out
			var interval: float = lerpf(FORM_FLASH_SLOW, FORM_FLASH_FAST, k)
			player.form_flash_elapsed += player.get_process_delta_time()
			if player.form_flash_elapsed >= interval:
				player.form_flash_elapsed = 0.0
				player.form_flash_on = not player.form_flash_on
			tinted = player.form_flash_on
		else:
			player.form_flash_elapsed = 0.0
			player.form_flash_on = true

	var want: Material = player.gray_ship_material if tinted else null
	if ship.material != want:
		ship.material = want
