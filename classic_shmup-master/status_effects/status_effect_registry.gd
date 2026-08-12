# status_effect_registry.gd
# NOT an autoload - a plain static-utility class, referenced globally as
# `StatusEffects` (from its class_name below) with no project.godot changes
# needed. Static vars/funcs have worked this way since Godot 4.0, so a
# lazily-initialized static Dictionary does the same job an autoload
# singleton would, just without the extra registration step.
#
# Central place that maps a status-condition name (String) to the
# StatusEffectHandler instance that implements its behavior. BaseEnemy calls
# into this registry from apply_status_effect() / remove_status_effect() /
# die() / blocks_pierce_consumption(), and Bullet reads BaseEnemy's status
# state indirectly through those same methods - so adding a brand new status
# condition later never requires touching base_enemy.gd or bullet_base.gd
# again. Just write a new StatusEffectHandler subclass and register() it
# below (or from anywhere else, e.g. another script's _ready()).
class_name StatusEffects
extends RefCounted

# ===== Known status-condition names =====
# Use these constants instead of typing the raw string elsewhere.
const POLLINATED := "pollinated"

static var _handlers: Dictionary = {}  # status_name -> StatusEffectHandler
static var _initialized: bool = false


static func _ensure_initialized() -> void:
	"""Registers the built-in handlers on first use. Guarded so that if
	something already registered a custom "pollinated" handler before this
	ever ran, we don't clobber it with the default one."""
	if _initialized:
		return
	_initialized = true
	if not _handlers.has(POLLINATED):
		register_handler(POLLINATED, PollinatedStatus.new())


static func register_handler(status_name: String, handler: StatusEffectHandler) -> void:
	_handlers[status_name] = handler


static func get_handler(status_name: String) -> StatusEffectHandler:
	_ensure_initialized()
	return _handlers.get(status_name)


static func has_handler(status_name: String) -> bool:
	_ensure_initialized()
	return _handlers.has(status_name)
