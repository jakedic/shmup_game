extends Control

## Developer/test-only menu (see levels/title_screen.gd's Test button). Lets
## you jump straight into any real level - anything under res://levels/ whose
## script "extends BaseLevel" (see _discover_level_paths()) - with any set of
## power-ups pre-applied, instead of playing through the whole overworld to
## get there. New levels and new power-ups show up here automatically;
## nothing to register by hand.
##
## Drawn entirely in code (same approach as levels/shop.gd and
## levels/overworld.gd) rather than with Container/Button nodes, to sidestep
## the min-size/anchor pitfalls those ran into before and to match the rest
## of the game's hand-drawn menus.
##
## Navigation: Up/Down moves the highlighted row between the level picker,
## one row per power-up, then LAUNCH and BACK. Left/Right on the level row
## cycles which level is selected. The "start" action activates whatever's
## highlighted - toggles a power-up's checkbox, launches the level, or
## returns to the title screen.
##
## NOT part of the overworld run system (see GameProgress) - launching a
## level from here doesn't touch GameProgress at all, so the level just
## follows its own ordinary next-level/title-screen fallback when it ends
## (see BaseLevel.change_levels()) instead of trying to report back to a run
## that was never started.

const MAP_WIDTH := 240.0

const ROW_HEIGHT := 14.0
const LEVEL_ROW_Y := 40.0
const POWERUPS_START_Y := 70.0

enum RowType { LEVEL, POWERUP, LAUNCH, BACK }

var level_paths: Array = []       # every discovered level scene path, sorted
var level_index: int = 0          # which one is currently selected

var powerups: Array = []          # every power-up dict (see PlayerPowerUps.get_every_powerup())
var powerup_checked: Array = []   # parallel bool array, index-matched to `powerups`

var rows: Array = []              # built once in _ready() - see _build_rows()
var cursor_row: int = 0


func _ready() -> void:
	level_paths = _discover_level_paths()
	level_index = 0

	powerups = PlayerPowerUps.get_every_powerup()
	powerup_checked = []
	for i in range(powerups.size()):
		powerup_checked.append(false)

	_build_rows()
	set_process(true)


func _build_rows() -> void:
	"""Flatten "the level picker, then one row per power-up, then LAUNCH,
	then BACK" into a single list Up/Down can walk with plain modular
	arithmetic - see _input()/_draw_*_row()."""
	rows.clear()
	rows.append({"type": RowType.LEVEL})
	for i in range(powerups.size()):
		rows.append({"type": RowType.POWERUP, "index": i})
	rows.append({"type": RowType.LAUNCH})
	rows.append({"type": RowType.BACK})
	cursor_row = 0


func _discover_level_paths() -> Array:
	"""Every .tscn directly under res://levels/ whose matching .gd script
	says "extends BaseLevel" - i.e. an actual playable level, as opposed to a
	menu/overworld/shop screen (title_screen.gd, overworld.gd, shop.gd, and
	tutorial_screen.gd all extend Control instead). New levels show up here
	automatically - nothing to register by hand."""
	var found: Array = []
	var dir := DirAccess.open("res://levels")
	if dir == null:
		return found

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tscn"):
			var script_path := "res://levels/%s.gd" % file_name.trim_suffix(".tscn")
			if FileAccess.file_exists(script_path):
				var source := FileAccess.get_file_as_string(script_path)
				if source.find("extends BaseLevel") != -1:
					found.append("res://levels/" + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

	found.sort()
	return found


func _input(event: InputEvent) -> void:
	if rows.is_empty():
		return

	if event.is_action_pressed("down"):
		cursor_row = (cursor_row + 1) % rows.size()
	elif event.is_action_pressed("up"):
		cursor_row = (cursor_row - 1 + rows.size()) % rows.size()

	var row: Dictionary = rows[cursor_row]

	if row["type"] == RowType.LEVEL and level_paths.size() > 1:
		if event.is_action_pressed("right"):
			level_index = (level_index + 1) % level_paths.size()
		elif event.is_action_pressed("left"):
			level_index = (level_index - 1 + level_paths.size()) % level_paths.size()

	if event.is_action_pressed("start"):
		_activate_row(row)


func _activate_row(row: Dictionary) -> void:
	match row["type"]:
		RowType.POWERUP:
			var i: int = row["index"]
			powerup_checked[i] = not powerup_checked[i]
		RowType.LAUNCH:
			_launch()
		RowType.BACK:
			get_tree().change_scene_to_file("res://levels/title_screen.tscn")


func _launch() -> void:
	if level_paths.is_empty():
		return

	# Clean slate - a test run shouldn't inherit power-ups/currency left over
	# from a previous playthrough or an earlier trip through this menu.
	Stats.clear_run_modifiers()
	Stats.clear_level_modifiers()
	Stats.clear_currency()

	# Checked power-ups become RUN modifiers (Stats.choose_run_powerup()),
	# same tier a player earns by picking one at the end-of-level popup - so
	# they're already active the instant the level starts and survive
	# BaseLevel.new_game()'s clear_level_modifiers() call.
	for i in range(powerups.size()):
		if powerup_checked[i]:
			var powerup: Dictionary = powerups[i]
			Stats.choose_run_powerup(powerup.get("id", ""), powerup.get("stats", {}))

	get_tree().change_scene_to_file(level_paths[level_index])


func _process(_delta: float) -> void:
	queue_redraw()


# ---------- Drawing ----------

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 1))

	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(12, 16), "* TEST MENU *", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.85, 0.2))

	_draw_level_row(font)
	_draw_powerup_rows(font)
	_draw_launch_row(font)
	_draw_back_row(font)


func _draw_level_row(font: Font) -> void:
	draw_string(font, Vector2(12, 30), "LEVEL", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.6, 0.65, 0.75))

	var is_selected := cursor_row == 0
	var label: String
	if level_paths.is_empty():
		label = "(no levels found)"
	else:
		var level_name: String = level_paths[level_index].get_file().trim_suffix(".tscn")
		if is_selected and level_paths.size() > 1:
			label = "< %s >" % level_name
		else:
			label = level_name

	var color := Color(1.0, 0.85, 0.35) if is_selected else Color(0.85, 0.87, 0.95)
	if is_selected:
		draw_rect(Rect2(10, LEVEL_ROW_Y - 11, MAP_WIDTH - 20, 15), Color(1, 1, 1, 0.08))
	draw_string(font, Vector2(20, LEVEL_ROW_Y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, color)


func _draw_powerup_rows(font: Font) -> void:
	draw_string(font, Vector2(12, POWERUPS_START_Y - 10), "POWER-UPS", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.6, 0.65, 0.75))

	for i in range(powerups.size()):
		var row_i := 1 + i  # row 0 is the level row - see _build_rows()
		var y: float = POWERUPS_START_Y + i * ROW_HEIGHT
		var is_selected := cursor_row == row_i
		var checked: bool = powerup_checked[i]
		var powerup: Dictionary = powerups[i]

		if is_selected:
			draw_rect(Rect2(10, y - 10, MAP_WIDTH - 20, ROW_HEIGHT), Color(1, 1, 1, 0.08))

		var box_color := Color(1.0, 0.85, 0.35) if is_selected else Color(0.5, 0.52, 0.62)
		draw_rect(Rect2(14, y - 8, 8, 8), box_color, false, 1.0)
		if checked:
			draw_rect(Rect2(16, y - 6, 4, 4), Color(0.4, 0.9, 0.55), true)

		var text_color := Color(1.0, 0.85, 0.35) if is_selected else Color(0.82, 0.84, 0.9)
		draw_string(font, Vector2(28, y), powerup.get("name", "?"), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, text_color)


func _draw_launch_row(font: Font) -> void:
	var row_i := 1 + powerups.size()
	var y: float = POWERUPS_START_Y + powerups.size() * ROW_HEIGHT + 14.0
	_draw_action_button(font, y, "LAUNCH", cursor_row == row_i, Color(0.4, 0.85, 0.55))


func _draw_back_row(font: Font) -> void:
	var row_i := 2 + powerups.size()
	var y: float = POWERUPS_START_Y + powerups.size() * ROW_HEIGHT + 14.0 + 26.0
	_draw_action_button(font, y, "BACK TO TITLE", cursor_row == row_i, Color(0.7, 0.72, 0.8))


func _draw_action_button(font: Font, y: float, label: String, is_selected: bool, accent: Color) -> void:
	var button_width := 150.0
	var button_height := 20.0
	var x := (MAP_WIDTH - button_width) / 2.0
	var rect := Rect2(x, y, button_width, button_height)

	var bg_color := Color(0.12, 0.12, 0.06, 1.0) if is_selected else Color(0.06, 0.07, 0.15, 1.0)
	var border_color := accent if is_selected else Color(0.4, 0.42, 0.5, 0.7)
	var text_color := accent if is_selected else Color(0.75, 0.77, 0.85)
	var text := ("> %s <" % label) if is_selected else label

	draw_rect(rect, bg_color, true)
	draw_rect(rect, border_color, false, 2.0 if is_selected else 1.0)

	var font_size := 9
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(font, Vector2(x + (button_width - text_size.x) / 2.0, y + button_height / 2.0 + text_size.y * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)
