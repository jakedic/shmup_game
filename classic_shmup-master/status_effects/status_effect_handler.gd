# status_effect_handler.gd
## Base class for a status-condition's behavior. Subclass this, implement
## whichever hooks you need, and register an instance with
## StatusEffects.register_handler() (see status_effects/status_effect_registry.gd)
## to plug a brand new status condition into BaseEnemy's generic
## apply_status_effect() / remove_status_effect() / take_damage() flow
## without touching base_enemy.gd or bullet_base.gd again.
##
## See pollinated_status.gd for a full example.
class_name StatusEffectHandler
extends RefCounted


## Called the first time this status is applied to an enemy that didn't
## already have it. `data` is whatever dictionary was passed to
## apply_status_effect() - use it for per-application parameters (e.g. who
## inflicted it, custom potency, etc).
func on_apply(_enemy: BaseEnemy, _data: Dictionary) -> void:
	pass


## Called when apply_status_effect() is used again on an enemy that already
## has this status (e.g. a pollen puff hitting an already-pollinated
## enemy). Default just re-runs on_apply(); override if "refreshing" an
## existing status should behave differently (e.g. stacking, resetting a
## duration, etc).
func on_reapply(enemy: BaseEnemy, data: Dictionary) -> void:
	on_apply(enemy, data)


## Called when the status is explicitly removed via remove_status_effect().
## NOT called when the enemy node is simply freed on death - any visual
## child nodes added in on_apply() are freed automatically along with the
## enemy, so no cleanup is needed there.
func on_remove(_enemy: BaseEnemy) -> void:
	pass


## Called from BaseEnemy.die() once for every status effect the enemy has
## at the moment it dies, regardless of what killed it. `context` is
## whatever was passed into take_damage() -> die() and is a good place to
## carry state across a cascade of deaths this status effect causes (see
## pollinated_status.gd's chain-explosion use of context["pollen_chain"]).
func on_owner_died(_enemy: BaseEnemy, _context: Dictionary) -> void:
	pass


## Return true if a piercing shot that hits an enemy currently affected by
## this status should NOT consume a charge of its pierce budget (still
## deals damage, bullet just keeps going). Used by bullet_base.gd via
## BaseEnemy.blocks_pierce_consumption().
func blocks_pierce_consumption() -> bool:
	return false
