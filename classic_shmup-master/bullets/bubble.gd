extends Bullet
class_name Bubble

@export var bubble_scene: PackedScene  # The bubble projectile scene
@export var bubble_lifetime: float = 30.0  # How long bubble stays on screen
@export var bubble_travel_distance: float = 20.0  # Distance bubble travels before stopping
# Bubble-specific properties
@export var travel_distance: float = 50.0
@export var hover_amplitude: float = 10.0  # How much it bobs up/down
@export var hover_frequency: float = 1.0   # How fast it bobs
@export var rotation_speed: float = 45.0   # Degrees per second rotation

var absorbed_enemy_type: String = "" 

var hit_points: int = 3  # Number of hits before bubble disappears
var current_hits: int = 0

#var distance_traveled: float = 0.0
var has_stopped: bool = false
var start_position: Vector2
var time_elapsed: float = 0.0
var original_speed: float

func _ready():
	# Connect to area entered signal
	area_entered.connect(_on_area_entered)
	
func set_enemy_type(enemy_type: String):
	absorbed_enemy_type = enemy_type
	print("Bubble contains: ", enemy_type)

func custom_start():
	"""Initialize bubble behavior"""
	start_position = position
	original_speed = speed
	has_stopped = false
	
	# Disable collision with player initially to prevent instant collision
	set_collision_mask_value(1, false)  # Disable player collision mask
	
	# Optional: Add a timer to enable collision after a short delay
	await get_tree().create_timer(0.1).timeout
	set_collision_mask_value(1, true)  # Re-enable player collision

func custom_process(delta: float):
	"""Handle bubble movement - travel then stop"""
	if not has_stopped:
		# Still traveling forward
		var movement = direction * speed * delta
		position += movement
		distance_traveled += movement.length()
		
		# Check if reached travel distance
		if distance_traveled >= travel_distance:
			has_stopped = true
			speed = 0  # Stop moving
			
			# Optional: Add a visual effect when bubble stops
			stop_effect()
	else:
		# Bubble has stopped - hover in place
		time_elapsed += delta
		
		# Add hovering motion (gentle bobbing)
		var hover_offset = sin(time_elapsed * hover_frequency * PI * 2) * hover_amplitude
		position.y = start_position.y + (travel_distance * direction.y) + hover_offset
		
		# Add rotation effect
		rotation_degrees += rotation_speed * delta
		
		# Check if bubble lifetime is exceeded
		if time_elapsed >= bubble_lifetime:
			pop_bubble()  # Bubble pops/disappears
			queue_free()

func stop_effect():
	"""Visual effect when bubble stops moving"""
	# Add a ripple or sparkle effect
	modulate = Color(0.8, 0.9, 1.0, 1.0)  # Slight color change
	
	# Optional: Create a small particle effect
	if has_node("StopEffect"):
		$StopEffect.emitting = true

func pop_bubble():
	"""Create a pop effect when bubble expires"""
	# Optional: Add pop particles
	if has_node("PopParticles"):
		$PopParticles.emitting = true
	
	# Optional: Add pop sound
	# if has_node("PopSound"):
	#     $PopSound.play()
	
	# Optional: Add a small area damage effect when bubble pops
	create_pop_damage()

func create_pop_damage():
	"""Create explosion damage using a simple timer approach"""
	print("Creating explosion at: ", global_position)
	
	# Get all enemies in range manually
	var explosion_radius = 80
	var enemies_in_range = []
	
	# Search for enemies in the scene
	var all_nodes = get_tree().get_nodes_in_group("enemies")
	
	for enemy in all_nodes:
		if is_instance_valid(enemy):
			var distance = global_position.distance_to(enemy.global_position)
			if distance <= explosion_radius:
				enemies_in_range.append(enemy)
				print("Found enemy in range: ", enemy.name, " at distance: ", distance)
	
	# Damage all enemies in range
	var damage_amount = damage * 3
	for enemy in enemies_in_range:
		if enemy.has_method("take_damage"):
			print("Damaging enemy: ", enemy.name)
			enemy.take_damage(damage_amount)
		elif enemy.has_method("explode"):
			print("Exploding enemy: ", enemy.name)
			enemy.explode()
	
	# Create a visual explosion effect (optional)
	create_visual_explosion()
	
	print("Damaged ", enemies_in_range.size(), " enemies")

func create_visual_explosion():
	"""Create a blue circular explosion effect using a Polygon2D"""
	var explosion = Polygon2D.new()
	
	# Create a circle with 32 points
	var points = []
	var radius = 80
	var segments = 32
	for i in range(segments):
		var angle = (i / float(segments)) * 2 * PI
		var x = cos(angle) * radius
		var y = sin(angle) * radius
		points.append(Vector2(x, y))
	
	explosion.polygon = points
	explosion.color = Color(0.3, 0.6, 1.0, 0.7)  # Blue with transparency
	explosion.position = global_position
	
	# Add to scene
	get_parent().add_child(explosion)
	
	# Animate the explosion (expand and fade)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(explosion, "scale", Vector2(1.5, 1.5), 0.3)
	tween.tween_property(explosion, "modulate:a", 0.0, 0.3)
	
	# Use a timer to clean up instead of await
	var cleanup_timer = Timer.new()
	cleanup_timer.wait_time = 0.35  # Slightly longer than animation
	cleanup_timer.one_shot = true
	cleanup_timer.timeout.connect(func(): 
		if is_instance_valid(explosion):
			explosion.queue_free()
		cleanup_timer.queue_free()
	)
	get_tree().root.add_child(cleanup_timer)
	cleanup_timer.start()

'''func _on_area_entered(area: Area2D):
	"""Handle collisions - bubble only damages enemies when stationary"""
	if area.is_in_group("enemies") and has_stopped:
		# Bubble hits enemy while stationary - damage and pop
		if area.has_method("take_damage"):
			area.take_damage(damage)
		pop_bubble()
		queue_free()
	elif area.is_in_group("enemies") and not has_stopped:
		# Bubble hits enemy while moving - just damage and continue
		if area.has_method("take_damage"):
			area.take_damage(damage)
		
		# Optional: Reduce pierce count if using piercing
		if pierce_count > 0:
			current_pierce += 1
			if current_pierce >= pierce_count:
				queue_free()'''
				
func _on_area_entered(area: Area2D):
	# Check if player touched the bubble
	if area.is_in_group("player") or area.name == "Player":
		print("Player touched bubble! Enemy type: ", absorbed_enemy_type)
		
		# Apply transformation to player if we have an enemy type
		if absorbed_enemy_type != "":
			apply_transformation_to_player(area)
		
		# Bubble gets absorbed/disappears
		queue_free()
		return
	
	# Check if what hit us is an enemy bullet
	if area.is_in_group("enemy_bullet"):
		current_hits += 1
		print("Bubble hit by enemy bullet! Hits: ", current_hits, "/", hit_points)
		
		# Visual feedback (optional)
		flash_white()
		
		# Remove the enemy bullet that hit us
		area.queue_free()
		
		# Check if bubble should disappear
		if current_hits >= hit_points:
			print("Bubble destroyed by bullets")
			queue_free()
		return
	
	# Check if hit by enemy (optional - makes bubble pop on enemy contact)
	if area.is_in_group("enemies") or area.is_in_group("enemy"):
		print("Bubble hit enemy! Popping...")
		current_hits += 3
		flash_white()
		
		if current_hits >= hit_points:
			queue_free()
	# NEW: Check if hit by player's bullet
	if area.is_in_group("player_bullet") or area.is_in_group("player_projectile"):
		print("Bubble hit by player bullet! Popping with explosion!")
		
		# Remove the player bullet
		area.queue_free()
		
		# Create explosion damage
		pop_bubble()
		
		# Remove the bubble
		queue_free()
		return
func apply_transformation_to_player(player: Area2D):
	print("Applying transformation: ", absorbed_enemy_type)
	
	# Call the player's absorb_complete function to trigger transformation
	if player.has_method("absorb_complete"):
		# This will trigger the player's transformation
		player.absorb_complete(absorbed_enemy_type)
	elif player.has_method("transform_" + absorbed_enemy_type.to_lower()):
		# Directly call the transformation function
		var transform_func = "transform_" + absorbed_enemy_type.to_lower()
		player.call(transform_func)
	else:
		print("Player cannot absorb enemy type: ", absorbed_enemy_type)
	
	# Optional: Add visual effect
	create_absorption_effect()

func create_absorption_effect():
	"""Create a visual effect when bubble is absorbed"""
	# Add particles or flash effect
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 0, 1), 0.1)
	tween.tween_property(self, "modulate", Color(1, 1, 0, 0), 0.1)

func flash_white():
	# Quick flash effect to show it was hit
	var original_color = modulate
	modulate = Color.WHITE
	await get_tree().create_timer(0.1).timeout
	modulate = original_color

func explode_or_disappear():
	queue_free()
	
