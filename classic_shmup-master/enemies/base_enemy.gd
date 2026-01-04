# base_enemy.gd
extends Area2D
class_name BaseEnemy

signal died(value: int)
signal health_changed(current_health: int, max_health: int)
signal enemy_shot(bullet: Node2D)  # Signal when enemy shoots

# ===== CUSTOMIZABLE PROPERTIES =====
@export var enemy_name: String = "Enemy"

# Health properties
@export var max_health: int = 1
@export var score_value: int = 5  # Points when killed

# Movement properties
@export var base_speed: float = 0
@export var dive_speed_min: float = 75.0
@export var dive_speed_max: float = 100.0
@export var can_dive: bool = true  # Whether enemy can dive toward player
@export var follow_anchor_enabled: bool = true

# Shooting properties
@export var can_shoot: bool = true
@export var bullet_scene: PackedScene
@export var shoot_cooldown_min: float = 4.0
@export var shoot_cooldown_max: float = 20.0
@export var bullet_damage: int = 1
@export var bullet_speed: float = 150.0
@export var multi_shot: bool = false
@export var shot_count: int = 1
@export var shot_spread: float = 15.0  #degrees

# Appearance properties
@export var enemy_color: Color = Color.WHITE
@export var has_damage_flash: bool = true
@export var flash_color: Color = Color.RED
@export var flash_duration: float = 0.1

# Spawn properties
@export var spawn_delay_min: float = 0.25
@export var spawn_delay_max: float = 0.55
@export var spawn_animation_duration: float = 1.4

# ===== INTERNAL VARIABLES =====
var start_pos = Vector2.ZERO
var current_speed = 0.0
var anchor
var follow_anchor = false
var current_health: int
var is_alive: bool = true

@onready var screensize = get_viewport_rect().size

func _ready():
	current_health = max_health
	modulate = enemy_color
	
	# Load bullet scene if not set in editor
	if not bullet_scene:
		bullet_scene = preload("res://enemy_bullets/enemy_bullet.tscn")
	
	# Custom ready for child classes
	custom_ready()

func custom_ready():
	"""Override this in child classes for custom initialization"""
	pass

func start(pos: Vector2):
	"""Initialize enemy at position"""
	if not is_alive:
		return
	
	start_pos = pos
	follow_anchor = false
	current_speed = 0
	
	# Set initial position above screen
	position = Vector2(pos.x, -pos.y)
	
	# Custom start logic
	custom_start(pos)
	
	# Wait random delay before spawning
	await get_tree().create_timer(randf_range(spawn_delay_min, spawn_delay_max)).timeout
	
	# Animate entrance
	var tw = create_tween().set_trans(Tween.TRANS_BACK)
	tw.tween_property(self, "position:y", start_pos.y, spawn_animation_duration)
	await tw.finished
	
	# Start normal behavior
	on_spawn_complete()

func custom_start(pos: Vector2):
	"""Override this for custom start behavior"""
	pass

func on_spawn_complete():
	"""Called when enemy finishes spawning animation"""
	if follow_anchor_enabled:
		follow_anchor = true
	
	if can_shoot:
		$ShootTimer.wait_time = randf_range(shoot_cooldown_min, shoot_cooldown_max)
		$ShootTimer.start()
	
	if can_dive:
		$MoveTimer.wait_time = randf_range(5, 20)
		$MoveTimer.start()
	
	# Custom spawn complete logic
	custom_spawn_complete()

func custom_spawn_complete():
	"""Override this for custom behavior after spawning"""
	pass

func _process(delta):
	if not is_alive:
		return
	
	# Update position
	if follow_anchor and anchor:
		position = start_pos + anchor.position
	
	position.y += current_speed * delta
	
	# Handle screen boundaries
	handle_boundaries()
	
	# Custom per-frame logic
	custom_process(delta)

func handle_boundaries():
	"""Handle screen boundary behavior"""
	if position.y > screensize.y + 32:
		reset_position()

func reset_position():
	"""Reset enemy to original position (for diving enemies)"""
	if is_alive:
		start(start_pos)

func custom_process(delta: float):
	"""Override this for custom per-frame logic"""
	pass

# ===== HEALTH & DAMAGE SYSTEM =====
func take_damage(damage_amount: int = 1) -> bool:
	if not is_alive:
		return true
	
	current_health -= damage_amount
	health_changed.emit(current_health, max_health)
	
	# Custom damage handling
	if custom_take_damage(damage_amount):
		return true
	
	if current_health <= 0:
		die()
		return true
	
	# Visual damage feedback
	if has_damage_flash:
		flash_damage()
	
	return false

func custom_take_damage(damage_amount: int) -> bool:
	"""Override this for custom damage handling. Return true if enemy died."""
	return false

func flash_damage():
	"""Visual feedback when taking damage"""
	var original_color = modulate
	modulate = flash_color
	
	# Reset color after delay
	var timer = get_tree().create_timer(flash_duration)
	timer.timeout.connect(_reset_color.bind(original_color))

func _reset_color(color: Color):
	modulate = color

func heal(heal_amount: int):
	"""Heal the enemy"""
	if not is_alive:
		return
	
	current_health = min(current_health + heal_amount, max_health)
	health_changed.emit(current_health, max_health)
	
	# Visual feedback
	modulate = Color.GREEN
	var timer = get_tree().create_timer(0.1)
	timer.timeout.connect(func(): modulate = enemy_color)

func get_health_percentage() -> float:
	"""Get current health as percentage (0.0 to 1.0)"""
	return float(current_health) / float(max_health)

func die():
	"""Handle enemy death"""
	if not is_alive:
		return
	
	is_alive = false
	
	# Stop all timers
	$MoveTimer.stop()
	$ShootTimer.stop()
	
	# Custom death logic
	custom_die()
	
	# Explode for visual effect
	explode()

func custom_die():
	"""Override this for custom death behavior"""
	pass

func explode():
	"""Play explosion animation and remove enemy"""
	current_speed = 0
	set_deferred("monitorable", false)
	
	# Emit died signal with score value
	died.emit(score_value)
	
	# Custom explosion
	custom_explode()
	
	# Wait for animation if exists
	if $AnimationPlayer.has_animation("explode"):
		$AnimationPlayer.play("explode")
		await $AnimationPlayer.animation_finished
	
	queue_free()

func custom_explode():
	"""Override this for custom explosion effects"""
	pass

# ===== SHOOTING SYSTEM =====
func _on_shoot_timer_timeout():
	"""Handle shoot timer timeout"""
	if not is_alive or not can_shoot:
		return
	
	shoot()
	
	# Reset timer with random cooldown
	if can_shoot:
		$ShootTimer.wait_time = randf_range(shoot_cooldown_min, shoot_cooldown_max)
		$ShootTimer.start()

func shoot():
	"""Execute shooting behavior"""
	if multi_shot and shot_count > 1:
		shoot_multiple()
	else:
		shoot_single()

func shoot_single():
	"""Shoot a single bullet"""
	var bullet = create_bullet()
	configure_bullet(bullet)
	launch_bullet(bullet, position)

func shoot_multiple():
	"""Shoot multiple bullets in a spread"""
	for i in range(shot_count):
		var angle_offset = deg_to_rad(shot_spread) * (i - (shot_count - 1) / 2.0)
		var bullet = create_bullet()
		configure_bullet(bullet)
		
		# Set direction with spread
		var direction = Vector2.DOWN.rotated(angle_offset)
		bullet.set_direction(direction)
		
		launch_bullet(bullet, position)

func create_bullet() -> Node2D:
	"""Create and configure a bullet instance"""
	var bullet = bullet_scene.instantiate()
	
	# Try to set bullet properties if they exist
	if bullet.has_method("set_damage"):
		bullet.set_damage(bullet_damage)
	if bullet.has_method("set_speed"):
		bullet.set_speed(bullet_speed)
	
	return bullet

func configure_bullet(bullet: Node2D):
	"""Configure bullet properties before launching"""
	# Override this in child classes for custom bullet configuration
	pass

func launch_bullet(bullet: Node2D, bullet_position: Vector2):
	"""Launch a bullet from position"""
	get_tree().root.add_child(bullet)
	bullet.start(bullet_position)
	
	# Emit signal
	enemy_shot.emit(bullet)
	
	# Custom launch behavior
	custom_bullet_launch(bullet)

func custom_bullet_launch(bullet: Node2D):
	"""Override this for custom bullet launch behavior"""
	pass

# ===== MOVEMENT SYSTEM =====
func _on_move_timer_timeout():
	"""Handle move timer timeout (initiate dive)"""
	if not is_alive or not can_dive:
		return
	
	initiate_dive()

func initiate_dive():
	"""Start diving toward player"""
	if follow_anchor_enabled:
		follow_anchor = false
	
	current_speed = randf_range(dive_speed_min, dive_speed_max)
	
	# Custom dive behavior
	custom_dive()

func custom_dive():
	"""Override this for custom dive behavior"""
	pass

# ===== HELPER METHODS =====
func set_anchor(new_anchor: Node2D):
	"""Set the anchor this enemy follows"""
	anchor = new_anchor

func set_color(color: Color):
	"""Change enemy color"""
	enemy_color = color
	modulate = color

func set_shooting_enabled(enabled: bool):
	"""Enable or disable shooting"""
	can_shoot = enabled
	if not enabled:
		$ShootTimer.stop()
	elif is_alive and enabled:
		$ShootTimer.start()

func set_diving_enabled(enabled: bool):
	"""Enable or disable diving"""
	can_dive = enabled
	if not enabled:
		$MoveTimer.stop()
		current_speed = 0
	elif is_alive and enabled:
		$MoveTimer.start()

func is_at_full_health() -> bool:
	"""Check if enemy is at full health"""
	return current_health >= max_health

# ===== TIMER SIGNALS =====
func _on_timer_timeout():
	"""Handle movement timer (alias for backward compatibility)"""
	initiate_dive()
