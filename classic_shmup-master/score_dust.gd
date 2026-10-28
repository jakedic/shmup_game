extends Node2D
## Sparkly "score dust": when an enemy dies, a little puff of glittering motes
## bursts out where it died, hangs in the air for a moment, then each mote
## streaks over to the SCORE digits in the right-hand HUD panel. The score
## only ticks up as the motes land, so the player sees the points travel.
##
## Lives in GameShell (on top of the play area AND the side panels), because
## the score counter sits outside the play-area SubViewport. Positions here are
## in the shell's logical units (the 480x320 window space - 1 unit is about one
## game pixel). GameShell converts play-area positions before calling burst().
##
## Runs with PROCESS_MODE_ALWAYS so dust that is in flight when the game
## pauses (power-up choice at the end of a level, absorb freeze, pause menu)
## still lands and the score is never left short.

## Called with the points a mote carries the moment it reaches the score.
signal mote_arrived(points: int)

# ---- Tuning ----------------------------------------------------------------
const MIN_MOTES := 4
const MAX_MOTES := 10
const POINTS_PER_EXTRA_MOTE := 10     # 1 extra mote per this many points earned

# Burst / hover: motes pop out from the corpse and drift to a stop.
const BURST_SPEED_MIN := 18.0
const BURST_SPEED_MAX := 55.0
const BURST_DRAG := 5.5               # higher = they slow down faster
const HOVER_TIME_MIN := 0.30          # how long the dust lingers before leaving
const HOVER_TIME_MAX := 0.50
const HOVER_STAGGER := 0.035          # extra delay per mote so they leave in a stream

# Flight to the score counter.
const FLY_SPEED := 420.0              # units / second (sets duration from distance)
const FLY_TIME_MIN := 0.35
const FLY_TIME_MAX := 0.80
const FLY_ARC := 0.35                 # how much the path curves (fraction of distance)

# Look.
const COLORS := [
	Color(1.0, 0.86, 0.35),   # gold
	Color(1.0, 0.95, 0.65),   # pale gold
	Color(1.0, 1.0, 0.95),    # white
]
const TRAIL_LENGTH := 4               # previous positions kept for the streak
const POP_TIME := 0.18                # little ring flash where a mote lands

var _motes: Array = []
var _pops: Array = []

## Callable returning the current target point (in this node's local space).
## Re-evaluated every frame, so window resizes / screen shake don't matter.
var target_provider: Callable


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	z_index = 10


## Spawn a puff of dust at `from` (local position) worth `points` in total.
## The points are split across the motes; together they add up exactly.
func burst(from: Vector2, points: int) -> void:
	var count: int = clampi(MIN_MOTES + points / POINTS_PER_EXTRA_MOTE, MIN_MOTES, MAX_MOTES)
	count = max(min(count, points), 1)
	var share: int = points / count
	var leftover: int = points - share * count
	for i in count:
		var dir := Vector2.RIGHT.rotated(randf() * TAU)
		var mote := {
			"pos": from + dir * randf_range(0.0, 3.0),
			"vel": dir * randf_range(BURST_SPEED_MIN, BURST_SPEED_MAX),
			"hover": randf_range(HOVER_TIME_MIN, HOVER_TIME_MAX) + i * HOVER_STAGGER,
			"flying": false,
			"t": 0.0,
			"fly_time": 0.5,
			"p0": Vector2.ZERO,
			"bend": randf_range(-1.0, 1.0),
			"points": share + (1 if i < leftover else 0),
			"color": COLORS[randi() % COLORS.size()],
			"size": 1.5 if randf() < 0.6 else 2.0,
			"twinkle": randf() * TAU,
			"twinkle_speed": randf_range(14.0, 24.0),
			"trail": [],
		}
		_motes.append(mote)


## Points that are still flying (not yet added to the displayed score).
func points_in_flight() -> int:
	var total := 0
	for m in _motes:
		total += m.points
	return total


## Drop all dust immediately (scene change / score reset).
func clear() -> void:
	_motes.clear()
	_pops.clear()
	queue_redraw()


func _process(delta: float) -> void:
	if _motes.is_empty() and _pops.is_empty():
		return
	var target: Vector2 = target_provider.call() if target_provider.is_valid() else Vector2.ZERO

	var i := _motes.size() - 1
	while i >= 0:
		var m: Dictionary = _motes[i]
		m.twinkle += m.twinkle_speed * delta
		var trail: Array = m.trail
		trail.push_front(m.pos)
		if trail.size() > TRAIL_LENGTH:
			trail.pop_back()

		if not m.flying:
			# Burst out and settle, with a tiny upward float.
			m.vel *= exp(-BURST_DRAG * delta)
			m.vel.y -= 6.0 * delta
			m.pos += m.vel * delta
			m.hover -= delta
			if m.hover <= 0.0:
				m.flying = true
				m.t = 0.0
				m.p0 = m.pos
				var dist: float = m.pos.distance_to(target)
				m.fly_time = clampf(dist / FLY_SPEED, FLY_TIME_MIN, FLY_TIME_MAX)
		else:
			m.t += delta / m.fly_time
			if m.t >= 1.0:
				_pops.append({"pos": target, "t": 0.0, "color": m.color})
				mote_arrived.emit(m.points)
				_motes.remove_at(i)
				i -= 1
				continue
			# Quadratic bezier from where it hovered to the score, bowed to
			# one side, eased in so it starts lazy and whips into the counter.
			var p0: Vector2 = m.p0
			var to := target - p0
			var normal := Vector2(-to.y, to.x).normalized()
			var p1: Vector2 = p0 + to * 0.35 + normal * to.length() * FLY_ARC * m.bend
			var s: float = m.t * m.t
			var a := p0.lerp(p1, s)
			var b := p1.lerp(target, s)
			m.pos = a.lerp(b, s)
		i -= 1

	var j := _pops.size() - 1
	while j >= 0:
		_pops[j].t += delta / POP_TIME
		if _pops[j].t >= 1.0:
			_pops.remove_at(j)
		j -= 1

	queue_redraw()


func _draw() -> void:
	for m in _motes:
		var glow: float = 0.55 + 0.45 * sin(m.twinkle)
		var col: Color = m.color
		# Streak behind it (only really visible once it's moving fast).
		var prev: Vector2 = m.pos
		var k := 0
		for p in m.trail:
			k += 1
			var fade := 1.0 - float(k) / float(TRAIL_LENGTH + 1)
			draw_line(prev, p, Color(col, 0.65 * fade * glow), m.size * 0.75)
			prev = p
		# Soft halo, then the core pixel.
		draw_circle(m.pos, m.size * 1.6, Color(col, 0.22 * glow))
		var half: float = m.size * 0.5
		draw_rect(Rect2(m.pos - Vector2(half, half), Vector2(m.size, m.size)), Color(col, glow))
		# Four-point glint on the twinkle peaks.
		if glow > 0.85:
			var arm: float = 2.0 + m.size * 1.25
			var gc := Color(col, (glow - 0.85) / 0.15)
			draw_line(m.pos - Vector2(arm, 0), m.pos + Vector2(arm, 0), gc, 0.75)
			draw_line(m.pos - Vector2(0, arm), m.pos + Vector2(0, arm), gc, 0.75)

	for p in _pops:
		var r: float = 2.0 + 6.0 * p.t
		draw_arc(p.pos, r, 0.0, TAU, 12, Color(p.color, 0.8 * (1.0 - p.t)), 1.0)
