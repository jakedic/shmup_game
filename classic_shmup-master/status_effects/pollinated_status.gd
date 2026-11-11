# pollinated_status.gd
## Behavior for the "pollinated" status condition (see
## status_effects/status_effect_registry.gd).
##
## Inflicted by pollen bullets / puffs / residue / Cross-Pollination etc. via
## Bullet's generic status_effect_name / status_effect_chance, or
## apply_status_effect() directly - this handler doesn't care where it came
## from.
##
## Rules (reworked 2026-11-11):
##   When a player bullet that does damage hits a POLLINATED enemy
##   (see resolve_bullet_hit(), called from bullets/bullet.gd):
##     - If another POLLINATED enemy is within bounce_radius() of it, the
##       bullet always (100%) travels on to the nearest one.
##     - Otherwise there's a BOUNCE_CHANCE (50%) roll. On success:
##         - another enemy within bounce_radius() -> the bullet travels on to
##           the nearest one;
##         - no enemy in range -> the hit enemy takes an extra
##           BONUS_DAMAGE_FRACTION (50%) of the damage it just took.
##       On a failed roll nothing happens and the enemy stays pollinated.
##     - Either effect (travel or bonus damage) removes the hit enemy's
##       pollination.
##   Because the bullet arrives at the next enemy as a normal hit, a bullet
##   that reaches another pollinated enemy keeps chaining until it hits one
##   that isn't pollinated (or the roll fails / nothing's in range). Each hop
##   removes a pollination, so a chain always ends.
##
## (The old rules - pollinated enemies exploding on death, and hits on them
## not using up a piercing shot's pierce - were removed in the rework.)
class_name PollinatedStatus
extends StatusEffectHandler

const BOUNCE_CHANCE := 0.5
const BONUS_DAMAGE_FRACTION := 0.5
# The bounce search radius is this fraction of the bubble's pop explosion
# radius (Bubble.POP_EXPLOSION_RADIUS = 80 -> 40px), so it stays in
# proportion if that radius is changed.
const BOUNCE_RADIUS_OF_BUBBLE_POP := 0.5
# Little pollen flash where a bounce / bonus happens.
const SPARK_RADIUS := 10.0

# Old default used by PollenExplosionVisual (still used for small pollen
# bursts) - unrelated to the bounce radius.
const EXPLOSION_RADIUS := 40.0


func on_apply(enemy: BaseEnemy, _data: Dictionary) -> void:
	if enemy.get_node_or_null("PollinatedVisual"):
		return  # already showing the visual, nothing more to do
	var visual := PollenVisual.new()
	visual.name = "PollinatedVisual"
	enemy.add_child(visual)


func on_remove(enemy: BaseEnemy) -> void:
	var visual := enemy.get_node_or_null("PollinatedVisual")
	if visual:
		visual.queue_free()


static func bounce_radius() -> float:
	return Bubble.POP_EXPLOSION_RADIUS * BOUNCE_RADIUS_OF_BUBBLE_POP


static func resolve_bullet_hit(enemy: Node2D, hit_position: Vector2, damage_dealt: int, enemy_died: bool) -> Node2D:
	"""Called by a player bullet right after it damaged an enemy that WAS
	pollinated going into the hit. Applies the rules above and returns the
	enemy the bullet should travel to next, or null if it doesn't bounce."""
	var tree := enemy.get_tree() if is_instance_valid(enemy) and enemy.is_inside_tree() else null
	if tree == null:
		return null

	var radius := bounce_radius()
	var nearest_pollinated: Node2D = null
	var nearest_pollinated_d := INF
	var nearest_any: Node2D = null
	var nearest_any_d := INF
	for other in tree.get_nodes_in_group("enemies"):
		if other == enemy or not is_instance_valid(other) or other.is_queued_for_deletion():
			continue
		if "is_alive" in other and not other.is_alive:
			continue
		var d: float = hit_position.distance_to(other.global_position)
		if d > radius:
			continue
		if d < nearest_any_d:
			nearest_any_d = d
			nearest_any = other
		if other.has_method("has_status_effect") and other.has_status_effect(StatusEffects.POLLINATED) \
				and d < nearest_pollinated_d:
			nearest_pollinated_d = d
			nearest_pollinated = other

	var target: Node2D = null
	if nearest_pollinated:
		target = nearest_pollinated                       # always chains to pollinated
	elif randf() < BOUNCE_CHANCE:
		if nearest_any:
			target = nearest_any
		elif not enemy_died and enemy.has_method("take_damage"):
			# Nothing to bounce to: extra damage instead. Fractions carry over
			# to later bonuses so the average is exactly 50%.
			var bonus := PlayerPowerUps.whole_damage("pollen_bonus", damage_dealt * BONUS_DAMAGE_FRACTION)
			if bonus > 0:
				enemy.take_damage(bonus, {"source": "pollen_bonus"})
		else:
			return null   # enemy already died and nothing in range - nothing to do
	else:
		return null       # failed roll - stays pollinated

	# Either effect uses up this enemy's pollination.
	if is_instance_valid(enemy) and not enemy.is_queued_for_deletion() and enemy.has_method("remove_status_effect"):
		enemy.remove_status_effect(StatusEffects.POLLINATED)
	_spawn_spark(hit_position)
	return target


static func _spawn_spark(pos: Vector2) -> void:
	var spark := PollenExplosionVisual.new()
	spark.max_radius = SPARK_RADIUS
	GameShell.game_root().add_child(spark)
	spark.global_position = pos
