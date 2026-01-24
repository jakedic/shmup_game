extends Bullet
class_name Bullet_Basic

func _ready():
	# Initialize with yellow bullet properties
	speed = 250
	damage = 1
	max_distance = 125.0  # Very short distance for quick disappearance
	$Bullet_disipation.play("Bullet_disipation")

func start(pos: Vector2, dir: Vector2 = Vector2.UP):
	super.start(pos, dir)
