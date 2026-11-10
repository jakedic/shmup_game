extends Control

## Side-panel row of the leveled power-ups the player has right now. Lives in
## GameShell's LEFT panel, just above the portrait (see game_shell.gd -
## _build_powerup_hud() / _layout()), and redraws whenever a level changes
## (Stats.powerup_levels_changed).
##
## Each power-up is one square:
##   fill   = the power-up's type color (gray for gray power-ups, yellow for
##            yellow ones... - PlayerPowerUps.get_accent_color_for_powerup_id())
##   border = its level: blue (1), red (2), gold (3) - PlayerPowerUps.LEVEL_COLORS
##
## While the game is paused (pause menu up), hovering the mouse over a square
## shows a tooltip with its name, level and what it does. The keyboard can do
## the same: Left/A from the pause menu selects the squares (browse_begin()),
## WASD/arrows move between them (browse_move()) - see pause_menu_keys.gd.
##
## Only leveled power-ups are shown (see PlayerPowerUps "POWER-UP LEVELS"); as
## more power-ups get levels they show up here automatically.

const SQUARE := 16.0       # square size, in shell UI units
const GAP := 4.0           # space between squares
const BORDER := 2.0        # level-color border width
const TOOLTIP_MAX_WIDTH := 150.0  # narrowed to the side panel so it never covers the pause menu
const TOOLTIP_PAD := 5.0
const TOOLTIP_FONT := 8
const TOOLTIP_TITLE_FONT := 9

var _area := Rect2()          # where the squares go, in shell UI coordinates
var _owned: Array = []        # PlayerPowerUps.get_owned_leveled_powerups()
var _rects: Array = []        # Rect2 per entry in _owned
var _hover := -1              # index into _owned under the mouse, -1 = none
var _keyboard_index := -1     # square picked with the keyboard, -1 = not browsing


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS   # hover has to work while paused
	Stats.powerup_levels_changed.connect(_refresh)
	_refresh()


## Rows of squares that fit across `width` - GameShell uses this to know how
## much room to leave above the portrait.
static func columns_for_width(width: float) -> int:
	return maxi(int((width + GAP) / (SQUARE + GAP)), 1)


static func height_for_rows(rows: int) -> float:
	return rows * SQUARE + maxi(rows - 1, 0) * GAP


func set_layout(area: Rect2) -> void:
	"""area = the strip just above the portrait. Squares fill it left to
	right, starting from the BOTTOM row (right above the portrait)."""
	_area = area
	_refresh()


func _refresh() -> void:
	_owned = PlayerPowerUps.get_owned_leveled_powerups()
	_rects.clear()
	var cols := columns_for_width(_area.size.x)
	for i in _owned.size():
		var col := i % cols
		var row := i / cols
		var x := _area.position.x + col * (SQUARE + GAP)
		var y := _area.end.y - SQUARE - row * (SQUARE + GAP)
		_rects.append(Rect2(x, y, SQUARE, SQUARE))
	_hover = -1
	if _keyboard_index >= _owned.size():
		_keyboard_index = _owned.size() - 1
	queue_redraw()


# ---------- Keyboard browsing ----------

func browse_begin() -> bool:
	"""Select the right-most square on the bottom row (the one nearest the
	pause menu). False if there are no squares."""
	if _owned.is_empty():
		return false
	var cols := columns_for_width(_area.size.x)
	_keyboard_index = mini(cols, _owned.size()) - 1
	queue_redraw()
	return true


func browse_move(dir: Vector2i) -> bool:
	"""dir is a screen direction: x -1 left / +1 right, y -1 up / +1 down.
	Returns false when moving right off the end of a row (= leave the
	squares)."""
	if _keyboard_index < 0 or _owned.is_empty():
		return false
	var cols := columns_for_width(_area.size.x)
	var col := _keyboard_index % cols
	var row := _keyboard_index / cols   # row 0 is the BOTTOM row
	var target := _keyboard_index
	if dir.x > 0:
		if col == cols - 1 or _keyboard_index + 1 >= _owned.size():
			browse_end()
			return false
		target += 1
	elif dir.x < 0:
		if col > 0:
			target -= 1
	elif dir.y < 0:   # up = next row
		if _keyboard_index + cols < _owned.size():
			target += cols
	elif dir.y > 0 and row > 0:
		target -= cols
	_keyboard_index = target
	queue_redraw()
	return true


func browse_end() -> void:
	_keyboard_index = -1
	queue_redraw()


func _process(_delta: float) -> void:
	var new_hover := -1
	if _keyboard_index >= 0 and not _is_pause_menu_open():
		_keyboard_index = -1   # menu closed some other way
	if _keyboard_index >= 0:
		new_hover = _keyboard_index
	elif visible and _is_pause_menu_open():
		var mouse := get_local_mouse_position()
		for i in _rects.size():
			if _rects[i].grow(1.0).has_point(mouse):
				new_hover = i
				break
	if new_hover != _hover:
		_hover = new_hover
		queue_redraw()


func _is_pause_menu_open() -> bool:
	var scene: Node = GameShell.current_scene()
	return scene != null and "is_paused" in scene and scene.is_paused


func _draw() -> void:
	for i in _owned.size():
		var powerup: Dictionary = _owned[i]
		var rect: Rect2 = _rects[i]
		var fill: Color = PlayerPowerUps.get_accent_color_for_powerup_id(powerup.get("id", ""))
		if i == _hover:
			fill = fill.lightened(0.3)
		draw_rect(rect, fill, true)
		var border := PlayerPowerUps.level_color(powerup.get("display_level", 0))
		draw_rect(rect.grow(-BORDER / 2.0), border, false, BORDER)
		if i == _keyboard_index:
			draw_rect(rect.grow(2.0), Color(1, 1, 1), false, 1.0)   # keyboard cursor

	if _hover >= 0 and _hover < _owned.size():
		_draw_tooltip(_owned[_hover], _rects[_hover])


func _draw_tooltip(powerup: Dictionary, anchor: Rect2) -> void:
	var font := ThemeDB.fallback_font
	var tooltip_w := minf(TOOLTIP_MAX_WIDTH, maxf(_area.size.x, 80.0))
	var inner_w := tooltip_w - TOOLTIP_PAD * 2.0
	var level: int = powerup.get("display_level", 0)
	var max_level: int = powerup.get("max_level", 1)
	var level_text := "LEVEL %d / %d" % [level, max_level]
	if level >= max_level and max_level > 1:
		level_text += " - MAX"
	var summary: String = powerup.get("level_summary", "")
	var desc: String = powerup.get("description", "")
	var name_text: String = powerup.get("name", "?").to_upper()

	var name_h := font.get_multiline_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, inner_w, TOOLTIP_TITLE_FONT).y
	var line_h := font.get_height(TOOLTIP_FONT)
	var summary_h := font.get_multiline_string_size(summary, HORIZONTAL_ALIGNMENT_LEFT, inner_w, TOOLTIP_FONT).y if summary != "" else 0.0
	var desc_h := font.get_multiline_string_size(desc, HORIZONTAL_ALIGNMENT_LEFT, inner_w, TOOLTIP_FONT).y
	var h := TOOLTIP_PAD * 2.0 + name_h + 4.0 + line_h + summary_h + desc_h + 6.0

	# Above the square if there's room, otherwise below; kept inside the window.
	var pos := Vector2(_area.position.x, anchor.position.y - h - 4.0)
	if pos.y < 2.0:
		pos.y = anchor.end.y + 4.0
	pos.x = clampf(pos.x, 2.0, maxf(size.x - tooltip_w - 2.0, 2.0))
	pos.y = clampf(pos.y, 2.0, maxf(size.y - h - 2.0, 2.0))
	var box := Rect2(pos, Vector2(tooltip_w, h))

	var accent: Color = PlayerPowerUps.get_accent_color_for_powerup_id(powerup.get("id", ""))
	var lvl_color := PlayerPowerUps.level_color(level)
	# Same look as the pickup popup: a title bar in the power-up's TYPE color
	# (gray for gray), the rest of the border in its LEVEL color.
	draw_rect(box, Color(0.05, 0.05, 0.1, 0.95), true)
	var bar := Rect2(box.position, Vector2(box.size.x, TOOLTIP_PAD + name_h + 2.0))
	draw_rect(bar, accent, true)
	draw_rect(box, lvl_color, false, 2.0)
	draw_rect(bar.grow_individual(-2.0, -2.0, -2.0, 0.0), accent, true)   # bar sits inside the border

	var x := box.position.x + TOOLTIP_PAD
	var y := box.position.y + TOOLTIP_PAD
	var luminance := 0.299 * accent.r + 0.587 * accent.g + 0.114 * accent.b
	var name_color := Color(0.08, 0.08, 0.11) if luminance > 0.6 else Color(0.95, 0.95, 0.97)
	draw_multiline_string(font, Vector2(x, y + font.get_ascent(TOOLTIP_TITLE_FONT) - 2.0), name_text, HORIZONTAL_ALIGNMENT_LEFT, inner_w, TOOLTIP_TITLE_FONT, -1, name_color)
	y += name_h + 4.0
	draw_string(font, Vector2(x, y + font.get_ascent(TOOLTIP_FONT)), level_text, HORIZONTAL_ALIGNMENT_LEFT, inner_w, TOOLTIP_FONT, lvl_color)
	y += line_h
	if summary != "":
		draw_multiline_string(font, Vector2(x, y + font.get_ascent(TOOLTIP_FONT)), summary, HORIZONTAL_ALIGNMENT_LEFT, inner_w, TOOLTIP_FONT, -1, Color(1, 1, 1))
		y += summary_h
	y += 6.0
	draw_multiline_string(font, Vector2(x, y + font.get_ascent(TOOLTIP_FONT)), desc, HORIZONTAL_ALIGNMENT_LEFT, inner_w, TOOLTIP_FONT, -1, Color(0.8, 0.82, 0.9))
