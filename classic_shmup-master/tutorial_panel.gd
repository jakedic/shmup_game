# tutorial_panel.gd
# Built and owned by GameShell (game_shell.gd), like dialogue_ui.gd - levels
# never touch it directly, they call GameShell.set_tutorial_panel() /
# GameShell.clear_tutorial_panel() (levels/tutorial.gd does this through its
# begin_challenge() helper).
#
# A box at the TOP of the RIGHT side panel (above the score/life stats box)
# with:
#
#   TITLE                     <- yellow, e.g. "SHOOT"
#   instruction text          <- what the current tutorial card taught
#   ---------------------
#   CHALLENGE
#   [ ] challenge text (3/10) <- checkbox: empty while in progress, green
#                                check once done, red X if failed (with a
#                                "wave will repeat" note under it)
#
# Hidden whenever there's nothing set. Cleared on every scene change.
extends Control

enum State { PENDING, DONE, FAILED }

const BOX_COLOR := Color(0.05, 0.05, 0.11, 0.94)
const BOX_BORDER_COLOR := Color(0.55, 0.55, 0.8)
const TITLE_COLOR := Color(1.0, 0.85, 0.3)
const TEXT_COLOR := Color(1, 1, 1)
const CAPTION_COLOR := Color(0.55, 0.55, 0.8)
const DONE_COLOR := Color(0.35, 0.95, 0.45)
const FAILED_COLOR := Color(1.0, 0.35, 0.3)
const PENDING_BOX_COLOR := Color(0.85, 0.85, 0.95)

const MAX_WIDTH := 200.0
const TITLE_FONT_SIZE := 9
const TEXT_FONT_SIZE := 8
const CAPTION_FONT_SIZE := 7
const NOTE_FONT_SIZE := 7
const CHECKBOX_SIZE := 9.0
const CHECK_POP_TIME := 0.25      # checkbox "pop" when it gets ticked / crossed
const CHECK_POP_SCALE := 1.6
const FAILED_NOTE := "Wave will repeat"
const FADE_IN_TIME := 0.5         # fade_in(): seconds to fade from invisible to full
const FADE_IN_SLIDE := 10.0       # fade_in(): px it slides in from the right while fading

var _area := Rect2(0, 0, 100, 200)   # set by GameShell._layout()

var _panel: PanelContainer
var _title: Label
var _text: Label
var _divider: ColorRect
var _caption: Label
var _row: HBoxContainer
var _checkbox: Control
var _challenge: Label
var _note: Label

var _state := State.PENDING
var _has_challenge := false
var _pop_t := 999.0
var _fade_t := 999.0   # time into the current fade_in() (>= FADE_IN_TIME = done)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	clear()


## title / text: the instruction block. challenge: "" = no challenge row.
## progress: shown after the challenge text, e.g. "3/10" ("" = none).
func set_content(title: String, text: String, challenge: String, progress: String, state: int) -> void:
	_title.text = title.to_upper()
	_title.visible = title != ""
	_text.text = text
	_text.visible = text != ""
	_has_challenge = challenge != ""
	_divider.visible = _has_challenge and (title != "" or text != "")
	_caption.visible = _has_challenge
	_row.visible = _has_challenge
	_challenge.text = challenge + ("  (%s)" % progress if progress != "" else "")
	if state != _state:
		_pop_t = 0.0 if state != State.PENDING else 999.0
	_state = state
	_note.visible = _has_challenge and _state == State.FAILED
	var c := TEXT_COLOR
	if _state == State.DONE:
		c = DONE_COLOR
	elif _state == State.FAILED:
		c = FAILED_COLOR
	_challenge.add_theme_color_override("font_color", c)
	_panel.visible = _title.visible or _text.visible or _has_challenge
	_checkbox.queue_redraw()
	_fit()


## Fade (and slide) the panel in from nothing. Call right after set_content().
func fade_in() -> void:
	_fade_t = 0.0
	_apply_fade()


func clear() -> void:
	_state = State.PENDING
	_has_challenge = false
	_fade_t = 999.0
	if _panel:
		_panel.visible = false
		_panel.modulate.a = 1.0


func _apply_fade() -> void:
	var k := clampf(_fade_t / FADE_IN_TIME, 0.0, 1.0)
	_panel.modulate.a = k * k * (3.0 - 2.0 * k)   # smoothstep


func set_layout(area: Rect2) -> void:
	_area = area
	_fit()


func _process(delta: float) -> void:
	if _pop_t < CHECK_POP_TIME:
		_pop_t += delta
		_checkbox.queue_redraw()
	if _fade_t < FADE_IN_TIME:
		_fade_t += delta
		_apply_fade()
	_fit()


func _fit() -> void:
	if not _panel:
		return
	var w: float = min(_area.size.x, MAX_WIDTH)
	var inner: float = max(w - 14.0, 10.0)
	_title.custom_minimum_size.x = inner
	_text.custom_minimum_size.x = inner
	_challenge.custom_minimum_size.x = max(inner - CHECKBOX_SIZE - 4.0, 10.0)
	# Shrink to 0 height so the container grows back to exactly fit its text.
	_panel.size = Vector2(w, 0)
	var slide := 0.0
	if _fade_t < FADE_IN_TIME:
		var k := _fade_t / FADE_IN_TIME
		slide = FADE_IN_SLIDE * (1.0 - k) * (1.0 - k)
	_panel.position = Vector2(_area.position.x + (_area.size.x - w) * 0.5 + slide, _area.position.y)


# ---------------------------------------------------------------------------
# Building
# ---------------------------------------------------------------------------

func _make_label(font_size: int, color: Color, wrap: bool) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.name = "TutorialPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := StyleBoxFlat.new()
	s.bg_color = BOX_COLOR
	s.border_color = BOX_BORDER_COLOR
	s.set_border_width_all(1)
	s.set_corner_radius_all(3)
	s.content_margin_left = 7
	s.content_margin_right = 7
	s.content_margin_top = 5
	s.content_margin_bottom = 6
	_panel.add_theme_stylebox_override("panel", s)
	add_child(_panel)

	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", 2)
	_panel.add_child(vb)

	_title = _make_label(TITLE_FONT_SIZE, TITLE_COLOR, true)
	vb.add_child(_title)
	_text = _make_label(TEXT_FONT_SIZE, TEXT_COLOR, true)
	vb.add_child(_text)

	_divider = ColorRect.new()
	_divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_divider.color = Color(BOX_BORDER_COLOR, 0.5)
	_divider.custom_minimum_size = Vector2(0, 1)
	vb.add_child(_divider)

	_caption = _make_label(CAPTION_FONT_SIZE, CAPTION_COLOR, false)
	_caption.text = "CHALLENGE"
	vb.add_child(_caption)

	_row = HBoxContainer.new()
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_theme_constant_override("separation", 4)
	vb.add_child(_row)

	_checkbox = Control.new()
	_checkbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_checkbox.custom_minimum_size = Vector2(CHECKBOX_SIZE, CHECKBOX_SIZE)
	_checkbox.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_checkbox.draw.connect(_draw_checkbox)
	_row.add_child(_checkbox)

	_challenge = _make_label(TEXT_FONT_SIZE, TEXT_COLOR, true)
	_challenge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_row.add_child(_challenge)

	_note = _make_label(NOTE_FONT_SIZE, FAILED_COLOR, false)
	_note.text = FAILED_NOTE
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vb.add_child(_note)


func _draw_checkbox() -> void:
	var sz := CHECKBOX_SIZE
	# Little pop when the state changes: grows then settles back.
	var k := 1.0
	if _pop_t < CHECK_POP_TIME:
		var p := _pop_t / CHECK_POP_TIME
		k = lerpf(CHECK_POP_SCALE, 1.0, p * p)
	var c := Vector2(sz, sz) * 0.5 + Vector2(0, 1)
	var half := sz * 0.5 * k
	var r := Rect2(c - Vector2(half, half), Vector2(half, half) * 2.0)
	match _state:
		State.DONE:
			_checkbox.draw_rect(r, Color(DONE_COLOR, 0.25), true)
			_checkbox.draw_rect(r, DONE_COLOR, false, 1.0)
			_checkbox.draw_polyline(PackedVector2Array([
				c + Vector2(-0.55, 0.0) * half,
				c + Vector2(-0.15, 0.45) * half,
				c + Vector2(0.6, -0.5) * half,
			]), DONE_COLOR, 1.5)
		State.FAILED:
			_checkbox.draw_rect(r, Color(FAILED_COLOR, 0.2), true)
			_checkbox.draw_rect(r, FAILED_COLOR, false, 1.0)
			var d := half * 0.55
			_checkbox.draw_line(c + Vector2(-d, -d), c + Vector2(d, d), FAILED_COLOR, 1.5)
			_checkbox.draw_line(c + Vector2(d, -d), c + Vector2(-d, d), FAILED_COLOR, 1.5)
		_:
			_checkbox.draw_rect(r, PENDING_BOX_COLOR, false, 1.0)
