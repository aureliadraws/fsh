extends Control
## Rewards Screen - Post-battle loot selection
## Uses proper card layout for display

signal rewards_completed(chosen_reward: Dictionary)

# Updated node paths for notebook layout
@onready var title_label: Label = $Title
@onready var cowrie_label: Label = $LeftPageContainer/CowriesEarned
@onready var card_choices: HBoxContainer = $LeftPageContainer/CardChoices
@onready var skip_button: Button = $RightPageContainer/Skip
@onready var close_button: Button = $CloseButton
@onready var effect_banner: TextureRect = $EffectBanner
@onready var effect_text: Label = $EffectText

const CARD_LAYOUT_SCENE := preload("res://scenes/roguelike/card layout.tscn")

# Effect banner positions
const EFFECT_SHOWN_X: float = 1223.0
const EFFECT_HIDDEN_X: float = 1438.0

var cowries_earned: int = 0
var card_options: Array = []
var selected_card: CardData = null

# Card pool for rewards
const REWARD_CARDS := [
	{"name": "Sharpened Hook", "hook": 2, "line": 2, "sinker": "None", "sinker_power": 0},
	{"name": "Sturdy Line", "hook": 1, "line": 3, "sinker": "None", "sinker_power": 0},
	{"name": "Shock Net", "hook": 1, "line": 2, "sinker": "Stun", "sinker_power": 1},
	{"name": "Serrated Edge", "hook": 2, "line": 1, "sinker": "Bleed", "sinker_power": 1},
	{"name": "Iron Anchor", "hook": 1, "line": 5, "sinker": "None", "sinker_power": 0},
	{"name": "Chum Pouch", "hook": 0, "line": 1, "sinker": "Attract", "sinker_power": 1},
	{"name": "Mending Thread", "hook": 1, "line": 2, "sinker": "Repair", "sinker_power": 1},
	{"name": "Pushing Oar", "hook": 1, "line": 2, "sinker": "Push", "sinker_power": 1},
	{"name": "Grapple", "hook": 2, "line": 2, "sinker": "Pull", "sinker_power": 1},
	{"name": "Thick Shield", "hook": 0, "line": 4, "sinker": "Shield", "sinker_power": 1},
]


func _ready() -> void:
	visible = false
	skip_button.pressed.connect(_on_skip)
	skip_button.mouse_entered.connect(_on_button_hover)
	if close_button:
		close_button.pressed.connect(_on_skip)
	_reset_effect_banner()


func _reset_effect_banner() -> void:
	if effect_banner:
		effect_banner.position.x = EFFECT_SHOWN_X
	if effect_text:
		effect_text.position.x = EFFECT_SHOWN_X + 36
		effect_text.text = ""


func _show_effect_notification(text: String) -> void:
	if not effect_banner or not effect_text:
		return
	effect_text.text = text
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(effect_banner, "position:x", EFFECT_HIDDEN_X, 0.3)
	tween.parallel().tween_property(effect_text, "position:x", EFFECT_HIDDEN_X + 36, 0.3)
	tween.tween_interval(1.5)
	tween.tween_property(effect_banner, "position:x", EFFECT_SHOWN_X, 0.3)
	tween.parallel().tween_property(effect_text, "position:x", EFFECT_SHOWN_X + 36, 0.3)


func _on_button_hover() -> void:
	AudioManager.play_ui_select()


func show_rewards(cowries: int, is_elite: bool = false) -> void:
	cowries_earned = cowries
	selected_card = null
	
	AudioManager.play_card_shuffle()
	
	# Generate card options
	card_options.clear()
	var pool := REWARD_CARDS.duplicate()
	pool.shuffle()
	
	var num_choices: int = 3 if is_elite else 2
	
	for i in num_choices:
		if i >= pool.size():
			break
		var template: Dictionary = pool[i]
		var card := CardData.new()
		card.card_name = template.name
		card.hook = template.hook
		card.line = template.line
		card.sinker = template.sinker
		card.sinker_power = template.sinker_power
		
		# Elite rewards get +1 to a random stat
		if is_elite:
			match randi() % 2:
				0: card.hook += 1
				1: card.line += 1
		
		card_options.append(card)
	
	_update_display()
	visible = true


func _update_display() -> void:
	title_label.text = "Choose a Reward"
	cowrie_label.text = "+%d Cowries" % cowries_earned
	
	# Animate title
	AnimHelper.pop_in(title_label, 0.5)
	AnimHelper.slide_in(cowrie_label, Vector2(0, -30), 0.4, 0.2)
	
	# Clear card choices
	for child in card_choices.get_children():
		child.queue_free()
	
	# Show card options using proper card layout at FULL SCALE
	var panels: Array = []
	for i in card_options.size():
		var card: CardData = card_options[i]
		var card_panel := _create_card_panel(card, i)
		card_choices.add_child(card_panel)
		panels.append(card_panel)
	
	# Animate cards appearing
	AnimHelper.stagger_pop_in(panels, 0.1)


func _create_card_panel(card: CardData, index: int) -> Control:
	# Create a container for the card and button
	var container := VBoxContainer.new()
	container.custom_minimum_size = Vector2(280, 450)
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.add_theme_constant_override("separation", 15)
	
	# Create a CenterContainer to hold the card
	var card_holder := CenterContainer.new()
	card_holder.custom_minimum_size = Vector2(280, 390)
	container.add_child(card_holder)
	
	# Create SubViewport to properly render Node2D card at FULL SCALE
	var viewport := SubViewport.new()
	viewport.size = Vector2i(280, 390)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	
	# Create the card display using the scene at FULL SCALE (1x, never smaller)
	var card_display: Node2D = CARD_LAYOUT_SCENE.instantiate()
	# Card origin is at center, so position it at viewport center
	card_display.position = Vector2(140, 195)  # Center of 280x390 viewport
	viewport.add_child(card_display)
	
	# Wrap viewport in container
	var viewport_container := SubViewportContainer.new()
	viewport_container.custom_minimum_size = Vector2(280, 390)
	viewport_container.stretch = true
	viewport_container.add_child(viewport)
	card_holder.add_child(viewport_container)
	
	# Setup the card with data
	_setup_card_display(card_display, card)
	
	# Choose button
	var choose_btn := Button.new()
	choose_btn.text = "TAKE THIS CARD"
	choose_btn.custom_minimum_size = Vector2(220, 45)
	choose_btn.pressed.connect(_on_card_chosen.bind(card))
	choose_btn.mouse_entered.connect(_on_button_hover)
	container.add_child(choose_btn)
	
	return container


func _setup_card_display(card_display: Node, card: CardData) -> void:
	if card_display.has_method("setup"):
		card_display.setup(card)
		return
	
	# Manual setup fallback
	var front = card_display.get_node_or_null("Front")
	var back = card_display.get_node_or_null("Back")
	var fish_name_label = card_display.get_node_or_null("FishName")
	var fish_name_label_2 = card_display.get_node_or_null("FishName2")
	var bait_label = card_display.get_node_or_null("Bait")
	var hook_label = card_display.get_node_or_null("Hook")
	var line_label = card_display.get_node_or_null("Line")
	var sinker_label = card_display.get_node_or_null("Sinker")
	var sinker_desc = card_display.get_node_or_null("SinkerDesc")
	var fish_image_bg = card_display.get_node_or_null("FishImageBackground")
	var fish_image_bg_effect = card_display.get_node_or_null("FishImageBackground/FishImageBackgroundEffect")
	
	# Show front, hide back
	if front: front.visible = true
	if back: back.visible = false
	
	# Show FishImageBackground
	if fish_image_bg: fish_image_bg.visible = true
	if fish_image_bg_effect: fish_image_bg_effect.visible = true
	
	var has_bait := card.bait_cost > 0
	var has_sinker := card.sinker != "None" and card.sinker != ""
	
	# Set name using appropriate label
	if has_bait:
		if fish_name_label:
			fish_name_label.visible = true
			fish_name_label.text = card.card_name
		if fish_name_label_2:
			fish_name_label_2.visible = false
	else:
		if fish_name_label:
			fish_name_label.visible = false
		if fish_name_label_2:
			fish_name_label_2.visible = true
			fish_name_label_2.text = card.card_name
	
	# Set stats
	if hook_label: hook_label.text = str(card.hook)
	if line_label: line_label.text = str(card.line)
	if bait_label:
		bait_label.visible = has_bait
		if has_bait: bait_label.text = str(card.bait_cost)
	
	# Set sinker
	if sinker_label:
		sinker_label.visible = has_sinker
		if has_sinker: sinker_label.text = card.sinker
	if sinker_desc:
		sinker_desc.visible = has_sinker
		if has_sinker and CardDatabase:
			sinker_desc.text = CardDatabase.get_sinker_description_dynamic(card.sinker, card.sinker_power)


func _on_card_chosen(card: CardData) -> void:
	AudioManager.play_card_deal()
	selected_card = card
	visible = false
	rewards_completed.emit({
		"cowries": cowries_earned,
		"card": selected_card
	})


func _on_skip() -> void:
	AudioManager.play_ui_confirm()
	visible = false
	rewards_completed.emit({
		"cowries": cowries_earned,
		"card": null
	})
