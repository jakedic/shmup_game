# yellow_enemy_bullet.gd
extends EnemyBullet
class_name YellowEnemyBullet

func _ready():
	# Set properties for yellow enemy bullets
	speed = 150
	damage = 1
	max_distance = 800.0
	pierce_count = 0  # How many times bullet can pierce through enemies
	homing_enabled = false
	homing_strength= 1.0
	bounce_count= 0
	
	# Set visual properties
	modulate = Color.YELLOW

'''func custom_start():
	"""Yellow bullet specific initialization"""
	# Add a yellow glow effect
	var light = Light2D.new()
	light.color = Color.YELLOW
	light.energy = 0.3
	add_child(light)'''

func custom_process(delta: float):
	"""Yellow bullet specific per-frame logic"""
	# Add a slight sine wave motion
	position.x += sin(Time.get_ticks_msec() * 0.005) * 20 * delta
