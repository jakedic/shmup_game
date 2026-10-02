extends Bullet
class_name Bubble

@export var bubble_scene: PackedScene  # The bubble projectile scene
# Safety net only - the bubble now moves and bounces continuously (see
# _process() below) rather than traveling then stopping, so this is just how
# long it's allowed to keep bouncing before it's forced to pop on its own.
@export var bubble_lifetime: float = 30.0

@onready var screensize: Vector2 = get_viewport_rect().size

var absorbed_enemy_type: String = "" 

# Every enemy type absorbed into this bubble, in the order absorbed. For a
# normal bubble this is just [absorbed_enemy_type] (or empty). When two
# bubbles fuse into a power bubble (see _try_merge_with_bubble), the two
# lists are concatenated - enemy_types[0] is then "the first enemy in the
# bubble" that PlayerPowerUps uses to pick which power-up pool to grant from.
var enemy_types: Array = []

# Power bubbles are formed when one bubble hits another (see
# _on_area_entered/_try_merge_with_bubble). They glow a different color and,
# instead of transforming the player on touch, grant a random power-up.
var is_power_bubble: bool = false

# Glow color per "first enemy type" for a power bubble. Falls back to
# DEFAULT_POWER_BUBBLE_COLOR for enemy types that aren't listed (or none).
const POWER_BUBBLE_COLORS := {
	"yellow": Color(1.0, 0.92, 0.15, 1.0),
	"red": Color(1.0, 0.25, 0.25, 1.0),
	"hive": Color(1.0, 0.6, 0.15, 1.0),
	"flower": Color(1.0, 0.45, 0.8, 1.0),
}
const DEFAULT_POWER_BUBBLE_COLOR := Color(0.75, 0.3, 1.0, 1.0)

var hit_points: int = 3  # Editor-time fallback; player._apply_bubble_stats() sets this from Stats.get_category("bubble") when spawned
var current_hits: int = 0

# Counts up every frame; compared against bubble_lifetime as a safety-net
# pop (see _process()).
var time_elapsed: float = 0.0

# ---- Player paddle-bounce tuning (see _bounce_off_player()) ----
const PLAYER_BOUNCE_MAX_ANGLE_DEG := 65.0
const PLAYER_BOUNCE_VELOCITY_INFLUENCE := 0.6
const PLAYER_BOUNCE_SPEED_MULTIPLIER_CAP := 1.75
# Collision with the player is disabled at spawn and only re-enabled once the
# bubble is at least this far from its spawn point - see custom_start() and
# _process(). Fixes an instant bounce the moment the bubble is launched,
# since it spawns almost right on top of the player's own collision shape.
const PLAYER_COLLISION_ARM_DISTANCE := 32.0

var base_speed: float = 0.0  # speed at spawn; caps how fast a paddle-bounce can make the bubble go
var _player_collision_armed: bool = false

# ---- Bubble-bubble "gravity" tuning (see _apply_bubble_attraction()) ----
const BUBBLE_ATTRACTION_RADIUS := 70.0  # smaller than the original 120 - only kicks in once bubbles are already fairly close
const BUBBLE_ATTRACTION_TURN_RATE := 10.0  # how fast direction snaps toward the nearest bubble in range - strong on purpose, see _apply_bubble_attraction()
const BUBBLE_ATTRACTION_PULL_SPEED := 160.0  # direct extra pull toward the nearest bubble, on top of steering, so the last bit of gap always closes

# ---- Shockwave charge (see on_shockwave_hit()) ----
# When the player's dash-jump landing shockwave (player/landing_shockwave.gd)
# reaches a bubble, it bounces away from the blast and becomes "charged" for
# a blue outline, slightly faster, and it deals SHOCKWAVE_CHARGE_DAMAGE to
# each enemy it passes through (once per pass - area_entered only fires
# again after it leaves and re-enters). Enemy bullets still pass through
# with no effect either way. The charge lasts until the player next
# paddle-bounces the bubble (see _bounce_off_player()) - another shockwave
# hit just keeps it charged.
const SHOCKWAVE_CHARGE_DAMAGE := 1
const SHOCKWAVE_CHARGE_SPEED_MULT := 1.12
const SHOCKWAVE_OUTLINE_COLOR := Color(0.3, 0.7, 1.0, 1.0)
var is_shockwave_charged: bool = false
# time_elapsed when the charge was applied. A paddle touch within
# SHOCKWAVE_TOUCH_GRACE of that doesn't clear it - covers landing right next
# to the bubble, where the ship's touch and the shockwave arrive together.
var _charged_at: float = -1.0
const SHOCKWAVE_TOUCH_GRACE := 0.25

# Solo bubbles show the enemy type they carry as a small tinted circle
# inside the bubble (see _apply_solo_tint()), instead of tinting the whole
# bubble. Subtle on purpose.
const TYPE_CORE_RADIUS := 5.0
const TYPE_CORE_FILL_ALPHA := 0.35
const TYPE_CORE_RING_ALPHA := 0.7

const COLOR_LOCK_SHADER := "shader_type canvas_item;\nuniform vec4 lock_color : source_color;\nvoid fragment() {\n\tCOLOR = vec4(lock_color.rgb, COLOR.a * lock_color.a);\n}\n"

static func _make_color_lock_material(c: Color) -> ShaderMaterial:
	"""Material that paints a node's drawing in exactly color c (keeping
	its alpha), ignoring the bubble's own modulate - so a white hit flash
	or tint never recolors the outline / type circle."""
	var shader := Shader.new()
	shader.code = COLOR_LOCK_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("lock_color", c)
	return mat

class TypeCore extends Node2D:
	## Small circle inside a solo bubble showing the enemy type it carries.
	var color: Color = Color(1.0, 0.92, 0.15, 1.0)
	var radius: float = 5.0
	var fill_alpha: float = 0.35
	var ring_alpha: float = 0.7

	func _ready() -> void:
		material = Bubble._make_color_lock_material(color)

	func _draw() -> void:
		draw_circle(Vector2.ZERO, radius, Color(1, 1, 1, fill_alpha))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 24, Color(1, 1, 1, ring_alpha), 1.0)

class ChargeOutline extends Node2D:
	## Pulsing blue ring drawn around a charged bubble. Uses a tiny shader
	## that replaces the color outright, so the bubble's own tint (yellow
	## solo bubble, power-bubble glow, white hit flash) doesn't recolor it.
	var color: Color = Color(0.3, 0.7, 1.0, 1.0)
	var radius: float = 12.5
	var _t: float = 0.0

	func _ready() -> void:
		material = Bubble._make_color_lock_material(color)

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		# Gentle pulse so it reads as "energized" rather than a static border.
		var a: float = 0.65 + 0.35 * sin(_t * 10.0)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(1, 1, 1, a), 2.0)

func _ready():
	# Connect to area entered signal
	area_entered.connect(_on_area_entered)
	add_to_group("bubble")
	
func set_enemy_type(enemy_type: String):
	absorbed_enemy_type = enemy_type
	enemy_types = [enemy_type] if enemy_type != "" else []
	_apply_solo_tint()

func _apply_solo_tint() -> void:
	"""Mark a solo (non-fused) bubble with a small circle inside it in the
	color of the transformation it's carrying (e.g. yellow after ejecting a
	yellow transformation), so it's visually distinct from a plain bubble
	and from a fused power bubble.
	Reuses the same per-type palette as a power bubble's glow
	(POWER_BUBBLE_COLORS) so the color language stays consistent."""
	if is_power_bubble:
		return  # power bubbles get their own glow treatment - see apply_power_bubble_visuals()
	_remove_type_core()
	if absorbed_enemy_type == "":
		return
	# A small circle inside the bubble rather than tinting the whole thing.
	# It's its own child node, so the shockwave charge outline (another
	# child) and hit flashes leave it alone - it stays for the bubble's life.
	var core := TypeCore.new()
	core.name = "TypeCore"
	core.color = POWER_BUBBLE_COLORS.get(absorbed_enemy_type, DEFAULT_POWER_BUBBLE_COLOR)
	core.radius = TYPE_CORE_RADIUS
	core.fill_alpha = TYPE_CORE_FILL_ALPHA
	core.ring_alpha = TYPE_CORE_RING_ALPHA
	add_child(core)

func _remove_type_core() -> void:
	var existing := get_node_or_null("TypeCore")
	if existing:
		# Detach first so a replacement added this same frame keeps the name.
		remove_child(existing)
		existing.queue_free()

func custom_start():
	"""Initialize bubble behavior"""
	time_elapsed = 0.0
	base_speed = speed
	_player_collision_armed = false

	# Disable collision with the player until the bubble is
	# PLAYER_COLLISION_ARM_DISTANCE away from its spawn point (see
	# _process()). Replaces the old fixed 0.1s timer, which could still
	# leave collision enabled while the bubble was overlapping the player
	# (e.g. player standing still), causing an instant bounce right at spawn.
	set_collision_mask_value(1, false)  # Disable player collision mask

func _process(delta: float):
	"""Continuously move and bounce off the stage's walls, brick-breaker
	style, instead of Bullet's normal travel-then-stop model. This fully
	replaces Bullet._process() (Bubble never calls super/custom_process for
	movement) - homing, bounce_count, and max_distance from the base Bullet
	class don't apply to bubbles at all.

	Bounces off the left, right, and top edges of the screen forever. The
	bottom edge is different: falling out the bottom counts as a miss (the
	bubble never hit the player) and it just disappears, no pop effect -
	same spirit as a normal bullet leaving the screen. bubble_lifetime is
	still a safety-net pop in case a bubble somehow keeps bouncing forever
	without ever resolving either way."""
	if _is_fusing:
		return  # driven by _play_fusion_sequence() instead
	time_elapsed += delta
	if time_elapsed >= bubble_lifetime:
		pop_bubble()
		queue_free()
		return

	if not is_power_bubble:
		_apply_bubble_attraction(delta)

	position += direction * speed * delta
	_bounce_off_walls()

	if not _player_collision_armed and global_position.distance_to(spawn_position) >= PLAYER_COLLISION_ARM_DISTANCE:
		_player_collision_armed = true
		set_collision_mask_value(1, true)  # Re-enable player collision

	if position.y > screensize.y + 16:
		# Missed - fell off the bottom without ever touching the player.
		queue_free()

func _bounce_off_walls() -> void:
	"""Reflect direction off the left/right/top screen edges. Never called
	for the bottom edge - see _process()."""
	if position.x <= 0:
		position.x = 0
		direction.x = abs(direction.x)
	elif position.x >= screensize.x:
		position.x = screensize.x
		direction.x = -abs(direction.x)

	if position.y <= 0:
		position.y = 0
		direction.y = abs(direction.y)

func _apply_bubble_attraction(delta: float) -> void:
	"""Once two plain bubbles get close enough (BUBBLE_ATTRACTION_RADIUS),
	pull this one toward the single nearest other bubble in range, so they
	actually collide and fuse instead of swinging past each other.

	First version of this steered direction toward the SUMMED pull of every
	bubble in range with a fairly gentle turn rate. That's a classic mutual-
	pursuit setup: two bubbles continuously re-aiming at each other's current
	position, at a turn rate that's weak relative to how fast they're
	closing, tends to spiral/orbit around a shared point rather than actually
	converge - which is exactly the "revolve around and miss" behavior that
	got reported. Fix: target only the single closest bubble (no more
	competing pulls from multiple directions to wobble around), turn toward
	it much more aggressively the closer it gets, and add a direct positional
	pull on top so the very last bit of gap always closes.

	Only between two plain bubbles - power bubbles never fuse with anything
	(_try_merge_with_bubble bails if either side already is one), so pulling
	one toward/away from something would have no payoff. Callers should only
	invoke this for a non-power bubble to begin with; it also skips any power
	bubble it finds while scanning for a target."""
	var closest: Bubble = null
	var closest_dist := BUBBLE_ATTRACTION_RADIUS
	for other in get_tree().get_nodes_in_group("bubble"):
		if other == self or not is_instance_valid(other) or other.is_queued_for_deletion():
			continue
		if other.is_power_bubble or other._is_fusing:
			continue
		var dist := global_position.distance_to(other.global_position)
		if dist < closest_dist:
			closest = other
			closest_dist = dist

	if closest == null:
		return

	# Closer bubbles pull harder - 0 at the radius edge, 1.0 on top of each other.
	var closeness := 1.0 - (closest_dist / BUBBLE_ATTRACTION_RADIUS)
	var pull_direction: Vector2 = (closest.global_position - global_position).normalized()

	# Snap the heading toward the other bubble - strong, and gets stronger
	# the closer they are, so it overrides the bubble's own momentum instead
	# of just gently curving it (the weak curve is what let them swing past
	# each other before). clamp() returns Variant even with float arguments
	# (same note as offset_x in _bounce_off_player) - explicit type here
	# rather than :=.
	var turn_factor: float = clamp(BUBBLE_ATTRACTION_TURN_RATE * (0.5 + closeness) * delta, 0.0, 1.0)
	direction = direction.lerp(pull_direction, turn_factor).normalized()

	# Extra direct pull on top of normal movement, so the last stretch of gap
	# always closes even if steering alone hasn't fully lined them up yet.
	position += pull_direction * BUBBLE_ATTRACTION_PULL_SPEED * closeness * delta

func _get_player_half_extents(player: Node2D) -> Vector2:
	"""Best-effort half-width/half-height of the player's collision shape, so
	_bounce_off_player() can tell where along the ship the bubble hit. Falls
	back to a small nonzero size if the shape can't be read, so the offset
	math below never divides by zero."""
	var collision_shape := player.get_node_or_null("CollisionShape2D")
	if collision_shape and collision_shape.shape is RectangleShape2D:
		return collision_shape.shape.size / 2.0
	return Vector2(16, 16)

func _bounce_off_player(player: Node2D) -> void:
	"""Deflect the bubble off the player like a brick-breaker paddle, instead
	of transforming/consuming it. Where along the player's width the bubble
	hit steers the bounce angle (capped at PLAYER_BOUNCE_MAX_ANGLE_DEG off
	straight up); the player's own velocity blends in a bit more steering
	(same idea as get_bubble_launch_direction() in player_absorption.gd); and
	the resulting speed can pick up slightly but never exceeds
	PLAYER_BOUNCE_SPEED_MULTIPLIER_CAP times the bubble's original speed.

	Also ends a shockwave charge - unless the charge was applied a moment
	ago (the touch and the landing shockwave arrived together)."""
	if is_shockwave_charged and time_elapsed - _charged_at > SHOCKWAVE_TOUCH_GRACE:
		_clear_shockwave_charge()

	var half_extents := _get_player_half_extents(player)
	# clamp() returns Variant in GDScript even with all-float arguments, so
	# offset_x needs an explicit type here rather than := - otherwise it
	# infers as Variant and trips "type inferred from Variant" as an error.
	var offset_x: float = clamp((global_position.x - player.global_position.x) / half_extents.x, -1.0, 1.0)
	var max_angle := deg_to_rad(PLAYER_BOUNCE_MAX_ANGLE_DEG)

	var bounce_direction := Vector2.UP.rotated(max_angle * offset_x)

	if "current_velocity" in player and player.current_velocity.length() > 0.01:
		bounce_direction = (bounce_direction + player.current_velocity.normalized() * PLAYER_BOUNCE_VELOCITY_INFLUENCE).normalized()
		# Re-clamp: velocity steering alone could otherwise push the angle
		# past the same cap the hit-offset is limited to.
		var angle_from_up := Vector2.UP.angle_to(bounce_direction)
		bounce_direction = Vector2.UP.rotated(clamp(angle_from_up, -max_angle, max_angle))

	direction = bounce_direction

	var speed_boost := 1.0
	if "current_velocity" in player:
		speed_boost += clamp(player.current_velocity.length() / 400.0, 0.0, 1.0) * 0.3
	speed = min(speed * speed_boost, base_speed * PLAYER_BOUNCE_SPEED_MULTIPLIER_CAP)

	# Nudge the bubble just past the player's edge along the new direction so
	# it doesn't immediately re-trigger the same touch next frame.
	global_position += bounce_direction * 4.0

	flash_white()

func on_shockwave_hit(center: Vector2) -> void:
	"""Called by LandingShockwave when its ring reaches this bubble. Bounces
	off the ring like off a wall (reflect if heading into it; if already
	heading away it just keeps going), then charges the bubble."""
	var normal: Vector2 = global_position - center
	if normal.length() < 0.01:
		normal = Vector2.UP
	normal = normal.normalized()
	if direction.dot(normal) < 0.0:
		direction = direction.bounce(normal).normalized()
	global_position += normal * 2.0
	flash_white()
	_become_shockwave_charged()

func _become_shockwave_charged() -> void:
	# Re-hit while already charged: just refresh the grace timer.
	_charged_at = time_elapsed
	if is_shockwave_charged:
		return
	is_shockwave_charged = true
	speed *= SHOCKWAVE_CHARGE_SPEED_MULT
	# Raise the paddle-bounce speed cap by the same amount so the first
	# bounce off the player doesn't immediately clamp the boost back off.
	base_speed *= SHOCKWAVE_CHARGE_SPEED_MULT
	var outline := ChargeOutline.new()
	outline.name = "ChargeOutline"
	outline.color = SHOCKWAVE_OUTLINE_COLOR
	add_child(outline)

func _clear_shockwave_charge() -> void:
	"""Back to a normal bubble: no outline, no enemy damage, speed boost
	removed."""
	if not is_shockwave_charged:
		return
	is_shockwave_charged = false
	speed /= SHOCKWAVE_CHARGE_SPEED_MULT
	base_speed /= SHOCKWAVE_CHARGE_SPEED_MULT
	var outline := get_node_or_null("ChargeOutline")
	if outline:
		remove_child(outline)
		outline.queue_free()

func pop_bubble():
	"""Create a pop effect when bubble expires"""
	# Optional: Add pop particles
	if has_node("PopParticles"):
		$PopParticles.emitting = true
	
	# Optional: Add pop sound
	# if has_node("PopSound"):
	#     $PopSound.play()
	
	# Optional: Add a small area damage effect when bubble pops
	create_pop_damage()

func create_pop_damage():
	"""Create explosion damage (or, with the yellow_bubble_pollen_pop
	power-up active, guaranteed pollination instead of damage) using a
	simple timer approach"""
	
	# Get all enemies in range manually
	var explosion_radius = 80
	var enemies_in_range = []
	
	# Search for enemies in the scene
	var all_nodes = get_tree().get_nodes_in_group("enemies")
	
	for enemy in all_nodes:
		if is_instance_valid(enemy):
			var distance = global_position.distance_to(enemy.global_position)
			if distance <= explosion_radius:
				enemies_in_range.append(enemy)
	
	# The pop also wipes out every enemy bullet inside the blast (including
	# the hive's walls, which normal shots can't destroy).
	_clear_enemy_bullets(explosion_radius)

	# yellow_bubble_pollen_pop power-up: the pop explosion no longer deals
	# damage at all - it guarantees the "pollinated" status effect on every
	# enemy it hits instead (see status_effects/pollinated_status.gd for
	# what pollination actually does).
	if Stats.get_stat("bubble", "pop_applies_pollination"):
		for enemy in enemies_in_range:
			if enemy.has_method("apply_status_effect"):
				enemy.apply_status_effect(StatusEffects.POLLINATED, {})
		create_visual_explosion()
		return
	
	# Damage all enemies in range
	var damage_amount = damage * 3
	for enemy in enemies_in_range:
		if enemy.has_method("take_damage"):
			enemy.take_damage(damage_amount)
		elif enemy.has_method("explode"):
			enemy.explode()
	
	# Create a visual explosion effect (optional)
	create_visual_explosion()
	

func _clear_enemy_bullets(radius: float) -> void:
	"""Remove every enemy bullet (group "enemy_bullet") within `radius` of the
	bubble's pop."""
	for b in get_tree().get_nodes_in_group("enemy_bullet"):
		if not is_instance_valid(b) or b.is_queued_for_deletion():
			continue
		if global_position.distance_to(b.global_position) <= radius:
			b.queue_free()

func create_visual_explosion():
	"""Create a blue circular explosion effect using a Polygon2D"""
	var explosion = Polygon2D.new()
	
	# Create a circle with 32 points
	var points = []
	var radius = 80
	var segments = 32
	for i in range(segments):
		var angle = (i / float(segments)) * 2 * PI
		var x = cos(angle) * radius
		var y = sin(angle) * radius
		points.append(Vector2(x, y))
	
	explosion.polygon = points
	explosion.color = Color(0.3, 0.6, 1.0, 0.7)  # Blue with transparency
	explosion.position = global_position
	
	# Add to scene
	get_parent().add_child(explosion)
	
	# Animate the explosion (expand and fade)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(explosion, "scale", Vector2(1.5, 1.5), 0.3)
	tween.tween_property(explosion, "modulate:a", 0.0, 0.3)
	
	# Use a timer to clean up instead of await
	var cleanup_timer = Timer.new()
	cleanup_timer.wait_time = 0.35  # Slightly longer than animation
	cleanup_timer.one_shot = true
	cleanup_timer.timeout.connect(func(): 
		if is_instance_valid(explosion):
			explosion.queue_free()
		cleanup_timer.queue_free()
	)
	GameShell.game_root().add_child(cleanup_timer)
	cleanup_timer.start()

'''func _on_area_entered(area: Area2D):
	"""Handle collisions - bubble only damages enemies when stationary"""
	if area.is_in_group("enemies") and has_stopped:
		# Bubble hits enemy while stationary - damage and pop
		if area.has_method("take_damage"):
			area.take_damage(damage)
		pop_bubble()
		queue_free()
	elif area.is_in_group("enemies") and not has_stopped:
		# Bubble hits enemy while moving - just damage and continue
		if area.has_method("take_damage"):
			area.take_damage(damage)
		
		# Optional: Reduce pierce count if using piercing
		if pierce_count > 0:
			current_pierce += 1
			if current_pierce >= pierce_count:
				queue_free()'''
				
func _on_area_entered(area: Area2D):
	# Check if this bubble hit another bubble - if so, fuse into a power
	# bubble instead of any of the normal collision handling below.
	if area is Bubble and area != self:
		_try_merge_with_bubble(area)
		return

	# Check if player touched the bubble
	if area.is_in_group("player") or area.name == "Player":
		if is_power_bubble:
			apply_powerup_to_player(area)
			# Power bubbles are still consumed on touch, same as before.
			queue_free()
		else:
			# Plain bubbles bounce off the player like a brick-breaker paddle
			# instead of transforming/consuming it. Power bubbles above are
			# untouched by this change.
			_bounce_off_player(area)
		return
	
	# Enemies and enemy bullets are deliberately ignored - the bubble has no
	# interaction with either of them at all. They pass through it and it
	# passes through them: no damage, no popping, no flash, nothing removed
	# on either side. (Enemy bullets and enemies used to chip away at
	# current_hits/hit_points here and eventually pop the bubble - removed
	# per request so the bubble is fully immune to them.)
	#
	# Exception: a shockwave-charged bubble (see on_shockwave_hit()) chips
	# SHOCKWAVE_CHARGE_DAMAGE off each enemy it passes through. Still no
	# effect on the bubble itself, and enemy bullets are still ignored.
	if area.is_in_group("enemies") or area.is_in_group("enemy"):
		if is_shockwave_charged and area.has_method("take_damage"):
			area.take_damage(SHOCKWAVE_CHARGE_DAMAGE)
		return
	if area.is_in_group("enemy_bullet"):
		return

	# NEW: Check if hit by player's bullet
	if area.is_in_group("player_bullet") or area.is_in_group("player_projectile"):
		
		# Remove the player bullet
		area.queue_free()
		
		# Create explosion damage
		pop_bubble()
		
		# Remove the bubble
		queue_free()
		return
func _try_merge_with_bubble(other: Bubble) -> void:
	"""Two overlapping bubbles fuse into one power bubble. Both bubbles get
	an area_entered callback for the same overlap (once per side), so only
	the lower-instance-id bubble (the one that existed first) performs the
	merge and frees the other one; the higher-id bubble just no-ops here and
	waits to be freed."""
	if is_power_bubble or other.is_power_bubble:
		return  # power bubbles don't fuse further
	if _is_fusing or other._is_fusing:
		return  # already mid-fusion with something else
	if is_queued_for_deletion() or other.is_queued_for_deletion():
		return
	if get_instance_id() > other.get_instance_id():
		return  # the other (older) bubble will perform the merge instead

	# Self is the older bubble, so its enemy type(s) come first - that's
	# "the first enemy in the bubble" that decides the power-up pool.
	var combined_types: Array = enemy_types.duplicate()
	combined_types.append_array(other.enemy_types)

	_play_fusion_sequence(other, combined_types)

# ---- Fusion cutscene (see _play_fusion_sequence()) ----
# Everything here runs while the whole game is paused, like the absorb freeze.
const FUSION_ORBIT_DURATION := 0.9   # seconds the two bubbles spiral around each other
const FUSION_ORBIT_TURNS := 2.5      # full revolutions during the spiral
const FUSION_MIN_ORBIT_RADIUS := 10.0  # start radius if they touched almost dead-centre
const FUSION_GROW_DURATION := 0.3    # pop up into the bigger bubble
const FUSION_BIG_SCALE := 1.8        # size of the fused bubble vs a normal one
const FUSION_HOLD_DURATION := 0.2    # beat to admire the big bubble before it moves
const FUSION_TRAVEL_SPEED := 260.0   # px/s flying to the player
const FUSION_MIN_TRAVEL_TIME := 0.25
const FUSION_ABSORB_DURATION := 0.15 # shrink into the player on arrival

var _is_fusing: bool = false

func _play_fusion_sequence(other: Bubble, combined_types: Array) -> void:
	"""Two bubbles met: freeze the game, spiral them around each other into
	one bigger power bubble, fly it to the player, then grant the power-up
	(whose popup - BaseLevel.show_powerup_popup() - keeps the game paused
	until the player dismisses it). Fire-and-forget coroutine; the bubble
	frees itself at the end."""
	_is_fusing = true
	other._is_fusing = true
	# No more collisions for either bubble while this plays out.
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	other.set_deferred("monitoring", false)
	other.set_deferred("monitorable", false)

	var tree := get_tree()
	tree.paused = true

	# --- 1. Spiral around each other ---
	var center: Vector2 = (global_position + other.global_position) * 0.5
	var start_offset: Vector2 = global_position - center
	if start_offset.length() < FUSION_MIN_ORBIT_RADIUS:
		start_offset = start_offset.normalized() * FUSION_MIN_ORBIT_RADIUS if start_offset.length() > 0.01 else Vector2(FUSION_MIN_ORBIT_RADIUS, 0)
	var orbit := func(t: float) -> void:
		# Ease in so the spin speeds up as they close in.
		var e := t * t
		var off := start_offset.rotated(TAU * FUSION_ORBIT_TURNS * e) * (1.0 - e)
		if is_instance_valid(self):
			global_position = center + off
		if is_instance_valid(other):
			other.global_position = center - off
	var tw := _paused_tween()
	tw.tween_method(orbit, 0.0, 1.0, FUSION_ORBIT_DURATION)
	await tw.finished

	# --- 2. Combine into a bigger bubble ---
	var other_charged: bool = is_instance_valid(other) and other.is_shockwave_charged
	if is_instance_valid(other):
		other.queue_free()
	global_position = center
	become_power_bubble(combined_types)
	if other_charged:
		_become_shockwave_charged()
	var base_scale := scale
	tw = _paused_tween()
	tw.tween_property(self, "scale", base_scale * FUSION_BIG_SCALE * 1.2, FUSION_GROW_DURATION * 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", base_scale * FUSION_BIG_SCALE, FUSION_GROW_DURATION * 0.4)
	tw.tween_interval(FUSION_HOLD_DURATION)
	await tw.finished

	# --- 3. Fly to the player ---
	var player = tree.get_first_node_in_group("player")
	if player == null or not is_instance_valid(player) or ("is_alive" in player and not player.is_alive):
		# Nobody to give it to - just end the freeze and drop the bubble.
		tree.paused = false
		queue_free()
		return
	var target: Vector2 = player.global_position
	var travel_time: float = max(global_position.distance_to(target) / FUSION_TRAVEL_SPEED, FUSION_MIN_TRAVEL_TIME)
	tw = _paused_tween()
	tw.tween_property(self, "global_position", target, travel_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "scale", Vector2.ZERO, FUSION_ABSORB_DURATION)
	await tw.finished

	# --- 4. Give the player the power-up and show it ---
	var first_enemy_type: String = enemy_types[0] if enemy_types.size() > 0 else absorbed_enemy_type
	var granted: Dictionary = {}
	if is_instance_valid(player) and player.has_method("apply_random_powerup"):
		granted = player.apply_random_powerup(first_enemy_type)
	if granted.is_empty():
		# No power-up available for this type (so no popup to dismiss) -
		# unfreeze ourselves.
		tree.paused = false
	# Otherwise the power-up popup is now up and owns the pause; it unpauses
	# when the player dismisses it.
	queue_free()

func _paused_tween() -> Tween:
	"""A tween that keeps running while the tree is paused."""
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	return tw

func become_power_bubble(combined_types: Array) -> void:
	"""Turn this bubble into a power bubble containing combined_types
	(first entry = the enemy type its power-up will be drawn from)."""
	is_power_bubble = true
	enemy_types = combined_types
	absorbed_enemy_type = combined_types[0] if combined_types.size() > 0 else absorbed_enemy_type
	current_hits = 0  # fresh health pool for the fused bubble
	_remove_type_core()  # the power glow shows the type now

	apply_power_bubble_visuals()

func apply_power_bubble_visuals() -> void:
	"""Glow a different color than a normal bubble, based on the first
	absorbed enemy type."""
	var glow_color: Color = POWER_BUBBLE_COLORS.get(absorbed_enemy_type, DEFAULT_POWER_BUBBLE_COLOR)
	modulate = glow_color

	var glow_tween = create_tween().set_loops()
	glow_tween.tween_property(self, "modulate", glow_color.lightened(0.5), 0.5)
	glow_tween.tween_property(self, "modulate", glow_color, 0.5)

func apply_powerup_to_player(player: Area2D) -> void:
	"""A power bubble was touched - grant a random power-up (from the pool
	belonging to the first enemy type absorbed into this bubble) instead of
	the normal transformation."""
	var first_enemy_type: String = enemy_types[0] if enemy_types.size() > 0 else absorbed_enemy_type

	if player.has_method("apply_random_powerup"):
		player.apply_random_powerup(first_enemy_type)

	create_absorption_effect()

func create_absorption_effect():
	"""Create a visual effect when bubble is absorbed"""
	# Add particles or flash effect
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 0, 1), 0.1)
	tween.tween_property(self, "modulate", Color(1, 1, 0, 0), 0.1)

func flash_white():
	# Quick flash effect to show it was hit
	var original_color = modulate
	modulate = Color.WHITE
	await get_tree().create_timer(0.1).timeout
	modulate = original_color

func explode_or_disappear():
	queue_free()
