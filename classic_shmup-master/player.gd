extends Area2D

signal shield_changed
signal died

@export var speed = 150
@export var cooldown = 0.25
@export var bullet_scene : PackedScene
@export var bullet_yellow_scene : PackedScene
@export var absorb_scene : PackedScene 
@export var max_shield = 10
var shield = max_shield:
	set = set_shield
	
var can_shoot = true
var can_absorb = true 

# Add these variables
var is_absorbing = false
@export var default_sprite_texture: Texture2D  # Set this in Inspector
@export var yellow_sprite_texture: Texture2D  # Set this in Inspector

@onready var screensize = get_viewport_rect().size

func _ready():
	start()

func start():
	show()
	position = Vector2(screensize.x / 2, screensize.y - 64)
	shield = max_shield
	$GunCooldown.wait_time = cooldown
	#$AbsorbCooldown.wait_time = cooldown
	
func _process(delta):
	if Input.is_action_pressed("absorb"):  # Make sure you have "absorb" action set to "k" key in Input Map
		is_absorbing = true
		#can_absorb=false
		#update_sprite()
		absorb()
	if Input.is_action_pressed("revert"):
		is_absorbing = false
		update_sprite()
	
	var input = Input.get_vector("left", "right", "up", "down")
	if input.x > 0:
		$Ship.frame = 2
		$Ship/Boosters.animation = "right"
	elif input.x < 0:
		$Ship.frame = 0
		$Ship/Boosters.animation = "left"
	else:
		$Ship.frame = 1
		$Ship/Boosters.animation = "forward"
	position += input * speed * delta
	position = position.clamp(Vector2(8, 8), screensize-Vector2(8, 8))

	if Input.is_action_pressed("shoot"):
		shoot()

func shoot():
	if not can_shoot:
		return
	can_shoot = false
	$GunCooldown.start()
	
	var current_bullet_scene
	if is_absorbing:
		current_bullet_scene = bullet_yellow_scene
	else:
		current_bullet_scene = bullet_scene
	
	
	var b = current_bullet_scene.instantiate()
	get_tree().root.add_child(b)
	b.start(position + Vector2(0, -8))
	var tween = create_tween().set_parallel(false)
	tween.tween_property($Ship, "position:y", 1, 0.1)
	tween.tween_property($Ship, "position:y", 0, 0.05)

func set_shield(value):
	shield = min(max_shield, value)
	shield_changed.emit(max_shield, shield)
	if shield <= 0:
		hide()
		died.emit()
		
func _on_gun_cooldown_timeout():
	can_shoot = true
	
func _on_absorb_cooldown_timeout():
	can_absorb = true


func _on_area_entered(area):
	if area.is_in_group("enemies"):
		area.explode()
		shield -= max_shield / 2.0
		
func update_sprite():
	if is_absorbing:
		# If using Sprite2D with texture
		if $Ship is Sprite2D:
			$Ship.texture = yellow_sprite_texture
			$Ship.hframes = 4
		# If using AnimatedSprite2D
		else:
			$Ship.hframes = 4  # Assuming frame 3 is your absorption sprite
	else:
		# Return to default
		if $Ship is Sprite2D:
			$Ship.hframes = 3
			$Ship.texture = default_sprite_texture
		else:
			# Frame will be set in _process based on movement
			pass
			
func absorb():
	if not can_absorb:
		return  # Don't shoot multiple boomerangs
	
	can_absorb = false
	$GunCooldown.start()
	$AbsorbCooldown.start()
	
	# Create boomerang bullet
	var b = absorb_scene.instantiate()
	get_tree().root.add_child(b)
	b.start(position + Vector2(0, -8), self)  # Pass self as reference
	
	
	# Recoil animation
	var tween = create_tween().set_parallel(false)
	tween.tween_property($Ship, "position:y", 1, 0.1)
	tween.tween_property($Ship, "position:y", 0, 0.05)
	
func absorb_complete():
	is_absorbing = true
	#can_absorb=true
	#is_absorbed = true  # Now permanently in yellow/absorbed state
	#current_boomerang = null
	update_sprite()
