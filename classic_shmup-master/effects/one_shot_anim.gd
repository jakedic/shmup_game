extends RefCounted

## Fire-and-forget animation helper (enemy explosion, bubble pop, ...):
## spawns an AnimatedSprite2D into the game world at a position, plays the
## animation once, then frees it. Lives on its own node, so the thing that
## died can be freed straight away without cutting the effect off.
##
## Used through a preload (no class_name, so it never depends on Godot's
## global class cache being up to date):
##   const OneShotAnim := preload("res://effects/one_shot_anim.gd")
##   OneShotAnim.spawn(EXPLOSION_FRAMES, &"explode", global_position, 0.12)

static func spawn(frames: SpriteFrames, anim: StringName, at: Vector2,
		size_scale: float = 1.0, tint: Color = Color.WHITE, rot: float = 0.0) -> AnimatedSprite2D:
	var fx := AnimatedSprite2D.new()
	fx.sprite_frames = frames
	fx.scale = Vector2.ONE * size_scale
	fx.modulate = tint
	fx.rotation = rot
	fx.z_index = 5
	fx.animation_finished.connect(fx.queue_free)
	GameShell.game_root().add_child(fx)
	fx.global_position = at
	fx.play(anim)
	return fx
