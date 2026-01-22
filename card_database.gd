class_name CardDatabase
## Database of all Salvage cards in Hook, Line & Sinker
## Cards have HOOK/LINE/SINKER/BAIT attributes
## Goal: Minimize harm to fish - cards focus on gentle capture, release, and utility
## Pure static class - no autoload needed

## Base path for card images
const CARD_IMAGE_PATH := "res://assets/cards/"

## Rarity tiers for card distribution:
## - starter: Base deck cards (10 total)
## - common: Salvage nodes (low quality)
## - uncommon: Merchants and salvage (medium quality)
## - rare: Shop only (highest quality, expensive)

const CARDS := {
	# ========== STARTER DECK (10 cards) ==========
	"Fishing Line": {
		"name": "Fishing Line",
		"hook": 2,  # Increased from 1
		"line": 2,
		"bait_cost": 1,
		"sinker": "None",
		"sinker_power": 0,
		"description": "Basic fishing equipment. Reliable catch.",
		"rarity": "starter",
		"card_type": "Salvage",
		"image": "fishing_line.png"
	},
	"Worn Net": {
		"name": "Worn Net",
		"hook": 1,
		"line": 2,
		"bait_cost": 1,
		"sinker": "None",
		"sinker_power": 0,
		"description": "A patched net. Catches without injury.",
		"rarity": "starter",
		"card_type": "Salvage",
		"image": "worn_net.png"
	},
	"Padded Hook": {
		"name": "Padded Hook",
		"hook": 2,  # Increased from 1
		"line": 3,
		"bait_cost": 1,
		"sinker": "None",
		"sinker_power": 0,
		"description": "Soft padding minimizes harm but hooks firmly.",
		"rarity": "starter",
		"card_type": "Salvage",
		"image": "padded_hook.png"
	},
	"Hand Net": {
		"name": "Hand Net",
		"hook": 1,
		"line": 2,
		"bait_cost": 1,
		"sinker": "Scoop",
		"sinker_power": 1,
		"description": "Gently scoop fish without hooks.",
		"rarity": "starter",
		"card_type": "Salvage",
		"image": "hand_net.png"
	},
	"Cork Float": {
		"name": "Cork Float",
		"hook": 0,
		"line": 3,
		"bait_cost": 0,
		"sinker": "None",
		"sinker_power": 0,
		"description": "Highly durable, no damage potential. Free to play.",
		"rarity": "starter",
		"card_type": "Salvage",
		"image": "cork_float.png"
	},
	"Silk Line": {
		"name": "Silk Line",
		"hook": 1,
		"line": 2,
		"bait_cost": 1,
		"sinker": "Gentle",
		"sinker_power": 1,
		"description": "Smooth silk doesn't cut scales.",
		"rarity": "starter",
		"card_type": "Salvage",
		"image": "silk_line.png"
	},
	"Bent Hook": {
		"name": "Bent Hook",
		"hook": 3,  # Increased from 2 - main damage dealer
		"line": 2,
		"bait_cost": 1,
		"sinker": "None",
		"sinker_power": 0,
		"description": "Sharp and bent for maximum grip.",
		"rarity": "starter",
		"card_type": "Salvage",
		"image": "bent_hook.png"
	},
	"Release Cage": {
		"name": "Release Cage",
		"hook": 0,
		"line": 4,
		"bait_cost": 1,
		"sinker": "Trap",
		"sinker_power": 1,
		"description": "Catches fish alive for safe release.",
		"rarity": "starter",
		"card_type": "Salvage",
		"image": "release_cage.png"
	},
	"Woven Basket": {
		"name": "Woven Basket",
		"hook": 1,
		"line": 2,
		"bait_cost": 0,
		"sinker": "None",
		"sinker_power": 0,
		"description": "Traditional basket trap. Free to play.",
		"rarity": "starter",
		"card_type": "Salvage",
		"image": "woven_basket.png"
	},
	"Old Net": {
		"name": "Old Net",
		"hook": 2,  # Increased from 1
		"line": 3,
		"bait_cost": 1,
		"sinker": "None",
		"sinker_power": 0,
		"description": "Durable and well-used.",
		"rarity": "starter",
		"card_type": "Salvage",
		"image": "old_net.png"
	},
	
	# ========== COMMON CARDS (Salvage Nodes - 8 cards) ==========
	"Mending Net": {
		"name": "Mending Net",
		"hook": 1,
		"line": 3,
		"bait_cost": 1,
		"sinker": "Repair",
		"sinker_power": 1,
		"description": "Can repair adjacent equipment.",
		"rarity": "common",
		"card_type": "Salvage",
		"image": "mending_net.png"
	},
	"Bubble Trap": {
		"name": "Bubble Trap",
		"hook": 0,
		"line": 3,
		"bait_cost": 1,
		"sinker": "Disorient",
		"sinker_power": 1,
		"description": "Bubbles confuse fish harmlessly.",
		"rarity": "common",
		"card_type": "Salvage",
		"image": "bubble_trap.png"
	},
	"Kelp Rope": {
		"name": "Kelp Rope",
		"hook": 1,
		"line": 4,
		"bait_cost": 1,
		"sinker": "None",
		"sinker_power": 0,
		"description": "Natural material, very durable.",
		"rarity": "common",
		"card_type": "Salvage",
		"image": "kelp_rope.png"
	},
	"Shell Scoop": {
		"name": "Shell Scoop",
		"hook": 1,
		"line": 2,
		"bait_cost": 1,
		"sinker": "Scoop",
		"sinker_power": 1,
		"description": "Large shell used for gentle capture.",
		"rarity": "common",
		"card_type": "Salvage",
		"image": "shell_scoop.png"
	},
	"Driftwood Rod": {
		"name": "Driftwood Rod",
		"hook": 2,
		"line": 2,
		"bait_cost": 1,
		"sinker": "None",
		"sinker_power": 0,
		"description": "Flexible driftwood bends, not breaks.",
		"rarity": "common",
		"card_type": "Salvage",
		"image": "driftwood_rod.png"
	},
	"Coral Cradle": {
		"name": "Coral Cradle",
		"hook": 0,
		"line": 5,
		"bait_cost": 2,
		"sinker": "Shelter",
		"sinker_power": 1,
		"description": "Fish rest here, reducing aggression.",
		"rarity": "common",
		"card_type": "Salvage",
		"image": "coral_cradle.png"
	},
	"Seaweed Wrap": {
		"name": "Seaweed Wrap",
		"hook": 1,
		"line": 2,
		"bait_cost": 1,
		"sinker": "Slow",
		"sinker_power": 1,
		"description": "Wraps around fish, slowing them.",
		"rarity": "common",
		"card_type": "Salvage",
		"image": "seaweed_wrap.png"
	},
	"Pebble Sinker": {
		"name": "Pebble Sinker",
		"hook": 1,
		"line": 2,
		"bait_cost": 1,
		"sinker": "Pull",
		"sinker_power": 1,
		"description": "Weight helps pull fish closer.",
		"rarity": "common",
		"card_type": "Salvage",
		"image": "pebble_sinker.png"
	},
	
	# ========== UNCOMMON CARDS (Merchants - 8 cards) ==========
	"Calming Bell": {
		"name": "Calming Bell",
		"hook": 0,
		"line": 3,
		"bait_cost": 2,
		"sinker": "Pacify",
		"sinker_power": 2,
		"description": "Sound waves calm aggressive fish.",
		"rarity": "uncommon",
		"card_type": "Salvage",
		"image": "calming_bell.png"
	},
	"Cushioned Trap": {
		"name": "Cushioned Trap",
		"hook": 1,
		"line": 4,
		"bait_cost": 2,
		"sinker": "Trap",
		"sinker_power": 2,
		"description": "Padded interior keeps fish safe.",
		"rarity": "uncommon",
		"card_type": "Salvage",
		"image": "cushioned_trap.png"
	},
	"Echo Lure": {
		"name": "Echo Lure",
		"hook": 1,
		"line": 2,
		"bait_cost": 2,
		"sinker": "Attract",
		"sinker_power": 2,
		"description": "Mimics fish calls to attract them.",
		"rarity": "uncommon",
		"card_type": "Salvage",
		"image": "echo_lure.png"
	},
	"Feather Float": {
		"name": "Feather Float",
		"hook": 1,
		"line": 3,
		"bait_cost": 2,
		"sinker": "Push",
		"sinker_power": 2,
		"description": "Gently guides fish to new positions.",
		"rarity": "uncommon",
		"card_type": "Salvage",
		"image": "feather_float.png"
	},
	"Tide Pool Net": {
		"name": "Tide Pool Net",
		"hook": 2,
		"line": 3,
		"bait_cost": 2,
		"sinker": "Shield",
		"sinker_power": 1,
		"description": "Creates a protective barrier.",
		"rarity": "uncommon",
		"card_type": "Salvage",
		"image": "tide_pool_net.png"
	},
	"Moonlight Line": {
		"name": "Moonlight Line",
		"hook": 1,
		"line": 3,
		"bait_cost": 2,
		"sinker": "Stun",
		"sinker_power": 1,
		"description": "Bioluminescent glow stuns briefly.",
		"rarity": "uncommon",
		"card_type": "Salvage",
		"image": "moonlight_line.png"
	},
	"Bamboo Pole": {
		"name": "Bamboo Pole",
		"hook": 2,
		"line": 4,
		"bait_cost": 2,
		"sinker": "None",
		"sinker_power": 0,
		"description": "Strong yet flexible bamboo.",
		"rarity": "uncommon",
		"card_type": "Salvage",
		"image": "bamboo_pole.png"
	},
	"Current Rider": {
		"name": "Current Rider",
		"hook": 1,
		"line": 2,
		"bait_cost": 1,
		"sinker": "Reposition",
		"sinker_power": 1,
		"description": "Uses water currents to move fish.",
		"rarity": "uncommon",
		"card_type": "Salvage",
		"image": "current_rider.png"
	},
	
	# ========== RARE CARDS (Shop Only - 8 cards) ==========
	"Harmony Chime": {
		"name": "Harmony Chime",
		"hook": 0,
		"line": 4,
		"bait_cost": 3,
		"sinker": "Pacify",
		"sinker_power": 3,
		"description": "All fish in encounter become passive.",
		"rarity": "rare",
		"card_type": "Salvage",
		"image": "harmony_chime.png"
	},
	"cowriesen Net": {
		"name": "cowriesen Net",
		"hook": 2,
		"line": 5,
		"bait_cost": 3,
		"sinker": "Fortune",
		"sinker_power": 2,
		"description": "Caught fish yield bonus cowries.",
		"rarity": "rare",
		"card_type": "Salvage",
		"image": "cowriesen_net.png"
	},
	"Pearl Diver": {
		"name": "Pearl Diver",
		"hook": 2,
		"line": 4,
		"bait_cost": 3,
		"sinker": "Treasure",
		"sinker_power": 1,
		"description": "May find pearls while fishing.",
		"rarity": "rare",
		"card_type": "Salvage",
		"image": "pearl_diver.png"
	},
	"Spirit Caller": {
		"name": "Spirit Caller",
		"hook": 1,
		"line": 3,
		"bait_cost": 3,
		"sinker": "Release",
		"sinker_power": 2,
		"description": "Released fish grant blessings.",
		"rarity": "rare",
		"card_type": "Salvage",
		"image": "spirit_caller.png"
	},
	"Tide Master": {
		"name": "Tide Master",
		"hook": 2,
		"line": 4,
		"bait_cost": 3,
		"sinker": "Control",
		"sinker_power": 2,
		"description": "Control fish movement completely.",
		"rarity": "rare",
		"card_type": "Salvage",
		"image": "tide_master.png"
	},
	"Ancient Weave": {
		"name": "Ancient Weave",
		"hook": 1,
		"line": 6,
		"bait_cost": 3,
		"sinker": "Shield",
		"sinker_power": 3,
		"description": "Nearly indestructible ancient net.",
		"rarity": "rare",
		"card_type": "Salvage",
		"image": "ancient_weave.png"
	},
	"Dreamer's Rod": {
		"name": "Dreamer's Rod",
		"hook": 3,
		"line": 3,
		"bait_cost": 3,
		"sinker": "Sleep",
		"sinker_power": 2,
		"description": "Fish fall into peaceful slumber.",
		"rarity": "rare",
		"card_type": "Salvage",
		"image": "dreamers_rod.png"
	},
	"Captain's Legacy": {
		"name": "Captain's Legacy",
		"hook": 3,
		"line": 5,
		"bait_cost": 4,
		"sinker": "Command",
		"sinker_power": 3,
		"description": "The ultimate fishing tool.",
		"rarity": "rare",
		"card_type": "Salvage",
		"image": "captains_legacy.png"
	},
}

## Sinker ability descriptions - expanded for fish-friendly focus
## Note: Use get_sinker_description_dynamic() for descriptions with actual power values
const SINKER_DESCRIPTIONS := {
	"None": "",
	"Attract": "Prevents fish from fleeing this battle",
	"Taunt": "All fish target this card instead of others",
	"Repair": "Heals adjacent cards after attacking",
	"Shield": "Blocks incoming damage to this card",
	"Bleed": "Fish loses LINE at end of each turn",
	"Stun": "Fish skips its next action",
	"Push": "Pushes fish to the right after attacking",
	"Pull": "Pulls fish toward this card's slot",
	"Scoop": "Gentle capture - preserves fish quality",
	"Gentle": "Reduces HOOK damage dealt to fish",
	"Trap": "Auto-catches fish at low LINE (see power)",
	"Disorient": "Fish misses its next attack",
	"Shelter": "Reduces fish aggression toward this card",
	"Slow": "Fish attacks every other turn",
	"Pacify": "Reduces fish's attack damage this turn",
	"Reposition": "Move fish without dealing damage",
	"Fortune": "Earn bonus cowries from catches",
	"Treasure": "Chance for bonus items on catch",
	"Release": "Bonus rewards for releasing fish",
	"Control": "Choose which slot fish moves to",
	"Sleep": "Fish becomes dormant for 2 turns",
	"Command": "Take full control of target fish",
}

## Combined card names for workstation
const COMBINATION_NAMES := [
	"Hybrid Catcher", "Fusion Net", "Blended Line", "Merged Trap",
	"Woven Wonder", "Dual Purpose", "Combined Force", "United Tackle",
	"Harmony Hook", "Synergy Snare", "Bound Together", "Twin Spirit",
	"Paired Might", "Double Duty", "Linked Legacy", "Joined Journey",
	"Coupled Craft", "Mixed Mastery", "Fused Fortune", "Bonded Blessing",
	"Amalgam Angler", "Composite Catch", "Integrated Implement", "Melded Method",
	"Unified Utensil", "Converged Contraption", "Consolidated Catcher", "Merged Marvel",
	"Blended Blessing", "Combined Creation", "Synthesized Snare", "Hybrid Helper",
	"Dual Design", "Joint Jig", "Paired Pole", "Twin Tackle",
	"United Undertaking", "Bound Boon", "Linked Lure", "Coupled Contraption"
]


## Get card data by name
static func get_card(card_name: String) -> Dictionary:
	if CARDS.has(card_name):
		return CARDS[card_name]
	return {}


## Get all cards of a specific rarity
static func get_cards_by_rarity(rarity: String) -> Array:
	var result := []
	for card_name in CARDS:
		if CARDS[card_name].rarity == rarity:
			result.append(CARDS[card_name])
	return result


## Get starter deck cards (10 cards)
static func get_starter_deck() -> Array:
	return get_cards_by_rarity("starter")


## Get salvage node pool (common cards)
static func get_salvage_pool() -> Array:
	return get_cards_by_rarity("common")


## Get merchant pool (common + uncommon)
static func get_merchant_pool() -> Array:
	var pool := []
	pool.append_array(get_cards_by_rarity("common"))
	pool.append_array(get_cards_by_rarity("uncommon"))
	return pool


## Get shop pool (rare cards only)
static func get_shop_pool() -> Array:
	return get_cards_by_rarity("rare")


## Get reward pool (excludes starters) - for battle rewards
static func get_reward_pool(include_rare: bool = false) -> Array:
	var pool := []
	pool.append_array(get_cards_by_rarity("common"))
	pool.append_array(get_cards_by_rarity("uncommon"))
	if include_rare:
		pool.append_array(get_cards_by_rarity("rare"))
	return pool


## Create CardData from database entry
static func create_card_data(card_name: String) -> CardData:
	var data: Dictionary = CARDS.get(card_name, {})
	if data.is_empty():
		return null
	
	var card := CardData.new()
	card.card_name = data.name
	card.hook = data.hook
	card.line = data.line
	card.bait_cost = data.bait_cost
	card.sinker = data.sinker
	card.sinker_power = data.sinker_power
	card.description = data.description
	card.card_type = data.card_type
	
	# Load texture if image path exists
	var image_file: String = data.get("image", "")
	if image_file != "":
		var full_path := CARD_IMAGE_PATH + image_file
		if ResourceLoader.exists(full_path):
			card.texture = load(full_path)
	
	return card


## Create CardData from dictionary (for combined cards)
static func create_card_from_dict(data: Dictionary) -> CardData:
	var card := CardData.new()
	card.card_name = data.get("name", "Unknown")
	card.hook = data.get("hook", 1)
	card.line = data.get("line", 1)
	card.bait_cost = data.get("bait_cost", 0)
	card.sinker = data.get("sinker", "None")
	card.sinker_power = data.get("sinker_power", 0)
	card.description = data.get("description", "")
	card.card_type = data.get("card_type", "Salvage")
	return card


## Get random card - inlined pool generation
static func get_random_card(rarity: String = "") -> Dictionary:
	var pool := []
	if rarity.is_empty():
		pool = CARDS.values()
	else:
		for card_name in CARDS:
			if CARDS[card_name].rarity == rarity:
				pool.append(CARDS[card_name])
	
	if pool.is_empty():
		return {}
	return pool[randi() % pool.size()]


## Get sinker description
static func get_sinker_description(sinker: String) -> String:
	return SINKER_DESCRIPTIONS.get(sinker, "")


## Get dynamic sinker description with actual power values shown
static func get_sinker_description_dynamic(sinker: String, power: int) -> String:
	match sinker:
		"Trap":
			return "Auto-catches fish with LINE ≤ %d" % power
		"Repair":
			return "Heals adjacent cards for %d LINE" % power
		"Shield":
			return "Blocks up to %d damage per turn" % power
		"Bleed":
			return "Fish loses %d LINE per turn" % power
		"Push":
			return "Pushes fish %d slot(s) right" % power
		"Pull":
			return "Pulls fish 1 slot toward this card"
		"Gentle":
			return "Reduces HOOK damage by %d" % power
		"Pacify":
			return "Reduces fish attack by %d this turn" % power
		"Attract":
			return "Prevents fish from fleeing"
		"Stun":
			return "Fish skips next action"
		"Disorient":
			return "Fish misses next attack"
		"Slow":
			return "Fish attacks every other turn"
		"Scoop":
			return "Preserves fish quality on catch"
		"Fortune":
			return "+%d%% cowries from catches" % (power * 10)
		"Treasure":
			return "%d%% chance for bonus items" % (power * 10)
		_:
			return SINKER_DESCRIPTIONS.get(sinker, "")


## Get all card names
static func get_all_card_names() -> Array:
	return CARDS.keys()


## Get the full image path for a card
static func get_card_image_path(card_name: String) -> String:
	var data: Dictionary = CARDS.get(card_name, {})
	var image_file: String = data.get("image", "")
	if image_file != "":
		return CARD_IMAGE_PATH + image_file
	return ""


## Get a random combination name
static func get_random_combination_name() -> String:
	return COMBINATION_NAMES[randi() % COMBINATION_NAMES.size()]


## Combine two cards at workstation
static func combine_cards(card_a: CardData, card_b: CardData) -> CardData:
	var new_card := CardData.new()
	
	# Random name from combination pool
	new_card.card_name = get_random_combination_name()
	
	# Randomly pick each attribute from either parent
	new_card.hook = card_a.hook if randf() > 0.5 else card_b.hook
	new_card.line = card_a.line if randf() > 0.5 else card_b.line
	new_card.sinker = card_a.sinker if randf() > 0.5 else card_b.sinker
	new_card.sinker_power = card_a.sinker_power if randf() > 0.5 else card_b.sinker_power
	new_card.bait_cost = card_a.bait_cost if randf() > 0.5 else card_b.bait_cost
	
	# Description combines parent names
	new_card.description = "Forged from %s and %s." % [card_a.card_name, card_b.card_name]
	new_card.card_type = "Salvage"
	
	return new_card
