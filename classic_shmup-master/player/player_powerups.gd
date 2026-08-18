extends RefCounted
class_name PlayerPowerUps

## Defines the pool of power-ups a power bubble can grant, keyed by the
## enemy type that "seeded" the bubble (see bullets/bubble.gd - the first
## enemy type absorbed into the bubble before it fused with another one),
## and applies a randomly chosen one to the player.
##
## Power-ups are applied as PERSISTENT-FOR-THE-LEVEL Stats modifiers (see
## Stats.add_powerup() / Stats.level_modifiers), not permanent progression
## and not a short transformation - they last until the level ends/restarts
## (Stats.clear_level_modifiers(), called from BaseLevel.new_game()).
##
## Called from player.gd as e.g. PlayerPowerUps.apply_random_powerup(self, "yellow").

# Each entry is one selectable power-up: an id (used to build a unique Stats
# modifier name and for the collected_powerups log), a display name, and the
# stat changes it applies. "stats" uses the exact same
# { category -> { stat_key -> {"op": ..., "value": ...} } } shape that
# Stats.add_modifier()/add_level_modifier() expect.
const YELLOW_POWERUPS: Array[Dictionary] = [
	{
		"id": "yellow_speed_boost",
		"name": "Speed Boost",
		"description": "Doubles the player's movement speed for the rest of the level.",
		"stats": {
			"player": {
				"speed": {"op": "mult", "value": 2.0},
			},
		},
	},
	{
		"id": "yellow_dash_invincibility",
		"name": "Dash Invincibility",
		"description": "The player is invincible to enemy bullets AND enemy ships while dashing (plus a brief moment after), and the dash loops in a tight loop-de-loop, for the rest of the level.",
		"stats": {
			"player": {
				# Covers both enemy bullets (physics-level collision toggle)
				# and enemy ships (explicit check in
				# PlayerHealth.is_invincible()) - see
				# player/player_movement.gd and player/player_health.gd.
				"dash_invincible": {"op": "set", "value": true},
				# Keep that same invincibility alive for a short moment after
				# the dash itself ends, instead of cutting off the instant it
				# does - see PlayerMovement._begin_post_dash_grace().
				"post_dash_invincibility_duration": {"op": "set", "value": 2.4},
				# Loop-de-loop dash motion - circle_radius/circle_speed drive
				# the circular strafe added on top of the dash's straight-line
				# direction (see PlayerMovement.handle_movement()). Both
				# default to 0 (a plain straight dash); these values are the
				# same ones that used to sit here commented out under
				# transform_yellow() in transformations/player_transformations.gd
				# before the dash-invincibility power-up existed. circle_radius
				# was originally 600.0 - way too large for this game's tiny
				# 240x320 viewport (project.godot) - shrunk down to a tight
				# loop that actually fits on screen.
				"circle_radius": {"op": "set", "value": 600.0},
				"circle_speed": {"op": "set", "value": 20.0},
			},
		},
	},
	{
		"id": "yellow_pollen_shot",
		"name": "Pollen Shot",
		"description": "While holding shoot, the ship also fires weak, wiggling pollen balls from its left and right sides, for the rest of the level.",
		"stats": {
			"player": {
				"has_pollen_shot": {"op": "set", "value": true},
			},
		},
	},
	{
		"id": "yellow_bubble_pollen_pop",
		"name": "Pollen Burst",
		"description": "Popping a power bubble with your shot no longer damages enemies caught in the blast - it guarantees the pollinated status on all of them instead, for the rest of the level.",
		"stats": {
			"bubble": {
				"pop_applies_pollination": {"op": "set", "value": true},
			},
		},
	},
	{
		"id": "yellow_pollen_blast_radius",
		"name": "Blast Radius",
		"description": "Increases the radius of the small explosion triggered when a pollinated enemy dies, for the rest of the level.",
		# Only offered once the player already has some way to actually
		# apply pollination - otherwise this power-up would do nothing.
		"requires_pollination_source": true,
		"stats": {
			"pollen": {
				"chain_explosion_radius": {"op": "add", "value": 40.0},
			},
		},
	},
	{
		"id": "yellow_piercing_rounds",
		"name": "Piercing Rounds",
		"description": "The player's main shot pierces through one additional enemy, for the rest of the level.",
		"stats": {
			"bullet": {
				"can_pierce": {"op": "set", "value": true},
				"pierce_count": {"op": "add", "value": 1},
			},
		},
	},
	{
		"id": "yellow_piercing_pollen",
		"name": "Cross-Pollination",
		"description": "The first enemy the player's main shot hits releases a cone of pollen behind it, with a 50% chance to pollinate each other enemy caught in the cone, for the rest of the level.",
		"stats": {
			"bullet": {
				"status_effect_name": {"op": "set", "value": "pollinated"},
				"pollen_cone_enabled": {"op": "set", "value": true},
				"pollen_cone_chance": {"op": "set", "value": 0.5},
				"pollen_cone_range": {"op": "set", "value": 60.0},
				"pollen_cone_angle_degrees": {"op": "set", "value": 70.0},
			},
		},
	},
]

# ids of every power-up that can, by itself, apply the "pollinated" status
# effect to an enemy. Used to gate power-ups like yellow_pollen_blast_radius
# that only make sense once the player has some way to actually pollinate
# something. Add new pollination-granting power-ups' ids here too.
const POLLINATION_SOURCE_POWERUP_IDS: Array[String] = [
	"yellow_pollen_shot",
	"yellow_bubble_pollen_pop",
	"yellow_piercing_pollen",
]

# enemy_type (as returned by e.g. YellowEnemy.get_enemy_type()) -> pool of
# power-ups that type's power bubbles can grant. Add more enemy types here
# (e.g. "red") once their power-ups are designed.
const POWERUPS_BY_ENEMY_TYPE: Dictionary = {
	"yellow": YELLOW_POWERUPS,
}

# enemy_type -> accent color PowerupPopup uses for that type's border/header
# (see PowerupPopup.show_powerup()). Add an entry here alongside each new
# entry in POWERUPS_BY_ENEMY_TYPE so its popups get their own color.
const ENEMY_TYPE_ACCENT_COLORS: Dictionary = {
	"yellow": Color(1.0, 0.85882353, 0.2),
}

# Fallback accent color for a power-up whose enemy type isn't in
# ENEMY_TYPE_ACCENT_COLORS yet (also PowerupPopup's own default).
const DEFAULT_ACCENT_COLOR := Color(0.54901961, 0.85098039, 1.0)


static func get_powerups_for_enemy_type(enemy_type: String) -> Array:
	"""Return the FULL power-up pool for the given enemy type (including
	ones the player can't currently receive, e.g. gated by
	requires_pollination_source), or an empty array if that enemy type has
	no power-ups defined yet. Use get_available_powerups_for_enemy_type()
	when picking what a bubble can actually grant right now."""
	return POWERUPS_BY_ENEMY_TYPE.get(enemy_type, [])


static func get_available_powerups_for_enemy_type(enemy_type: String) -> Array:
	"""Same as get_powerups_for_enemy_type(), but filtered down to power-ups
	the player is currently eligible to receive (e.g. excludes
	yellow_pollen_blast_radius until the player already has some way to
	apply pollination)."""
	var pool: Array = get_powerups_for_enemy_type(enemy_type)
	var available: Array = []
	for powerup: Dictionary in pool:
		if powerup.get("requires_pollination_source", false) and not _player_has_pollination_source():
			continue
		available.append(powerup)
	return available


static func get_all_available_powerups() -> Array:
	"""Every power-up, across every enemy type's pool, the player is
	currently eligible for (see get_available_powerups_for_enemy_type()) -
	the FULL pool the overworld shop offers from (see
	get_random_shop_offers() / levels/shop.gd), as opposed to a single power
	bubble which only draws from one enemy type at a time."""
	var all: Array = []
	for enemy_type in POWERUPS_BY_ENEMY_TYPE:
		all.append_array(get_available_powerups_for_enemy_type(enemy_type))
	return all


static func get_random_shop_offers(count: int) -> Array:
	"""Pick up to `count` DISTINCT random power-ups from the full eligible
	pool (see get_all_available_powerups()). Used by the shop screen
	(levels/shop.gd) each time the player enters it - may return fewer than
	`count` if the eligible pool itself is smaller."""
	var pool: Array = get_all_available_powerups()
	pool.shuffle()
	return pool.slice(0, min(count, pool.size()))


static func _player_has_pollination_source() -> bool:
	"""True if the player has already collected a power-up that can, by
	itself, apply the "pollinated" status effect (see
	POLLINATION_SOURCE_POWERUP_IDS) - either earned this level, or chosen to
	carry forward from an earlier level this run (see
	Stats.choose_run_powerup())."""
	for collected_id in Stats.collected_powerups:
		if collected_id in POLLINATION_SOURCE_POWERUP_IDS:
			return true
	for chosen_id in Stats.chosen_run_powerups:
		if chosen_id in POLLINATION_SOURCE_POWERUP_IDS:
			return true
	return false


static func apply_random_powerup(player: Player, enemy_type: String) -> Dictionary:
	"""Pick a random power-up from enemy_type's pool (filtered to ones the
	player is currently eligible for) and apply it to the player via
	Stats.add_powerup() (persists for the rest of the level). Returns the
	chosen power-up dict, or an empty dict if enemy_type has no eligible
	power-ups right now."""
	var pool: Array = get_available_powerups_for_enemy_type(enemy_type)
	if pool.is_empty():
		return {}

	var powerup: Dictionary = pool[randi() % pool.size()]
	Stats.add_powerup(powerup.get("id", ""), powerup.get("stats", {}))
	return powerup


static func get_powerup_by_id(powerup_id: String) -> Dictionary:
	"""Look up a power-up's full definition (name/description/stats) by its
	id, searching across every enemy type's pool. Used by PowerupPopup to
	turn the id from Stats.powerup_collected into display text. Returns an
	empty dict if no power-up with that id exists."""
	for enemy_type in POWERUPS_BY_ENEMY_TYPE:
		for powerup: Dictionary in POWERUPS_BY_ENEMY_TYPE[enemy_type]:
			if powerup.get("id", "") == powerup_id:
				return powerup
	return {}


static func get_enemy_type_for_powerup_id(powerup_id: String) -> String:
	"""Look up which enemy type's pool a power-up id belongs to (used to
	pick the popup's accent color - see get_accent_color_for_powerup_id()).
	Empty string if no power-up with that id exists."""
	for enemy_type in POWERUPS_BY_ENEMY_TYPE:
		for powerup: Dictionary in POWERUPS_BY_ENEMY_TYPE[enemy_type]:
			if powerup.get("id", "") == powerup_id:
				return enemy_type
	return ""


static func get_accent_color_for_powerup_id(powerup_id: String) -> Color:
	"""The color PowerupPopup should border/highlight itself with for a given
	power-up id, based on the enemy type it came from (e.g. yellow for a
	yellow-enemy power-up). Falls back to DEFAULT_ACCENT_COLOR for an
	unknown id or an enemy type with no color registered yet."""
	var enemy_type := get_enemy_type_for_powerup_id(powerup_id)
	return ENEMY_TYPE_ACCENT_COLORS.get(enemy_type, DEFAULT_ACCENT_COLOR)
