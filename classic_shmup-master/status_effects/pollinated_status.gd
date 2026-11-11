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
##     - Pollen Split power-up (Stats "pollen"/"extra_bounce_shots"): when
##       the bullet travels on, up to that many EXTRA shots also fly out to
##       other enemies in range (pollinated ones first, then nearest).
##   The search radius is bounce_radius() - 50% of the bubble pop radius,
##   times Stats "pollen"/"bounce_radius_mult" (Wide Bloom power-up).
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
	return Bubble.POP_EXPLOSION_RADIUS * BOUNCE_RADIUS_OF_BUBBLE_POP * float(Stats.get_stat("pollen", "bounce_radius_mult"))


static func resolve_bullet_hit(enemy: Node2D, hit_position: Vector2, damage_dealt: int, enemy_died: bool) -> Array:
	"""Called by a player bullet right after it damaged an enemy that WAS
	pollinated going into the hit. Applies the rules above and returns the
	enemies to send shots at: [] = no bounce; otherwise the first one is
	where the bullet itself goes, and any others (Pollen Split) get extra
	shots spawned by the bullet."""
	var tree := enemy.get_tree() if is_instance_valid(enemy) and enemy.is_inside_tree() else null
	if tree == null:
		return []

	var radius := bounce_radius()
	# Everything in range, pollinated enemies first, each group nearest first.
	var pollinated_in_range: Array = []
	var others_in_range: Array = []
	for other in tree.get_nodes_in_group("enemies"):
		if other == enemy or not is_instance_valid(other) or other.is_queued_for_deletion():
			continue
		if "is_alive" in other and not other.is_alive:
			continue
		var d: float = hit_position.distance_to(other.global_position)
		if d > radius:
			continue
		if other.has_method("has_status_effect") and other.has_status_effect(StatusEffects.POLLINATED):
			pollinated_in_range.append([d, other])
		else:
			others_in_range.append([d, other])
	var by_distance := func(a, b): return a[0] < b[0]
	pollinated_in_range.sort_custom(by_distance)
	others_in_range.sort_custom(by_distance)
	var candidates: Array = []
	for pair in pollinated_in_range + others_in_range:
		candidates.append(pair[1])

	var bounces := false
	if not pollinated_in_range.is_empty():
		bounces = true                                    # always chains to pollinated
	elif randf() < BOUNCE_CHANCE:
		if not candidates.is_empty():
			bounces = true
		elif not enemy_died and enemy.has_method("take_damage"):
			# Nothing to bounce to: extra damage instead. Fractions carry over
			# to later bonuses so the average is exactly 50%.
			var bonus := PlayerPowerUps.whole_damage("pollen_bonus", damage_dealt * BONUS_DAMAGE_FRACTION)
			if bonus > 0:
				enemy.take_damage(bonus, {"source": "pollen_bonus"})
		else:
			return []   # enemy already died and nothing in range - nothing to do
	else:
		return []       # failed roll - stays pollinated

	# Either effect uses up this enemy's pollination.
	if is_instance_valid(enemy) and not enemy.is_queued_for_deletion() and enemy.has_method("remove_status_effect"):
		enemy.remove_status_effect(StatusEffects.POLLINATED)
	_spawn_spark(hit_position)
	if not bounces:
		return []
	var extra: int = int(Stats.get_stat("pollen", "extra_bounce_shots"))
	return candidates.slice(0, mini(1 + maxi(extra, 0), candidates.size()))


static func _spawn_spark(pos: Vector2) -> void:
	var spark := PollenExplosionVisual.new()
	spark.max_radius = SPARK_RADIUS
	GameShell.game_root().add_child(spark)
	spark.global_position = pos
