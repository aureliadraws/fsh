extends Resource
class_name FishData
## Fish data structure following the Hook, Line & Sinker design
## Fish are enemies with HOOK (attack), LINE (health), and SINKER (special ability)

@export var fish_name: String = "Fish"
@export var hook: int = 1  # Damage dealt when attacking
@export var line: int = 2  # Health (max LINE)
@export var base_cowries: int = 10  # cowries value at base quality
@export var rarity: String = "common"  # common, uncommon, elite

## Fish abilities (Sinkers)
@export_enum(
	"None",
	# Movement
	"Leap",         # After attacking, swaps with nearest enemy to the right
	"Skittish",     # Flees on 2nd turn and constantly after if blocked
	"Patrol",       # Moves one slot each turn
	"Scatter",      # Moves to random slot when hit
	
	# Defensive
	"Shell",        # First X damage each turn ignored
	"Venomous",     # Recoil damage (50% rounded up)
	"Camouflage",   # Can't be targeted while other fish exist
	"Regenerate",   # Heals 1 LINE at end of turn if not damaged
	
	# Aggressive
	"Consume",      # Can one-hit cards with lower LINE
	"Ambush",       # Attacks before all other fish and player
	"Frenzy",       # Attacks twice when below half LINE
	
	# Utility/Special
	"School",       # +1 LINE per other sardine on field
	"Crab_Bucket",  # Stops other enemies from fleeing
	"Territorial",  # Can't be hooked while other fish exist
	"Circus_Act",   # Must be hooked first, or blocks hooking others
	"Angelic",      # Debuff if caught, buff if ignored and escapes
	"Polish"        # Every 2nd turn, increases another fish's quality by 1 star
) var sinker: String = "None"

@export var sinker_power: int = 0  # For abilities that need a value (like Shell)
@export_multiline var description: String = ""
@export var texture: Texture2D

## Intent system - what the fish will do instead of attacking
enum Intent {
	ATTACK,     # Default - attacks opposite card or boat
	DIVE,       # Repositioning
	REST,       # Does nothing
	FLEE,       # Will escape next turn
	SUBMERGE    # Becomes untargetable
}


func create_instance() -> Dictionary:
	return {
		"data": self,
		"current_line": line,
		"max_line": line,
		"intent": Intent.ATTACK,
		"turns_alive": 0,
		"damaged_this_turn": false,
		"stunned": false,
		"submerged": false,
		"flee_next_turn": false,
		"polished_stars": 0,  # Extra quality stars from Senorita
		"has_attacked": false,
		"shell_used": false,  # Track if shell was used this turn
	}


## Calculate catch quality based on remaining LINE
## Pristine (5 stars) = 3+ LINE remaining = best value
## Fresh (4 stars) = 2 LINE = good value  
## Mediocre (3 stars) = 1 LINE = reduced value
## Poor (2 stars) = 0 LINE = low value
## Ruined (1 star) = negative/overkill = minimal value
func calculate_quality(remaining_line: int, polished_stars: int = 0) -> Dictionary:
	var stars: int = 0
	var multiplier: float = 1.0
	var quality_name: String = "Ruined"
	
	if remaining_line >= 3:
		stars = 5
		multiplier = 1.3  # 30% bonus for pristine
		quality_name = "Pristine"
	elif remaining_line == 2:
		stars = 4
		multiplier = 1.0  # Base/ideal price
		quality_name = "Fresh"
	elif remaining_line == 1:
		stars = 3
		multiplier = 0.6  # 40% reduction
		quality_name = "Mediocre"
	elif remaining_line == 0:
		stars = 2
		multiplier = 0.35  # 65% reduction
		quality_name = "Poor"
	else:  # negative (overkill damage)
		stars = 1
		multiplier = 0.15  # 85% reduction
		quality_name = "Ruined"
	
	# Add polished stars (from Senorita ability) - max 5 stars
	stars = mini(stars + polished_stars, 5)
	
	# Recalculate multiplier based on new star count
	match stars:
		5:
			multiplier = 1.3
			quality_name = "Pristine"
		4:
			multiplier = 1.0
			quality_name = "Fresh"
		3:
			multiplier = 0.6
			quality_name = "Mediocre"
		2:
			multiplier = 0.35
			quality_name = "Poor"
		1:
			multiplier = 0.15
			quality_name = "Ruined"
	
	return {
		"stars": stars,
		"multiplier": multiplier,
		"quality_name": quality_name,
		"cowrie_value": int(base_cowries * multiplier)  # Changed from cowries_value to cowrie_value
	}


## Get behavior description for UI
func get_sinker_description() -> String:
	match sinker:
		"None": return ""
		"Leap": return "Moves to adjacent slot after attacking"
		"Skittish": return "Flees battle if its attack is blocked"
		"Patrol": return "Moves one slot each turn"
		"Scatter": return "Jumps to random slot when damaged"
		"Shell": return "Blocks first %d damage each turn" % maxi(1, sinker_power)
		"Venomous": return "Deals 50%% recoil damage to attacker"
		"Camouflage": return "Cannot be targeted while other fish exist"
		"Regenerate": return "Recovers %d LINE at end of turn" % maxi(1, sinker_power)
		"Consume": return "Destroys cards with LINE ≤ %d" % hook
		"Ambush": return "Always attacks before player cards"
		"Frenzy": return "Attacks twice when below half LINE"
		"School": return "+%d LINE for each other Sardine" % maxi(1, sinker_power)
		"Crab_Bucket": return "Other fish cannot flee while this exists"
		"Territorial": return "Cannot be hooked while other fish exist"
		"Circus_Act": return "Must be hooked before other fish"
		"Angelic": return "Inflicts curse debuff if caught"
		"Polish": return "Increases quality of adjacent fish"
		_: return ""
