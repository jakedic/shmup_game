# game_shell.gd
# Autoload (registered as "GameShell" in project.godot).
#
# Wraps the whole game in a fixed 240x320 play area centered in a wider
# window, with the HUD (score / multiplier / shield) living in side panels
# to the left and right of the play area instead of overlapping its bottom.
#
# How it works:
#   - The root window is wider than the play area (project viewport is
#     480x320 with aspect "expand", so wider laptop screens just get wider
#     side panels).
#   - Every game scene (title, overworld, levels, shop...) runs inside a
#     SubViewport whose *logical* size is exactly 240x320
#     (size_2d_override), so get_viewport_rect(), VisibleOnScreenNotifier2D,
#     cameras, spawn positions etc. all behave exactly as before. The
#     SubViewport is rendered at the window's real resolution (same crispness
#     as the old "canvas_items" stretch), then scaled down into the 240x320
#     slot.
#   - Because of that, scenes must be changed with GameShell.change_scene()
#     (not get_tree().change_scene_to_file()), and anything that used to be
#     added to get_tree().root (bullets, effects...) must be added to
#     GameShell.game_root() instead so it lives in the same world as the level.
#   - Levels still contain their own CanvasLayer/UI node (ui.gd); it now hides
#     itself and forwards its updates to the side-panel HUD here.
#   - HUD layout: the HUD art (Art assets/Hud assets) is split in two. Left
#     panel = the portrait window with the pilot's face; right panel = the
#     stats box with score, life (shield), multiplier + multiplier bar
#     (multiplier_bar.gd) and the round jump-cooldown clock (jump_indicator.gd). Both sit at the bottom of the play area.
extends CanvasLayer

const PLAY_SIZE := Vector2(240, 320)

const PANEL_COLOR := Color(0.035, 0.035, 0.07)
const BORDER_COLOR := Color(0.28, 0.28, 0.42)
const MULTIPLIER_BAR_SCRIPT := preload("res://multiplier_bar.gd")
const JUMP_INDICATOR_SCRIPT := preload("res://jump_indicator.gd")

# HUD art (Art assets/Hud assets). All sheets are 2048x2048 and drawn on the
# same canvas. Hud_Asset.png holds two pieces that are used separately:
#   - the portrait window (left panel), with the pilot portrait sheet drawn
#     over it using the same region so the face lines up inside the window;
#   - the stats box with "Score:" / "Life:" printed on it (right panel).
const HUD_FRAME_TEXTURE := "res://Art assets/Hud assets/Hud_Asset.png"
const PORTRAIT_NEUTRAL_TEXTURE := "res://Art assets/Hud assets/Player_Neutral_Asset.png"
const PORTRAIT_NERVOUS_TEXTURE := "res://Art assets/Hud assets/Player_Nervous_asset.png"
# When the player is hit: the portrait swaps to the nervous face for the whole
# hit-invincibility window (duration passed in by PlayerHealth), and the
# portrait frame shakes for PORTRAIT_SHAKE_DURATION.
const PORTRAIT_SHAKE_DURATION := 0.35
const PORTRAIT_SHAKE_STRENGTH := 22.0   # art px (the frame is ~341 art px wide)
const PORTRAIT_REGION := Rect2(0, 1695, 341, 351)
const STATS_BOX_REGION := Rect2(346, 1695, 521, 329)

# How big the two pieces get: they fill their side panel's width (minus
# HUD_MARGIN each side) up to these caps, and sit at the bottom of the play
# area.
const HUD_MARGIN := 6.0
const PORTRAIT_MAX_WIDTH := 200.0
const STATS_BOX_MAX_WIDTH := 260.0

# Everything inside the stats box is laid out in the art's own pixels
# (relative to STATS_BOX_REGION). The printed "Score:" text spans y 15-39 and
# "Life:" y 118-144, both starting at x ~13. The box is drawn as a nine-patch
# so it can be made taller than the original art: only the plain strip below
# the "Life:" row (STATS_BOX_PATCH_TOP .. height - STATS_BOX_PATCH_EDGE)
# stretches, which makes room for the multiplier row and bar.
const STATS_BOX_PATCH_TOP := 230
const STATS_BOX_PATCH_EDGE := 12
const STATS_BOX_HEIGHT := 380.0
const STATS_CONTENT_X := 16.0
const STATS_CONTENT_RIGHT := 496.0       # right edge of the content area
const SCORE_DIGITS_POS := Vector2(STATS_CONTENT_X, 50)
const SCORE_DIGITS_SCALE := 5.5          # 8px digits -> 44 art px tall
# Left column (jump clock, multiplier value) sits to the left of the bars.
const STATS_LEFT_COLUMN_W := 88.0
const STATS_BAR_X := STATS_CONTENT_RIGHT - 77.0 * 5.0   # bars are 77 units x5 wide
# Life row: round jump-cooldown clock (jump_indicator.gd) on the left with
# "READY" drawn on it, shield bar to its right.
const LIFE_BAR_POS := Vector2(STATS_BAR_X, 156)
const LIFE_BAR_SIZE := Vector2(77, 12)
const LIFE_BAR_SCALE := 5.0
const JUMP_CLOCK_SIZE := 72.0
# Nudged down from the life bar's centre so the dial clears the printed
# "Life:" text above it (which ends at y 144).
const JUMP_CLOCK_Y_OFFSET := 6.0
const JUMP_STATUS_FONT_SIZE := 18
# Multiplier row: "Multiplier:" caption, then the "2x" value on the left
# with the bar to its right.
const MULT_LABEL_POS := Vector2(13, 236)  # "Multiplier:" caption
const MULT_LABEL_FONT_SIZE := 30
const MULT_VALUE_FONT_SIZE := 52
const MULT_BAR_POS := Vector2(STATS_BAR_X, 280)
const MULT_BAR_SIZE := Vector2(77, 16)
const MULT_BAR_SCALE := 5.0
const STATS_TEXT_COLOR := Color(1, 1, 1)

# All shell UI hangs off this full-window Control. The shell is a CanvasLayer
# so a Camera2D that briefly lands on the root (see _adopt_startup_scene())
# can never shift the side panels.
var _ui: Control
var _container: SubViewportContainer
var _viewport: SubViewport
var _current_scene: Node = null

var _left_panel: ColorRect
var _right_panel: ColorRect
var _border: ReferenceRect

# HUD widgets
var _portrait_frame: Control   # left panel: portrait window + face
var _stats_box: Control        # right panel: score / life / multiplier box
var _portrait: TextureRect
var _portrait_shake_root: Control   # holds window + face; this is what shakes
var _portrait_neutral_tex: Texture2D
var _portrait_nervous_tex: Texture2D
var _portrait_shake_tween: Tween = null
var _hit_id := 0   # bumps on every hit so an older hit's timer can't reset a newer one
var _multiplier_bar: Control
var _score_counter: Node
var _multiplier_label: Label
var _shield_bar: TextureProgressBar
var _hud_users := 0


func _ready() -> void:
	# The shell itself (and the container that forwards input into the game)
	# must keep running while the tree is paused, otherwise the pause menu /
	# popups inside the game would never receive input. The SubViewport is
	# explicitly PAUSABLE so everything *inside* it pauses exactly like it
	# did when it lived directly under the root.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ui = Control.new()
	_ui.name = "ShellUI"
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ui)

	_build_panels()
	_build_game_viewport()
	_build_hud()
	_set_hud_visible(false)

	get_tree().root.size_changed.connect(_layout)
	_layout()

	# Whatever scene Godot loads at startup (the main scene, or the scene
	# being run with F6 in the editor) gets added directly to the root, after
	# the autoloads. Re-load it inside the play-area viewport instead.
	get_tree().root.child_entered_tree.connect(_on_root_child_entered)
	_adopt_startup_scene.call_deferred()


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Drop-in replacement for get_tree().change_scene_to_file(). Deferred to the
## end of the frame, same as the built-in.
func change_scene(path: String) -> void:
	_do_change_scene.call_deferred(path)


## Node that bullets / effects / anything that used to go on
## get_tree().root should be added to, so they share the level's world.
func game_root() -> Node:
	if _viewport:
		return _viewport
	return get_tree().root


## The scene currently shown in the play area.
func current_scene() -> Node:
	return _current_scene


# --- HUD (called by ui.gd) ---

func hud_attach() -> void:
	_hud_users += 1
	_set_hud_visible(true)
	update_score(0)
	update_score_multiplier(1)
	update_multiplier_progress(0, 5, false)
	_hit_id += 1
	_reset_portrait()


func hud_detach() -> void:
	_hud_users = max(_hud_users - 1, 0)
	if _hud_users == 0:
		_set_hud_visible(false)
		set_multiplier_timer(null)


func update_score(value) -> void:
	if _score_counter:
		_score_counter.display_digits(value)


func update_shield(max_value, value) -> void:
	if _shield_bar:
		_shield_bar.max_value = max_value
		_shield_bar.value = value


func update_score_multiplier(value) -> void:
	if _multiplier_label:
		_multiplier_label.text = str(value) + "x"


## Called by PlayerHealth.take_damage() when the player gets hit: nervous
## face for `nervous_duration` seconds (the hit-invincibility window), and a
## short shake of the portrait frame.
func on_player_hit(nervous_duration: float) -> void:
	_hit_id += 1
	var my_hit := _hit_id
	if _portrait:
		_portrait.texture = _portrait_nervous_tex
	_shake_portrait()
	# process_always = false: pausing the game pauses the countdown too,
	# same as the player's own invincibility timer.
	await get_tree().create_timer(nervous_duration, false).timeout
	if my_hit == _hit_id:
		_reset_portrait()


func _shake_portrait() -> void:
	if not _portrait_shake_root:
		return
	if is_instance_valid(_portrait_shake_tween):
		_portrait_shake_tween.kill()
	_portrait_shake_root.position = Vector2.ZERO
	var tween := create_tween()
	var steps := 7
	var step_time := PORTRAIT_SHAKE_DURATION / float(steps + 1)
	for i in steps:
		# Random jolts that die down over the shake.
		var falloff := 1.0 - float(i) / float(steps)
		var offset := Vector2(randf_range(-1.0, 1.0), randf_range(-0.6, 0.6)) * PORTRAIT_SHAKE_STRENGTH * falloff
		tween.tween_property(_portrait_shake_root, "position", offset, step_time)
	tween.tween_property(_portrait_shake_root, "position", Vector2.ZERO, step_time)
	_portrait_shake_tween = tween


func _reset_portrait() -> void:
	if is_instance_valid(_portrait_shake_tween):
		_portrait_shake_tween.kill()
	if _portrait_shake_root:
		_portrait_shake_root.position = Vector2.ZERO
	if _portrait:
		_portrait.texture = _portrait_neutral_tex


## kills: kills counted toward the next multiplier; kills_needed: how many it
## takes; at_max: the multiplier can't go any higher.
func update_multiplier_progress(kills: int, kills_needed: int, at_max: bool) -> void:
	if _multiplier_bar:
		_multiplier_bar.set_progress(kills, kills_needed, at_max)


## The level's multiplier decay Timer - the bar reads it every frame to show
## how long until the multiplier drops.
func set_multiplier_timer(timer: Timer) -> void:
	if _multiplier_bar:
		_multiplier_bar.set_decay_timer(timer)


# ---------------------------------------------------------------------------
# Scene handling
# ---------------------------------------------------------------------------

func _on_root_child_entered(_node: Node) -> void:
	_adopt_startup_scene.call_deferred()


func _adopt_startup_scene() -> void:
	var root := get_tree().root
	var startup := get_tree().current_scene
	if startup == null or startup == self or startup.get_parent() != root:
		return
	if root.child_entered_tree.is_connected(_on_root_child_entered):
		root.child_entered_tree.disconnect(_on_root_child_entered)
	var path := startup.scene_file_path
	get_tree().current_scene = null
	root.remove_child(startup)
	startup.queue_free()
	# If the startup scene had a Camera2D it was briefly the root's camera;
	# make sure it doesn't leave the root canvas offset.
	root.canvas_transform = Transform2D.IDENTITY
	if path != "":
		_do_change_scene(path)


func _do_change_scene(path: String) -> void:
	# Free the old scene AND anything else that was spawned into the play
	# area (bullets, effects...), so nothing carries over between scenes.
	for child in _viewport.get_children():
		_viewport.remove_child(child)
		child.queue_free()
	_current_scene = null

	var packed := load(path) as PackedScene
	if packed == null:
		push_error("GameShell: could not load scene '%s'" % path)
		return
	_current_scene = packed.instantiate()
	_viewport.add_child(_current_scene)


# ---------------------------------------------------------------------------
# Building the layout
# ---------------------------------------------------------------------------

func _build_panels() -> void:
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.color = PANEL_COLOR
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(bg)

	_left_panel = ColorRect.new()
	_left_panel.name = "LeftPanel"
	_left_panel.color = PANEL_COLOR
	_left_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_left_panel)

	_right_panel = ColorRect.new()
	_right_panel.name = "RightPanel"
	_right_panel.color = PANEL_COLOR
	_right_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_right_panel)


func _build_game_viewport() -> void:
	_container = SubViewportContainer.new()
	_container.name = "GameViewportContainer"
	_container.stretch = false
	_container.process_mode = Node.PROCESS_MODE_ALWAYS
	_container.mouse_filter = Control.MOUSE_FILTER_STOP
	_ui.add_child(_container)

	_viewport = SubViewport.new()
	_viewport.name = "GameViewport"
	_viewport.process_mode = Node.PROCESS_MODE_PAUSABLE
	_viewport.handle_input_locally = true
	_viewport.size_2d_override = Vector2i(PLAY_SIZE)
	_viewport.size_2d_override_stretch = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_viewport.audio_listener_enable_2d = true
	_container.add_child(_viewport)

	# Thin frame around the play area.
	_border = ReferenceRect.new()
	_border.name = "PlayAreaBorder"
	_border.border_color = BORDER_COLOR
	_border.border_width = 1.0
	_border.editor_only = false
	_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_border)


func _build_hud() -> void:
	# Both pieces are laid out in art pixels and scaled as a whole in _layout().

	# ---- Left panel: portrait window + pilot face ----
	_portrait_frame = Control.new()
	_portrait_frame.name = "PortraitFrame"
	_portrait_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait_frame.size = PORTRAIT_REGION.size
	_left_panel.add_child(_portrait_frame)
	_portrait_shake_root = Control.new()
	_portrait_shake_root.name = "ShakeRoot"
	_portrait_shake_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait_shake_root.size = PORTRAIT_REGION.size
	_portrait_frame.add_child(_portrait_shake_root)
	_portrait_shake_root.add_child(_make_art_rect("PortraitWindow", HUD_FRAME_TEXTURE, PORTRAIT_REGION))
	_portrait = _make_art_rect("Portrait", PORTRAIT_NEUTRAL_TEXTURE, PORTRAIT_REGION)
	_portrait_neutral_tex = _portrait.texture
	var nervous_atlas := AtlasTexture.new()
	nervous_atlas.atlas = load(PORTRAIT_NERVOUS_TEXTURE)
	nervous_atlas.region = PORTRAIT_REGION
	_portrait_nervous_tex = nervous_atlas
	_portrait_shake_root.add_child(_portrait)

	# ---- Right panel: stats box (score, life, multiplier + bar) ----
	_stats_box = Control.new()
	_stats_box.name = "StatsBox"
	_stats_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stats_box.size = Vector2(STATS_BOX_REGION.size.x, STATS_BOX_HEIGHT)
	_right_panel.add_child(_stats_box)

	var box_atlas := load(HUD_FRAME_TEXTURE)
	var box := NinePatchRect.new()
	box.name = "BoxArt"
	box.texture = box_atlas
	box.region_rect = STATS_BOX_REGION
	box.patch_margin_left = STATS_BOX_PATCH_EDGE
	box.patch_margin_right = STATS_BOX_PATCH_EDGE
	box.patch_margin_bottom = STATS_BOX_PATCH_EDGE
	box.patch_margin_top = STATS_BOX_PATCH_TOP
	box.size = _stats_box.size
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_stats_box.add_child(box)

	# Score digits under the printed "Score:".
	var score_scene := load("res://score_counter.tscn") as PackedScene
	_score_counter = score_scene.instantiate()
	_score_counter.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_score_counter.grow_horizontal = Control.GROW_DIRECTION_END
	_score_counter.alignment = BoxContainer.ALIGNMENT_BEGIN
	_score_counter.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_score_counter.size = Vector2.ZERO  # shrink to its digits
	_score_counter.position = SCORE_DIGITS_POS
	_score_counter.scale = Vector2.ONE * SCORE_DIGITS_SCALE
	_stats_box.add_child(_score_counter)

	# Shield bar under the printed "Life:".
	_shield_bar = TextureProgressBar.new()
	_shield_bar.name = "ShieldBar"
	_shield_bar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_shield_bar.size = LIFE_BAR_SIZE
	_shield_bar.position = LIFE_BAR_POS
	_shield_bar.scale = Vector2.ONE * LIFE_BAR_SCALE
	_shield_bar.value = 10.0
	_shield_bar.nine_patch_stretch = true
	_shield_bar.stretch_margin_left = 3
	_shield_bar.stretch_margin_top = 3
	_shield_bar.stretch_margin_right = 3
	_shield_bar.stretch_margin_bottom = 3
	_shield_bar.texture_under = load("res://bar_background.png")
	_shield_bar.texture_progress = load("res://bar_foreground.png")
	_stats_box.add_child(_shield_bar)

	# Multiplier row: "Multiplier:" caption on the left, value on the right.
	var caption := _make_stats_label("Multiplier:", MULT_LABEL_FONT_SIZE)
	caption.position = MULT_LABEL_POS
	_stats_box.add_child(caption)

	_multiplier_label = _make_stats_label("1x", MULT_VALUE_FONT_SIZE)
	_multiplier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_multiplier_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Left of the multiplier bar, vertically centred on it.
	var mult_bar_h := MULT_BAR_SIZE.y * MULT_BAR_SCALE
	_multiplier_label.position = Vector2(STATS_CONTENT_X, MULT_BAR_POS.y - 10)
	_multiplier_label.size = Vector2(STATS_LEFT_COLUMN_W, mult_bar_h + 20)
	_stats_box.add_child(_multiplier_label)

	# Multiplier progress / decay bar (multiplier_bar.gd).
	_multiplier_bar = MULTIPLIER_BAR_SCRIPT.new()
	_multiplier_bar.name = "MultiplierBar"
	_multiplier_bar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_multiplier_bar.size = MULT_BAR_SIZE
	_multiplier_bar.position = MULT_BAR_POS
	_multiplier_bar.scale = Vector2.ONE * MULT_BAR_SCALE
	_stats_box.add_child(_multiplier_bar)

	# Jump clock: left of the life bar, vertically centred on it, with
	# "READY" written across it when a jump is available.
	var life_bar_h := LIFE_BAR_SIZE.y * LIFE_BAR_SCALE
	var clock_pos := Vector2(
		STATS_CONTENT_X + (STATS_LEFT_COLUMN_W - JUMP_CLOCK_SIZE) * 0.5,
		LIFE_BAR_POS.y + life_bar_h * 0.5 - JUMP_CLOCK_SIZE * 0.5 + JUMP_CLOCK_Y_OFFSET)

	var jump_status := _make_stats_label("READY", JUMP_STATUS_FONT_SIZE)
	jump_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	jump_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	jump_status.size = Vector2.ONE * JUMP_CLOCK_SIZE
	jump_status.position = clock_pos

	var jump_clock = JUMP_INDICATOR_SCRIPT.new()
	jump_clock.name = "JumpClock"
	jump_clock.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	jump_clock.size = Vector2.ONE * JUMP_CLOCK_SIZE
	jump_clock.position = clock_pos
	jump_clock.status_label = jump_status
	_stats_box.add_child(jump_clock)
	_stats_box.add_child(jump_status)  # after the clock so it draws on top


## A TextureRect showing `region` of one of the 2048x2048 HUD art sheets.
func _make_art_rect(node_name: String, texture_path: String, region: Rect2) -> TextureRect:
	var atlas := AtlasTexture.new()
	atlas.atlas = load(texture_path)
	atlas.region = region
	var r := TextureRect.new()
	r.name = node_name
	r.texture = atlas
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.size = region.size
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The art is high-res and gets drawn much smaller, so smooth filtering
	# (with mipmaps) instead of the project's nearest-neighbour default.
	r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return r


func _make_stats_label(text: String, font_size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", STATS_TEXT_COLOR)
	return l


func _set_hud_visible(v: bool) -> void:
	if _portrait_frame:
		_portrait_frame.visible = v
	if _stats_box:
		_stats_box.visible = v


func _layout() -> void:
	var vis: Vector2 = get_viewport().get_visible_rect().size
	_ui.position = Vector2.ZERO
	_ui.size = vis

	# Play area centered in the window (in logical units). Rounded so the
	# play area lands on whole logical pixels.
	var play_pos := ((vis - PLAY_SIZE) * 0.5).floor()
	var side_w_left := play_pos.x
	var side_w_right := vis.x - play_pos.x - PLAY_SIZE.x

	_left_panel.position = Vector2.ZERO
	_left_panel.size = Vector2(side_w_left, vis.y)
	_right_panel.position = Vector2(play_pos.x + PLAY_SIZE.x, 0)
	_right_panel.size = Vector2(side_w_right, vis.y)

	# Render the game at the window's real pixel resolution (so it looks just
	# as sharp as before), then scale the container back down so it occupies
	# exactly PLAY_SIZE logical units.
	var win := Vector2(get_window().size)
	var scale_factor := 1.0
	if vis.x > 0 and vis.y > 0:
		scale_factor = max(min(win.x / vis.x, win.y / vis.y), 1.0)
	var render_size := Vector2i((PLAY_SIZE * scale_factor).ceil())
	_viewport.size = render_size
	_container.size = Vector2(render_size)
	_container.scale = PLAY_SIZE / Vector2(render_size)
	_container.position = play_pos

	_border.position = play_pos - Vector2.ONE
	_border.size = PLAY_SIZE + Vector2(2, 2)

	# HUD pieces: each fills its side panel's width (up to a cap), and both
	# sit with their bottoms level with the bottom of the play area.
	var bottom := play_pos.y + PLAY_SIZE.y - HUD_MARGIN
	_fit_hud_piece(_portrait_frame, 0.0, side_w_left, PORTRAIT_MAX_WIDTH, bottom)
	_fit_hud_piece(_stats_box, 0.0, side_w_right, STATS_BOX_MAX_WIDTH, bottom)


func _fit_hud_piece(piece: Control, panel_x: float, panel_w: float, max_w: float, bottom: float) -> void:
	var w: float = clamp(panel_w - HUD_MARGIN * 2.0, 40.0, max_w)
	var k := w / piece.size.x
	piece.scale = Vector2.ONE * k
	piece.position = Vector2(panel_x + (panel_w - w) * 0.5, bottom - piece.size.y * k)
