extends Node2D
## Battle Scene - combines boat background with battle UI
## Updated for Hook, Line & Sinker design with Fixes

signal battle_finished(victory: bool, rewards: Dictionary)

@onready var background: Node2D = $RoguelikeBackground
@onready var ui_layer: CanvasLayer = $UILayer
@onready var battle_board: Control = $UILayer/BattleBoard

var battle_manager: Node = null
var current_fish: Array = []
var current_deck: Array = []
var boat_hp: int = 3

# Flag to prevent double signal emission
var _battle_result_emitted: bool = false


func _ready() -> void:
	# Start hidden first
	hide_battle()
	
	# Use a timer to ensure everything is properly initialized
	await get_tree().process_frame
	await get_tree().process_frame
	_connect_battle_signals()


func _connect_battle_signals() -> void:
	# Get battle manager reference - it's a child of battle_board
	if battle_board:
		battle_manager = battle_board.get_node_or_null("BattleManager")
	
	if battle_manager and is_instance_valid(battle_manager):
		# Check if the signals exist before trying to connect
		if battle_manager.has_signal("battle_won"):
			# Disconnect any existing connections first to prevent duplicates
			if battle_manager.is_connected("battle_won", _on_battle_won):
				battle_manager.disconnect("battle_won", _on_battle_won)
			battle_manager.connect("battle_won", _on_battle_won)
		else:
			push_error("BattleScene: BattleManager missing battle_won signal!")
		
		if battle_manager.has_signal("battle_lost"):
			if battle_manager.is_connected("battle_lost", _on_battle_lost):
				battle_manager.disconnect("battle_lost", _on_battle_lost)
			battle_manager.connect("battle_lost", _on_battle_lost)
		else:
			push_error("BattleScene: BattleManager missing battle_lost signal!")
	else:
		push_error("BattleScene: Could not find BattleManager!")


## Show the battle UI
func show_battle() -> void:
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	if background:
		background.visible = true
		background.process_mode = Node.PROCESS_MODE_INHERIT
	if ui_layer:
		ui_layer.visible = true
	if battle_board:
		battle_board.visible = true


## Hide the battle UI  
func hide_battle() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	if background:
		background.visible = false
		background.process_mode = Node.PROCESS_MODE_DISABLED
	if ui_layer:
		ui_layer.visible = false
	if battle_board:
		battle_board.visible = false


## Start a battle with specific deck and enemies
func start_battle(deck: Array, enemies: Array, boat_health: int = 3, p_rod_strength: int = 2, p_hook_cooldown_max: int = 3) -> void:
	print("=== BATTLE_SCENE: start_battle called ===")
	print("Deck size: ", deck.size())
	print("Enemies size: ", enemies.size())
	print("Boat HP: ", boat_health)
	
	# Reset the result flag for new battle
	_battle_result_emitted = false
	
	current_deck = deck
	current_fish = enemies
	boat_hp = boat_health
	
	show_battle()
	
	# Get battle_manager directly if not set yet
	if not battle_manager or not is_instance_valid(battle_manager):
		if battle_board:
			battle_manager = battle_board.get_node_or_null("BattleManager")
		_connect_battle_signals()
	
	if battle_manager and is_instance_valid(battle_manager):
		# Check if script is loaded by checking for the method
		if battle_manager.has_method("start_battle"):
			battle_manager.start_battle(deck, enemies, boat_health, p_rod_strength, p_hook_cooldown_max)
		else:
			push_error("BattleScene: BattleManager exists but start_battle method not found!")
	else:
		push_error("BattleScene: Cannot start battle - BattleManager not found!")


func _on_battle_won(catch_hold: Array) -> void:
	if _battle_result_emitted:
		return
	_battle_result_emitted = true
	
	print("=== BATTLE_SCENE: Battle Won ===")
	
	# Calculate rewards from catch hold
	var total_cowries := 0
	var fish_caught := []
	
	for catch_data in catch_hold:
		if catch_data == null:
			continue
		var cowrie_value: int = catch_data.get("cowries", catch_data.get("cowries", 0))
		total_cowries += cowrie_value
		
		var fish = catch_data.get("fish")
		var quality = catch_data.get("quality", {})
		
		if fish != null:
			fish_caught.append({
				"name": fish.fish_name if fish.fish_name else "Unknown",
				"quality": quality.get("quality_name", "Unknown") if quality else "Unknown",
				"value": cowrie_value
			})
	
	var rewards := {
		"victory": true,
		"cowries": total_cowries,
		"fish_caught": fish_caught,
		"catch_hold": catch_hold
	}
	
	print("Total cowries: ", total_cowries)
	print("Fish caught: ", fish_caught.size())
	
	# Delay before emitting to let player see victory message
	await get_tree().create_timer(2.0).timeout
	
	if not is_inside_tree(): return
	
	battle_finished.emit(true, rewards)


func _on_battle_lost() -> void:
	if _battle_result_emitted:
		return
	_battle_result_emitted = true
	
	print("=== BATTLE_SCENE: Battle Lost ===")
	print("Boat HP when lost: ", get_remaining_boat_hp())
	
	var rewards := {
		"victory": false,
		"cowries": 0,
		"fish_caught": [],
		"catch_hold": []
	}
	
	# Safety: check tree before await
	if not is_inside_tree():
		# If we are already exiting, just emit immediately if needed or skip
		return
		
	var tree = get_tree()
	if tree == null:
		return
	
	await tree.create_timer(2.0).timeout
	
	# Safety check after await
	if not is_inside_tree():
		return
	
	battle_finished.emit(false, rewards)


## Get remaining boat HP after battle
func get_remaining_boat_hp() -> int:
	if battle_manager and is_instance_valid(battle_manager):
		return battle_manager.boat_hp
	return 0
