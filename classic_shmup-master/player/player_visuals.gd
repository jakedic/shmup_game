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
