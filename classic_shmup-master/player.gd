# player_base.gd
extends Area2D
#class_name Player

signal shield_changed(max_shield: int, current_shield: int)
signal died
signal player_shot(bullet: Node2D)
signal player_absorbed(enemy_type: int)
signal player_healed(amount: int)

# ===== CUSTOMIZABLE PROPERTIES =====
@export var player_name: String = "Player"

# Movement properties
@export var speed: float = 150
@export var acceleration: float = 10.0  # For smooth movement
@export var deceleration: float = 10.0  # For smooth stopping

# Health/shield properties
@export var max_shield: int = 10
@export var shield_regen_rate: float = 0.0  # Shield per second
@export var shield_regen_delay: float = 3.0  # Seconds after damage before regen

# Shooting properties
@export var shoot_cooldown: float = 0.25
@export var bullet_scene: PackedScene
@export var bullet_yellow_scene: PackedScene
@export var can_multi_shoot: bool = false
@export var shot_count: int = 1
@export var shot_spread: float = 10.0  # degrees

# Absorption properties
@export var absorb_scene: PackedScene
@export var absorb_cooldown: float = 2.0
@export var max_absorption_level: int = 2  # Maximum enemy types that can be absorbed

# Visual properties
@export var default_sprite_texture: Texture2D
@export var yellow_sprite_texture: Texture2D
@export var player_color: Color = Color.WHITE
@export var has_recoil_animation: bool = true
@export var recoil_distance: float = 1.0
@export var recoil_duration: float = 0.1

# Simple dictionary to define form properties
var current_form_data: Dictionary = {}
var yellow_form = preload("res://transformations/yellow.tres")
var default_form = preload("res://transformations/default.tres")
var current_form='default'
var form_path
var form_resource
# Sound properties (add these if you have sound)
# @export var shoot_sound: AudioStream
# @export var absorb_sound: AudioStream
# @export var hit_sound: AudioStream

# ===== INTERNAL VARIABLES =====
var shield: int:
	set = set_shield

var can_shoot: bool = true
var can_absorb: bool = true
var is_absorbing: int = 0
var current_velocity: Vector2 = Vector2.ZERO
var time_since_last_damage: float = 0.0
var is_alive: bool = true

@onready var screensize = get_viewport_rect().size

# ===== INITIALIZATION =====
func start():
	initialize_player()

func initialize_player():
	"""Initialize all player systems"""
	is_alive = true
	show()
	
	# Set initial position
	reset_position()
	
	# Set initial shield
	shield = max_shield
	
	# Set up timers
	$GunCooldown.wait_time = shoot_cooldown
	$AbsorbCooldown.wait_time = absorb_cooldown
	
	# Apply visual properties
	apply_visuals()
	
	# Custom initialization for child classes
	custom_initialize()

func custom_initialize():
	"""Override this in child classes for custom initialization"""
	pass

func reset_position():
	"""Reset player to starting position"""
	position = Vector2(screensize.x / 2, screensize.y - 64)

func apply_visuals():
	"""Apply visual properties like color and texture"""
	modulate = player_color
	update_sprite()

# ===== MOVEMENT SYSTEM =====
func _process(delta):
	if not is_alive:
		return
	
	process_input(delta)
	process_shield_regen(delta)
	
	# Custom per-frame logic
	custom_process(delta)

func process_input(delta):
	"""Process all player input"""
	handle_absorb_input()
	handle_movement(delta)
	handle_shoot_input()

func handle_movement(delta):
	"""Process player movement with smooth acceleration"""
	var input = Input.get_vector("left", "right", "up", "down")
	
	# Update animations
	update_movement_animation(input.x)
	
	# Calculate target velocity
	var target_velocity = input * speed
	
	# Smooth acceleration/deceleration
	if input.length() > 0:
		current_velocity = current_velocity.lerp(target_velocity, acceleration * delta)
	else:
		current_velocity = current_velocity.lerp(Vector2.ZERO, deceleration * delta)
	
	# Apply movement
	position += current_velocity * delta
	
	# Enforce screen boundaries
	clamp_to_screen()

func update_movement_animation(x_input: float):
	"""Update ship animation based on movement direction"""
	if x_input > 0:
		$Ship.frame = 2
		$Ship/Boosters.animation = "right"
	elif x_input < 0:
		$Ship.frame = 0
		$Ship/Boosters.animation = "left"
	else:
		$Ship.frame = 1
		$Ship/Boosters.animation = "forward"

func clamp_to_screen():
	"""Keep player within screen boundaries"""
	position = position.clamp(Vector2(8, 8), screensize - Vector2(8, 8))

func custom_process(delta: float):
	"""Override this for custom per-frame logic"""
	pass

# ===== SHOOTING SYSTEM =====
func handle_shoot_input():
	"""Check for shoot input and handle shooting"""
	if Input.is_action_pressed("shoot"):
		shoot()

func shoot():
	"""Fire bullets based on current state"""
	if not can_shoot or not is_alive:
		return
	
	can_shoot = false
	$GunCooldown.start()
	
	# Choose bullet type
	var bullet_type = get_current_bullet_type()
	
	# Fire bullets
	if can_multi_shoot and shot_count > 1:
		shoot_multiple(bullet_type)
	else:
		shoot_single(bullet_type)
	
	# Visual/sound effects
	on_shoot()

func get_current_bullet_type() -> PackedScene:
	"""Get the appropriate bullet scene based on absorption state"""
	if is_absorbing > 0:
		return bullet_yellow_scene if bullet_yellow_scene else bullet_scene
	return bullet_scene

func shoot_single(bullet_type: PackedScene):
	"""Shoot a single bullet"""
	var bullet = create_bullet(bullet_type)
	if bullet:
		configure_bullet(bullet)
		launch_bullet(bullet, position + Vector2(0, -8))

func shoot_multiple(bullet_type: PackedScene):
	"""Shoot multiple bullets in a spread"""
	var base_direction = Vector2.UP
	var bullet_spawn = position + Vector2(0, -8)
	
	for i in range(shot_count):
		# Calculate spread angle
		var t = float(i) / max(1, shot_count - 1)
		var angle = shot_spread * (t - 0.5)  # Center the spread
		var direction = base_direction.rotated(deg_to_rad(angle))
		
		var bullet = create_bullet(bullet_type)
		if bullet:
			configure_bullet(bullet)
			
			# Set bullet direction if supported
			if bullet.has_method("set_direction"):
				bullet.set_direction(direction)
			elif bullet.has_method("start"):
				# Pass direction to start method if it accepts it
				bullet.start(bullet_spawn, direction)
			else:
				bullet.start(bullet_spawn)

func create_bullet(bullet_type: PackedScene) -> Node2D:
	"""Create a bullet instance"""
	if not bullet_type:
		return null
	return bullet_type.instantiate()

func configure_bullet(bullet: Node2D):
	"""Configure bullet properties before launching"""
	# Override this for custom bullet configuration
	pass

func launch_bullet(bullet: Node2D, spawn_pos: Vector2):
	"""Launch a bullet into the game"""
	get_tree().root.add_child(bullet)
	
	# Start the bullet
	if bullet.has_method("start"):
		bullet.start(spawn_pos)
	
	# Emit signal
	player_shot.emit(bullet)
	
	# Custom launch behavior
	custom_bullet_launch(bullet)

func custom_bullet_launch(bullet: Node2D):
	"""Override this for custom bullet launch behavior"""
	pass

func on_shoot():
	"""Handle visual and audio effects for shooting"""
	if has_recoil_animation:
		animate_recoil()
	
	# Play shoot sound if available
	# if shoot_sound and $ShootSound:
	#     $ShootSound.stream = shoot_sound
	#     $ShootSound.play()

# ===== ABSORPTION SYSTEM =====
func handle_absorb_input():
	"""Process absorption input"""
	if Input.is_action_pressed("absorb") and can_absorb:
		absorb()
	if Input.is_action_pressed("revert"):
		revert_absorption()

func absorb():
	"""Fire absorption projectile"""
	if not can_absorb or not is_alive:
		return
	
	can_absorb = false
	$GunCooldown.start()
	$AbsorbCooldown.start()
	
	# Create absorption projectile
	var boomerang = create_absorption_projectile()
	if boomerang:
		configure_absorption_projectile(boomerang)
		launch_absorption_projectile(boomerang)
	
	# Visual/sound effects
	on_absorb()

func create_absorption_projectile() -> Node2D:
	"""Create absorption projectile instance"""
	if not absorb_scene:
		return null
	return absorb_scene.instantiate()

func configure_absorption_projectile(projectile: Node2D):
	"""Configure absorption projectile properties"""
	# Override this for custom projectile configuration
	pass

func launch_absorption_projectile(projectile: Node2D):
	"""Launch absorption projectile"""
	get_tree().root.add_child(projectile)
	
	if projectile.has_method("start"):
		projectile.start(position + Vector2(0, -8), self)
	
	# Custom launch behavior
	custom_absorption_launch(projectile)

func custom_absorption_launch(projectile: Node2D):
	"""Override this for custom absorption launch behavior"""
	pass

func on_absorb():
	"""Handle visual and audio effects for absorption"""
	if has_recoil_animation:
		animate_recoil()
	
	# Play absorb sound if available
	# if absorb_sound and $AbsorbSound:
	#     $AbsorbSound.stream = absorb_sound
	#     $AbsorbSound.play()

func revert_absorption():
	"""Revert back to normal state"""
	#if is_absorbing > 0:
	if current_form!='default':
		'''is_absorbing = 0
		update_sprite()
		on_revert_absorption()'''
		self.set_form(default_form.get_modified_properties())
		

func on_revert_absorption():
	"""Called when absorption is reverted"""
	# Override for custom behavior
	pass

func absorb_complete(hit_enemy_type: String):
	"""Called when absorption projectile returns successfully"""
	if hit_enemy_type:
		'''is_absorbing = hit_enemy_type
		update_sprite()
		player_absorbed.emit(hit_enemy_type)'''
		#current_form='yellow'
		#self.set_form(yellow_form.get_modified_properties())
		form_path = "res://transformations/%s.tres" % hit_enemy_type.to_lower()
		form_resource = load(form_path)
		self.set_form(form_resource.get_modified_properties())
		current_form=hit_enemy_type
		
		# Custom behavior based on enemy type
		#on_absorption_complete(hit_enemy_type)

func on_absorption_complete(enemy_type: int):
	"""Override this for custom behavior when absorption completes"""
	pass

# ===== SHIELD/HEALTH SYSTEM =====
func set_shield(value: int):
	"""Setter function for shield"""
	shield = clamp(value, 0, max_shield)
	shield_changed.emit(max_shield, shield)
	
	if shield <= 0 and is_alive:
		die()

func take_damage(damage_amount: int = 1):
	"""Take damage from enemies or hazards"""
	if not is_alive:
		return
	
	shield -= damage_amount
	time_since_last_damage = 0.0
	
	# Visual feedback
	flash_damage()
	
	# Play hit sound if available
	# if hit_sound and $HitSound:
	#     $HitSound.stream = hit_sound
	#     $HitSound.play()
	
	# Custom damage handling
	custom_take_damage(damage_amount)

func custom_take_damage(damage_amount: int):
	"""Override this for custom damage handling"""
	pass

func flash_damage():
	"""Visual feedback when taking damage"""
	var original_color = modulate
	modulate = Color.RED
	
	var timer = get_tree().create_timer(0.1)
	timer.timeout.connect(func(): modulate = original_color)

func heal(amount: int):
	"""Heal the player"""
	if not is_alive:
		return
	
	var old_shield = shield
	shield = min(shield + amount, max_shield)
	
	if shield > old_shield:
		player_healed.emit(shield - old_shield)
		
		# Visual feedback
		modulate = Color.GREEN
		var timer = get_tree().create_timer(0.2)
		timer.timeout.connect(func(): modulate = player_color)

func process_shield_regen(delta: float):
	"""Process automatic shield regeneration"""
	if shield_regen_rate > 0 and shield < max_shield:
		time_since_last_damage += delta
		
		if time_since_last_damage >= shield_regen_delay:
			shield += int(shield_regen_rate * delta)
			shield = min(shield, max_shield)

func die():
	"""Handle player death"""
	if not is_alive:
		return
	
	is_alive = false
	hide()
	died.emit()
	
	# Custom death behavior
	custom_die()

func custom_die():
	"""Override this for custom death behavior"""
	pass

func revive():
	"""Revive the player"""
	if not is_alive:
		is_alive = true
		initialize_player()

# ===== VISUAL SYSTEM =====
func update_sprite():
	"""Update ship sprite based on absorption state"""
	if is_absorbing == 1:
		$Ship.texture = yellow_sprite_texture
		$Ship.hframes = 4
	elif is_absorbing == 2:
		var texture = load("res://Mini Pixel Pack 3/Enemies/Lips (16 x 16).png")
		$Ship.texture = texture
		$Ship.hframes = 5
	else:
		if $Ship is Sprite2D:
			$Ship.hframes = 3
			$Ship.texture = default_sprite_texture
	
	# Custom sprite update
	custom_update_sprite()

func custom_update_sprite():
	"""Override this for custom sprite updates"""
	pass

func animate_recoil():
	"""Play the ship recoil animation when shooting"""
	var tween = create_tween().set_parallel(false)
	tween.tween_property($Ship, "position:y", recoil_distance, recoil_duration)
	tween.tween_property($Ship, "position:y", 0, recoil_duration * 0.5)

# ===== COLLISION HANDLING =====
func _on_area_entered(area):
	"""Handle collision with enemies"""
	if area.is_in_group("enemies"):
		handle_enemy_collision(area)

func handle_enemy_collision(area: Area2D):
	"""Handle collision with enemy"""
	if area.has_method("explode"):
		area.explode()
	
	# Take damage
	take_damage(int(max_shield / 2.0))
	
	# Custom collision handling
	custom_enemy_collision(area)

func custom_enemy_collision(area: Area2D):
	"""Override this for custom enemy collision handling"""
	pass

# ===== HELPER METHODS =====
func set_speed(new_speed: float):
	"""Change player speed"""
	speed = new_speed

func set_shoot_cooldown(new_cooldown: float):
	"""Change shooting cooldown"""
	shoot_cooldown = new_cooldown
	$GunCooldown.wait_time = shoot_cooldown

func set_absorb_cooldown(new_cooldown: float):
	"""Change absorption cooldown"""
	absorb_cooldown = new_cooldown
	$AbsorbCooldown.wait_time = absorb_cooldown

func set_max_shield(new_max_shield: int):
	"""Change maximum shield"""
	max_shield = new_max_shield
	shield = min(shield, max_shield)

func set_bullet_type(new_bullet_scene: PackedScene, is_yellow: bool = false):
	"""Change bullet type"""
	if is_yellow:
		bullet_yellow_scene = new_bullet_scene
	else:
		bullet_scene = new_bullet_scene

func set_multi_shot(enabled: bool, count: int = 1, spread: float = 10.0):
	"""Configure multi-shot"""
	can_multi_shoot = enabled
	shot_count = count
	shot_spread = spread

func set_absorption_level(level: int):
	"""Set absorption level (0 = normal, 1+ = absorbed enemy types)"""
	is_absorbing = clamp(level, 0, max_absorption_level)
	update_sprite()

func is_at_full_shield() -> bool:
	"""Check if player is at full shield"""
	return shield >= max_shield

func get_absorption_level() -> int:
	"""Get current absorption level"""
	return is_absorbing

# ===== TIMER SIGNALS =====
func _on_gun_cooldown_timeout():
	can_shoot = true

func _on_absorb_cooldown_timeout():
	can_absorb = true
	
func set_form(form_data: Dictionary):
	"""
	Set the player's form with the given data.
	Only updates properties that are specified in the dictionary.
	"""
	if not is_alive:
		return
	
	# Store previous form data for transition effects
	var previous_form = current_form_data.duplicate()
	
	# Merge new form data with existing (new values override old ones)
	current_form_data.merge(form_data, true)
	
	# Apply the form changes
	apply_form_changes(form_data, previous_form)

func apply_form_changes(new_data: Dictionary, previous_data: Dictionary):
	"""Apply only the changed properties"""
	
	# Movement properties
	if new_data.has("speed"):
		speed = new_data["speed"]
	
	if new_data.has("acceleration"):
		acceleration = new_data["acceleration"]
	
	if new_data.has("deceleration"):
		deceleration = new_data["deceleration"]
	
	# Health/shield properties
	if new_data.has("max_shield"):
		var new_max_shield = new_data["max_shield"]
		max_shield = new_max_shield
		shield = min(shield, new_max_shield)  # Adjust current shield if needed
	
	if new_data.has("shield_regen_rate"):
		shield_regen_rate = new_data["shield_regen_rate"]
	
	if new_data.has("shield_regen_delay"):
		shield_regen_delay = new_data["shield_regen_delay"]
	
	# Shooting properties
	if new_data.has("shoot_cooldown"):
		shoot_cooldown = new_data["shoot_cooldown"]
		$GunCooldown.wait_time = shoot_cooldown
	
	if new_data.has("bullet_scene"):
		bullet_scene = new_data["bullet_scene"]
	
	if new_data.has("bullet_yellow_scene"):
		bullet_yellow_scene = new_data["bullet_yellow_scene"]
	
	if new_data.has("can_multi_shoot"):
		can_multi_shoot = new_data["can_multi_shoot"]
	
	if new_data.has("shot_count"):
		shot_count = new_data["shot_count"]
	
	if new_data.has("shot_spread"):
		shot_spread = new_data["shot_spread"]
	
	# Visual properties
	if new_data.has("default_sprite_texture"):
		default_sprite_texture = new_data["default_sprite_texture"]
	
	if new_data.has("yellow_sprite_texture"):
		yellow_sprite_texture = new_data["yellow_sprite_texture"]
	
	if new_data.has("player_color"):
		player_color = new_data["player_color"]
		modulate = player_color
	
	# Update sprite if texture changed
	if new_data.has("default_sprite_texture") or new_data.has("yellow_sprite_texture"):
		update_sprite()
	
	# Special: If you want to trigger a transformation animation
	if new_data.has("play_transform_animation") and new_data["play_transform_animation"]:
		play_simple_transition_effect()

func play_simple_transition_effect():
	"""Play a simple transformation effect"""
	var tween = create_tween()
	tween.tween_property($Ship, "modulate", Color(1, 1, 1, 0.5), 0.1)
	tween.tween_property($Ship, "modulate", player_color, 0.1)
