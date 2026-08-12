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

# Status-effect infliction (generic - see status_effects/status_effect_registry.gd).
# Any bullet can inflict any registered status just by setting these two;
# nothing else in this file needs to know what the status actually does.
# e.g. bullets/bullet_pollen.gd sets status_effect_name = StatusEffects.POLLINATED,
# status_effect_chance = 0.2.
@export var status_effect_name: String = ""  # empty = doesn't inflict anything
@export var status_effect_chance: float = 0.0  # 0.0-1.0 chance per hit
# If true, this bullet won't try to inflict its status effect on the very
# first enemy it hits - only on enemies hit afterward via piercing (see
# yellow_piercing_pollen power-up in player/player_powerups.gd). No effect
# on a non-piercing bullet, since it never gets a "second hit" anyway.
@export var status_effect_skip_first_hit: bool = false

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
# How many enemies this bullet has hit so far (regardless of whether they
# died), used by status_effect_skip_first_hit to tell "the first enemy shot"
# apart from anything hit afterward while piercing.
var enemies_hit_count: int = 0

var slow_down: int = 0

func _ready():
	"""Called when bullet is added to scene"""
	# Apply visual properties
	apply_visuals()
	
	# Needed so things like Bubble._on_area_entered() (which only reacts to
	# area.is_in_group("player_bullet")) can recognize the default player
	# shot. bullet_yellow.gd and bullet_pollen.gd already add themselves to
	# this group in their own _ready(); the base/default bullet was missing
	# it, which is why bubbles never exploded from a normal shot.
	add_to_group("player_bullet")
	
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
	if distance_traveled >= max_distance*0.95 and slow_down==0:
		speed=speed/2
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
	elif area.is_in_group("enemy_bullet"):
		handle_enemy_bullet_collision(area)
	
	# Call custom collision handler
	custom_area_collision(area)

func handle_enemy_collision(area: Area2D):
	"""Handle collision with enemy area"""
	if area.is_in_group("enemies"):
		# Prevent multiple collisions in same frame
		if is_queued_for_deletion():
			return
		
		# Check BEFORE dealing damage - this is about whatever status the
		# enemy already had going into this hit (e.g. already pollinated),
		# not anything this same hit might apply below.
		var blocks_pierce := _enemy_blocks_pierce(area)
		
		# Count this enemy toward "enemies hit" BEFORE applying/rolling the
		# status effect below, so status_effect_skip_first_hit can tell this
		# was (or wasn't) the first enemy this bullet has hit.
		enemies_hit_count += 1
		
		# Damage the enemy
		var enemy_died = false
		if area.has_method("take_damage"):
			enemy_died = await area.take_damage(damage)
		elif area.has_method("explode"):
			area.explode()
			enemy_died = true
		
		# Only try to inflict a new status on an enemy that's still around
		# to carry it.
		if not enemy_died:
			_maybe_inflict_status_effect(area)
		
		# Destroy bullet if no piercing at all
		if pierce_count == 0:
			queue_free()
			return
		
		# A status that blocks pierce consumption (e.g. pollinated) means
		# this hit is free: damage already applied above, but the bullet
		# keeps its full remaining pierce budget and keeps going, whether
		# or not the enemy died from it.
		if blocks_pierce:
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

func handle_enemy_bullet_collision(area: Area2D):
	"""Handle collision with an enemy bullet - the two cancel each other out.
	The enemy bullet destroys itself independently (see its own
	handle_player_bullet_collision), so this only decides our own fate: with
	no piercing left we're destroyed too, same as a normal 1-for-1 trade.
	With piercing, this consumes a charge from the same pierce budget used
	against enemies and we keep going."""
	if is_queued_for_deletion():
		return

	if pierce_count == 0:
		queue_free()
		return

	current_pierce += 1
	if current_pierce >= pierce_count:
		queue_free()

func _on_body_entered(body: Node2D):
	"""Handle collisions with physics bodies"""
	if body.is_in_group("enemies"):
		handle_enemy_body_collision(body)
	
	# Call custom body collision handler
	custom_body_collision(body)

func handle_enemy_body_collision(body: Node2D):
	"""Handle collision with enemy body"""
	var blocks_pierce := _enemy_blocks_pierce(body)
	
	enemies_hit_count += 1
	
	var enemy_died = false
	if body.has_method("take_damage"):
		enemy_died = body.take_damage(damage)
	
	if not enemy_died:
		_maybe_inflict_status_effect(body)
	
	if blocks_pierce and pierce_count > 0:
		return
	
	if pierce_count == 0 or current_pierce >= pierce_count:
		if not enemy_died and split_on_death:
			split_bullet()
		queue_free()
	else:
		current_pierce += 1

func _maybe_inflict_status_effect(target) -> void:
	"""Roll status_effect_chance and, on success, apply status_effect_name to
	`target` (an enemy Area2D/body). No-op if this bullet doesn't inflict a
	status at all, or if the target doesn't support the status system."""
	if status_effect_name == "" or status_effect_chance <= 0.0:
		return
	# yellow_piercing_pollen power-up: skip the first enemy this bullet
	# ever hits - only enemies hit afterward (i.e. via piercing) qualify.
	if status_effect_skip_first_hit and enemies_hit_count <= 1:
		return
	if not target.has_method("apply_status_effect"):
		return
	if randf() < status_effect_chance:
		target.apply_status_effect(status_effect_name, {})

func _enemy_blocks_pierce(target) -> bool:
	"""Whether `target`'s current status (if any) means this hit shouldn't
	consume this bullet's pierce budget. See BaseEnemy.blocks_pierce_consumption()."""
	return target.has_method("blocks_pierce_consumption") and target.blocks_pierce_consumption()

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
