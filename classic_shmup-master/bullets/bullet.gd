extends Bullet
class_name Bullet_Basic

func _ready():
	# Values here are just editor-time fallbacks (e.g. for previewing the
	# scene in isolation). Whenever this bullet is spawned by the player,
	# configure_bullet() in player.gd overwrites damage/speed/pierce/max_distance
	# from Stats.get_category("bullet") right after instantiate().
	add_to_group("player_bullet")
	speed = 250
	damage = 1
	max_distance = 125.0
	$Bullet_disipation.play("Bullet_disipation")

func start(pos: Vector2, dir: Vector2 = Vector2.UP):
	super.start(pos, dir)
