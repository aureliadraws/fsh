extends Control
## Salvage Screen - Choose 1 of 3 cards at salvage nodes
## FIXED: Cards now span across both pages for proper layout

signal salvage_completed(result: Dictionary)

# Updated node paths for notebook layout
@onready var title_label: Label = $Title
@onready var left_page_container: Control = $LeftPageContainer
@onready var right_page_container: VBoxContainer = $RightPageContainer
@onready var message_label: Label = $RightPageContainer/Message
@onready var skip_button: Button = $RightPageContainer/SkipButton
@onready var close_button: Button = $CloseButton
@onready var effect_banner: TextureRect = $EffectBanner
@onready var effect_text: Label = $EffectText

const CARD_LAYOUT_SCENE := preload("res://scenes/roguelike/card layout.tscn")

# Effect banner positions
const EFFECT_SHOWN_X: float = 1223.0
const EFFECT_HIDDEN_X: float = 1438.0

var card_choices: Array = []  # Array of CardData
var card_displays: Array = []  # Array of CardDisplay nodes
var selected_card: CardData = null
var is_first_salvage: bool = false

# Container for cards that spans both pages
var card_container: HBoxContainer = null


func _ready() -> void:
	visible = false
	if skip_button:
		skip_button.pressed.connect(_on_skip)
		skip_button.mouse_entered.connect(_on_button_hover)
	if close_button:
		close_button.pressed.connect(_on_skip)
	_reset_effect_banner()
	_setup_card_container()


func _setup_card_container() -> void:
	# Create a container that spans both pages
	card_container = HBoxContainer.new()
	card_container.alignment = BoxContainer.ALIGNMENT_CENTER
	card_container.add_theme_constant_override("separation", 30)
	# Position to span across both notebook pages
	card_container.position = Vector2(450, 300)
	card_container.size = Vector2(950, 450)
	add_child(card_container)


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


## Show salvage screen with 3 card options
func show_salvage(salvage: Array, deck: Array, is_starter: bool = false) -> void:
	is_first_salvage = is_starter
	selected_card = null
	
	# Generate 3 card choices from salvage pool
	card_choices.clear()
	var pool: Array = CardDatabase.get_salvage_pool()
	pool.shuffle()
	
	for i in mini(3, pool.size()):
		var card := CardDatabase.create_card_data(pool[i].name)
		if card:
			card_choices.append(card)
	
	# If not enough cards in pool, add some common ones
	while card_choices.size() < 3:
		var backup := CardDatabase.get_random_card("common")
		if not backup.is_empty():
			var card := CardDatabase.create_card_data(backup.name)
			if card:
				card_choices.append(card)
	
	AudioManager.play_card_shuffle()
	_update_display()
	visible = true


func _update_display() -> void:
	# Clear existing cards
	if card_container:
		for child in card_container.get_children():
			child.queue_free()
	card_displays.clear()
	
	if title_label:
		title_label.text = "SALVAGE"
	if message_label:
		message_label.text = "Select one card to add to your deck"
	
	# Create card displays for each choice - now they'll span both pages
	for i in card_choices.size():
		var card: CardData = card_choices[i]
		var card_panel := _create_card_panel(card, i)
		card_container.add_child(card_panel)


func _create_card_panel(card: CardData, index: int) -> Control:
	# Create a container for the card and button
	var container := VBoxContainer.new()
	container.custom_minimum_size = Vector2(254, 400)
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.add_theme_constant_override("separation", 15)
	
	# Create a CenterContainer to hold the card
	var card_holder := CenterContainer.new()
	card_holder.custom_minimum_size = Vector2(254, 348)
	container.add_child(card_holder)
	
	# Create SubViewport to properly render Node2D card
	var viewport := SubViewport.new()
	viewport.size = Vector2i(254, 348)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	
	# Create the card display using the scene at FULL SCALE
	var card_display: Node2D = CARD_LAYOUT_SCENE.instantiate()
	# Card origin is at center, so position it at viewport center
	card_display.position = Vector2(127, 174)  # Center of 254x348 viewport
	viewport.add_child(card_display)
	
	# Wrap viewport in container
	var viewport_container := SubViewportContainer.new()
	viewport_container.custom_minimum_size = Vector2(254, 348)
	viewport_container.stretch = true
	# CRITICAL: Allow mouse events to pass through to button below
	viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport_container.add_child(viewport)
	card_holder.add_child(viewport_container)
	
	# Setup the card with data
	if card_display.has_method("setup"):
		card_display.setup(card)
	
	card_displays.append(card_display)
	
	# Choose button - positioned below card
	var choose_btn := Button.new()
	choose_btn.text = "TAKE THIS"
	choose_btn.custom_minimum_size = Vector2(200, 40)
	choose_btn.pressed.connect(_on_card_chosen.bind(index))
	choose_btn.mouse_entered.connect(_on_button_hover)
	container.add_child(choose_btn)
	
	return container


func _on_card_chosen(index: int) -> void:
	if index < 0 or index >= card_choices.size():
		return
	
	AudioManager.play_card_deal()
	selected_card = card_choices[index]
	
	# Notify GameState if available
	if has_node("/root/GameState"):
		GameState.add_run_salvage_card(selected_card)
	
	if message_label:
		message_label.text = "Acquired: %s!" % selected_card.card_name
	
	# Brief delay then complete
	await get_tree().create_timer(0.5).timeout
	_complete()


func _on_skip() -> void:
	AudioManager.play_ui_confirm()
	selected_card = null
	_complete()


func _complete() -> void:
	visible = false
	salvage_completed.emit({
		"crafted": [selected_card] if selected_card else [],
		"upgraded": [],
		"was_starter": is_first_salvage
	})
