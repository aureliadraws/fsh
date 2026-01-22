extends Node
## Global Game State - Persists across scenes and runs
## Add as autoload: Project Settings > Autoload > game_state.gd as "GameState"

signal cowries_changed(new_amount: int)
signal catch_changed(catch_hold: Array)
signal buff_applied(buff_name: String)
signal permanent_card_added(card: CardData)

## Persistent data (survives game close)
var persistent_cowries: int = 0
var permanent_deck: Array = []  # Cards permanently in deck
var permanent_buffs: Array = []  # Permanent buffs from cooking/bear
var total_fish_caught: int = 0
var current_area: int = 1  # Current area (1-5)
var highest_area_unlocked: int = 1  # Highest area beaten
var bear_salmon_given: int = 0
var bear_buff_unlocked: bool = false
var tutorial_completed: bool = false
var first_battle_done: bool = false
var fish_quality_dialogues_seen: Dictionary = {}  # Track which quality dialogues shown

## Area definitions
const AREAS := {
	1: {"name": "Shallow Waters", "difficulty": 1.0, "fish_count_mod": 0},
	2: {"name": "The Reef", "difficulty": 1.3, "fish_count_mod": 1},
	3: {"name": "Deep Currents", "difficulty": 1.6, "fish_count_mod": 1},
	4: {"name": "The Abyss", "difficulty": 2.0, "fish_count_mod": 2},
	5: {"name": "Leviathan's Domain", "difficulty": 2.5, "fish_count_mod": 2}
}

## Run data (resets on new run, partially on death)
var run_cowries: int = 0
var run_cowries_at_start: int = 0  # Track cowries at run start for death penalty
var run_items_at_start: Array = []  # Items at run start
var run_catch_hold: Array = []  # Fish caught this run
var run_salvage_cards: Array = []  # New cards gained this run (lost on death)
var run_buffs: Array = []  # Temporary buffs from cooking

## Available buffs for the game - prices balanced against fish economy
## Common fish = 5-15 cowries, Elite fish = 35-50 cowries
## Pristine multiplier = 1.5x, so max fish value ~75 cowries
const AVAILABLE_BUFFS := [
	# Tier 1: Minor buffs (50-80 cowries, ~1-2 good fish)
	{"name": "Bait Pouch", "desc": "+1 Starting Bait", "effect": "start_bait", "value": 1, "price": 50},
	{"name": "Keen Eye", "desc": "+5% better fish quality", "effect": "quality_bonus", "value": 5, "price": 60},
	{"name": "Haggler", "desc": "5% shop discount", "effect": "shop_discount", "value": 5, "price": 55},
	{"name": "Scavenger", "desc": "+1 card choice at salvage", "effect": "salvage_choices", "value": 1, "price": 65},
	
	# Tier 2: Medium buffs (100-150 cowries, ~2-3 good fish)
	{"name": "Iron Hull", "desc": "+1 Max Boat HP", "effect": "max_boat_hp", "value": 1, "price": 120},
	{"name": "Sharp Hooks", "desc": "+1 Hook damage", "effect": "hook_bonus", "value": 1, "price": 100},
	{"name": "Strong Line", "desc": "+1 Line durability", "effect": "line_bonus", "value": 1, "price": 100},
	{"name": "Thick Nets", "desc": "+1 catch minigame zones", "effect": "catch_zones", "value": 1, "price": 110},
	{"name": "Cowrie Finder", "desc": "+10% cowrie rewards", "effect": "cowrie_bonus", "value": 10, "price": 130},
	
	# Tier 3: Strong buffs (180-250 cowries, ~4-5 good fish)
	{"name": "Steel Hull", "desc": "+2 Max Boat HP", "effect": "max_boat_hp", "value": 2, "price": 220},
	{"name": "Fisher's Instinct", "desc": "See incoming fish 1 turn earlier", "effect": "fish_warning", "value": 1, "price": 180},
	{"name": "Quick Hands", "desc": "+1 card draw per turn", "effect": "draw_bonus", "value": 1, "price": 200},
	{"name": "Resilient Gear", "desc": "Cards take 1 less damage", "effect": "card_armor", "value": 1, "price": 190},
	{"name": "Merchant's Favor", "desc": "15% shop discount", "effect": "shop_discount", "value": 15, "price": 180},
	
	# Tier 4: Powerful buffs (300-400 cowries, ~6-8 good fish, major investment)
	{"name": "Master Angler", "desc": "+2 Hook damage", "effect": "hook_bonus", "value": 2, "price": 300},
	{"name": "Reinforced Line", "desc": "+2 Line durability", "effect": "line_bonus", "value": 2, "price": 300},
	{"name": "Lucky Catch", "desc": "+20% better fish quality", "effect": "quality_bonus", "value": 20, "price": 350},
	{"name": "Cowrie Magnet", "desc": "+25% cowrie rewards", "effect": "cowrie_bonus", "value": 25, "price": 380},
	{"name": "Bait Master", "desc": "+3 Starting Bait", "effect": "start_bait", "value": 3, "price": 320},
]

## Track which nationalities we've stolen from this run
var stolen_from_nationalities: Array = []

## Combined accessor for total cowries
var cowries: int:
	get: return persistent_cowries + run_cowries
	set(value):
		run_cowries = value - persistent_cowries
		cowries_changed.emit(cowries)

## Fish catch data structure
## { "name": String, "rarity": String, "cowrie_value": int, "quality_name": String, "stars": int }


func _ready() -> void:
	load_persistent_data()


## Start a new run
func start_new_run() -> void:
	run_cowries_at_start = persistent_cowries
	run_items_at_start = run_catch_hold.duplicate(true)
	run_cowries = 0
	run_catch_hold.clear()
	run_salvage_cards.clear()
	run_buffs.clear()
	stolen_from_nationalities.clear()


## Reset run state when exiting to main menu (lose all run progress)
func reset_run() -> void:
	run_cowries = 0
	run_cowries_at_start = persistent_cowries
	run_catch_hold.clear()
	run_items_at_start.clear()
	run_salvage_cards.clear()
	run_buffs.clear()
	stolen_from_nationalities.clear()
	# Reset area to start (player loses run progress)
	current_area = 1
	save_persistent_data()


## Called when player dies in combat - apply 60% penalty
func on_run_defeat() -> void:
	# Calculate what was gained this run
	var cowries_gained := run_cowries
	var cowries_penalty := int(cowries_gained * 0.6)
	
	# Keep 40% of cowries gained, lose all new salvage cards
	persistent_cowries += (cowries_gained - cowries_penalty)
	
	# Lose 60% of items gained
	var items_to_keep := int(run_catch_hold.size() * 0.4)
	while run_catch_hold.size() > items_to_keep:
		run_catch_hold.pop_back()
	
	# All new salvage cards are lost
	run_salvage_cards.clear()
	
	# Reset stolen nationalities for new run
	stolen_from_nationalities.clear()
	
	run_cowries = 0
	
	save_persistent_data()


## Called when boss is defeated
func on_boss_victory() -> void:
	# Keep all cowries and items
	persistent_cowries += run_cowries
	run_cowries = 0
	
	# Add bonus cowries for victory
	var bonus := 50 + (current_area * 25)
	persistent_cowries += bonus
	
	# Unlock next area if higher than current
	if current_area >= highest_area_unlocked:
		highest_area_unlocked = mini(current_area + 1, 5)
	
	# Keep all salvage cards
	for card in run_salvage_cards:
		permanent_deck.append(card)
	run_salvage_cards.clear()
	
	# Reset stolen nationalities
	stolen_from_nationalities.clear()
	
	save_persistent_data()


## Add cowries (during run)
func add_run_cowries(amount: int) -> void:
	run_cowries += amount
	cowries_changed.emit(cowries)



## Add fish to catch hold
func add_to_catch(fish_data: Dictionary) -> void:
	run_catch_hold.append(fish_data)
	total_fish_caught += 1
	catch_changed.emit(run_catch_hold)


## Remove fish from catch hold (for cooking/selling)
func remove_from_catch(index: int) -> Dictionary:
	if index < 0 or index >= run_catch_hold.size():
		return {}
	var fish: Dictionary = run_catch_hold[index]
	run_catch_hold.remove_at(index)
	catch_changed.emit(run_catch_hold)
	return fish


## Get catch hold
func get_catch_hold() -> Array:
	return run_catch_hold


## Clear all fish from catch hold
func clear_catch_hold() -> void:
	run_catch_hold.clear()
	catch_changed.emit(run_catch_hold)


## Add fish to catch hold (alternative to add_to_catch for consistency)
func add_to_catch_hold(fish_data: Dictionary) -> void:
	add_to_catch(fish_data)


## Add a new salvage card gained during run
func add_run_salvage_card(card: CardData) -> void:
	run_salvage_cards.append(card)


## Record that we stole from a nationality
func record_theft(nationality: int) -> void:
	if nationality not in stolen_from_nationalities:
		stolen_from_nationalities.append(nationality)


## Check if we've stolen from a nationality
func has_stolen_from(nationality: int) -> bool:
	return nationality in stolen_from_nationalities


## Get list of nationalities stolen from
func get_stolen_nationalities() -> Array:
	return stolen_from_nationalities


## Cook fish for yourself - gives buff based on quality
func cook_for_self(fish_data: Dictionary) -> Dictionary:
	var buff := {}
	var quality: String = fish_data.get("quality_name", "Fresh")
	
	match quality:
		"Pristine":
			buff = {
				"name": "Feast of Champions",
				"effect": "both_bonus",
				"value": 1,
				"duration": "next_battle",
				"description": "+1 HOOK and +1 LINE next battle"
			}
		"Fresh":
			buff = {
				"name": "Hearty Meal",
				"effect": "hook_bonus",
				"value": 1,
				"duration": "next_battle",
				"description": "+1 HOOK damage next battle"
			}
		"Mediocre":
			buff = {
				"name": "Light Snack",
				"effect": "heal",
				"value": 1,
				"duration": "instant",
				"description": "Heal 1 boat HP"
			}
		"Poor":
			buff = {
				"name": "Meager Rations",
				"effect": "bait_bonus",
				"value": 1,
				"duration": "next_battle",
				"description": "+1 starting bait next battle"
			}
		"Ruined":
			buff = {
				"name": "Desperation Meal",
				"effect": "none",
				"value": 0,
				"duration": "instant",
				"description": "No benefit"
			}
	
	if buff.effect != "none":
		run_buffs.append(buff)
		buff_applied.emit(buff.name)
	return buff


## Cook fish for trade/selling - gives cowries based on quality
func cook_for_seekers(fish_data: Dictionary) -> int:
	var base_cowries: int = fish_data.get("cowrie_value", fish_data.get("cowries_value", 10))
	var quality: String = fish_data.get("quality_name", "Fresh")
	
	# Quality multipliers for cooking
	var multiplier := 1.2  # Default Fresh
	match quality:
		"Pristine": multiplier = 1.5
		"Fresh": multiplier = 1.2
		"Mediocre": multiplier = 0.7
		"Poor": multiplier = 0.4
		"Ruined": multiplier = 0.2
	
	var cowries_earned := int(base_cowries * multiplier)
	add_run_cowries(cowries_earned)
	return cowries_earned


## Give salmon to bear
func give_salmon_to_bear() -> bool:
	# Check if player has salmon
	var salmon_index := -1
	for i in run_catch_hold.size():
		if run_catch_hold[i].get("name", "") == "Salmon":
			salmon_index = i
			break
	
	if salmon_index < 0:
		return false
	
	# Remove salmon
	remove_from_catch(salmon_index)
	bear_salmon_given += 1
	
	# Check if buff unlocked
	if bear_salmon_given >= 3 and not bear_buff_unlocked:
		bear_buff_unlocked = true
		var bear_buff := {
			"name": "Bear's Blessing",
			"effect": "permanent_hp",
			"value": 1,
			"duration": "permanent",
			"description": "+1 Max Boat HP permanently"
		}
		permanent_buffs.append(bear_buff)
		buff_applied.emit(bear_buff.name)
		save_persistent_data()
	
	return true


## Get salmon count given to bear
func get_bear_salmon_count() -> int:
	return bear_salmon_given


## Check for salmon in inventory
func has_salmon() -> bool:
	for fish in run_catch_hold:
		if fish.get("name", "") == "Salmon":
			return true
	return false

func apply_temp_buff(buff: Dictionary) -> void:
	if not buff.has("effect"):
		return

	match buff.get("duration", ""):
		"instant":
			if buff.effect == "heal":
				# example instant effect
				# apply heal here
				pass
		"next_battle":
			run_buffs.append(buff)
			buff_applied.emit(buff.get("name", "Unknown Buff"))
		"permanent":
			permanent_buffs.append(buff)
			buff_applied.emit(buff.get("name", "Unknown Buff"))


## Get active buffs for current/next run
func get_active_buffs() -> Array:
	var all_buffs := []
	all_buffs.append_array(permanent_buffs)
	all_buffs.append_array(run_buffs)
	return all_buffs


## Get buff bonus for hook
func get_hook_bonus() -> int:
	var bonus := 0
	for buff in get_active_buffs():
		if buff.effect == "hook_bonus" or buff.effect == "both_bonus":
			bonus += buff.value
	return bonus


## Get buff bonus for line
func get_line_bonus() -> int:
	var bonus := 0
	for buff in get_active_buffs():
		if buff.effect == "line_bonus" or buff.effect == "both_bonus":
			bonus += buff.value
	return bonus


## Get max HP bonus from buffs
func get_max_hp_bonus() -> int:
	var bonus := 0
	for buff in permanent_buffs:
		if buff.effect == "permanent_hp":
			bonus += buff.value
	return bonus


## Clear temporary run buffs (called after they're applied)
func clear_run_buffs() -> void:
	run_buffs.clear()


## Add permanent card to deck (from shop)
func add_permanent_card(card: CardData) -> void:
	permanent_deck.append(card)
	permanent_card_added.emit(card)
	save_persistent_data()


## Get full deck (permanent + starter)
func get_full_deck() -> Array:
	var deck: Array = []
	
	# Add starter deck
	var starters := CardDatabase.get_starter_deck()
	for card_data in starters:
		var card := CardDatabase.create_card_data(card_data.name)
		if card:
			deck.append(card)
	
	# Add permanent cards
	deck.append_array(permanent_deck)
	
	return deck


## Save persistent data
func save_persistent_data() -> void:
	var data := {
		"persistent_cowries": persistent_cowries,
		"total_fish_caught": total_fish_caught,
		"current_area": current_area,
		"highest_area_unlocked": highest_area_unlocked,
		"bear_salmon_given": bear_salmon_given,
		"bear_buff_unlocked": bear_buff_unlocked,
		"tutorial_completed": tutorial_completed,
		"first_battle_done": first_battle_done,
		"fish_quality_dialogues_seen": fish_quality_dialogues_seen,
		"permanent_buffs": permanent_buffs,
		"permanent_deck": _cards_to_dicts(permanent_deck)
	}
	
	var json := JSON.stringify(data, "\t")
	var file := FileAccess.open("user://game_state.json", FileAccess.WRITE)
	if file:
		file.store_string(json)
		file.close()


## Load persistent data
func load_persistent_data() -> void:
	if not FileAccess.file_exists("user://game_state.json"):
		return
	
	var file := FileAccess.open("user://game_state.json", FileAccess.READ)
	if not file:
		return
	
	var json := file.get_as_text()
	file.close()
	
	var data = JSON.parse_string(json)
	if not data is Dictionary:
		return
	
	# Support both old "cowries" and new "cowries" keys
	persistent_cowries = data.get("persistent_cowries", data.get("persistent_cowries", 0))
	total_fish_caught = data.get("total_fish_caught", 0)
	current_area = data.get("current_area", 1)
	highest_area_unlocked = data.get("highest_area_unlocked", 1)
	bear_salmon_given = data.get("bear_salmon_given", 0)
	bear_buff_unlocked = data.get("bear_buff_unlocked", false)
	tutorial_completed = data.get("tutorial_completed", false)
	first_battle_done = data.get("first_battle_done", false)
	fish_quality_dialogues_seen = data.get("fish_quality_dialogues_seen", {})
	permanent_buffs = data.get("permanent_buffs", [])
	permanent_deck = _dicts_to_cards(data.get("permanent_deck", []))


## Helper to convert cards to dictionaries for saving
func _cards_to_dicts(cards: Array) -> Array:
	var dicts := []
	for card in cards:
		if card is CardData:
			dicts.append({
				"name": card.card_name,
				"hook": card.hook,
				"line": card.line,
				"bait_cost": card.bait_cost,
				"sinker": card.sinker,
				"sinker_power": card.sinker_power,
				"description": card.description,
				"card_type": card.card_type
			})
	return dicts


## Helper to convert dictionaries back to cards
func _dicts_to_cards(dicts: Array) -> Array:
	var cards := []
	for dict in dicts:
		var card := CardData.new()
		card.card_name = dict.get("name", "Unknown")
		card.hook = dict.get("hook", 1)
		card.line = dict.get("line", 1)
		card.bait_cost = dict.get("bait_cost", 0)
		card.sinker = dict.get("sinker", "None")
		card.sinker_power = dict.get("sinker_power", 0)
		card.description = dict.get("description", "")
		card.card_type = dict.get("card_type", "Salvage")
		cards.append(card)
	return cards
