extends Control

# Space-themed overworld map. Draws the planet graph tracked by
# GameProgress (autoload) and lets the player pick a path with
# left/right + start (Enter) once a level has been beaten.

const NODE_RADIUS := 9.0
const MAP_WIDTH := 240.0
const MAP_HEIGHT := 320.0
const TOP_MARGIN := 34.0
const BOTTOM_MARGIN := 34.0
const STAR_COUNT := 40

# x position for each slot in a 3-node layer (1st/2nd/3rd node left to right)
const LAYER_X := {
	1: 46.0,
	2: 120.0,
	3: 194.0,
}

var cursor_index: int = 0
var available: Array = []
var pulse_time: float = 0.0
var showing_victory: bool = false
var stars: Array = []

@onready var victory_label: Label = $VictoryLabel


func _ready() -> void:
	victory_label.hide()

	stars.clear()
	for i in range(STAR_COUNT):
		stars.append(Vector2(randf() * MAP_WIDTH, randf() * MAP_HEIGHT))

	if GameProgress.has_won_run():
		_show_victory()
		return

	available = GameProgress.get_available_nodes()
	cursor_index = 0
	set_process(true)


func _show_victory() -> void:
	showing_victory = true
	victory_label.show()
	queue_redraw()
	await get_tree().create_timer(2.5).timeout
	GameProgress.reset_run()
	get_tree().change_scene_to_file("res://levels/title_screen.tscn")


func _process(delta: float) -> void:
	pulse_time += delta
	queue_redraw()


func _input(event: InputEvent) -> void:
	if showing_victory:
		return

	if available.size() > 1:
		if event.is_action_pressed("right"):
			cursor_index = (cursor_index + 1) % available.size()
		elif event.is_action_pressed("left"):
			cursor_index = (cursor_index - 1 + available.size()) % available.size()

	if event.is_action_pressed("start") and available.size() > 0:
		var chosen_id: int = available[cursor_index]
		set_process(false)
		GameProgress.select_and_play(chosen_id)


# ---------- Layout ----------

func _node_position(node_id: int) -> Vector2:
	var layer := GameProgress.get_layer_of(node_id)
	var layer_nodes: Array = GameProgress.LAYERS[layer]
	var layer_span := MAP_HEIGHT - TOP_MARGIN - BOTTOM_MARGIN
	var y := TOP_MARGIN + layer * (layer_span / float(GameProgress.LAYERS.size() - 1))

	var x: float
	if layer_nodes.size() == 1:
		x = MAP_WIDTH / 2.0
	else:
		x = LAYER_X[layer_nodes.find(node_id) + 1]

	return Vector2(x, y)


# ---------- Drawing ----------

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 1))

	for star in stars:
		draw_circle(star, 1.0, Color(1, 1, 1, 0.5))

	if showing_victory:
		return

	for layer_index in range(GameProgress.LAYERS.size() - 1):
		for node_id in GameProgress.LAYERS[layer_index]:
			for child_id in GameProgress.get_next_nodes(node_id):
				_draw_edge(node_id, child_id)

	for layer in GameProgress.LAYERS:
		for node_id in layer:
			_draw_node(node_id)

	_draw_currency()


func _draw_currency() -> void:
	"""Small readout of the player's shop currency (see stats.gd) in the
	top-left corner, so it's visible before deciding whether to head for a
	shop node (see GameProgress.is_shop_node())."""
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(8, 14), "$ %d" % Stats.currency, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1.0, 0.85, 0.35))


func _draw_edge(from_id: int, to_id: int) -> void:
	var from_pos := _node_position(from_id)
	var to_pos := _node_position(to_id)

	var is_choice := from_id == GameProgress.current_node_id and available.has(to_id)
	var is_travelled := _is_travelled_edge(from_id, to_id)

	var color := Color(0.35, 0.37, 0.5, 0.45)
	var width := 1.0

	if is_travelled:
		color = Color(0.4, 0.85, 0.55, 0.9)
		width = 2.0
	elif is_choice:
		var pulse := 0.6 + 0.4 * sin(pulse_time * 4.0)
		color = Color(1.0, 0.85, 0.35, pulse)
		width = 2.0

	draw_line(from_pos, to_pos, color, width)


func _is_travelled_edge(from_id: int, to_id: int) -> bool:
	var history: Array = GameProgress.path_history
	for i in range(history.size() - 1):
		if history[i] == from_id and history[i + 1] == to_id:
			return true
	return false


func _draw_node(node_id: int) -> void:
	var pos := _node_position(node_id)
	var reached: bool = GameProgress.path_history.has(node_id)
	var is_available: bool = available.has(node_id)
	var is_selected: bool = is_available and available.size() > 0 and available[cursor_index] == node_id
	var is_shop: bool = GameProgress.is_shop_node(node_id)

	var color := Color(0.4, 0.42, 0.55, 1.0) # locked / not yet reachable
	var radius := NODE_RADIUS

	if reached:
		color = Color(0.35, 0.8, 0.5, 1.0)
	if is_available:
		color = Color(0.95, 0.75, 0.3, 1.0)
	if is_selected:
		var pulse := 6.0 + 2.0 * sin(pulse_time * 6.0)
		radius = NODE_RADIUS + pulse
		draw_circle(pos, radius + 3.0, Color(1, 1, 1, 0.35))

	if is_shop:
		_draw_shop_node(pos, radius, color)
	else:
		draw_circle(pos, radius, color)
		draw_arc(pos, radius, 0, TAU, 24, Color(0, 0, 0, 0.4), 1.5, true)


func _draw_shop_node(pos: Vector2, radius: float, color: Color) -> void:
	"""Shop nodes (see GameProgress.is_shop_node()) are drawn as a diamond
	with a "$" glyph instead of a plain planet circle, so they read as a
	different kind of stop on the map at a glance - state (locked/available/
	reached/selected) still comes through via `color`/`radius`, same as
	_draw_node() computes for every other node."""
	var points := PackedVector2Array([
		pos + Vector2(0, -radius),
		pos + Vector2(radius, 0),
		pos + Vector2(0, radius),
		pos + Vector2(-radius, 0),
	])
	draw_colored_polygon(points, color)
	draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[0]]), Color(0, 0, 0, 0.4), 1.5, true)

	var font := ThemeDB.fallback_font
	var font_size := int(max(6.0, radius))
	var label := "$"
	var text_size: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(font, pos - text_size / 2.0 + Vector2(0, text_size.y * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0, 0, 0, 0.75))
