# yellow_miniboss.gd
# End-of-level miniboss for Yellow Level (see levels/yellow_level.gd, wave
# 4): a single 30-health BaseEnemy dressed up as a "giant mound" of yellow
# enemies - a cluster of cloned yellow-enemy sprites, randomly placed and
# rotated within a circle (see _build_visual_mound()), all belonging to ONE
# hurtbox/health pool rather than being separately-alive enemies. Each piece
# also gets a small in-place wobble/rotation/frame-flicker (see
# _process_mound_swarm()) so the pile reads as a swarm of bees shifting
# around inside the mound, not a static image or one rigid rotating blob.
#
# Fight structure: the boss idles at a fixed spot, vulnerable. Every time it
# loses RETREAT_HEALTH_STEP (10) health, it goes invincible, flies up off
# the top of the screen, and the level spawns two YellowSquad "adds" (see
# levels/yellow_level.gd's _on_miniboss_retreat_started()) - the SAME squad
# behavior other waves use, not a special variant. Once every add is
# destroyed, the level calls resume_after_adds() and the boss flies back
# down and becomes vulnerable again. This repeats for as many 10-health
# steps as fit under max_health, minus the last one - the final step just
# lets it die normally (explode, wave clear) instead of retreating again.
extends BaseEnemy
class_name YellowMiniboss

signal retreat_started

const RETREAT_HEALTH_STEP := 20
const MOUND_PIECE_COUNT := 48
const MOUND_RADIUS := 24.0
const OFFSCREEN_Y := -60.0

@export var retreat_duration: float = 1.1
@export var mound_spin_speed: float = 0.3  # radians/sec, whole-mound rotation - purely cosmetic

# Per-piece "swarming" motion (see _build_visual_mound()/custom_process()) -
# each bee jitters/rotates in place around its own fixed spot in the mound
# and occasionally flickers its sprite frame, instead of the mound reading as
# one frozen, rigidly-spinning blob. Kept small relative to MOUND_RADIUS so
# pieces never visibly wander in or out of the mound's silhouette.
@export var piece_wobble_radius: float = 2.5       # px of drift around each piece's home spot
@export var piece_wobble_speed_min: float = 1.5     # radians/sec of that drift's own cycle
@export var piece_wobble_speed_max: float = 3.5
@export var piece_rotation_wobble: float = 0.35     # radians of extra rotation jitter, +/-
@export var piece_flicker_interval_min: float = 0.12  # seconds between a piece's wing-frame flickers
@export var piece_flicker_interval_max: float = 0.4

enum State { ENTERING, VULNERABLE, RETREATING, WAITING_FOR_ADDS, RETURNING }

var _state: int = State.ENTERING
var _home_pos: Vector2 = Vector2.ZERO
var _next_retreat_threshold: int = 0  # next health value <= which triggers a retreat; 0 once retreats are used up

# Parallel arrays, one entry per mound piece (see _build_visual_mound()) -
# kept separate from the Sprite2D nodes themselves so custom_process() can
# animate every piece each frame without any per-frame allocation.
var _mound_pieces: Array = []
var _mound_base_pos: Array = []
var _mound_base_rot: Array = []
var _mound_wobble_phase: Array = []
var _mound_wobble_speed: Array = []
var _mound_next_flicker: Array = []

@onready var _visual_root: Node2D = $VisualRoot


func _ready():
	max_health = 60
	current_health = max_health
	score_value = 500  # a real payoff for a boss kill, well above a regular enemy's 5
	can_shoot = false
	can_dive = false
	follow_anchor_enabled = false
	squad_controlled = true  # this node drives its own position entirely - see custom_process()/base_enemy._process()

	# A boss deserves a slower, more deliberate entrance than a regular grunt's.
	spawn_delay_min = 0.3
	spawn_delay_max = 0.3
	spawn_animation_duration = 2.0

	# base_enemy._ready() (which this override replaces entirely, not calls
	# via super()) is what would normally add "enemy" (singular) - "enemies"
	# (plural) is the group base_level.gd's wave-clear check and bubble.gd's
	# targeting actually look for, and normally comes from the .tscn node's
	# own groups=[...] (see yellow_miniboss.tscn). Adding it here too is
	# belt-and-suspenders in case the scene file's group ever gets dropped.
	add_to_group("enemies")
	modulate = enemy_color
	_build_visual_mound()


func _build_visual_mound() -> void:
	"""Fake the "giant mound of yellow enemies" look by cloning the yellow
	enemy's own sprite sheet a bunch of times at random positions/rotations/
	scales inside a circle - purely visual, none of these pieces are
	separately alive or hittable. The whole mound shares ONE hurtbox/health
	pool (see the CollisionShape2D in yellow_miniboss.tscn). Each piece also
	gets its own wobble/flicker timing stashed in the _mound_* arrays so
	custom_process() can animate it in place - see _process_mound_swarm()."""
	var texture: Texture2D = preload("res://Art assets/Player assets and transformations/Bee_enemy_spritesheet.png")
	for i in range(MOUND_PIECE_COUNT):
		var piece := Sprite2D.new()
		piece.texture = texture
		piece.hframes = 3
		piece.frame = randi() % 3
		var r: float = MOUND_RADIUS * sqrt(randf())  # uniform over the disk, not just the radius
		var a: float = randf() * TAU
		piece.position = Vector2(cos(a), sin(a)) * r
		piece.rotation = randf() * TAU
		var s: float = randf_range(0.08, 0.12)
		piece.scale = Vector2(s, s)
		_visual_root.add_child(piece)

		_mound_pieces.append(piece)
		_mound_base_pos.append(piece.position)
		_mound_base_rot.append(piece.rotation)
		_mound_wobble_phase.append(randf() * TAU)
		_mound_wobble_speed.append(randf_range(piece_wobble_speed_min, piece_wobble_speed_max))
		_mound_next_flicker.append(randf_range(piece_flicker_interval_min, piece_flicker_interval_max))


func custom_start(pos: Vector2):
	_state = State.ENTERING
	_home_pos = pos
	_next_retreat_threshold = max_health - RETREAT_HEALTH_STEP


func custom_spawn_complete():
	_state = State.VULNERABLE


func custom_process(delta: float):
	_visual_root.rotation += mound_spin_speed * delta
	_process_mound_swarm(delta)


func _process_mound_swarm(delta: float) -> void:
	"""Give each bee in the mound its own small, contained motion - a slow
	circular drift around its fixed spot plus a bit of rotation jitter, with
	an occasional sprite-frame flicker layered on top - so the mound reads as
	a pile of individually-shifting/buzzing bees rather than one rigid shape
	that just spins as a whole (that's mound_spin_speed, above). Every piece
	always drifts back around its own _mound_base_pos, so nothing wanders out
	of the mound's silhouette."""
	for i in range(_mound_pieces.size()):
		var piece: Sprite2D = _mound_pieces[i]
		if not is_instance_valid(piece):
			continue

		_mound_wobble_phase[i] += _mound_wobble_speed[i] * delta
		var phase: float = _mound_wobble_phase[i]
		var wobble := Vector2(cos(phase), sin(phase * 1.3)) * piece_wobble_radius
		piece.position = _mound_base_pos[i] + wobble
		piece.rotation = _mound_base_rot[i] + sin(phase * 1.7) * piece_rotation_wobble

		_mound_next_flicker[i] -= delta
		if _mound_next_flicker[i] <= 0.0:
			piece.frame = randi() % 3
			_mound_next_flicker[i] = randf_range(piece_flicker_interval_min, piece_flicker_interval_max)


func custom_take_damage(damage_amount: int) -> bool:
	"""Watch for crossing the next retreat threshold instead of dying
	outright. Returning true here (same as a real death, per base_enemy's
	take_damage()) short-circuits the normal current_health<=0 death check
	below it and skips the plain damage-flash - the retreat's own
	invincibility flash (see set_invincible()) is the feedback instead."""
	if _state != State.VULNERABLE:
		return false
	if _next_retreat_threshold > 0 and current_health <= _next_retreat_threshold:
		_begin_retreat()
		return true
	return false


func _begin_retreat() -> void:
	_state = State.RETREATING
	set_invincible(true)
	set_deferred("monitorable", false)
	set_deferred("monitoring", false)
	_next_retreat_threshold -= RETREAT_HEALTH_STEP
	retreat_started.emit()  # levels/yellow_level.gd spawns the two add squads on this

	var tw = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "position:y", OFFSCREEN_Y, retreat_duration)
	await tw.finished
	visible = false
	_state = State.WAITING_FOR_ADDS


func resume_after_adds() -> void:
	"""Called by levels/yellow_level.gd once both add squads spawned by the
	last retreat are fully cleared."""
	if _state != State.WAITING_FOR_ADDS or not is_alive:
		return
	_state = State.RETURNING
	position = Vector2(_home_pos.x, OFFSCREEN_Y)
	visible = true
	set_deferred("monitorable", true)
	set_deferred("monitoring", true)

	var tw = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position:y", _home_pos.y, retreat_duration)
	await tw.finished
	set_invincible(false)
	_state = State.VULNERABLE
