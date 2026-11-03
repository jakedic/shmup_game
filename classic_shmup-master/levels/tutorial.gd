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
#   3b     bounce the same bubble 5 times (same supply, plus random astroids)
#   5a     set off all 3 bombs with a jump-charged bubble
#   5b     set off all 3 bombs by shooting a bubble
#   5c     set off all 3 bombs with Penetrator Rounds (combine two bubbles)
#   6      make it to the end without losing all your health
#   7      (outro - no challenge)
extends SquadWaveLevel
class_name TutorialLevel   # levels/a_test.gd reuses these waves (no dialogue / challenges)


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
const CHALLENGE_SURVIVE := "survive"            # don't lose all your health - passes when the wave ends
const CHALLENGE_MAX_HITS := "max_hits"          # get hit fewer than `target` times - passes when the wave ends
const CHALLENGE_DESTROY_ASTROIDS := "astroids"  # destroy `target` astroids (gray bees don't count)
const CHALLENGE_ABSORB := "absorb"              # absorb any enemy
const CHALLENGE_BUBBLE_BOUNCES := "bounces"     # bounce ONE bubble off the ship `target` times
const CHALLENGE_BOMBS := "bombs"                # set off `target` bombs, every one with `method`

# How a bomb was set off - read from the bomb's BaseEnemy.death_context (the
# "source" its killing hit was tagged with in bubble.gd / bullet.gd / ...).
const BOMB_METHOD_JUMP := "bubble_charged"          # a bubble charged by a jump landing flew into it
const BOMB_METHOD_SHOOT := "bubble_pop"             # a bubble got shot and its explosion caught it
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
const RANDOM_ASTROID_GAP_MIN := 1.2
const RANDOM_ASTROID_GAP_MAX := 2.4
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


## Set this wave's instructions + challenge and reset its progress. Also tops
## the player's health back up, so a rough previous wave can't doom this one.
## The right side panel stays hidden until show_challenge() - call that once
## the wave's dialogue and cards are done.
func begin_challenge(config: Dictionary) -> void:
	_challenge = config
	_challenge_state = ChallengeState.PENDING
	_challenge_count = 0
	_challenge_shown = false
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
		CHALLENGE_DESTROY_ASTROIDS, CHALLENGE_BUBBLE_BOUNCES, CHALLENGE_BOMBS:
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


# --- Waves 3 / 3b supply drops ---

## Golden astroid, then a gray bee, in random lanes, over and over until the
## current challenge is done. random_astroids = also send plain astroids down
## the screen at random in between. Returns once the challenge is done.
func _supply_until_challenge_done(random_astroids: bool = false) -> void:
	_random_astroid_timer = 0.0
	while _challenge_state == ChallengeState.PENDING:
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
		"challenge": "Avoid the astroids without losing all your health",
		"kind": CHALLENGE_SURVIVE,
		"retry_line": "Let's try that again. With less crashing this time.",
	})
	# Dialogue + card only the first time (not when the wave replays).
	if not is_retry():
		await talk([
			{"text": "Corporate has me taking you through basic training today.", "portrait": FACE_RED,"speaker": "Red Frog"},
			{"text": "Listen, I don't pick the insurance plan I just deal with the consequences of it. One way or another we gotta get through this.","portrait": FACE_RED,"speaker": "Red Frog"},
			{"text": "We can either do this the hard way or the way that involves me forging a signature.","portrait": FACE_RED,"speaker": "Red Frog"},
		], FROG)

		# Player picks one of the options - `choice` is its position in the list
		# (0 = "Start Tutorial", 1 = "Forge Signature").
		var choice: int = await ask("What'll it be?", ["Start Tutorial", "Forge Signature and Lie to Corporate"], {"portrait": FACE_RED, "speaker": "Red Frog"})
		if choice == CHOICE_START_TUTORIAL:
			pass   # TODO: tutorial path - for now both choices carry on the same way
		elif choice == CHOICE_FORGE_SIGNATURE:
			pass   # TODO: forge-signature path - for now both choices carry on the same way

		await talk([
			{"text": "Begin the training module by having the trainee navigate through BLAH BLAH BLAH", "portrait": FACE_RED,"speaker": "Red Frog"},
			{"text": "Why don't you just try and avoid these astroids. Seems like a good warm-up.","portrait": FACE_RED,"speaker": "Red Frog"},
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
		"fail_line": "That's three hits. Insurance is gonna love this.",
		"retry_line": "Again. Jump OVER the rocks this time, not into them.",
	})
	# Dialogue + card only the first time (not when the wave replays).
	if not is_retry():
		await talk([
			{"text": "Ace pilots like yours truly don't really need special modifications, but why don't you show me what yours can do?", "portrait": FACE_RED,"speaker": "Red Frog"},
			{"text": "A frog jumping is a little on the nose for my taste, but I'm curious to see what you've been spending all that time working on.","portrait": FACE_RED,"speaker": "Red Frog"},
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
		"retry_line": "You're supposed to shoot the astroids. Let's go again.",
	})
	# Dialogue + card only the first time (not when the wave replays).
	if not is_retry():
		await talk([
			{"text": "Looks like you're out of jumping juice. Oh well. Not really sure how one jumps in the vacuum of space anyway.", "portrait": FACE_RED,"speaker": "Red Frog"},
			{"text": "Why don't we bring out the big guns or whatever pea shooter you scrapped together and blast some of these astroids away.","portrait": FACE_RED,"speaker": "Red Frog"},
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
	say("A golden astroid! Those are super valuable. Let's shoot it and collect the debris.", RED_FROG)
	
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
			{"text": "Look's like that golden astroid did the trick. Absorbing an enemy ship and stealing their power. Not quite for me.", "portrait": FACE_RED,"speaker": "Red Frog"},
			{"text": "There is no equal to my brilliance so what would I even want to copy? Oh, I mean... but I'm sure you could use the boost.","portrait": FACE_RED,"speaker": "Red Frog"},
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
# down the screen - until one bubble has bounced off the ship 5 times.
# Re-absorbing a bee gives a fresh bubble to try with.
func _wave_3b() -> void:
	_set_abilities(true, false, true)
	begin_challenge({
		"title": "Bubbles",
		"text": "While transformed, press K to give up the transformation and shoot it out as a bubble. Bounce the bubble around the level off your ship.",
		"challenge": "Bounce the same bubble 5 times",
		"kind": CHALLENGE_BUBBLE_BOUNCES,
		"target": 5,
	})
	if not is_retry():
		# The absorb beam removes the bee the moment it hits, BEFORE the
		# player transforms, so wait for the absorb to finish first.
		while player and player.currently_absorbing:
			await get_tree().process_frame
		if player and player.current_form != 'default':
			await talk([
				{"text": "Hmmmm, I was expecting something a little more dramatic but I guess your ship does seem a stronger faster now.", "portrait": FACE_RED,"speaker": "Red Frog"},
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
			"text": "While transformed, press K to give up the transformation and shoot it out as a bubble. Bounce the bubble around the level off your ship.",
		})
	show_challenge()   # instructions + challenge fade in now that the talking's done

	await _supply_until_challenge_done(true)
	say("Look at you, keeping it up. Nice.", RED_FROG)


# Waves 5a / 5b / 5c - the bomb-ring encounter (same as levels/a_test.gd),
# three times over. Each one teaches ONE way to use a bubble with its own
# card, then runs base_level.gd's run_bomb_ring_challenge(): three bombs
# inside rings of armored astroids, with golden astroids and gray bees
# drifting down until every ring is gone. Combining two bubbles always grants
# Penetrator Rounds during it.

# Wave 5a - bubble use #1: jump on it.
func _wave_5a() -> void:
	_set_abilities(true, true, true)
	begin_challenge({
		"title": "Using Bubbles: Jump",
		"text": "Jump (L) on the bubble and it does damage to enemies for a short time.",
		"challenge": "Destroy all 3 bombs with a jump-charged bubble",
		"kind": CHALLENGE_BOMBS,
		"target": 3,
		"method": BOMB_METHOD_JUMP,
		"fail_line": "That one doesn't count. Charge a bubble with a jump and send it in.",
		"retry_line": "Rings are back. Jump-charged bubbles only, please.",
	})
	# Dialogue + card only the first time (not when the wave replays).
	if not is_retry():
		await talk([
			{"text": "Some weird astroid formations ahead. If I were taking this test, I'd hit the bombs in the center with a triple barrel flipturn switcheroo."},
			{"text": "Kinda advanced for you so you may need to get a bit creative."},
		], RED_FROG)

		await show_info({
			"title": "Using Bubbles: Jump",
			"video": TUTORIAL_BUBBLE_JUMP_VIDEO,
			"keys": [["L"]],
			"text": "Jump (L) on the bubble and it does damage to enemies for a short time.",
		})
	show_challenge()   # instructions + challenge fade in now that the talking's done

	await run_bomb_ring_challenge()
	if _challenge_state == ChallengeState.DONE:
		say("Ha! Three bombs down. Not bad.", RED_FROG)


# Wave 5b - bubble use #2: shoot it.
func _wave_5b() -> void:
	_set_abilities(true, true, true)
	begin_challenge({
		"title": "Using Bubbles: Shoot",
		"text": "Shoot (J) a bubble to trigger a big explosion.",
		"challenge": "Destroy all 3 bombs by shooting a bubble",
		"kind": CHALLENGE_BOMBS,
		"target": 3,
		"method": BOMB_METHOD_SHOOT,
		"fail_line": "Doesn't count. Pop a bubble next to the bomb.",
		"retry_line": "One more time. Shoot the bubble, let it blow.",
	})
	# Dialogue + card only the first time (not when the wave replays).
	if not is_retry():
		await talk([
			{"text": "More rings. Let's try a different trick this time."},
		], RED_FROG)

		await show_info({
			"title": "Using Bubbles: Shoot",
			"video": TUTORIAL_BUBBLE_SHOOT_VIDEO,
			"keys": [["J"]],
			"text": "Shoot (J) the bubble to trigger a big explosion.",
		})
	show_challenge()   # instructions + challenge fade in now that the talking's done

	await run_bomb_ring_challenge()
	if _challenge_state == ChallengeState.DONE:
		say("Kaboom. Love that.", RED_FROG)


# Wave 5c - bubble use #3: combine two.
func _wave_5c() -> void:
	_set_abilities(true, true, true)
	begin_challenge({
		"title": "Using Bubbles: Combine",
		"text": "Combine two bubbles to get a permanent buff.",
		"challenge": "Destroy all 3 bombs with Penetrator Rounds",
		"kind": CHALLENGE_BOMBS,
		"target": 3,
		"method": BOMB_METHOD_COMBINE,
		"fail_line": "Nope. Combine two bubbles, then shoot through the ring.",
		"retry_line": "Again. Combine first, then shoot.",
	})
	# Dialogue + card only the first time (not when the wave replays).
	if not is_retry():
		await talk([
			{"text": "One more set. Last trick, and it's my favorite."},
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
		"retry_line": "Paperwork says you have to finish in one piece. From the top.",
	})
	# Dialogue + card only the first time (not when the wave replays).
	if not is_retry():
		await talk([
			{"text": "And check! Mandatory insurance requirements fullfilled. Now guess all that's left is for you to get out of this super dangerous astroid field."},
			{"text": "Hmmmm looks like the next section is even more dangerous. Use everything I taught..."},
			{"text": "Err I guess use all the stuff you already knew to not die which would force me to do even more paper work."},
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
		{"text": "You made it?"},
		{"text": "I mean, you made it!"},
		{"text": "I knew you had it in you the whole time. If the whole time started five seconds ago."},
		{"text": "That's enough of that. I'm outta here. Have a great day or night or whatever time it is in space."},
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
	say("So you're actually supposed to avoid the giant boulders hurdling towards you.", RED_FROG)
	# Short beat at empty so the line lands, then fill back up. The hit that
	# emptied the bar already started the 1s hit invincibility, so nothing
	# can land in between.
	await wait(0.6)
	if is_instance_valid(player):
		player.heal(player.max_shield)
	_refilling_health = false
