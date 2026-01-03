# base_enemy.gd
extends Area2D
class_name BaseEnemy  # Makes it available as a class

signal died(value: int)
signal health_changed(current_health: int, max_health: int)  # Optional: for health bars

# Common properties for ALL enemies
var start_pos = Vector2.ZERO
var speed = 0
var anchor
var follow_anchor = false

# Health system
@export var max_health: int = 1  # Make this exportable to set different health per enemy type
var current_health: int

@onready var screensize = get_viewport_rect().size

# Must be implemented by child classes
var bullet_scene: PackedScene

func _ready():
	current_health = max_health  # Initialize health
	# If you want to set a specific bullet for this enemy type:
	bullet_scene = preload("res://bullets/enemy_bullet.tscn")

func start(pos: Vector2):
	follow_anchor = false
	speed = 0
	position = Vector2(pos.x, -pos.y)
	start_pos = pos
	await get_tree().create_timer(randf_range(0.25, 0.55)).timeout
	var tw = create_tween().set_trans(Tween.TRANS_BACK)
	tw.tween_property(self, "position:y", start_pos.y, 1.4)
	await tw.finished
	follow_anchor = true
	$MoveTimer.wait_time = randf_range(5, 20)
	$MoveTimer.start()
	$ShootTimer.wait_time = randf_range(4, 20)
	$ShootTimer.start()

func _process(delta):
	if follow_anchor:
		position = start_pos + anchor.position
	position.y += speed * delta
	if position.y > screensize.y + 32:
		start(start_pos)

# Function to take damage
func take_damage(damage_amount: int = 1):
	current_health -= damage_amount
	health_changed.emit(current_health, max_health)
	
	if current_health <= 0:
		die()
		return true
	
	# Try RED flash instead of white (more noticeable)
	var original_modulate = modulate
	
	# Flash red
	modulate = Color.RED
	
	# Reset after delay using timer
	var reset_timer = Timer.new()
	add_child(reset_timer)
	reset_timer.one_shot = true
	reset_timer.wait_time = 0.1
	reset_timer.timeout.connect(_on_damage_flash_timeout.bind(original_modulate, reset_timer))
	reset_timer.start()
	
	return false

func _on_damage_flash_timeout(original_color: Color, timer: Timer):
	modulate = original_color
	timer.queue_free()

# Function to handle death
func die():
	# Stop all timers
	$MoveTimer.stop()
	$ShootTimer.stop()
	
	# Call explode for visual effect
	explode()

func explode():
	speed = 0
	$AnimationPlayer.play("explode")
	set_deferred("monitorable", false)
	died.emit(5)  # Default 5 points
	await $AnimationPlayer.animation_finished
	queue_free()

func _on_timer_timeout():
	speed = randf_range(75, 100)
	follow_anchor = false

# Method for enemy shooting
func _on_shoot_timer_timeout():
	shoot_bullet(position)
	$ShootTimer.wait_time = randf_range(4, 20)
	$ShootTimer.start()

# Common method for shooting
func shoot_bullet(bullet_position: Vector2):
	var b = bullet_scene.instantiate()
	get_tree().root.add_child(b)
	b.start(bullet_position)

# Optional: Healing function
func heal(heal_amount: int):
	current_health = min(current_health + heal_amount, max_health)
	health_changed.emit(current_health, max_health)
	
	# Visual feedback for healing
	modulate = Color.GREEN
	await get_tree().create_timer(0.1).timeout
	modulate = Color.WHITE

# Optional: Getter for health percentage
func get_health_percentage() -> float:
	return float(current_health) / float(max_health)
