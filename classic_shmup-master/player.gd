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
@export var shot_spread: float = 30.0  # degrees

# Absorption properties
@export var absorb_scene: PackedScene
@export var absorb_cooldown: float = 2.0
@export var max_absorption_level: int = 2  # Maximum enemy types that can be absorbed

# ===== DASH SYSTEM VARIABLES =====
@export var dash_speed: float = 400.0  # Speed while dashing
@export var dash_duration: float = 0.15  # How long the dash lasts
@export var dash_cooldown: float = 0.5  # Cooldown between dashes
var spin_speed: float = 0.0
var steering_influence = 5

var circle_radius = 0.0
var circle_speed = 0.0

var dash_time = 0.0
var bullet_invincible_during_dash: bool = false
var do_dash_damage_to_enemies: bool = false  # Turn this on to damage enemies during dash
var dash_damage_amount: int = 1  # How much damage to deal to enemies during dash

# Double-tap detection variables
const DOUBLETAP_DELAY = 0.25
var doubletap_time_left = 0.0
var doubletap_time_right = 0.0
var doubletap_time_up = 0.0
var doubletap_time_down = 0.0
var last_direction_input = Vector2.ZERO
var dash_timer: Timer
var dash_cooldown_timer: Timer
var is_dashing: bool = false
var can_dash: bool = true
var dash_direction: Vector2 = Vector2.ZERO
var original_speed: float

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
	
	setup_dash_timers()
	original_speed = speed
	can_dash = true
	is_dashing = false
	
	
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
	
	# Update double-tap timers
	update_doubletap_timers(delta)
	
	if is_dashing and is_instance_valid($Ship):
		$Ship.rotation += deg_to_rad(spin_speed) * delta


func process_input(delta):
	"""Process all player input"""
	handle_absorb_input()
	handle_movement(delta)
	handle_shoot_input()
	handle_dash_input()  # Add this line

func handle_movement(delta):
	"""Process player movement with smooth acceleration"""
	var input = Input.get_vector("left", "right", "up", "down")
	
	# If dashing, override input with dash direction
	
	if is_dashing:
		# Get the dash direction (initial direction when dash started)
		var base_dash_dir = dash_direction
		
		# Track dash time for circular motion
		dash_time += delta

		# Create perpendicular vector (90 degrees)
		var perpendicular_dir = base_dash_dir.rotated(PI/2)

		# Adjust circle size and speed

		# Create a vector that will rotate in a circle
		# Start with a vector pointing to the "right" of the perpendicular direction
		var circle_vector = Vector2(circle_radius, 0)

		# Rotate it over time
		var rotation_angle = dash_time * circle_speed
		circle_vector = circle_vector.rotated(rotation_angle)

		# Now rotate this circle to align with our perpendicular plane
		# We need to rotate it so it's perpendicular to our dash direction
		var circle_offset = circle_vector.rotated(perpendicular_dir.angle())

		# Apply player input to modify dash direction
		var modified_direction = (base_dash_dir + input * steering_influence).normalized()

		# Smoothly transition to new direction
		dash_direction = dash_direction.lerp(modified_direction, 2.0 * delta)

		# Apply dash velocity with circular motion added
		current_velocity = (dash_direction * dash_speed) - circle_offset
	else:
		# Reset dash time when not dashing
		dash_time = 0
		
		# Normal movement with acceleration/deceleration
		if input.length() > 0:
			current_velocity = current_velocity.lerp(input * speed, acceleration * delta)
		else:
			current_velocity = current_velocity.lerp(Vector2.ZERO, deceleration * delta)
		
	# Update animations (skip animation during dash for different effect)
	if not is_dashing:
		update_movement_animation(input.x)
	else:
		# Special dash animation
		$Ship.frame = 1  # Forward frame during dash
		$Ship/Boosters.animation = "forward"
		#$Ship.modulate = Color(0.5, 0.8, 1.0)  # Blue tint
	
	# Apply movement
	position += current_velocity * delta
	
	# Enforce screen boundaries
	clamp_to_screen()

func can_player_dash() -> bool:
	"""Check if player can dash"""
	return can_dash and is_alive and not is_dashing

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

func setup_dash_timers():
	"""Set up timers for dash duration and cooldown"""
	dash_timer = Timer.new()
	dash_timer.name = "DashTimer"
	dash_timer.one_shot = true
	dash_timer.timeout.connect(_on_dash_timer_timeout)
	add_child(dash_timer)
	
	dash_cooldown_timer = Timer.new()
	dash_cooldown_timer.name = "DashCooldownTimer"
	dash_cooldown_timer.one_shot = true
	dash_cooldown_timer.timeout.connect(_on_dash_cooldown_timeout)
	add_child(dash_cooldown_timer)
	
func update_doubletap_timers(delta: float):
	"""Update all double-tap detection timers"""
	if doubletap_time_left > 0:
		doubletap_time_left -= delta
	if doubletap_time_right > 0:
		doubletap_time_right -= delta
	if doubletap_time_up > 0:
		doubletap_time_up -= delta
	if doubletap_time_down > 0:
		doubletap_time_down -= delta
		
func handle_dash_input():
	"""Handle dash input based on double-tap detection"""
	if not is_alive or not can_dash or is_dashing:
		return
	
	# Check for double-tap in each direction
	if Input.is_action_just_pressed("left"):
		if doubletap_time_left > 0:
			start_dash(Vector2.LEFT)
		else:
			doubletap_time_left = DOUBLETAP_DELAY
	
	if Input.is_action_just_pressed("right"):
		if doubletap_time_right > 0:
			start_dash(Vector2.RIGHT)
		else:
			doubletap_time_right = DOUBLETAP_DELAY
	
	if Input.is_action_just_pressed("up"):
		if doubletap_time_up > 0:
			start_dash(Vector2.UP)
		else:
			doubletap_time_up = DOUBLETAP_DELAY
	
	if Input.is_action_just_pressed("down"):
		if doubletap_time_down > 0:
			start_dash(Vector2.DOWN)
		else:
			doubletap_time_down = DOUBLETAP_DELAY
	
	# Also check for double-tap using held direction + opposite press
	# (Alternative method: tap direction, release, tap same direction quickly)
	var input = Input.get_vector("left", "right", "up", "down")
	if input != Vector2.ZERO and input != last_direction_input:
		# Check if this is a quick return to the same direction
		if last_direction_input != Vector2.ZERO and input.dot(last_direction_input) > 0.7:
			# This detects quick direction changes (like left-right-left)
			pass
	last_direction_input = input
	
func start_dash(direction: Vector2):
	"""Start a dash in the given direction"""
	if not can_dash or is_dashing:
		return
	
	# Normalize diagonal dashes
	if direction.length() > 1:
		direction = direction.normalized()
	
	dash_direction = direction
	is_dashing = true
	can_dash = false
	
	# Change to dash speed
	speed = dash_speed
	
	if bullet_invincible_during_dash:
		# Disable collision with enemy bullets
		set_collision_layer_value(1, false)  # Disable player collision layer
		set_collision_mask_value(2, false)   # Disable enemy bullet collision mask
		# Also disable collision with enemies themselves if desired
		#set_collision_mask_value(1, false)   # Disable enemy collision mask
	
	
	# Start dash duration timer
	dash_timer.start(dash_duration)
	
	# Visual feedback for dash
	on_dash_start()

func on_dash_start():
	"""Visual and audio effects for dash start"""
	# Visual effect
	modulate = Color(0.5, 0.8, 1.0, 0.7)  # Blue tint during dash
	
	# Particle effect (if you have one)
	if has_node("DashParticles"):
		$DashParticles.emitting = true
	
	# Sound effect
	# if dash_sound and $DashSound:
	#     $DashSound.stream = dash_sound
	#     $DashSound.play()

func on_dash_end():
	"""Clean up dash effects"""
	# Restore normal speed
	speed = original_speed
	is_dashing = false
	
	if bullet_invincible_during_dash:
		set_collision_layer_value(1, true)    # Re-enable player collision layer
		set_collision_mask_value(2, true)     # Re-enable enemy bullet collision mask
		#set_collision_mask_value(1, true)     # Re-enable enemy collision mask
	
	# Restore normal appearance
	modulate = player_color
	
	# Stop particle effects
	if has_node("DashParticles"):
		$DashParticles.emitting = false
	
	# Start cooldown timer
	dash_cooldown_timer.start(dash_cooldown)
	
	if is_instance_valid($Ship):
		$Ship.rotation = 0
	
	# Restore collision (if disabled)
	# set_collision_layer_value(1, true)
	# set_collision_mask_value(2, true)

func _on_dash_timer_timeout():
	"""Called when dash duration ends"""
	on_dash_end()

func _on_dash_cooldown_timeout():
	"""Called when dash cooldown ends"""
	can_dash = true

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
		launch_absorption_projectile(boomerang)
	
	# Visual/sound effects
	on_absorb()

func create_absorption_projectile() -> Node2D:
	"""Create absorption projectile instance"""
	if not absorb_scene:
		return null
	return absorb_scene.instantiate()

func launch_absorption_projectile(projectile: Node2D):
	"""Launch absorption projectile"""
	get_tree().root.add_child(projectile)
	
	if projectile.has_method("start"):
		projectile.start(position + Vector2(0, -8), self)
	

func on_absorb():
	"""Handle visual and audio effects for absorption"""
	if has_recoil_animation:
		animate_recoil()
	
	# Play absorb sound if available
	# if absorb_sound and $AbsorbSound:
	#     $AbsorbSound.stream = absorb_sound
	#     $AbsorbSound.play()

func revert_absorption():
	if current_form != 'default':
		# Reset to default form
		reset_to_default_form()
		current_form = 'default'

func reset_to_default_form():
	speed = original_speed
	shoot_cooldown = 0.25  # Your default value
	$GunCooldown.wait_time = shoot_cooldown
	max_shield = 10  # Your default value
	shield = min(shield, max_shield)
	shield_regen_rate = 0.0  # Your default value
	absorb_cooldown = 2.0  # Your default value
	$AbsorbCooldown.wait_time = absorb_cooldown
	can_multi_shoot = false  # Your default value
	shot_count = 1  # Your default value
	bullet_scene=load("res://bullets/bullet.tscn")
	circle_radius = 0
	circle_speed = 0
	spin_speed=0
	steering_influence=5
	dash_duration=0.15
	bullet_invincible_during_dash=false
	do_dash_damage_to_enemies=false
	
	# Reset visual appearance
	modulate = player_color
	update_sprite()
		

'''func absorb_complete(hit_enemy_type: String):
	"""Called when absorption projectile returns successfully"""
	if hit_enemy_type:

		form_path = "res://transformations/%s.tres" % hit_enemy_type.to_lower()
		form_resource = load(form_path)
		self.set_form(form_resource.get_modified_properties())
		current_form=hit_enemy_type'''
		
func absorb_complete(hit_enemy_type: String):
	if hit_enemy_type:
		current_form = hit_enemy_type
		
		# Call the corresponding transformation function
		var transform_func_name = get_transformation_function_name(hit_enemy_type)
		
		if has_method(transform_func_name):
			call(transform_func_name)
		else:
			print("No transformation function found for: ", hit_enemy_type)
			# Fall back to resource-based transformation
		'''form_path = "res://transformations/%s.tres" % hit_enemy_type.to_lower()
		if ResourceLoader.exists(form_path):
			form_resource = load(form_path)
			self.set_form(form_resource.get_modified_properties())'''

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
	
	# Check if we're dashing and should damage enemies instead of taking damage
	if is_dashing and do_dash_damage_to_enemies:
		# Player deals damage to enemy during dash
		var damage_dealt = false
		
		if area.has_method("take_damage"):
			area.take_damage(dash_damage_amount)
			damage_dealt = true
		elif area.has_method("explode"):
			area.explode()
			damage_dealt = true
		
		# Optional: Apply knockback to enemy
		if area.has_method("apply_knockback") and damage_dealt:
			var knockback_direction = (area.global_position - global_position).normalized()
			area.apply_knockback(knockback_direction, dash_speed * 0.5)
		
		# Optional: Add visual feedback for damaging enemies during dash
		if damage_dealt:
			if has_node("DashDamageParticles"):
				$DashDamageParticles.global_position = area.global_position
				$DashDamageParticles.emitting = true
			
			# Optional screen shake effect
			if get_tree().has_group("camera"):
				get_tree().call_group("camera", "add_trauma", 0.3)
		
		# Return early - player doesn't take damage during dash
		return
	
	# Normal collision handling (player takes damage)
	if area.has_method("explode"):
		area.explode()
	
	# Take damage
	take_damage(int(max_shield / 2.0))
	
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

func play_simple_transition_effect():
	"""Play a simple transformation effect"""
	var tween = create_tween()
	tween.tween_property($Ship, "modulate", Color(1, 1, 1, 0.5), 0.1)
	tween.tween_property($Ship, "modulate", player_color, 0.1)

func get_transformation_function_name(enemy_type: String) -> String:
	return "transform_" + enemy_type.to_lower()
	
# ===== TRANSFORMATION FUNCTIONS =====

func transform_yellow():
	speed = original_speed * 2
	
	# Optional visual feedback
	modulate = Color.YELLOW
	var timer = get_tree().create_timer(0.5)
	timer.timeout.connect(func(): modulate = player_color)
	
	var yellow_texture = load("res://Player_topdown_placeholder_transformation_sprite.png")
	$Ship.texture = yellow_texture
	$Ship.hframes = 3  # Adjust this to match your yellow sprite's frame count
	
	circle_radius = 600.0
	circle_speed = 20.0
	dash_duration=dash_duration*2.5
	dash_speed=dash_speed*.5
	
	bullet_invincible_during_dash=true
	
	# Change bullets to yellow bullets
	# If you want ALL bullets to be yellow while transformed:
	bullet_scene = load("res://bullets/bullet_yellow.tscn")

func transform_red():

	shoot_cooldown = max(0.05, shoot_cooldown * 0.75)  # Halve cooldown (faster shooting)
	$GunCooldown.wait_time = shoot_cooldown
	
	# Visual feedback
	modulate = Color.RED
	var timer = get_tree().create_timer(0.5)
	timer.timeout.connect(func(): modulate = player_color)
	
	var red_texture = load("res://Player_topdown_placeholder_transformation_sprite.png")
	$Ship.texture = red_texture
	$Ship.hframes = 3 
	
	dash_duration=dash_duration*15
	dash_speed=dash_speed/5
	spin_speed=2080
	steering_influence=steering_influence*4
	do_dash_damage_to_enemies=true
