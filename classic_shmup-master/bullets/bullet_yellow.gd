extends Bullet
class_name Yellow_Bullet

func _ready():
	# Initialize with yellow bullet properties
	speed = 250
	damage = 3
	max_distance = 500.0  # Very short distance for quick disappearance

func start(pos: Vector2, dir: Vector2 = Vector2.UP):
	super.start(pos, dir)
