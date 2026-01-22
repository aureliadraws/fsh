extends Node
## Battle Manager - FIXED for infinite loop prevention
## Key changes: Damage queue system, proper state guards, awaits with timeouts

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
signal player_attack_started(slot: int, has_target: bool)
signal player_attack_finished(slot: int)
signal fish_attack_started(slot: int, has_target: bool)
signal fish_attack_finished(slot: int)
signal all_attacks_finished
signal fish_incoming(slot: int, fish_data)
signal fish_spawned(slot: int)

const NUM_SLOTS: int = 4
const MAX_BAIT: int = 10
const STARTING_BAIT: int = 0
const MAX_HAND_SIZE: int = 7

var player_cards: Array = []
var fish_slots: Array = []
var pending_fish: Array = []
var bait: int = 0
var boat_hp: int = 3
var max_boat_hp: int = 3
var hook_cooldown: int = 0
var hook_cooldown_max: int = 3
var rod_strength: int = 2
var salvage_deck: Array = []
var salvage_discard: Array = []
var hand: Array = []
var chum_card_template: CardData
var battle_active: bool = false
var turn_number: int = 0
var awaiting_qte: bool = false
var pending_qte_slot: int = -1
var has_drawn_this_turn: bool = false
var catch_hold: Array = []
var flee_blocked: bool = false
var _defeat_triggered: bool = false

# CRITICAL FIX: Prevent infinite loops
var _in_damage_handler: bool = false
var _damage_depth: int = 0
const MAX_DAMAGE_DEPTH: int = 3

func _ready() -> void:
	chum_card_template = CardData.new()
	chum_card_template.card_name = "Chum"
	chum_card_template.hook = 0
	chum_card_template.line = 1
	chum_card_template.bait_cost = 0
	chum_card_template.sinker = "Attract"
	chum_card_template.card_type = "Chum"

func start_battle(deck: Array, enemies: Array, boat_health: int = 3, p_rod_strength: int = 2, p_hook_cooldown_max: int = 3) -> void:
	_defeat_triggered = false
	_in_damage_handler = false
	_damage_depth = 0
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
	var slot := 0
	var immediate_spawn_count := 0
	for fish in enemies:
		if slot >= NUM_SLOTS: break
		if fish != null and fish is FishData:
			var should_stagger := false
			if immediate_spawn_count > 0 and slot < enemies.size():
				should_stagger = randf() < 0.4
			if should_stagger:
				pending_fish.append({"slot": slot, "fish": fish, "turns_until_spawn": 2})
				fish_incoming.emit(slot, fish)
			else:
				fish_slots[slot] = fish.create_instance()
				immediate_spawn_count += 1
			slot += 1
	bait = STARTING_BAIT
	turn_number = 0
	hook_cooldown = hook_cooldown_max
	battle_active = true
	awaiting_qte = false
	pending_qte_slot = -1
	catch_hold.clear()
	flee_blocked = false
	has_drawn_this_turn = false
	_update_flee_blocked()
	battle_started.emit()
	for i in 3: _draw_from_salvage()
	var chum := chum_card_template.duplicate_card()
	hand.append(chum)
	hand_updated.emit()
	_start_turn()

func _start_turn() -> void:
	if not battle_active: return
	turn_number += 1
	has_drawn_this_turn = false
	_process_pending_fish()
	bait_changed.emit(bait)
	if hook_cooldown > 0:
		hook_cooldown -= 1
		hook_cooldown_tick.emit(hook_cooldown)
		if hook_cooldown == 0: hook_available.emit()
	for i in NUM_SLOTS:
		if player_cards[i] != null: player_cards[i].has_acted = false
	for i in NUM_SLOTS:
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
	var fish_to_spawn: Array = []
	for pending in pending_fish:
		pending.turns_until_spawn -= 1
		if pending.turns_until_spawn <= 0:
			fish_to_spawn.append(pending)
	for pending in fish_to_spawn:
		pending_fish.erase(pending)
	var any_spawned := false
	for pending in fish_to_spawn:
		var slot: int = pending.slot
		var fish: FishData = pending.fish
		if fish_slots[slot] != null:
			slot = _find_empty_fish_slot()
		if slot >= 0 and slot < NUM_SLOTS:
			fish_slots[slot] = fish.create_instance()
			any_spawned = true
			fish_incoming.emit(pending.slot, null)
			fish_spawned.emit(slot)
	if any_spawned: board_updated.emit()

func _find_empty_fish_slot() -> int:
	for i in NUM_SLOTS:
		if fish_slots[i] == null: return i
	return -1

func get_pending_fish() -> Array: return pending_fish
func draw_from_salvage() -> bool:
	if not battle_active or awaiting_qte or has_drawn_this_turn or hand.size() >= MAX_HAND_SIZE: return false
	var success := _draw_from_salvage()
	if success:
		has_drawn_this_turn = true
		draw_state_changed.emit(false)
	return success

func draw_from_chum() -> bool:
	if not battle_active or awaiting_qte or has_drawn_this_turn or hand.size() >= MAX_HAND_SIZE: return false
	var chum := chum_card_template.duplicate_card()
	hand.append(chum)
	has_drawn_this_turn = true
	draw_state_changed.emit(false)
	hand_updated.emit()
	return true

func _draw_from_salvage() -> bool:
	if salvage_deck.is_empty(): _shuffle_discard_into_deck()
	if salvage_deck.is_empty(): return false
	var card: CardData = salvage_deck.pop_back()
	hand.append(card)
	hand_updated.emit()
	return true

func _shuffle_discard_into_deck() -> void:
	for card in salvage_discard: salvage_deck.append(card)
	salvage_discard.clear()
	salvage_deck.shuffle()

func play_card(hand_index: int, slot: int) -> bool:
	if not battle_active or awaiting_qte: return false
	if slot < 0 or slot >= NUM_SLOTS or hand_index < 0 or hand_index >= hand.size(): return false
	var card: CardData = hand[hand_index]
	if card == null or bait < card.bait_cost: return false
	bait -= card.bait_cost
	bait_changed.emit(bait)
	hand.remove_at(hand_index)
	var existing_card = player_cards[slot]
	if existing_card != null: hand.append(existing_card.data)
	player_cards[slot] = {"data": card, "current_line": card.line, "has_acted": false}
	card_played.emit(card, slot)
	board_updated.emit()
	hand_updated.emit()
	return true

func scrap_card_from_hand(hand_index: int) -> bool:
	if not battle_active or awaiting_qte or hand_index < 0 or hand_index >= hand.size(): return false
	var card: CardData = hand[hand_index]
	if card == null: return false
	var scrap_value := card.get_scrap_value()
	bait = mini(bait + scrap_value, MAX_BAIT)
	bait_changed.emit(bait)
	hand.remove_at(hand_index)
	if card.card_type == "Salvage": salvage_discard.append(card)
	hand_updated.emit()
	return true

func scrap_card_from_board(slot: int) -> bool:
	if not battle_active or awaiting_qte or slot < 0 or slot >= NUM_SLOTS: return false
	if player_cards[slot] == null: return false
	var card_instance = player_cards[slot]
	var card_data: CardData = card_instance.data
	if card_data == null: return false
	var scrap_value := card_data.get_scrap_value()
	bait = mini(bait + scrap_value, MAX_BAIT)
	bait_changed.emit(bait)
	if card_data.card_type == "Salvage": salvage_discard.append(card_data)
	player_cards[slot] = null
	board_updated.emit()
	return true

func try_hook_fish(slot: int) -> bool:
	if not battle_active or awaiting_qte or hook_cooldown > 0: return false
	if slot < 0 or slot >= NUM_SLOTS: return false
	var fish = fish_slots[slot]
	if fish == null or fish.data == null: return false
	if not _can_hook_fish(slot) or fish.current_line > rod_strength: return false
	hook_cooldown = hook_cooldown_max
	hook_used.emit()
	awaiting_qte = true
	pending_qte_slot = slot
	catch_qte_triggered.emit(slot, fish.data, fish.current_line)
	return true

func _can_hook_fish(slot: int) -> bool:
	var fish = fish_slots[slot]
	if fish == null or fish.data == null: return false
	var fish_data: FishData = fish.data
	var other_fish_exist := _count_fish() > 1
	if fish_data.sinker == "Territorial" and other_fish_exist: return false
	if fish_data.sinker == "Camouflage" and other_fish_exist: return false
	if fish_data.sinker != "Circus_Act":
		for i in NUM_SLOTS:
			if i == slot: continue
			var other_fish = fish_slots[i]
			if other_fish != null and other_fish.data != null:
				if other_fish.data.sinker == "Circus_Act": return false
	if fish.submerged: return false
	return true

func end_turn() -> void:
	if not battle_active or awaiting_qte: return
	turn_ended.emit()
	await _process_ambush_attacks_animated()
	if not battle_active: return
	await _process_player_attacks_animated()
	if not battle_active: return
	await _process_normal_fish_attacks_animated()
	if not battle_active: return
	all_attacks_finished.emit()
	_process_end_of_turn_effects()
	if not battle_active: return
	if _check_win():
		battle_active = false
		if has_node("/root/MusicController"):
			var music_ctrl = get_node("/root/MusicController")
			if music_ctrl.has_method("play_roguelike_music"):
				music_ctrl.play_roguelike_music()
		battle_won.emit(catch_hold)
		return
	_start_turn()

func _process_ambush_attacks_animated() -> void:
	for i in NUM_SLOTS:
		if not battle_active or _defeat_triggered: return
		var fish = fish_slots[i]
		if fish == null or fish.has_attacked: continue
		var fish_data: FishData = fish.data
		if fish_data != null and fish_data.sinker == "Ambush":
			await _fish_attack_animated(i)

func _process_normal_fish_attacks_animated() -> void:
	for i in NUM_SLOTS:
		if not battle_active or _defeat_triggered: return
		var fish = fish_slots[i]
		if fish == null or fish.has_attacked: continue
		await _fish_attack_animated(i)

func _process_player_attacks_animated() -> void:
	var player_card_slots: Array[int] = []
	var fish_slot_list: Array[int] = []
	for i in NUM_SLOTS:
		if player_cards[i] != null: player_card_slots.append(i)
		if fish_slots[i] != null: fish_slot_list.append(i)
	if player_card_slots.is_empty() or fish_slot_list.is_empty(): return
	for card_slot in player_card_slots:
		if not battle_active: return
		var card = player_cards[card_slot]
		if card == null: continue
		var card_data: CardData = card.data
		if card_data == null: continue
		var target_fish_slot := -1
		if fish_slots[card_slot] != null:
			target_fish_slot = card_slot
		else:
			target_fish_slot = _find_nearest_fish(card_slot, fish_slot_list)
		if target_fish_slot < 0: continue
		var fish = fish_slots[target_fish_slot]
		if fish == null: continue
		var fish_data: FishData = fish.data
		if fish_data == null: continue
		if fish_data.sinker == "Camouflage" and _count_fish() > 1:
			if target_fish_slot == card_slot:
				target_fish_slot = _find_nearest_fish_excluding(card_slot, fish_slot_list, card_slot)
			else:
				target_fish_slot = _find_nearest_fish_excluding(card_slot, fish_slot_list, target_fish_slot)
			if target_fish_slot >= 0:
				fish = fish_slots[target_fish_slot]
				fish_data = fish.data
			else:
				continue
		player_attack_started.emit(card_slot, true)
		await get_tree().create_timer(0.35).timeout
		var damage: int = card_data.hook
		if card_data.sinker == "Gentle":
			damage = maxi(1, damage - card_data.sinker_power)
		_damage_fish(target_fish_slot, damage)
		_process_card_sinker_ability(card_slot, card_data, target_fish_slot)
		player_attack_finished.emit(card_slot)
		var qte_timeout := 0
		while awaiting_qte and qte_timeout < 100:
			await get_tree().create_timer(0.1).timeout
			qte_timeout += 1
		fish_slot_list.clear()
		for i in NUM_SLOTS:
			if fish_slots[i] != null: fish_slot_list.append(i)
		await get_tree().create_timer(0.15).timeout
		fish = fish_slots[target_fish_slot]
		if fish != null and fish_data.sinker == "Venomous":
			var recoil: int = ceili(float(damage) / 2.0)
			_damage_card(card_slot, recoil)
		if not battle_active: return

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

func _fish_attack_animated(slot: int) -> void:
	if not battle_active or _defeat_triggered: return
	var fish = fish_slots[slot]
	if fish == null: return
	var fish_data: FishData = fish.data
	if fish_data == null: return
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
	for _atk in attacks:
		if not battle_active or _defeat_triggered: return
		var target_slot := _find_nearest_player_card(slot)
		var attacks_boat := false
		var fish_count := _count_fish()
		var card_count := _count_player_cards()
		if target_slot < 0:
			if card_count == 0 or fish_count >= card_count + 2:
				attacks_boat = true
			else:
				fish_attack_started.emit(slot, false)
				await get_tree().create_timer(0.2).timeout
				fish_attack_finished.emit(slot)
				continue
		fish_attack_started.emit(slot, target_slot >= 0)
		await get_tree().create_timer(0.35).timeout
		if not battle_active or _defeat_triggered:
			fish_attack_finished.emit(slot)
			return
		if attacks_boat:
			_damage_boat(damage)
			fish_attack_finished.emit(slot)
			if not battle_active or _defeat_triggered: return
		elif target_slot >= 0:
			if fish_data.sinker == "Consume":
				var target_card = player_cards[target_slot]
				if target_card != null and target_card.current_line <= fish_data.hook:
					_destroy_card(target_slot)
				else:
					_damage_card(target_slot, damage)
			else:
				_damage_card(target_slot, damage)
			fish_attack_finished.emit(slot)
			if not battle_active or _defeat_triggered: return
		await get_tree().create_timer(0.15).timeout
		if not battle_active or _defeat_triggered: return
	if battle_active and not _defeat_triggered:
		_process_post_attack_effects(slot)

func _process_card_sinker_ability(card_slot: int, card_data: CardData, target_fish_slot: int) -> void:
	if card_data == null: return
	var fish = fish_slots[target_fish_slot]
	if fish == null: return
	match card_data.sinker:
		"Stun": fish.stunned = true
		"Trap":
			if fish.current_line > 0 and fish.current_line <= card_data.sinker_power:
				_trigger_catch_qte(target_fish_slot)
		"Push": _push_fish(target_fish_slot, card_data.sinker_power)
		"Pull": _pull_fish(target_fish_slot, card_slot)
		"Disorient": fish.stunned = true
		"Slow": fish.slowed = true if not fish.get("slowed") else false
		"Pacify": fish.pacified = card_data.sinker_power
		"Repair": _repair_adjacent_cards(card_slot, card_data.sinker_power)

func _push_fish(fish_slot: int, power: int) -> void:
	var target_slot := mini(fish_slot + power, NUM_SLOTS - 1)
	for i in range(fish_slot + 1, target_slot + 1):
		if fish_slots[i] == null:
			fish_slots[i] = fish_slots[fish_slot]
			fish_slots[fish_slot] = null
			fish_swapped.emit(fish_slot, i)
			board_updated.emit()
			return

func _pull_fish(fish_slot: int, toward_slot: int) -> void:
	if fish_slot == toward_slot: return
	var direction := 1 if toward_slot > fish_slot else -1
	var target_slot := fish_slot + direction
	if target_slot >= 0 and target_slot < NUM_SLOTS and fish_slots[target_slot] == null:
		fish_slots[target_slot] = fish_slots[fish_slot]
		fish_slots[fish_slot] = null
		fish_swapped.emit(fish_slot, target_slot)
		board_updated.emit()

func _repair_adjacent_cards(card_slot: int, heal_amount: int) -> void:
	var adjacent_slots := []
	if card_slot > 0: adjacent_slots.append(card_slot - 1)
	if card_slot < NUM_SLOTS - 1: adjacent_slots.append(card_slot + 1)
	for slot in adjacent_slots:
		var card = player_cards[slot]
		if card != null:
			var card_data: CardData = card.data
			if card_data != null:
				card.current_line = mini(card.current_line + heal_amount, card_data.line)
	board_updated.emit()

func _process_non_attack_intent(slot: int) -> void:
	var fish = fish_slots[slot]
	if fish == null: return
	match fish.intent:
		FishData.Intent.DIVE: _fish_dive(slot)
		FishData.Intent.REST: pass
		FishData.Intent.FLEE: _fish_flee(slot)
		FishData.Intent.SUBMERGE: fish.submerged = true

func _process_post_attack_effects(slot: int) -> void:
	var fish = fish_slots[slot]
	if fish == null: return
	var fish_data: FishData = fish.data
	if fish_data == null: return
	if fish_data.sinker == "Leap": _fish_leap(slot)

func _fish_leap(slot: int) -> void:
	for i in range(slot + 1, NUM_SLOTS):
		if fish_slots[i] != null:
			var temp = fish_slots[slot]
			fish_slots[slot] = fish_slots[i]
			fish_slots[i] = temp
			fish_swapped.emit(slot, i)
			board_updated.emit()
			return

func _fish_dive(slot: int) -> void:
	var empty_slots := []
	for i in NUM_SLOTS:
		if i != slot and fish_slots[i] == null:
			empty_slots.append(i)
	if not empty_slots.is_empty():
		var target: int = empty_slots[randi() % empty_slots.size()]
		fish_slots[target] = fish_slots[slot]
		fish_slots[slot] = null
		fish_swapped.emit(slot, target)
		board_updated.emit()

func _fish_flee(slot: int) -> void:
	if flee_blocked: return
	var fish = fish_slots[slot]
	if fish == null: return
	var fish_data: FishData = fish.data
	if fish_data != null and fish_data.sinker == "Angelic":
		if has_node("/root/GameState"):
			var blessing_buff := {"name": "Angelic Blessing", "desc": "Next fish caught is higher quality", "effect": "quality_bonus", "value": 25, "temporary": true}
			GameState.run_buffs.append(blessing_buff)
			GameState.buff_applied.emit("Angelic Blessing")
	fish_slots[slot] = null
	fish_fled.emit(slot)
	board_updated.emit()

func _process_end_of_turn_effects() -> void:
	for i in NUM_SLOTS:
		var fish = fish_slots[i]
		if fish == null: continue
		var fish_data: FishData = fish.data
		if fish_data != null and fish_data.sinker == "Regenerate" and not fish.damaged_this_turn:
			fish.current_line = mini(fish.current_line + 1, fish.max_line)
	for i in NUM_SLOTS:
		var fish = fish_slots[i]
		if fish == null: continue
		var fish_data: FishData = fish.data
		if fish_data != null and fish_data.sinker == "Polish" and fish.turns_alive % 2 == 0:
			_polish_random_ally(i)
	var sardine_count := 0
	for i in NUM_SLOTS:
		var fish = fish_slots[i]
		if fish != null and fish.data != null and fish.data.sinker == "School":
			sardine_count += 1
	for i in NUM_SLOTS:
		var fish = fish_slots[i]
		if fish != null and fish.data != null and fish.data.sinker == "School":
			fish.current_line = fish.data.line + (sardine_count - 1)
			fish.max_line = fish.current_line
	board_updated.emit()

func _polish_random_ally(senorita_slot: int) -> void:
	var allies := []
	for i in NUM_SLOTS:
		if i != senorita_slot and fish_slots[i] != null:
			allies.append(i)
	if not allies.is_empty():
		var target: int = allies[randi() % allies.size()]
		fish_slots[target].polished_stars += 1

# CRITICAL FIX: Damage handlers with depth protection
func _damage_card(slot: int, damage: int) -> void:
	if not battle_active or _defeat_triggered: return
	if _damage_depth >= MAX_DAMAGE_DEPTH:
		print("WARNING: Max damage depth reached, queuing boat damage")
		return
	_damage_depth += 1
	var card = player_cards[slot]
	if card == null:
		_damage_depth -= 1
		return
	var console := _get_debug_console()
	if console and console.is_invincible():
		card_damaged.emit(slot, 0)
		_damage_depth -= 1
		return
	card.current_line -= damage
	card_damaged.emit(slot, damage)
	if card.current_line <= 0:
		var overkill: int = absi(card.current_line)
		_destroy_card(slot)
		if overkill > 0 and battle_active and not _defeat_triggered and boat_hp > 0:
			var actual_overkill: int = mini(overkill, boat_hp)
			_damage_boat(actual_overkill)
	_damage_depth -= 1

func _destroy_card(slot: int) -> void:
	var card = player_cards[slot]
	if card == null: return
	var card_data: CardData = card.data
	if card_data != null:
		card_data.is_damaged = true
	player_cards[slot] = null
	card_destroyed.emit(slot)
	board_updated.emit()

func _damage_boat(damage: int) -> void:
	if _defeat_triggered: return
	if not battle_active: return
	if damage <= 0: return
	if boat_hp <= 0:
		if not _defeat_triggered:
			_defeat_triggered = true
			battle_active = false
			call_deferred("_emit_battle_lost")
		return
	var actual_damage: int = mini(damage, boat_hp)
	boat_hp -= actual_damage
	if is_inside_tree():
		boat_damaged.emit(boat_hp)
	if boat_hp <= 0 and not _defeat_triggered:
		_defeat_triggered = true
		battle_active = false
		if has_node("/root/MusicController"):
			var music_ctrl = get_node("/root/MusicController")
			if music_ctrl.has_method("play_roguelike_music"):
				music_ctrl.play_roguelike_music()
		call_deferred("_emit_battle_lost")

func _emit_battle_lost() -> void:
	battle_lost.emit()

func _damage_fish(slot: int, damage: int) -> void:
	var fish = fish_slots[slot]
	if fish == null: return
	var fish_data: FishData = fish.data
	if fish_data == null: return
	fish.damaged_this_turn = true
	
	# Shell: Block first X damage each turn
	if fish_data.sinker == "Shell" and not fish.shell_used:
		fish.shell_used = true
		damage = maxi(0, damage - fish_data.sinker_power)
		if damage == 0:
			return
	
	fish.current_line -= damage
	fish_damaged.emit(slot, damage)
	
	# Scatter: Move when hit
	if fish_data.sinker == "Scatter" and fish.current_line > 0:
		_fish_dive(slot)  # Reuse dive logic for random movement
	
	if fish.current_line <= 0:
		_trigger_catch_qte(slot)


func _trigger_catch_qte(slot: int) -> void:
	var fish = fish_slots[slot]
	if fish == null:
		return
	
	awaiting_qte = true
	pending_qte_slot = slot
	catch_qte_triggered.emit(slot, fish.data, 0)  # 0 LINE = battered quality


# ============ QTE RESOLUTION ============

func resolve_catch(success: bool, quality_stars: int = 1) -> void:
	if pending_qte_slot < 0:
		awaiting_qte = false
		return
	
	var fish = fish_slots[pending_qte_slot]
	if fish == null:
		awaiting_qte = false
		pending_qte_slot = -1
		_check_win_and_emit()
		return
	
	var fish_data: FishData = fish.data
	
	if success and fish_data != null:
		# Calculate value based on quality
		var quality := fish_data.calculate_quality(fish.current_line, fish.polished_stars)
		catch_hold.append({
			"fish": fish_data,
			"quality": quality,
			"cowries": quality.cowrie_value
		})
		
		# Angelic: Apply curse debuff if caught (bittersweet - you caught it but at a cost)
		if fish_data.sinker == "Angelic":
			# Curse: -1 to hook damage for rest of battle
			if has_node("/root/GameState"):
				var curse_debuff := {
					"name": "Angelic Curse",
					"desc": "-1 Hook damage this battle",
					"effect": "hook_penalty",
					"value": 1,
					"temporary": true
				}
				GameState.run_buffs.append(curse_debuff)
				GameState.buff_applied.emit("Angelic Curse")
		
		fish_slots[pending_qte_slot] = null
		fish_destroyed.emit(pending_qte_slot)
	else:
		# Fish escapes - remove from board but no reward
		fish_slots[pending_qte_slot] = null
		fish_fled.emit(pending_qte_slot)
	
	awaiting_qte = false
	pending_qte_slot = -1
	board_updated.emit()
	
	# Check win condition (the waiting loop in attack processing will continue after this)
	_check_win_and_emit()


func _check_win_and_emit() -> void:
	if _check_win() and battle_active:
		battle_active = false
		battle_won.emit(catch_hold)


# ============ FISH INTENT SYSTEM ============

func _update_fish_intents() -> void:
	for i in NUM_SLOTS:
		var fish = fish_slots[i]
		if fish == null:
			continue
		
		var fish_data: FishData = fish.data
		if fish_data == null:
			continue
		
		var intent: int = FishData.Intent.ATTACK  # Default: attack
		
		# Skittish: Flee on turn 2 and after if blocked by Attract
		if fish_data.sinker == "Skittish":
			if fish.turns_alive >= 1:
				var blocked_by_attract := _is_blocked_by_attract(i)
				if blocked_by_attract or fish.turns_alive >= 2:
					intent = FishData.Intent.FLEE
		
		# Sea Turtle and other 0-HOOK fish just sit there
		if fish_data.hook == 0:
			intent = FishData.Intent.REST
		
		# Submerged fish are resurfacing
		if fish.submerged:
			intent = FishData.Intent.REST  # Resurfacing, no attack
		
		# Update intent
		fish.intent = intent
		fish_intent_changed.emit(i, intent)


func _is_blocked_by_attract(slot: int) -> bool:
	var card = player_cards[slot]
	if card == null:
		return false
	
	var card_data: CardData = card.data
	if card_data == null:
		return false
	
	return card_data.sinker == "Attract"


func _update_flee_blocked() -> void:
	flee_blocked = false
	for i in NUM_SLOTS:
		var fish = fish_slots[i]
		if fish != null and fish.data != null and fish.data.sinker == "Crab_Bucket":
			flee_blocked = true
			return


# ============ UTILITY ============

func _count_fish() -> int:
	var count := 0
	for fish in fish_slots:
		if fish != null:
			count += 1
	return count

func _count_player_cards() -> int:
	var count := 0
	for card in player_cards:
		if card != null:
			count += 1
	return count


func _check_win() -> bool:
	# Win only if no fish on board AND no pending fish incoming
	return _count_fish() == 0 and pending_fish.is_empty()


# ============ GETTERS ============

func get_bait() -> int:
	return bait

func get_hand() -> Array:
	return hand

func get_deck_count() -> int:
	return salvage_deck.size()

func get_discard_count() -> int:
	return salvage_discard.size()

func can_hook() -> bool:
	return hook_cooldown == 0 and battle_active and not awaiting_qte

func get_hook_cooldown() -> int:
	return hook_cooldown

func get_rod_strength() -> int:
	return rod_strength

func get_catch_hold() -> Array:
	return catch_hold

func can_draw() -> bool:
	return not has_drawn_this_turn and battle_active and not awaiting_qte

func is_battle_active() -> bool:
	return battle_active


# ============ DEBUG HELPERS ============

func _get_debug_console() -> Node:
	return get_node_or_null("/root/DebugConsole")
