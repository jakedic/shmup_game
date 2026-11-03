extends Control
const TestOptions := preload("res://test_options.gd")   # Test menu switches (see test_options.gd)

## Developer/test-only menu (see levels/title_screen.gd's Test button). Lets
## you jump straight into any real level - anything under res://levels/ whose
## script extends BaseLevel, directly or indirectly (see
## _discover_level_paths()) - with any set of power-ups pre-applied, instead
## of playing through the whole overworld to get there. New levels and new
## power-ups show up here automatically; nothing to register by hand.
##
## Drawn entirely in code (same approach as levels/shop.gd and
## levels/overworld.gd) rather than with Container/Button nodes, to sidestep
## the min-size/anchor pitfalls those ran into before and to match the rest
## of the game's hand-drawn menus.
##
## Below the level picker are the TEST OPTIONS checkboxes - gameplay
## variations to try out (bubble behaviors, multiplier, absorbing), defined in
## test_options.gd (TestOptions.MENU_ROWS). They stay set for the rest of the
## session. The power-up checkboxes are hidden for now - flip SHOW_POWERUPS
## back on to bring them back.
##
## Navigation: Up/Down moves the highlighted row between the level picker,
## one row per test option (and power-up, if shown), then LAUNCH and BACK. Left/Right on the level row
## cycles which level is selected, and on a slider row (e.g. bubble Speed)
## changes its number. The "start" action activates whatever's
## highlighted - toggles a power-up's checkbox, launches the level, or
## returns to the title screen.
##
## NOT part of the overworld run system (see GameProgress) - launching a
## level from here doesn't touch GameProgress at all, so the level just
## follows its own ordinary next-level/title-screen fallback when it ends
## (see BaseLevel.change_levels()) instead of trying to report back to a run
## that was never started.

const MAP_WIDTH := 240.0

const ROW_HEIGHT := 12.0
const LEVEL_ROW_Y := 40.0
const OPTIONS_START_Y := 60.0
const BUTTON_GAP := 4.0          # space above LAUNCH
const BUTTON_SPACING := 24.0     # LAUNCH -> BACK

# Power-up checkboxes are switched off for now (test options instead). Set
# true to show them again, under the test options.
const SHOW_POWERUPS := false

enum RowType { LEVEL, HEADER, OPTION, SLIDER, POWERUP, LAUNCH, BACK }

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
	"""Flatten "the level picker, the test options (with their group
	headers), the power-ups if shown, then LAUNCH, then BACK" into one list,
	each row with the y it's drawn at. Up/Down walks it, skipping headers -
	see _input()/_draw()."""
	rows.clear()
	rows.append({"type": RowType.LEVEL, "y": LEVEL_ROW_Y})
	var y := OPTIONS_START_Y
	for entry in TestOptions.MENU_ROWS:
		if entry.has("header"):
			rows.append({"type": RowType.HEADER, "label": entry["header"], "y": y})
		elif entry.has("slider"):
			rows.append({"type": RowType.SLIDER, "id": entry["slider"], "label": entry["name"],
				"min": entry.get("min", 0), "max": entry.get("max", 10), "y": y})
		else:
			rows.append({"type": RowType.OPTION, "id": entry["id"], "label": entry["name"], "y": y})
		y += ROW_HEIGHT
	if SHOW_POWERUPS:
		rows.append({"type": RowType.HEADER, "label": "POWER-UPS", "y": y})
		y += ROW_HEIGHT
		for i in range(powerups.size()):
			rows.append({"type": RowType.POWERUP, "index": i, "label": powerups[i].get("name", "?"), "y": y})
			y += ROW_HEIGHT
	y += BUTTON_GAP
	rows.append({"type": RowType.LAUNCH, "y": y})
	rows.append({"type": RowType.BACK, "y": y + BUTTON_SPACING})
	cursor_row = 0


func _step_cursor(step: int) -> void:
	"""Move the cursor one selectable row up/down (headers are skipped)."""
	for _i in rows.size():
		cursor_row = (cursor_row + step + rows.size()) % rows.size()
		if rows[cursor_row]["type"] != RowType.HEADER:
			return


func _discover_level_paths() -> Array:
	"""Every .tscn directly under res://levels/ whose matching .gd script
	extends BaseLevel, directly OR indirectly (e.g. levels/squad_wave_level.gd
	extends BaseLevel, and levels/yellow_level.gd extends THAT) - i.e. an
	actual playable level, as opposed to a menu/overworld/shop screen
	(title_screen.gd, overworld.gd, shop.gd, and tutorial_screen.gd all
	extend Control instead). New levels show up here automatically - nothing
	to register by hand, no matter how many levels deep their own base class
	sits above BaseLevel."""
	var found: Array = []
	var dir := DirAccess.open("res://levels")
	if dir == null:
		return found

	var level_class_names := _classes_descended_from("BaseLevel")

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tscn"):
			var script_path := "res://levels/%s.gd" % file_name.trim_suffix(".tscn")
			if FileAccess.file_exists(script_path):
				var source := FileAccess.get_file_as_string(script_path)
				if _extends_any_class(source, level_class_names):
					found.append("res://levels/" + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

	found.sort()
	return found


func _classes_descended_from(root_class_name: String) -> Array:
	"""Every class_name registered in the project that IS `root_class_name`
	or ultimately extends it, however many steps removed - e.g. passing
	"BaseLevel" also returns "SquadWaveLevel" (which extends BaseLevel) plus
	anything that in turn extends SquadWaveLevel. Used by
	_extends_any_class() so new level base classes don't need their own
	special-casing here."""
	var base_class_of := {}  # registered class_name -> the class_name it extends
	for entry in ProjectSettings.get_global_class_list():
		base_class_of[entry["class"]] = entry["base"]

	var descendants := [root_class_name]
	var found_more := true
	while found_more:
		found_more = false
		for a_class_name in base_class_of.keys():
			if descendants.has(a_class_name):
				continue
			if descendants.has(base_class_of[a_class_name]):
				descendants.append(a_class_name)
				found_more = true
	return descendants


func _extends_any_class(source: String, class_names: Array) -> bool:
	for a_class_name in class_names:
		if source.find("extends %s" % a_class_name) != -1:
			return true
	return false


func _input(event: InputEvent) -> void:
	if rows.is_empty():
		return

	if event.is_action_pressed("down"):
		_step_cursor(1)
	elif event.is_action_pressed("up"):
		_step_cursor(-1)

	var row: Dictionary = rows[cursor_row]

	if row["type"] == RowType.LEVEL and level_paths.size() > 1:
		if event.is_action_pressed("right"):
			level_index = (level_index + 1) % level_paths.size()
		elif event.is_action_pressed("left"):
			level_index = (level_index - 1 + level_paths.size()) % level_paths.size()

	# Sliders: Left/Right change the number.
	if row["type"] == RowType.SLIDER:
		var v := TestOptions.get_value(row["id"])
		if event.is_action_pressed("right"):
			TestOptions.set_value(row["id"], mini(v + 1, row["max"]))
		elif event.is_action_pressed("left"):
			TestOptions.set_value(row["id"], maxi(v - 1, row["min"]))

	if event.is_action_pressed("start"):
		_activate_row(row)


func _activate_row(row: Dictionary) -> void:
	match row["type"]:
		RowType.OPTION:
			TestOptions.toggle(row["id"])
		RowType.POWERUP:
			var i: int = row["index"]
			powerup_checked[i] = not powerup_checked[i]
		RowType.LAUNCH:
			_launch()
		RowType.BACK:
			GameShell.change_scene("res://levels/title_screen.tscn")


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

	GameShell.change_scene(level_paths[level_index])


func _process(_delta: float) -> void:
	queue_redraw()


# ---------- Drawing ----------

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 1))

	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(12, 16), "* TEST MENU *", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.85, 0.2))

	_draw_level_row(font)
	for i in range(rows.size()):
		var row: Dictionary = rows[i]
		var is_selected := cursor_row == i
		match row["type"]:
			RowType.HEADER:
				draw_string(font, Vector2(12, row["y"]), row["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(0.6, 0.65, 0.75))
			RowType.OPTION:
				_draw_checkbox_row(font, row["y"], row["label"], TestOptions.is_on(row["id"]), is_selected)
			RowType.SLIDER:
				_draw_slider_row(font, row, is_selected)
			RowType.POWERUP:
				_draw_checkbox_row(font, row["y"], row["label"], powerup_checked[row["index"]], is_selected)
			RowType.LAUNCH:
				_draw_action_button(font, row["y"], "LAUNCH", is_selected, Color(0.4, 0.85, 0.55))
			RowType.BACK:
				_draw_action_button(font, row["y"], "BACK TO TITLE", is_selected, Color(0.7, 0.72, 0.8))


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


func _draw_slider_row(font: Font, row: Dictionary, is_selected: bool) -> void:
	"""Label, a track with one notch per step and a knob, and the number.
	Left/Right changes it while the row is highlighted."""
	var y: float = row["y"]
	if is_selected:
		draw_rect(Rect2(10, y - 9, MAP_WIDTH - 20, ROW_HEIGHT), Color(1, 1, 1, 0.08))
	var value := TestOptions.get_value(row["id"])
	var lo: int = row["min"]
	var hi: int = row["max"]
	var text_color := Color(1.0, 0.85, 0.35) if is_selected else Color(0.82, 0.84, 0.9)
	var label: String = ("< %s >" % row["label"]) if is_selected else row["label"]
	draw_string(font, Vector2(14, y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, text_color)

	var track_x := 86.0
	var track_w := 110.0
	var track_y := y - 3.5
	var track_color := Color(1.0, 0.85, 0.35) if is_selected else Color(0.5, 0.52, 0.62)
	draw_line(Vector2(track_x, track_y), Vector2(track_x + track_w, track_y), track_color, 1.0)
	for i in range(lo, hi + 1):
		var nx := track_x + track_w * float(i - lo) / float(maxi(hi - lo, 1))
		draw_line(Vector2(nx, track_y - 1.5), Vector2(nx, track_y + 1.5), track_color, 1.0)
	var kx := track_x + track_w * float(value - lo) / float(maxi(hi - lo, 1))
	draw_rect(Rect2(kx - 2, track_y - 3.5, 4, 7), Color(0.4, 0.9, 0.55), true)
	draw_string(font, Vector2(track_x + track_w + 8, y), str(value), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, text_color)


func _draw_checkbox_row(font: Font, y: float, label: String, checked: bool, is_selected: bool) -> void:
	if is_selected:
		draw_rect(Rect2(10, y - 9, MAP_WIDTH - 20, ROW_HEIGHT), Color(1, 1, 1, 0.08))

	var box_color := Color(1.0, 0.85, 0.35) if is_selected else Color(0.5, 0.52, 0.62)
	draw_rect(Rect2(14, y - 7, 7, 7), box_color, false, 1.0)
	if checked:
		draw_rect(Rect2(16, y - 5, 3, 3), Color(0.4, 0.9, 0.55), true)

	var text_color := Color(1.0, 0.85, 0.35) if is_selected else Color(0.82, 0.84, 0.9)
	draw_string(font, Vector2(27, y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, text_color)


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
