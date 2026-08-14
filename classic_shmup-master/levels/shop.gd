extends Control

## Space-themed shop screen, reached by landing on the overworld's shop layer
## (see GameProgress.SHOP_LAYER_INDEX / is_shop_node()). Offers 3 random
## abilities drawn from the full power-up pool (see
## PlayerPowerUps.get_random_shop_offers()) at a flat ABILITY_COST currency
## each - the player can buy any subset of the 3 offered this visit. Each
## purchase becomes a permanent run modifier, exactly like a power-up chosen
## at the end-of-level popup (see Stats.choose_run_powerup()), so it carries
## into every level for the rest of the run.
##
## Currency is earned from level score (see BaseLevel.change_levels()) and
## persists across levels/shops for the rest of the run, same lifetime as
## Stats.run_modifiers - both are wiped on a loss (see
## GameProgress.reset_run()).
##
## Drawn entirely in code (same approach as levels/overworld.gd) rather than
## with Container/Button nodes, to sidestep the min-size/anchor pitfalls
## those ran into before (see powerup_choice_popup.gd's history) and to
## match the overworld's visual style. Navigation is two rows: Left/Right
## cycles between the offered cards, Down moves to the "Leave Shop" button
## below them, Up moves back to the cards - the "start" action (Enter) buys
## the highlighted card, or leaves the shop if the button is highlighted.

const MAP_WIDTH := 240.0
const MAP_HEIGHT := 320.0
const STAR_COUNT := 40
const ABILITY_COST := 100
const OFFER_COUNT := 3

const CARD_WIDTH := 70.0
const CARD_HEIGHT := 160.0
const CARD_GAP := 5.0
const CARD_TOP := 56.0

var stars: Array = []
var pulse_time: float = 0.0
var offered: Array = []    # up to OFFER_COUNT power-up dicts on offer this visit
var purchased: Array = []  # parallel bool array - which of `offered` is bought

# Navigation is two rows: the card row (cursor_row == 0, Left/Right cycles
# `cursor_index` through `offered`) and the "Leave Shop" button below it
# (cursor_row == 1). Down moves from the cards to the Leave button, Up moves
# back, and Enter ("start") activates whichever is currently highlighted.
var cursor_row: int = 0
var cursor_index: int = 0


func _ready() -> void:
	stars.clear()
	for i in range(STAR_COUNT):
		stars.append(Vector2(randf() * MAP_WIDTH, randf() * MAP_HEIGHT))

	offered = PlayerPowerUps.get_random_shop_offers(OFFER_COUNT)
	purchased.clear()
	for i in range(offered.size()):
		purchased.append(false)
	cursor_index = 0
	# No cards to show - land straight on the Leave button, otherwise start
	# on the card row.
	cursor_row = 1 if offered.is_empty() else 0

	set_process(true)


func _process(delta: float) -> void:
	pulse_time += delta
	queue_redraw()


func _input(event: InputEvent) -> void:
	if cursor_row == 0 and offered.size() > 1:
		if event.is_action_pressed("right"):
			cursor_index = (cursor_index + 1) % offered.size()
		elif event.is_action_pressed("left"):
			cursor_index = (cursor_index - 1 + offered.size()) % offered.size()

	if event.is_action_pressed("down") and cursor_row == 0:
		cursor_row = 1
	elif event.is_action_pressed("up") and cursor_row == 1 and not offered.is_empty():
		cursor_row = 0

	if event.is_action_pressed("start"):
		_activate_cursor()


func _activate_cursor() -> void:
	if cursor_row == 1:
		_leave_shop()
	else:
		_try_purchase(cursor_index)


func _try_purchase(index: int) -> void:
	if purchased[index]:
		return
	if not Stats.spend_currency(ABILITY_COST):
		return  # can't afford it - no-op
	var powerup: Dictionary = offered[index]
	Stats.choose_run_powerup(powerup.get("id", ""), powerup.get("stats", {}))
	purchased[index] = true


func _leave_shop() -> void:
	set_process(false)
	GameProgress.on_level_won()


# ---------- Drawing ----------

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 1))

	for star in stars:
		draw_circle(star, 1.0, Color(1, 1, 1, 0.5))

	var font := ThemeDB.fallback_font

	draw_string(font, Vector2(12, 22), "* SHOP *", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1.0, 0.85, 0.2))
	draw_string(font, Vector2(12, 38), "$ %d" % Stats.currency, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.85, 0.9, 1.0))

	if offered.is_empty():
		draw_string(font, Vector2(MAP_WIDTH / 2.0 - 60, CARD_TOP + 30), "Nothing left to sell you!", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.8, 0.82, 0.9))
	else:
		for i in range(offered.size()):
			_draw_card(i, font)

	_draw_leave_option(font)


func _draw_card(index: int, font: Font) -> void:
	var powerup: Dictionary = offered[index]
	var total_width := offered.size() * CARD_WIDTH + (offered.size() - 1) * CARD_GAP
	var start_x := (MAP_WIDTH - total_width) / 2.0
	var x := start_x + index * (CARD_WIDTH + CARD_GAP)
	var rect := Rect2(x, CARD_TOP, CARD_WIDTH, CARD_HEIGHT)

	var is_selected := cursor_row == 0 and index == cursor_index
	var is_bought: bool = purchased[index]
	var can_afford := Stats.currency >= ABILITY_COST

	var border_color := Color(0.35, 0.37, 0.5, 0.6)
	if is_bought:
		border_color = Color(0.4, 0.85, 0.55, 0.9)
	elif is_selected:
		var pulse := 0.6 + 0.4 * sin(pulse_time * 4.0)
		border_color = Color(1.0, 0.85, 0.35, pulse)
	elif not can_afford:
		border_color = Color(0.5, 0.3, 0.3, 0.6)

	draw_rect(rect, Color(0.06, 0.07, 0.15, 1.0), true)
	draw_rect(rect, border_color, false, 3.0 if is_selected else 2.0)

	var name_text: String = powerup.get("name", "?").to_upper()
	var desc_text: String = powerup.get("description", "")
	var text_color := Color(0.55, 0.85, 1.0) if not is_bought else Color(0.6, 0.9, 0.7)

	_draw_wrapped_text(font, name_text, x + 6, CARD_TOP + 16, CARD_WIDTH - 12, 8, text_color)
	_draw_wrapped_text(font, desc_text, x + 6, CARD_TOP + 40, CARD_WIDTH - 12, 7, Color(0.82, 0.84, 0.9))

	var status_text := "OWNED" if is_bought else "%d G" % ABILITY_COST
	var status_color := Color(0.4, 0.85, 0.55) if is_bought else (Color(1.0, 0.85, 0.35) if can_afford else Color(0.8, 0.4, 0.4))
	draw_string(font, Vector2(x + 6, CARD_TOP + CARD_HEIGHT - 10), status_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, status_color)


func _draw_wrapped_text(font: Font, text: String, x: float, y: float, max_width: float, font_size: int, color: Color) -> void:
	"""Manual word-wrap since these cards are hand-drawn rather than backed
	by a Label's autowrap."""
	var words := text.split(" ")
	var line := ""
	var line_y := y
	var line_height := font_size + 3
	for word in words:
		var candidate := line + (" " if line != "" else "") + word
		var w: float = font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		if w > max_width and line != "":
			draw_string(font, Vector2(x, line_y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
			line = word
			line_y += line_height
		else:
			line = candidate
	if line != "":
		draw_string(font, Vector2(x, line_y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _draw_leave_option(font: Font) -> void:
	"""Drawn as an actual button (filled rect + border), separate from the
	card row below/above it - reached with Down from the cards (or Up to go
	back), and activated with the "start" action same as a card purchase."""
	var button_width := 118.0
	var button_height := 24.0
	var x := (MAP_WIDTH - button_width) / 2.0
	var y := CARD_TOP + CARD_HEIGHT + 24.0
	var rect := Rect2(x, y, button_width, button_height)

	var is_selected := cursor_row == 1

	var bg_color := Color(0.06, 0.07, 0.15, 1.0)
	var border_color := Color(0.5, 0.52, 0.62, 0.9)
	var text_color := Color(0.85, 0.87, 0.95, 1.0)
	var label := "LEAVE SHOP"

	if is_selected:
		var pulse := 0.6 + 0.4 * sin(pulse_time * 4.0)
		bg_color = Color(0.18, 0.15, 0.05, 1.0)
		border_color = Color(1.0, 0.85, 0.35, pulse)
		text_color = Color(1.0, 0.85, 0.35, 1.0)
		label = "> LEAVE SHOP <"

	draw_rect(rect, bg_color, true)
	draw_rect(rect, border_color, false, 3.0 if is_selected else 2.0)

	var font_size := 9
	var text_size: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(font, Vector2(x + (button_width - text_size.x) / 2.0, y + button_height / 2.0 + text_size.y * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)
