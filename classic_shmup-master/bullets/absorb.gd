# bullet_boomerang.gd
extends Area2D

var speed = 300
var direction = Vector2.UP
var returning = false
var target_player = null
var has_hit_enemy = false

# Add these variables for distance tracking
var max_distance = 80  # Adjust this value as needed
var start_position = Vector2.ZERO
var distance_traveled = 0.0

var hit_enemy_type = 0

func start(pos, player):
	position = pos
	target_player = player
	start_position = pos  # Record starting position

func _physics_process(delta):
	# Calculate how far we've traveled from starting point
	if not returning:
		distance_traveled = position.distance_to(start_position)
		
		# Auto-return if we've traveled far enough
		if distance_traveled >= max_distance:
			returning = true
	
	# Movement logic
	if returning and target_player:
		# Move toward player
		var to_player = target_player.global_position - global_position
		direction = to_player.normalized()
		
		# Check if reached player
		if to_player.length() < 10:
			if  has_hit_enemy and target_player and target_player.has_method("absorb_complete"):
				target_player.absorb_complete(hit_enemy_type)  # Callback to player
			queue_free()
	else:
		# Move forward
		direction = Vector2.UP
	
	# Apply movement
	position += direction * speed * delta
	
	# Remove if goes off screen (only when not returning)
	if not returning and position.y < -20:
		queue_free()

func _on_area_entered(area):
	if area.is_in_group("enemies") and not has_hit_enemy:
		area.explode()  # Or whatever enemy destruction method you have
		has_hit_enemy = true
		returning = true
		
		if area.has_method("get_enemy_type"):  # Check if enemy has this method
			hit_enemy_type = area.get_enemy_type()
		else:
			hit_enemy_type = 1 
