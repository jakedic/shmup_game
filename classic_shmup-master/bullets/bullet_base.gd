# bullet_base.gd
class_name Bullet extends Area2D

@export var speed: float = -250
var direction: Vector2 = Vector2.UP  # Optional: for directional bullets

# Optional: Add customizable properties
@export var damage: int = 1
@export var pierce_count: int = 0  # 0 means no piercing
@export var lifespan: float = 5.0  # Time before auto-destruction
@export var homing_enabled: bool = false
@export var homing_strength: float = 1.0

var current_pierce: int = 0
var _target = null

func start(pos: Vector2, dir: Vector2 = Vector2.UP):
	position = pos
	direction = dir.normalized() if dir.length() > 0 else Vector2.UP
	
	# Set up auto-destruction timer if lifespan is set
	if lifespan > 0:
		$BulletTimer.wait_time = lifespan
		$BulletTimer.start()

func _process(delta: float):
	# Basic movement
	position += direction * speed * delta
	
	# Optional homing behavior
	if homing_enabled and _target and is_instance_valid(_target):
		var target_dir = (_target.global_position - global_position).normalized()
		direction = direction.lerp(target_dir, homing_strength * delta).normalized()

func _on_visible_on_screen_notifier_2d_screen_exited():
	queue_free()

func _on_area_entered(area: Area2D):
	if area.is_in_group("enemies"):
		# Apply damage to enemy (assuming enemy has a take_damage function)
		if area.has_method("take_damage"):
			area.take_damage(damage)
		
		# Handle piercing
		if pierce_count > 0 and current_pierce < pierce_count:
			current_pierce += 1
		else:
			queue_free()
		
		# Call explode if enemy has that method
		if area.has_method("explode"):
			area.explode()

func _on_body_entered(body: Node2D):
	# Optional: handle body collisions too
	if body.is_in_group("enemies"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
		if pierce_count == 0 or current_pierce >= pierce_count:
			queue_free()

func _on_bullettimer_timeout():
	queue_free()

# Optional: Helper methods
func set_target(target: Node2D):
	_target = target

func set_speed(new_speed: float):
	speed = new_speed

func set_damage(new_damage: int):
	damage = new_damage
