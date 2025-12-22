# bullet_boomerang.gd
extends Area2D

var speed = 300
var direction = Vector2.UP
var returning = false
var target_player = null
var has_hit_enemy = false

func start(pos, player):
	position = pos
	target_player = player

func _physics_process(delta):
	if returning and target_player:
		# Move toward player
		var to_player = target_player.global_position - global_position
		direction = to_player.normalized()
		
		# Check if reached player
		if to_player.length() < 10:
			target_player.absorb_complete()  # Callback to player
			queue_free()
	else:
		# Move forward
		direction = Vector2.UP
	
	position += direction * speed * delta
	
	# Remove if goes off screen (only when not returning)
	if not returning and position.y < -20:
		queue_free()

func _on_area_entered(area):
	if area.is_in_group("enemies") and not has_hit_enemy:
		area.explode()  # Or whatever enemy destruction method you have
		has_hit_enemy = true
		returning = true
