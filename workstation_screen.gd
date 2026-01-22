extends Control
## Workstation Screen - Combine two cards to create a new one
## Each attribute (hook, line, sinker, bait) is randomly taken from either parent
## Uses proper card layout for display at FULL SCALE (1x minimum)

signal workstation_completed(result: Dictionary)

# Updated node paths for notebook layout
@onready var title_label: Label = $Title
@onready var card_list: GridContainer = $LeftPageContainer/CardScroll/CardList
@onready var selected_container: HBoxContainer = $RightPageContainer/SelectedCards
@onready var result_container: Control = $RightPageContainer/ResultContainer
@onready var combine_button: Button = $RightPageContainer/Buttons/CombineButton
@onready var done_button: Button = $RightPageContainer/Buttons/DoneButton
@onready var message_label: Label = $RightPageContainer/Message
@onready var close_button: Button = $CloseButton
@onready var effect_banner: TextureRect = $EffectBanner
@onready var effect_text: Label = $EffectText

const CARD_LAYOUT_SCENE := preload("res://scenes/roguelike/card layout.tscn")

# Effect banner positions
const EFFECT_SHOWN_X: float = 1223.0
const EFFECT_HIDDEN_X: float = 1438.0

var player_deck: Array = []
var selected_cards: Array = []  # [CardData, CardData]
var combined_card: CardData = null
var has_combined: bool = false


func _ready() -> void:
	visible = false
	combine_button.pressed.connect(_on_combine)
	done_button.pressed.connect(_on_done)
	combine_button.mouse_entered.connect(_on_button_hover)
	done_button.mouse_entered.connect(_on_button_hover)
	if close_button:
		close_button.pressed.connect(_on_done)
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


func show_workstation(deck: Array) -> void:
	player_deck = deck.duplicate()
	selected_cards.clear()
	combined_card = null
	has_combined = false
	message_label.text = "Select two cards to combine"
	if result_container:
		result_container.visible = true
	combine_button.disabled = true
	
	_update_display()
	visible = true


func _update_display() -> void:
	# Clear card list
	for child in card_list.get_children():
		child.queue_free()
	
	# Clear selected display
	for child in selected_container.get_children():
		child.queue_free()
	
	# Show available cards
	for i in player_deck.size():
		var card: CardData = player_deck[i]
		
		# Skip already selected cards
		var is_selected := false
		for sel in selected_cards:
			if sel == card:
				is_selected = true
				break
		
		if is_selected:
			continue
		
		var card_panel := _create_card_panel(card, i)
		card_list.add_child(card_panel)
	
	# Show selected cards
	for card in selected_cards:
		var panel := _create_selected_panel(card)
		selected_container.add_child(panel)
	
	# Add placeholder if not enough selected
	while selected_container.get_child_count() < 2:
		var card_width := mini(220, int(get_viewport_rect().size.x / 5))
		var card_height := int(card_width * 1.4)
		var placeholder := Panel.new()
		placeholder.custom_minimum_size = Vector2(card_width, card_height + 50)
		placeholder.modulate = Color(0.5, 0.5, 0.5, 0.5)
		selected_container.add_child(placeholder)
	
	# Update combine button
	combine_button.disabled = selected_cards.size() != 2 or has_combined


func _create_card_panel(card: CardData, index: int) -> Control:
	# Create a container for the card and button
	var container := VBoxContainer.new()
	# Smaller sizes for better fit on lower resolutions
	var card_width := mini(220, int(get_viewport_rect().size.x / 5))
	var card_height := int(card_width * 1.4)  # Maintain aspect ratio
	container.custom_minimum_size = Vector2(card_width, card_height + 50)
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.add_theme_constant_override("separation", 8)
	
	# Create a CenterContainer to hold the card
	var card_holder := CenterContainer.new()
	card_holder.custom_minimum_size = Vector2(card_width, card_height)
	container.add_child(card_holder)
	
	# Create SubViewport to properly render Node2D card at FULL SCALE
	var viewport := SubViewport.new()
	viewport.size = Vector2i(card_width, card_height)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	
	# Create the card display using the scene at FULL SCALE (1x)
	var card_display: Node2D = CARD_LAYOUT_SCENE.instantiate()
	var scale_factor := float(card_width) / 280.0
	card_display.position = Vector2(card_width / 2, card_height / 2)  # Center of viewport
	card_display.scale = Vector2(scale_factor, scale_factor)
	viewport.add_child(card_display)
	
	# Wrap viewport in container
	var viewport_container := SubViewportContainer.new()
	viewport_container.custom_minimum_size = Vector2(card_width, card_height)
	viewport_container.stretch = true
	viewport_container.add_child(viewport)
	card_holder.add_child(viewport_container)
	
	# Setup the card with data
	_setup_card_display(card_display, card)
	
	# Select button
	var select_btn := Button.new()
	select_btn.text = "SELECT"
	select_btn.custom_minimum_size = Vector2(mini(160, card_width - 20), 35)
	select_btn.pressed.connect(_on_card_selected.bind(index))
	select_btn.mouse_entered.connect(_on_button_hover)
	container.add_child(select_btn)
	
	return container


func _create_selected_panel(card: CardData) -> Control:
	# Create a container for the card and button
	var container := VBoxContainer.new()
	# Smaller sizes for better fit on lower resolutions
	var card_width := mini(220, int(get_viewport_rect().size.x / 5))
	var card_height := int(card_width * 1.4)  # Maintain aspect ratio
	container.custom_minimum_size = Vector2(card_width, card_height + 50)
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.add_theme_constant_override("separation", 8)
	
	# Create a CenterContainer to hold the card
	var card_holder := CenterContainer.new()
	card_holder.custom_minimum_size = Vector2(card_width, card_height)
	container.add_child(card_holder)
	
	# Create SubViewport to properly render Node2D card at FULL SCALE
	var viewport := SubViewport.new()
	viewport.size = Vector2i(card_width, card_height)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	
	# Create the card display using the scene at FULL SCALE (1x)
	var card_display: Node2D = CARD_LAYOUT_SCENE.instantiate()
	card_display.position = Vector2(card_width / 2, card_height / 2)  # Center of viewport
	# Scale down the card to fit smaller viewport
	var scale_factor := float(card_width) / 280.0
	card_display.scale = Vector2(scale_factor, scale_factor)
	viewport.add_child(card_display)
	
	# Wrap viewport in container
	var viewport_container := SubViewportContainer.new()
	viewport_container.custom_minimum_size = Vector2(card_width, card_height)
	viewport_container.stretch = true
	viewport_container.add_child(viewport)
	card_holder.add_child(viewport_container)
	
	# Setup the card with data
	_setup_card_display(card_display, card)
	
	# Add green tint to selected cards
	viewport_container.modulate = Color(0.8, 1.2, 0.8)
	
	# Remove button
	var remove_btn := Button.new()
	remove_btn.text = "REMOVE"
	remove_btn.custom_minimum_size = Vector2(mini(160, card_width - 20), 35)
	remove_btn.pressed.connect(_on_card_deselected.bind(card))
	remove_btn.mouse_entered.connect(_on_button_hover)
	container.add_child(remove_btn)
	
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


func _on_card_selected(index: int) -> void:
	if selected_cards.size() >= 2:
		return
	
	AudioManager.play_card_deal()
	selected_cards.append(player_deck[index])
	
	if selected_cards.size() == 2:
		message_label.text = "Ready to combine!"
	else:
		message_label.text = "Select one more card"
	
	_update_display()


func _on_card_deselected(card: CardData) -> void:
	AudioManager.play_card_flip()
	selected_cards.erase(card)
	message_label.text = "Select two cards to combine"
	_update_display()


func _on_combine() -> void:
	if selected_cards.size() != 2:
		return
	
	AudioManager.play_ui_confirm()
	AudioManager.play_hammering()  # Crafting sound
	
	# Combine the cards
	combined_card = CardDatabase.combine_cards(selected_cards[0], selected_cards[1])
	
	# Remove old cards from deck
	for card in selected_cards:
		player_deck.erase(card)
	
	# Add new card
	player_deck.append(combined_card)
	
	# Show result
	_show_result()
	
	has_combined = true
	selected_cards.clear()
	_update_display()


func _show_result() -> void:
	# Clear and show the combined card using card layout
	if result_container:
		for child in result_container.get_children():
			child.queue_free()
		
		# Create SubViewport for result card at FULL SCALE
		var viewport := SubViewport.new()
		viewport.size = Vector2i(280, 390)
		viewport.transparent_bg = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		
		var card_display: Node2D = CARD_LAYOUT_SCENE.instantiate()
		card_display.position = Vector2(140, 195)
		viewport.add_child(card_display)
		
		var viewport_container := SubViewportContainer.new()
		viewport_container.custom_minimum_size = Vector2(280, 390)
		viewport_container.stretch = true
		viewport_container.add_child(viewport)
		result_container.add_child(viewport_container)
		
		_setup_card_display(card_display, combined_card)
	
	message_label.text = "Card created! Click Done to continue."


func _on_done() -> void:
	AudioManager.play_ui_confirm()
	visible = false
	workstation_completed.emit({
		"deck": player_deck,
		"combined": combined_card
	})
