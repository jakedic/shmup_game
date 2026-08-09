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
		"description": "The player is invincible to enemy bullets while dashing, for the rest of the level.",
		"stats": {
			"player": {
				"dash_invincible": {"op": "set", "value": true},
			},
		},
	},
]

# enemy_type (as returned by e.g. YellowEnemy.get_enemy_type()) -> pool of
# power-ups that type's power bubbles can grant. Add more enemy types here
# (e.g. "red") once their power-ups are designed.
const POWERUPS_BY_ENEMY_TYPE: Dictionary = {
	"yellow": YELLOW_POWERUPS,
}


static func get_powerups_for_enemy_type(enemy_type: String) -> Array:
	"""Return the power-up pool for the given enemy type, or an empty array
	if that enemy type has no power-ups defined yet."""
	return POWERUPS_BY_ENEMY_TYPE.get(enemy_type, [])


static func apply_random_powerup(player: Player, enemy_type: String) -> Dictionary:
	"""Pick a random power-up from enemy_type's pool and apply it to the
	player via Stats.add_powerup() (persists for the rest of the level).
	Returns the chosen power-up dict, or an empty dict if enemy_type has no
	pool defined (e.g. any type other than "yellow" for now)."""
	var pool: Array = get_powerups_for_enemy_type(enemy_type)
	if pool.is_empty():
		print("No power-ups defined for enemy type: ", enemy_type)
		return {}

	var powerup: Dictionary = pool[randi() % pool.size()]
	Stats.add_powerup(powerup.get("id", ""), powerup.get("stats", {}))
	print("Power bubble granted power-up: ", powerup.get("name", powerup.get("id", "?")))
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
