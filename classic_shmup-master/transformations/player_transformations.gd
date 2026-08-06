extends RefCounted
class_name PlayerTransformations

## Handles turning the player into an absorbed enemy's form (transform_yellow,
## transform_red, ...) and the timer that reverts it automatically.
##
## Called from player.gd as e.g. PlayerTransformations.transform_yellow(self).
## player.gd still keeps thin transform_yellow()/transform_red() wrapper
## methods, because PlayerAbsorption.absorb_complete() dispatches to them
## by name via has_method()/call(), which only works on methods that exist
## directly on the player's own script.

static func setup_transformation_timer(player: Player) -> void:
	"""Set up the timer for automatic transformation reversion"""
	player.transformation_timer = Timer.new()
	player.transformation_timer.name = "TransformationTimer"
	player.transformation_timer.one_shot = true
	player.transformation_timer.timeout.connect(func(): on_transformation_timer_timeout(player))
	player.add_child(player.transformation_timer)

static func on_transformation_timer_timeout(player: Player) -> void:
	"""Called when transformation duration expires"""
	if player.current_form != 'default':
		PlayerAbsorption.revert_absorption(player)

static func get_transformation_function_name(enemy_type: String) -> String:
	return "transform_" + enemy_type.to_lower()

static func transform_yellow(player: Player) -> void:
	if player.transformation_timer:
		player.transformation_timer.stop()
		player.transformation_timer.start(player.transformation_duration)

	Stats.add_modifier("transform_yellow", {
		"player": {
			"speed": {"op": "mult", "value": 2.0},
			#"circle_radius": {"op": "set", "value": 600.0},
			#"circle_speed": {"op": "set", "value": 20.0},
			#"dash_duration": {"op": "mult", "value": 2.5},
			#"dash_speed": {"op": "mult", "value": 0.5},
			#"dash_invincible": {"op": "set", "value": true},
			# Uncomment to make the charge take a different amount of time
			# specifically while in yellow form (defaults to 1.0s otherwise):
			"charge_shot_duration": {"op": "set", "value": 0.5},
		},
		"bullet": {
			# These are the ONLY bullet stats now - the charge shot pulls
			# from this same category (via PlayerShooting.configure_bullet),
			# so there's one place that defines "how strong is yellow's shot".
			"damage": {"op": "set", "value": 3},
			"max_distance": {"op": "set", "value": 500.0},
			"speed": {"op": "mult", "value": 2.0},
			"pierce_count": {"op": "set", "value": 3},
			"can_pierce": {"op": "set", "value": true},
		},
	})

	# Optional visual feedback
	player.modulate = Color.YELLOW
	var timer = player.get_tree().create_timer(0.5)
	timer.timeout.connect(func(): player.modulate = player.player_color)

	var yellow_texture = load("res://Art assets/Player assets and transformations/Player_topdown_placeholder_transformation_sprite.png")
	player.get_node("Ship").texture = yellow_texture
	player.get_node("Ship").hframes = 3  # Adjust this to match your yellow sprite's frame count

	# Change bullets to yellow bullets
	# If you want ALL bullets to be yellow while transformed:
	player.bullet_scene = load("res://bullets/bullet_yellow.tscn")

static func transform_red(player: Player) -> void:
	if player.transformation_timer:
		player.transformation_timer.stop()
		player.transformation_timer.start(player.transformation_duration)

	Stats.add_modifier("transform_red", {
		"player": {
			"shoot_cooldown": {"op": "mult", "value": 0.75},
			"dash_duration": {"op": "mult", "value": 15.0},
			"dash_speed": {"op": "mult", "value": 0.2},
			"spin_speed": {"op": "set", "value": 2080.0},
			"steering_influence": {"op": "mult", "value": 4.0},
			"dash_damages_enemies": {"op": "set", "value": true},
		},
	})

	# Visual feedback
	player.modulate = Color.RED
	var timer = player.get_tree().create_timer(0.5)
	timer.timeout.connect(func(): player.modulate = player.player_color)

	var red_texture = load("res://Art assets/Player assets and transformations/Player_topdown_placeholder_transformation_sprite.png")
	player.get_node("Ship").texture = red_texture
	player.get_node("Ship").hframes = 3

static func play_simple_transition_effect(player: Player) -> void:
	"""Play a simple transformation effect"""
	var tween = player.create_tween()
	tween.tween_property(player.get_node("Ship"), "modulate", Color(1, 1, 1, 0.5), 0.1)
	tween.tween_property(player.get_node("Ship"), "modulate", player.player_color, 0.1)
