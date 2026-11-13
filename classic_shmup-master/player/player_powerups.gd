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
# Trimmed 2026-11-11 to just these two while the yellow pool is redone.
# Removed: Speed Boost, Dash Invincibility, Pollen Burst, Blast Radius,
# Piercing Rounds. (Their stat keys - e.g. "dash_invincible",
# "pop_applies_pollination" - still exist in stats.gd, unused.)
const YELLOW_POWERUPS: Array[Dictionary] = [
	{
		"id": "yellow_pollen_shot",
		"name": "Pollen Shot",
		"description": "While holding shoot, the ship also fires wiggling pollen balls from its left and right sides. They barely do damage, but each hit may pollinate the enemy.",
		"levels": [
			{"summary": "20% pollination per hit", "stats": {"player": {"has_pollen_shot": {"op": "set", "value": true}}, "pollen": {"status_effect_chance": {"op": "set", "value": 0.2}}}},
			{"summary": "30% pollination per hit", "stats": {"player": {"has_pollen_shot": {"op": "set", "value": true}}, "pollen": {"status_effect_chance": {"op": "set", "value": 0.3}}}},
			{"summary": "40% pollination per hit", "stats": {"player": {"has_pollen_shot": {"op": "set", "value": true}}, "pollen": {"status_effect_chance": {"op": "set", "value": 0.4}}}},
		],
	},
	{
		"id": "yellow_piercing_pollen",
		"name": "Cross-Pollination",
		"description": "The first enemy your main shot hits sprays a cone of pollen behind it. Each other enemy in the cone may become pollinated - and leaves a patch of pollen residue where it was.",
		"levels": [
			{"summary": "20% per enemy in the cone", "stats": {"bullet": {
				"status_effect_name": {"op": "set", "value": "pollinated"},
				"pollen_cone_enabled": {"op": "set", "value": true},
				"pollen_cone_chance": {"op": "set", "value": 0.2},
				"pollen_cone_range": {"op": "set", "value": 60.0},
				"pollen_cone_angle_degrees": {"op": "set", "value": 70.0},
			}}},
			{"summary": "30% per enemy in the cone", "stats": {"bullet": {
				"status_effect_name": {"op": "set", "value": "pollinated"},
				"pollen_cone_enabled": {"op": "set", "value": true},
				"pollen_cone_chance": {"op": "set", "value": 0.3},
				"pollen_cone_range": {"op": "set", "value": 60.0},
				"pollen_cone_angle_degrees": {"op": "set", "value": 70.0},
			}}},
			{"summary": "40% per enemy in the cone", "stats": {"bullet": {
				"status_effect_name": {"op": "set", "value": "pollinated"},
				"pollen_cone_enabled": {"op": "set", "value": true},
				"pollen_cone_chance": {"op": "set", "value": 0.4},
				"pollen_cone_range": {"op": "set", "value": 60.0},
				"pollen_cone_angle_degrees": {"op": "set", "value": 70.0},
			}}},
		],
	},
	{
		"id": "yellow_pollen_trail",
		"name": "Pollen Trail",
		"description": "You leave a trail of pollen behind you as you move. Enemies passing through it have a 50% chance to become pollinated.",
		"levels": [
			{"summary": "Residue lasts 2.5s", "stats": {"pollen": {"trail_duration_mult": {"op": "set", "value": 1.0}}}},
			{"summary": "Residue lasts ~3.1s", "stats": {"pollen": {"trail_duration_mult": {"op": "set", "value": 1.25}}}},
			{"summary": "Residue lasts 3.75s", "stats": {"pollen": {"trail_duration_mult": {"op": "set", "value": 1.5}}}},
		],
	},
	{
		"id": "yellow_pollen_pop",
		"name": "Pollen Pop",
		"description": "Jumping on a bubble leaves pollen over the whole blast area. Enemies passing through it have a 50% chance to become pollinated.",
		"levels": [
			{"summary": "Residue lasts 2.5s", "stats": {"pollen": {"jump_pop_residue_mult": {"op": "set", "value": 1.0}}}},
			{"summary": "Residue lasts ~3.1s", "stats": {"pollen": {"jump_pop_residue_mult": {"op": "set", "value": 1.25}}}},
			{"summary": "Residue lasts 3.75s", "stats": {"pollen": {"jump_pop_residue_mult": {"op": "set", "value": 1.5}}}},
		],
	},
	{
		"id": "yellow_pollen_wake",
		"name": "Pollen Wake",
		"description": "A fully charged bubble leaves a trail of pollen behind it until it runs out of charges. Enemies passing through have a 50% chance to become pollinated.",
		"levels": [
			{"summary": "Trail lasts 2.5s", "stats": {"pollen": {"bubble_trail_duration_mult": {"op": "set", "value": 1.0}}}},
			{"summary": "Trail lasts ~3.1s", "stats": {"pollen": {"bubble_trail_duration_mult": {"op": "set", "value": 1.25}}}},
			{"summary": "Trail lasts 3.75s", "stats": {"pollen": {"bubble_trail_duration_mult": {"op": "set", "value": 1.5}}}},
		],
	},
	{
		"id": "yellow_pollen_haven",
		# Only offered once the player owns a power-up that leaves pollen
		# residue (see RESIDUE_SOURCE_POWERUP_IDS).
		"requires_residue_source": true,
		"name": "Pollen Haven",
		"description": "You're invulnerable while standing in pollen residue.",
		"levels": [
			{"summary": "Only while in pollen", "stats": {"player": {"has_pollen_haven": {"op": "set", "value": true}, "haven_linger": {"op": "set", "value": 0.0}}}},
			{"summary": "+0.5s after leaving", "stats": {"player": {"has_pollen_haven": {"op": "set", "value": true}, "haven_linger": {"op": "set", "value": 0.5}}}},
			{"summary": "+1s after leaving", "stats": {"player": {"has_pollen_haven": {"op": "set", "value": true}, "haven_linger": {"op": "set", "value": 1.0}}}},
		],
	},
	{
		"id": "yellow_wide_bloom",
		# Only offered once the player owns a pollen source (see
		# POLLINATION_SOURCE_POWERUP_IDS) - it does nothing without one.
		"requires_pollination_source": true,
		"name": "Wide Bloom",
		"description": "Shots that hit a pollinated enemy can bounce to enemies farther away.",
		"levels": [
			{"summary": "Bounce range x1.25 (50px)", "stats": {"pollen": {"bounce_radius_mult": {"op": "set", "value": 1.25}}}},
			{"summary": "Bounce range x1.5 (60px)", "stats": {"pollen": {"bounce_radius_mult": {"op": "set", "value": 1.5}}}},
			{"summary": "Bounce range x1.75 (70px)", "stats": {"pollen": {"bounce_radius_mult": {"op": "set", "value": 1.75}}}},
		],
	},
	{
		"id": "yellow_pollen_split",
		# Only offered once the player owns a pollen source (see
		# POLLINATION_SOURCE_POWERUP_IDS) - it does nothing without one.
		"requires_pollination_source": true,
		"name": "Pollen Split",
		"description": "When a shot bounces off a pollinated enemy, extra shots also fly out to other enemies in range.",
		"levels": [
			{"summary": "+1 extra shot", "stats": {"pollen": {"extra_bounce_shots": {"op": "set", "value": 1}}}},
			{"summary": "+2 extra shots", "stats": {"pollen": {"extra_bounce_shots": {"op": "set", "value": 2}}}},
			{"summary": "+3 extra shots", "stats": {"pollen": {"extra_bounce_shots": {"op": "set", "value": 3}}}},
		],
	},
	{
		"id": "yellow_safe_landing",
		"name": "Safe Landing",
		"description": "You stay invulnerable for a moment after landing a jump.",
		"levels": [
			{"summary": "0.5s after landing", "stats": {"player": {"landing_invincibility": {"op": "set", "value": 0.5}}}},
			{"summary": "0.75s after landing", "stats": {"player": {"landing_invincibility": {"op": "set", "value": 0.75}}}},
			{"summary": "1s after landing", "stats": {"player": {"landing_invincibility": {"op": "set", "value": 1.0}}}},
		],
	},
	{
		"id": "yellow_bubble_guard",
		"name": "Bubble Guard",
		"description": "You become invulnerable for a moment every time a bubble bounces off you.",
		"levels": [
			{"summary": "0.5s per bounce", "stats": {"player": {"bubble_bounce_invincibility": {"op": "set", "value": 0.5}}}},
			{"summary": "0.75s per bounce", "stats": {"player": {"bubble_bounce_invincibility": {"op": "set", "value": 0.75}}}},
			{"summary": "1s per bounce", "stats": {"player": {"bubble_bounce_invincibility": {"op": "set", "value": 1.0}}}},
		],
	},
	{
		"id": "yellow_second_wind",
		"name": "Second Wind",
		"description": "You stay invulnerable for longer after getting hit (normally 1s).",
		"levels": [
			{"summary": "1.5s after a hit", "stats": {"player": {"hit_invincibility_duration": {"op": "set", "value": 1.5}}}},
			{"summary": "2s after a hit", "stats": {"player": {"hit_invincibility_duration": {"op": "set", "value": 2.0}}}},
			{"summary": "2.5s after a hit", "stats": {"player": {"hit_invincibility_duration": {"op": "set", "value": 2.5}}}},
		],
	},
	{
		"id": "yellow_stinger",
		# Only offered once the player owns an invulnerability power-up (see
		# INVULNERABILITY_SOURCE_POWERUP_IDS).
		"requires_invulnerability_source": true,
		"name": "Stinger",
		"description": "While invulnerable, enemies you touch take damage, and your jump cooldown pauses. All your invulnerability lasts longer.",
		"levels": [
			{"summary": "Invulnerability x2", "stats": {"player": {"has_stinger": {"op": "set", "value": true}, "invincibility_mult": {"op": "set", "value": 2.0}}}},
			{"summary": "Invulnerability x2.5", "stats": {"player": {"has_stinger": {"op": "set", "value": true}, "invincibility_mult": {"op": "set", "value": 2.5}}}},
			{"summary": "Invulnerability x3", "stats": {"player": {"has_stinger": {"op": "set", "value": true}, "invincibility_mult": {"op": "set", "value": 3.0}}}},
		],
	},
	{
		"id": "yellow_long_shot",
		"name": "Long Shot",
		"description": "Your shots fly farther and hit harder the farther they travel (+100% damage per base shot range travelled).",
		"levels": [
			{"summary": "Shot distance x1.25", "stats": {"bullet": {"distance_damage_bonus": {"op": "set", "value": 1.0}, "max_distance": {"op": "mult", "value": 1.25}}}},
			{"summary": "Shot distance x1.5", "stats": {"bullet": {"distance_damage_bonus": {"op": "set", "value": 1.0}, "max_distance": {"op": "mult", "value": 1.5}}}},
			{"summary": "Shot distance x1.75", "stats": {"bullet": {"distance_damage_bonus": {"op": "set", "value": 1.0}, "max_distance": {"op": "mult", "value": 1.75}}}},
		],
	},
	{
		"id": "yellow_bullseye",
		"name": "Bullseye",
		"description": "An aimer marks the enemy your shot will hit, and your shots fly faster.",
		"levels": [
			{"summary": "Shot speed x1.25", "stats": {"player": {"has_aimer": {"op": "set", "value": true}}, "bullet": {"speed": {"op": "mult", "value": 1.25}}}},
			{"summary": "Shot speed x1.5", "stats": {"player": {"has_aimer": {"op": "set", "value": true}}, "bullet": {"speed": {"op": "mult", "value": 1.5}}}},
			{"summary": "Shot speed x1.75", "stats": {"player": {"has_aimer": {"op": "set", "value": true}}, "bullet": {"speed": {"op": "mult", "value": 1.75}}}},
		],
	},
	{
		"id": "yellow_heavy_rounds",
		"name": "Heavy Rounds",
		"description": "Your main shot fires half as often but does triple damage and passes through enemies.",
		# shoot_cooldown x2 = half the fire rate (in yellow form this also
		# doubles the charge time - see PlayerChargeShot). Damage and the
		# slower fire rate stay the same at every level; each level adds one
		# more enemy the shot passes through (same penetration_count stat as
		# gray_penetration, so the two stack).
		"levels": [
			{"summary": "Passes through 1 enemy", "stats": {"player": {"shoot_cooldown": {"op": "mult", "value": 2.0}}, "bullet": {"damage": {"op": "mult", "value": 3.0}, "penetration_count": {"op": "add", "value": 1}}}},
			{"summary": "Passes through 2 enemies", "stats": {"player": {"shoot_cooldown": {"op": "mult", "value": 2.0}}, "bullet": {"damage": {"op": "mult", "value": 3.0}, "penetration_count": {"op": "add", "value": 2}}}},
			{"summary": "Passes through 3 enemies", "stats": {"player": {"shoot_cooldown": {"op": "mult", "value": 2.0}}, "bullet": {"damage": {"op": "mult", "value": 3.0}, "penetration_count": {"op": "add", "value": 3}}}},
		],
	},
]

# ids of every power-up that can, by itself, apply the "pollinated" status
# effect to an enemy. Used to gate power-ups like yellow_pollen_blast_radius
# that only make sense once the player has some way to actually pollinate
# something. Add new pollination-granting power-ups' ids here too.
# Owning any of these unlocks power-ups flagged
# "requires_invulnerability_source" (Stinger).
const INVULNERABILITY_SOURCE_POWERUP_IDS: Array[String] = [
	"yellow_safe_landing",
	"yellow_bubble_guard",
	"yellow_second_wind",
]

# Power-ups that leave pollen residue on the field. Owning any of these
# unlocks power-ups flagged "requires_residue_source" (Pollen Haven).
const RESIDUE_SOURCE_POWERUP_IDS: Array[String] = [
	"yellow_piercing_pollen",
	"yellow_pollen_trail",
	"yellow_pollen_pop",
	"yellow_pollen_wake",
]

const POLLINATION_SOURCE_POWERUP_IDS: Array[String] = [
	"yellow_pollen_shot",
	"yellow_piercing_pollen",
	"yellow_pollen_trail",
	"yellow_pollen_pop",
	"yellow_pollen_wake",
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
	"gray": Color(0.65, 0.67, 0.72),
}

# Fallback accent color for a power-up whose enemy type isn't in
# ENEMY_TYPE_ACCENT_COLORS yet (also PowerupPopup's own default).
const DEFAULT_ACCENT_COLOR := Color(0.54901961, 0.85098039, 1.0)


## ===== POWER-UP LEVELS =====
##
## A power-up can have LEVELS. Instead of a single "stats" dict, a leveled
## power-up has a "levels" array - one entry per level, level 1 first:
##
##     "levels": [
##         {"summary": "Speed x1.5",  "stats": { ...level 1 stat changes... }},
##         {"summary": "Speed x1.75", "stats": { ...level 2 stat changes... }},
##         {"summary": "Speed x2",    "stats": { ...level 3 stat changes... }},
##     ],
##
## Getting the same power-up again moves it up one level (up to the last
## entry). Each level's "stats" REPLACE the previous level's (they are not
## stacked on top), so write each level as the full effect at that level -
## e.g. speed x1.75 at level 2, not "another x1.17". "summary" is the short
## line shown on popups/cards/the HUD for that level.
##
## Levels are tracked by Stats (see stats.gd - get_powerup_level()): levels
## earned this level (power bubbles) sit on top of levels kept for the run
## (end-of-level choice / shop / test menu), capped at the last level.
##
## To make any power-up leveled - including the yellow ones below - just
## swap its "stats" for a "levels" array. Power-ups that still use plain
## "stats" keep the old behavior (each pickup stacks another copy).

## ===== GRAY POWER-UPS =====
##
## A second, separate pool from POWERUPS_BY_ENEMY_TYPE - plain, dependable
## power-ups (more damage, more speed, more health, penetration) that are
## NEVER offered in the shop. Granted by gray-form power bubbles, and exactly
## one random gray power-up is added to the end-of-level choice popup
## whenever the player earned fewer than BaseLevel.MAX_POWERUP_CHOICES
## power-ups that level (including zero) - see
## BaseLevel._offer_run_powerup_choice() / get_random_gray_powerup() below.
## All four have 3 levels.
# How fast a Seeker Rounds (gray_homing) shot can turn toward its target at
# level 1, in radians per second (bullets/bullet.gd update_homing()). 1.2
# (~70 deg/s) bends a shot into an enemy ~30px off its line over 100px of
# travel; levels 2/3 are x1.3 / x1.6 (~45px / ~60px). Turning is capped and
# shots let go of a target they've passed, so they never circle it.
const HOMING_BASE_STRENGTH := 1.2

const GRAY_POWERUPS: Array[Dictionary] = [
	{
		"id": "gray_speed_up",
		"name": "Engine Tune-Up",
		"description": "Multiplies the ship's movement speed.",
		"levels": [
			{"summary": "Speed x1.5", "stats": {"player": {"speed": {"op": "mult", "value": 1.5}}}},
			{"summary": "Speed x1.75", "stats": {"player": {"speed": {"op": "mult", "value": 1.75}}}},
			{"summary": "Speed x2", "stats": {"player": {"speed": {"op": "mult", "value": 2.0}}}},
		],
	},
	{
		"id": "gray_damage_up",
		"name": "Sharpened Rounds",
		"description": "Multiplies the damage of the ship's main shot.",
		# Enemy health is whole numbers, so fractional damage is averaged out
		# over a run of shots (x1.5 = shots alternate 1 and 2 damage) - see
		# PlayerShooting.configure_bullet().
		"levels": [
			{"summary": "Damage x1.5", "stats": {"bullet": {"damage": {"op": "mult", "value": 1.5}}}},
			{"summary": "Damage x1.75", "stats": {"bullet": {"damage": {"op": "mult", "value": 1.75}}}},
			{"summary": "Damage x2", "stats": {"bullet": {"damage": {"op": "mult", "value": 2.0}}}},
		],
	},
	{
		"id": "gray_health_up",
		"name": "Reinforced Hull",
		"description": "Multiplies the ship's maximum health. The extra health is added right away.",
		"levels": [
			{"summary": "Health x1.5", "stats": {"player": {"max_shield": {"op": "mult", "value": 1.5}}}},
			{"summary": "Health x1.75", "stats": {"player": {"max_shield": {"op": "mult", "value": 1.75}}}},
			{"summary": "Health x2", "stats": {"player": {"max_shield": {"op": "mult", "value": 2.0}}}},
		],
	},
	{
		"id": "gray_penetration",
		"name": "Penetrator Rounds",
		"description": "The main shot passes through enemies it hits, even ones that survive, and keeps going.",
		# Penetration count is how many enemies a shot passes THROUGH (see
		# bullets/bullet.gd) - level 1 hits 2 enemies total, level 3 hits 4.
		"levels": [
			{"summary": "Passes through 1 enemy", "stats": {"bullet": {"penetration_count": {"op": "add", "value": 1}}}},
			{"summary": "Passes through 2 enemies", "stats": {"bullet": {"penetration_count": {"op": "add", "value": 2}}}},
			{"summary": "Passes through 3 enemies", "stats": {"bullet": {"penetration_count": {"op": "add", "value": 3}}}},
		],
	},
	{
		"id": "gray_shot_speed",
		"name": "Muzzle Booster",
		"description": "Multiplies how fast the ship's main shot travels.",
		"levels": [
			{"summary": "Shot speed x1.5", "stats": {"bullet": {"speed": {"op": "mult", "value": 1.5}}}},
			{"summary": "Shot speed x1.75", "stats": {"bullet": {"speed": {"op": "mult", "value": 1.75}}}},
			{"summary": "Shot speed x2", "stats": {"bullet": {"speed": {"op": "mult", "value": 2.0}}}},
		],
	},
	{
		"id": "gray_shot_range",
		"name": "Long Barrel",
		"description": "Multiplies how far the ship's main shot travels before fading.",
		"levels": [
			{"summary": "Shot distance x1.5", "stats": {"bullet": {"max_distance": {"op": "mult", "value": 1.5}}}},
			{"summary": "Shot distance x1.75", "stats": {"bullet": {"max_distance": {"op": "mult", "value": 1.75}}}},
			{"summary": "Shot distance x2", "stats": {"bullet": {"max_distance": {"op": "mult", "value": 2.0}}}},
		],
	},
	{
		"id": "gray_fire_rate",
		"name": "Rapid Cycler",
		"description": "Multiplies how often the ship fires its main shot.",
		# Fire rate x1.5 = the time between shots divided by 1.5.
		"levels": [
			{"summary": "Fire rate x1.5", "stats": {"player": {"shoot_cooldown": {"op": "mult", "value": 1.0 / 1.5}}}},
			{"summary": "Fire rate x1.75", "stats": {"player": {"shoot_cooldown": {"op": "mult", "value": 1.0 / 1.75}}}},
			{"summary": "Fire rate x2", "stats": {"player": {"shoot_cooldown": {"op": "mult", "value": 0.5}}}},
		],
	},
	{
		"id": "gray_jump_damage",
		"name": "Heavy Landing",
		"description": "Multiplies the damage of the shockwave when you land a jump.",
		"levels": [
			{"summary": "Jump damage x1.5", "stats": {"player": {"jump_damage": {"op": "mult", "value": 1.5}}}},
			{"summary": "Jump damage x1.75", "stats": {"player": {"jump_damage": {"op": "mult", "value": 1.75}}}},
			{"summary": "Jump damage x2", "stats": {"player": {"jump_damage": {"op": "mult", "value": 2.0}}}},
		],
	},
	{
		"id": "gray_jump_radius",
		"name": "Wide Impact",
		"description": "Multiplies how far the shockwave reaches when you land a jump.",
		"levels": [
			{"summary": "Shockwave size x1.5", "stats": {"player": {"jump_shockwave_radius": {"op": "mult", "value": 1.5}}}},
			{"summary": "Shockwave size x1.75", "stats": {"player": {"jump_shockwave_radius": {"op": "mult", "value": 1.75}}}},
			{"summary": "Shockwave size x2", "stats": {"player": {"jump_shockwave_radius": {"op": "mult", "value": 2.0}}}},
		],
	},
	{
		"id": "gray_bubble_charge_damage",
		"name": "Charged Shell",
		"description": "Multiplies the damage a charged (blue) bubble deals to enemies it passes through.",
		"levels": [
			{"summary": "Charged bubble damage x1.5", "stats": {"bubble": {"charged_damage": {"op": "mult", "value": 1.5}}}},
			{"summary": "Charged bubble damage x1.75", "stats": {"bubble": {"charged_damage": {"op": "mult", "value": 1.75}}}},
			{"summary": "Charged bubble damage x2", "stats": {"bubble": {"charged_damage": {"op": "mult", "value": 2.0}}}},
		],
	},
	{
		"id": "gray_bubble_jump_pop",
		"name": "Pop Blast",
		"description": "Multiplies the explosion damage when you jump on a bubble and pop it.",
		"levels": [
			{"summary": "Jump-pop damage x1.5", "stats": {"bubble": {"jump_pop_damage_mult": {"op": "mult", "value": 1.5}}}},
			{"summary": "Jump-pop damage x1.75", "stats": {"bubble": {"jump_pop_damage_mult": {"op": "mult", "value": 1.75}}}},
			{"summary": "Jump-pop damage x2", "stats": {"bubble": {"jump_pop_damage_mult": {"op": "mult", "value": 2.0}}}},
		],
	},
	{
		"id": "gray_jump_cooldown",
		"name": "Quick Recovery",
		"description": "Shortens the wait before you can jump again.",
		"levels": [
			{"summary": "Jump cooldown 90%", "stats": {"player": {"dash_cooldown": {"op": "mult", "value": 0.9}}}},
			{"summary": "Jump cooldown 80%", "stats": {"player": {"dash_cooldown": {"op": "mult", "value": 0.8}}}},
			{"summary": "Jump cooldown 70%", "stats": {"player": {"dash_cooldown": {"op": "mult", "value": 0.7}}}},
		],
	},
	{
		"id": "gray_armor",
		"name": "Plating",
		"description": "Every hit you take does less damage (but always at least 1).",
		# Flat damage reduction - see PlayerHealth.take_damage() / ARMOR_MIN_DAMAGE.
		"levels": [
			{"summary": "Armor 1", "stats": {"player": {"armor": {"op": "set", "value": 1}}}},
			{"summary": "Armor 2", "stats": {"player": {"armor": {"op": "set", "value": 2}}}},
			{"summary": "Armor 3", "stats": {"player": {"armor": {"op": "set", "value": 3}}}},
		],
	},
	{
		"id": "gray_homing",
		"name": "Seeker Rounds",
		"description": "The main shot curves toward the nearest enemy ahead of it.",
		# Level 2 / 3 turn 30% / 60% harder than level 1 (HOMING_BASE_STRENGTH).
		"levels": [
			{"summary": "Homing", "stats": {"bullet": {"homing_enabled": {"op": "set", "value": true}, "homing_strength": {"op": "set", "value": HOMING_BASE_STRENGTH * 1.0}}}},
			{"summary": "Homing +30%", "stats": {"bullet": {"homing_enabled": {"op": "set", "value": true}, "homing_strength": {"op": "set", "value": HOMING_BASE_STRENGTH * 1.3}}}},
			{"summary": "Homing +60%", "stats": {"bullet": {"homing_enabled": {"op": "set", "value": true}, "homing_strength": {"op": "set", "value": HOMING_BASE_STRENGTH * 1.6}}}},
		],
	},
	{
		"id": "gray_kill_score",
		"name": "Bounty Hunter",
		"description": "Multiplies the points every kill is worth.",
		"levels": [
			{"summary": "Kill points x1.5", "stats": {"player": {"kill_score_mult": {"op": "mult", "value": 1.5}}}},
			{"summary": "Kill points x1.75", "stats": {"player": {"kill_score_mult": {"op": "mult", "value": 1.75}}}},
			{"summary": "Kill points x2", "stats": {"player": {"kill_score_mult": {"op": "mult", "value": 2.0}}}},
		],
	},
	{
		"id": "gray_bubble_charges",
		"name": "Capacitor",
		"description": "Bubbles can hold more charges when you shoot them (normally 3).",
		"levels": [
			{"summary": "Bubble charges +1 (4)", "stats": {"bubble": {"shot_charge_max": {"op": "add", "value": 1}}}},
			{"summary": "Bubble charges +2 (5)", "stats": {"bubble": {"shot_charge_max": {"op": "add", "value": 2}}}},
			{"summary": "Bubble charges +3 (6)", "stats": {"bubble": {"shot_charge_max": {"op": "add", "value": 3}}}},
		],
	},
]

# Level override for power-bubble fusions. While set to a power-up id, EVERY
# fusion (two bubbles combining) grants exactly that power-up instead of a
# random one from the bubble's pool. Levels set it for a specific wave via
# BaseLevel.force_fusion_powerup() / clear_fusion_powerup() - e.g.
# levels/a_test.gd's bomb wave forces gray_penetration. BaseLevel._ready()
# clears it, so it never leaks into another level.
static var fusion_powerup_override_id: String = ""

# Accent color for gray power-ups (PowerupChoicePopup border/header) - kept
# separate from ENEMY_TYPE_ACCENT_COLORS since gray power-ups aren't keyed by
# an enemy type. See get_accent_color_for_powerup_id().
const GRAY_ACCENT_COLOR := Color(0.65, 0.67, 0.72)


static func get_random_gray_powerup() -> Dictionary:
	"""Pick one random power-up from GRAY_POWERUPS that ISN'T already at its
	max level for the run - the standard, always-available fallback offered
	at the end of a level whenever the player earned fewer than
	MAX_POWERUP_CHOICES power-ups that level (see
	BaseLevel._offer_run_powerup_choice()). Returns an empty dict if every
	gray power-up is maxed (or GRAY_POWERUPS is empty)."""
	var pool: Array = []
	for powerup: Dictionary in GRAY_POWERUPS:
		if Stats.get_run_powerup_level(powerup.get("id", "")) < get_max_level(powerup):
			pool.append(powerup)
	if pool.is_empty():
		return {}
	return pool[randi() % pool.size()]


static func get_powerups_for_enemy_type(enemy_type: String) -> Array:
	"""Return the FULL power-up pool for the given enemy type (including
	ones the player can't currently receive, e.g. gated by
	requires_pollination_source), or an empty array if that enemy type has
	no power-ups defined yet. Use get_available_powerups_for_enemy_type()
	when picking what a bubble can actually grant right now."""
	# Gray-form bubbles (from absorbing a gray enemy) grant gray power-ups.
	# Handled here rather than by adding "gray" to POWERUPS_BY_ENEMY_TYPE,
	# so gray power-ups still never show up in the shop.
	if enemy_type == "gray":
		return GRAY_POWERUPS
	return POWERUPS_BY_ENEMY_TYPE.get(enemy_type, [])


static func get_available_powerups_for_enemy_type(enemy_type: String) -> Array:
	"""Same as get_powerups_for_enemy_type(), but filtered down to power-ups
	the player is currently eligible to receive (e.g. excludes
	yellow_pollen_blast_radius until the player already has some way to
	apply pollination, and any leveled power-up already at max level)."""
	var pool: Array = get_powerups_for_enemy_type(enemy_type)
	var available: Array = []
	for powerup: Dictionary in pool:
		if powerup.get("requires_pollination_source", false) and not _player_has_pollination_source():
			continue
		if powerup.get("requires_invulnerability_source", false) and not _player_owns_any(INVULNERABILITY_SOURCE_POWERUP_IDS):
			continue
		if powerup.get("requires_residue_source", false) and not _player_owns_any(RESIDUE_SOURCE_POWERUP_IDS):
			continue
		# A leveled power-up already at its top level has nothing left to give.
		if is_maxed(powerup.get("id", "")):
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


static func get_powerup_pages() -> Array:
	"""Every power-up grouped by type, one group per page of the test
	picker: gray first, then each enemy type in POWERUPS_BY_ENEMY_TYPE
	(yellow...). Each page is {"title", "color", "powerups"}. New enemy
	types get their own page automatically."""
	var pages: Array = [{"title": "GRAY", "color": GRAY_ACCENT_COLOR, "powerups": GRAY_POWERUPS}]
	for enemy_type in POWERUPS_BY_ENEMY_TYPE:
		pages.append({
			"title": String(enemy_type).to_upper(),
			"color": ENEMY_TYPE_ACCENT_COLORS.get(enemy_type, DEFAULT_ACCENT_COLOR),
			"powerups": POWERUPS_BY_ENEMY_TYPE[enemy_type],
		})
	return pages


static func get_every_powerup() -> Array:
	"""EVERY power-up that exists, full stop: every enemy type's pool (see
	POWERUPS_BY_ENEMY_TYPE) UNFILTERED by eligibility gates like
	requires_pollination_source, plus every entry in GRAY_POWERUPS. Unlike
	get_all_available_powerups()/get_random_shop_offers(), this ignores
	whether the player could normally get each one yet. Used by the debug
	test menu (levels/test_menu.gd) so a developer can pick literally any
	power-up to test with."""
	var all: Array = []
	for enemy_type in POWERUPS_BY_ENEMY_TYPE:
		all.append_array(POWERUPS_BY_ENEMY_TYPE[enemy_type])
	all.append_array(GRAY_POWERUPS)
	return all


static func _player_owns_any(ids: Array[String]) -> bool:
	"""True if the player has any of these power-ups (this level, carried
	forward this run, or set from the test picker)."""
	for id in ids:
		if id in Stats.collected_powerups or id in Stats.chosen_run_powerups:
			return true
		if Stats.get_powerup_level(id) > 0:
			return true
	return false


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
	# Leveled power-ups (incl. ones set from the test picker).
	for source_id in POLLINATION_SOURCE_POWERUP_IDS:
		if Stats.get_powerup_level(source_id) > 0:
			return true
	return false


static func apply_random_powerup(player: Player, enemy_type: String) -> Dictionary:
	"""Pick a random power-up from enemy_type's pool (filtered to ones the
	player is currently eligible for) and apply it to the player via
	Stats.add_powerup() (persists for the rest of the level). Returns the
	chosen power-up dict, or an empty dict if enemy_type has no eligible
	power-ups right now. A leveled power-up the player already has goes up a
	level (see grant_for_level())."""
	if fusion_powerup_override_id != "":
		var forced := get_powerup_by_id(fusion_powerup_override_id)
		if not forced.is_empty():
			grant_for_level(forced.get("id", ""))
			return forced
		push_warning("fusion_powerup_override_id '%s' isn't a real power-up id - falling back to random" % fusion_powerup_override_id)

	var pool: Array = get_available_powerups_for_enemy_type(enemy_type)
	if pool.is_empty():
		return {}

	var powerup: Dictionary = pool[randi() % pool.size()]
	grant_for_level(powerup.get("id", ""))
	return powerup


static func get_powerup_by_id(powerup_id: String) -> Dictionary:
	"""Look up a power-up's full definition (name/description/stats) by its
	id, searching across every enemy type's pool AND GRAY_POWERUPS. Used by
	PowerupPopup to turn the id from Stats.powerup_collected into display
	text, and by BaseLevel to turn Stats.collected_powerups ids back into
	full dicts for the end-of-level choice popup. Returns an empty dict if
	no power-up with that id exists."""
	for enemy_type in POWERUPS_BY_ENEMY_TYPE:
		for powerup: Dictionary in POWERUPS_BY_ENEMY_TYPE[enemy_type]:
			if powerup.get("id", "") == powerup_id:
				return powerup
	for powerup: Dictionary in GRAY_POWERUPS:
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
	"""The color PowerupPopup/PowerupChoicePopup should border/highlight
	itself with for a given power-up id: GRAY_ACCENT_COLOR for one of the
	GRAY_POWERUPS, otherwise the color for the enemy type it came from (e.g.
	yellow for a yellow-enemy power-up). Falls back to DEFAULT_ACCENT_COLOR
	for an unknown id or an enemy type with no color registered yet."""
	for powerup: Dictionary in GRAY_POWERUPS:
		if powerup.get("id", "") == powerup_id:
			return GRAY_ACCENT_COLOR
	var enemy_type := get_enemy_type_for_powerup_id(powerup_id)
	return ENEMY_TYPE_ACCENT_COLORS.get(enemy_type, DEFAULT_ACCENT_COLOR)


# ===== LEVELS - helpers (see "POWER-UP LEVELS" near the top) =====

static func is_leveled(powerup: Dictionary) -> bool:
	"""True if this power-up uses a "levels" array (rather than plain
	"stats")."""
	return powerup.has("levels")


static func get_max_level(powerup: Dictionary) -> int:
	"""How many levels this power-up has (1 for a plain "stats" power-up)."""
	if is_leveled(powerup):
		return maxi(powerup["levels"].size(), 1)
	return 1


static func get_max_level_for_id(powerup_id: String) -> int:
	var powerup := get_powerup_by_id(powerup_id)
	if powerup.is_empty():
		return 1
	return get_max_level(powerup)


static func get_level_entry(powerup: Dictionary, level: int) -> Dictionary:
	"""The "levels" entry for `level` (1-based, clamped into range). For a
	plain "stats" power-up, a level-1 entry wrapping its stats."""
	if not is_leveled(powerup):
		return {"summary": "", "stats": powerup.get("stats", {})}
	var levels: Array = powerup["levels"]
	if levels.is_empty():
		return {}
	return levels[clampi(level, 1, levels.size()) - 1]


static func get_level_stats(powerup_id: String, level: int) -> Dictionary:
	"""Stat changes a leveled power-up applies at `level` (used by
	Stats.recompute()). Empty for level 0 / unknown ids."""
	if level <= 0:
		return {}
	var powerup := get_powerup_by_id(powerup_id)
	if powerup.is_empty():
		return {}
	return get_level_entry(powerup, level).get("stats", {})


static func get_level_summary(powerup: Dictionary, level: int) -> String:
	"""Short "what this level does" line, e.g. "Speed x1.75" ("" if the
	power-up has no per-level summaries)."""
	if level <= 0:
		return ""
	return get_level_entry(powerup, level).get("summary", "")


static func is_maxed(powerup_id: String) -> bool:
	"""True if this is a leveled power-up the player already has at its top
	level (counting this level's pickups plus the run's). Plain "stats"
	power-ups are never "maxed" - they keep stacking like before."""
	var powerup := get_powerup_by_id(powerup_id)
	if powerup.is_empty() or not is_leveled(powerup):
		return false
	return Stats.get_powerup_level(powerup_id) >= get_max_level(powerup)


static func grant_for_level(powerup_id: String) -> void:
	"""Give the player this power-up for the rest of the LEVEL (power-bubble
	pickups, the test pause menu). Leveled power-ups go up one level; plain
	ones stack another copy (old behavior). Either way Stats emits
	powerup_collected, which pops up the info screen (see
	BaseLevel._on_powerup_collected())."""
	var powerup := get_powerup_by_id(powerup_id)
	if powerup.is_empty():
		push_warning("grant_for_level: unknown power-up id '%s'" % powerup_id)
		return
	if is_leveled(powerup):
		Stats.add_leveled_powerup(powerup_id, false)
	else:
		Stats.add_powerup(powerup_id, powerup.get("stats", {}))


static func set_level_for_test(powerup_id: String, level: int) -> void:
	"""TEST TOOL: set a power-up to an exact level for the rest of this
	level (see Stats.set_leveled_powerup_level()). Plain "stats" power-ups
	have no levels, so this just grants one like grant_for_level()."""
	var powerup := get_powerup_by_id(powerup_id)
	if powerup.is_empty():
		push_warning("set_level_for_test: unknown power-up id '%s'" % powerup_id)
		return
	if is_leveled(powerup):
		Stats.set_leveled_powerup_level(powerup_id, level)
	else:
		grant_for_level(powerup_id)


static func remove_for_test(powerup_id: String) -> void:
	"""TEST TOOL: take a power-up away completely (see
	Stats.remove_powerup_completely())."""
	Stats.remove_powerup_completely(powerup_id)


static func grant_for_run(powerup_id: String) -> void:
	"""Keep this power-up for the rest of the RUN (end-of-level choice, the
	shop, the Test menu's launch). Leveled power-ups go up one run level;
	plain ones stack another copy (old behavior). No popup."""
	var powerup := get_powerup_by_id(powerup_id)
	if powerup.is_empty():
		push_warning("grant_for_run: unknown power-up id '%s'" % powerup_id)
		return
	if is_leveled(powerup):
		Stats.add_leveled_powerup(powerup_id, true)
	else:
		Stats.choose_run_powerup(powerup_id, powerup.get("stats", {}))


static func with_level_info(powerup: Dictionary, level: int) -> Dictionary:
	"""A copy of `powerup` with display info for one particular level added,
	for the popups/cards to show:
		"display_level"  - the level to show (0 = don't show a level)
		"max_level"      - its top level
		"level_summary"  - that level's summary line
	Plain "stats" power-ups get display_level 0 (no level badge)."""
	var copy := powerup.duplicate()
	if is_leveled(powerup) and level > 0:
		var max_level := get_max_level(powerup)
		copy["display_level"] = mini(level, max_level)
		copy["max_level"] = max_level
		copy["level_summary"] = get_level_summary(powerup, level)
	else:
		copy["display_level"] = 0
		copy["max_level"] = 1
		copy["level_summary"] = ""
	return copy


static func level_badge_text(display_level: int, max_level: int) -> String:
	"""e.g. "LV 2/3", or "LV 3/3 MAX" at the top level - shared by every
	place that shows a level. "" for power-ups without levels."""
	if display_level <= 0:
		return ""
	var text := "LV %d/%d" % [display_level, max_level]
	if display_level >= max_level and max_level > 1:
		text += " MAX"
	return text


# Leftover fractions of a damage point, per damage source - see whole_damage().
static var _damage_carry: Dictionary = {}


static func whole_damage(source_key: String, amount: float) -> int:
	"""(Also used for kill score - any whole-number amount a power-up
	multiplies.) Enemy health is whole numbers, but power-up multipliers make damage
	fractional (5 x 1.75 = 8.75). Rounding would make some levels identical,
	so each hit from `source_key` does the whole part and the leftover
	fraction builds up until it adds an extra point - the average is exact
	(x1.5 on 3 damage: 4, 5, 4, 5...). Same idea as
	PlayerShooting._whole_damage_for_next_shot() for the main shot."""
	var whole := floori(amount)
	var carry: float = _damage_carry.get(source_key, 0.0) + (amount - whole)
	if carry >= 0.999:
		carry -= 1.0
		whole += 1
	_damage_carry[source_key] = carry
	return whole


# Border color for each level - level 1 blue, 2 red, 3 gold. Used for the
# power-up squares in the side panel, the pickup popup and the choice cards.
# Add more entries if a power-up ever gets more than 3 levels (anything past
# the end uses the last color).
const LEVEL_COLORS: Array[Color] = [
	Color(0.3, 0.55, 1.0),    # level 1 - blue
	Color(0.95, 0.25, 0.25),  # level 2 - red
	Color(1.0, 0.8, 0.2),     # level 3 - gold
]


static func level_color(level: int) -> Color:
	"""Border color for a power-up at `level` (see LEVEL_COLORS)."""
	if level <= 0:
		return Color(0.5, 0.52, 0.6)
	return LEVEL_COLORS[mini(level, LEVEL_COLORS.size()) - 1]


static func get_owned_leveled_powerups() -> Array:
	"""Every leveled power-up the player currently has (level >= 1), in
	definition order, each as with_level_info(powerup, current level). Used
	by the side-panel power-up list (powerup_hud.gd)."""
	var owned: Array = []
	for powerup: Dictionary in get_every_powerup():
		if not is_leveled(powerup):
			continue
		var level: int = Stats.get_powerup_level(powerup.get("id", ""))
		if level > 0:
			owned.append(with_level_info(powerup, level))
	return owned
