# tutorial.gd
#
# Tutorial level - started as a copy of levels/a_test.gd (same waves and
# dialogue), to be reworked into the real tutorial. Uses the level-flow
# tools (see base_level.gd's WAVE FLOW + DIALOGUE sections):
#
#   next_wave_after_last_spawn(seconds) - next wave comes `seconds` after this
#                                         wave's last enemy spawns (or sooner
#                                         if the screen is cleared first)
#   say(text, options)                  - side-panel dialogue, game keeps going
#   await talk(lines, options)          - center dialogue, game pauses until
#                                         the player clicks through
#   await wait(seconds)                 - pause-aware delay inside a wave
#
# Built the same way as Yellow/Dylan Level - one function per wave, each spawn
# a labeled config (see levels/squad_wave_level.gd's header comment for every
# field). Waves play in order; once the outro is done the level ends and goes
# to level_paths["next_level"].
#
# Every wave except the outro has a CHALLENGE (see WAVE CHALLENGES below):
# the wave's instructions and challenge show at the top of the right side
# panel with a checkbox. Finish the challenge and the box gets ticked and the
# level moves on; end the wave without it and the same wave plays again
# (without its dialogue / cards the second time).
#
#   wave   challenge
#   0      dodge the astroids without losing all your health
#   1      jump over astroids 3 times (landing on one and destroying it counts too)
#   2      destroy 10 astroids
#   3      absorb an enemy ship (small astroids, gray bees and the odd golden
#          astroid keep falling until you do)
#   3b     absorb all 3 green target bubbles by bouncing a bubble into them
#          (resupply drops while you have no bubble). Shooting / flying through
#          a target only scatters it for a moment - see bullets/target_bubble.gd
#   5a     destroy the 3 green astroids with a shot-powered bubble (nothing
#          else can hurt them; no jumping)
#   5b     jump on bubbles: destroy 2 armored medium astroids by jumping on
#          a bubble next to them
#   5c     set off both bombs with Penetrator Rounds (combine two bubbles)
#          without getting hurt by a bomb blast
#   6      make it to the end without losing all your health
#   7      (outro - no challenge)
extends SquadWaveLevel
class_name TutorialLevel   # levels/level_0.gd reuses these waves (no dialogue / challenges); levels/a_test.gd runs single waves


# ===== DIALOGUE =====
# Whenever the center box opens, the side box's line (and anything queued
# behind it) disappears, so the same character never talks in both places
# at once. Lines said after the center box closes show as normal.
func talk(lines, options: Dictionary = {}) -> void:
	GameShell.clear_side_dialogue()
	await super(lines, options)


func ask(text: String, choices: Array, options: Dictionary = {}) -> int:
	GameShell.clear_side_dialogue()
	return await super(text, choices, options)


# ===== WAVE CHALLENGES =====
# Start one at the top of a wave function with begin_challenge({...}):
#   "title"       - instruction heading in the right panel, e.g. "Shoot"
#   "text"        - instruction text (usually the same as the wave's card)
#   "challenge"   - the line next to the checkbox
#   "kind"        - how it's checked - one of the CHALLENGE_* consts below
#   "target"      - the number to reach (astroids, bounces, bombs), or for
#                   CHALLENGE_MAX_HITS the number of hits that fails it
#   "method"      - CHALLENGE_BOMBS only: the BOMB_METHOD_* that counts
#   "fail_line"   - OPTIONAL - Red Frog's line the moment it's failed
#   "retry_line"  - OPTIONAL - Red Frog's line just before the wave repeats
#   "no_damage"   - OPTIONAL - true = taking any damage fails the challenge
#                   (on top of whatever its kind asks for).
#   "no_bomb_damage" - OPTIONAL - true = getting hurt by a bomb blast fails
#                   the challenge (other hits don't). Wave 5c uses it.
const CHALLENGE_SURVIVE := "survive"            # don't lose all your health - passes when the wave ends
const CHALLENGE_MAX_HITS := "max_hits"          # get hit fewer than `target` times - passes when the wave ends
const CHALLENGE_DESTROY_ASTROIDS := "astroids"  # destroy `target` astroids (gray bees don't count)
const CHALLENGE_ABSORB := "absorb"              # absorb any enemy
const CHALLENGE_BUBBLE_BOUNCES := "bounces"     # bounce ONE bubble off the ship `target` times
const CHALLENGE_BOMBS := "bombs"                # set off `target` bombs, every one with `method`
const CHALLENGE_POP_TARGETS := "targets"        # absorb `target` TargetBubbles by bouncing a bubble into them
const CHALLENGE_FILM_TARGETS := "film"          # destroy `target` of wave 5a's green astroids
const CHALLENGE_JUMP_TARGETS := "jump_targets"  # destroy `target` of wave 5b's armored medium astroids
const CHALLENGE_JUMP_OVER := "jump_over"        # `target` jumps that pass over an astroid (or land on one and destroy it)

# How a bomb was set off - read from the bomb's BaseEnemy.death_context (the
# "source" its killing hit was tagged with in bubble.gd / bullet.gd / ...).
# These follow the default bubble interactions in test_options.gd: jumping on
# a bubble pops it in an explosion, shooting it powers it up.
const BOMB_METHOD_JUMP := "bubble_jump_pop"         # jumped on a bubble and its explosion caught it
const BOMB_METHOD_SHOOT := "bubble_shot_charged"    # a bubble powered up by shots flew into it
const BOMB_METHOD_COMBINE := "penetrating_bullet"   # Penetrator Rounds (from combining two bubbles) shot through the ring

# Same order as tutorial_panel.gd's State (the panel takes the int).
enum ChallengeState { PENDING, DONE, FAILED }

const CHALLENGE_DONE_HOLD := 1.5   # seconds the ticked box stays up before the next wave starts
const RETRY_DELAY := 2.5            # seconds between "let's go again" and the wave restarting
const DEFAULT_RETRY_LINE := "Not quite. Let's run that one back."
# Early wave ends (_end_wave_early()): how long the ticked box stays up first.
const EARLY_END_HOLD := 0.3          # waves 1, 2 and 3 - the next wave's dialogue starts almost right away
const EARLY_END_HOLD_3B := 1.0       # after the green bubbles - a short beat, not the full clear-out
const EARLY_END_HOLD_5B := 0.5       # after the armored mediums
# Waves 1, 2 and 3 hand over once only this fraction of their last objects is still on screen.
const EARLY_END_ON_SCREEN_FRACTION := 0.25

# Waves 3b, 5a and 5b resupply: while the player has no bubble out and isn't
# transformed, something falls every RESUPPLY_DROP_INTERVAL seconds - a small
# astroid, a gray bee or a golden astroid (see _mixed_drops_until_done()).
const RESUPPLY_DROP_INTERVAL := 1.2       # seconds between drops
const RESUPPLY_DROP_SMALL_CHANCE := 0.5   # small astroid
const RESUPPLY_DROP_BEE_CHANCE := 0.25    # gray bee - whatever's left (25%) is a golden astroid

# Wave 0's astroids - 20% faster than the 45 px/s the rest of the tutorial uses.
const WAVE_0_ASTROID_SPEED := 54.0

var _challenge: Dictionary = {}
var _challenge_state := ChallengeState.PENDING
var _challenge_count := 0       # astroids destroyed / hits taken / best bounce / bombs done
var _retrying := false          # true while a wave is replaying after a failed challenge
var _wave_ending := false       # in the "ticked" hold or the retry countdown
var _challenge_shown := false   # panel is held back until the wave's dialogue is done (show_challenge())
var _done_hold := CHALLENGE_DONE_HOLD   # ticked-box hold for this wave - _end_wave_early() shortens it
var _last_shield := -1
# CHALLENGE_JUMP_OVER bookkeeping (see _track_jumps()).
const JUMP_OVER_REACH := 12.0   # px - an astroid's center this close under the airborne ship counts as jumped over
var _was_dashing := false
var _jump_passed_astroid := false   # the current jump has gone over at least one astroid
var _jump_counted := false          # the current / just-landed jump already counted toward the challenge


## Set this wave's instructions + challenge and reset its progress. Also tops
## the player's health back up, so a rough previous wave can't doom this one.
## The right side panel stays hidden until show_challenge() - call that once
## the wave's dialogue and cards are done.
func begin_challenge(config: Dictionary) -> void:
	_challenge = config
	_challenge_state = ChallengeState.PENDING
	_challenge_count = 0
	_challenge_shown = false
	_done_hold = CHALLENGE_DONE_HOLD
	GameShell.clear_tutorial_panel()
	if player:
		player.heal(player.max_shield)
		_last_shield = player.shield


## Fade the instructions + challenge into the right side panel. Every wave
## calls this right after its dialogue / cards (straight away on a replay).
func show_challenge() -> void:
	if _challenge.is_empty() or _challenge_shown:
		return
	_challenge_shown = true
	_refresh_challenge_panel()
	GameShell.fade_in_tutorial_panel()


## No challenge (and no instructions) - the right panel goes away.
func clear_challenge() -> void:
	_challenge = {}
	GameShell.clear_tutorial_panel()


## True while a wave is replaying after a failed challenge - wave functions
## skip their dialogue and cards when it is.
func is_retry() -> bool:
	return _retrying


func _challenge_kind() -> String:
	return _challenge.get("kind", "")


func _challenge_pending(kind: String) -> bool:
	return _challenge_kind() == kind and _challenge_state == ChallengeState.PENDING


func _refresh_challenge_panel() -> void:
	if _challenge.is_empty():
		GameShell.clear_tutorial_panel()
		return
	if not _challenge_shown:
		return   # still in the wave's dialogue - see show_challenge()
	var target: int = _challenge.get("target", 0)
	var progress := ""
	match _challenge_kind():
		CHALLENGE_MAX_HITS:
			progress = "hits: %d" % _challenge_count
		CHALLENGE_DESTROY_ASTROIDS, CHALLENGE_BUBBLE_BOUNCES, CHALLENGE_BOMBS, CHALLENGE_POP_TARGETS, CHALLENGE_FILM_TARGETS, CHALLENGE_JUMP_TARGETS, CHALLENGE_JUMP_OVER:
			progress = "%d/%d" % [mini(_challenge_count, target), target]
	GameShell.set_tutorial_panel(_challenge.get("title", ""), _challenge.get("text", ""),
		_challenge.get("challenge", ""), progress, _challenge_state)


func _add_challenge_progress(amount: int = 1) -> void:
	_challenge_count += amount
	_refresh_challenge_panel()
	if _challenge_count >= int(_challenge.get("target", 0)):
		_complete_challenge()


func _complete_challenge() -> void:
	if _challenge.is_empty() or _challenge_state != ChallengeState.PENDING:
		return
	_challenge_state = ChallengeState.DONE
	_refresh_challenge_panel()


func _fail_challenge() -> void:
	if _challenge.is_empty() or _challenge_state != ChallengeState.PENDING:
		return
	_challenge_state = ChallengeState.FAILED
	_refresh_challenge_panel()
	var line: String = _challenge.get("fail_line", "")
	if line != "":
		say(line, RED_FROG)


# --- Wave end: move on, or replay the wave ---

func handle_wave_completion() -> void:
	if _wave_ending:
		return
	if _challenge.is_empty():
		super.handle_wave_completion()
		return
	# "Don't..." challenges pass by getting to the end of the wave intact.
	var kind := _challenge_kind()
	if kind == CHALLENGE_SURVIVE or kind == CHALLENGE_MAX_HITS:
		_complete_challenge()
	if _challenge_state == ChallengeState.DONE:
		_finish_wave()
		return
	# Not done. A timed wave (next_wave_after_last_spawn) can get here with
	# enemies still on screen - wait for them to clear, then replay it.
	if not get_tree().get_nodes_in_group("enemies").is_empty() or _pending_spawns > 0:
		return
	_retry_wave()


func _finish_wave() -> void:
	_wave_ending = true
	await wait(_done_hold)   # let the ticked box sink in
	if not is_inside_tree():
		return
	_wave_ending = false
	_retrying = false
	_challenge = {}
	super.handle_wave_completion()


func _retry_wave() -> void:
	_wave_ending = true
	_fail_challenge()   # red X, if it wasn't already
	say(_challenge.get("retry_line", DEFAULT_RETRY_LINE), RED_FROG)
	await wait(RETRY_DELAY)
	if not is_inside_tree() or not playing:
		return
	_wave_ending = false
	_retrying = true
	# A timed wave's next-wave timer could still be counting - it mustn't
	# fire into the replay.
	_next_wave_timer.stop()
	_run_wave()


## Call at the end of a wave function: move on to the next wave as soon as
## the function returns (once its challenge is done), with only `hold`
## seconds of ticked box, instead of waiting for every leftover enemy to
## leave the screen. Leftovers keep drifting off during the next wave. If the
## challenge isn't done yet, the wave still waits for the screen to clear and
## replays as usual.
func _end_wave_early(hold: float = EARLY_END_HOLD) -> void:
	_done_hold = hold
	next_wave_after_last_spawn(0.0)


## Waits until no more than `fraction` of `nodes` are still alive and on the
## screen (destroyed or gone off the edge both count as gone).
func _wait_until_mostly_gone(nodes: Array, fraction: float) -> void:
	var total := nodes.size()
	if total == 0:
		return
	var screen := Rect2(Vector2.ZERO, get_viewport_rect().size)
	while is_inside_tree():
		var showing := 0
		for n in nodes:
			if is_instance_valid(n) and not n.is_queued_for_deletion() and screen.has_point(n.global_position):
				showing += 1
		if showing <= total * fraction:
			return
		await wait(0.1)


# --- What counts toward each challenge ---

func _on_node_added(node: Node) -> void:
	if node is BombEnemy:
		node.died.connect(_on_bomb_died.bind(node))
	elif node is AstroidEnemy and not (node is GrayEnemy):
		node.died.connect(_on_astroid_destroyed.bind(node))
	elif node is Bubble:
		node.bounced_off_player.connect(_on_bubble_bounced)


func _on_astroid_destroyed(_value: int, astroid: Node = null) -> void:
	if _challenge_pending(CHALLENGE_DESTROY_ASTROIDS):
		_add_challenge_progress()
	# Landing on an astroid and destroying it counts as a jump over it (once
	# per jump). death_context is set before `died` fires (BaseEnemy.die()).
	if _challenge_pending(CHALLENGE_JUMP_OVER) and not _jump_counted \
			and is_instance_valid(astroid) and astroid.death_context.get("source", "") == "jump_landing":
		_jump_counted = true
		_add_challenge_progress()


## CHALLENGE_JUMP_OVER: while the ship is in the air, note whether it passes
## over any astroid; when it lands, that jump counts once (however many
## astroids it cleared). A jump that lands on an astroid and destroys it
## counts too - see _on_astroid_destroyed().
func _track_jumps() -> void:
	if not player or not is_instance_valid(player):
		return
	var dashing: bool = player.is_dashing
	if dashing and not _was_dashing:   # just took off
		_jump_passed_astroid = false
		_jump_counted = false
	if dashing and not _jump_passed_astroid and _challenge_pending(CHALLENGE_JUMP_OVER):
		_jump_passed_astroid = _astroid_under_player()
	if _was_dashing and not dashing:   # just landed
		if _jump_passed_astroid and not _jump_counted and _challenge_pending(CHALLENGE_JUMP_OVER):
			_jump_counted = true
			_add_challenge_progress()
	_was_dashing = dashing


func _astroid_under_player() -> bool:
	for area in player.get_overlapping_areas():
		if area is AstroidEnemy and not (area is GrayEnemy) and area.is_alive:
			return true
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is AstroidEnemy and not (e is GrayEnemy) and e.is_alive \
				and e.global_position.distance_to(player.global_position) <= JUMP_OVER_REACH:
			return true
	return false


func _on_bubble_bounced(total_bounces: int) -> void:
	# Progress shows the best single bubble so far.
	if _challenge_pending(CHALLENGE_BUBBLE_BOUNCES) and total_bounces > _challenge_count:
		_add_challenge_progress(total_bounces - _challenge_count)


func _on_bomb_died(_value: int, bomb: Node) -> void:
	if not _challenge_pending(CHALLENGE_BOMBS):
		return
	if _bomb_kill_method(bomb.death_context) == _challenge.get("method", ""):
		_add_challenge_progress()
	else:
		_fail_challenge()


## Which BOMB_METHOD_* a bomb's death_context adds up to ("" / something else
## = none of them). A bomb set off by another bomb's blast counts as whatever
## set off the first one.
func _bomb_kill_method(context: Dictionary) -> String:
	var source: String = context.get("source", "")
	if source == "bomb_blast":
		return _bomb_kill_method(context.get("chained_from", {}))
	if source == "bullet":
		return BOMB_METHOD_COMBINE if context.get("penetrating", false) else "bullet"
	return source


func _on_player_shield_changed(_max_shield: int, current: int) -> void:
	var before := _last_shield
	_last_shield = current
	if before < 0 or current >= before:
		return   # a heal, not a hit
	if _challenge_state == ChallengeState.PENDING and _challenge.get("no_damage", false):
		_fail_challenge()
		return
	# BombEnemy.BlastFx tags the player with this meta for the length of its hit.
	if _challenge_state == ChallengeState.PENDING and _challenge.get("no_bomb_damage", false) \
			and player and player.get_meta("damage_source", "") == "bomb_blast":
		_fail_challenge()
		return
	if _challenge_pending(CHALLENGE_MAX_HITS):
		_challenge_count += 1
		_refresh_challenge_panel()
		if _challenge_count >= int(_challenge.get("target", 0)):
			_fail_challenge()


func _process(delta: float) -> void:
	super._process(delta)
	# Absorbing = the ship has taken on an enemy's form.
	if _challenge_pending(CHALLENGE_ABSORB) and player and player.current_form != 'default':
		_complete_challenge()
	_track_jumps()


# --- Drops ---

## True while the player has a bubble out (any of theirs on screen), is
## transformed, or is mid-absorb.
func _player_has_bubble_power() -> bool:
	if player and (player.current_form != 'default' or player.currently_absorbing):
		return true
	for b in get_tree().get_nodes_in_group("bubble"):
		if is_instance_valid(b) and not b.is_queued_for_deletion():
			return true
	return false


## Waits up to `seconds` (pause-aware), stopping early once the challenge is
## no longer pending. Returns true if it's still pending afterward.
func _wait_while_challenge_pending(seconds: float) -> bool:
	var remaining := seconds
	while remaining > 0.0:
		var step: float = minf(0.25, remaining)
		await wait(step)
		if not is_inside_tree():
			return false
		remaining -= step
		if _challenge_state != ChallengeState.PENDING:
			return false
	return _challenge_state == ChallengeState.PENDING


# Enemy scenes (ENEMY_BEE, FLOWER, ...), dialogue faces (FACE_HAPPY,
# FACE_NERVOUS, ...) and speaker presets (FROG) are shared by every level -
# they're declared once in levels/squad_wave_level.gd.


# Options for the "What'll it be?" question in _wave_intro(), in the order
# they're listed there.
const CHOICE_START_TUTORIAL := 0
const CHOICE_FORGE_SIGNATURE := 1

# Tutorial card clips (Art assets/Tutorial). movement.ogv is a placeholder
# recording of the ship dodging astroids - replace the file to update it.
const TUTORIAL_MOVEMENT_VIDEO := "res://Art assets/Tutorial/movement.ogv"
# When each key is pressed in movement.ogv - [key, from, to] in seconds of
# the clip - so the W/A/S/D caps light up in sync with the ship. Nudge these
# if you re-record the clip.
const TUTORIAL_MOVEMENT_KEYS := [
	["A", 0.25, 0.85],   # left
	["D", 1.15, 1.85],   # back right
	["W", 2.00, 2.55],   # up
	["S", 2.95, 3.65],   # down
]

# Jump card clip (a later part of the same recording): two jumps with the
# full cooldown wait between them. Times are seconds of jump.ogv.
const TUTORIAL_JUMP_VIDEO := "res://Art assets/Tutorial/jump.ogv"
const TUTORIAL_JUMP_KEYS := [
	["L", 0.35, 0.55],   # first jump (lands at ~1.23)
	["L", 3.05, 3.25],   # second jump (lands at ~3.93)
]
# Landing + cooldown after each jump (landing pause 0.25 + dash_cooldown 1.5
# in stats.gd) - the L cap dims and refills during these.
const TUTORIAL_JUMP_COOLDOWNS := [
	["L", 1.23, 2.98],
	["L", 3.93, 5.68],
]

# Shooting card clip: holding SPACE and firing a stream of shots.
const TUTORIAL_SHOOT_VIDEO := "res://Art assets/Tutorial/shoot.ogv"
const TUTORIAL_SHOOT_KEYS := [
	["SPACE", 0.6, 2.75],
]

# Absorb card clip: a gray bee drifts in, K fires the absorb beam, the ship
# takes on its form.
const TUTORIAL_ABSORB_VIDEO := "res://Art assets/Tutorial/absorb.ogv"
const TUTORIAL_ABSORB_KEYS := [
	["K", 1.75, 1.95],
]

# Transformation card clip: the gray ship flashing as the form runs out, then
# reverting to normal. No keys - it's just showing the timer running down.
const TUTORIAL_RUNOUT_VIDEO := "res://Art assets/Tutorial/transform_runout.ogv"

# Bubble card clip: K gives up the gray form and shoots out a bubble, which
# then bounces around the level.
const TUTORIAL_BUBBLE_VIDEO := "res://Art assets/Tutorial/bubble.ogv"
const TUTORIAL_BUBBLE_KEYS := [
	["K", 0.85, 1.05],
]

# "Using Bubbles" card - one short clip per way to use a bubble:
#   bubble_jump.ogv    - jump next to a falling bubble; the landing charges it
#                        and it flies into a ring and sets off the bomb
#   bubble_shoot.ogv   - fire a bubble and shoot it: big explosion
#   bubble_combine.ogv - two bubbles merge (Penetrator Rounds), then shots go
#                        through a ring to hit the bomb
const TUTORIAL_BUBBLE_JUMP_VIDEO := "res://Art assets/Tutorial/bubble_jump.ogv"
const TUTORIAL_BUBBLE_SHOOT_VIDEO := "res://Art assets/Tutorial/bubble_shoot.ogv"
const TUTORIAL_BUBBLE_COMBINE_VIDEO := "res://Art assets/Tutorial/bubble_combine.ogv"

# Wave 5a card clip: K shoots out a bubble, J shots power it up, and it flies
# up and destroys an astroid. Recorded in the old cosmic storm version of the
# wave - re-record to show the green astroids. Times are seconds of
# bubble_storm_shoot.ogv.
const TUTORIAL_BUBBLE_SHOOT_CARD_VIDEO := "res://Art assets/Tutorial/bubble_storm_shoot.ogv"
const TUTORIAL_BUBBLE_SHOOT_CARD_KEYS := [
	["J", 0.75, 1.65],
]

# Wave 5b card clip (recorded with the old caged bubble): jumping on a bubble pops it and the explosion
# takes out the armored ring. Times are seconds of bubble_jump_on.ogv.
const TUTORIAL_JUMP_ON_VIDEO := "res://Art assets/Tutorial/bubble_jump_on.ogv"
const TUTORIAL_JUMP_ON_KEYS := [
	["L", 0.65, 0.85],
]

# Red Frog as a speaker preset for say()/talk().
const RED_FROG := {"speaker": "Red Frog", "portrait": FACE_RED}

# Which abilities the player has in each tutorial wave. Wave 0 (intro) is
# movement only, wave 1 adds jumping, wave 2 shooting, and absorbing (K, plus
# the flashing white absorb-ready border) stays off until wave 3.
func _set_abilities(can_shoot: bool, can_jump: bool, can_absorb: bool) -> void:
	if player:
		player.shoot_enabled = can_shoot
		player.jump_enabled = can_jump
		player.absorb_enabled = can_absorb


# Intro - a pausing, center-screen conversation before anything spawns. Each
# line can set its own speaker/portrait; anything a line leaves out comes from
# the shared options (FROG here). No enemies in this wave, so once the player
# clicks through the last line the next wave starts right away.
func _wave_intro() -> void:
	_set_abilities(false, false, false)   # movement only - no shooting, jumping or absorbing
	begin_challenge({
		"title": "Movement",
		"text": "Move with W A S D. Dodge everything coming your way.",
		"challenge": "Avoid the asteroids without losing all your health",
		"kind": CHALLENGE_SURVIVE,
		"retry_line": "Let's try that again. You got this!",
	})
	# Dialogue + card only the first time (not when the wave replays).
	if not is_retry():
		await talk([
			{"text": "Howdy new friend!", "portrait": FACE_RED,"speaker": "Red Frog"},
			{"text": "...", "portrait": FACE_NEUTRAL,"speaker": "Frog"},
			{"text": "Er, I mean old friend.", "portrait": FACE_RED,"speaker": "Red Frog"},
			{"text": "...", "portrait": FACE_NEUTRAL,"speaker": "Frog"},
			{"text": "Well, I mean, I guess we're not friends, but I've seen you around at the conferences. Great field research on the indigenous hexagonal lotus root by the way.", "portrait": FACE_RED,"speaker": "Red Frog"},
			{"text": "Where are my manners? I'm Red Frog. And you are?", "portrait": FACE_RED,"speaker": "Red Frog"},
			{"text": "Frog.", "portrait": FACE_NEUTRAL,"speaker": "Frog"},
			{"text": "Oh, so you do speak! I thought your coms were fried for a second. More of the strong and almost silent type, eh.", "portrait": FACE_RED,"speaker": "Red Frog"},
			{"text": "Anyway, says here you're looking to renew your intergalactic travel license. Was the photo really that bad?", "portrait": FACE_RED,"speaker": "Red Frog"},
			{"text": "...", "portrait": FACE_NEUTRAL,"speaker": "Frog"},
			{"text": "Sorry, just a little joke. Guess it didn't land. Speaking of jokes, this test should be a hop in the pond for someone like you.", "portrait": FACE_RED,"speaker": "Red Frog"},
			{"text": "I'm sure you have important research to do and I wouldn't want to waste your time. If you want, Gary from licensing owes me a favor, well actually a few favors.", "portrait": FACE_RED,"speaker": "Red Frog"},
			{"text": "I could have him check all the boxes for us. Oh, but also if you want some practice I'm happy to administer.", "portrait": FACE_RED,"speaker": "Red Frog"},
		], FROG)

		# Player picks one of the options - `choice` is its position in the list
		# (0 = "Start Tutorial", 1 = "Forge Signature").
		var choice: int = await ask("Up to you", ["Start Tutorial", "Skip Tutorial (Cash in one of the Gary favors)"], {"portrait": FACE_RED, "speaker": "Red Frog"})
		if choice == CHOICE_START_TUTORIAL:
			pass   # TODO: tutorial path - for now both choices carry on the same way
		elif choice == CHOICE_FORGE_SIGNATURE:
			pass   # TODO: forge-signature path - for now both choices carry on the same way

		await talk([
			{"text": "Great! This'll give us a chance to get to know each other a little better!", "portrait": FACE_RED,"speaker": "Red Frog"},
			{"text": "First, we'll have to test out your ship's maneuverability. Luckily there are a bunch of loose asteroids, just looking to be avoided.","portrait": FACE_RED,"speaker": "Red Frog"},
		], FROG)

		# Tutorial card: how to move. Pauses until the player closes it.
		await show_info({
			"title": "Movement",
			"video": TUTORIAL_MOVEMENT_VIDEO,
			"keys": [["W"], ["A", "S", "D"]],
			"key_timeline": TUTORIAL_MOVEMENT_KEYS,
		})
	show_challenge()   # instructions + challenge fade in now that the talking's done

	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.8, "end_side": Side.BOTTOM, "end_percent": 0.8, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 0.0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.2, "end_side": Side.BOTTOM, "end_percent": 0.2, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 0.0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.5, "end_side": Side.BOTTOM, "end_percent": 0.5, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 0.0})
	
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.6, "end_side": Side.BOTTOM, "end_percent": 0.65, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 2.0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.4, "end_side": Side.BOTTOM, "end_percent": 0.35, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 2.0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.9, "end_side": Side.BOTTOM, "end_percent": 0.9, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 2.0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.1, "end_side": Side.BOTTOM, "end_percent": 0.1, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 2.0})
	
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.8, "end_side": Side.BOTTOM, "end_percent": 0.8, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 4.0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.2, "end_side": Side.BOTTOM, "end_percent": 0.2, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 4.0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.5, "end_side": Side.BOTTOM, "end_percent": 0.5, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 4.0})
	
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.6, "end_side": Side.BOTTOM, "end_percent": 0.65, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 6.0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.4, "end_side": Side.BOTTOM, "end_percent": 0.35, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 6.0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.9, "end_side": Side.BOTTOM, "end_percent": 0.9, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 6.0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.1, "end_side": Side.BOTTOM, "end_percent": 0.1, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 6.0})
	
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.9, "end_side": Side.BOTTOM, "end_percent": 0.9, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 8.0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.1, "end_side": Side.BOTTOM, "end_percent": 0.1, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 8.0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.85, "end_side": Side.BOTTOM, "end_percent": 0.85, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 8.75})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.15, "end_side": Side.BOTTOM, "end_percent": 0.15, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 8.75})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.8, "end_side": Side.BOTTOM, "end_percent": 0.8, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 9.5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.2, "end_side": Side.BOTTOM, "end_percent": 0.2, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 9.5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.75, "end_side": Side.BOTTOM, "end_percent": 0.75, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 10.25})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.25, "end_side": Side.BOTTOM, "end_percent": 0.25, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 10.25})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.7, "end_side": Side.BOTTOM, "end_percent": 0.7, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 11.0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.3, "end_side": Side.BOTTOM, "end_percent": 0.3, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 11.0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.65, "end_side": Side.BOTTOM, "end_percent": 0.65, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 11.75})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.35, "end_side": Side.BOTTOM, "end_percent": 0.35, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 11.75})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.6, "end_side": Side.BOTTOM, "end_percent": 0.6, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 12.5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.4, "end_side": Side.BOTTOM, "end_percent": 0.4, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 12.5})
	
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.RIGHT, "start_percent": 0.6, "end_side": Side.LEFT, "end_percent": 0.65, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 15.0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.RIGHT, "start_percent": 0.4, "end_side": Side.LEFT, "end_percent": 0.35, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 15.0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.RIGHT, "start_percent": 0.9, "end_side": Side.LEFT, "end_percent": 0.9, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 15.0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.RIGHT, "start_percent": 0.1, "end_side": Side.LEFT, "end_percent": 0.1, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 15.0})
	
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.LEFT, "start_percent": 0.5, "end_side": Side.RIGHT, "end_percent": 0.5, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 15.0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.LEFT, "start_percent": 0.775, "end_side": Side.RIGHT, "end_percent": 0.775, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 15.0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.LEFT, "start_percent": 0.225, "end_side": Side.RIGHT, "end_percent": 0.225, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 15.0})
	
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.1, "end_side": Side.BOTTOM, "end_percent": 0.1, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 17.0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.2, "end_side": Side.BOTTOM, "end_percent": 0.2, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 17.0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.3, "end_side": Side.BOTTOM, "end_percent": 0.3, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 17.0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.4, "end_side": Side.BOTTOM, "end_percent": 0.4, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 17.0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.5, "end_side": Side.BOTTOM, "end_percent": 0.5, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 17.0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.6, "end_side": Side.BOTTOM, "end_percent": 0.6, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 17.0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.7, "end_side": Side.BOTTOM, "end_percent": 0.7, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 17.0})
	
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.9, "end_side": Side.BOTTOM, "end_percent": 0.9, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 19.5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.8, "end_side": Side.BOTTOM, "end_percent": 0.8, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 19.5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.3, "end_side": Side.BOTTOM, "end_percent": 0.3, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 19.5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.4, "end_side": Side.BOTTOM, "end_percent": 0.4, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 19.5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.5, "end_side": Side.BOTTOM, "end_percent": 0.5, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 19.5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.6, "end_side": Side.BOTTOM, "end_percent": 0.6, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 19.5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.7, "end_side": Side.BOTTOM, "end_percent": 0.7, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 19.5})
	
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.1, "end_side": Side.BOTTOM, "end_percent": 0.1, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 22.0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.2, "end_side": Side.BOTTOM, "end_percent": 0.2, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 22.0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.3, "end_side": Side.BOTTOM, "end_percent": 0.3, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 22.0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.4, "end_side": Side.BOTTOM, "end_percent": 0.4, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 22.0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.5, "end_side": Side.BOTTOM, "end_percent": 0.5, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 22.0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.6, "end_side": Side.BOTTOM, "end_percent": 0.6, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 22.0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.7, "end_side": Side.BOTTOM, "end_percent": 0.7, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 22.0})
	
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.9, "end_side": Side.BOTTOM, "end_percent": 0.9, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 24.5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.8, "end_side": Side.BOTTOM, "end_percent": 0.8, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 24.5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.3, "end_side": Side.BOTTOM, "end_percent": 0.3, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 24.5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.4, "end_side": Side.BOTTOM, "end_percent": 0.4, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 24.5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.5, "end_side": Side.BOTTOM, "end_percent": 0.5, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 24.5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.6, "end_side": Side.BOTTOM, "end_percent": 0.6, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 24.5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.7, "end_side": Side.BOTTOM, "end_percent": 0.7, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 24.5})
	
	# --- Commented out 2026-11-17 to shorten wave 0: the corner fan-sprays (26.5-32.5s)
	# and side-to-side crossings (34.5-36.5s). Uncomment to bring them back. ---
	#spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.9, "end_side": Side.BOTTOM, "end_percent": 0.9, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 26.5})
	#spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.9, "end_side": Side.BOTTOM, "end_percent": 0.5, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 26.5})
	#spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.9, "end_side": Side.BOTTOM, "end_percent": 0.1, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 26.5})
	#spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.1, "end_side": Side.BOTTOM, "end_percent": 0.1, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 28.5})
	#spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.1, "end_side": Side.BOTTOM, "end_percent": 0.5, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 28.5})
	#spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.1, "end_side": Side.BOTTOM, "end_percent": 0.9, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 28.5})
	
	#spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.9, "end_side": Side.BOTTOM, "end_percent": 0.9, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 30.5})
	#spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.9, "end_side": Side.BOTTOM, "end_percent": 0.5, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 30.5})
	#spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.9, "end_side": Side.BOTTOM, "end_percent": 0.1, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 30.5})
	#spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.1, "end_side": Side.BOTTOM, "end_percent": 0.1, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 32.5})
	#spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.1, "end_side": Side.BOTTOM, "end_percent": 0.5, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 32.5})
	#spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.1, "end_side": Side.BOTTOM, "end_percent": 0.9, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 32.5})
	
	#spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.LEFT, "start_percent": 0.9, "end_side": Side.RIGHT, "end_percent": 0.9, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 34.5})
	#spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.LEFT, "start_percent": 0.9, "end_side": Side.RIGHT, "end_percent": 0.5, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 34.5})
	#spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.LEFT, "start_percent": 0.9, "end_side": Side.RIGHT, "end_percent": 0.1, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 34.5})
	#spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.RIGHT, "start_percent": 0.1, "end_side": Side.LEFT, "end_percent": 0.1, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 34.5})
	#spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.RIGHT, "start_percent": 0.1, "end_side": Side.LEFT, "end_percent": 0.5, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 34.5})
	#spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.RIGHT, "start_percent": 0.1, "end_side": Side.LEFT, "end_percent": 0.9, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 34.5})
	
	#spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.RIGHT, "start_percent": 0.9, "end_side": Side.LEFT, "end_percent": 0.9, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 36.5})
	#spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.RIGHT, "start_percent": 0.9, "end_side": Side.LEFT, "end_percent": 0.5, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 36.5})
	#spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.RIGHT, "start_percent": 0.9, "end_side": Side.LEFT, "end_percent": 0.1, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 36.5})
	#spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.LEFT, "start_percent": 0.1, "end_side": Side.RIGHT, "end_percent": 0.1, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 36.5})
	#spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.LEFT, "start_percent": 0.1, "end_side": Side.RIGHT, "end_percent": 0.5, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 36.5})
	#spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.LEFT, "start_percent": 0.1, "end_side": Side.RIGHT, "end_percent": 0.9, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 36.5})
	next_wave_after_last_spawn(6.0)
	


# Wave 1 - jump tutorial: Red Frog's lines, the Jump card, then astroid
# columns and the jump-only formations (two diagonal walls and a ring).
func _wave_1() -> void:
	_set_abilities(false, true, false)    # jumping unlocked, still no shooting or absorbing
	begin_challenge({
		"title": "Jump",
		"text": "Press L to jump. After you land, the jump needs a moment to recharge before you can use it again.",
		"challenge": "Jump over astroids 3 times",
		"kind": CHALLENGE_JUMP_OVER,
		"target": 3,
		"retry_line": "Let's give it another hop!",
	})
	# Dialogue + card only the first time (not when the wave replays).
	if not is_retry():
		await talk([
			{"text": "Says here your ship is equipped with hyperdimensional optimized propulsion. Oh I get it H.O.P.! Cause you're a frog.", "portrait": FACE_RED,"speaker": "Red Frog"},
			{"text": "...","portrait": FACE_NEUTRAL,"speaker": "Frog"},
			{"text": "Seems like you have more of a sense of humor than you let on. Would love to see H.O.P. in action! I don't think I've seen modifications this advance on such an old model.", "portrait": FACE_RED,"speaker": "Red Frog"},
			{"text": "Oh um, not old model like old old. I meant more like vintage. Or um, distinguished.", "portrait": FACE_RED,"speaker": "Red Frog"},
		], FROG)

		# Tutorial card: jumping + its cooldown. Pauses until the player closes it.
		await show_info({
			"title": "Jump",
			"video": TUTORIAL_JUMP_VIDEO,
			"keys": [["L"]],
			"key_timeline": TUTORIAL_JUMP_KEYS,
			"key_cooldowns": TUTORIAL_JUMP_COOLDOWNS,
			"text": "Press L to jump. After you land, the jump needs a moment to recharge before you can use it again.",
		})
	show_challenge()   # instructions + challenge fade in now that the talking's done

	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.1, "end_side": Side.BOTTOM, "end_percent": 0.1, "speed": 45, "start_delay": 0.0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.2, "end_side": Side.BOTTOM, "end_percent": 0.2, "speed": 45, "start_delay": 0.0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.3, "end_side": Side.BOTTOM, "end_percent": 0.3, "speed": 45, "start_delay": 0.0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.4, "end_side": Side.BOTTOM, "end_percent": 0.4, "speed": 45, "start_delay": 0.0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.5, "end_side": Side.BOTTOM, "end_percent": 0.5, "speed": 45, "start_delay": 0.0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.6, "end_side": Side.BOTTOM, "end_percent": 0.6, "speed": 45, "start_delay": 0.0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.7, "end_side": Side.BOTTOM, "end_percent": 0.7, "speed": 45, "start_delay": 0.0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.8, "end_side": Side.BOTTOM, "end_percent": 0.8, "speed": 45, "start_delay": 0.0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.9, "end_side": Side.BOTTOM, "end_percent": 0.9, "speed": 45, "start_delay": 0.0})

	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.1, "end_side": Side.BOTTOM, "end_percent": 0.1, "speed": 45, "start_delay": 2.5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.2, "end_side": Side.BOTTOM, "end_percent": 0.2, "speed": 45, "start_delay": 2.5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.3, "end_side": Side.BOTTOM, "end_percent": 0.3, "speed": 45, "start_delay": 2.5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.4, "end_side": Side.BOTTOM, "end_percent": 0.4, "speed": 45, "start_delay": 2.5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.5, "end_side": Side.BOTTOM, "end_percent": 0.5, "speed": 45, "start_delay": 2.5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.6, "end_side": Side.BOTTOM, "end_percent": 0.6, "speed": 45, "start_delay": 2.5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.7, "end_side": Side.BOTTOM, "end_percent": 0.7, "speed": 45, "start_delay": 2.5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.8, "end_side": Side.BOTTOM, "end_percent": 0.8, "speed": 45, "start_delay": 2.5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.9, "end_side": Side.BOTTOM, "end_percent": 0.9, "speed": 45, "start_delay": 2.5})

	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.1, "end_side": Side.BOTTOM, "end_percent": 0.1, "speed": 45, "start_delay": 5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.2, "end_side": Side.BOTTOM, "end_percent": 0.2, "speed": 45, "start_delay": 5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.3, "end_side": Side.BOTTOM, "end_percent": 0.3, "speed": 45, "start_delay": 5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.4, "end_side": Side.BOTTOM, "end_percent": 0.4, "speed": 45, "start_delay": 5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.5, "end_side": Side.BOTTOM, "end_percent": 0.5, "speed": 45, "start_delay": 5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.6, "end_side": Side.BOTTOM, "end_percent": 0.6, "speed": 45, "start_delay": 5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.7, "end_side": Side.BOTTOM, "end_percent": 0.7, "speed": 45, "start_delay": 5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.8, "end_side": Side.BOTTOM, "end_percent": 0.8, "speed": 45, "start_delay": 5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.9, "end_side": Side.BOTTOM, "end_percent": 0.9, "speed": 45, "start_delay": 5})

	spawn_diagonal_astroid_wall({"from_corner": "top_right", "enemy": ASTROID_SMALL, "speed": 55.0, "spacing": 18.0, "start_delay": 9.0})
	spawn_diagonal_astroid_wall({"from_corner": "top_left", "enemy": ASTROID_SMALL, "speed": 55.0, "spacing": 18.0, "start_delay": 12.0})
	spawn_astroid_ring({"enemy": ASTROID_SMALL, "speed": 55.0, "spacing": 18.0, "start_delay": 16.0, "group": "wave_1_ring"})

	# Hand over to the next wave once only a quarter of the ring is still on
	# screen - its dialogue starts while the rest of the ring slides out.
	while _pending_spawns > 0 and is_inside_tree():   # every ring astroid is in
		await wait(0.1)
	await _wait_until_mostly_gone(get_tree().get_nodes_in_group("wave_1_ring"), EARLY_END_ON_SCREEN_FRACTION)
	_end_wave_early()


# Wave 2 - hands over to the next wave once only a quarter of its astroids
# are still on screen (see _end_wave_early()). (The golden astroid that used to park
# here at the end was removed 2026-11-18 - golden astroids now first show up
# mixed into wave 3's drops.)
func _wave_2() -> void:
	_set_abilities(true, false, false)    # shooting unlocked, no absorbing yet
	begin_challenge({
		"title": "Shoot",
		"text": "Hold J to fire. Damaging enemies fills your multiplier.",
		"challenge": "Destroy 10 astroids",
		"kind": CHALLENGE_DESTROY_ASTROIDS,
		"target": 10,
		"retry_line": "Looks like there's still a lot more asteroids to clear.",
	})
	# Dialogue + card only the first time (not when the wave replays).
	if not is_retry():
		await talk([
			{"text": "That was awesome! How you got a ship to jump in the vacuum of space, I'll never know. Now, time to see what kind of firepower we are working with. Your ship has blasters right?", "portrait": FACE_RED,"speaker": "Red Frog"},
			{"text": "Yup.","portrait": FACE_NEUTRAL,"speaker": "Frog"},
			{"text": "Of course it does, it's regulation. Why don't you use those blasters to clear out some of this asteroid field.","portrait": FACE_RED,"speaker": "Red Frog"},
			{"text": "Funny story, I was actually supposed to clear these out this morning, but got trapped in a convo with Gary. It was about his kids again.", "portrait": FACE_RED,"speaker": "Red Frog"},
			{"text": "You'd actually be doing me a huge favor by clearing these out.","portrait": FACE_RED,"speaker": "Red Frog"},
		], FROG)

		# Tutorial card: shooting. Pauses until the player closes it.
		await show_info({
			"title": "Shoot",
			"video": TUTORIAL_SHOOT_VIDEO,
			"keys": [["J"]],
			"key_timeline": TUTORIAL_SHOOT_KEYS,
			"text": "Hold J to fire. Damaging enemies fills your multiplier.",
		})
	show_challenge()   # instructions + challenge fade in now that the talking's done

	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.1, "end_side": Side.BOTTOM, "end_percent": 0.1, "speed": 45, "start_delay": 0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.2, "end_side": Side.BOTTOM, "end_percent": 0.2, "speed": 45, "start_delay": 0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.3, "end_side": Side.BOTTOM, "end_percent": 0.3, "speed": 45, "start_delay": 0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.4, "end_side": Side.BOTTOM, "end_percent": 0.4, "speed": 45, "start_delay": 0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.5, "end_side": Side.BOTTOM, "end_percent": 0.5, "speed": 45, "start_delay": 0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.6, "end_side": Side.BOTTOM, "end_percent": 0.6, "speed": 45, "start_delay": 0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.7, "end_side": Side.BOTTOM, "end_percent": 0.7, "speed": 45, "start_delay": 0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.8, "end_side": Side.BOTTOM, "end_percent": 0.8, "speed": 45, "start_delay": 0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.9, "end_side": Side.BOTTOM, "end_percent": 0.9, "speed": 45, "start_delay": 0})
	
	spawn_drift_wave({"enemy": ASTROID_MEDIUM, "start_side": Side.TOP, "start_percent": 0.5, "end_side": Side.BOTTOM, "end_percent": 0.5, "speed": 30, "start_delay": 2})
	
	spawn_drift_wave({"enemy": ASTROID_MEDIUM, "start_side": Side.TOP, "start_percent": 0.5, "end_side": Side.BOTTOM, "end_percent": 0.5, "speed": 30, "start_delay": 6})
	spawn_drift_wave({"enemy": ASTROID_MEDIUM, "start_side": Side.TOP, "start_percent": 0.6, "end_side": Side.BOTTOM, "end_percent": 0.8, "speed": 30, "start_delay": 6})
	spawn_drift_wave({"enemy": ASTROID_MEDIUM, "start_side": Side.TOP, "start_percent": 0.4, "end_side": Side.BOTTOM, "end_percent": 0.1, "speed": 30, "start_delay": 6})
	
	spawn_diagonal_astroid_wall({"from_corner": "top_right", "enemy": ASTROID_SMALL, "speed": 30.0, "spacing": 18.0, "start_delay": 11.0})
	spawn_diagonal_astroid_wall({"from_corner": "top_left", "enemy": ASTROID_SMALL, "speed": 30.0, "spacing": 18.0, "start_delay": 15.0})

	# Hand over to the next wave once only a quarter of what's left is still
	# on screen (after the last wall has come in), instead of waiting for
	# every astroid to clear.
	while _pending_spawns > 0 and is_inside_tree():   # everything has spawned
		await wait(0.1)
	await _wait_until_mostly_gone(get_tree().get_nodes_in_group("enemies"), EARLY_END_ON_SCREEN_FRACTION)
	_end_wave_early()


# Wave 3 - absorb. Small astroids, gray bees and the odd golden astroid fall
# from top to bottom at a steady beat (ABSORB_DROP_* below - roughly 65% /
# 30% / 5%) until the player builds up their multiplier and absorbs a gray
# bee for the gray transformation. Shooting stays on so the astroids can
# charge the multiplier; jumping stays off.
const ABSORB_DROP_INTERVAL := 0.7        # seconds between drops - several things on screen at once
const ABSORB_DROP_SMALL_CHANCE := 0.65   # small astroid
const ABSORB_DROP_BEE_CHANCE := 0.30     # gray bee - whatever's left (5%) is a golden astroid
const ABSORB_DROP_MIN_LANE_GAP := 0.15   # a drop never lands right on top of the one before it (wave 5a too)

func _wave_3() -> void:
	_set_abilities(true, false, true)    # absorbing (K + absorb-ready border) unlocked
	begin_challenge({
		"title": "Absorb",
		"text": "Shoot asteroids without taking damage to charge up your multiplier. At 4x multiplier (when your ship glows), press K to fire an absorb beam. Hit an enemy ship with an absorb beam to temporarily absorb its ability.",
		"challenge": "Absorb an enemy ship",
		"kind": CHALLENGE_ABSORB,
	})
	if not is_retry():
		await talk([
			{"text": "Looks like there are some broken down enemy ships floating around. Not uncommon in this belt but it is a little ominous. We shouldn't leave them just lying around.", "portrait": FACE_RED,"speaker": "Red Frog"},
			{"text": "Sorry I roped you into helping me clear the asteroid belt. I wish there weren't so many annoying rocks floating around.", "portrait": FACE_RED,"speaker": "Red Frog"},
			{"text": "I could use my Phase Absorption.", "portrait": FACE_NEUTRAL,"speaker": "Frog"},
			{"text": "Brilliant! Hyper-grafting other ships parts onto yours for a temporary boost. That'd make this go way faster! Wait, your ship can do that?!?", "portrait": FACE_RED,"speaker": "Red Frog"},
			{"text": "Yup.", "portrait": FACE_NEUTRAL,"speaker": "Frog"},
			{"text": "What a humble little genius you are.", "portrait": FACE_RED,"speaker": "Red Frog"},
		], FROG)

		# Tutorial card: absorbing. Pauses until the player closes it.
		await show_info({
			"title": "Absorb",
			"video": TUTORIAL_ABSORB_VIDEO,
			"keys": [["K"]],
			"key_timeline": TUTORIAL_ABSORB_KEYS,
			"text": "Shoot asteroids without taking damage to charge up your multiplier. At 4x multiplier (when your ship glows), press K to fire an absorb beam. Hit an enemy ship with an absorb beam to temporarily absorb its ability.",
		})
	show_challenge()   # instructions + challenge fade in now that the talking's done

	# Keeps going until the absorb lands (see _mixed_drops_until_done()).
	await _mixed_drops_until_done(ABSORB_DROP_INTERVAL, ABSORB_DROP_SMALL_CHANCE, ABSORB_DROP_BEE_CHANCE)

	# Right after the absorb: the Transformations card (boosts are temporary,
	# flashing = about to run out). Waits for the absorb to finish and the
	# ability-acquired flash to play first.
	if _challenge_state == ChallengeState.DONE and not is_retry():
		while player and player.currently_absorbing:
			await get_tree().process_frame
		await wait(0.6)
		if not is_inside_tree():
			return
		await show_info({
			"title": "Transformations",
			"video": TUTORIAL_RUNOUT_VIDEO,
			"text": "Transformations give you different boosts, but they're temporary. When your ship starts flashing, the transformation is about to run out.",
		})

	# Hand over to wave 3b once only a quarter of what's still falling is on
	# screen, instead of waiting for all of it to leave.
	await _wait_until_mostly_gone(get_tree().get_nodes_in_group("enemies"), EARLY_END_ON_SCREEN_FRACTION)
	_end_wave_early()


## Mixed drops (waves 3 and 5a): one thing every `interval` seconds, picked
## at random - a small astroid (`small_chance`), a gray bee (`bee_chance`) or
## else a golden astroid - straight down a random lane. Stops once the
## challenge is done. hold_with_bubble = no drops while the player has a
## bubble out or is transformed. If _mixed_drops_time_limit() is above 0 it
## also stops after that many seconds (level_0.gd's practice run uses that).
func _mixed_drops_until_done(interval: float, small_chance: float, bee_chance: float, hold_with_bubble: bool = false) -> void:
	var time_limit := _mixed_drops_time_limit()
	var elapsed := 0.0
	var last_lane := -1.0
	while _challenge_state == ChallengeState.PENDING and (time_limit <= 0.0 or elapsed < time_limit):
		if hold_with_bubble and _player_has_bubble_power():
			if not await _wait_while_challenge_pending(0.25):
				return
			elapsed += 0.25
			continue
		last_lane = _spawn_mixed_drop(small_chance, bee_chance, last_lane)
		if not await _wait_while_challenge_pending(interval):
			return
		elapsed += interval


## One mixed drop: a small astroid (`small_chance`), a gray bee (`bee_chance`)
## or else a golden astroid, straight down a random lane that isn't right on
## top of `last_lane`. Returns the lane it used.
func _spawn_mixed_drop(small_chance: float, bee_chance: float, last_lane: float = -1.0) -> float:
	var lane := randf_range(0.1, 0.9)
	while last_lane >= 0.0 and absf(lane - last_lane) < ABSORB_DROP_MIN_LANE_GAP:
		lane = randf_range(0.1, 0.9)
	var roll := randf()
	if roll < small_chance:
		spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": lane, "end_side": Side.BOTTOM, "end_percent": lane, "speed": 45})
	elif roll < small_chance + bee_chance:
		spawn_drift_wave({"enemy": GRAY_BEE, "start_percent": lane, "speed": 30})
	else:
		spawn_drift_wave({"enemy": ASTROID_GOLDEN, "start_percent": lane, "speed": 35})
	return lane


## Wave 5c's drops: same mix and rate as the resupply drops, but they never
## hold - they keep coming whether or not the player has a bubble out or is
## transformed, for as long as any bomb ring is left (even after the
## challenge is failed, like the old supply drops).
func _resupply_while_bomb_rings_left() -> void:
	await get_tree().process_frame   # let run_bomb_ring_challenge() put the rings up first
	var last_lane := -1.0
	while is_inside_tree() and bomb_rings_left():
		last_lane = _spawn_mixed_drop(RESUPPLY_DROP_SMALL_CHANCE, RESUPPLY_DROP_BEE_CHANCE, last_lane)
		if not await _wait_while_bomb_rings_left(RESUPPLY_DROP_INTERVAL):
			return


## Seconds the mixed drops run before giving up - 0 = no limit (keep going
## until the challenge is done). level_0.gd overrides this.
func _mixed_drops_time_limit() -> float:
	return 0.0


# Wave 3b - bubbles. Starts with what used to be wave 4 (Red Frog reacting to
# the new form, then the Bubbles card), then the resupply drops
# (RESUPPLY_DROP_*, held while the player has a bubble out or is
# transformed) until all 3 green target bubbles (bullets/
# target_bubble.gd) have been absorbed by bouncing a bubble into them.
# Shooting or flying through a target just scatters it for a moment.
# Re-absorbing a bee gives a fresh bubble to try with.
# Loaded by path (not the TargetBubble class_name) so this script never
# depends on Godot's global class list having picked up the new file.
const TargetBubbleScript := preload("res://bullets/target_bubble.gd")
const TARGET_BUBBLE_SPOTS := [   # screen fractions (x, y)
	Vector2(0.25, 0.22),
	Vector2(0.75, 0.30),
	Vector2(0.50, 0.45),
]

func _wave_3b() -> void:
	_set_abilities(true, false, true)
	begin_challenge({
		"title": "Bubbles",
		"text": "While transformed, press K to give up the transformation and shoot it out as a bubble. Bounce the bubble off your ship into the green bubbles to capture them.",
		"challenge": "Capture all 3 green bubbles with your bubble",
		"kind": CHALLENGE_POP_TARGETS,
		"target": TARGET_BUBBLE_SPOTS.size(),
	})
	if not is_retry():
		# The absorb beam removes the bee the moment it hits, BEFORE the
		# player transforms, so wait for the absorb to finish first.
		while player and player.currently_absorbing:
			await get_tree().process_frame
		await talk([
			{"text": "Hmmmm, the changes aren't too drastic. I guess since it's using scrap ships. Still I noticed your ship does seem faster and stronger.", "portrait": FACE_RED,"speaker": "Red Frog"},
			{"text": "There are some cosmic bubbles ahead. Tricky little things. Shooting them won't cut it.", "portrait": FACE_RED,"speaker": "Red Frog"},
			{"text": "Ah frogs! I was supposed to grab the bubble blaster to recapture these, but I forgot it at base. Guess I'll have to grab them after this training. It'll be a late lunch for me.", "portrait": FACE_RED,"speaker": "Red Frog"},
			{"text": "My ship has bubble capabilities.", "portrait": FACE_NEUTRAL,"speaker": "Frog"},
			{"text": "Wait really! If you use your bubbles to snag these it'll save me a fin and a flipper. I'd promise to treat you to lunch after!", "portrait": FACE_RED,"speaker": "Red Frog"},
			{"text": "No need to bother. It's no extra effort.", "portrait": FACE_NEUTRAL,"speaker": "Frog"},
		], FROG)

		# Tutorial card: trading a transformation in for a bubble. (The
		# Transformations card now shows at the end of wave 3, right after
		# the absorb.)
		await show_info({
			"title": "Bubbles",
			"video": TUTORIAL_BUBBLE_VIDEO,
			"keys": [["K"]],
			"key_timeline": TUTORIAL_BUBBLE_KEYS,
			"text": "While transformed, press K to give up the transformation and shoot it out as a bubble. Bounce the bubble off your ship into the green bubbles to capture them.",
		})
	show_challenge()   # instructions + challenge fade in now that the talking's done
	_spawn_target_bubbles()   # after the talking, so they fall in while you watch

	# Resupply drops (small astroids, gray bees, golden astroids) - held while
	# the player is transformed or has a bubble on screen.
	await _mixed_drops_until_done(RESUPPLY_DROP_INTERVAL, RESUPPLY_DROP_SMALL_CHANCE, RESUPPLY_DROP_BEE_CHANCE, true)
	_clear_target_bubbles()   # level_0.gd's practice run ends the wave with some still up
	if _challenge_state == ChallengeState.DONE:
		say("Look at you go.", RED_FROG)
		_end_wave_early(EARLY_END_HOLD_3B)   # next wave right after the objective


## Puts up the 3 target bubbles for wave 3b (clearing any left from before).
## Each one starts just above the screen and falls into its spot.
const TARGET_BUBBLE_FALL_TIME := 1.6     # seconds to fall from the top into place
const TARGET_BUBBLE_FALL_STAGGER := 0.25 # each one starts this much after the last

func _spawn_target_bubbles() -> void:
	_clear_target_bubbles()
	var screen := get_viewport_rect().size
	var i := 0
	for spot in TARGET_BUBBLE_SPOTS:
		var home := Vector2(screen.x * spot.x, screen.y * spot.y)
		var t = TargetBubbleScript.new()
		t.home_position = home   # its resting spot (it drifts back here between nudges)
		t.position = home
		t.popped.connect(_on_target_bubble_popped)
		add_child(t)
		# Then lift it above the screen and let it fall into place.
		t.home_position = Vector2(home.x, -16.0)
		t.position = t.home_position
		var tw := t.create_tween()
		tw.tween_interval(TARGET_BUBBLE_FALL_STAGGER * i)
		tw.tween_property(t, "home_position", home, TARGET_BUBBLE_FALL_TIME) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		i += 1


func _clear_target_bubbles() -> void:
	for t in get_tree().get_nodes_in_group("target_bubble"):
		t.queue_free()


func _on_target_bubble_popped() -> void:
	if _challenge_pending(CHALLENGE_POP_TARGETS):
		_add_challenge_progress()


# Wave 5c - the bomb-ring encounter (same as levels/level_0.gd). 5a and 5b
# used to be bomb-ring waves too - they're now the green-astroid and the
# jump-on-bubble waves (below). It teaches ONE way to use a bubble with its own
# card, then runs base_level.gd's run_bomb_ring_challenge(): two bombs
# inside rings of armored astroids, with golden astroids and gray bees
# drifting down until every ring is gone. Combining two bubbles always grants
# Penetrator Rounds during it.

# Wave 5a - shoot the bubble to power it up. FILM_TARGET_SPOTS green
# astroids (coated in cosmic bubble fluid) drift in from the top and park.
# Only a powered-up bubble can hurt them - shots, bubble pops and everything
# else bounce off (BaseEnemy.set_damage_only_from()). A powered bubble does 1
# damage per charge and they have FILM_TARGET_HEALTH = 1, so each charge = one
# astroid. Jumping is off for the whole wave.
# While the player has no bubble out and isn't transformed, the resupply
# drops (RESUPPLY_DROP_*) fall so they can earn a bubble; they stop as soon
# as they have one.
const FILM_TARGET_SPOTS := TARGET_BUBBLE_SPOTS   # same spots as wave 3b's green bubbles
const FILM_TARGET_HEALTH := 1
const FILM_TARGET_SPEED := 40.0       # px/s drifting in from the top before they park
const FILM_TARGET_COLOR := Color(0.35, 1.0, 0.6, 1.0)   # same mint green as the target bubbles (bullets/target_bubble.gd)
const FILM_TARGET_TINT := Color(0.7, 1.0, 0.8, 1.0)     # light green wash over the astroid sprite
const FILM_DAMAGE_SOURCES := ["bubble_charged", "bubble_shot_charged"]   # a powered-up bubble's hits (bullets/bubble.gd)

func _wave_5a() -> void:
	_set_abilities(true, false, true)    # no jumping
	begin_challenge({
		"title": "Using Bubbles: Shoot",
		"text": "Shoot (J) a bubble to power it up. A powered-up bubble damages the enemies and objects it hits.",
		"challenge": "Destroy the %d asteroids with a powered-up bubble" % FILM_TARGET_SPOTS.size(),
		"kind": CHALLENGE_FILM_TARGETS,
		"target": FILM_TARGET_SPOTS.size(),
	})
	_clear_film_targets()
	for spot in FILM_TARGET_SPOTS:
		_spawn_film_target(spot)
	# Dialogue + card only the first time (not when the wave replays).
	if not is_retry():
		await talk([
			{"text": "These asteroids look a bit different. Fun fact, they actually coated in cosmic bubble fluid."},
			{"text": "The film from the fluid is enough to disrupt the bullet integrity. Let me just dig into my notes and if there's something we can do, apart from getting out of our ships and cleaning off the film ourselves."},
			{"text": "Bubble energy assimilation.", "portrait": FACE_NEUTRAL,"speaker": "Frog"},
			{"text": "That won't wo...wait a minute. THAT'S GENIUS!!!"},
			{"text": "The stability of the bubble should be able to soak up the energy from your bullets and collide with the asteroid with enough power to disrupt its disruption."},
			{"text": "It was a natural conclusion from your paper on bubble composition and surface tension.", "portrait": FACE_NEUTRAL,"speaker": "Frog"},
			{"text": "Aw shucks. You actually read that thing? Guess we're both geniuses then."},
		], RED_FROG)

		await show_info({
			"title": "Using Bubbles: Shoot",
			"video": TUTORIAL_BUBBLE_SHOOT_CARD_VIDEO,
			"keys": [["J"]],
			"key_timeline": TUTORIAL_BUBBLE_SHOOT_CARD_KEYS,
			"text": "Shoot (J) a bubble to power it up. A powered-up bubble damages the enemies and objects it hits.",
		})
	show_challenge()   # instructions + challenge fade in now that the talking's done

	# Drops until every green astroid is gone, held while the player has a
	# bubble out or is transformed (see _mixed_drops_until_done()).
	await _mixed_drops_until_done(RESUPPLY_DROP_INTERVAL, RESUPPLY_DROP_SMALL_CHANCE, RESUPPLY_DROP_BEE_CHANCE, true)
	_clear_film_targets()   # level_0.gd's practice run ends the wave with some still up
	if _challenge_state == ChallengeState.DONE:
		say("Glad we got that all sorted.", RED_FROG)


## One green astroid that drifts in from the top and parks at `spot` (screen
## fractions) until a powered-up bubble destroys it.
func _spawn_film_target(spot: Vector2) -> void:
	var size := get_viewport_rect().size
	var x := size.x * spot.x
	var a = ASTROID_SMALL.instantiate()
	a.max_health = FILM_TARGET_HEALTH   # before add_child, so _ready() picks it up
	a.enemy_color = FILM_TARGET_TINT
	add_child(a)
	a.add_to_group("film_target")
	a.set_damage_only_from(FILM_DAMAGE_SOURCES, FILM_TARGET_COLOR)
	a.launch(Vector2(x, -16.0), Vector2(x, size.y), FILM_TARGET_SPEED)
	a.hold_at_y = size.y * spot.y
	a.died.connect(_on_enemy_died)
	a.died.connect(_on_film_target_died)
	note_spawn(0.0)


func _clear_film_targets() -> void:
	for t in get_tree().get_nodes_in_group("film_target"):
		t.queue_free()


func _on_film_target_died(_value: int) -> void:
	if _challenge_pending(CHALLENGE_FILM_TARGETS):
		_add_challenge_progress()


# Wave 5b - bubble use #2: jump on it. (Until 2026-11-06 this was "Using
# Bubbles: Shoot" with the bomb rings - shooting the bubble moved to 5a.)
# JUMP_MEDIUM_SPOTS armored (gray-outlined) medium astroids drift down and
# park on screen. Shots and plain jump landings bounce off the armor; the
# way through is to get a bubble next to one and jump on the bubble - the pop
# explosion breaks it. (Until 2026-11-18 a ring of armored astroids with a
# gray bubble pinned in its middle came first - removed.)
# The mediums get 3 armor, which soaks a plain jump landing (3 damage) and
# normal shots completely. Jumping on a bubble pops it for 5
# (bubble.gd JUMP_POP_DAMAGE_MULT): 5 - 3 armor = 2 = JUMP_TARGET_HEALTH, so
# one jump-pop finishes them.
# The resupply drops (RESUPPLY_DROP_*) fall only while the player has no
# bubble out and isn't transformed, so they can earn a bubble.
const JUMP_MEDIUM_SPOTS := [0.28, 0.72]   # across the screen (0-1)
const JUMP_MEDIUM_STOP_PERCENT := 0.3     # how far down they park
const JUMP_MEDIUM_SPEED := 30.0
const JUMP_TARGET_ARMOR := 3    # > plain jump landing damage (3), so only a jump-pop gets through
const JUMP_TARGET_HEALTH := 2   # jump-pop 5 - armor 3 = 2

var _jump_wave_active := false

func _wave_5b() -> void:
	_set_abilities(true, true, true)
	begin_challenge({
		"title": "Using Bubbles: Jump",
		"text": "Jump (L) on a bubble to pop it in a big explosion.",
		"challenge": "Jump on a bubble to destroy the %d armored astroids" % JUMP_MEDIUM_SPOTS.size(),
		"kind": CHALLENGE_JUMP_TARGETS,
		"target": JUMP_MEDIUM_SPOTS.size(),
	})
	_clear_jump_wave()
	_strip_bubble_power()   # start from scratch: no transformation, no bubbles out
	_jump_wave_active = true
	for x in JUMP_MEDIUM_SPOTS:
		_spawn_jump_medium(x)
	# Dialogue + card only the first time (not when the wave replays).
	if not is_retry():
		await talk([
			{"text": "Now these asteroids are looking a bit sturdier. While your ship is impressive, I'm not sure if the firepower is enough to deal with these."},
			{"text": "I should be able to clear these out quickly. Promise not to deduct any points since you've been helping me out so much."},
			{"text": "I got it.", "portrait": FACE_NEUTRAL,"speaker": "Frog"},
			{"text": "Not sure how, but I can't say you haven't surprised me before."},
		], RED_FROG)

		await show_info({
			"title": "Using Bubbles: Jump",
			"video": TUTORIAL_JUMP_ON_VIDEO,
			"keys": [["L"]],
			"key_timeline": TUTORIAL_JUMP_ON_KEYS,
			"text": "Jump (L) on a bubble to pop it in a big explosion.",
		})
	show_challenge()   # instructions + challenge fade in now that the talking's done

	await _mixed_drops_until_done(RESUPPLY_DROP_INTERVAL, RESUPPLY_DROP_SMALL_CHANCE, RESUPPLY_DROP_BEE_CHANCE, true)
	_jump_wave_active = false
	_clear_jump_wave()   # level_0.gd's practice run ends the wave with some still up
	if _challenge_state == ChallengeState.DONE:
		say("Guess you really did got it.", RED_FROG)
		_end_wave_early(EARLY_END_HOLD_5B)   # straight on to 5c instead of waiting for the screen to clear


## Wave 5b starts the player off with nothing: ends any transformation they
## carried over and removes every bubble on screen (no pop, they just vanish).
func _strip_bubble_power() -> void:
	if player and is_instance_valid(player) and player.current_form != 'default':
		player.revert_absorption()
	for b in get_tree().get_nodes_in_group("bubble"):
		if is_instance_valid(b):
			b.queue_free()


## One armored medium astroid that drifts down and parks until destroyed.
func _spawn_jump_medium(x_percent: float) -> void:
	var size := get_viewport_rect().size
	var x := size.x * x_percent
	var a = ASTROID_MEDIUM.instantiate()
	a.max_health = JUMP_TARGET_HEALTH   # before add_child, so _ready() picks it up
	add_child(a)
	a.add_to_group("jump_medium")
	a.launch(Vector2(x, -20.0), Vector2(x, size.y), JUMP_MEDIUM_SPEED)
	a.hold_at_y = size.y * JUMP_MEDIUM_STOP_PERCENT
	a.set_armor(JUMP_TARGET_ARMOR)
	a.died.connect(_on_enemy_died)
	a.died.connect(_on_jump_medium_died)
	note_spawn(0.0)


func _on_jump_medium_died(_value: int) -> void:
	if _challenge_pending(CHALLENGE_JUMP_TARGETS):
		_add_challenge_progress()


## Removes anything left from this wave (the mediums).
func _clear_jump_wave() -> void:
	for group in ["jump_medium"]:
		for n in get_tree().get_nodes_in_group(group):
			n.queue_free()


# Wave 5c - bubble use #3: combine two.
# Two bomb rings, left and right - the default layout minus the middle ring
# (base_level.gd DEFAULT_BOMB_RINGS). No start delay since nothing has to get
# out of the middle ring's way.
const WAVE_5C_BOMB_RINGS := [
	{"center_percent": 0.25, "stop_percent": 0.2},
	{"center_percent": 0.75, "stop_percent": 0.2},
]

func _wave_5c() -> void:
	_set_abilities(true, true, true)
	begin_challenge({
		"title": "Using Bubbles: Combine",
		"text": "Combine two bubbles to get a permanent buff.",
		"challenge": "Destroy both bombs with Penetrator Rounds without taking damage from a bomb",
		"kind": CHALLENGE_BOMBS,
		"target": WAVE_5C_BOMB_RINGS.size(),
		"method": BOMB_METHOD_COMBINE,
		"no_bomb_damage": true,   # getting caught in a bomb blast fails it too (other hits don't)
		"fail_line": "Ouch. Looks like that hurt.",
		"retry_line": "Dang even more mines. Don't know what's more of a minefield, this or a conversation with accounting?",
	})
	# Dialogue + card only the first time (not when the wave replays).
	if not is_retry():
		await talk([
			{"text": "Looks like there are some old mines floating around this asteroid field. There's a lot of dangerous stuff here. Guess that's why they asked me to clean it huh."},
			{"text": "I would ask you to just hop on the mines but I wouldn't want you damaging your precious ship. Got any other neat tricks to deal with this?"},
			{"text": "Do I!", "portrait": FACE_NEUTRAL,"speaker": "Frog"},
			{"text": "Do you?"},
		], RED_FROG)

		await show_info({
			"title": "Using Bubbles: Combine",
			"video": TUTORIAL_BUBBLE_COMBINE_VIDEO,
			"text": "Combine two bubbles to get a permanent buff.",
		})
	show_challenge()   # instructions + challenge fade in now that the talking's done

	# Resupply drops (RESUPPLY_DROP_*) all the way through - unlike 3b / 5a /
	# 5b they don't stop while the player has a bubble or transformation.
	_resupply_while_bomb_rings_left()   # not awaited - runs alongside the rings
	await run_bomb_ring_challenge({"rings": WAVE_5C_BOMB_RINGS, "supply": false})
	
# Wave 6 - the final exam. Everything from the earlier waves, one after the
# other, building up:
#   1. Dodge + shoot  - staggered astroid columns with gaps to slip through,
#                       and medium astroids that split when shot.
#   2. Gold + absorb  - a golden astroid (shoot it for 4x) and a gray bee
#                       right behind it (absorb it with K for the gray form).
#   3. Jump           - two diagonal astroid walls that can only be jumped,
#                       then a big astroid ring to jump into and back out of.
#   4. Bombs          - two bomb rings (run_bomb_ring_challenge in
#                       base_level.gd) with golden astroid / gray bee supply
#                       drops. Bubble fusions grant a RANDOM power-up here
#                       ("fusion_powerup": ""), not just Penetrator Rounds.
# The phases overlap a little (each phase starts while the last one's
# stragglers are still on screen) so it feels like one continuous run.
func _wave_6() -> void:
	_set_abilities(true, true, true)
	begin_challenge({
		"title": "Final Exam",
		"text": "Use everything you've learned: move, jump, shoot, absorb and bubbles.",
		"challenge": "Make it to the end without losing all your health",
		"kind": CHALLENGE_SURVIVE,
	})
	# Dialogue + card only the first time (not when the wave replays).
	if not is_retry():
		await talk([
			{"text": "And check! Mandatory training requirements fulfilled. Guess all that's left is for you to get back to base."},
			{"text": "I normally wouldn't ask this of a testee, but given you passed with flying colors, you shouldn't have any problems getting through this next part right?"},
			{"text": "No sweat.", "portrait": FACE_NEUTRAL,"speaker": "Frog"},
			{"text": "The only one sweating was me before you came along and cleared out this place for me. Thanks again! I'll have to treat you to a lotus bun when we get back."},
		], RED_FROG)
	show_challenge()   # instructions + challenge fade in now that the talking's done

	# --- 1. Dodge + shoot ---
	var gaps := [0.5, 0.3, 0.7, 0.2, 0.8]
	for row in gaps.size():
		for lane in [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9]:
			if absf(lane - gaps[row]) < 0.15:
				continue   # leave a gap for the ship
			spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": lane, "end_side": Side.BOTTOM, "end_percent": lane, "speed": 45, "start_delay": row * 2.0})
	spawn_drift_wave({"enemy": ASTROID_MEDIUM, "start_side": Side.TOP, "start_percent": 0.2, "end_side": Side.BOTTOM, "end_percent": 0.6, "speed": 30, "start_delay": 3.0})
	spawn_drift_wave({"enemy": ASTROID_MEDIUM, "start_side": Side.TOP, "start_percent": 0.8, "end_side": Side.BOTTOM, "end_percent": 0.4, "speed": 30, "start_delay": 6.0})
	# Gray hive down the left side, right after the second medium astroid.
	spawn_drift_wave({"enemy": GRAY_HIVE, "start_side": Side.TOP, "start_percent": 0.2, "end_side": Side.BOTTOM, "end_percent": 0.2, "speed": 25, "start_delay": 8.5})
	await wait(11.0)

	# --- 2. Jump ---
	spawn_diagonal_astroid_wall({"from_corner": "top_left", "enemy": ASTROID_SMALL, "speed": 40.0, "spacing": 18.0, "start_delay": 0.0})
	spawn_diagonal_astroid_wall({"from_corner": "top_right", "enemy": ASTROID_SMALL, "speed": 40.0, "spacing": 18.0, "start_delay": 5.0})
	# Two gray bees drifting down with the walls.
	spawn_drift_wave({"enemy": GRAY_BEE, "start_side": Side.TOP, "start_percent": 0.75, "end_side": Side.BOTTOM, "end_percent": 0.75, "speed": 25, "start_delay": 1.0})
	spawn_drift_wave({"enemy": GRAY_BEE, "start_side": Side.TOP, "start_percent": 0.25, "end_side": Side.BOTTOM, "end_percent": 0.25, "speed": 25, "start_delay": 6.0})
	# Big astroid ring with a bomb ring in its middle. Same start point, speed
	# and start_delay, so the bomb ring stays centered as they fall together;
	# keep_moving means it never stops and just leaves off the bottom.
	var big_ring_radius: float = get_viewport_rect().size.x * 0.5 - 10.0
	var ring_speed := 45.0
	var ring_delay := 10.0
	spawn_astroid_ring({"enemy": ASTROID_SMALL, "radius": big_ring_radius, "speed": ring_speed, "spacing": 18.0, "start_delay": ring_delay})
	spawn_bomb_ring({"center_percent": 0.5, "speed": ring_speed, "start_delay": ring_delay, "keep_moving": true, "start_y": -big_ring_radius - FORMATION_ENTRY_MARGIN})
	await wait(18.0)

	# --- 3. Bombs ---
	# Walls + medium astroids sweeping through while the bomb rings sit there.
	for i in 4:
		var corner: String = "top_left" if i % 2 == 0 else "top_right"
		spawn_diagonal_astroid_wall({"from_corner": corner, "enemy": ASTROID_SMALL, "speed": 40.0, "spacing": 18.0, "start_delay": 4.0 + i * 6.0})
	spawn_drift_wave({"enemy": ASTROID_MEDIUM, "start_side": Side.TOP, "start_percent": 0.15, "end_side": Side.BOTTOM, "end_percent": 0.5, "speed": 30, "start_delay": 1.0})
	spawn_drift_wave({"enemy": ASTROID_MEDIUM, "start_side": Side.TOP, "start_percent": 0.85, "end_side": Side.BOTTOM, "end_percent": 0.5, "speed": 30, "start_delay": 7.0})
	spawn_drift_wave({"enemy": ASTROID_MEDIUM, "start_side": Side.TOP, "start_percent": 0.5, "end_side": Side.BOTTOM, "end_percent": 0.2, "speed": 30, "start_delay": 13.0})
	spawn_drift_wave({"enemy": ASTROID_MEDIUM, "start_side": Side.TOP, "start_percent": 0.5, "end_side": Side.BOTTOM, "end_percent": 0.8, "speed": 30, "start_delay": 19.0})
	# Two gray flowers to absorb.
	spawn_drift_wave({"enemy": GRAY_FLOWER, "start_side": Side.TOP, "start_percent": 0.8, "end_side": Side.BOTTOM, "end_percent": 0.8, "speed": 20, "start_delay": 5.0})
	spawn_drift_wave({"enemy": GRAY_FLOWER, "start_side": Side.TOP, "start_percent": 0.2, "end_side": Side.BOTTOM, "end_percent": 0.2, "speed": 20, "start_delay": 15.0})

# Wave 7 - outro. No challenge, so the right panel goes away.
func _wave_7() -> void:
	_set_abilities(true, true, true)
	clear_challenge()
	await talk([
		{"text": "A+, gold star, some third thing!"},
		{"text": "Let's celebrate a job well done, root beer floating flies on me!"},
		{"text": "Can't.", "portrait": FACE_NEUTRAL,"speaker": "Frog"},
		{"text": "Oh yeah, of course. I'm sure you have a ton of other work to do."},
		{"text": "...", "portrait": FACE_NEUTRAL,"speaker": "Frog"},
		{"text": "..."},
		{"text": "Maybe next time?", "portrait": FACE_NEUTRAL,"speaker": "Frog"},
		{"text": "Next time would be great! I'll hold you to it."},
	], RED_FROG)

func _ready() -> void:
	level_paths = {
		"next_level": "res://levels/test_menu.tscn"
	}
	waves = [_wave_intro, _wave_1, _wave_2, _wave_3, _wave_3b, _wave_5a, _wave_5b, _wave_5c, _wave_6, _wave_7]
	fallback_enemy = FLOWER
	super._ready()   # sets max_waves = waves.size(), so the level ends after the last wave
	# No dying in the tutorial - Red Frog makes a crack and the health refills.
	if player:
		player.prevent_death = true
		player.death_prevented.connect(_on_player_out_of_health)
		# Hits count toward wave 1's challenge (see _on_player_shield_changed()).
		_last_shield = player.shield
		player.shield_changed.connect(_on_player_shield_changed)
	# Astroids, bombs and bubbles are hooked up as they spawn, for the
	# challenges (see _on_node_added()).
	get_tree().node_added.connect(_on_node_added)


var _refilling_health := false

func _on_player_out_of_health() -> void:
	if _refilling_health:
		return
	_refilling_health = true
	# Losing all your health fails the "don't lose all your health" challenges.
	if _challenge_pending(CHALLENGE_SURVIVE):
		_fail_challenge()
	say("Let me fix up your ship. Wouldn't want you stranded here in space.", RED_FROG)
	# Short beat at empty so the line lands, then fill back up. The hit that
	# emptied the bar already started the 1s hit invincibility, so nothing
	# can land in between.
	await wait(0.6)
	if is_instance_valid(player):
		player.heal(player.max_shield)
	_refilling_health = false
