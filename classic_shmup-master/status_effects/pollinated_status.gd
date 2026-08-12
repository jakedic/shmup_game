# pollinated_status.gd
## Behavior for the "pollinated" status condition (see
## status_effects/status_effect_registry.gd).
##
## Currently only inflicted by the pollen-puff secondary shot
## (bullets/bullet_pollen.gd, via Bullet's generic status_effect_name /
## status_effect_chance exports - see bullets/bullet_base.gd), but this
## handler doesn't know or care where the status came from. Any future
## bullet/attack can inflict "pollinated" just by setting those same two
## exports, and any future status condition just needs its own
## StatusEffectHandler subclass - nothing here is pollen-shot-specific.
##
## Rules implemented here:
##   - Applying: attaches a small visual (pollen stuck to the enemy).
##   - On death: triggers a small explosion at the enemy's position.
##       - Non-pollinated enemies caught in the explosion become pollinated.
##       - Pollinated enemies caught in the explosion take a large amount of
##         damage - which may kill them and chain into further explosions.
##         Each explosion in a chain does less damage than the last, so the
##         chain dissipates instead of exploding the whole screen at full
##         strength.
##   - Piercing shots that hit a pollinated enemy don't consume pierce.
class_name PollinatedStatus
extends StatusEffectHandler

# Fallback/default only - the actual radius used at runtime comes from
# Stats.get_stat("pollen", "chain_explosion_radius") (see stats.gd), which
# starts at this same value and can be increased by the
# yellow_pollen_blast_radius power-up. Kept as a const so PollenExplosionVisual
# has a sane default even if Stats isn't available for some reason.
const EXPLOSION_RADIUS := 40.0
const BASE_EXPLOSION_DAMAGE := 8
const MIN_EXPLOSION_DAMAGE := 1
# How much each subsequent explosion in the same cascade dissipates by.
# e.g. 0.55 means the 2nd explosion in a chain does ~55% of the 1st's
# damage, the 3rd does ~55% of the 2nd's, and so on.
const CHAIN_DAMAGE_DECAY := 0.55


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


func on_owner_died(enemy: BaseEnemy, context: Dictionary) -> void:
	# Continue an existing cascade's chain state if this death was itself
	# caused by a chain explosion, otherwise start a fresh one.
	var chain_state: Dictionary = context.get("pollen_chain", {})
	if chain_state.is_empty():
		chain_state = {"count": 0}

	var damage := _damage_for_chain(chain_state.count)
	chain_state.count += 1  # this explosion now counts toward the chain

	var explosion_radius := _current_explosion_radius()
	_spawn_explosion_visual(enemy, explosion_radius)
	_detonate(enemy, damage, chain_state, explosion_radius)


func blocks_pierce_consumption() -> bool:
	return true


func _damage_for_chain(chain_count: int) -> int:
	var scaled: float = BASE_EXPLOSION_DAMAGE * pow(CHAIN_DAMAGE_DECAY, chain_count)
	return int(max(MIN_EXPLOSION_DAMAGE, round(scaled)))


func _detonate(dying_enemy: BaseEnemy, damage: int, chain_state: Dictionary, explosion_radius: float) -> void:
	if not is_instance_valid(dying_enemy) or not dying_enemy.is_inside_tree():
		return

	var origin: Vector2 = dying_enemy.global_position

	for other in dying_enemy.get_tree().get_nodes_in_group("enemies"):
		if other == dying_enemy or not is_instance_valid(other):
			continue
		if not (other.has_method("has_status_effect") and other.has_method("apply_status_effect")):
			continue
		if "is_alive" in other and not other.is_alive:
			continue
		if origin.distance_to(other.global_position) > explosion_radius:
			continue

		if other.has_status_effect(StatusEffects.POLLINATED):
			if other.has_method("take_damage"):
				other.take_damage(damage, {"pollen_chain": chain_state})
		else:
			other.apply_status_effect(StatusEffects.POLLINATED, {})


func _current_explosion_radius() -> float:
	var radius = Stats.get_stat("pollen", "chain_explosion_radius")
	if radius == null:
		return EXPLOSION_RADIUS
	return radius


func _spawn_explosion_visual(enemy: BaseEnemy, explosion_radius: float) -> void:
	if not is_instance_valid(enemy) or not enemy.is_inside_tree():
		return
	var explosion := PollenExplosionVisual.new()
	explosion.global_position = enemy.global_position
	explosion.max_radius = explosion_radius
	enemy.get_tree().root.add_child(explosion)
