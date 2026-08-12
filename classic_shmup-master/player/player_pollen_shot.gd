extends RefCounted
class_name PlayerPollenShot

## "Pollen Shot" yellow power-up (see player/player_powerups.gd -
## yellow_pollen_shot): once granted, holding "shoot" fires a pair of weak,
## slow, wiggling pollen-ball bullets from the left and right of the ship,
## alongside whatever the normal bullet is doing. Completely independent of
## PlayerShooting - separate scene (bullet_pollen), separate stats
## (Stats.get_category("pollen")), and its own cooldown, so it never
## competes with or replaces the primary fire.
##
## Called from player.gd every frame as
## PlayerPollenShot.handle_input(self, delta).

# How far left/right of center and how far forward of center (relative to
# the ship's origin) the two pollen balls spawn from.
const SIDE_OFFSET := 6.0
const FORWARD_OFFSET := -4.0

static func handle_input(player: Player, delta: float) -> void:
	if player.pollen_cooldown_remaining > 0.0:
		player.pollen_cooldown_remaining -= delta

	if not player.has_pollen_shot or not player.is_alive:
		return

	if Input.is_action_pressed("shoot") and player.pollen_cooldown_remaining <= 0.0:
		_fire(player)

static func _fire(player: Player) -> void:
	var p: Dictionary = Stats.get_category("pollen")
	if p.is_empty():
		return

	if not player.bullet_pollen_scene:
		return

	player.pollen_cooldown_remaining = p.get("cooldown", 0.35)

	var spawn_center = player.position + Vector2(0, FORWARD_OFFSET)
	_spawn_one(player, spawn_center + Vector2(-SIDE_OFFSET, 0), p)
	_spawn_one(player, spawn_center + Vector2(SIDE_OFFSET, 0), p)

static func _spawn_one(player: Player, spawn_pos: Vector2, p: Dictionary) -> void:
	var bullet: Node2D = player.bullet_pollen_scene.instantiate()
	if not bullet:
		return

	# Add to the tree first so _ready() runs, then apply the live
	# Stats-driven values - same reason as PlayerShooting.launch_bullet():
	# the bullet's own _ready() hardcodes fallback stats that would
	# otherwise clobber whatever we set beforehand.
	player.get_tree().root.add_child(bullet)

	if bullet.has_method("set_damage"):
		bullet.set_damage(p.get("damage", 1))
	if bullet.has_method("set_speed"):
		bullet.set_speed(p.get("speed", 90.0))
	if "max_distance" in bullet:
		bullet.max_distance = p.get("max_distance", 220.0)
	if "wiggle_amplitude" in bullet:
		bullet.wiggle_amplitude = p.get("wiggle_amplitude", 10.0)
	if "wiggle_frequency" in bullet:
		bullet.wiggle_frequency = p.get("wiggle_frequency", 6.0)
	if "status_effect_chance" in bullet:
		bullet.status_effect_chance = p.get("status_effect_chance", 0.2)

	if bullet.has_method("start"):
		bullet.start(spawn_pos, Vector2.UP)

	player.player_shot.emit(bullet)
