# yellow_bullet.gd
extends Bullet
class_name Bullet_Basic

func _ready():
	# Initialize with yellow bullet properties
	speed = 250
	damage = 1
	#modulate = Color.YELLOW
	
	# Set up the bullet timer for auto-destruction
	$BulletTimer.wait_time = 0.7  # 5 second lifespan
	$BulletTimer.start()

# Override start method if you need different behavior
func start(pos: Vector2, dir: Vector2 = Vector2.UP):
	# Call parent start method
	super.start(pos, dir)
	# Yellow bullet specific initialization can go here

# The base Bullet class already handles:
# - _process (movement)
# - _on_visible_on_screen_notifier_2d_screen_exited
# - _on_area_entered (with damage and explode)
# - _on_bullettimer_timeout
