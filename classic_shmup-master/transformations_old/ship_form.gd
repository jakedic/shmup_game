extends Resource
class_name ShipForm

# Define properties that can be overridden
@export var form_name: String = "Default Form"
@export var form_id: String = "default"

# Movement
@export var speed: float = 150
@export var acceleration: float = 10.0
@export var deceleration: float = 10.0

# Health/shield
@export var max_shield: int = 10
@export var shield_regen_rate: float = 0.0
@export var shield_regen_delay: float = 3.0

# Shooting
@export var shoot_cooldown: float = 0.25
@export var bullet_scene: PackedScene
@export var can_multi_shoot: bool = false
@export var shot_count: int = 1
@export var shot_spread: float = 10.0

# Visual
@export var default_sprite_texture: Texture2D
@export var yellow_sprite_texture: Texture2D
@export var player_color: Color = Color.WHITE

# Additional visual properties
@export var has_recoil_animation: bool = true
@export var recoil_distance: float = 1.0
@export var recoil_duration: float = 0.1

# Sound (optional)
# @export var shoot_sound: AudioStream
# @export var transform_sound: AudioStream

# Special properties
@export var is_form_locked: bool = false
@export var unlock_requirement: String = ""

# Get form data as dictionary
func to_dictionary() -> Dictionary:
	var dict = {}
	
	# Only include properties that are different from default
	if form_name != "Default Form":
		dict["form_name"] = form_name
	
	if speed != 150:
		dict["speed"] = speed
	
	if acceleration != 10.0:
		dict["acceleration"] = acceleration
	
	if deceleration != 10.0:
		dict["deceleration"] = deceleration
	
	if max_shield != 10:
		dict["max_shield"] = max_shield
	
	if shield_regen_rate != 0.0:
		dict["shield_regen_rate"] = shield_regen_rate
	
	if shield_regen_delay != 3.0:
		dict["shield_regen_delay"] = shield_regen_delay
	
	if shoot_cooldown != 0.25:
		dict["shoot_cooldown"] = shoot_cooldown
	
	if bullet_scene:
		dict["bullet_scene"] = bullet_scene
	
	if can_multi_shoot != false:
		dict["can_multi_shoot"] = can_multi_shoot
	
	if shot_count != 1:
		dict["shot_count"] = shot_count
	
	if shot_spread != 10.0:
		dict["shot_spread"] = shot_spread
	
	if default_sprite_texture:
		dict["default_sprite_texture"] = default_sprite_texture
	
	if yellow_sprite_texture:
		dict["yellow_sprite_texture"] = yellow_sprite_texture
	
	if player_color != Color.WHITE:
		dict["player_color"] = player_color
	
	if has_recoil_animation != true:
		dict["has_recoil_animation"] = has_recoil_animation
	
	if recoil_distance != 1.0:
		dict["recoil_distance"] = recoil_distance
	
	if recoil_duration != 0.1:
		dict["recoil_duration"] = recoil_duration
	
	return dict

# Get only modified properties
func get_modified_properties() -> Dictionary:
	return to_dictionary()
