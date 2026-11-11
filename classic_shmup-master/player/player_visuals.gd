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
	update_ship_anim(player, 0.0)

# ===== ANIMATED SHIP (default form) =====
# Ship/Anim (AnimatedSprite2D, player/anim/player_ship_frames.tres) draws the
# frog in its default form with the idle / left / right animations. The Ship
# Sprite2D underneath keeps doing everything it always did (form textures,
# jump scale, spin, recoil, gray tint via use_parent_material) - while the
# default texture is on it, its own art is just hidden (self_modulate) and
# Anim shows instead. Any form that swaps Ship's texture automatically hides
# Anim again, so the form sprites need no changes.

static func update_ship_anim(player: Player, x_dir: float) -> void:
	var ship := player.get_node_or_null("Ship") as Sprite2D
	if ship == null:
		return
	var anim := ship.get_node_or_null("Anim") as AnimatedSprite2D
	if anim == null:
		return
	var use_anim: bool = ship.texture == player.default_sprite_texture
	anim.visible = use_anim
	ship.self_modulate.a = 0.0 if use_anim else 1.0
	if not use_anim:
		return
	var want: StringName = &"idle"
	if x_dir > 0:
		want = &"right"
	elif x_dir < 0:
		want = &"left"
	if anim.animation != want:
		# Same frame count in all three, so carry the frame over and the
		# hand-glow cycle doesn't restart on every direction change.
		var f := anim.frame
		var prog := anim.frame_progress
		anim.play(want)
		anim.set_frame_and_progress(f, prog)
	elif not anim.is_playing():
		anim.play(want)

static func mirror_ship(ship: Sprite2D, dst: Sprite2D) -> Vector2:
	"""Copy what the ship is currently showing onto `dst` (used by the jump
	shadow and the absorb-ready outline). Returns the extra scale to apply
	on top of the Ship's own scale (Anim's scale when it's the one drawing)."""
	var anim := ship.get_node_or_null("Anim") as AnimatedSprite2D
	if anim and anim.visible and anim.sprite_frames and anim.sprite_frames.has_animation(anim.animation):
		var tex := anim.sprite_frames.get_frame_texture(anim.animation, anim.frame)
		if dst.texture != tex:
			dst.texture = tex
		dst.hframes = 1
		dst.vframes = 1
		dst.frame = 0
		dst.region_enabled = false
		dst.centered = anim.centered
		dst.offset = anim.offset
		dst.flip_h = anim.flip_h
		dst.flip_v = anim.flip_v
		return anim.scale
	if dst.texture != ship.texture:
		dst.texture = ship.texture
	dst.hframes = ship.hframes
	dst.vframes = ship.vframes
	dst.frame = ship.frame
	dst.region_enabled = ship.region_enabled
	dst.region_rect = ship.region_rect
	dst.centered = ship.centered
	dst.offset = ship.offset
	dst.flip_h = ship.flip_h
	dst.flip_v = ship.flip_v
	return Vector2.ONE

static func animate_recoil(player: Player) -> void:
	"""Play the ship recoil animation when shooting"""
	var tween = player.create_tween().set_parallel(false)
	tween.tween_property(player.get_node("Ship"), "position:y", player.recoil_distance, player.recoil_duration)
	tween.tween_property(player.get_node("Ship"), "position:y", 0, player.recoil_duration * 0.5)

# ===== FORM TINT (gray + yellow forms) =====
# While the player is in the gray form the ship is drawn in greyscale (same
# shader as the gray enemies); in the yellow form it's the same ship tinted
# yellow (player/yellow_tint.gdshader). In the last FORM_EXPIRY_WARNING
# seconds of the transformation it flashes between the tint and its normal
# colors, faster and faster, to warn that the form is about to run out.
# Colors mean the same thing everywhere:
#   BLUE flashing   = can't be hurt. While intangible after a full charge
#                     (yellow form - PlayerChargeShot) the ship blinks blue
#                     exactly like the jump's invincibility
#                     (PlayerMovement.DASH_TINT_COLOR / INVINCIBILITY_FLASH_INTERVAL).
#   BRIGHT YELLOW   = charging the yellow shot (blinking), solid when fully
#                     charged - player.charge_flash_amount -> the yellow
#                     tint shader's "flash". Driven every frame from player.gd's
# _process(), so reverting (timer, bubble shot, manual) just naturally drops
# the tint the next frame.

const GRAYSCALE_SHADER := preload("res://enemies/grayscale.gdshader")
const YELLOW_TINT_SHADER := preload("res://player/yellow_tint.gdshader")
const FORM_EXPIRY_WARNING := 3.0      # seconds left when the flashing starts
const FORM_FLASH_SLOW := 0.2          # seconds per tint/normal swap at the start...
const FORM_FLASH_FAST := 0.07         # ...speeding up to this by the very end

static func _form_material(player: Player, form: String) -> ShaderMaterial:
	if form == "gray":
		if player.gray_ship_material == null:
			player.gray_ship_material = ShaderMaterial.new()
			player.gray_ship_material.shader = GRAYSCALE_SHADER
		return player.gray_ship_material
	if form == "yellow":
		if player.yellow_ship_material == null:
			player.yellow_ship_material = ShaderMaterial.new()
			player.yellow_ship_material.shader = YELLOW_TINT_SHADER
		return player.yellow_ship_material
	return null

static func update_form_tint(player: Player) -> void:
	var ship := player.get_node_or_null("Ship") as CanvasItem
	if ship == null:
		return
	# Never clobber some other material put on the ship by something else.
	if ship.material != null and ship.material != player.gray_ship_material \
			and ship.material != player.yellow_ship_material:
		return

	var form_mat := _form_material(player, String(player.current_form))
	var intangible: bool = player.is_charge_invincible
	var tinted: bool = form_mat != null
	if tinted and not intangible:
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

	# Intangible: blink blue like the jump's invincibility (whole ship,
	# via modulate), then settle back on the normal color once it ends.
	# On the blue beats the form tint is dropped too - blue over the yellow
	# tint would come out green instead of the jump's blue.
	var blue_beat := false
	if intangible:
		player.intangible_flash_elapsed += player.get_process_delta_time()
		blue_beat = int(player.intangible_flash_elapsed / PlayerMovement.INVINCIBILITY_FLASH_INTERVAL) % 2 == 0
		player.modulate = PlayerMovement.DASH_TINT_COLOR if blue_beat else player.player_color
		player._intangible_flash_active = true
	elif player._intangible_flash_active:
		player._intangible_flash_active = false
		player.intangible_flash_elapsed = 0.0
		player.modulate = player.player_color

	# Charging glow (bright yellow) - off while intangible so the blue reads.
	if player.yellow_ship_material:
		var amount: float = 0.0 if intangible else player.charge_flash_amount
		player.yellow_ship_material.set_shader_parameter("flash", amount)

	var want: Material = form_mat if tinted and not blue_beat else null
	if ship.material != want:
		ship.material = want
