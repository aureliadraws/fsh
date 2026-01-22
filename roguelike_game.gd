extends Node
## Roguelike Game Manager - Hook, Line & Sinker
## Full game loop with updated mechanics

# Scene references
@onready var map_screen = $MapScreen
@onready var battle_layer: CanvasLayer = $BattleLayer
@onready var battle_scene = $BattleLayer/BattleScene
@onready var map_ui = $MapScreen
@onready var rest_screen = $UILayer/RestScreen
@onready var salvage_screen = $UILayer/SalvageScreen
@onready var mystery_screen = $UILayer/MysteryScreen
@onready var merchant_screen = $UILayer/MerchantScreen
@onready var rewards_screen = $UILayer/RewardsScreen
@onready var game_over_screen = $UILayer/GameOverScreen
@onready var tutorial_screen = $TutorialLayer/TutorialScreen
@onready var transition = $TransitionManager
@onready var workstation_screen = $UILayer/WorkstationScreen
@onready var catch_viewer = $UILayer/CatchViewer
@onready var options3_menu = $Options3Layer/Options3

# Player state
var boat_hp: int = 3
var max_boat_hp: int = 3
var player_deck: Array = []
var damaged_cards: Array = []  # Cards removed until repaired at Dock
var cowries: int = 0
var current_area: int = 1

# Catch hold (fish caught, sold at Dock)
var catch_hold: Array = []
var catch_hold_capacity: int = 10

# Upgrades
var rod_strength: int = 2
var hook_cooldown_max: int = 3

# Run statistics
var nodes_cleared: int = 0
var fish_caught: int = 0
var total_cowries_earned: int = 0

# Current state
var current_node_type: MapNodeData.NodeType
var was_elite_fight: bool = false
var is_loading_save: bool = false

# Flag to prevent processing battle results multiple times
var _battle_result_processed: bool = false


func _ready() -> void:
	_connect_signals()
	
	# Initialize from GameState if available
	if has_node("/root/GameState"):
		GameState.start_new_run()
		max_boat_hp = 3 + GameState.get_max_hp_bonus()
		current_area = GameState.current_area
	
	# Check for saved run
	var has_save := false
	if Engine.has_singleton("SaveManager") or has_node("/root/SaveManager"):
		has_save = SaveManager.has_saved_run()
	else:
		has_save = FileAccess.file_exists("user://current_run.json")
	
	if has_save and not is_loading_save:
		_show_continue_prompt()
	else:
		_start_new_run()


func _connect_signals() -> void:
	# Map
	if map_ui and map_ui.has_signal("node_clicked"):
		map_ui.node_clicked.connect(_on_map_node_clicked)
	
	# Battle
	if battle_scene and battle_scene.has_signal("battle_finished"):
		battle_scene.battle_finished.connect(_on_battle_finished)
	
	# Screens
	if rest_screen and rest_screen.has_signal("rest_completed"):
		rest_screen.rest_completed.connect(_on_rest_completed)
	if salvage_screen and salvage_screen.has_signal("salvage_completed"):
		salvage_screen.salvage_completed.connect(_on_salvage_completed)
	if mystery_screen and mystery_screen.has_signal("event_completed"):
		mystery_screen.event_completed.connect(_on_mystery_completed)
	if merchant_screen and merchant_screen.has_signal("merchant_completed"):
		merchant_screen.merchant_completed.connect(_on_merchant_completed)
	if rewards_screen and rewards_screen.has_signal("rewards_completed"):
		rewards_screen.rewards_completed.connect(_on_rewards_completed)
	if game_over_screen and game_over_screen.has_signal("continue_pressed"):
		game_over_screen.continue_pressed.connect(_on_game_over_continue)
	if workstation_screen and workstation_screen.has_signal("workstation_completed"):
		workstation_screen.workstation_completed.connect(_on_workstation_completed)
	if catch_viewer and catch_viewer.has_signal("closed"):
		catch_viewer.closed.connect(_on_catch_viewer_closed)
	if options3_menu and options3_menu.has_signal("closed"):
		options3_menu.closed.connect(_on_options3_closed)
	
	# Tutorial
	if tutorial_screen and tutorial_screen.has_signal("tutorial_completed"):
		tutorial_screen.tutorial_completed.connect(_on_tutorial_completed)


func _show_continue_prompt() -> void:
	_load_saved_run()


func _start_new_run() -> void:
	_setup_starter_deck()
	boat_hp = max_boat_hp
	cowries = 0
	nodes_cleared = 0
	fish_caught = 0
	total_cowries_earned = 0
	catch_hold.clear()
	damaged_cards.clear()
	rod_strength = 2
	hook_cooldown_max = 3
	
	# Apply buffs from GameState
	if has_node("/root/GameState"):
		max_boat_hp = 3 + GameState.get_max_hp_bonus()
		boat_hp = max_boat_hp
	
	# Generate fresh map
	if map_ui and map_ui.has_method("generate_new_map"):
		map_ui.generate_new_map()
	
	_show_map()
	_update_hud()
	
	# Show tutorial on first run
	if tutorial_screen and tutorial_screen.has_method("should_show_tutorial"):
		if tutorial_screen.should_show_tutorial():
			tutorial_screen.start_tutorial()


func _on_tutorial_completed() -> void:
	pass


func _setup_starter_deck() -> void:
	player_deck.clear()
	
	# Get 10 starter deck cards
	var starters := CardDatabase.get_starter_deck()
	for card_data in starters:
		var card := CardDatabase.create_card_data(card_data.name)
		if card:
			player_deck.append(card)
	
	# Only add permanent cards from GameState if they exist and are actual upgrades
	# (not from a previous run that should have been reset)
	if has_node("/root/GameState"):
		# Clear any run-specific salvage cards (they reset each run)
		GameState.run_salvage_cards.clear()
		# Only add permanent cards if they were purchased at the shop (persist through runs)
		for card in GameState.permanent_deck:
			if card != null:
				player_deck.append(card.duplicate_card())


func _get_active_deck() -> Array:
	var active: Array = []
	for card in player_deck:
		if not card.is_damaged:
			# Apply buffs
			var buffed_card = card.duplicate_card() as CardData
			if buffed_card and has_node("/root/GameState"):
				buffed_card.hook += GameState.get_hook_bonus()
				buffed_card.line += GameState.get_line_bonus()
			if buffed_card:
				active.append(buffed_card)
	return active


# --- SCREEN MANAGEMENT ---

func _show_map() -> void:
	if map_screen:
		map_screen.visible = true
	if battle_layer:
		battle_layer.visible = false
	if battle_scene:
		battle_scene.hide_battle()
	_update_hud()


func _show_battle() -> void:
	if map_screen:
		map_screen.visible = false
	if battle_layer:
		battle_layer.visible = true
	if battle_scene:
		battle_scene.show_battle()


func _update_hud() -> void:
	# HUD removed - state is shown in Options3 menu
	pass


func _get_area_name() -> String:
	match current_area:
		1: return "The Shallows"
		2: return "Open Waters"
		3: return "The Deep"
		_: return "Unknown Waters"


func _show_catch_viewer() -> void:
	if catch_viewer and catch_viewer.has_method("show_catch"):
		catch_viewer.show_catch(catch_hold, player_deck, cowries)


func _show_options3_inventory() -> void:
	if options3_menu and options3_menu.has_method("show_options"):
		options3_menu.show_options(catch_hold, player_deck)


func _show_options3_pause() -> void:
	if options3_menu and options3_menu.has_method("show_pause"):
		options3_menu.show_pause()


func _on_options3_closed() -> void:
	pass


func _on_catch_viewer_closed() -> void:
	pass


# --- MAP NODE HANDLING ---

func _on_map_node_clicked(node: MapNodeData) -> void:
	if node == null:
		return
	
	current_node_type = node.type
	
	match node.type:
		MapNodeData.NodeType.COMBAT:
			was_elite_fight = false
			if transition:
				await transition.fade_to_black(0.3)
			_start_combat(false)
			if transition:
				await transition.fade_from_black(0.3)
		MapNodeData.NodeType.ELITE:
			was_elite_fight = true
			if transition:
				await transition.fade_to_black(0.3)
			_start_combat(true)
			if transition:
				await transition.fade_from_black(0.3)
		MapNodeData.NodeType.BOSS:
			was_elite_fight = true
			if transition:
				await transition.fade_to_black(0.3)
			_start_boss()
			if transition:
				await transition.fade_from_black(0.3)
		MapNodeData.NodeType.REST:
			_handle_rest()
		MapNodeData.NodeType.SALVAGE:
			_handle_salvage()
		MapNodeData.NodeType.MYSTERY:
			_handle_mystery()
		MapNodeData.NodeType.MERCHANT:
			_handle_merchant()
		MapNodeData.NodeType.WORKSTATION:
			_handle_workstation()


# --- COMBAT ---

func _start_combat(is_elite: bool) -> void:
	_battle_result_processed = false
	
	var enemies: Array = []
	
	var num_fish: int
	if nodes_cleared <= 2:
		num_fish = 1 if not is_elite else 2
	elif nodes_cleared <= 5:
		num_fish = 2 if not is_elite else 3
	else:
		num_fish = 2 if not is_elite else 3
	
	var pool: Array = FishDatabase.get_encounter_pool(is_elite)
	
	# First, generate initial fish selections
	var selected_fish: Array = []
	for i in num_fish:
		if pool.size() > 0:
			var fish_dict: Dictionary = pool[randi() % pool.size()]
			selected_fish.append(fish_dict)
	
	# Post-process for special fish spawning rules:
	# 1. Sardines should spawn in groups of 2+ (School ability)
	# 2. Senorita should only spawn with other fish (Polish ability)
	
	var has_sardine := false
	var sardine_count := 0
	var has_senorita := false
	var senorita_indices: Array = []
	
	for i in selected_fish.size():
		var fish_name: String = selected_fish[i].get("name", "")
		if fish_name == "Sardine":
			has_sardine = true
			sardine_count += 1
		elif fish_name == "Senorita":
			has_senorita = true
			senorita_indices.append(i)
	
	# Rule 1: If only 1 sardine was selected, add more sardines (at least 2 total)
	if has_sardine and sardine_count == 1:
		# Add 1-2 more sardines
		var extra_sardines := randi_range(1, 2)
		for _j in extra_sardines:
			if selected_fish.size() < 4:  # Don't exceed 4 fish
				var sardine_dict := FishDatabase.get_fish("Sardine")
				if not sardine_dict.is_empty():
					selected_fish.append(sardine_dict)
	
	# Rule 2: If senorita is alone (only fish), replace with different fish or add another fish
	if has_senorita and selected_fish.size() == 1:
		# Add another random fish that isn't a senorita
		var non_senorita_pool: Array = []
		for fish_dict in pool:
			if fish_dict.get("name", "") != "Senorita":
				non_senorita_pool.append(fish_dict)
		
		if not non_senorita_pool.is_empty():
			var extra_fish: Dictionary = non_senorita_pool[randi() % non_senorita_pool.size()]
			selected_fish.append(extra_fish)
	
	# Create FishData from selections
	for fish_dict in selected_fish:
		var fish := FishDatabase.create_fish_data(fish_dict.get("name", ""))
		if fish:
			enemies.append(fish)
	
	_show_battle()
	
	# Play bubble sound at battle start
	if AudioManager and AudioManager.has_method("play_sfx"):
		var bubble_sound = load("res://assets/sounds/fishing/bubble.mp3")
		if bubble_sound:
			AudioManager.play_sfx(bubble_sound, -5.0)
	
	# Show first battle tutorial if not done yet
	if has_node("/root/GameState") and not GameState.first_battle_done:
		await _show_first_battle_tutorial(enemies)
		GameState.first_battle_done = true
		GameState.save_persistent_data()
	
	if battle_scene:
		var battle_board = battle_scene.get_node_or_null("UILayer/BattleBoard")
		if battle_board and battle_board.has_method("set_area_name"):
			battle_board.set_area_name(_get_area_name())
		
		battle_scene.start_battle(_get_active_deck(), enemies, boat_hp, rod_strength, hook_cooldown_max)


func _start_boss() -> void:
	_battle_result_processed = false
	
	var enemies: Array = []
	
	var elite_pool: Array = FishDatabase.get_fish_by_rarity("elite")
	if not elite_pool.is_empty():
		var boss_dict: Dictionary = elite_pool[randi() % elite_pool.size()]
		var boss := FishDatabase.create_fish_data(boss_dict.get("name", ""))
		if boss:
			enemies.append(boss)
	
	# Add support fish
	var common_pool: Array = FishDatabase.get_encounter_pool(false)
	for i in 2:
		if common_pool.size() > 0:
			var fish_dict: Dictionary = common_pool[randi() % common_pool.size()]
			var fish := FishDatabase.create_fish_data(fish_dict.get("name", ""))
			if fish:
				enemies.append(fish)
	
	_show_battle()
	
	# Play bubble sound at battle start
	if AudioManager and AudioManager.has_method("play_sfx"):
		var bubble_sound = load("res://assets/sounds/fishing/bubble.mp3")
		if bubble_sound:
			AudioManager.play_sfx(bubble_sound, -5.0)
	
	if battle_scene:
		battle_scene.start_battle(_get_active_deck(), enemies, boat_hp, rod_strength, hook_cooldown_max)


func _on_battle_finished(victory: bool, rewards: Dictionary) -> void:
	if _battle_result_processed:
		return
	_battle_result_processed = true
	
	# Get remaining boat HP from battle_scene
	var remaining_hp: int = boat_hp
	if battle_scene and battle_scene.has_method("get_remaining_boat_hp"):
		remaining_hp = battle_scene.get_remaining_boat_hp()
	
	boat_hp = remaining_hp
	
	if victory:
		# Add caught fish to hold
		var caught: Array = rewards.get("catch_hold", [])
		for catch_data in caught:
			if catch_hold.size() < catch_hold_capacity:
				catch_hold.append(catch_data)
				if has_node("/root/GameState"):
					GameState.add_to_catch(catch_data)
		
		fish_caught += caught.size()
		
		# cowries reward (more prevalent now)
		var base_cowries: int = rewards.get("cowries", 0)
		var bonus_cowries: int = randi_range(5, 15) * current_area
		var total_reward_cowries := base_cowries + bonus_cowries
		
		# Check for boss victory
		if current_node_type == MapNodeData.NodeType.BOSS:
			_handle_boss_victory()
			return
		
		# Skip rewards screen - directly add cowries and return to map
		cowries += total_reward_cowries
		total_cowries_earned += total_reward_cowries
		
		if has_node("/root/GameState"):
			GameState.add_run_cowries(total_reward_cowries)
		
		nodes_cleared += 1
		_save_run()
		
		if transition:
			await transition.fade_to_black(0.3)
		if map_ui and map_ui.has_method("on_node_completed"):
			map_ui.on_node_completed()
		_show_map()
		if transition:
			await transition.fade_from_black(0.3)
	else:
		_trigger_game_over()


func _handle_boss_victory() -> void:
	var stats := {
		"cowries": cowries,
		"nodes_cleared": nodes_cleared,
		"fish_caught": fish_caught,
		"total_cowries_earned": total_cowries_earned,
		"current_level": current_area,
	}
	
	if game_over_screen and game_over_screen.has_method("show_victory"):
		game_over_screen.show_victory(stats)


func _on_rewards_completed(result: Dictionary) -> void:
	var cowries_reward: int = result.get("cowries", 0)
	cowries += cowries_reward
	total_cowries_earned += cowries_reward
	
	if has_node("/root/GameState"):
		GameState.add_run_cowries(cowries_reward)
	
	var card: CardData = result.get("card")
	if card:
		player_deck.append(card)
		if has_node("/root/GameState"):
			GameState.add_run_salvage_card(card)
	
	nodes_cleared += 1
	_save_run()
	
	if transition:
		await transition.fade_to_black(0.3)
	if map_ui and map_ui.has_method("on_node_completed"):
		map_ui.on_node_completed()
	_show_map()
	if transition:
		await transition.fade_from_black(0.3)


# --- REST (Dock) ---

func _handle_rest() -> void:
	if rest_screen and rest_screen.has_method("show_rest"):
		rest_screen.show_rest(boat_hp, max_boat_hp, damaged_cards)


func _on_rest_completed(choice: String) -> void:
	match choice:
		"heal_boat":
			boat_hp = mini(boat_hp + 1, max_boat_hp)
		"repair_cards":
			for card in damaged_cards:
				if card != null:
					card.is_damaged = false
			damaged_cards.clear()
		"sell_catch":
			var total := 0
			for catch_data in catch_hold:
				if catch_data != null:
					total += catch_data.get("cowries", 0)
			cowries += total
			total_cowries_earned += total
			if has_node("/root/GameState"):
				GameState.add_run_cowries(total)
			catch_hold.clear()
		"skip":
			pass
	
	nodes_cleared += 1
	_save_run()
	if map_ui and map_ui.has_method("on_node_completed"):
		map_ui.on_node_completed()
	_update_hud()


# --- SALVAGE ---

func _handle_salvage() -> void:
	var is_first := (nodes_cleared == 0)
	
	if salvage_screen and salvage_screen.has_method("show_salvage"):
		salvage_screen.show_salvage([], player_deck, is_first)


func _on_salvage_completed(result: Dictionary) -> void:
	var crafted: Array = result.get("crafted", [])
	for card in crafted:
		if card != null:
			player_deck.append(card)
	
	nodes_cleared += 1
	_save_run()
	if map_ui and map_ui.has_method("on_node_completed"):
		map_ui.on_node_completed()
	_update_hud()


# --- MYSTERY ---

func _handle_mystery() -> void:
	if mystery_screen and mystery_screen.has_method("show_event"):
		# Pass all necessary info: deck, catch_hold, cowries, and stolen nationalities
		var stolen_nations: Array = []
		if has_node("/root/GameState") and GameState.has_method("get_stolen_nationalities"):
			stolen_nations = GameState.get_stolen_nationalities()
		mystery_screen.show_event(player_deck, catch_hold, cowries, stolen_nations)


func _on_mystery_completed(result: Dictionary) -> void:
	# Ensure mystery screen is hidden
	if mystery_screen:
		mystery_screen.visible = false
	
	# --- DAMAGE / HEAL / COWRIES ---
	var damage: int = result.get("damage", 0)
	if damage > 0:
		boat_hp -= damage

	var heal: int = result.get("heal", 0)
	if heal > 0:
		boat_hp = mini(boat_hp + heal, max_boat_hp)
	
	var cowries_change: int = result.get("cowries", 0)
	if cowries_change != 0:
		cowries += cowries_change
		if cowries < 0:
			cowries = 0
		if cowries_change > 0 and has_node("/root/GameState"):
			GameState.add_run_cowries(cowries_change)
			total_cowries_earned += cowries_change
	
	# --- ARMOR ---
	var armor: int = result.get("armor", 0)
	if armor > 0:
		max_boat_hp += armor
		boat_hp += armor

	# --- LOSE / ADD FISH ---
	if result.get("lose_fish", false) and not catch_hold.is_empty():
		catch_hold.pop_back()
	
	var add_fish: Dictionary = result.get("add_fish", {})
	if not add_fish.is_empty() and catch_hold.size() < catch_hold_capacity:
		catch_hold.append(add_fish)
		fish_caught += 1

	# --- TEMP CARD ---
	var temp_card: Dictionary = result.get("temp_card", {})
	if not temp_card.is_empty():
		var card := CardData.new()
		card.card_name = temp_card.get("name", "Traded Item")
		card.hook = temp_card.get("hook", 1)
		card.line = temp_card.get("line", 1)
		card.sinker = temp_card.get("sinker", "None")
		card.sinker_power = 0
		player_deck.append(card)

	# --- BUFFS ---
	var buff: Dictionary = result.get("buff", {})
	if not buff.is_empty() and has_node("/root/GameState"):
		GameState.apply_temp_buff(buff)

	# --- HALVE REWARDS ---
	if result.get("halve_rewards", false) and has_node("/root/GameState"):
		if GameState.has_method("set_halve_next_rewards"):
			GameState.set_halve_next_rewards(true)

	# --- TRIGGER AMBUSH COMBAT ---
	if result.get("trigger_combat", false):
		var enemies: Array = []
		var pool: Array = FishDatabase.get_encounter_pool(false)
		var num_fish: int = 2
		for i in num_fish:
			if pool.size() > 0:
				var fish_dict: Dictionary = pool[randi() % pool.size()]
				var fish := FishDatabase.create_fish_data(fish_dict.get("name", ""))
				if fish:
					enemies.append(fish)
		if not enemies.is_empty() and battle_scene:
			_show_battle()
			if AudioManager and AudioManager.has_method("play_sfx"):
				var bubble_sound = load("res://assets/sounds/fishing/bubble.mp3")
				if bubble_sound:
					AudioManager.play_sfx(bubble_sound, -5.0)
			battle_scene.start_battle(_get_active_deck(), enemies, boat_hp, rod_strength, hook_cooldown_max)
		return  # Don't complete node yet

	# --- CHECK GAME OVER ---
	if boat_hp <= 0:
		_trigger_game_over()
		return

	# --- COMPLETE NODE ---
	nodes_cleared += 1
	_save_run()
	if map_ui and map_ui.has_method("on_node_completed"):
		map_ui.on_node_completed()
	_show_map()
	_update_hud()

	
	# Handle salvage rewards (random cards)
	var salvage: int = result.get("salvage", 0)
	if salvage > 0:
		for i in range(salvage):
			var common_cards := CardDatabase.get_cards_by_rarity("common")
			if not common_cards.is_empty():
				common_cards.shuffle()
				var new_card := CardDatabase.create_card_data(common_cards[0].name)
				if new_card:
					player_deck.append(new_card)
	
	# Handle stolen_from tracking
	var stolen_from = result.get("stolen_from")
	if stolen_from != null and has_node("/root/GameState"):
		if GameState.has_method("record_theft"):
			GameState.record_theft(stolen_from)
	
	# Handle trigger_combat (ambush)
	if result.get("trigger_combat", false):
		# Generate enemies like a normal battle
		var enemies: Array = []
		var pool: Array = FishDatabase.get_encounter_pool(false)
		var num_fish: int = 2  # Ambush spawns 2 fish
		
		for i in num_fish:
			if pool.size() > 0:
				var fish_dict: Dictionary = pool[randi() % pool.size()]
				var fish := FishDatabase.create_fish_data(fish_dict.get("name", ""))
				if fish:
					enemies.append(fish)
		
		if not enemies.is_empty() and battle_scene:
			_show_battle()
			# Play bubble sound at battle start
			if AudioManager and AudioManager.has_method("play_sfx"):
				var bubble_sound = load("res://assets/sounds/fishing/bubble.mp3")
				if bubble_sound:
					AudioManager.play_sfx(bubble_sound, -5.0)
			battle_scene.start_battle(_get_active_deck(), enemies, boat_hp, rod_strength, hook_cooldown_max)
		return  # Don't complete node yet - battle will handle it
	
	# Check for game over
	if boat_hp <= 0:
		_trigger_game_over()
		return
	
	# Complete the mystery node - always do this at the end
	nodes_cleared += 1
	_save_run()
	
	# Ensure the node is properly marked as completed and connected nodes are available
	if map_ui and map_ui.has_method("on_node_completed"):
		map_ui.on_node_completed()
	
	# Make sure we're showing the map
	_show_map()
	_update_hud()


# --- MERCHANT ---

func _handle_merchant() -> void:
	if merchant_screen and merchant_screen.has_method("show_merchant"):
		merchant_screen.show_merchant(cowries, player_deck)


func _on_merchant_completed(result: Dictionary) -> void:
	cowries = result.get("cowries", cowries)
	
	var new_deck = result.get("deck", null)
	if new_deck != null:
		player_deck.clear()
		for card in new_deck:
			if card is CardData:
				player_deck.append(card)
	
	nodes_cleared += 1
	_save_run()
	if map_ui and map_ui.has_method("on_node_completed"):
		map_ui.on_node_completed()
	_update_hud()


# --- WORKSTATION ---

func _handle_workstation() -> void:
	if workstation_screen and workstation_screen.has_method("show_workstation"):
		workstation_screen.show_workstation(player_deck)


func _on_workstation_completed(result: Dictionary) -> void:
	var new_deck = result.get("deck", null)
	if new_deck != null:
		player_deck.clear()
		for card in new_deck:
			if card is CardData:
				player_deck.append(card)
	
	nodes_cleared += 1
	_save_run()
	if map_ui and map_ui.has_method("on_node_completed"):
		map_ui.on_node_completed()
	_update_hud()


# --- GAME OVER ---

func _trigger_game_over() -> void:
	var stats := {
		"cowries": cowries,
		"nodes_cleared": nodes_cleared,
		"fish_caught": fish_caught,
		"total_cowries_earned": total_cowries_earned,
		"area": current_area,
	}
	
	if Engine.has_singleton("SaveManager") or has_node("/root/SaveManager"):
		SaveManager.record_run_end(false, stats)
	
	if transition:
		await transition.fade_to_black(0.3)
	_show_map()
	if game_over_screen and game_over_screen.has_method("show_game_over"):
		game_over_screen.show_game_over(stats)
	if transition:
		await transition.fade_from_black(0.3)


func _on_game_over_continue() -> void:
	# Hide game over screen
	if game_over_screen:
		game_over_screen.visible = false
	
	# Get final cowries after penalty
	if game_over_screen and game_over_screen.has_method("get_final_cowries"):
		cowries = game_over_screen.get_final_cowries()
	
	# Reset run state
	boat_hp = max_boat_hp
	nodes_cleared = 0
	fish_caught = 0
	catch_hold.clear()
	damaged_cards.clear()
	
	# Reset battle flag
	_battle_result_processed = false
	
	# Setup new deck
	_setup_starter_deck()
	
	# Generate new map
	if map_ui and map_ui.has_method("generate_new_map"):
		map_ui.generate_new_map()
	
	# Show the map screen
	_show_map()
	_update_hud()
	_save_run()


# --- SAVE / LOAD ---

func _save_run() -> void:
	if not (Engine.has_singleton("SaveManager") or has_node("/root/SaveManager")):
		return
	
	# FIXED: Get map state for saving
	var map_state := {}
	if map_ui and map_ui.has_method("get_map_state"):
		map_state = map_ui.get_map_state()
	
	var run_data := {
		"boat_hp": boat_hp,
		"max_boat_hp": max_boat_hp,
		"cowries": cowries,
		"deck": player_deck,
		"damaged_cards": damaged_cards,
		"catch_hold": catch_hold,
		"current_area": current_area,
		"nodes_cleared": nodes_cleared,
		"fish_caught": fish_caught,
		"rod_strength": rod_strength,
		"hook_cooldown_max": hook_cooldown_max,
		"map_state": map_state,  # FIXED: Include map state
	}
	SaveManager.save_run(run_data)


func _load_saved_run() -> void:
	if not (Engine.has_singleton("SaveManager") or has_node("/root/SaveManager")):
		_start_new_run()
		return
	
	var run_data: Dictionary = SaveManager.load_run()
	
	if run_data.is_empty():
		_start_new_run()
		return
	
	is_loading_save = true
	
	boat_hp = run_data.get("boat_hp", 3)
	max_boat_hp = run_data.get("max_boat_hp", 3)
	cowries = run_data.get("cowries", 0)
	
	player_deck.clear()
	for card in run_data.get("deck", []):
		if card is CardData:
			player_deck.append(card)
	
	damaged_cards.clear()
	for card in run_data.get("damaged_cards", []):
		if card is CardData:
			damaged_cards.append(card)
	
	catch_hold = run_data.get("catch_hold", [])
	current_area = run_data.get("current_area", 1)
	nodes_cleared = run_data.get("nodes_cleared", 0)
	fish_caught = run_data.get("fish_caught", 0)
	rod_strength = run_data.get("rod_strength", 2)
	hook_cooldown_max = run_data.get("hook_cooldown_max", 3)
	
	if player_deck.is_empty():
		_setup_starter_deck()
	
	# FIXED: Load map state if available
	var map_state: Dictionary = run_data.get("map_state", {})
	if map_ui and not map_state.is_empty():
		if map_ui.has_method("load_map_state"):
			map_ui.load_map_state(map_state)
	elif map_ui and map_ui.has_method("generate_new_map"):
		# Fallback: generate new map if no saved state
		map_ui.generate_new_map()
	
	_update_hud()
	_show_map()
	
	is_loading_save = false


func _quit_to_menu() -> void:
	_save_run()
	if transition:
		await transition.fade_to_black(0.5)
	get_tree().change_scene_to_file("res://scenes/menus/main_menu.tscn")


# --- INPUT ---

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		# Check if options3 menu is open and close it
		if options3_menu and options3_menu.visible:
			options3_menu._close()
			return
		
		if catch_viewer and catch_viewer.visible:
			catch_viewer.visible = false
			return
		
		if rewards_screen and rewards_screen.visible:
			return  # Don't allow closing rewards screen with escape
		
		if salvage_screen and salvage_screen.visible:
			return  # Don't allow closing salvage screen with escape
		
		if merchant_screen and merchant_screen.visible:
			return  # Don't allow closing merchant screen with escape
		
		if rest_screen and rest_screen.visible:
			return  # Don't allow closing rest screen with escape
		
		if mystery_screen and mystery_screen.visible:
			return  # Don't allow closing mystery screen with escape
		
		if workstation_screen and workstation_screen.visible:
			return  # Don't allow closing workstation screen with escape
		
		# Open Options3 for pause menu
		if options3_menu:
			_show_options3_pause()
	
	# Quick access to inventory with I key
	if event.is_action_pressed("inventory"):
		if map_screen and map_screen.visible and not (options3_menu and options3_menu.visible):
			_show_options3_inventory()
	
	# Quick access to inventory with Tab
	if event.is_action_pressed("ui_focus_next"):
		if map_screen and map_screen.visible and not (options3_menu and options3_menu.visible):
			_show_options3_inventory()


## Show first battle tutorial with dialogue
func _show_first_battle_tutorial(enemies: Array) -> void:
	if not DialogueManager:
		return
	
	# Get first fish name for dialogue
	var fish_name := "fish"
	if enemies.size() > 0 and enemies[0] is FishData:
		fish_name = enemies[0].fish_name
	
	var tutorial_dialogue := [
		{"character": "olamide", "text": "Hmm... something's off about these fish. Nothing like I ever saw back home."},
		{"character": "olamide", "text": "Ah well, I'm sure they can be caught all the same."},
		{"character": "olamide", "text": "I'll probably need to use some of this salvage lying around to weaken them before I can hook 'em."},
		{"character": "narrator", "text": "Your SALVAGE deck contains useful cards with special abilities. CHUM cards are weaker but cost no bait - scrap them to afford powerful salvage cards."},
		{"character": "olamide", "text": "And this one looks hungry too. Very unusual for a %s to try to attack a vessel like mine." % fish_name},
		{"character": "narrator", "text": "Fish will attack your cards each turn. When a card's LINE reaches 0, it's destroyed. If damage overflows, your BOAT takes damage!"},
		{"character": "narrator", "text": "Watch for INCOMING FISH warnings - new fish will spawn and attack after a few turns."},
		{"character": "olamide", "text": "Looks like it's ready to be reeled in now."},
		{"character": "olamide", "text": "I'll need to precisely time my movements; if I mess up now, they'll likely escape."},
		{"character": "narrator", "text": "When a fish's LINE reaches 0, the CATCH MINIGAME starts. Press SPACE when the bar is in a GREEN ZONE to catch it. Rarer fish have more green zones!"},
	]
	
	DialogueManager.start_dialogue(tutorial_dialogue)
	await DialogueManager.dialogue_ended
