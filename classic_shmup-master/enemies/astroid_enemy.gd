# astroid_enemy.gd
#
# Shared behavior for every astroid size (see enemies/astroid_medium.tscn and
# enemies/astroid_small.tscn) - just health, straight-line drift + a slow
# spin, and (for the medium astroid) breaking into smaller pieces on death.
# No shooting, no diving, no anchor-following like base_enemy.gd's other
# enemies get - astroids only ever do one thing: travel a straight line.
#
# HOW TO SPAWN ONE FROM LEVEL CODE (this is the whole API):
#
#     var a = preload("res://enemies/astroid_medium.tscn").instantiate()
#     add_child(a)
#     a.launch(start_pos, end_pos, speed)
#
# `start_pos`/`end_pos` just define the straight line the astroid travels
# (it keeps going straight past `end_pos` - it doesn't stop there, it only
# sets the direction). `speed` is in pixels/second. See
# levels/astroid_level.gd for a working example.
extends "res://enemies/base_enemy.gd"
class_name AstroidEnemy

# ===== SPIN (cosmetic only - not part of the path) =====
@export var rotation_speed_min_deg: float = 15.0
@export var rotation_speed_max_deg: float = 40.0

# ===== FALLBACK SPEED =====
# Only used if something spawns this astroid the generic way - calling
# start(pos) instead of launch(start_pos, end_pos, speed). New level code
# should always use launch() instead; this just keeps a plain start(pos)
# call from doing nothing.
@export var default_travel_speed: float = 20.0

# ===== OFF-SCREEN DESPAWN MARGIN =====
# How far past the screen edge (px) handle_boundaries() below lets this
# astroid travel before quietly removing it - see handle_boundaries(). Has to
# be bigger than however far off-screen whatever spawns this astroid places
# it at launch(), or it despawns itself on its very first frame, before it
# ever gets a chance to move into view or render - which is exactly what was
# happening for every astroid spawned through levels/squad_wave_level.gd's
# spawn_drift_wave(): _side_point() there places a fresh spawn
# OFFSCREEN_MARGIN (48px) past the edge, well beyond this margin's old 32px
# default, so handle_boundaries() (called before custom_process() applies any
# movement each frame - see base_enemy.gd's _process()) saw an "out of
# bounds" position before the astroid had moved at all and killed it
# instantly. 64px comfortably clears that 48px spawn offset with room to
# spare; bump this further if a level's own off-screen spawn margin is ever
# made larger than that.
@export var offscreen_despawn_margin: float = 64.0

# ===== SPLITTING (medium astroid only) =====
# When split_scene is set, this astroid breaks into split_count copies of it
# the moment it dies (see custom_die() below). Leave split_scene empty for an
# astroid that should just disappear when destroyed - e.g. the small astroid,
# which is already the smallest piece this enemy type comes in.
@export var split_scene: PackedScene
@export var split_count: int = 3
@export var split_angle_spread_deg: float = 70.0  # how far apart the fragments fan out
@export var split_speed_multiplier: float = 1.3  # fragments fly out a bit faster than the parent was moving

# Current straight-line velocity (px/s) and spin (deg/s). Set by launch(),
# start(), or _spawn_fragment() below - custom_process() just applies
# whatever is here every frame.
var travel_velocity: Vector2 = Vector2.ZERO
var rotation_speed_deg: float = 0.0
var _is_traveling: bool = false

func custom_ready():
	# Astroids don't shoot, dive, or follow the bobbing enemy anchor the way
	# most other enemies do - they only ever move in the straight line set
	# by launch() below.
	can_shoot = false
	can_dive = false
	follow_anchor_enabled = false

func launch(start_pos: Vector2, end_pos: Vector2, speed: float) -> void:
	"""The normal way to spawn an astroid from level code - see the header
	comment at the top of this file. Places it at start_pos, points it
	toward end_pos, and sends it off at `speed` pixels/second - no spawn-in
	animation, it's already moving the instant this returns."""
	position = start_pos
	var direction = (end_pos - start_pos).normalized()
	_begin_travel(direction * speed)

func start(pos: Vector2) -> void:
	"""Fallback for the generic `if e.has_method("start"): e.start(pos)`
	spawn pattern used elsewhere in this project - sends the astroid
	straight down at default_travel_speed. Prefer launch() from new level
	code, which lets you choose the direction and speed directly."""
	if not is_alive:
		return
	position = pos
	_begin_travel(Vector2.DOWN * default_travel_speed)

func _begin_travel(velocity: Vector2) -> void:
	"""Shared by launch(), start(), and _spawn_fragment() - sets the
	velocity this astroid will drift at, picks a random spin, and turns on
	movement (see custom_process() below)."""
	travel_velocity = velocity
	rotation_speed_deg = randf_range(rotation_speed_min_deg, rotation_speed_max_deg)
	if randf() < 0.5:
		rotation_speed_deg = -rotation_speed_deg
	_is_traveling = true

func custom_process(delta: float):
	if not _is_traveling:
		return
	position += travel_velocity * delta
	rotation += deg_to_rad(rotation_speed_deg) * delta

func handle_boundaries():
	"""Override base_enemy.gd's version, which resets a diving enemy once it
	falls past the bottom of the screen so it can dive again - wrong for an
	astroid drifting in a straight line, which should just quietly disappear
	once it's left the play area on any side, with no explosion and no
	score."""
	if not _is_traveling:
		return
	if position.x < -offscreen_despawn_margin or position.x > screensize.x + offscreen_despawn_margin \
			or position.y < -offscreen_despawn_margin or position.y > screensize.y + offscreen_despawn_margin:
		is_alive = false
		queue_free()

func custom_die():
	if not split_scene:
		return
	for i in range(split_count):
		var t = float(i) / max(1, split_count - 1)
		var angle = deg_to_rad(split_angle_spread_deg) * (t - 0.5)
		var fragment_velocity = travel_velocity.rotated(angle) * split_speed_multiplier
		_spawn_fragment(fragment_velocity)

func _spawn_fragment(velocity: Vector2) -> void:
	"""Spawn one split fragment already traveling, at this astroid's current
	position - adds it as a sibling under the same level so its `died`
	signal can be wired up the same way a normally-launched astroid's is."""
	var fragment = split_scene.instantiate()
	var level = get_parent()
	level.add_child(fragment)
	fragment.position = position
	fragment.rotation = rotation
	fragment._begin_travel(velocity)
	if fragment.has_signal("died") and level.has_method("_on_enemy_died"):
		fragment.died.connect(level._on_enemy_died)
