class_name FishDatabase
## Complete fish database following Hook, Line & Sinker design
## All fish with HOOK/LINE/SINKER stats
## Pure static class - no autoload needed

## Base path for fish images
const FISH_IMAGE_PATH := "res://assets/fish/"

const FISH := {
	# ========== BASIC FISH (No Sinker) ==========
	"Guppy": {
		"name": "Guppy",
		"hook": 1,
		"line": 1,
		"sinker": "None",
		"sinker_power": 0,
		"base_cowries": 5,
		"description": "Tiny, harmless, nearly worthless.",
		"rarity": "common",
		"image": "gupppy.png"
	},
	"Sardine": {
		"name": "Sardine",
		"hook": 1,
		"line": 1,
		"sinker": "School",
		"sinker_power": 0,
		"base_cowries": 5,
		"description": "Strength in numbers.",
		"rarity": "common",
		"image": "sardine.png"
	},
	"Sea Bream": {
		"name": "Sea Bream",
		"hook": 1,
		"line": 2,
		"sinker": "None",
		"sinker_power": 0,
		"base_cowries": 8,
		"description": "Basic fish. Slightly tougher than a sardine.",
		"rarity": "common",
		"image": "sea_bream.png"
	},
	"Redfish": {
		"name": "Redfish",
		"hook": 2,
		"line": 2,
		"sinker": "None",
		"sinker_power": 0,
		"base_cowries": 12,
		"description": "Honest stats. No tricks.",
		"rarity": "common",
		"image": "redfish.png"
	},
	"Halfmoon": {
		"name": "Halfmoon",
		"hook": 1,
		"line": 3,
		"sinker": "None",
		"sinker_power": 0,
		"base_cowries": 10,
		"description": "Tanky but passive.",
		"rarity": "common",
		"image": "halfmoon.png"
	},
	"Kelp Bass": {
		"name": "Kelp Bass",
		"hook": 2,
		"line": 3,
		"sinker": "None",
		"sinker_power": 0,
		"base_cowries": 15,
		"description": "Solid all-rounder.",
		"rarity": "common",
		"image": "kelpbass.png"
	},
	"Opal Eye": {
		"name": "Opal Eye",
		"hook": 1,
		"line": 2,
		"sinker": "None",
		"sinker_power": 0,
		"base_cowries": 8,
		"description": "Basic small fish.",
		"rarity": "common",
		"image": "opaleye.png"
	},
	"Sea Turtle": {
		"name": "Sea Turtle",
		"hook": 0,
		"line": 5,
		"sinker": "None",
		"sinker_power": 0,
		"base_cowries": 40,
		"description": "Peaceful and incredibly durable. Won't attack.",
		"rarity": "uncommon",
		"image": "sea_turtle.png"
	},
	"Needlefish": {
		"name": "Needlefish",
		"hook": 2,
		"line": 1,
		"sinker": "None",
		"sinker_power": 0,
		"base_cowries": 10,
		"description": "Sharp and fragile. Glass cannon.",
		"rarity": "common",
		"image": "needle_fish.png"
	},
	
	# ========== AGGRESSIVE FISH ==========
	"Shark": {
		"name": "Shark",
		"hook": 3,
		"line": 3,
		"sinker": "None",
		"sinker_power": 0,
		"base_cowries": 50,
		"description": "Apex predator. High damage, tough.",
		"rarity": "rare",
		"image": "shark.png"
	},
	"Barracuda": {
		"name": "Barracuda",
		"hook": 3,
		"line": 2,
		"sinker": "Ambush",
		"sinker_power": 0,
		"base_cowries": 35,
		"description": "Strikes first, asks questions never.",
		"rarity": "uncommon",
		"image": "barracuda.png"
	},
	"Tuna": {
		"name": "Tuna",
		"hook": 2,
		"line": 3,
		"sinker": "Consume",
		"sinker_power": 2,
		"base_cowries": 30,
		"description": "Can devour weaker cards in one bite.",
		"rarity": "uncommon",
		"image": "tuna.png"
	},
	
	# ========== MOVEMENT FISH ==========
	"Salmon": {
		"name": "Salmon",
		"hook": 1,
		"line": 2,
		"sinker": "Leap",
		"sinker_power": 0,
		"base_cowries": 15,
		"description": "Athletic. Swaps position after attacking.",
		"rarity": "common",
		"image": "salmon.png"
	},
	"Mackerel": {
		"name": "Mackerel",
		"hook": 1,
		"line": 2,
		"sinker": "Skittish",
		"sinker_power": 0,
		"base_cowries": 12,
		"description": "Fast schooling fish that spooks easily.",
		"rarity": "common",
		"image": "Mackerel.png"
	},
	
	# ========== DEFENSIVE FISH ==========
	"Crab": {
		"name": "Crab",
		"hook": 2,
		"line": 1,
		"sinker": "Crab_Bucket",
		"sinker_power": 0,
		"base_cowries": 15,
		"description": "Pincers hurt. Stops others from fleeing.",
		"rarity": "common",
		"image": "crab.png"
	},
	"Lionfish": {
		"name": "Lionfish",
		"hook": 1,
		"line": 2,
		"sinker": "Venomous",
		"sinker_power": 0,
		"base_cowries": 20,
		"description": "Beautiful but dangerous to touch.",
		"rarity": "uncommon",
		"image": "lionfish.png"
	},
	"Garibaldi": {
		"name": "Garibaldi",
		"hook": 1,
		"line": 3,
		"sinker": "Territorial",
		"sinker_power": 0,
		"base_cowries": 18,
		"description": "Won't leave while defending territory.",
		"rarity": "uncommon",
		"image": "garibaldi.png"
	},
	"Giant Kelpfish": {
		"name": "Giant Kelpfish",
		"hook": 1,
		"line": 4,
		"sinker": "Camouflage",
		"sinker_power": 0,
		"base_cowries": 25,
		"description": "Hides among the kelp until alone.",
		"rarity": "uncommon",
		"image": "giantkelpfish.png"
	},
	
	# ========== SPECIAL FISH ==========
	"Clownfish": {
		"name": "Clownfish",
		"hook": 1,
		"line": 1,
		"sinker": "Circus_Act",
		"sinker_power": 0,
		"base_cowries": 12,
		"description": "Must be hooked first or blocks others.",
		"rarity": "uncommon",
		"image": "clownfish.png"
	},
	"Angelfish": {
		"name": "Angelfish",
		"hook": 1,
		"line": 1,
		"sinker": "Angelic",
		"sinker_power": 0,
		"base_cowries": 8,
		"description": "Catch it for a curse. Let it go for a blessing.",
		"rarity": "rare",
		"image": "angelfish.png"
	},
	"Senorita": {
		"name": "Senorita",
		"hook": 1,
		"line": 1,
		"sinker": "Polish",
		"sinker_power": 0,
		"base_cowries": 10,
		"description": "Cleaner fish. Improves quality of allies.",
		"rarity": "uncommon",
		"image": "senorita.png"
	},
	
	# ========== ELITE FISH ==========
	"Triggerfish": {
		"name": "Triggerfish",
		"hook": 2,
		"line": 3,
		"sinker": "Frenzy",
		"sinker_power": 0,
		"base_cowries": 35,
		"description": "Aggressive when threatened. Attacks twice when wounded.",
		"rarity": "elite",
		"image": "triggerfish.png"
	},
	"Mahi Mahi": {
		"name": "Mahi Mahi",
		"hook": 3,
		"line": 3,
		"sinker": "None",
		"sinker_power": 0,
		"base_cowries": 45,
		"description": "Fast, powerful predator.",
		"rarity": "elite",
		"image": "mahi_mahi.png"
	},
	"Flying Fish": {
		"name": "Flying Fish",
		"hook": 1,
		"line": 2,
		"sinker": "Scatter",
		"sinker_power": 0,
		"base_cowries": 20,
		"description": "Leaps away when threatened.",
		"rarity": "uncommon",
		"image": "flyingfish.png"
	},
	"Red Snapper": {
		"name": "Red Snapper",
		"hook": 2,
		"line": 3,
		"sinker": "Shell",
		"sinker_power": 1,
		"base_cowries": 28,
		"description": "Tough scales block the first hit each turn.",
		"rarity": "uncommon",
		"image": "red_snapper.png"
	},
	"Parrotfish": {
		"name": "Parrotfish",
		"hook": 1,
		"line": 4,
		"sinker": "Shell",
		"sinker_power": 1,
		"base_cowries": 22,
		"description": "Bony mouth for crushing coral. Hard to damage.",
		"rarity": "uncommon",
		"image": "parrotfish.png"
	},
	"Bluetang": {
		"name": "Bluetang",
		"hook": 2,
		"line": 2,
		"sinker": "Venomous",
		"sinker_power": 0,
		"base_cowries": 18,
		"description": "Tail spines cause nasty wounds.",
		"rarity": "uncommon",
		"image": "bluetang.png"
	},
	"Rockwrasse": {
		"name": "Rockwrasse",
		"hook": 1,
		"line": 2,
		"sinker": "Regenerate",
		"sinker_power": 0,
		"base_cowries": 15,
		"description": "Heals when left alone.",
		"rarity": "uncommon",
		"image": "rockwrasse.png"
	},
	"Sculpin": {
		"name": "Sculpin",
		"hook": 2,
		"line": 2,
		"sinker": "Ambush",
		"sinker_power": 0,
		"base_cowries": 20,
		"description": "Ambush predator. Strikes first.",
		"rarity": "uncommon",
		"image": "sculpin.png"
	},
}

## Intent descriptions for UI
const INTENT_DESCRIPTIONS := {
	"ATTACK": "Will attack",
	"DIVE": "Repositioning",
	"REST": "Resting",
	"FLEE": "Will escape!",
	"SUBMERGE": "Submerging"
}

## Sinker descriptions for UI
const SINKER_DESCRIPTIONS := {
	"None": "",
	"Leap": "Moves to adjacent slot after attacking",
	"Skittish": "Flees battle if its attack is blocked",
	"Patrol": "Moves one slot each turn",
	"Scatter": "Jumps to random slot when damaged",
	"Shell": "Blocks first hit each turn (ignores damage)",
	"Venomous": "Deals 50% recoil damage to attacker",
	"Camouflage": "Cannot be targeted while other fish exist",
	"Regenerate": "Recovers 1 LINE at end of each turn",
	"Consume": "Destroys cards with LINE ≤ its HOOK",
	"Ambush": "Always attacks before player cards",
	"Frenzy": "Attacks twice when below half LINE",
	"School": "+1 LINE for each other Sardine in battle",
	"Crab_Bucket": "Other fish cannot flee while this exists",
	"Territorial": "Cannot be hooked while other fish exist",
	"Circus_Act": "Must be hooked before other fish",
	"Angelic": "Inflicts curse debuff if caught",
	"Polish": "Increases quality of adjacent fish"
}


## Get fish data by name
static func get_fish(fish_name: String) -> Dictionary:
	if FISH.has(fish_name):
		return FISH[fish_name]
	return {}


## Get all fish of a specific rarity
static func get_fish_by_rarity(rarity: String) -> Array:
	var result := []
	for fish_name in FISH:
		if FISH[fish_name].rarity == rarity:
			result.append(FISH[fish_name])
	return result


## Get fish pool for encounters - inlined to avoid static-to-static call issues
static func get_encounter_pool(include_elite: bool = false) -> Array:
	var pool := []
	for fish_name in FISH:
		var fish_data: Dictionary = FISH[fish_name]
		var rarity: String = fish_data.rarity
		if rarity == "common" or rarity == "uncommon":
			pool.append(fish_data)
		elif include_elite and rarity == "elite":
			pool.append(fish_data)
	return pool


## Create a FishData resource from database entry
static func create_fish_data(fish_name: String) -> FishData:
	var data: Dictionary = FISH.get(fish_name, {})
	if data.is_empty():
		return null
	
	var fish := FishData.new()
	fish.fish_name = data.name
	fish.hook = data.hook
	fish.line = data.line
	fish.sinker = data.sinker
	fish.sinker_power = data.get("sinker_power", 0)
	fish.base_cowries = data.base_cowries
	fish.description = data.description
	fish.rarity = data.get("rarity", "common")  # Include rarity
	
	# Load texture if image path exists
	var image_file: String = data.get("image", "")
	if image_file != "":
		var full_path := FISH_IMAGE_PATH + image_file
		if ResourceLoader.exists(full_path):
			fish.texture = load(full_path)
	
	return fish


## Get random fish from pool - inlined pool generation
static func get_random_fish(include_elite: bool = false) -> Dictionary:
	var pool := []
	for fish_name in FISH:
		var fish_data: Dictionary = FISH[fish_name]
		var rarity: String = fish_data.rarity
		if rarity == "common" or rarity == "uncommon":
			pool.append(fish_data)
		elif include_elite and rarity == "elite":
			pool.append(fish_data)
	
	if pool.is_empty():
		return {}
	return pool[randi() % pool.size()]


## Get sinker description
static func get_sinker_description(sinker: String) -> String:
	return SINKER_DESCRIPTIONS.get(sinker, "")


## Get dynamic fish sinker description with power values
static func get_sinker_description_dynamic(sinker: String, power: int) -> String:
	match sinker:
		"Shell":
			return "Blocks first %d damage each turn" % maxi(1, power)
		"Regenerate":
			return "Recovers %d LINE at end of turn" % maxi(1, power)
		"Consume":
			return "Destroys cards with LINE ≤ %d" % power
		"School":
			return "+%d LINE per other Sardine" % maxi(1, power)
		_:
			return SINKER_DESCRIPTIONS.get(sinker, "")


## Get all fish names
static func get_all_fish_names() -> Array:
	return FISH.keys()


## Get the full image path for a fish
static func get_fish_image_path(fish_name: String) -> String:
	var data: Dictionary = FISH.get(fish_name, {})
	var image_file: String = data.get("image", "")
	if image_file != "":
		return FISH_IMAGE_PATH + image_file
	return ""
