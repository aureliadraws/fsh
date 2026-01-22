extends Control
## Cooking Screen - Notebook-style UI for eating/selling fish
## Shows fish in a grid layout with actual fish images from FishDatabase

signal cooking_completed(result: Dictionary)

# Node references
@onready var effect_banner: TextureRect = $EffectBanner
@onready var effect_text: Label = $EffectText
@onready var left_page: TextureRect = $LeftPage
@onready var right_page: TextureRect = $RightPage
@onready var left_container: VBoxContainer = $LeftPageContainer
@onready var right_container: VBoxContainer = $RightPageContainer
@onready var cooking_title: Label = $"Cooking Title"
@onready var cowries_label: Label = $CowriesLabel
@onready var prev_page_btn: TextureButton = $LeftPage/PrevPage
@onready var next_page_btn: TextureButton = $RightPage/NextPage
@onready var close_btn: Button = $CloseButton

# Button texture for fish entries
var button_texture: Texture2D = null

# Quality colors
const QUALITY_COLORS := {
	"Pristine": Color(1.0, 0.84, 0.0),
	"Fresh": Color(0.2, 0.8, 0.2),
	"Mediocre": Color(0.7, 0.7, 0.3),
	"Poor": Color(0.6, 0.4, 0.2),
	"Ruined": Color(0.4, 0.2, 0.2),
	"Bad": Color(0.6, 0.4, 0.2),
	"Damaged": Color(0.4, 0.2, 0.2),
}

# Random effects for eating
const POSITIVE_EFFECTS := [
	{"name": "Feast", "effect": "hook_bonus", "value": 2, "desc": "+2 HOOK"},
	{"name": "Blessing", "effect": "line_bonus", "value": 2, "desc": "+2 LINE"},
	{"name": "Bounty", "effect": "bait_bonus", "value": 3, "desc": "+3 bait"},
	{"name": "Luck", "effect": "cowrie_bonus", "value": 20, "desc": "+20% cowries"},
	{"name": "Hull", "effect": "hp_bonus", "value": 1, "desc": "+1 max HP"},
	{"name": "Heal", "effect": "heal", "value": 1, "desc": "Heal 1 HP"},
]

const NEUTRAL_EFFECTS := [
	{"name": "Filling", "effect": "none", "value": 0, "desc": "Nothing special"},
]

const NEGATIVE_EFFECTS := [
	{"name": "Poison", "effect": "damage", "value": 1, "desc": "-1 HP!"},
	{"name": "Queasy", "effect": "hook_penalty", "value": 1, "desc": "-1 HOOK"},
]

const SELL_MULTIPLIERS := {
	"Pristine": 1.5, "Fresh": 1.0, "Mediocre": 0.6, 
	"Poor": 0.3, "Ruined": 0.15, "Bad": 0.3, "Damaged": 0.15,
}

const QUALITY_ORDER := ["Pristine", "Fresh", "Mediocre", "Poor", "Bad", "Ruined", "Damaged"]

var catch_hold: Array = []
var current_cowries: int = 0
var effects_gained: Array = []
var cowries_earned: int = 0
var fish_eaten: Array = []
var fish_sold: Array = []
var current_page: int = 0
var fish_per_page: int = 18  # 9 per side (3x3 grid)

# Effect banner positions - hidden at 1438, shown at 1223
const EFFECT_HIDDEN_X: float = 1438.0
const EFFECT_SHOWN_X: float = 1223.0


func _ready() -> void:
	visible = false
	
	# Load button texture
	if ResourceLoader.exists("res://assets/menu/Sprites/UI_NoteBook_Button01a.png"):
		button_texture = load("res://assets/menu/Sprites/UI_NoteBook_Button01a.png")
	
	# Clear template fish entries
	_clear_containers()
	
	# Connect buttons
	if prev_page_btn:
		prev_page_btn.pressed.connect(_on_prev_page)
	if next_page_btn:
		next_page_btn.pressed.connect(_on_next_page)
	if close_btn:
		close_btn.pressed.connect(close)
	
	_reset_effect_banner()


func _clear_containers() -> void:
	if left_container:
		for child in left_container.get_children():
			child.queue_free()
	if right_container:
		for child in right_container.get_children():
			child.queue_free()


func show_cooking(player_catch: Array, cowries: int = 0) -> void:
	catch_hold = player_catch.duplicate(true)
	current_cowries = cowries
	effects_gained.clear()
	cowries_earned = 0
	fish_eaten.clear()
	fish_sold.clear()
	current_page = 0
	
	_update_display()
	_reset_effect_banner()
	visible = true


func _update_display() -> void:
	_update_cowries()
	_populate_fish_grid()
	_update_page_buttons()


func _update_cowries() -> void:
	if cowries_label:
		cowries_label.text = "Cowries: %d" % current_cowries


func _populate_fish_grid() -> void:
	_clear_containers()
	
	if catch_hold.is_empty():
		# Show empty message
		var empty_label := Label.new()
		empty_label.text = "No fish in catch hold"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if left_container:
			left_container.add_child(empty_label)
		return
	
	# Group fish by name+quality
	var fish_groups := _group_fish()
	var group_keys := fish_groups.keys()
	
	# Sort by quality
	group_keys.sort_custom(func(a, b):
		var qa: String = fish_groups[a].quality
		var qb: String = fish_groups[b].quality
		var ia: int = QUALITY_ORDER.find(qa) if qa in QUALITY_ORDER else 99
		var ib: int = QUALITY_ORDER.find(qb) if qb in QUALITY_ORDER else 99
		return ia < ib if ia != ib else a < b
	)
	
	# Create grids for each page
	var left_grid := GridContainer.new()
	left_grid.columns = 3
	left_grid.add_theme_constant_override("h_separation", 15)
	left_grid.add_theme_constant_override("v_separation", 15)
	
	var right_grid := GridContainer.new()
	right_grid.columns = 3
	right_grid.add_theme_constant_override("h_separation", 15)
	right_grid.add_theme_constant_override("v_separation", 15)
	
	if left_container:
		left_container.add_child(left_grid)
	if right_container:
		right_container.add_child(right_grid)
	
	# Paginate
	var start_idx := current_page * fish_per_page
	var end_idx := mini(start_idx + fish_per_page, group_keys.size())
	
	for i in range(start_idx, end_idx):
		var key: String = group_keys[i]
		var group: Dictionary = fish_groups[key]
		var entry := _create_fish_entry(group)
		
		# First 9 on left, next 9 on right
		if (i - start_idx) < 9:
			left_grid.add_child(entry)
		else:
			right_grid.add_child(entry)


func _group_fish() -> Dictionary:
	var groups: Dictionary = {}
	for i in catch_hold.size():
		var fish = catch_hold[i]
		var fish_name := _get_fish_name(fish)
		var quality := _get_fish_quality(fish)
		var key := "%s|%s" % [quality, fish_name]
		
		if not groups.has(key):
			groups[key] = {
				"name": fish_name,
				"quality": quality,
				"indices": [],
				"base_value": _get_fish_value(fish),
			}
		groups[key].indices.append(i)
	return groups


func _get_fish_name(fish) -> String:
	if fish is Dictionary:
		if fish.has("fish") and fish.fish is FishData:
			return fish.fish.fish_name
		if fish.has("fish") and fish.fish is Dictionary:
			return fish.fish.get("fish_name", fish.fish.get("name", "Unknown"))
		return fish.get("name", fish.get("fish_name", "Unknown"))
	return "Unknown"


func _get_fish_quality(fish) -> String:
	if fish is Dictionary:
		if fish.has("quality_name"):
			return fish.quality_name
		if fish.has("quality") and fish.quality is Dictionary:
			return fish.quality.get("name", "Fresh")
	return "Fresh"


func _get_fish_value(fish) -> int:
	if fish is Dictionary:
		return fish.get("cowrie_value", fish.get("cowries", 10))
	return 10


func _create_fish_entry(group: Dictionary) -> Control:
	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(120, 150)
	vbox.add_theme_constant_override("separation", 5)
	
	# Fish image
	var tex_rect := TextureRect.new()
	tex_rect.custom_minimum_size = Vector2(80, 80)
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	
	# Load fish image from FishDatabase
	var img_path := _get_fish_image_path(group.name)
	if ResourceLoader.exists(img_path):
		tex_rect.texture = load(img_path)
	
	vbox.add_child(tex_rect)
	
	# Fish name + quality + count
	var label := Label.new()
	var count: int = group.indices.size()
	var text: String = group.name
	if count > 1:
		text += " x%d" % count
	text += "\n" + group.quality
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", QUALITY_COLORS.get(group.quality, Color.WHITE))
	vbox.add_child(label)
	
	# Buttons - use TextureButton with notebook button texture
	var btn_box := HBoxContainer.new()
	btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_box.add_theme_constant_override("separation", 5)
	
	# Eat button
	var eat_btn := TextureButton.new()
	eat_btn.custom_minimum_size = Vector2(75, 28)
	if button_texture:
		eat_btn.texture_normal = button_texture
		eat_btn.stretch_mode = TextureButton.STRETCH_SCALE
	eat_btn.pressed.connect(_on_eat_fish.bind(group.name, group.quality))
	
	var eat_label := Label.new()
	eat_label.text = "Eat"
	eat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eat_label.add_theme_font_size_override("font_size", 16)
	eat_label.add_theme_color_override("font_color", Color(0.035, 0.137, 0.271))
	eat_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	eat_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	eat_btn.add_child(eat_label)
	btn_box.add_child(eat_btn)
	
	# Sell button (was Cook)
	var sell_value: int = int(group.base_value * SELL_MULTIPLIERS.get(group.quality, 1.0))
	var sell_btn := TextureButton.new()
	sell_btn.custom_minimum_size = Vector2(75, 28)
	if button_texture:
		sell_btn.texture_normal = button_texture
		sell_btn.stretch_mode = TextureButton.STRETCH_SCALE
	sell_btn.pressed.connect(_on_sell_fish.bind(group.name, group.quality, sell_value))
	
	var sell_label := Label.new()
	sell_label.text = "$%d" % sell_value
	sell_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sell_label.add_theme_font_size_override("font_size", 16)
	sell_label.add_theme_color_override("font_color", Color(0.035, 0.137, 0.271))
	sell_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	sell_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sell_btn.add_child(sell_label)
	btn_box.add_child(sell_btn)
	
	vbox.add_child(btn_box)
	
	return vbox


func _get_fish_image_path(fish_name: String) -> String:
	# Try FishDatabase first
	if FishDatabase:
		var path: String = FishDatabase.get_fish_image_path(fish_name)
		if path and ResourceLoader.exists(path):
			return path
	
	# Fallback paths
	var clean_name := fish_name.to_lower().replace(" ", "").replace("-", "")
	var paths := [
		"res://assets/fish/%s.png" % clean_name,
		"res://assets/fish/kelpforest/%s.png" % clean_name,
		"res://assets/fish/%s.png" % fish_name.to_lower(),
	]
	
	for path in paths:
		if ResourceLoader.exists(path):
			return path
	
	return "res://assets/fish/kelpbass.png"  # Default


func _on_eat_fish(fish_name: String, quality: String) -> void:
	var idx := _find_fish_index(fish_name, quality)
	if idx < 0:
		return
	
	fish_eaten.append(catch_hold[idx])
	catch_hold.remove_at(idx)
	
	var effect := _roll_effect(quality)
	effects_gained.append(effect)
	_show_effect_notification(effect.desc)
	
	_update_display()
	if AudioManager:
		AudioManager.play_ui_confirm()


func _on_sell_fish(fish_name: String, quality: String, value: int) -> void:
	var idx := _find_fish_index(fish_name, quality)
	if idx < 0:
		return
	
	fish_sold.append(catch_hold[idx])
	catch_hold.remove_at(idx)
	current_cowries += value
	cowries_earned += value
	
	# Show quality dialogue first time for each quality
	_show_quality_dialogue(fish_name, quality, value)
	
	_update_display()
	if AudioManager:
		AudioManager.play_coins()


func _show_quality_dialogue(fish_name: String, quality: String, value: int) -> void:
	if not GameState:
		return
	
	# Check if we've seen this quality's dialogue before
	if GameState.fish_quality_dialogues_seen.has(quality):
		return
	
	GameState.fish_quality_dialogues_seen[quality] = true
	GameState.save_persistent_data()
	
	var dialogue_lines: Array = []
	var seeker := "relic_seeker_1"
	
	match quality:
		"Damaged", "Ruined":
			dialogue_lines = [
				{"character": "relic_seeker_1", "text": "Not much meat on this one..."},
				{"character": "relic_seeker_2", "text": "Not at all. Looks like it's been hacked to bits..."},
				{"character": "relic_seeker_3", "text": "What did you do to this one, boy?"},
				{"character": "narrator", "text": "You received a pittance for this meal: %d cowries." % value},
				{"character": "thought", "text": "Looks like they'll pay me almost nothing for a low-quality catch."}
			]
		"Bad", "Poor":
			dialogue_lines = [
				{"character": "relic_seeker_1", "text": "A bit disappointing today."},
				{"character": "relic_seeker_2", "text": "Definitely not your finest work."},
				{"character": "narrator", "text": "You received a meagre sum for this meal: %d cowries." % value},
				{"character": "thought", "text": "Looks like they'll pay less for a poor catch."}
			]
		"Mediocre":
			dialogue_lines = [
				{"character": "relic_seeker_1", "text": "I've seen worse, I suppose."},
				{"character": "relic_seeker_2", "text": "I've definitely seen better, too."},
				{"character": "relic_seeker_3", "text": "It'll do."},
				{"character": "narrator", "text": "You received the expected payment: %d cowries." % value},
				{"character": "thought", "text": "Looks like they'll pay me fairly for an average catch."}
			]
		"Fresh":
			dialogue_lines = [
				{"character": "relic_seeker_1", "text": "Now this is a good fish, boy."},
				{"character": "relic_seeker_2", "text": "Could be better..."},
				{"character": "relic_seeker_3", "text": "It's the best we've seen in a while, I'm not complainin'."},
				{"character": "narrator", "text": "You received a small bonus: %d cowries." % value},
				{"character": "thought", "text": "Looks like they'll pay a little extra for a good catch."}
			]
		"Pristine":
			dialogue_lines = [
				{"character": "relic_seeker_1", "text": "Well, well, everybody gather 'round for this beaut!"},
				{"character": "relic_seeker_2", "text": "Didn't think you were capable of a catch like this, boy, well done."},
				{"character": "narrator", "text": "The rest are too interested in eating to comment. You received a great sum: %d cowries." % value},
				{"character": "thought", "text": "Looks like they'll pay a lot extra for a high-quality catch."}
			]
	
	if dialogue_lines.size() > 0 and DialogueManager:
		DialogueManager.start_dialogue(dialogue_lines)


func _find_fish_index(fish_name: String, quality: String) -> int:
	for i in catch_hold.size():
		var fish = catch_hold[i]
		if _get_fish_name(fish) == fish_name and _get_fish_quality(fish) == quality:
			return i
	return -1


func _roll_effect(quality: String) -> Dictionary:
	var roll := randf()
	var effect_pool: Array
	
	match quality:
		"Pristine":
			effect_pool = POSITIVE_EFFECTS if roll < 0.9 else NEUTRAL_EFFECTS
		"Fresh":
			effect_pool = POSITIVE_EFFECTS if roll < 0.7 else NEUTRAL_EFFECTS
		"Mediocre":
			if roll < 0.4:
				effect_pool = POSITIVE_EFFECTS
			elif roll < 0.8:
				effect_pool = NEUTRAL_EFFECTS
			else:
				effect_pool = NEGATIVE_EFFECTS
		"Poor", "Bad":
			if roll < 0.2:
				effect_pool = POSITIVE_EFFECTS
			elif roll < 0.5:
				effect_pool = NEUTRAL_EFFECTS
			else:
				effect_pool = NEGATIVE_EFFECTS
		_:  # Ruined, Damaged
			effect_pool = NEGATIVE_EFFECTS if roll < 0.7 else NEUTRAL_EFFECTS
	
	return effect_pool[randi() % effect_pool.size()]


func _show_effect_notification(text: String) -> void:
	if not effect_banner or not effect_text:
		return
	
	effect_text.text = text
	
	# Banner starts at SHOWN position, animate right (out) then back left (in)
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	# Slide out to the right
	tween.tween_property(effect_banner, "position:x", EFFECT_HIDDEN_X, 0.3)
	tween.parallel().tween_property(effect_text, "position:x", EFFECT_HIDDEN_X + 36, 0.3)
	# Hold briefly
	tween.tween_interval(1.5)
	# Slide back in to the left (shown position)
	tween.tween_property(effect_banner, "position:x", EFFECT_SHOWN_X, 0.3)
	tween.parallel().tween_property(effect_text, "position:x", EFFECT_SHOWN_X + 36, 0.3)


func _reset_effect_banner() -> void:
	# Banner is at SHOWN position by default
	if effect_banner:
		effect_banner.position.x = EFFECT_SHOWN_X
	if effect_text:
		effect_text.position.x = EFFECT_SHOWN_X + 36
		effect_text.text = ""


func _update_page_buttons() -> void:
	var total_groups := _group_fish().size()
	var total_pages := ceili(float(total_groups) / fish_per_page)
	
	if prev_page_btn:
		prev_page_btn.visible = current_page > 0
	if next_page_btn:
		next_page_btn.visible = current_page < total_pages - 1


func _on_prev_page() -> void:
	if current_page > 0:
		current_page -= 1
		if AudioManager:
			AudioManager.play_card_flip()
		_update_display()


func _on_next_page() -> void:
	current_page += 1
	if AudioManager:
		AudioManager.play_card_flip()
	_update_display()


func close() -> void:
	visible = false
	cooking_completed.emit({
		"remaining_catch": catch_hold,
		"effects": effects_gained,
		"cowries_earned": cowries_earned,
		"total_cowries": current_cowries,
		"fish_eaten": fish_eaten,
		"fish_sold": fish_sold
	})
