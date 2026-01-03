# bullet_base.gd
class_name Bullet extends Area2D

@export var speed: float = -250
var direction: Vector2 = Vector2.UP  # Optional: for directional bullets

# Optional: Add customizable properties
@export var damage: int = 1
@export var pierce_count: int = 0  # 0 means no piercing
@export var max_distance: float = 1000.0  # Max distance before bullet expires
@export var homing_enabled: bool = false
@export var homing_strength: float = 1.0

var current_pierce: int = 0
var _target = null
var distance_traveled: float = 0.0
var spawn_position: Vector2

func start(pos: Vector2, dir: Vector2 = Vector2.UP):
	position = pos
	spawn_position = pos  # Store where the bullet was spawned
	direction = dir.normalized() if dir.length() > 0 else Vector2.UP

func _process(delta: float):
	# Calculate movement
	var movement = direction * speed * delta
	
	# Update position
	position += movement
	
	# Update distance traveled
	distance_traveled += abs(movement.length())
	
	# Check if bullet has exceeded max distance
	if distance_traveled >= max_distance:
		queue_free()
	
	# Optional homing behavior
	if homing_enabled and _target and is_instance_valid(_target):
		var target_dir = (_target.global_position - global_position).normalized()
		direction = direction.lerp(target_dir, homing_strength * delta).normalized()

func _on_visible_on_screen_notifier_2d_screen_exited():
	queue_free()

func _on_area_entered(area: Area2D):
	if area.is_in_group("enemies"):
		# Damage the enemy
		if area.has_method("take_damage"):
			area.take_damage(damage)
		elif area.has_method("explode"):
			area.explode()
		
		# Handle piercing
		if pierce_count == 0:
			# No piercing - always destroy bullet
			queue_free()
		else:
			# Has piercing capability
			current_pierce += 1
			if current_pierce >= pierce_count:
				queue_free()  # Destroy after max pierces

func _on_body_entered(body: Node2D):
	# Optional: handle body collisions too
	if body.is_in_group("enemies"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
		if pierce_count == 0 or current_pierce >= pierce_count:
			queue_free()

# Optional: Helper methods
func set_target(target: Node2D):
	_target = target

func set_speed(new_speed: float):
	speed = new_speed

func set_damage(new_damage: int):
	damage = new_damage

func set_max_distance(new_distance: float):
	max_distance = new_distance
