extends Node
## Achievement Manager - Tracks and awards achievements
## Add as autoload: Project Settings > Autoload > achievement_manager.gd as "AchievementManager"

signal achievement_unlocked(achievement_id: String)

const ACHIEVEMENTS_SAVE_PATH := "user://achievements.json"

## Achievement popup scene
var achievement_popup_scene: PackedScene = preload("res://scenes/roguelike/achievement.tscn")
var current_popup: Control = null
var popup_queue: Array = []
var is_showing_popup: bool = false

## All achievements in the game
## Each achievement has: id, name, description, unlocked (runtime), hidden (optional)
var achievements: Dictionary = {
	"hard_mode": {
		"id": "hard_mode",
		"name": "HARD MODE",
		"description": "Name your Sailer 'Olamide'.\n*Not actually, btw.",
		"unlocked": false,
		"hidden": false
	},
	"first_blood": {
		"id": "first_blood",
		"name": "FIRST BLOOD",
		"description": "Secure your first catch.",
		"unlocked": false,
		"hidden": false
	},
	"sarah_lynn": {
		"id": "sarah_lynn",
		"name": "SARAH LYNN?",
		"description": "Catch 17 fish.",
		"unlocked": false,
		"hidden": false
	},
	"you_can_not_fish": {
		"id": "you_can_not_fish",
		"name": "49.0 + 1.0 YOU CAN (not) FISH",
		"description": "Catch 50 fish.",
		"unlocked": false,
		"hidden": false
	},
	"seeking_nwosu": {
		"id": "seeking_nwosu",
		"name": "SEEKING MRS. NWOSU'S FISH",
		"description": "Catch 77 fish.",
		"unlocked": false,
		"hidden": false
	},
	"some_strange_angel": {
		"id": "some_strange_angel",
		"name": "SOME STRANGE ANGEL",
		"description": "Catch an Angelfish for the first time.",
		"unlocked": false,
		"hidden": false
	},
	"dedicated_fisherman": {
		"id": "dedicated_fisherman",
		"name": "DEDICATED FISHERMAN",
		"description": "Catch every type of fish for the first time.",
		"unlocked": false,
		"hidden": false
	},
	"exceptional_fisherman": {
		"id": "exceptional_fisherman",
		"name": "EXCEPTIONAL FISHERMAN",
		"description": "Catch every type of fish in pristine condition.",
		"unlocked": false,
		"hidden": false
	},
	"beary_good_friend": {
		"id": "beary_good_friend",
		"name": "BEARY GOOD FRIEND",
		"description": "Win the friendship of the bear in the forest.",
		"unlocked": false,
		"hidden": false
	},
	"defeat_leviathan": {
		"id": "defeat_leviathan",
		"name": "DEFEAT THE LEVIATHAN",
		"description": "Defeat the monster of Bridge Tower for the first time.",
		"unlocked": false,
		"hidden": false
	},
	"modern_mansa_musa": {
		"id": "modern_mansa_musa",
		"name": "MODERN DAY MANSA MUSA",
		"description": "Buy every card available in the shop.",
		"unlocked": false,
		"hidden": false
	},
	"true_pacifist": {
		"id": "true_pacifist",
		"name": "TRUE PACIFIST",
		"description": "Complete a run without killing a single fish.",
		"unlocked": false,
		"hidden": false
	}
}

## Track certain stats for achievement checks
var stats: Dictionary = {
	"lifetime_fish_caught": 0,
	"fish_types_caught": {},      # Dictionary of fish_name -> bool
	"fish_types_pristine": {},    # Dictionary of fish_name -> bool (pristine catches)
	"shop_cards_bought": {},      # Dictionary of card_name -> bool
	"run_fish_killed": 0,         # Tracks fish killed in current run
}


func _ready() -> void:
	_load_achievements()


## Award an achievement by ID
func unlock_achievement(achievement_id: String) -> void:
	if not achievements.has(achievement_id):
		push_warning("AchievementManager: Unknown achievement ID: " + achievement_id)
		return
	
	var achievement: Dictionary = achievements[achievement_id]
	
	# Already unlocked? Skip
	if achievement.get("unlocked", false):
		return
	
	# Mark as unlocked
	achievement["unlocked"] = true
	_save_achievements()
	
	# Queue the popup
	_queue_popup(achievement)
	
	# Emit signal for any listeners
	achievement_unlocked.emit(achievement_id)
	
	print("Achievement Unlocked: ", achievement.get("name", achievement_id))


## Check if an achievement is unlocked
func is_unlocked(achievement_id: String) -> bool:
	if not achievements.has(achievement_id):
		return false
	return achievements[achievement_id].get("unlocked", false)


## Get all achievements (for display in list)
func get_all_achievements() -> Array:
	var result: Array = []
	for key in achievements.keys():
		result.append(achievements[key])
	return result


## Get only unlocked achievements
func get_unlocked_achievements() -> Array:
	var result: Array = []
	for key in achievements.keys():
		if achievements[key].get("unlocked", false):
			result.append(achievements[key])
	return result


## Get achievement count
func get_achievement_count() -> Dictionary:
	var total: int = achievements.size()
	var unlocked: int = 0
	for key in achievements.keys():
		if achievements[key].get("unlocked", false):
			unlocked += 1
	return {"unlocked": unlocked, "total": total}


## --- Popup System ---

func _queue_popup(achievement: Dictionary) -> void:
	popup_queue.append(achievement)
	if not is_showing_popup:
		_show_next_popup()


func _show_next_popup() -> void:
	if popup_queue.is_empty():
		is_showing_popup = false
		return
	
	is_showing_popup = true
	var achievement: Dictionary = popup_queue.pop_front()
	
	# Create a CanvasLayer to ensure popup is on top of everything
	var canvas_layer := CanvasLayer.new()
	canvas_layer.layer = 100  # Very high layer to be on top of everything
	get_tree().root.add_child(canvas_layer)
	
	# Instance the popup
	current_popup = achievement_popup_scene.instantiate()
	canvas_layer.add_child(current_popup)
	
	# Set the achievement data
	_setup_popup(current_popup, achievement)
	
	# Animate it
	await _animate_popup(current_popup)
	
	# Clean up
	if is_instance_valid(canvas_layer):
		canvas_layer.queue_free()
	current_popup = null
	
	# Show next if queued
	_show_next_popup()


func _setup_popup(popup: Control, achievement: Dictionary) -> void:
	# Find the label nodes
	var name_label: Label = popup.get_node_or_null("AchievementName")
	var desc_label: Label = popup.get_node_or_null("AchievementDesc")
	var background: TextureRect = popup.get_node_or_null("AchievementBackground")
	
	if name_label:
		name_label.text = achievement.get("name", "ACHIEVEMENT")
	if desc_label:
		desc_label.text = achievement.get("description", "")
	
	# Position everything off-screen (bottom right)
	# The achievement.tscn has elements positioned around x=1468-1869, y=803-1034
	# We need to move them down first, then animate up
	var screen_size := popup.get_viewport_rect().size
	var offset_y := 300.0  # How far below to start
	
	if background:
		background.position.y += offset_y
	if name_label:
		name_label.position.y += offset_y
	if desc_label:
		desc_label.position.y += offset_y


func _animate_popup(popup: Control) -> void:
	var name_label: Label = popup.get_node_or_null("AchievementName")
	var desc_label: Label = popup.get_node_or_null("AchievementDesc")
	var background: TextureRect = popup.get_node_or_null("AchievementBackground")
	
	var nodes: Array = []
	if background:
		nodes.append(background)
	if name_label:
		nodes.append(name_label)
	if desc_label:
		nodes.append(desc_label)
	
	if nodes.is_empty():
		return
	
	# Store original positions (after offset applied in _setup_popup)
	var original_positions: Array = []
	for node in nodes:
		original_positions.append(node.position.y)
	
	# Target positions (300 pixels up from current)
	var target_offset := -300.0
	
	# Play sound if available
	if has_node("/root/AudioManager"):
		var audio = get_node("/root/AudioManager")
		if audio.has_method("play_ui_confirm"):
			audio.play_ui_confirm()
	
	# Animate UP (slide in)
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	
	for i in nodes.size():
		var node: Control = nodes[i] as Control
		tween.parallel().tween_property(node, "position:y", original_positions[i] + target_offset, 0.5)
	
	await tween.finished
	
	# Hold for 2 seconds
	await get_tree().create_timer(2.0).timeout
	
	# Animate DOWN (slide out)
	var tween_out := create_tween()
	tween_out.set_ease(Tween.EASE_IN)
	tween_out.set_trans(Tween.TRANS_BACK)
	
	for i in nodes.size():
		var node: Control = nodes[i] as Control
		tween_out.parallel().tween_property(node, "position:y", original_positions[i], 0.4)
	
	await tween_out.finished


## --- Achievement Triggers ---
## Call these from gameplay code to check/award achievements

## Call when player sets their name
func check_name_achievement(player_name: String) -> void:
	if player_name.strip_edges().to_lower() == "olamide":
		unlock_achievement("hard_mode")


## Call when player catches a fish (lifetime tracking)
func on_fish_caught(fish_name: String = "", is_pristine: bool = false) -> void:
	stats["lifetime_fish_caught"] += 1
	
	# Track fish type caught
	if fish_name != "":
		stats["fish_types_caught"][fish_name] = true
		if is_pristine:
			stats["fish_types_pristine"][fish_name] = true
	
	# First Blood - first catch ever
	if stats["lifetime_fish_caught"] >= 1:
		unlock_achievement("first_blood")
	
	# SARAH LYNN? - 17 fish
	if stats["lifetime_fish_caught"] >= 17:
		unlock_achievement("sarah_lynn")
	
	# YOU CAN (not) FISH - 50 fish
	if stats["lifetime_fish_caught"] >= 50:
		unlock_achievement("you_can_not_fish")
	
	# SEEKING MRS. NWOSU'S FISH - 77 fish
	if stats["lifetime_fish_caught"] >= 77:
		unlock_achievement("seeking_nwosu")
	
	# SOME STRANGE ANGEL - catch Angelfish
	if fish_name == "Angelfish":
		unlock_achievement("some_strange_angel")
	
	# Check if all fish types caught
	_check_all_fish_achievements()
	
	_save_achievements()


## Check if player has caught all fish types
func _check_all_fish_achievements() -> void:
	var all_fish_names: Array = FishDatabase.get_all_fish_names()
	
	# Check DEDICATED FISHERMAN - all types caught
	var all_caught := true
	for fish_name in all_fish_names:
		if not stats["fish_types_caught"].has(fish_name):
			all_caught = false
			break
	
	if all_caught:
		unlock_achievement("dedicated_fisherman")
	
	# Check EXCEPTIONAL FISHERMAN - all types pristine
	var all_pristine := true
	for fish_name in all_fish_names:
		if not stats["fish_types_pristine"].has(fish_name):
			all_pristine = false
			break
	
	if all_pristine:
		unlock_achievement("exceptional_fisherman")


## Call when bear buff is unlocked
func on_bear_friendship() -> void:
	unlock_achievement("beary_good_friend")


## Call when leviathan is defeated
func on_leviathan_defeated() -> void:
	unlock_achievement("defeat_leviathan")


## Call when a shop card is bought (track for Mansa Musa)
func on_shop_card_bought(card_name: String) -> void:
	stats["shop_cards_bought"][card_name] = true
	_check_mansa_musa()
	_save_achievements()


## Check if all shop cards bought
func _check_mansa_musa() -> void:
	var shop_pool: Array = CardDatabase.get_shop_pool()
	var all_bought := true
	
	for card_data in shop_pool:
		var name: String = card_data.get("name", "")
		if name != "" and not stats["shop_cards_bought"].has(name):
			all_bought = false
			break
	
	if all_bought:
		unlock_achievement("modern_mansa_musa")


## Call at start of run to reset fish killed counter
func on_run_start() -> void:
	stats["run_fish_killed"] = 0


## Call when fish is killed/destroyed (not caught)
func on_fish_killed() -> void:
	stats["run_fish_killed"] += 1


## Call at end of successful run
func on_run_complete() -> void:
	if stats["run_fish_killed"] == 0:
		unlock_achievement("true_pacifist")


## --- Save / Load ---

func _save_achievements() -> void:
	var save_data: Dictionary = {}
	for key in achievements.keys():
		save_data[key] = achievements[key].get("unlocked", false)
	
	# Also save stats
	save_data["_stats"] = stats
	
	var json := JSON.stringify(save_data, "\t")
	var file := FileAccess.open(ACHIEVEMENTS_SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(json)
		file.close()


func _load_achievements() -> void:
	if not FileAccess.file_exists(ACHIEVEMENTS_SAVE_PATH):
		return
	
	var file := FileAccess.open(ACHIEVEMENTS_SAVE_PATH, FileAccess.READ)
	if not file:
		return
	
	var json := file.get_as_text()
	file.close()
	
	var parsed = JSON.parse_string(json)
	if not parsed is Dictionary:
		return
	
	# Restore unlocked status
	for key in achievements.keys():
		if parsed.has(key):
			achievements[key]["unlocked"] = parsed[key]
	
	# Restore stats with proper defaults for new fields
	if parsed.has("_stats") and parsed["_stats"] is Dictionary:
		var loaded_stats: Dictionary = parsed["_stats"]
		stats["lifetime_fish_caught"] = loaded_stats.get("lifetime_fish_caught", loaded_stats.get("total_fish_caught", 0))
		stats["fish_types_caught"] = loaded_stats.get("fish_types_caught", {})
		stats["fish_types_pristine"] = loaded_stats.get("fish_types_pristine", {})
		stats["shop_cards_bought"] = loaded_stats.get("shop_cards_bought", {})
		stats["run_fish_killed"] = loaded_stats.get("run_fish_killed", 0)


## Reset all achievements (for testing)
func reset_all_achievements() -> void:
	for key in achievements.keys():
		achievements[key]["unlocked"] = false
	stats = {
		"lifetime_fish_caught": 0,
		"fish_types_caught": {},
		"fish_types_pristine": {},
		"shop_cards_bought": {},
		"run_fish_killed": 0,
	}
	_save_achievements()
	print("All achievements reset!")
