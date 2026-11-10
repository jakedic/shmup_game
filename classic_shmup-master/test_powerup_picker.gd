extends Control
const MenuKeys := preload("res://menu_keys.gd")   # shared menu keys: WASD/arrows + J/Space/Enter

## Test-mode-only power-up picker, opened from the pause menu's
## "Test: Power-ups" button (only added when the level was launched from the
## Test menu - see TestOptions.launched_from_test_menu and
## BaseLevel._add_test_powerup_button()).
##
## Power-ups are split into PAGES by type (PlayerPowerUps.get_powerup_pages()):
## gray first, then yellow, then any future type. The page bar at the top
## shows "< GRAY 1/2 >"; with it highlighted, Left/Right (A/D) flips pages.
## Each row has a checkbox, the level you have now (HAVE) and the level to
## give it at (SET). Ticks carry across pages - GIVE gives every ticked one. Tick any
## number, pick their levels, then GIVE: the pause menu closes and each ticked
## power-up is set to exactly that level for the rest of the level
## (PlayerPowerUps.set_level_for_test()) - up or down - and the normal info
## popup shows for each one, one after another. Power-ups without levels just
## get granted once.
##
## SET can also take a power-up AWAY: leveled ones go down to NONE (below
## LV 1); ones without levels switch between GIVE and REMOVE.
##
## Keyboard: W/S or Up/Down to move (the page bar is the top row);
##           A/D or Left/Right flips pages on the page bar, and changes SET
##           on a row (also ticking it); J/Space/Enter ticks a row / presses
##           a button.
## Mouse:    click the page bar's < > to flip pages, a row's checkbox/name to
##           tick it, its SET level to cycle it, GIVE/BACK. Drawn in code like levels/test_menu.gd.

## picks: [{"id": String, "level": int}] - level 0 for power-ups without levels.
signal give_requested(picks: Array)
signal back_requested

const WIDTH := 240.0
const ROW_HEIGHT := 13.0
const PAGE_BAR_Y := 40.0
const LIST_TOP := 60.0
const BUTTON_W := 96.0
const BUTTON_H := 18.0
const HAVE_X := 140.0    # "HAVE" column
const SET_X := 180.0     # "SET" column (the level selector)

var pages: Array = []          # PlayerPowerUps.get_powerup_pages()
var page: int = 0              # which page is showing
var powerups: Array = []       # the current page's power-ups (rows)
var checked_ids: Dictionary = {}   # id -> true, across ALL pages
# id -> what GIVE does for that row:
#   leveled power-ups: the level to set, 1..max, or 0 = NONE (take it away)
#   plain power-ups:   1 = GIVE one more copy, 0 = REMOVE every copy
var target_levels: Dictionary = {}
# cursor: -1 = page bar, 0..powerups.size()-1 = rows, then GIVE, then BACK
var cursor: int = -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	hide()


func open() -> void:
	pages = PlayerPowerUps.get_powerup_pages()
	checked_ids.clear()
	target_levels.clear()
	for p: Dictionary in pages:
		for powerup: Dictionary in p["powerups"]:
			if PlayerPowerUps.is_leveled(powerup):
				# Default: one level above what you have now (capped).
				var have: int = Stats.get_powerup_level(powerup.get("id", ""))
				target_levels[powerup.get("id", "")] = mini(have + 1, PlayerPowerUps.get_max_level(powerup))
			else:
				target_levels[powerup.get("id", "")] = 1   # GIVE
	_set_page(0)
	cursor = -1
	show()
	queue_redraw()


func _set_page(index: int) -> void:
	page = wrapi(index, 0, maxi(pages.size(), 1))
	powerups = pages[page]["powerups"] if not pages.is_empty() else []


func _id(i: int) -> String:
	return powerups[i].get("id", "")


func _is_checked(i: int) -> bool:
	return checked_ids.has(_id(i))


func _target(i: int) -> int:
	return int(target_levels.get(_id(i), 0))


func _leveled(i: int) -> bool:
	return PlayerPowerUps.is_leveled(powerups[i])


func _give_index() -> int:
	return powerups.size()


func _back_index() -> int:
	return powerups.size() + 1


func _buttons_y() -> float:
	# Below the tallest page, so GIVE/BACK don't jump around when flipping.
	var rows := 0
	for p: Dictionary in pages:
		rows = maxi(rows, p["powerups"].size())
	return LIST_TOP + rows * ROW_HEIGHT + 10.0


func _give_rect() -> Rect2:
	return Rect2(WIDTH / 2.0 - BUTTON_W - 4.0, _buttons_y(), BUTTON_W, BUTTON_H)


func _back_rect() -> Rect2:
	return Rect2(WIDTH / 2.0 + 4.0, _buttons_y(), BUTTON_W, BUTTON_H)


func _page_bar_rect() -> Rect2:
	return Rect2(8, PAGE_BAR_Y - 10.0, WIDTH - 16, 14.0)


func _row_rect(i: int) -> Rect2:
	return Rect2(8, LIST_TOP + i * ROW_HEIGHT - 10.0, WIDTH - 16, ROW_HEIGHT)


func _change_level(i: int, step: int, wrap: bool) -> void:
	"""Move row i's SET value by step: 0 (NONE / REMOVE) .. max level (1 for
	plain power-ups = GIVE). Changing it also ticks the row, since you
	clearly want to apply it."""
	var max_level := PlayerPowerUps.get_max_level(powerups[i]) if _leveled(i) else 1
	var lvl: int = _target(i) + step
	if wrap:
		lvl = wrapi(lvl, 0, max_level + 1)
	else:
		lvl = clampi(lvl, 0, max_level)
	target_levels[_id(i)] = lvl
	checked_ids[_id(i)] = true


func _flip_page(step: int) -> void:
	_set_page(page + step)
	if cursor >= 0 and cursor < _give_index():
		cursor = -1   # rows changed under the cursor - park it on the page bar


func _input(event: InputEvent) -> void:
	if not visible:
		return
	# Cursor stops: -1 (page bar), rows, GIVE, BACK.
	var last := _back_index()
	var on_row := cursor >= 0 and cursor < powerups.size()
	var dir := 0
	if event.is_action_pressed("right"):
		dir = 1
	elif event.is_action_pressed("left"):
		dir = -1
	if event.is_action_pressed("down"):
		cursor = -1 if cursor >= last else cursor + 1
	elif event.is_action_pressed("up"):
		cursor = last if cursor <= -1 else cursor - 1
	elif dir != 0:
		if on_row:
			_change_level(cursor, dir, false)
		elif cursor == _give_index() and dir > 0:
			cursor = _back_index()
		elif cursor == _back_index() and dir < 0:
			cursor = _give_index()
		elif cursor == -1 or on_row:
			_flip_page(dir)
	elif MenuKeys.is_confirm(event):
		_activate(cursor)
	else:
		return
	get_viewport().set_input_as_handled()
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var p: Vector2 = event.position
	if _page_bar_rect().has_point(p):
		cursor = -1
		_flip_page(-1 if p.x < WIDTH / 2.0 else 1)
	for i in powerups.size():
		if _row_rect(i).has_point(p):
			cursor = i
			if p.x >= SET_X - 6.0:
				_change_level(i, 1, true)   # click the level to cycle it
			else:
				_activate(i)
			break
	if _give_rect().has_point(p):
		_activate(_give_index())
	elif _back_rect().has_point(p):
		_activate(_back_index())
	accept_event()
	queue_redraw()


func _activate(index: int) -> void:
	if index == -1:
		_flip_page(1)   # select on the page bar = next page
	elif index < powerups.size():
		if _is_checked(index):
			checked_ids.erase(_id(index))
		else:
			checked_ids[_id(index)] = true
	elif index == _give_index():
		# Every ticked power-up, from every page, in page order.
		var picks: Array = []
		for p: Dictionary in pages:
			for powerup: Dictionary in p["powerups"]:
				var pid: String = powerup.get("id", "")
				if checked_ids.has(pid):
					var lvl := int(target_levels.get(pid, 0))
					var leveled := PlayerPowerUps.is_leveled(powerup)
					picks.append({"id": pid, "level": lvl if leveled else 0, "remove": lvl == 0})
		hide()
		give_requested.emit(picks)
	else:
		hide()
		back_requested.emit()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.85))
	var font := ThemeDB.fallback_font
	var dim := Color(0.6, 0.65, 0.75)
	draw_string(font, Vector2(10, 16), "* TEST: GIVE POWER-UPS *", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1.0, 0.85, 0.2))
	draw_string(font, Vector2(10, 27), "Tick, set with A/D (NONE removes it), then GIVE.", HORIZONTAL_ALIGNMENT_LEFT, WIDTH - 20, 6, dim)
	_draw_page_bar(font)
	draw_string(font, Vector2(HAVE_X, LIST_TOP - 10.0), "HAVE", HORIZONTAL_ALIGNMENT_LEFT, -1, 6, dim)
	draw_string(font, Vector2(SET_X, LIST_TOP - 10.0), "SET", HORIZONTAL_ALIGNMENT_LEFT, -1, 6, dim)

	for i in powerups.size():
		var powerup: Dictionary = powerups[i]
		var y := LIST_TOP + i * ROW_HEIGHT
		var selected := cursor == i
		var accent: Color = PlayerPowerUps.get_accent_color_for_powerup_id(powerup.get("id", ""))
		if selected:
			draw_rect(_row_rect(i), Color(1, 1, 1, 0.08))
		var box_color := Color(1.0, 0.85, 0.35) if selected else accent.darkened(0.2)
		draw_rect(Rect2(12, y - 7, 7, 7), box_color, false, 1.0)
		if _is_checked(i):
			draw_rect(Rect2(14, y - 5, 3, 3), Color(0.4, 0.9, 0.55), true)
		var text_color := Color(1.0, 0.85, 0.35) if selected else Color(0.85, 0.87, 0.93)
		draw_string(font, Vector2(25, y), powerup.get("name", "?"), HORIZONTAL_ALIGNMENT_LEFT, HAVE_X - 30, 8, text_color)

		var lvl: int = _target(i)
		var remove_color := Color(0.95, 0.4, 0.4)
		var set_label: String
		var set_color: Color
		if _leveled(i):
			# HAVE: current level (or "--").
			var have: int = Stats.get_powerup_level(powerup.get("id", ""))
			var have_text := "--" if have == 0 else "LV %d" % have
			draw_string(font, Vector2(HAVE_X, y), have_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, PlayerPowerUps.level_color(have) if have > 0 else dim)
			set_label = "NONE" if lvl == 0 else "LV %d" % lvl
			set_color = remove_color if lvl == 0 else PlayerPowerUps.level_color(lvl)
		else:
			# HAVE: how many stacked copies (or "--").
			var copies: int = Stats.count_powerup_copies(powerup.get("id", ""))
			draw_string(font, Vector2(HAVE_X, y), "--" if copies == 0 else "x%d" % copies, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(0.85, 0.87, 0.93) if copies > 0 else dim)
			set_label = "REMOVE" if lvl == 0 else "GIVE"
			set_color = remove_color if lvl == 0 else Color(0.4, 0.9, 0.55)
		# SET, with arrows when highlighted.
		var set_text := ("< %s >" % set_label) if selected else ("  %s" % set_label)
		draw_string(font, Vector2(SET_X - 6, y), set_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, set_color)

	_draw_button(font, _give_rect(), "GIVE", cursor == _give_index(), Color(0.4, 0.85, 0.55))
	_draw_button(font, _back_rect(), "BACK", cursor == _back_index(), Color(0.7, 0.72, 0.8))


func _draw_page_bar(font: Font) -> void:
	"""< GRAY  1/2 >  in the page's type color; highlighted when the cursor
	is on it. Shows how many are ticked on the other pages too."""
	if pages.is_empty():
		return
	var selected := cursor == -1
	var r := _page_bar_rect()
	var color: Color = pages[page]["color"]
	draw_rect(r, Color(1, 1, 1, 0.08) if selected else Color(1, 1, 1, 0.03), true)
	draw_rect(r, color if selected else color.darkened(0.4), false, 1.0)
	var text := "<  %s  %d/%d  >" % [pages[page]["title"], page + 1, pages.size()]
	var ts: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9)
	draw_string(font, Vector2((WIDTH - ts.x) / 2.0, PAGE_BAR_Y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, color.lightened(0.3) if selected else color)
	var ticked := checked_ids.size()
	if ticked > 0:
		draw_string(font, Vector2(r.end.x - 52, PAGE_BAR_Y), "%d ticked" % ticked, HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color(0.4, 0.9, 0.55))


func _draw_button(font: Font, rect: Rect2, label: String, selected: bool, accent: Color) -> void:
	draw_rect(rect, Color(0.12, 0.12, 0.06) if selected else Color(0.06, 0.07, 0.15), true)
	draw_rect(rect, accent if selected else Color(0.4, 0.42, 0.5, 0.7), false, 2.0 if selected else 1.0)
	var text := ("> %s <" % label) if selected else label
	var ts: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9)
	draw_string(font, Vector2(rect.position.x + (rect.size.x - ts.x) / 2.0, rect.position.y + 13), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, accent if selected else Color(0.75, 0.77, 0.85))
