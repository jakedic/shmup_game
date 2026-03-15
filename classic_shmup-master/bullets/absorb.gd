# bullet_boomerang.gd
'''extends Area2D

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

func _ready():
	# Scale the sprite to be 8 times longer in the Y direction
	$Sprite2D.scale.y = 8
	
	# Make collision shape longer to match the scaled sprite
	$CollisionShape2D.scale.y = 8

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
			else:
				target_player.absorb_fail()
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
			hit_enemy_type = 1'''

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

# Add these variables for scaling effect
var scale_progress = 0.0  # 0 to 1 for growing, then 1 to 0 for shrinking
var scaling_speed = 1.5  # How fast it scales
var max_scale_y = 8.0
var min_scale_y = 1.0
var growing = true  # Whether we're in the growing or shrinking phase
var absorption_active = true  # Whether absorption is still happening

# Store the original texture size for positioning calculations
var original_sprite_height = 0.0

func _ready():
	# Get the sprite's texture height
	if $Sprite2D.texture:
		original_sprite_height = $Sprite2D.texture.get_size().y
	
	# Start with minimum scale
	$Sprite2D.scale.y = min_scale_y
	
	# Make collision shape match initial sprite scale
	$CollisionShape2D.scale.y = min_scale_y
	
	# Set the initial position so bottom is fixed
	update_sprite_position(min_scale_y)

func start(pos, player):
	position = pos
	target_player = player
	start_position = pos  # Record starting position

func _physics_process(delta):
	# Only continue scaling if absorption is still active
	if absorption_active:
		# Handle scaling effect
		if growing:
			# Grow from min to max
			scale_progress += scaling_speed * delta
			if scale_progress >= 1.0:
				scale_progress = 1.0
				growing = false  # Switch to shrinking phase
		else:
			# Shrink from max to min
			scale_progress -= scaling_speed * delta
			if scale_progress <= 0.0:
				scale_progress = 0.0
				absorption_active = false  # Stop absorption when small again
				if has_hit_enemy and target_player and target_player.has_method("absorb_complete"):
					target_player.absorb_complete(hit_enemy_type)  # Callback to player
				else:
					target_player.absorb_fail()
				queue_free()
		
		# Apply scale based on progress (ease in-out for smoother effect)
		var t = scale_progress
		# Use ease function for smoother transition
		t = smoothstep(0.0, 1.0, t)  # This creates an S-shaped curve
		
		var current_scale_y = lerp(min_scale_y, max_scale_y, t)
		$Sprite2D.scale.y = current_scale_y
		$CollisionShape2D.scale.y = current_scale_y * 0.8
		
		# Update position to keep bottom fixed
		update_sprite_position(current_scale_y)
	
	# Remove if goes off screen (optional - adjust based on your needs)
	if position.y < -20 or position.y > get_viewport().get_visible_rect().size.y + 20:
		queue_free()
	
	# Auto-remove if absorption is finished
	if not absorption_active:
		queue_free()

# Helper function to update sprite position keeping bottom fixed
func update_sprite_position(current_scale):
	# Calculate the height difference from scaling
	var original_height = original_sprite_height
	var scaled_height = original_height * current_scale
	var height_difference = scaled_height - original_height
	
	# Move the sprite up by half the height difference to keep bottom fixed
	# This works because sprite scaling happens from the center by default
	$Sprite2D.position.y = -height_difference / 2
	
	# Also update collision shape position to match
	$CollisionShape2D.position.y = -height_difference / 2

# Helper function for smooth interpolation
func smoothstep(edge0, edge1, x):
	# Scale, bias and saturate x to 0..1 range
	x = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0)
	# Evaluate polynomial
	return x * x * (3 - 2 * x)

func _on_area_entered(area):
	if area.is_in_group("enemies") and not has_hit_enemy:
		area.explode()  # Or whatever enemy destruction method you have
		has_hit_enemy = true
		returning = true
		
		if area.has_method("get_enemy_type"):  # Check if enemy has this method
			hit_enemy_type = area.get_enemy_type()
		else:
			hit_enemy_type = 1
