extends Node

# ==========================================
# SIGNALS
# ==========================================
signal battle_started
signal turn_started(turn_number: int)
signal turn_ended
signal board_updated
signal hand_updated
signal bait_changed(new_bait: int)

signal card_played(card, slot: int)
signal card_damaged(slot: int, damage: int)
signal card_destroyed(slot: int)

signal fish_damaged(slot: int, damage: int)
signal fish_destroyed(slot: int)
signal fish_intent_changed(slot: int, intent: int)
signal fish_fled(slot: int)
signal fish_swapped(from_slot: int, to_slot: int)

signal boat_damaged(new_hp: int)
signal hook_available
signal hook_used
signal hook_cooldown_tick(turns_remaining: int)

signal catch_qte_triggered(slot: int, fish_data, remaining_line: int)
signal battle_won(catch_hold: Array)
signal battle_lost
signal draw_state_changed(can_draw: bool)

# Animation signals
signal player_attack_started(slot: int, has_target: bool)
signal player_attack_finished(slot: int)
signal fish_attack_started(slot: int, has_target: bool)
signal fish_attack_finished(slot: int)
signal all_attacks_finished

# Staggered fish signals
signal fish_incoming(slot: int, fish_data) 
signal fish_spawned(slot: int) 

# ==========================================
# CONSTANTS & VARIABLES
# ==========================================
const NUM_SLOTS: int = 4
const MAX_BAIT: int = 10
const STARTING_BAIT: int = 0 
const MAX_HAND_SIZE: int = 7

# Board state
var player_cards: Array = [] 
var fish_slots: Array = []   

# Staggered fish spawning
var pending_fish: Array = [] 

# Resources
var bait: int = 0
var boat_hp: int = 3
var max_boat_hp: int = 3

# Hook
var hook_cooldown: int = 0
var hook_cooldown_max: int = 3 
var rod_strength: int = 2        

# Decks
var salvage_deck: Array = []
var salvage_discard: Array = []
var hand: Array = []
var chum_card_template: CardData

# State Flags
var battle_active: bool = false
var turn_number: int = 0
var awaiting_qte: bool = false
var pending_qte_slot: int = -1
var has_drawn_this_turn: bool = false
var catch_hold: Array = []
var flee_blocked: bool = false

# SAFETY FLAGS
var _defeat_triggered: bool = false

# ==========================================
# INITIALIZATION
# ==========================================
func _ready() -> void:
	print("DEBUG: BattleManager Ready")
	# Setup chum card template
	chum_card_template = CardData.new()
	chum_card_template.card_name = "Chum"
	chum_card_template.hook = 0
	chum_card_template.line = 1
	chum_card_template.bait_cost = 0
	chum_card_template.sinker = "Attract"
	chum_card_template.card_type = "Chum"

func start_battle(deck: Array, enemies: Array, boat_health: int = 3, p_rod_strength: int = 2, p_hook_cooldown_max: int = 3) -> void:
	print("DEBUG: Starting Battle")
	_defeat_triggered = false
	battle_active = true
	
	if has_node("/root/MusicController"):
		var music_ctrl = get_node("/root/MusicController")
		if music_ctrl.has_method("play_battle_music"):
			music_ctrl.play_battle_music()
	
	rod_strength = p_rod_strength
	hook_cooldown_max = p_hook_cooldown_max
	
	player_cards.clear()
	fish_slots.clear()
	pending_fish.clear()
	for i in NUM_SLOTS:
		player_cards.append(null)
		fish_slots.append(null)
	
	boat_hp = boat_health
	max_boat_hp = boat_health
	
	salvage_deck.clear()
	salvage_discard.clear()
	hand.clear()
	
	for card in deck:
		if card != null and card is CardData and not card.is_damaged:
			salvage_deck.append(card.duplicate_card())
	salvage_deck.shuffle()
	
	# Fish Placement Logic
	var slot := 0
	var immediate_spawn_count := 0
	
	var console = get_node_or_null("/root/DebugConsole")
	var force_stagger: bool = false
	if console and console.has_method("should_stagger_next_encounter"):
		force_stagger = console.should_stagger_next_encounter()
		if force_stagger: console.reset_stagger_flag()
	
	for fish in enemies:
		if slot >= NUM_SLOTS: break
		if fish != null and fish is FishData:
			var should_stagger := false
			if immediate_spawn_count > 0 and slot < enemies.size():
				should_stagger = true if force_stagger else (randf() < 0.4)
			
			if should_stagger:
				pending_fish.append({
					"slot": slot,
					"fish": fish,
					"turns_until_spawn": 2
				})
				fish_incoming.emit(slot, fish)
			else:
				fish_slots[slot] = fish.create_instance()
				immediate_spawn_count += 1
			slot += 1
	
	bait = STARTING_BAIT
	turn_number = 0
	hook_cooldown = hook_cooldown_max
	awaiting_qte = false
	pending_qte_slot = -1
	catch_hold.clear()
	flee_blocked = false
	has_drawn_this_turn = false
	
	_update_flee_blocked()
	battle_started.emit()
	
	for i in 3: _draw_from_salvage()
	hand.append(chum_card_template.duplicate_card())
	hand_updated.emit()
	
	_start_turn()

# ==========================================
# TURN LOGIC & LOOP FIXES
# ==========================================
func _start_turn() -> void:
	if not battle_active or _defeat_triggered: return
	
	turn_number += 1
	print("DEBUG: Start Turn ", turn_number)
	has_drawn_this_turn = false
	
	_process_pending_fish()
	
	bait_changed.emit(bait)
	
	if hook_cooldown > 0:
		hook_cooldown -= 1
		hook_cooldown_tick.emit(hook_cooldown)
		if hook_cooldown == 0: hook_available.emit()
	
	for i in NUM_SLOTS:
		if player_cards[i] != null: player_cards[i].has_acted = false
		if fish_slots[i] != null:
			fish_slots[i].damaged_this_turn = false
			fish_slots[i].has_attacked = false
			fish_slots[i].shell_used = false
	
	_update_fish_intents()
	_update_flee_blocked()
	
	turn_started.emit(turn_number)
	draw_state_changed.emit(true)
	board_updated.emit()
	hand_updated.emit()

func _process_pending_fish() -> void:
	var next_pending_list: Array = []
	var fish_to_spawn: Array = []
	
	for pending in pending_fish:
		pending.turns_until_spawn -= 1
		if pending.turns_until_spawn <= 0:
			fish_to_spawn.append(pending)
		else:
			next_pending_list.append(pending)
	
	pending_fish = next_pending_list
	
	var any_spawned := false
	for item in fish_to_spawn:
		var slot: int = item.slot
		var fish: FishData = item.fish
		
		if fish_slots[slot] != null:
			slot = _find_empty_fish_slot()
		
		if slot >= 0 and slot < NUM_SLOTS:
			fish_slots[slot] = fish.create_instance()
			any_spawned = true
			fish_incoming.emit(item.slot, null)
			fish_spawned.emit(slot)
	
	if any_spawned: board_updated.emit()

func get_pending_fish() -> Array:
	return pending_fish

func end_turn() -> void:
	if not battle_active or awaiting_qte or _defeat_triggered: return
	print("DEBUG: End Turn Requested")
	
	turn_ended.emit()
	
	await _process_ambush_attacks_animated()
	if _defeat_triggered or not battle_active: return
	
	await _process_player_attacks_animated()
	if _defeat_triggered or not battle_active: return
	
	await _process_normal_fish_attacks_animated()
	if _defeat_triggered or not battle_active: return
	
	all_attacks_finished.emit()
	
	_process_end_of_turn_effects()
	if _defeat_triggered or not battle_active: return
	
	if _check_win():
		battle_active = false
		battle_won.emit(catch_hold)
		return
	
	_start_turn()

# ==========================================
# COMBAT & ANIMATION
# ==========================================
func _process_ambush_attacks_animated() -> void:
	for i in NUM_SLOTS:
		if _defeat_triggered or not battle_active: return
		var fish = fish_slots[i]
		if fish == null or fish.has_attacked: continue
		if fish.data != null and fish.data.sinker == "Ambush":
			await _fish_attack_animated(i)

func _process_normal_fish_attacks_animated() -> void:
	for i in NUM_SLOTS:
		if _defeat_triggered or not battle_active: return
		var fish = fish_slots[i]
		if fish == null or fish.has_attacked: continue
		await _fish_attack_animated(i)

func _fish_attack_animated(slot: int) -> void:
	if _defeat_triggered or not battle_active: return
	
	var fish = fish_slots[slot]
	if fish == null: return
	var fish_data: FishData = fish.data
	if fish_data == null: return
	
	print("DEBUG: Fish Attack Animated | Slot:", slot, " | Name:", fish_data.fish_name)
	
	fish.has_attacked = true
	fish.turns_alive += 1
	
	if fish.intent != FishData.Intent.ATTACK:
		_process_non_attack_intent(slot)
		return
		
	if fish.stunned:
		fish.stunned = false
		return
	if fish.submerged:
		fish.submerged = false
		return
	if fish_data.hook == 0: return
	
	var damage: int = fish_data.hook
	var attacks := 1
	if fish_data.sinker == "Frenzy" and fish.current_line <= fish_data.line / 2:
		attacks = 2
	
	for atk_num in attacks:
		if _defeat_triggered or not battle_active: return
		
		var target_slot := _find_nearest_player_card(slot)
		var attacks_boat := false
		
		if target_slot < 0:
			if _count_player_cards() == 0 or _count_fish() >= _count_player_cards() + 2:
				attacks_boat = true
			else:
				fish_attack_started.emit(slot, false)
				await get_tree().create_timer(0.2).timeout
				if _defeat_triggered: return
				fish_attack_finished.emit(slot)
				continue
		
		fish_attack_started.emit(slot, target_slot >= 0)
		await get_tree().create_timer(0.35).timeout
		if _defeat_triggered or not battle_active: return
		
		if attacks_boat:
			print("DEBUG: Fish attacking boat")
			_damage_boat(damage)
			if _defeat_triggered: return
			fish_attack_finished.emit(slot)
		elif target_slot >= 0:
			print("DEBUG: Fish attacking card | Target Slot:", target_slot)
			if fish_data.sinker == "Consume":
				var target_card = player_cards[target_slot]
				if target_card != null and target_card.current_line <= fish_data.hook:
					_destroy_card(target_slot)
				else:
					_damage_card(target_slot, damage)
			else:
				_damage_card(target_slot, damage)
			
			if _defeat_triggered: return
			fish_attack_finished.emit(slot)
		
		await get_tree().create_timer(0.15).timeout
		if _defeat_triggered or not battle_active: return

	if battle_active and not _defeat_triggered:
		_process_post_attack_effects(slot)

func _process_player_attacks_animated() -> void:
	var player_card_slots: Array[int] = []
	var fish_slot_list: Array[int] = []
	
	for i in NUM_SLOTS:
		if player_cards[i] != null: player_card_slots.append(i)
		if fish_slots[i] != null: fish_slot_list.append(i)
	
	if player_card_slots.is_empty() or fish_slot_list.is_empty(): return
	
	for card_slot in player_card_slots:
		if _defeat_triggered or not battle_active: return
		
		var card = player_cards[card_slot]
		if card == null: continue
		var card_data: CardData = card.data
		
		var current_fish_list: Array[int] = []
		for i in NUM_SLOTS:
			if fish_slots[i] != null: current_fish_list.append(i)
		if current_fish_list.is_empty(): break
		
		var target_fish_slot := -1
		if fish_slots[card_slot] != null:
			target_fish_slot = card_slot
		else:
			target_fish_slot = _find_nearest_fish(card_slot, current_fish_list)
		
		if target_fish_slot < 0: continue
		var fish = fish_slots[target_fish_slot]
		
		if fish.data.sinker == "Camouflage" and _count_fish() > 1:
			if target_fish_slot == card_slot:
				target_fish_slot = _find_nearest_fish_excluding(card_slot, current_fish_list, card_slot)
			else:
				target_fish_slot = _find_nearest_fish_excluding(card_slot, current_fish_list, target_fish_slot)
			if target_fish_slot == -1: continue
		
		player_attack_started.emit(card_slot, true)
		await get_tree().create_timer(0.35).timeout
		if _defeat_triggered or not battle_active: return
		
		var damage: int = card_data.hook
		if card_data.sinker == "Gentle": damage = maxi(1, damage - card_data.sinker_power)
		
		_damage_fish(target_fish_slot, damage)
		
		if fish_slots[target_fish_slot] != null:
			_process_card_sinker_ability(card_slot, card_data, target_fish_slot)
		
		player_attack_finished.emit(card_slot)
		
		var safety_timer = 0
		while awaiting_qte:
			await get_tree().create_timer(0.1).timeout
			safety_timer += 1
			if _defeat_triggered: return
			if safety_timer > 100:
				awaiting_qte = false
				print("ERROR: QTE timed out, forcing progress.")
				break
			
		await get_tree().create_timer(0.15).timeout
		if _defeat_triggered or not battle_active: return
		
		if player_cards[card_slot] != null: 
			fish = fish_slots[target_fish_slot]
			if fish != null and fish.data.sinker == "Venomous":
				var recoil: int = ceili(float(damage) / 2.0)
				_damage_card(card_slot, recoil)

# ============ SAFE DAMAGE FUNCTIONS ============
func _damage_card(slot: int, damage: int) -> void:
	print("DEBUG: _damage_card called | Slot:", slot, " | Damage:", damage)
	if not is_inside_tree() or _defeat_triggered: return
	if slot < 0 or slot >= NUM_SLOTS: return
	var card = player_cards[slot]
	if card == null:
		print("DEBUG: _damage_card | Card is null, returning")
		return
	
	var console = get_node_or_null("/root/DebugConsole")
	if console and console.has_method("is_invincible") and console.is_invincible():
		card_damaged.emit(slot, 0)
		return
	
	var previous_line: int = card.current_line
	var new_line: int = previous_line - damage
	var overkill: int = 0
	
	if new_line < 0:
		overkill = abs(new_line)
	
	card.current_line = new_line
	print("DEBUG: _damage_card | New Line:", new_line, " | Overkill:", overkill)
	
	# Emit damaged signal - UI will update display
	print("DEBUG: Emitting card_damaged signal")
	card_damaged.emit(slot, damage)
	
	if card.current_line <= 0:
		print("DEBUG: Card died, calling _destroy_card")
		_destroy_card(slot)
		
		# Overkill boat damage logic
		if overkill > 0 and not _defeat_triggered and boat_hp > 0:
			print("DEBUG: Applying Overkill to boat:", overkill)
			var actual_overkill: int = mini(overkill, boat_hp)
			_damage_boat(actual_overkill)

func _destroy_card(slot: int) -> void:
	print("DEBUG: _destroy_card called | Slot:", slot)
	if not is_inside_tree() or _defeat_triggered: return
	var card = player_cards[slot]
	if card == null: return
	
	if card.data != null:
		card.data.is_damaged = true
	
	# CRITICAL: Nullify slot BEFORE emitting signals
	player_cards[slot] = null
	print("DEBUG: _destroy_card | Slot nulled, emitting signals")
	
	card_destroyed.emit(slot)
	board_updated.emit()

func _damage_boat(damage: int) -> void:
	# GUARD: If already defeated or dead, stop immediately to prevent recursion
	if _defeat_triggered or boat_hp <= 0: return
	
	print("DEBUG: _damage_boat called | Damage:", damage)
	if not is_inside_tree() or not battle_active: return
	
	var actual_damage: int = mini(damage, boat_hp)
	boat_hp = max(0, boat_hp - actual_damage)
	
	print("DEBUG: _damage_boat | New HP:", boat_hp)
	boat_damaged.emit(boat_hp)
	
	# Trigger defeat if HP hits 0
	if boat_hp <= 0 and not _defeat_triggered:
		print("DEBUG: Boat died, triggering defeat sequence")
		_trigger_defeat()

func _trigger_defeat() -> void:
	if _defeat_triggered: return
	print("DEBUG: Triggering Defeat")
	_defeat_triggered = true
	battle_active = false
	boat_hp = 0
	
	# Stop any pending QTEs immediately
	awaiting_qte = false
	pending_qte_slot = -1
	
	if has_node("/root/MusicController"):
		var music_ctrl = get_node("/root/MusicController")
		if music_ctrl.has_method("play_roguelike_music"):
			music_ctrl.play_roguelike_music()
	
	# Use call_deferred to allow the current frame (and any loops) to finish cleanly
	# This prevents crashes if the scene changes while a loop is running
	call_deferred("emit_signal", "battle_lost")

func _damage_fish(slot: int, damage: int) -> void:
	if not is_inside_tree(): return
	var fish = fish_slots[slot]
	if fish == null: return
	
	fish.damaged_this_turn = true
	if fish.data.sinker == "Shell" and not fish.shell_used:
		fish.shell_used = true
		damage = maxi(0, damage - fish.data.sinker_power)
		if damage == 0: return
		
	fish.current_line -= damage
	fish_damaged.emit(slot, damage)
	
	if fish.data.sinker == "Scatter" and fish.current_line > 0:
		_fish_dive(slot)
		
	if fish.current_line <= 0:
		_trigger_catch_qte(slot)

# ============ UTILITY FUNCTIONS ============
func _find_nearest_fish(card_slot: int, fish_slot_list: Array[int]) -> int:
	if fish_slot_list.is_empty(): return -1
	var nearest := -1
	var nearest_dist := 999
	for fish_slot in fish_slot_list:
		var dist := absi(fish_slot - card_slot)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = fish_slot
	return nearest

func _find_nearest_fish_excluding(card_slot: int, fish_slot_list: Array[int], exclude_slot: int) -> int:
	if fish_slot_list.is_empty(): return -1
	var nearest := -1
	var nearest_dist := 999
	for fish_slot in fish_slot_list:
		if fish_slot == exclude_slot: continue
		var dist := absi(fish_slot - card_slot)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = fish_slot
	return nearest

func _find_nearest_player_card(fish_slot: int) -> int:
	if player_cards[fish_slot] != null: return fish_slot
	var nearest := -1
	var nearest_dist := 999
	for i in NUM_SLOTS:
		if player_cards[i] != null:
			var dist := absi(i - fish_slot)
			if dist < nearest_dist:
				nearest_dist = dist
				nearest = i
	return nearest
	
func _find_empty_fish_slot() -> int:
	for i in NUM_SLOTS:
		if fish_slots[i] == null: return i
	return -1

func _count_fish() -> int:
	var count := 0
	for fish in fish_slots:
		if fish != null: count += 1
	return count

func _count_player_cards() -> int:
	var count := 0
	for card in player_cards:
		if card != null: count += 1
	return count

func _check_win() -> bool:
	return _count_fish() == 0 and pending_fish.is_empty()

# ============ PLAYER INTERACTION ============
func play_card(hand_index: int, slot: int) -> bool:
	if not battle_active or awaiting_qte or _defeat_triggered: return false
	if slot < 0 or slot >= NUM_SLOTS: return false
	if hand_index < 0 or hand_index >= hand.size(): return false
	var card = hand[hand_index]
	if card == null: return false
	if bait < card.bait_cost: return false
	
	bait -= card.bait_cost
	bait_changed.emit(bait)
	hand.remove_at(hand_index)
	
	if player_cards[slot] != null:
		hand.append(player_cards[slot].data)
		
	player_cards[slot] = {"data": card, "current_line": card.line, "has_acted": false}
	card_played.emit(card, slot)
	board_updated.emit()
	hand_updated.emit()
	return true

func scrap_card_from_hand(hand_index: int) -> bool:
	if not battle_active or awaiting_qte: return false
	var card = hand[hand_index]
	bait = mini(bait + card.get_scrap_value(), MAX_BAIT)
	bait_changed.emit(bait)
	hand.remove_at(hand_index)
	if card.card_type == "Salvage": salvage_discard.append(card)
	hand_updated.emit()
	return true

func scrap_card_from_board(slot: int) -> bool:
	if not battle_active or awaiting_qte: return false
	if player_cards[slot] == null: return false
	var card = player_cards[slot].data
	bait = mini(bait + card.get_scrap_value(), MAX_BAIT)
	bait_changed.emit(bait)
	if card.card_type == "Salvage": salvage_discard.append(card)
	player_cards[slot] = null
	board_updated.emit()
	return true

func draw_from_salvage() -> bool:
	if not battle_active or awaiting_qte or has_drawn_this_turn or hand.size() >= MAX_HAND_SIZE: return false
	if not _draw_from_salvage(): return false
	has_drawn_this_turn = true
	draw_state_changed.emit(false)
	return true

func draw_from_chum() -> bool:
	if not battle_active or awaiting_qte or has_drawn_this_turn or hand.size() >= MAX_HAND_SIZE: return false
	hand.append(chum_card_template.duplicate_card())
	has_drawn_this_turn = true
	draw_state_changed.emit(false)
	hand_updated.emit()
	return true

func _draw_from_salvage() -> bool:
	if salvage_deck.is_empty():
		for c in salvage_discard: salvage_deck.append(c)
		salvage_discard.clear()
		salvage_deck.shuffle()
	if salvage_deck.is_empty(): return false
	hand.append(salvage_deck.pop_back())
	hand_updated.emit()
	return true

func try_hook_fish(slot: int) -> bool:
	if not battle_active or awaiting_qte or hook_cooldown > 0: return false
	var fish = fish_slots[slot]
	if fish == null: return false
	if fish.current_line > rod_strength: return false
	
	if fish.submerged: return false
	var fish_data = fish.data
	if _count_fish() > 1:
		if fish_data.sinker == "Territorial" or fish_data.sinker == "Camouflage": return false
		if fish_data.sinker != "Circus_Act":
			for i in NUM_SLOTS:
				if i != slot and fish_slots[i] != null and fish_slots[i].data.sinker == "Circus_Act": return false
	
	hook_cooldown = hook_cooldown_max
	hook_used.emit()
	awaiting_qte = true
	pending_qte_slot = slot
	catch_qte_triggered.emit(slot, fish_data, fish.current_line)
	return true

func resolve_catch(success: bool, quality_stars: int = 1) -> void:
	if pending_qte_slot < 0:
		awaiting_qte = false
		return
	
	var fish = fish_slots[pending_qte_slot]
	if fish != null:
		if success:
			var quality = fish.data.calculate_quality(fish.current_line, fish.polished_stars)
			catch_hold.append({"fish": fish.data, "quality": quality, "cowries": quality.cowrie_value})
			if fish.data.sinker == "Angelic":
				if has_node("/root/GameState"):
					var curse = {"name": "Angelic Curse", "desc": "-1 Hook damage", "effect": "hook_penalty", "value": 1, "temporary": true}
					get_node("/root/GameState").run_buffs.append(curse)
					get_node("/root/GameState").buff_applied.emit("Angelic Curse")
			fish_slots[pending_qte_slot] = null
			fish_destroyed.emit(pending_qte_slot)
		else:
			fish_slots[pending_qte_slot] = null
			fish_fled.emit(pending_qte_slot)
	
	awaiting_qte = false
	pending_qte_slot = -1
	board_updated.emit()
	if _check_win():
		battle_active = false
		call_deferred("emit_signal", "battle_won", catch_hold)

func _trigger_catch_qte(slot: int) -> void:
	var fish = fish_slots[slot]
	if fish == null: return
	awaiting_qte = true
	pending_qte_slot = slot
	catch_qte_triggered.emit(slot, fish.data, 0)

# ============ ABILITY HANDLERS ============
func _process_card_sinker_ability(card_slot: int, card_data: CardData, target_fish_slot: int) -> void:
	var fish = fish_slots[target_fish_slot]
	match card_data.sinker:
		"Stun": fish.stunned = true
		"Trap": if fish.current_line <= card_data.sinker_power: _trigger_catch_qte(target_fish_slot)
		"Push": _push_fish(target_fish_slot, card_data.sinker_power)
		"Pull": _pull_fish(target_fish_slot, card_slot)
		"Disorient": fish.stunned = true
		"Slow": fish.slowed = !fish.get("slowed")
		"Pacify": fish.pacified = card_data.sinker_power
		"Repair": _repair_adjacent_cards(card_slot, card_data.sinker_power)

func _push_fish(fish_slot: int, power: int) -> void:
	var target = mini(fish_slot + power, NUM_SLOTS - 1)
	for i in range(fish_slot + 1, target + 1):
		if fish_slots[i] == null:
			fish_slots[i] = fish_slots[fish_slot]
			fish_slots[fish_slot] = null
			fish_swapped.emit(fish_slot, i)
			board_updated.emit()
			return

func _pull_fish(fish_slot: int, toward_slot: int) -> void:
	if fish_slot == toward_slot: return
	var dir = 1 if toward_slot > fish_slot else -1
	var target = fish_slot + dir
	if target >= 0 and target < NUM_SLOTS and fish_slots[target] == null:
		fish_slots[target] = fish_slots[fish_slot]
		fish_slots[fish_slot] = null
		fish_swapped.emit(fish_slot, target)
		board_updated.emit()

func _repair_adjacent_cards(card_slot: int, heal: int) -> void:
	var targets = []
	if card_slot > 0: targets.append(card_slot - 1)
	if card_slot < NUM_SLOTS - 1: targets.append(card_slot + 1)
	for t in targets:
		if player_cards[t] != null:
			player_cards[t].current_line = mini(player_cards[t].current_line + heal, player_cards[t].data.line)
	board_updated.emit()

func _process_non_attack_intent(slot: int) -> void:
	var fish = fish_slots[slot]
	match fish.intent:
		FishData.Intent.DIVE: _fish_dive(slot)
		FishData.Intent.FLEE: _fish_flee(slot)
		FishData.Intent.SUBMERGE: fish.submerged = true

func _process_post_attack_effects(slot: int) -> void:
	if fish_slots[slot] != null and fish_slots[slot].data.sinker == "Leap":
		for i in range(slot + 1, NUM_SLOTS):
			if fish_slots[i] != null:
				var temp = fish_slots[slot]
				fish_slots[slot] = fish_slots[i]
				fish_slots[i] = temp
				fish_swapped.emit(slot, i)
				board_updated.emit()
				return

func _fish_dive(slot: int) -> void:
	var empty = []
	for i in NUM_SLOTS:
		if i != slot and fish_slots[i] == null: empty.append(i)
	if not empty.is_empty():
		var target = empty[randi() % empty.size()]
		fish_slots[target] = fish_slots[slot]
		fish_slots[slot] = null
		fish_swapped.emit(slot, target)
		board_updated.emit()

func _fish_flee(slot: int) -> void:
	if flee_blocked: return
	if fish_slots[slot].data.sinker == "Angelic":
		if has_node("/root/GameState"):
			var bless = {"name": "Angelic Blessing", "desc": "Next fish caught +quality", "effect": "quality_bonus", "value": 25, "temporary": true}
			get_node("/root/GameState").run_buffs.append(bless)
			get_node("/root/GameState").buff_applied.emit("Angelic Blessing")
	fish_slots[slot] = null
	fish_fled.emit(slot)
	board_updated.emit()

func _process_end_of_turn_effects() -> void:
	for i in NUM_SLOTS:
		var fish = fish_slots[i]
		if fish != null and fish.data.sinker == "Regenerate" and not fish.damaged_this_turn:
			fish.current_line = mini(fish.current_line + 1, fish.max_line)
	
	var sardine_count = 0
	for f in fish_slots:
		if f != null and f.data.sinker == "School": sardine_count += 1
	for f in fish_slots:
		if f != null and f.data.sinker == "School":
			f.current_line = f.data.line + (sardine_count - 1)
			f.max_line = f.current_line
			
	for i in NUM_SLOTS:
		var fish = fish_slots[i]
		if fish != null and fish.data.sinker == "Polish" and fish.turns_alive % 2 == 0:
			var allies = []
			for j in NUM_SLOTS:
				if j != i and fish_slots[j] != null: allies.append(j)
			if not allies.is_empty():
				fish_slots[allies[randi() % allies.size()]].polished_stars += 1
	board_updated.emit()

func _update_fish_intents() -> void:
	for i in NUM_SLOTS:
		var fish = fish_slots[i]
		if fish == null: continue
		var intent = FishData.Intent.ATTACK
		if fish.data.sinker == "Skittish" and fish.turns_alive >= 1:
			var attracted = player_cards[i] != null and player_cards[i].data.sinker == "Attract"
			if not attracted or fish.turns_alive >= 2: intent = FishData.Intent.FLEE
		if fish.data.hook == 0 or fish.submerged: intent = FishData.Intent.REST
		fish.intent = intent
		fish_intent_changed.emit(i, intent)

func _update_flee_blocked() -> void:
	flee_blocked = false
	for fish in fish_slots:
		if fish != null and fish.data.sinker == "Crab_Bucket":
			flee_blocked = true
			return

# ============ GETTERS ============
func get_bait() -> int: return bait
func get_hand() -> Array: return hand
func get_deck_count() -> int: return salvage_deck.size()
func get_discard_count() -> int: return salvage_discard.size()
func can_hook() -> bool: return hook_cooldown == 0 and battle_active and not awaiting_qte
func get_hook_cooldown() -> int: return hook_cooldown
func get_rod_strength() -> int: return rod_strength
func get_catch_hold() -> Array: return catch_hold
func can_draw() -> bool: return not has_drawn_this_turn and battle_active and not awaiting_qte
func is_battle_active() -> bool: return battle_active
func _get_debug_console() -> Node: return get_node_or_null("/root/DebugConsole")
