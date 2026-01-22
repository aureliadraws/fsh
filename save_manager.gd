extends Node
## Save Manager - Handles all save/load operations
## Add as autoload: Project Settings > Autoload > save_manager.gd as "SaveManager"
## FIXED: Now properly saves and loads map state for continue game

const SAVE_PATH := "user://roguelike_save.json"
const RUN_SAVE_PATH := "user://current_run.json"
const SETTINGS_PATH := "user://settings.json"

signal save_completed
signal load_completed
signal run_saved
signal run_loaded


## --- PERSISTENT SAVE (across runs) ---

func save_game(data: Dictionary) -> void:
	var json := JSON.stringify(data, "\t")
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(json)
		file.close()
		save_completed.emit()


func load_game() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return _get_default_save()
	
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return _get_default_save()
	
	var json := file.get_as_text()
	file.close()
	
	var parsed = JSON.parse_string(json)
	if parsed is Dictionary:
		load_completed.emit()
		return parsed
	
	return _get_default_save()


func _get_default_save() -> Dictionary:
	return {
		"total_cowries": 0,
		"total_runs": 0,
		"best_area": 0,
		"fish_caught": 0,
		"tutorial_completed": false,
		"unlocked_cards": [],
	}


## --- RUN SAVE (current run state) ---

func save_run(run_data: Dictionary) -> void:
	# Convert CardData to dictionaries
	var deck_data: Array = []
	for card in run_data.get("deck", []):
		if card is CardData:
			deck_data.append(_card_to_dict(card))
		elif card is Dictionary:
			deck_data.append(card)
	
	# Convert damaged_cards to dictionaries
	var damaged_data: Array = []
	for card in run_data.get("damaged_cards", []):
		if card is CardData:
			damaged_data.append(_card_to_dict(card))
		elif card is Dictionary:
			damaged_data.append(card)
	
	# Serialize catch_hold
	var catch_data: Array = []
	for catch_item in run_data.get("catch_hold", []):
		if catch_item is Dictionary:
			var serialized_catch := {}
			for key in catch_item:
				if key == "fish" and catch_item[key] is FishData:
					serialized_catch[key] = _fish_to_dict(catch_item[key])
				else:
					serialized_catch[key] = catch_item[key]
			catch_data.append(serialized_catch)
	
	var save_data := {
		"boat_hp": run_data.get("boat_hp", 3),
		"max_boat_hp": run_data.get("max_boat_hp", 3),
		"cowries": run_data.get("cowries", 0),
		"deck": deck_data,
		"damaged_cards": damaged_data,
		"catch_hold": catch_data,
		"current_area": run_data.get("current_area", 1),
		"nodes_cleared": run_data.get("nodes_cleared", 0),
		"fish_caught": run_data.get("fish_caught", 0),
		"rod_strength": run_data.get("rod_strength", 2),
		"hook_cooldown_max": run_data.get("hook_cooldown_max", 3),
		"map_state": run_data.get("map_state", {}),  # FIXED: Map state is now saved
		"timestamp": Time.get_unix_time_from_system(),
	}
	
	var json := JSON.stringify(save_data, "\t")
	var file := FileAccess.open(RUN_SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(json)
		file.close()
		run_saved.emit()


func load_run() -> Dictionary:
	if not FileAccess.file_exists(RUN_SAVE_PATH):
		return {}
	
	var file := FileAccess.open(RUN_SAVE_PATH, FileAccess.READ)
	if not file:
		return {}
	
	var json := file.get_as_text()
	file.close()
	
	var parsed = JSON.parse_string(json)
	if not parsed is Dictionary:
		return {}
	
	# Convert deck back to CardData
	var deck: Array = []
	for card_dict in parsed.get("deck", []):
		deck.append(_dict_to_card(card_dict))
	parsed["deck"] = deck
	
	# Convert damaged_cards back to CardData
	var damaged: Array = []
	for card_dict in parsed.get("damaged_cards", []):
		damaged.append(_dict_to_card(card_dict))
	parsed["damaged_cards"] = damaged
	
	# Convert catch_hold fish back to FishData
	var catch_hold: Array = []
	for catch_dict in parsed.get("catch_hold", []):
		if catch_dict is Dictionary:
			var restored_catch := {}
			for key in catch_dict:
				if key == "fish" and catch_dict[key] is Dictionary:
					restored_catch[key] = _dict_to_fish(catch_dict[key])
				else:
					restored_catch[key] = catch_dict[key]
			catch_hold.append(restored_catch)
	parsed["catch_hold"] = catch_hold
	
	run_loaded.emit()
	return parsed


func has_saved_run() -> bool:
	return FileAccess.file_exists(RUN_SAVE_PATH)


func delete_run_save() -> void:
	if FileAccess.file_exists(RUN_SAVE_PATH):
		DirAccess.remove_absolute(RUN_SAVE_PATH)


## --- SETTINGS ---

func save_settings(settings: Dictionary) -> void:
	var json := JSON.stringify(settings, "\t")
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(json)
		file.close()


func load_settings() -> Dictionary:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return _get_default_settings()
	
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if not file:
		return _get_default_settings()
	
	var json := file.get_as_text()
	file.close()
	
	var parsed = JSON.parse_string(json)
	if parsed is Dictionary:
		return parsed
	
	return _get_default_settings()


func _get_default_settings() -> Dictionary:
	return {
		"master_volume": 1.0,
		"music_volume": 0.8,
		"sfx_volume": 1.0,
		"fullscreen": false,
		"screen_shake": true,
	}


## --- CONVERSION HELPERS ---

func _card_to_dict(card: CardData) -> Dictionary:
	return {
		"name": card.card_name,
		"hook": card.hook,
		"line": card.line,
		"bait_cost": card.bait_cost,
		"sinker": card.sinker,
		"sinker_power": card.sinker_power,
		"description": card.description,
		"card_type": card.card_type,
		"is_damaged": card.is_damaged,
	}


func _dict_to_card(data: Dictionary) -> CardData:
	var card := CardData.new()
	card.card_name = data.get("name", "Unknown")
	card.hook = int(data.get("hook", 1))
	card.line = int(data.get("line", 1))
	card.bait_cost = int(data.get("bait_cost", 0))
	card.sinker = str(data.get("sinker", "None"))
	card.sinker_power = int(data.get("sinker_power", 0))
	card.description = str(data.get("description", ""))
	card.card_type = str(data.get("card_type", "Salvage"))
	card.is_damaged = data.get("is_damaged", false)
	return card


func _fish_to_dict(fish: FishData) -> Dictionary:
	return {
		"fish_name": fish.fish_name,
		"hook": fish.hook,
		"line": fish.line,
		"rarity": fish.rarity,
		"base_cowries": fish.base_cowries,
		"sinker": fish.sinker,
		"sinker_power": fish.sinker_power,
		"description": fish.description,
	}


func _dict_to_fish(data: Dictionary) -> FishData:
	var fish := FishData.new()
	fish.fish_name = data.get("fish_name", "Unknown Fish")
	fish.hook = int(data.get("hook", 1))
	fish.line = int(data.get("line", 1))
	fish.rarity = data.get("rarity", "common")
	fish.base_cowries = int(data.get("base_cowries", 10))
	fish.sinker = data.get("sinker", "None")
	fish.sinker_power = int(data.get("sinker_power", 0))
	fish.description = data.get("description", "")
	return fish


## --- MAP STATE HELPERS ---

## Serialize map nodes to dictionary for saving
func serialize_map_nodes(nodes: Array) -> Array:
	var serialized: Array = []
	for node in nodes:
		if node is MapNodeData:
			serialized.append({
				"node_id": node.node_id,
				"type": node.type,
				"row": node.row,
				"column": node.column,
				"connections": node.connections.duplicate(),
				"completed": node.completed,
				"available": node.available,
				"is_elite": node.is_elite,
				"event_id": node.event_id,
			})
	return serialized


## Deserialize map nodes from saved dictionary
func deserialize_map_nodes(data: Array) -> Array:
	var nodes: Array = []
	for node_data in data:
		if node_data is Dictionary:
			var node := MapNodeData.new()
			node.node_id = int(node_data.get("node_id", 0))
			node.type = int(node_data.get("type", 0))
			node.row = int(node_data.get("row", 0))
			node.column = int(node_data.get("column", 0))
			
			# Handle connections array
			var connections: Array[int] = []
			for conn in node_data.get("connections", []):
				connections.append(int(conn))
			node.connections = connections
			
			node.completed = node_data.get("completed", false)
			node.available = node_data.get("available", false)
			node.is_elite = node_data.get("is_elite", false)
			node.event_id = node_data.get("event_id", "")
			nodes.append(node)
	return nodes


## --- STATISTICS ---

func record_run_end(victory: bool, stats: Dictionary) -> void:
	var save_data := load_game()
	
	save_data["total_runs"] = save_data.get("total_runs", 0) + 1
	save_data["fish_caught"] = save_data.get("fish_caught", 0) + stats.get("fish_caught", 0)
	
	if victory:
		var area: int = stats.get("area", 1)
		if area > save_data.get("best_area", 0):
			save_data["best_area"] = area
	
	# Add remaining cowries (after penalty if loss)
	save_data["total_cowries"] = save_data.get("total_cowries", 0) + stats.get("final_cowries", 0)
	
	save_game(save_data)
	delete_run_save()
