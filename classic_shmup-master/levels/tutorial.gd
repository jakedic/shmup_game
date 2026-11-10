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
#   1      take damage fewer than 3 times
#   2      destroy 10 astroids
#   3      absorb an enemy (golden astroids + gray bees keep coming until you do)
#   3b     absorb all 3 green target bubbles by bouncing a bubble into them
#          (same supply, plus random astroids). Shooting / flying through
#          a target only scatters it for a moment - see bullets/target_bubble.gd
#   5a     cosmic storm: destroy the 4 astroids parked in it with a
#          shot-powered bubble (no shooting inside the storm, no jumping)
#   5b     jump on bubbles: pop the caged bubble to break its armored ring,
#          then destroy 2 armored medium astroids the same way
#   5c     set off all 3 bombs with Penetrator Rounds (combine two bubbles)
#          without taking any damage
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
#                   (on top of whatever its kind asks for). Wave 5c uses it.
const CHALLENGE_SURVIVE := "survive"            # don't lose all your health - passes when the wave ends
const CHALLENGE_MAX_HITS := "max_hits"          # get hit fewer than `target` times - passes when the wave ends
const CHALLENGE_DESTROY_ASTROIDS := "astroids"  # destroy `target` astroids (gray bees don't count)
const CHALLENGE_ABSORB := "absorb"              # absorb any enemy
const CHALLENGE_BUBBLE_BOUNCES := "bounces"     # bounce ONE bubble off the ship `target` times
const CHALLENGE_BOMBS := "bombs"                # set off `target` bombs, every one with `method`
const CHALLENGE_POP_TARGETS := "targets"        # absorb `target` TargetBubbles by bouncing a bubble into them
const CHALLENGE_STORM_TARGETS := "storm"        # destroy `target` of wave 5a's storm astroids
const CHALLENGE_JUMP_TARGETS := "jump_targets"  # destroy `target` of wave 5b's armored medium astroids

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

# Waves 3 / 3b: a golden astroid, then a gray bee a bit later, in random lanes,
# over and over until the challenge is done (like the bomb-ring supply drops).
const SUPPLY_LANES := [0.15, 0.3, 0.5, 0.7, 0.85]
const SUPPLY_BEE_DELAY := 2.5      # seconds after the golden astroid that the bee follows
const SUPPLY_INTERVAL := 11.0      # seconds between golden astroids
# Wave 3b's extra random astroids (top to bottom).
const RANDOM_ASTROID_GAP_MIN := 2.0   # was 1.2 - dialed back 2026-11-06 (about a third fewer astroids)
const RANDOM_ASTROID_GAP_MAX := 3.5   # was 2.4
const RANDOM_ASTROID_MEDIUM_CHANCE := 0.2

# Wave 0's astroids - 20% faster than the 45 px/s the rest of the tutorial uses.
const WAVE_0_ASTROID_SPEED := 54.0

var _challenge: Dictionary = {}
var _challenge_state := ChallengeState.PENDING
var _challenge_count := 0       # astroids destroyed / hits taken / best bounce / bombs done
var _retrying := false          # true while a wave is replaying after a failed challenge
var _wave_ending := false       # in the "ticked" hold or the retry countdown
var _challenge_shown := false   # panel is held back until the wave's dialogue is done (show_challenge())
var _last_shield := -1
var _random_astroid_timer := 0.0
# When true, _supply_until_challenge_done() holds each golden astroid + gray
# bee drop until the player has no bubble out and isn't transformed (wave 5a).
var _supply_only_when_needed := false


## Set this wave's instructions + challenge and reset its progress. Also tops
## the player's health back up, so a rough previous wave can't doom this one.
## The right side panel stays hidden until show_challenge() - call that once
## the wave's dialogue and cards are done.
func begin_challenge(config: Dictionary) -> void:
	_challenge = config
	_challenge_state = ChallengeState.PENDING
	_challenge_count = 0
	_challenge_shown = false
	_supply_only_when_needed = false   # only wave 5a turns this on
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
		CHALLENGE_DESTROY_ASTROIDS, CHALLENGE_BUBBLE_BOUNCES, CHALLENGE_BOMBS, CHALLENGE_POP_TARGETS, CHALLENGE_STORM_TARGETS, CHALLENGE_JUMP_TARGETS:
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
	await wait(CHALLENGE_DONE_HOLD)   # let the ticked box sink in
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


# --- What counts toward each challenge ---

func _on_node_added(node: Node) -> void:
	if node is BombEnemy:
		node.died.connect(_on_bomb_died.bind(node))
	elif node is AstroidEnemy and not (node is GrayEnemy):
		node.died.connect(_on_astroid_destroyed)
	elif node is Bubble:
		node.bounced_off_player.connect(_on_bubble_bounced)


func _on_astroid_destroyed(_value: int) -> void:
	if _challenge_pending(CHALLENGE_DESTROY_ASTROIDS):
		_add_challenge_progress()


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
	_update_storm_blasters()


# --- Waves 3 / 3b supply drops ---

## Golden astroid, then a gray bee, in random lanes, over and over until the
## current challenge is done. random_astroids = also send plain astroids down
## the screen at random in between. Returns once the challenge is done.
func _supply_until_challenge_done(random_astroids: bool = false) -> void:
	_random_astroid_timer = 0.0
	while _challenge_state == ChallengeState.PENDING:
		# Hold the drop while the player still has a bubble / transformation.
		while _supply_only_when_needed and _player_has_bubble_power():
			if not await _wait_while_challenge_pending(0.25, random_astroids):
				return
		var gold_lane: float = SUPPLY_LANES.pick_random()
		spawn_drift_wave({"enemy": ASTROID_GOLDEN, "start_percent": gold_lane, "speed": 35})
		if not await _wait_while_challenge_pending(SUPPLY_BEE_DELAY, random_astroids):
			return
		var bee_lane: float = SUPPLY_LANES.pick_random()
		while is_equal_approx(bee_lane, gold_lane):
			bee_lane = SUPPLY_LANES.pick_random()
		spawn_drift_wave({"enemy": GRAY_BEE, "start_percent": bee_lane, "speed": 30})
		if not await _wait_while_challenge_pending(SUPPLY_INTERVAL - SUPPLY_BEE_DELAY, random_astroids):
			return


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
func _wait_while_challenge_pending(seconds: float, random_astroids: bool) -> bool:
	var remaining := seconds
	while remaining > 0.0:
		var step: float = minf(0.25, remaining)
		await wait(step)
		if not is_inside_tree():
			return false
		remaining -= step
		if _challenge_state != ChallengeState.PENDING:
			return false
		if random_astroids:
			_random_astroid_timer -= step
			if _random_astroid_timer <= 0.0:
				_random_astroid_timer = randf_range(RANDOM_ASTROID_GAP_MIN, RANDOM_ASTROID_GAP_MAX)
				var medium := randf() < RANDOM_ASTROID_MEDIUM_CHANCE
				var lane := randf_range(0.08, 0.92)
				spawn_drift_wave({
					"enemy": ASTROID_MEDIUM if medium else ASTROID_SMALL,
					"start_percent": lane,
					"end_percent": clampf(lane + randf_range(-0.15, 0.15), 0.05, 0.95),
					"speed": randf_range(30.0, 40.0) if medium else randf_range(40.0, 60.0),
				})
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

# Wave 5a card clip: in the cosmic storm, K shoots out a bubble, J shots
# power it up from the clear strip, and it flies up and destroys a storm
# astroid. Times are seconds of bubble_storm_shoot.ogv.
const TUTORIAL_STORM_SHOOT_VIDEO := "res://Art assets/Tutorial/bubble_storm_shoot.ogv"
const TUTORIAL_STORM_SHOOT_KEYS := [
	["J", 0.75, 1.65],
]

# Wave 5b card clip: jumping on the caged bubble pops it and the explosion
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
			{"text": "Well I mean I guess we're not friends, but I've seen you around at the conferences. Great field research on the indigenous hexagonal lotus root by the way.", "portrait": FACE_RED,"speaker": "Red Frog"},
			{"text": "Where are my manners. I'm Red Frog. And you are?", "portrait": FACE_RED,"speaker": "Red Frog"},
			{"text": "Frog.", "portrait": FACE_NEUTRAL,"speaker": "Frog"},
			{"text": "Oh, so you do speak! I thought your coms were fried for a second. More of the strong and almost silent type eh.", "portrait": FACE_RED,"speaker": "Red Frog"},
			{"text": "Anyway, says here you're looking to renew your intergalactic travel license. Was the photo really that bad?", "portrait": FACE_RED,"speaker": "Red Frog"},
			{"text": "...", "portrait": FACE_NEUTRAL,"speaker": "Frog"},
			{"text": "Sorry just a little joke, guess it didn't land. Speaking of jokes, this test should be a hop in the pond for someone like you.", "portrait": FACE_RED,"speaker": "Red Frog"},
			{"text": "I'm sure you have important research to do and I wouldn't want to waste your time. If you want, Gary from licensing owes me a favor, well actually a few favors.", "portrait": FACE_RED,"speaker": "Red Frog"},
			{"text": "I could have him check all the boxes for us. Oh, but also if you want some practice, I'm happy to administer.", "portrait": FACE_RED,"speaker": "Red Frog"},
		], FROG)

		# Player picks one of the options - `choice` is its position in the list
		# (0 = "Start Tutorial", 1 = "Forge Signature").
		var choice: int = await ask("Up to you", ["Start Tutorial", "Cash in one of the Gary favors"], {"portrait": FACE_RED, "speaker": "Red Frog"})
		if choice == CHOICE_START_TUTORIAL:
			pass   # TODO: tutorial path - for now both choices carry on the same way
		elif choice == CHOICE_FORGE_SIGNATURE:
			pass   # TODO: forge-signature path - for now both choices carry on the same way

		await talk([
			{"text": "Great! This'll give us a chance to get to know each other a little better!", "portrait": FACE_RED,"speaker": "Red Frog"},
			{"text": "First, we'll have to test out your ship's maneuverability. Luckily there are a bunch of loose asteroids just looking to be avoided.","portrait": FACE_RED,"speaker": "Red Frog"},
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
	
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.9, "end_side": Side.BOTTOM, "end_percent": 0.9, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 26.5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.9, "end_side": Side.BOTTOM, "end_percent": 0.5, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 26.5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.9, "end_side": Side.BOTTOM, "end_percent": 0.1, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 26.5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.1, "end_side": Side.BOTTOM, "end_percent": 0.1, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 28.5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.1, "end_side": Side.BOTTOM, "end_percent": 0.5, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 28.5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.1, "end_side": Side.BOTTOM, "end_percent": 0.9, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 28.5})
	
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.9, "end_side": Side.BOTTOM, "end_percent": 0.9, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 30.5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.9, "end_side": Side.BOTTOM, "end_percent": 0.5, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 30.5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.9, "end_side": Side.BOTTOM, "end_percent": 0.1, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 30.5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.1, "end_side": Side.BOTTOM, "end_percent": 0.1, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 32.5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.1, "end_side": Side.BOTTOM, "end_percent": 0.5, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 32.5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.1, "end_side": Side.BOTTOM, "end_percent": 0.9, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 32.5})
	
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.LEFT, "start_percent": 0.9, "end_side": Side.RIGHT, "end_percent": 0.9, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 34.5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.LEFT, "start_percent": 0.9, "end_side": Side.RIGHT, "end_percent": 0.5, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 34.5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.LEFT, "start_percent": 0.9, "end_side": Side.RIGHT, "end_percent": 0.1, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 34.5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.RIGHT, "start_percent": 0.1, "end_side": Side.LEFT, "end_percent": 0.1, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 34.5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.RIGHT, "start_percent": 0.1, "end_side": Side.LEFT, "end_percent": 0.5, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 34.5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.RIGHT, "start_percent": 0.1, "end_side": Side.LEFT, "end_percent": 0.9, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 34.5})
	
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.RIGHT, "start_percent": 0.9, "end_side": Side.LEFT, "end_percent": 0.9, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 36.5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.RIGHT, "start_percent": 0.9, "end_side": Side.LEFT, "end_percent": 0.5, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 36.5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.RIGHT, "start_percent": 0.9, "end_side": Side.LEFT, "end_percent": 0.1, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 36.5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.LEFT, "start_percent": 0.1, "end_side": Side.RIGHT, "end_percent": 0.1, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 36.5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.LEFT, "start_percent": 0.1, "end_side": Side.RIGHT, "end_percent": 0.5, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 36.5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.LEFT, "start_percent": 0.1, "end_side": Side.RIGHT, "end_percent": 0.9, "speed": WAVE_0_ASTROID_SPEED, "start_delay": 36.5})
	next_wave_after_last_spawn(6.0)
	


# Wave 1 - jump tutorial: Red Frog's lines, the Jump card, then astroid
# columns and the jump-only formations (two diagonal walls and a ring).
func _wave_1() -> void:
	_set_abilities(false, true, false)    # jumping unlocked, still no shooting or absorbing
	begin_challenge({
		"title": "Jump",
		"text": "Press L to jump. After you land, the jump needs a moment to recharge before you can use it again.",
		"challenge": "Take damage fewer than 3 times",
		"kind": CHALLENGE_MAX_HITS,
		"target": 3,
		"fail_line": "Oof that doesn't bode well for your deductible.",
		"retry_line": "Let's give it another hop!",
	})
	# Dialogue + card only the first time (not when the wave replays).
	if not is_retry():
		await talk([
			{"text": "Says here your ship is equipped with hyperdimensional optimized propulsion. Oh I get it H.O.P.! Cause you're a frog.", "portrait": FACE_RED,"speaker": "Red Frog"},
			{"text": "...","portrait": FACE_NEUTRAL,"speaker": "Frog"},
			{"text": "Seems like you have more of a sense of humor than you let on. Would love to see H.O.P. in action! I don't think I've seen modifications this advance on such an old model.", "portrait": FACE_RED,"speaker": "Red Frog"},
			{"text": "Oh um, not old model like old old. I meant more like vintage. Or um distinguished.", "portrait": FACE_RED,"speaker": "Red Frog"},
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
	spawn_astroid_ring({"enemy": ASTROID_SMALL, "speed": 55.0, "spacing": 18.0, "start_delay": 16.0})


# Wave 2 - NOT timed (no next_wave_after_last_spawn), so the next loop only
# starts once every flower is gone. Shows dialogue in the MIDDLE of a wave:
# the wave function awaits a wait() and a talk() between spawns, and still
# counts as running the whole time, so the level never skips ahead.
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
			{"text": "That was awesome! How you got a ship to jump in the vacuum of space, I'll never know. Now time to see what kind of firepower we are working with. Your ship has blasters right?", "portrait": FACE_RED,"speaker": "Red Frog"},
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
	
	# Golden astroid at 15s - Red Frog calls it out the moment it appears. It
	# stops a third of the way down and waits there until it's shot.
	await wait(30.0)
	spawn_drift_wave({"enemy": ASTROID_GOLDEN, "start_side": Side.TOP, "start_percent": 0.5, "end_side": Side.BOTTOM, "end_percent": 0.5, "speed": 30, "stop_percent": 0.33})
	say("Golden astroids, huh. Heard there's a wave of them. They're stocked full of quantum energy. Grabbing them is like snagging two flies with one tongue.", RED_FROG)
	
# Wave 3 - absorb. A golden astroid (shoot it for 4x) and then a gray bee
# (absorb it with K) come down in random lanes, over and over, until the
# player absorbs something. Shooting stays on so the golden astroid can be
# hit; jumping stays off.
func _wave_3() -> void:
	_set_abilities(true, false, true)    # absorbing (K + absorb-ready border) unlocked
	begin_challenge({
		"title": "Absorb",
		"text": "At 4x multiplier, press K to fire an absorb beam. Hit an enemy with it to take on its form for a while.",
		"challenge": "Absorb an enemy",
		"kind": CHALLENGE_ABSORB,
	})
	if not is_retry():
		await talk([
			{"text": "Your ship's glowing! Is that another mod you added?", "portrait": FACE_RED,"speaker": "Red Frog"},
			{"text": "Phase absorption.", "portrait": FACE_NEUTRAL,"speaker": "Frog"},
			{"text": "Genius! Hyper-grafting other ships parts for a temporary boost. That's pretty advanced tech. I'm not sure if I've even heard of that before.","portrait": FACE_RED,"speaker": "Red Frog"},
			{"text": "Luckily there are a bunch of old junk ships around you could try it on. Might make clearing the area even faster.","portrait": FACE_RED,"speaker": "Red Frog"},
		], FROG)

		# Tutorial card: absorbing. Pauses until the player closes it.
		await show_info({
			"title": "Absorb",
			"video": TUTORIAL_ABSORB_VIDEO,
			"keys": [["K"]],
			"key_timeline": TUTORIAL_ABSORB_KEYS,
			"text": "At 4x multiplier, press K to fire an absorb beam. Hit an enemy with it to take on its form for a while.",
		})
	show_challenge()   # instructions + challenge fade in now that the talking's done

	# Keeps going until the absorb lands (see _supply_until_challenge_done()).
	await _supply_until_challenge_done()


# Wave 3b - bubbles. Starts with what used to be wave 4 (Red Frog reacting to
# the new form, then the Transformations and Bubbles cards), then the same
# golden astroid / gray bee supply as wave 3 - plus random astroids falling
# down the screen - until all 3 green target bubbles (bullets/
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
	_spawn_target_bubbles()
	if not is_retry():
		# The absorb beam removes the bee the moment it hits, BEFORE the
		# player transforms, so wait for the absorb to finish first.
		while player and player.currently_absorbing:
			await get_tree().process_frame
		if player and player.current_form != 'default':
			await talk([
				{"text": "Hmmmm, the changes aren't too drastic. I guess since it's using scrap ships. Still I noticed your ship does seem faster and stronger.", "portrait": FACE_RED,"speaker": "Red Frog"},
				{"text": "There are some space bubbles ahead. Tricky little things. Shooting them won't cut it.", "portrait": FACE_RED,"speaker": "Red Frog"},
				{"text": "Ah frogs! I was supposed to grab the bubble blaster to recapture these, but I forgot it at base. Guess I'll have to grab them after this training. It'll be a late lunch for me.", "portrait": FACE_RED,"speaker": "Red Frog"},
				{"text": "My ship has bubble capabilities.", "portrait": FACE_NEUTRAL,"speaker": "Frog"},
				{"text": "Wait really! If you use your bubbles to snag these it'll save me a fin and a flipper. I'd promise to treat you to lunch after!", "portrait": FACE_RED,"speaker": "Red Frog"},
				{"text": "No need to bother. It's no extra effort.", "portrait": FACE_NEUTRAL,"speaker": "Frog"},
			], FROG)

		# Tutorial cards: transformations wear off, and trading one in for a
		# bubble.
		await show_info({
			"title": "Transformations",
			"video": TUTORIAL_RUNOUT_VIDEO,
			"text": "Transformations give you different boosts, but they're temporary. When your ship starts flashing, the transformation is about to run out.",
		})
		await show_info({
			"title": "Bubbles",
			"video": TUTORIAL_BUBBLE_VIDEO,
			"keys": [["K"]],
			"key_timeline": TUTORIAL_BUBBLE_KEYS,
			"text": "While transformed, press K to give up the transformation and shoot it out as a bubble. Bounce the bubble off your ship into the green bubbles to capture them.",
		})
	show_challenge()   # instructions + challenge fade in now that the talking's done

	await _supply_until_challenge_done(true)
	_clear_target_bubbles()   # level_0.gd's practice run ends the wave with some still up
	if _challenge_state == ChallengeState.DONE:
		say("Look at you go.", RED_FROG)


## Puts up the 3 target bubbles for wave 3b (clearing any left from before).
func _spawn_target_bubbles() -> void:
	_clear_target_bubbles()
	var screen := get_viewport_rect().size
	for spot in TARGET_BUBBLE_SPOTS:
		var t = TargetBubbleScript.new()
		t.home_position = Vector2(screen.x * spot.x, screen.y * spot.y)
		t.position = t.home_position
		t.popped.connect(_on_target_bubble_popped)
		add_child(t)


func _clear_target_bubbles() -> void:
	for t in get_tree().get_nodes_in_group("target_bubble"):
		t.queue_free()


func _on_target_bubble_popped() -> void:
	if _challenge_pending(CHALLENGE_POP_TARGETS):
		_add_challenge_progress()


# Wave 5c - the bomb-ring encounter (same as levels/level_0.gd). 5a and 5b
# used to be bomb-ring waves too - they're now the cosmic storm and the
# jump-on-bubble waves (below). It teaches ONE way to use a bubble with its own
# card, then runs base_level.gd's run_bomb_ring_challenge(): three bombs
# inside rings of armored astroids, with golden astroids and gray bees
# drifting down until every ring is gone. Combining two bubbles always grants
# Penetrator Rounds during it.

# Wave 5a - cosmic storm: shoot the bubble to power it up. A purple storm
# (effects/cosmic_storm.gd) covers the top of the screen, leaving a strip at
# the bottom to fly in. Inside the storm the blasters are jammed (no
# shooting), and jumping is off for the whole wave. STORM_TARGET_SPOTS
# astroids park up in the storm, just out of reach of normal shots (bullets
# only travel ~125 px - bullet max_distance in stats.gd), so the only way to
# hit them is to shoot the bubble from the safe strip to power it up and
# bounce it up into them. A powered bubble does 1 damage per charge, and
# these astroids get STORM_TARGET_HEALTH = 1, so each charge = one astroid.
# Golden astroids + gray bees drift down (same supply as wave 3) so the
# player can get a bubble back if they lose it - but only while they have no
# bubble out and aren't transformed (_supply_only_when_needed).
const CosmicStormScript := preload("res://effects/cosmic_storm.gd")
const STORM_BOTTOM_PERCENT := 0.75   # storm covers the top 75% of the screen
const STORM_TARGET_SPOTS := [        # screen fractions (x, y) where the astroids park
	Vector2(0.15, 0.22),
	Vector2(0.4, 0.18),
	Vector2(0.65, 0.24),
	Vector2(0.88, 0.19),
]
# Shots from the very top of the safe strip reach about y = 0.33 of the
# screen (bullet max_distance 125 px in stats.gd), so these sit roughly
# 25-45 px past that. If a power-up ever raises bullet range, move them up.
const STORM_TARGET_HEALTH := 1
const STORM_TARGET_SPEED := 40.0     # px/s drifting in from the top before they park

var _storm: Node2D = null
var _storm_y := 0.0

func _wave_5a() -> void:
	_set_abilities(true, false, true)    # no jumping in the storm
	begin_challenge({
		"title": "Using Bubbles: Shoot",
		"text": "Shoot (J) a bubble to power it up. A powered-up bubble damages the enemies it hits. The storm jams your blasters - you can only shoot from the clear space at the bottom.",
		"challenge": "Destroy the %d astroids in the storm with a powered-up bubble" % STORM_TARGET_SPOTS.size(),
		"kind": CHALLENGE_STORM_TARGETS,
		"target": STORM_TARGET_SPOTS.size(),
	})
	_start_cosmic_storm()
	_clear_storm_targets()
	for spot in STORM_TARGET_SPOTS:
		_spawn_storm_target(spot)
	# Dialogue + card only the first time (not when the wave replays).
	if not is_retry():
		await talk([
			{"text": "A cosmic storm? This training just keeps having so many pesky little surprises."},
			{"text": "The storm's going to conk out your blasters, making them impossible to shoot while in the storm. Ugh, but they're right there. I can see all those little asteroids. Just floating there. Taunting me!"},
			{"text": "Bubble energy assimilation.", "portrait": FACE_NEUTRAL,"speaker": "Frog"},
			{"text": "That won't wo...wait a minute. THAT'S GENIUS!!!"},
			{"text": "The stability of the bubble should be able to soak up the energy from your bullets and carry that energy into the storm without disruption."},
			{"text": "It was a natural conclusion from your paper on bubble composition and surface tension.", "portrait": FACE_NEUTRAL,"speaker": "Frog"},
			{"text": "Aw shucks. You actually read that thing? Guess we're both geniuses then."},
		], RED_FROG)

		await show_info({
			"title": "Using Bubbles: Shoot",
			"video": TUTORIAL_STORM_SHOOT_VIDEO,
			"keys": [["J"]],
			"key_timeline": TUTORIAL_STORM_SHOOT_KEYS,
			"text": "Shoot (J) a bubble to power it up. A powered-up bubble damages the enemies it hits. The storm jams your blasters - you can only shoot from the clear space at the bottom.",
		})
	show_challenge()   # instructions + challenge fade in now that the talking's done

	# Supply drops until every storm astroid is gone (see _supply_until_challenge_done()),
	# but only when the player has no bubble out and isn't transformed.
	_supply_only_when_needed = true
	await _supply_until_challenge_done()
	_supply_only_when_needed = false
	_clear_storm_targets()   # level_0.gd's practice run ends the wave with some still up
	_end_cosmic_storm()
	if _challenge_state == ChallengeState.DONE:
		say("Glad we got that all sorted.", RED_FROG)


func _start_cosmic_storm() -> void:
	_end_cosmic_storm()
	var size := get_viewport_rect().size
	_storm_y = size.y * STORM_BOTTOM_PERCENT
	_storm = CosmicStormScript.new()
	_storm.bottom_y = _storm_y
	_storm.width = size.x
	add_child(_storm)


func _end_cosmic_storm() -> void:
	if is_instance_valid(_storm):
		_storm.dissipate()
	_storm = null
	if player:
		player.shoot_enabled = true


## Called every frame: while the storm is up, the blasters only work with the
## ship below it. Trying to fire inside it makes a little fizzle instead.
func _update_storm_blasters() -> void:
	if not is_instance_valid(_storm) or not player:
		return
	var in_storm: bool = player.position.y < _storm_y
	player.shoot_enabled = not in_storm
	if in_storm and Input.is_action_pressed("shoot") and player.is_alive:
		_storm.jam_at(player.position + Vector2(0, -8))


## One astroid that drifts in from the top and parks at `spot` (screen
## fractions) until it's destroyed.
func _spawn_storm_target(spot: Vector2) -> void:
	var size := get_viewport_rect().size
	var x := size.x * spot.x
	var a = ASTROID_SMALL.instantiate()
	a.max_health = STORM_TARGET_HEALTH   # before add_child, so _ready() picks it up
	add_child(a)
	a.add_to_group("storm_target")
	a.launch(Vector2(x, -16.0), Vector2(x, size.y), STORM_TARGET_SPEED)
	a.hold_at_y = size.y * spot.y
	a.died.connect(_on_enemy_died)
	a.died.connect(_on_storm_target_died)
	note_spawn(0.0)


func _clear_storm_targets() -> void:
	for t in get_tree().get_nodes_in_group("storm_target"):
		t.queue_free()


func _on_storm_target_died(_value: int) -> void:
	if _challenge_pending(CHALLENGE_STORM_TARGETS):
		_add_challenge_progress()


# Wave 5b - bubble use #2: jump on it. (Until 2026-11-06 this was "Using
# Bubbles: Shoot" with the bomb rings - shooting the bubble moved to 5a.)
# Two stages, jumping on:
#   1. A ring of armored (gray-outlined) astroids slides in like the bomb-ring
#      trial, but with a gray bubble pinned in the middle instead of a bomb.
#      Shots bounce off the armor; jumping on the bubble pops it in a big
#      explosion that takes out the whole ring (and gives the player its gray
#      transformation back - TestOptions BUBBLE_JUMP_REGAINS).
#   2. Once the ring is gone, JUMP_MEDIUM_SPOTS armored medium astroids drift
#      down and park on screen. Same trick: get a bubble next to them and
#      jump on it. The challenge counts these.
# The ring astroids and mediums get 3 armor, which soaks a plain jump landing
# (3 damage) and normal shots completely. Jumping on a bubble pops it for 5
# (bubble.gd JUMP_POP_DAMAGE_MULT): 5 - 3 armor = 2 = JUMP_TARGET_HEALTH, so
# one jump-pop finishes them.
# Golden astroids + gray bees drift down only while the player has no bubble
# out and isn't transformed (_supply_only_when_needed), in case they lose it.
const CAGED_BUBBLE_SCENE := preload("res://bullets/bubble.tscn")
const JUMP_RING := {                 # same look as the bomb-ring trial
	"radius": 36.0,
	"spacing": 17.0,
	"armor": 2,
	"speed": 30.0,
	"stop_percent": 0.3,
	"center_percent": 0.5,
	"orbit_speed": 20.0,
}
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
		"text": "Jump (L) on a bubble to pop it in a big explosion - and get its transformation back.",
		"challenge": "Jump on a bubble to destroy the %d armored astroids" % JUMP_MEDIUM_SPOTS.size(),
		"kind": CHALLENGE_JUMP_TARGETS,
		"target": JUMP_MEDIUM_SPOTS.size(),
	})
	_clear_jump_wave()
	_jump_wave_active = true
	_spawn_caged_bubble_ring()
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
			"text": "Jump (L) on a bubble to pop it in a big explosion - and get its transformation back.",
		})
	show_challenge()   # instructions + challenge fade in now that the talking's done

	_run_jump_wave_stages()   # not awaited - runs alongside the supply drops
	_supply_only_when_needed = true
	await _supply_until_challenge_done()
	_supply_only_when_needed = false
	_jump_wave_active = false
	_clear_jump_wave()   # level_0.gd's practice run ends the wave with some still up
	if _challenge_state == ChallengeState.DONE:
		say("Guess you really did got it.", RED_FROG)


## Stage 1 -> stage 2: wait for the ring to be gone, then bring in the mediums.
func _run_jump_wave_stages() -> void:
	while _jump_wave_active and is_inside_tree() and not get_tree().get_nodes_in_group("jump_ring_astroid").is_empty():
		await get_tree().create_timer(0.2, false).timeout
	if not _jump_wave_active or not is_inside_tree():
		return
	for x in JUMP_MEDIUM_SPOTS:
		_spawn_jump_medium(x)


## Ring of armored astroids around a gray bubble pinned at its center. Reuses
## the bomb-ring formation (enemies/bomb_ring_formation.gd), with the bubble
## in the bomb's slot so it rides down and stays in the middle.
func _spawn_caged_bubble_ring() -> void:
	var size := get_viewport_rect().size
	var radius: float = JUMP_RING["radius"]
	var formation = BombRingFormationScript.new()
	formation.radius = radius
	formation.fall_speed = JUMP_RING["speed"]
	formation.stop_y = size.y * float(JUMP_RING["stop_percent"])
	formation.orbit_speed = deg_to_rad(JUMP_RING["orbit_speed"])
	formation.despawn_y = size.y + radius + BOMB_RING_ENTRY_MARGIN
	formation.center = Vector2(size.x * float(JUMP_RING["center_percent"]), -radius - BOMB_RING_ENTRY_MARGIN)
	add_child(formation)
	formation.add_to_group("jump_ring_formation")

	var count := int(ceil(TAU * radius / float(JUMP_RING["spacing"])))
	for i in count:
		var a = BOMB_RING_ASTROID.instantiate()
		a.max_health = JUMP_TARGET_HEALTH   # before add_child, so _ready() picks it up
		a.position = formation.center + Vector2.from_angle(TAU * i / count) * radius
		a.squad_controlled = true   # the formation moves it
		add_child(a)
		a.set_armor(JUMP_TARGET_ARMOR)
		a.add_to_group("jump_ring_astroid")
		a.died.connect(_on_enemy_died)
		formation.astroids.append(a)

	# The bubble: a plain gray one that the formation just carries. Its own
	# _process is switched off - otherwise it clamps itself to the top edge
	# of the screen (bubble.gd _bounce_off_walls()) and shows up there before
	# the ring arrives. With no movement it never arms its player collision,
	# so the ship passes through it instead of bouncing it. Jumping on it
	# still works (LandingShockwave calls on_shockwave_hit() directly).
	var bubble = CAGED_BUBBLE_SCENE.instantiate()
	PlayerAbsorption.apply_bubble_stats(bubble)
	bubble.speed = 0.0
	bubble.position = formation.center
	add_child(bubble)
	bubble.start(formation.center, Vector2.DOWN)
	bubble.set_process(false)
	bubble.set_enemy_type("gray")
	bubble.add_to_group("caged_bubble")
	formation.bomb = bubble
	note_spawn(0.0)


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


## Removes anything left from this wave (ring, caged bubble, mediums).
func _clear_jump_wave() -> void:
	for group in ["jump_ring_formation", "jump_ring_astroid", "caged_bubble", "jump_medium"]:
		for n in get_tree().get_nodes_in_group(group):
			n.queue_free()


# Wave 5c - bubble use #3: combine two.
func _wave_5c() -> void:
	_set_abilities(true, true, true)
	begin_challenge({
		"title": "Using Bubbles: Combine",
		"text": "Combine two bubbles to get a permanent buff.",
		"challenge": "Destroy all 3 bombs with Penetrator Rounds without taking damage",
		"kind": CHALLENGE_BOMBS,
		"target": 3,
		"method": BOMB_METHOD_COMBINE,
		"no_damage": true,   # any hit fails it too
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

	await run_bomb_ring_challenge()
	
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
