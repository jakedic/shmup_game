# info_card.gd
# Built and owned by GameShell (game_shell.gd) - levels call
# BaseLevel.show_info() instead of touching this directly.
#
# A tutorial / "how to play" card shown over the middle of the play area while
# the game is paused (BaseLevel.show_info() does the pausing):
#
#     +-----------------------+
#     |       MOVEMENT        |   title
#     |   +---------------+   |
#     |   |  looping clip |   |   video (.ogv)
#     |   +---------------+   |
#     |         [W]           |   keys - each one lights up while the
#     |      [A][S][D]        |   player holds it, and/or in time with
#                                     the clip (see "key_timeline")
#     |   optional text...    |   text
#     | +--+   +--+   +--+    |   sections - optional columns side by
#     | |  |   |  |   |  |    |   side, each a small looping clip with
#     | +--+   +--+   +--+    |   its own description under it (see
#     | desc 1 desc 2 desc 3  |   "sections" below)
#     |  Press SPACE to go on |
#     +-----------------------+
#
# Every part is optional except the title. Shoot / start closes it.
extends Control

signal closed

# Which input action lights up each key cap. Add entries here for new keys.
const KEY_ACTIONS := {
	"W": "up", "A": "left", "S": "down", "D": "right",
	"UP": "up", "LEFT": "left", "DOWN": "down", "RIGHT": "right",
	"J": "shoot", "SPACE": "shoot", "K": "absorb", "L": "jump",
	"ENTER": "start", "P": "pause",
}

# --- Look (logical px - the play area is 240x320) ---
const BOX_COLOR := Color(0.05, 0.05, 0.11, 0.96)
const BOX_BORDER_COLOR := Color(0.55, 0.55, 0.8)
const TITLE_COLOR := Color(1.0, 0.85, 0.3)
const TEXT_COLOR := Color(1, 1, 1)
const DIM_COLOR := Color(0, 0, 0, 0.55)
const CARD_WIDTH := 200.0
const TITLE_FONT_SIZE := 16
const TEXT_FONT_SIZE := 8
const PROMPT_FONT_SIZE := 7
const VIDEO_SIZE := Vector2(120, 160)   # 3:4, same shape as the play area
# A card with "sections" is wider so its side-by-side columns get more room
# (the play area is 240 wide). Each column's clip fills the column width at 3:4.
const SECTIONS_CARD_WIDTH := 228.0
const SECTION_GAP := 6.0   # between section columns
const KEY_SIZE := 17.0
const KEY_GAP := 2.0
const KEY_FONT_SIZE := 9
const KEY_COLOR := Color(0.16, 0.16, 0.26)
const KEY_PRESSED_COLOR := Color(1.0, 0.85, 0.3)
const KEY_TEXT_COLOR := Color(1, 1, 1)
const KEY_PRESSED_TEXT_COLOR := Color(0.1, 0.08, 0.02)
const KEY_COOLDOWN_COLOR := Color(0.09, 0.09, 0.14)        # dimmed cap while recharging
const KEY_COOLDOWN_FILL_COLOR := Color(1.0, 0.6, 0.2, 0.85)  # refill, orange like the jump clock
const KEY_COOLDOWN_TEXT_COLOR := Color(0.55, 0.55, 0.65)
const INPUT_GRACE := 0.5   # ignore presses this long after opening (no accidental skips)

var _play_rect := Rect2(0, 0, 240, 320)
var _active := false
var _grace := 0.0
var _blink_t := 0.0
var _key_rows: Array = []   # Array of Array[String]
var _key_timeline: Array = []   # [[key, from, to], ...] in clip seconds
var _key_cooldowns: Array = []  # [[key, from, to], ...] in clip seconds

var _dim: ColorRect
var _panel: PanelContainer
var _title: Label
var _video_frame: PanelContainer
var _video: VideoStreamPlayer
var _keys: Control
var _text: Label
var _sections_box: HBoxContainer
var _section_videos: Array = []   # VideoStreamPlayers in the current sections
var _card_width := CARD_WIDTH     # SECTIONS_CARD_WIDTH while sections are shown
var _prompt: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # runs (and plays the clip) while the game is paused
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	_hide()


## Show a card and wait (as a coroutine) until the player closes it.
## config keys (all optional except "title"):
##   "title" - big heading, e.g. "MOVEMENT"
##   "video" - res:// path to an .ogv clip (loops), or a VideoStream
##   "keys"  - rows of key caps, e.g. [["W"], ["A", "S", "D"]]; see KEY_ACTIONS
##   "text"  - a line or two of explanation under the keys
##   "key_timeline" - when each key is "pressed" in the clip, so the caps
##             light up in sync with the video: a list of [key, from, to] in
##             seconds of the clip, e.g. [["A", 0.3, 0.85], ["D", 1.2, 1.9]]
##   "key_cooldowns" - when a key is recharging in the clip, same
##             [key, from, to] format: the cap dims and refills from the
##             bottom (like the HUD's jump clock) until it's ready again
##   "sections" - columns side by side under the text, each a small
##             looping clip with its own description under it: a list of
##             {"video": ..., "text": ...}, e.g.
##             [{"video": "res://.../a.ogv", "text": "Do this."}, ...]
func show_card(config: Dictionary) -> void:
	if _active:
		await closed   # one card at a time - wait for the current one
	_active = true
	_grace = INPUT_GRACE
	_blink_t = 0.0

	_title.text = str(config.get("title", "")).to_upper()

	var stream = config.get("video", null)
	if stream is String and stream != "":
		stream = load(stream)
	_video_frame.visible = stream is VideoStream
	if stream is VideoStream:
		_video.stream = stream
		_video.play()

	_key_rows = config.get("keys", [])
	_key_timeline = config.get("key_timeline", [])
	_key_cooldowns = config.get("key_cooldowns", [])
	_keys.visible = not _key_rows.is_empty()
	_keys.custom_minimum_size = Vector2(0, _key_rows.size() * (KEY_SIZE + KEY_GAP))

	var text := str(config.get("text", ""))
	_text.text = text
	_text.visible = text != ""

	_clear_sections()
	var sections: Array = config.get("sections", [])
	_card_width = SECTIONS_CARD_WIDTH if not sections.is_empty() else CARD_WIDTH
	for section in sections:
		_add_section(section, sections.size())
	_sections_box.visible = _sections_box.get_child_count() > 0

	_prompt.text = "Press %s to continue" % _key_name("shoot", "SPACE")

	_dim.visible = true
	_panel.visible = true
	_fit()
	await closed


func is_open() -> bool:
	return _active


## Close without waiting for the player (used on scene changes).
func clear() -> void:
	if _active:
		_close()


func set_layout(play_rect: Rect2) -> void:
	_play_rect = play_rect
	_fit()


func _process(delta: float) -> void:
	if not _active:
		return
	_grace = max(_grace - delta, 0.0)
	_blink_t += delta
	_prompt.modulate.a = 1.0 if _grace > 0.0 or fmod(_blink_t, 1.0) < 0.65 else 0.35
	_keys.queue_redraw()   # key caps light up with the live input
	_fit()


func _input(event: InputEvent) -> void:
	if not _active or not event.is_pressed() or event.is_echo():
		return
	if not (event.is_action_pressed("shoot") or event.is_action_pressed("start")):
		return
	get_viewport().set_input_as_handled()
	if _grace <= 0.0:
		_close()


func _close() -> void:
	_active = false
	_video.stop()
	for v in _section_videos:
		if is_instance_valid(v):
			v.stop()
	_hide()
	closed.emit()


func _hide() -> void:
	_dim.visible = false
	_panel.visible = false


func _fit() -> void:
	_dim.position = _play_rect.position
	_dim.size = _play_rect.size
	_text.custom_minimum_size.x = _card_width - 16.0
	_panel.size = Vector2(_card_width, 0)
	_panel.position = _play_rect.position + (_play_rect.size - _panel.size) * 0.5


# ---------------------------------------------------------------------------
# Key caps
# ---------------------------------------------------------------------------

func _draw_keys() -> void:
	var font := ThemeDB.fallback_font
	for r in _key_rows.size():
		var row: Array = _key_rows[r]
		var widths: Array = []
		var total := 0.0
		for k in row:
			var w := _key_width(str(k))
			widths.append(w)
			total += w
		total += KEY_GAP * max(row.size() - 1, 0)
		var x := (_keys.size.x - total) * 0.5
		var y := r * (KEY_SIZE + KEY_GAP)
		for i in row.size():
			var label := str(row[i]).to_upper()
			var rect := Rect2(x, y, widths[i], KEY_SIZE)
			var action: String = KEY_ACTIONS.get(label, "")
			var down := (action != "" and InputMap.has_action(action) and Input.is_action_pressed(action)) \
				or _timeline_has(label)
			var cooldown := -1.0 if down else _cooldown_progress(label)   # 0..1 while recharging
			var cap := StyleBoxFlat.new()
			cap.bg_color = KEY_PRESSED_COLOR if down else (KEY_COOLDOWN_COLOR if cooldown >= 0.0 else KEY_COLOR)
			cap.border_color = BOX_BORDER_COLOR
			cap.set_border_width_all(1)
			cap.border_width_bottom = 1 if down else 3   # "raised" key unless held
			cap.set_corner_radius_all(3)
			_keys.draw_style_box(cap, rect)
			if cooldown >= 0.0:
				# Refill rising from the bottom of the cap.
				var inner := rect.grow(-1.5)
				var h := inner.size.y * cooldown
				_keys.draw_rect(Rect2(inner.position.x, inner.end.y - h, inner.size.x, h), KEY_COOLDOWN_FILL_COLOR)
			var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, KEY_FONT_SIZE)
			var baseline := Vector2(
				rect.position.x + (rect.size.x - text_size.x) * 0.5,
				rect.position.y + (rect.size.y + KEY_FONT_SIZE * 0.7) * 0.5 - (0.0 if down else 1.0))
			var text_color := KEY_TEXT_COLOR
			if down:
				text_color = KEY_PRESSED_TEXT_COLOR
			elif cooldown >= 0.0:
				text_color = KEY_COOLDOWN_TEXT_COLOR
			_keys.draw_string(font, baseline, label, HORIZONTAL_ALIGNMENT_LEFT, -1, KEY_FONT_SIZE, text_color)
			x += widths[i] + KEY_GAP


func _timeline_has(label: String) -> bool:
	"""Is `label` "held" at this moment of the clip (see key_timeline)?"""
	if _key_timeline.is_empty() or not _video.is_playing():
		return false
	var t := _video.stream_position
	for entry in _key_timeline:
		if entry.size() >= 3 and str(entry[0]).to_upper() == label \
				and t >= float(entry[1]) and t < float(entry[2]):
			return true
	return false


func _cooldown_progress(label: String) -> float:
	"""0..1 refill progress if `label` is recharging at this moment of the
	clip (see key_cooldowns), or -1 if it isn't."""
	if _key_cooldowns.is_empty() or not _video.is_playing():
		return -1.0
	var t := _video.stream_position
	for entry in _key_cooldowns:
		if entry.size() >= 3 and str(entry[0]).to_upper() == label:
			var from := float(entry[1])
			var to := float(entry[2])
			if t >= from and t < to and to > from:
				return (t - from) / (to - from)
	return -1.0


func _key_width(label: String) -> float:
	# Longer labels (SPACE, ENTER...) get wider caps.
	return KEY_SIZE if label.length() <= 1 else KEY_SIZE + 6.0 * (label.length() - 1)


func _key_name(action: String, fallback: String) -> String:
	if InputMap.has_action(action):
		for e in InputMap.action_get_events(action):
			if e is InputEventKey:
				var code: int = e.physical_keycode if e.physical_keycode != 0 else e.keycode
				if code != 0:
					return OS.get_keycode_string(code).to_upper()
	return fallback


# ---------------------------------------------------------------------------
# Sections (small clip + description rows)
# ---------------------------------------------------------------------------

func _clear_sections() -> void:
	for v in _section_videos:
		if is_instance_valid(v):
			v.stop()
	_section_videos.clear()
	for c in _sections_box.get_children():
		_sections_box.remove_child(c)
		c.queue_free()


func _add_section(section: Dictionary, count: int) -> void:
	"""One column: clip on top, its description centered underneath."""
	var col_w: float = floor((SECTIONS_CARD_WIDTH - 16.0 - SECTION_GAP * max(count - 1, 0)) / max(count, 1))
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 3)
	col.custom_minimum_size.x = col_w
	_sections_box.add_child(col)

	var stream = section.get("video", null)
	if stream is String and stream != "":
		stream = load(stream)
	if stream is VideoStream:
		var center := CenterContainer.new()
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(center)
		var frame := _make_video_frame()
		center.add_child(frame)
		# Fill the column (minus the 1px frame on each side), 3:4 like the play area.
		var clip_w: float = col_w - 2.0
		var v := _make_video_player(Vector2(clip_w, round(clip_w * 4.0 / 3.0)))
		frame.add_child(v)
		v.stream = stream
		v.play()
		_section_videos.append(v)

	var text := str(section.get("text", ""))
	if text != "":
		var l := _make_label(TEXT_FONT_SIZE, TEXT_COLOR)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.text = text
		col.add_child(l)
		# Give the label its wrapped size up front. An autowrapping Label in a
		# container otherwise reports ~0 height until it has been laid out at
		# its final width, which can leave it squashed to nothing.
		var font: Font = l.get_theme_font("font")
		var text_h: float = font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, col_w, TEXT_FONT_SIZE).y
		l.custom_minimum_size = Vector2(col_w, ceil(text_h) + 2.0)


func _make_video_frame() -> PanelContainer:
	var f := PanelContainer.new()
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(0, 0, 0)
	frame.border_color = BOX_BORDER_COLOR
	frame.set_border_width_all(1)
	frame.content_margin_left = 1
	frame.content_margin_right = 1
	frame.content_margin_top = 1
	frame.content_margin_bottom = 1
	f.add_theme_stylebox_override("panel", frame)
	return f


func _make_video_player(clip_size: Vector2) -> VideoStreamPlayer:
	var v := VideoStreamPlayer.new()
	v.loop = true
	v.expand = true
	v.volume_db = -80.0
	v.custom_minimum_size = clip_size
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	return v


# ---------------------------------------------------------------------------
# Building
# ---------------------------------------------------------------------------

func _make_label(font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


func _build() -> void:
	_dim = ColorRect.new()
	_dim.name = "InfoDim"
	_dim.color = DIM_COLOR
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)

	_panel = PanelContainer.new()
	_panel.name = "InfoCard"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = BOX_COLOR
	box.border_color = BOX_BORDER_COLOR
	box.set_border_width_all(1)
	box.set_corner_radius_all(4)
	box.content_margin_left = 8
	box.content_margin_right = 8
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	_panel.add_theme_stylebox_override("panel", box)
	add_child(_panel)

	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", 5)
	_panel.add_child(vb)

	_title = _make_label(TITLE_FONT_SIZE, TITLE_COLOR)
	vb.add_child(_title)

	# Clip in a thin frame, centered.
	var video_row := CenterContainer.new()
	video_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(video_row)
	_video_frame = PanelContainer.new()
	_video_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(0, 0, 0)
	frame.border_color = BOX_BORDER_COLOR
	frame.set_border_width_all(1)
	frame.content_margin_left = 1
	frame.content_margin_right = 1
	frame.content_margin_top = 1
	frame.content_margin_bottom = 1
	_video_frame.add_theme_stylebox_override("panel", frame)
	video_row.add_child(_video_frame)
	_video = VideoStreamPlayer.new()
	_video.loop = true
	_video.expand = true
	_video.volume_db = -80.0
	_video.custom_minimum_size = VIDEO_SIZE
	_video.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_video.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_video_frame.add_child(_video)

	_keys = Control.new()
	_keys.name = "Keys"
	_keys.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_keys.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_keys.draw.connect(_draw_keys)
	vb.add_child(_keys)

	_text = _make_label(TEXT_FONT_SIZE, TEXT_COLOR)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(_text)

	_sections_box = HBoxContainer.new()
	_sections_box.name = "Sections"
	_sections_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sections_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_sections_box.add_theme_constant_override("separation", int(SECTION_GAP))
	vb.add_child(_sections_box)

	_prompt = _make_label(PROMPT_FONT_SIZE, BOX_BORDER_COLOR)
	vb.add_child(_prompt)
