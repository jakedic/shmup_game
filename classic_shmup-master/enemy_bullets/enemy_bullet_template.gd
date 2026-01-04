# enemy_bullet_base.gd
class_name EnemyBullet extends Area2D

# Export properties for easy customization in child classes or in the editor
@export var speed: float = 150
@export var damage: int = 1
@export var max_distance: float = 1000.0  # How far bullet travels before disappearing
@export var pierce_count: int = 0  # How many times bullet can pierce through enemies
@export var homing_enabled: bool = false
@export var homing_strength: float = 1.0
@export var bounce_count: int = 0  # How many times bullet bounces off screen edges

# Internal variables
var direction: Vector2 = Vector2.DOWN  # Default direction (downward)
var distance_traveled: float = 0.0
var spawn_position: Vector2
var current_pierce: int = 0
var current_bounce: int = 0
var target = null  # For homing bullets

func start(pos: Vector2, dir: Vector2 = Vector2.DOWN):
	"""Initialize bullet with starting position and direction"""
	position = pos
	spawn_position = pos
	direction = dir.normalized() if dir.length() > 0 else Vector2.DOWN
	
	# Optional: Add initialization for child classes
	custom_start()

func custom_start():
	"""Override this in child classes for custom initialization"""
	pass

func _process(delta):
	"""Process bullet movement each frame"""
	var movement = direction * speed * delta
	position += movement
	distance_traveled += abs(movement.length())
	
	# Check if bullet has exceeded max distance
	if distance_traveled >= max_distance:
		queue_free()
		return
	
	# Handle homing behavior
	if homing_enabled and target and is_instance_valid(target):
		var target_dir = (target.global_position - global_position).normalized()
		direction = direction.lerp(target_dir, homing_strength * delta).normalized()
	
	# Handle bouncing
	if bounce_count > 0:
		check_bounce()
	
	# Optional: Custom process for child classes
	custom_process(delta)

func custom_process(delta: float):
	"""Override this in child classes for custom per-frame logic"""
	pass

func check_bounce():
	"""Handle bullet bouncing off screen edges"""
	var viewport = get_viewport_rect()
	
	# Check screen bounds
	if global_position.x <= 0 or global_position.x >= viewport.size.x:
		direction.x *= -1  # Reverse horizontal direction
		current_bounce += 1
		on_bounce()
	
	if global_position.y <= 0 or global_position.y >= viewport.size.y:
		direction.y *= -1  # Reverse vertical direction
		current_bounce += 1
		on_bounce()
	
	# Check if bounce limit reached
	if current_bounce >= bounce_count:
		queue_free()

func on_bounce():
	"""Called when bullet bounces - override for custom bounce effects"""
	pass

func _on_visible_on_screen_notifier_2d_screen_exited():
	"""Handle when bullet leaves the screen"""
	queue_free()

func _on_area_entered(area):
	"""Handle collisions with other areas"""
	if area.name == "Player":
		# Damage the player
		if area.has_method("take_damage"):
			area.take_damage(damage)
		elif area.has_method("_on_area_entered"):
			# Fallback for original player script
			area.shield -= damage
		
		# Handle piercing
		if pierce_count == 0 or current_pierce >= pierce_count:
			queue_free()
		else:
			current_pierce += 1
	
	# Call custom collision handler for child classes
	custom_collision(area)

func _on_body_entered(body):
	"""Handle collisions with physics bodies"""
	if body.name == "Player":
		if body.has_method("take_damage"):
			body.take_damage(damage)
		elif body.has_method("_on_area_entered"):
			body.shield -= damage
		
		if pierce_count == 0 or current_pierce >= pierce_count:
			queue_free()
		else:
			current_pierce += 1
	
	custom_body_collision(body)

func custom_collision(area: Area2D):
	"""Override this in child classes for custom collision behavior"""
	pass

func custom_body_collision(body: Node2D):
	"""Override this in child classes for custom body collision behavior"""
	pass

# Helper methods for child classes or external control
func set_target(new_target: Node2D):
	"""Set a target for homing bullets"""
	target = new_target

func set_direction(new_direction: Vector2):
	"""Change bullet direction"""
	direction = new_direction.normalized()

func set_speed(new_speed: float):
	"""Change bullet speed"""
	speed = new_speed

func set_damage(new_damage: int):
	"""Change bullet damage"""
	damage = new_damage
