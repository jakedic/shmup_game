# bullet_base.gd
class_name Bullet extends Area2D

# Core bullet properties - all @export for easy customization
@export var speed: float = -250
@export var damage: int = 1
@export var pierce_count: int = 0  # 0 means no piercing
@export var max_distance: float = 1000.0  # Max distance before bullet expires
@export var bounce_count: int = 0  # How many times bullet bounces off screen edges
@export var split_on_death: bool = false  # Split into smaller bullets when destroyed
@export var split_count: int = 2  # How many bullets to split into
@export var split_angle_spread: float = 30.0  # Angle spread for split bullets

# Homing properties
@export var homing_enabled: bool = false
@export var homing_strength: float = 1.0
@export var homing_start_delay: float = 0.0  # Delay before homing starts

# Visual/effect properties
@export var bullet_color: Color = Color.WHITE
@export var trail_enabled: bool = false
@export var trail_length: float = 0.5
@export var glow_enabled: bool = false
@export var glow_color: Color = Color.YELLOW
@export var glow_energy: float = 0.5

# Internal variables
var direction: Vector2 = Vector2.UP
var _target = null
var distance_traveled: float = 0.0
var spawn_position: Vector2
var current_pierce: int = 0
var current_bounce: int = 0
var time_alive: float = 0.0
var is_homing_active: bool = false

var slow_down: int = 0

func _ready():
	"""Called when bullet is added to scene"""
	# Apply visual properties
	apply_visuals()
	
	# Custom initialization for child classes
	custom_ready()

func apply_visuals():
	"""Apply visual properties like color and glow"""
	modulate = bullet_color
	
	if glow_enabled:
		add_glow_effect()

func add_glow_effect():
	"""Add a light/glow effect to the bullet"""
	var light = PointLight2D.new()
	light.color = glow_color
	light.energy = glow_energy
	light.texture_scale = 0.5
	add_child(light)

func start(pos: Vector2, dir: Vector2 = Vector2.UP):
	"""Initialize bullet with starting position and direction"""
	position = pos
	spawn_position = pos
	direction = dir.normalized() if dir.length() > 0 else Vector2.UP
	
	# Start homing delay timer if needed
	if homing_enabled and homing_start_delay > 0:
		await get_tree().create_timer(homing_start_delay).timeout
		is_homing_active = true
	else:
		is_homing_active = homing_enabled
	
	# Custom initialization for child classes
	custom_start()

func custom_ready():
	"""Override this in child classes for custom ready behavior"""
	pass

func custom_start():
	"""Override this in child classes for custom initialization"""
	pass

func _process(delta: float):
	"""Process bullet movement and behavior each frame"""
	time_alive += delta
	
	# Calculate movement
	var movement = direction * speed * delta
	
	# Update position
	position += movement
	
	# Update distance traveled
	distance_traveled += abs(movement.length())
	
	#Slow Down at the end
	if distance_traveled >= max_distance*0.5 and slow_down==0:
		speed=speed/10
		slow_down=1
		return
	
	# Check if bullet has exceeded max distance
	if distance_traveled >= max_distance:
		on_max_distance_reached()
		return
	
	# Handle homing behavior
	if is_homing_active and _target and is_instance_valid(_target):
		update_homing(delta)
	
	# Handle bouncing
	if bounce_count > 0:
		check_bounce()
	
	# Custom per-frame logic for child classes
	custom_process(delta)

func update_homing(delta: float):
	"""Update homing direction toward target"""
	var target_dir = (_target.global_position - global_position).normalized()
	direction = direction.lerp(target_dir, homing_strength * delta).normalized()

func check_bounce():
	"""Handle bullet bouncing off screen edges"""
	var viewport = get_viewport_rect()
	
	# Check screen bounds
	if global_position.x <= 0 or global_position.x >= viewport.size.x:
		direction.x *= -1  # Reverse horizontal direction
		current_bounce += 1
		on_bounce()
	
	if global_position.y <= 0:
		direction.y *= -1  # Reverse vertical direction (only at top)
		current_bounce += 1
		on_bounce()
	
	# Check if bounce limit reached
	if current_bounce >= bounce_count:
		queue_free()

func on_bounce():
	"""Called when bullet bounces - override for custom bounce effects"""
	# Example: Play bounce sound
	# $BounceSound.play() if has_node("BounceSound") else null
	pass

func on_max_distance_reached():
	"""Called when bullet reaches max distance"""
	if split_on_death:
		split_bullet()
	queue_free()

func split_bullet():
	"""Split bullet into multiple smaller bullets"""
	for i in range(split_count):
		var angle = deg_to_rad(split_angle_spread) * (i - (split_count - 1) / 2.0)
		var split_direction = direction.rotated(angle)
		
		# Create split bullet (would need a split bullet scene)
		# var split_bullet = split_bullet_scene.instantiate()
		# get_parent().add_child(split_bullet)
		# split_bullet.start(position, split_direction)
		# split_bullet.damage = damage / 2
		# split_bullet.speed = speed * 0.8
	pass

func custom_process(delta: float):
	"""Override this in child classes for custom per-frame logic"""
	pass

func _on_visible_on_screen_notifier_2d_screen_exited():
	"""Handle when bullet leaves the screen"""
	queue_free()

func _on_area_entered(area: Area2D):
	"""Handle collisions with other areas"""
	if area.is_in_group("enemies"):
		handle_enemy_collision(area)
	
	# Call custom collision handler
	custom_area_collision(area)

func handle_enemy_collision(area: Area2D):
	"""Handle collision with enemy area"""
	if area.is_in_group("enemies"):
		# Prevent multiple collisions in same frame
		if is_queued_for_deletion():
			return
		
		# Damage the enemy
		var enemy_died = false
		if area.has_method("take_damage"):
			enemy_died = await area.take_damage(damage)
		elif area.has_method("explode"):
			area.explode()
			enemy_died = true
		
		# Destroy bullet if no piercing OR enemy didn't die
		if pierce_count == 0:
			queue_free()
			return
		
		# Handle piercing
		if enemy_died:
			# Enemy died, bullet can continue piercing
			current_pierce += 1
			if current_pierce >= pierce_count:
				queue_free()
		else:
			# Enemy survived with health remaining, destroy bullet
			queue_free()

func _on_body_entered(body: Node2D):
	"""Handle collisions with physics bodies"""
	if body.is_in_group("enemies"):
		handle_enemy_body_collision(body)
	
	# Call custom body collision handler
	custom_body_collision(body)

func handle_enemy_body_collision(body: Node2D):
	"""Handle collision with enemy body"""
	var enemy_died = false
	if body.has_method("take_damage"):
		enemy_died = body.take_damage(damage)
	
	if pierce_count == 0 or current_pierce >= pierce_count:
		if not enemy_died and split_on_death:
			split_bullet()
		queue_free()
	else:
		current_pierce += 1

func custom_area_collision(area: Area2D):
	"""Override this in child classes for custom area collision behavior"""
	pass

func custom_body_collision(body: Node2D):
	"""Override this in child classes for custom body collision behavior"""
	pass

# ===== HELPER METHODS =====

func set_target(target: Node2D):
	"""Set a target for homing bullets"""
	_target = target

func set_direction(new_direction: Vector2):
	"""Change bullet direction"""
	direction = new_direction.normalized()

func set_speed(new_speed: float):
	"""Change bullet speed"""
	speed = new_speed

func set_damage(new_damage: int):
	"""Change bullet damage"""
	damage = new_damage

func set_max_distance(new_distance: float):
	"""Change max travel distance"""
	max_distance = new_distance

func set_bullet_color(color: Color):
	"""Change bullet color"""
	bullet_color = color
	modulate = color

func set_pierce_count(count: int):
	"""Change pierce count"""
	pierce_count = count

func set_bounce_count(count: int):
	"""Change bounce count"""
	bounce_count = count

func set_homing(enabled: bool, strength: float = 1.0):
	"""Configure homing behavior"""
	homing_enabled = enabled
	homing_strength = strength

# ===== UTILITY METHODS =====

func get_time_alive() -> float:
	"""Get how long the bullet has been alive"""
	return time_alive

func get_distance_from_spawn() -> float:
	"""Get current distance from spawn point"""
	return position.distance_to(spawn_position)

func is_near_target(threshold: float = 50.0) -> bool:
	"""Check if bullet is near its homing target"""
	if not _target or not is_instance_valid(_target):
		return false
	return global_position.distance_to(_target.global_position) <= threshold

func change_direction_towards(point: Vector2, turn_rate: float = 1.0):
	"""Gradually turn bullet toward a point"""
	var target_dir = (point - global_position).normalized()
	direction = direction.lerp(target_dir, turn_rate).normalized()
