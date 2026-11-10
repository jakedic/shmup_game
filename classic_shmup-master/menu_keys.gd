# menu_keys.gd
#
# Shared keyboard controls for every menu, so they all work the same:
#   move   - W/A/S/D or the arrow keys (the "up"/"down"/"left"/"right" actions)
#   select - J, Space (the "shoot" action) or Enter (the "start" action)
#
# Scripts load it with `const MenuKeys := preload("res://menu_keys.gd")`.
#
# Button menus (title screen, pause menu...) are made of regular Button nodes,
# which only respond to the mouse on their own. handle_buttons() adds keys:
# Up/Down moves the highlighted (focused) button, select presses it.
extends RefCounted


## Select presses are ignored for this long after a menu opens, so mashing
## shoot at the end of a level doesn't instantly pick something on the next
## screen. Menus record Time.get_ticks_msec() when they open and check
## too_soon().
const ARM_DELAY_MSEC := 400


static func too_soon(opened_msec: int, delay_msec: int = ARM_DELAY_MSEC) -> bool:
	return Time.get_ticks_msec() - opened_msec < delay_msec


## True for a fresh press of a select key (J / Space / Enter).
static func is_confirm(event: InputEvent) -> bool:
	return event.is_action_pressed("start") or event.is_action_pressed("shoot")


## Visible, enabled buttons out of `buttons`.
static func usable(buttons: Array) -> Array:
	var out: Array = []
	for b in buttons:
		if b is BaseButton and is_instance_valid(b) and b.is_visible_in_tree() and not b.disabled:
			out.append(b)
	return out


## Highlight the first usable button (call when the menu opens).
static func focus_first(buttons: Array) -> void:
	var list := usable(buttons)
	if not list.is_empty():
		list[0].grab_focus()


## Index (into usable(buttons)) of the button that has focus, or -1.
static func focused_index(buttons: Array) -> int:
	var list := usable(buttons)
	if list.is_empty():
		return -1
	var owner: Control = list[0].get_viewport().gui_get_focus_owner()
	return list.find(owner)


## Up/Down moves focus between the buttons (wrapping), select presses the
## focused one. Returns true (and marks the event handled) if it used the
## event. Call from the menu's _input().
static func handle_buttons(event: InputEvent, buttons: Array) -> bool:
	var list := usable(buttons)
	if list.is_empty():
		return false
	var viewport: Viewport = list[0].get_viewport()
	var index := list.find(viewport.gui_get_focus_owner())
	var step := 0
	if event.is_action_pressed("down"):
		step = 1
	elif event.is_action_pressed("up"):
		step = -1
	if step != 0:
		index = 0 if index < 0 else wrapi(index + step, 0, list.size())
		list[index].grab_focus()
		viewport.set_input_as_handled()
		return true
	if is_confirm(event):
		viewport.set_input_as_handled()
		if index < 0:
			list[0].grab_focus()   # nothing highlighted yet - highlight first, don't press
		else:
			list[index].pressed.emit()
		return true
	return false
