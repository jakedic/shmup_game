extends Node2D
class_name LilyPad

## Lily pad under the frog ship (placeholder: a plain dark green circle,
## small enough that it just peeks out from under the ship).
##
## - Always sits directly under the player's actual position - during a jump
##   it stays where the ship would be if it weren't in the air (like the old
##   shadow), it does NOT predict the landing spot.
## - Hidden while the jump is recharging (dash cooldown); back as soon as a
##   jump is ready.
##
## It is NOT a child of the Player: Player.gd spawns it as a sibling right
## after itself (see Player._spawn_lily_pad()). That way:
##   - it draws at z_index 0 like the enemies, but earlier in the tree than
##     anything spawned during the level, so enemies (and bullets) that
##     overlap the pad draw ON TOP of it, while the ship (z_index 10) still
##     draws above everything;
##   - the player's hit/dash/heal color flashes (modulate) don't tint it.
## It frees itself when the player goes away and hides while the player is
## dead/hidden.

## Circle radius in play-area pixels (the frog ship is ~28px wide).
@export var radius: float = 9.0
@export var color: Color = Color(0.08, 0.30, 0.12)
## Where the pad sits relative to the Player node's origin (play-area px).
@export var pad_offset: Vector2 = Vector2(1, -1)

var player: Player = null


func _ready() -> void:
	z_as_relative = false
	z_index = 0
	if player:
		position = player.position + pad_offset
	queue_redraw()


func _process(_delta: float) -> void:
	if not is_instance_valid(player) or not player.is_inside_tree():
		queue_free()
		return

	position = player.position + pad_offset
	# Hidden while the jump recharges (not dashing and can't dash yet).
	var recharging: bool = not player.can_dash and not player.is_dashing
	visible = player.is_alive and player.visible and not recharging


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, color)
