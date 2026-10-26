# dialogue_ui.gd
# Built and owned by GameShell (game_shell.gd) - levels never touch this
# directly, they call BaseLevel.say() / BaseLevel.talk() instead (see
# base_level.gd's DIALOGUE section for how to use them in a wave function).
#
# Two kinds of dialogue box:
#
#   SIDE BOX  (say)  - sits in the LEFT side panel, just above the pilot
#                      portrait. Does NOT interrupt gameplay. Text types out,
#                      stays up for a moment, then fades. Several say() calls
#                      in a row queue up and play one after another.
#
#   CHOICE (ask)     - a center-box line with options listed under it. Once
#                      the line has typed out, up/down (or left/right) moves
#                      the cursor and shoot / start picks; ask() returns the
#                      index of the picked option (0 = first).
#
#   CENTER BOX (talk) - sits over the middle of the play area with the game
#                      dimmed behind it, and the game is PAUSED while it's up
#                      (BaseLevel.talk() does the pausing). Text types out;
#                      pressing shoot / start finishes the line, pressing again
#                      goes to the next line, or closes the box after the last.
#
# Both show an optional speaker name above the text, and while a line is up
# the HUD portrait (bottom left) swaps to that line's "portrait" (if it has
# one) - the face in the HUD is whoever is talking. A center-box line's
# portrait wins over a side-box line's while both are up.
extends Control

signal side_line_done(id: int)
signal talk_done

# --- Timing ---
const CHARS_PER_SECOND := 45.0       # typewriter speed, both boxes
const SIDE_MIN_HOLD := 1.5           # side box: seconds it stays up after typing...
const SIDE_HOLD_PER_CHAR := 0.04     # ...plus this much per character
const SIDE_FADE_TIME := 0.3          # side box fade in/out, seconds
const SIDE_GAP := 0.15               # pause between queued side lines
const INPUT_GRACE := 0.25            # center box ignores presses this long after a new line appears

# --- Look (all sizes in logical px - the play area is 240x320) ---
const BOX_COLOR := Color(0.05, 0.05, 0.11, 0.94)
const BOX_BORDER_COLOR := Color(0.55, 0.55, 0.8)
const NAME_COLOR := Color(1.0, 0.85, 0.3)
const TEXT_COLOR := Color(1, 1, 1)
const DIM_COLOR := Color(0, 0, 0, 0.45)
const CHOICE_COLOR := Color(0.75, 0.75, 0.85)   # unselected option
const CHOICE_FONT_SIZE := 9
const SIDE_MAX_WIDTH := 200.0
const SIDE_NAME_FONT_SIZE := 9
const SIDE_TEXT_FONT_SIZE := 8
const CENTER_MARGIN := 10.0          # gap between the center box and the play-area edges
const CENTER_NAME_FONT_SIZE := 10
const CENTER_TEXT_FONT_SIZE := 9

var shell: Node = null   # GameShell - set by it; used for the portrait swap

# Layout rects (set by GameShell._layout() via set_layout()).
var _play_rect := Rect2(0, 0, 240, 320)
var _side_rect := Rect2(0, 0, 100, 200)   # side box sits at the BOTTOM of this

# ---- Side box state ----
var _side_panel: PanelContainer
var _side_name: Label
var _side_text: Label
var _side_queue: Array = []          # pending lines (Dictionaries, see _make_line())
var _side_current = null             # line being shown, or null
var _side_state := ""                # "typing" / "hold" / "fade_out" / "gap"
var _side_t := 0.0
var _side_chars := 0.0
var _next_side_id := 0

# ---- Center box state ----
var _dim: ColorRect
var _center_panel: PanelContainer
var _center_name: Label
var _center_text: Label
var _center_prompt: Control
var _talk_lines: Array = []
var _talk_index := -1
var _talk_active := false
var _center_chars := 0.0
var _center_grace := 0.0
var _prompt_t := 0.0
var _choice_box: VBoxContainer
var _choice_labels: Array[Label] = []
var _choice_index := 0
var _last_choice := -1

var _last_portrait = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # keeps typing/advancing while the game is paused
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_side_box()
	_build_center_box()
	_hide_side()
	_hide_center()


# ---------------------------------------------------------------------------
# Public API (called through GameShell)
# ---------------------------------------------------------------------------

## Queue a line in the side box. Returns (as a coroutine) once that line has
## finished and faded - so `await` it to wait, or don't to keep going.
func say(text: String, options: Dictionary = {}) -> void:
	var line := _make_line(text, options)
	var id := _next_side_id
	_next_side_id += 1
	line["id"] = id
	_side_queue.append(line)
	while true:
		var done_id: int = await side_line_done
		if done_id == id:
			return


## Show the center box for one or more lines. Returns once the player has
## clicked through the last line. Pausing the game is the CALLER's job
## (BaseLevel.talk()). If a talk is already up, these lines are added to the
## end of it.
func talk(lines, options: Dictionary = {}) -> void:
	var entries := _normalize_lines(lines, options)
	if entries.is_empty():
		return
	if _talk_active:
		_talk_lines.append_array(entries)
		await talk_done
		return
	_talk_lines = entries
	_talk_active = true
	_dim.visible = true
	_center_panel.visible = true
	_show_center_line(0)
	await talk_done


## Center box with a question and options. Returns (as a coroutine) the index
## of the option the player picked. Pausing is the caller's job, same as
## talk() (BaseLevel.ask() does it).
func ask(text: String, choices: Array, options: Dictionary = {}) -> int:
	var line := _make_line(text, options)
	var labels: Array = []
	for c in choices:
		labels.append(str(c))
	line["choices"] = labels
	_last_choice = -1
	await talk([line])
	return _last_choice


func is_talking() -> bool:
	return _talk_active


## Drop everything (used on scene changes). Anything awaiting a line is
## released so no coroutine is left hanging.
func clear_all() -> void:
	var ids: Array = []
	if _side_current != null:
		ids.append(_side_current["id"])
	for l in _side_queue:
		ids.append(l["id"])
	_side_queue.clear()
	_side_current = null
	_hide_side()
	for id in ids:
		side_line_done.emit(id)
	if _talk_active:
		_talk_active = false
		_talk_lines.clear()
		_hide_center()
		talk_done.emit()
	_update_portrait()


func set_layout(play_rect: Rect2, side_rect: Rect2) -> void:
	_play_rect = play_rect
	_side_rect = side_rect
	_fit_boxes()


# ---------------------------------------------------------------------------
# Per-frame
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	_process_center(delta)
	# The side box belongs to gameplay - it freezes along with everything
	# else whenever the game is paused (pause menu, center box, absorb...).
	if not get_tree().paused:
		_process_side(delta)
	_fit_boxes()
	_update_portrait()


func _process_side(delta: float) -> void:
	if _side_current == null:
		# Short breather between queued lines.
		if _side_state == "gap" and _side_t < SIDE_GAP:
			_side_t += delta
			return
		if _side_queue.is_empty():
			return
		_side_current = _side_queue.pop_front()
		_side_name.text = _side_current["speaker"]
		_side_name.visible = _side_current["speaker"] != ""
		_side_text.text = _side_current["text"]
		_side_text.visible_characters = 0
		_side_chars = 0.0
		_side_t = 0.0
		_side_state = "typing"
		_side_panel.visible = true
		_side_panel.modulate.a = 0.0

	_side_t += delta
	match _side_state:
		"typing":
			_side_panel.modulate.a = min(_side_t / SIDE_FADE_TIME, 1.0)
			_side_chars += CHARS_PER_SECOND * delta
			var total := _side_text.get_total_character_count()
			if _side_chars >= total:
				_side_text.visible_characters = -1
				_side_state = "hold"
				_side_t = 0.0
			else:
				_side_text.visible_characters = int(_side_chars)
		"hold":
			_side_panel.modulate.a = 1.0
			var hold: float = _side_current["duration"]
			if hold < 0.0:
				hold = SIDE_MIN_HOLD + SIDE_HOLD_PER_CHAR * _side_text.get_total_character_count()
			if _side_t >= hold:
				_side_state = "fade_out"
				_side_t = 0.0
		"fade_out":
			_side_panel.modulate.a = 1.0 - min(_side_t / SIDE_FADE_TIME, 1.0)
			if _side_t >= SIDE_FADE_TIME:
				var id: int = _side_current["id"]
				_side_current = null
				_hide_side()
				_side_state = "gap"
				_side_t = 0.0
				side_line_done.emit(id)


func _process_center(delta: float) -> void:
	if not _talk_active:
		return
	_center_grace = max(_center_grace - delta, 0.0)
	var total := _center_text.get_total_character_count()
	if _center_text.visible_characters != -1:
		_center_chars += CHARS_PER_SECOND * delta
		if _center_chars >= total:
			_center_text.visible_characters = -1
		else:
			_center_text.visible_characters = int(_center_chars)
	# Blinking "next" arrow once the line has fully typed out.
	var done_typing := _center_text.visible_characters == -1
	_prompt_t += delta
	var has_choices := not _choice_labels.is_empty()
	_center_prompt.visible = done_typing and not has_choices and fmod(_prompt_t, 0.8) < 0.5
	if has_choices and done_typing and not _choice_box.visible:
		_choice_box.visible = true
		_refresh_choices()


func _input(event: InputEvent) -> void:
	if not _talk_active:
		return
	if not event.is_pressed() or event.is_echo():
		return
	# Moving the cursor between options (only once they're showing).
	if not _choice_labels.is_empty() and _choice_box.visible:
		var step := 0
		if event.is_action_pressed("up") or event.is_action_pressed("left"):
			step = -1
		elif event.is_action_pressed("down") or event.is_action_pressed("right"):
			step = 1
		if step != 0:
			get_viewport().set_input_as_handled()
			_choice_index = wrapi(_choice_index + step, 0, _choice_labels.size())
			_refresh_choices()
			return
	var advance := event.is_action_pressed("shoot") or event.is_action_pressed("start")
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		advance = true
	if not advance:
		return
	get_viewport().set_input_as_handled()
	if _center_grace > 0.0:
		return
	if _center_text.visible_characters != -1:
		# Still typing - finish the line instantly.
		_center_text.visible_characters = -1
		_prompt_t = 0.0
		return
	if not _choice_labels.is_empty():
		_last_choice = _choice_index   # this press picks the highlighted option
	if _talk_index + 1 < _talk_lines.size():
		_show_center_line(_talk_index + 1)
	else:
		_talk_active = false
		_talk_lines.clear()
		_hide_center()
		_update_portrait()
		talk_done.emit()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _show_center_line(index: int) -> void:
	_talk_index = index
	var line: Dictionary = _talk_lines[index]
	_center_name.text = line["speaker"]
	_center_name.visible = line["speaker"] != ""
	_center_text.text = line["text"]
	_center_text.visible_characters = 0
	_center_chars = 0.0
	_center_grace = INPUT_GRACE
	_prompt_t = 0.0
	_center_prompt.visible = false
	_build_choices(line.get("choices", []))


func _build_choices(choices: Array) -> void:
	for l in _choice_labels:
		l.queue_free()
	_choice_labels.clear()
	_choice_index = 0
	_choice_box.visible = false   # shown once the question has typed out
	for c in choices:
		var l := _make_label(CHOICE_FONT_SIZE, CHOICE_COLOR, true)
		_choice_box.add_child(l)
		_choice_labels.append(l)
		l.set_meta("choice_text", str(c))
	_refresh_choices()


func _refresh_choices() -> void:
	for i in _choice_labels.size():
		var l: Label = _choice_labels[i]
		var selected := i == _choice_index
		l.text = ("> " if selected else "   ") + str(l.get_meta("choice_text"))
		l.add_theme_color_override("font_color", NAME_COLOR if selected else CHOICE_COLOR)


func _normalize_lines(lines, options: Dictionary) -> Array:
	var out: Array = []
	if lines is String:
		lines = [lines]
	if not (lines is Array):
		push_error("talk(): expected a String or an Array of lines, got %s" % [lines])
		return out
	for entry in lines:
		if entry is String:
			out.append(_make_line(entry, options))
		elif entry is Dictionary and entry.has("choices") and entry.has("duration"):
			out.append(entry)   # already a finished line (from ask())
		elif entry is Dictionary:
			var merged := options.duplicate()
			merged.merge(entry, true)
			out.append(_make_line(str(merged.get("text", "")), merged))
		else:
			push_error("talk(): each line must be a String or a Dictionary, got %s" % [entry])
	return out


func _make_line(text: String, options: Dictionary) -> Dictionary:
	var portrait = options.get("portrait", null)
	if shell and shell.has_method("make_portrait_texture"):
		portrait = shell.make_portrait_texture(portrait)
	return {
		"text": text,
		"speaker": str(options.get("speaker", "")),
		"portrait": portrait,
		"duration": float(options.get("duration", -1.0)),
		"choices": [],
	}


func _update_portrait() -> void:
	var want = null
	if _talk_active and _talk_index >= 0 and _talk_index < _talk_lines.size():
		want = _talk_lines[_talk_index]["portrait"]
	elif _side_current != null:
		want = _side_current["portrait"]
	if want == _last_portrait:
		return
	_last_portrait = want
	if shell and shell.has_method("set_portrait_override"):
		shell.set_portrait_override(want)


func _hide_side() -> void:
	if _side_panel:
		_side_panel.visible = false


func _hide_center() -> void:
	_talk_index = -1
	if _choice_box:
		_build_choices([])
	if _dim:
		_dim.visible = false
	if _center_panel:
		_center_panel.visible = false


func _fit_boxes() -> void:
	# Side box: full width of its area (capped), bottom-aligned just above the
	# portrait. Shrinking size to 0 height lets the container grow back to
	# exactly fit its text.
	if _side_panel:
		var w: float = min(_side_rect.size.x, SIDE_MAX_WIDTH)
		_side_text.custom_minimum_size.x = max(w - 12.0, 10.0)
		_side_panel.size = Vector2(w, 0)
		_side_panel.position = Vector2(
			_side_rect.position.x + (_side_rect.size.x - w) * 0.5,
			_side_rect.end.y - _side_panel.size.y)
	# Center box: centered over the play area.
	if _dim:
		_dim.position = _play_rect.position
		_dim.size = _play_rect.size
	if _center_panel:
		var cw: float = _play_rect.size.x - CENTER_MARGIN * 2.0
		_center_text.custom_minimum_size.x = cw - 14.0
		_center_panel.size = Vector2(cw, 0)
		_center_panel.position = Vector2(
			_play_rect.position.x + CENTER_MARGIN,
			_play_rect.position.y + (_play_rect.size.y - _center_panel.size.y) * 0.5)


func _make_box_style(margin_x: float, margin_y: float) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = BOX_COLOR
	s.border_color = BOX_BORDER_COLOR
	s.set_border_width_all(1)
	s.set_corner_radius_all(3)
	s.content_margin_left = margin_x
	s.content_margin_right = margin_x
	s.content_margin_top = margin_y
	s.content_margin_bottom = margin_y
	return s


func _make_label(font_size: int, color: Color, wrap: bool) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Lay out the WHOLE line up front, so the box is already its final size
	# while the text types out (instead of growing a line at a time).
	l.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	return l


func _build_side_box() -> void:
	_side_panel = PanelContainer.new()
	_side_panel.name = "SideDialogue"
	_side_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_side_panel.add_theme_stylebox_override("panel", _make_box_style(6, 4))
	add_child(_side_panel)
	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", 1)
	_side_panel.add_child(vb)
	_side_name = _make_label(SIDE_NAME_FONT_SIZE, NAME_COLOR, false)
	vb.add_child(_side_name)
	_side_text = _make_label(SIDE_TEXT_FONT_SIZE, TEXT_COLOR, true)
	vb.add_child(_side_text)


func _build_center_box() -> void:
	_dim = ColorRect.new()
	_dim.name = "DialogueDim"
	_dim.color = DIM_COLOR
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)

	_center_panel = PanelContainer.new()
	_center_panel.name = "CenterDialogue"
	_center_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_center_panel.add_theme_stylebox_override("panel", _make_box_style(7, 6))
	add_child(_center_panel)
	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", 2)
	_center_panel.add_child(vb)
	_center_name = _make_label(CENTER_NAME_FONT_SIZE, NAME_COLOR, false)
	vb.add_child(_center_name)
	_center_text = _make_label(CENTER_TEXT_FONT_SIZE, TEXT_COLOR, true)
	vb.add_child(_center_text)
	_choice_box = VBoxContainer.new()
	_choice_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_choice_box.add_theme_constant_override("separation", 0)
	vb.add_child(_choice_box)

	# Little blinking "next" triangle in the bottom-right corner.
	var row := Control.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.custom_minimum_size = Vector2(0, 5)
	vb.add_child(row)
	_center_prompt = Control.new()
	_center_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_center_prompt.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.add_child(_center_prompt)
	_center_prompt.draw.connect(_draw_prompt)


func _draw_prompt() -> void:
	var x := _center_prompt.size.x - 2.0
	_center_prompt.draw_colored_polygon(PackedVector2Array([
		Vector2(x - 6, 0), Vector2(x, 0), Vector2(x - 3, 4)]), NAME_COLOR)
