extends Area2D

signal shield_changed
signal died

# Player movement and combat properties
@export var speed = 150
@export var cooldown = 0.25
@export var max_shield = 10

# Scenes for different bullet types
@export var bullet_scene : PackedScene
@export var bullet_yellow_scene : PackedScene
@export var absorb_scene : PackedScene

# Sprite textures for normal and absorbing states
@export var default_sprite_texture: Texture2D
@export var yellow_sprite_texture: Texture2D

# State variables
var shield = max_shield:
	set = set_shield  # Use setter function when shield changes
var can_shoot = true
var can_absorb = true
var is_absorbing = false

@onready var screensize = get_viewport_rect().size

func _ready():
	start()

func start():
	"""Initialize player state and position"""
	show()
	position = Vector2(screensize.x / 2, screensize.y - 64)
	shield = max_shield
	$GunCooldown.wait_time = cooldown

func _process(delta):
	handle_absorb_input()
	handle_movement(delta)
	handle_shoot_input()

func handle_absorb_input():
	"""Process absorb/revert key inputs"""
	if Input.is_action_pressed("absorb"):
		#is_absorbing = true
		absorb()
	if Input.is_action_pressed("revert"):
		is_absorbing = false
		update_sprite()

func handle_movement(delta):
	"""Process player movement and update animations"""
	var input = Input.get_vector("left", "right", "up", "down")
	
	# Update ship animation based on horizontal movement
	if input.x > 0:
		$Ship.frame = 2
		$Ship/Boosters.animation = "right"
	elif input.x < 0:
		$Ship.frame = 0
		$Ship/Boosters.animation = "left"
	else:
		$Ship.frame = 1
		$Ship/Boosters.animation = "forward"
	
	# Apply movement with boundary clamping
	position += input * speed * delta
	position = position.clamp(Vector2(8, 8), screensize - Vector2(8, 8))

func handle_shoot_input():
	"""Check for shoot input"""
	if Input.is_action_pressed("shoot"):
		shoot()

func shoot():
	"""Fire a bullet based on current absorption state"""
	if not can_shoot:
		return
	
	can_shoot = false
	$GunCooldown.start()
	
	# Choose bullet type based on absorption state
	var bullet = bullet_yellow_scene.instantiate() if is_absorbing else bullet_scene.instantiate()
	get_tree().root.add_child(bullet)
	bullet.start(position + Vector2(0, -8))
	
	# Add recoil animation
	animate_recoil()

func absorb():
	"""Fire an absorb bullet/boomerang"""
	if not can_absorb:
		return
	
	can_absorb = false
	$GunCooldown.start()
	$AbsorbCooldown.start()
	
	# Create and launch boomerang
	var boomerang = absorb_scene.instantiate()
	get_tree().root.add_child(boomerang)
	boomerang.start(position + Vector2(0, -8), self)
	
	# Add recoil animation
	animate_recoil()

func animate_recoil():
	"""Play the ship recoil animation when shooting"""
	var tween = create_tween().set_parallel(false)
	tween.tween_property($Ship, "position:y", 1, 0.1)
	tween.tween_property($Ship, "position:y", 0, 0.05)

func set_shield(value):
	"""Setter function for shield that clamps value and emits signals"""
	shield = min(max_shield, value)
	shield_changed.emit(max_shield, shield)
	
	if shield <= 0:
		hide()
		died.emit()

func update_sprite():
	"""Update ship sprite based on absorption state"""
	if is_absorbing:
		if $Ship is Sprite2D:
			$Ship.texture = yellow_sprite_texture
			$Ship.hframes = 4
		else:
			$Ship.hframes = 4
	else:
		if $Ship is Sprite2D:
			$Ship.hframes = 3
			$Ship.texture = default_sprite_texture

func absorb_complete():
	"""Called when boomerang returns successfully"""
	is_absorbing = true
	update_sprite()

func _on_gun_cooldown_timeout():
	can_shoot = true

func _on_absorb_cooldown_timeout():
	can_absorb = true

func _on_area_entered(area):
	"""Handle collision with enemies"""
	if area.is_in_group("enemies"):
		area.explode()
		shield -= max_shield / 2.0
