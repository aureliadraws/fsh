extends Control
## Deck Viewer - View all cards in your deck
## Uses proper card layout at FULL SCALE (1x minimum)

signal closed

@onready var title_label: Label = $Panel/VBoxContainer/Header/Title
@onready var card_count_label: Label = $Panel/VBoxContainer/Header/CardCount
@onready var card_grid: GridContainer = $Panel/VBoxContainer/ScrollContainer/CardGrid
@onready var close_button: Button = $Panel/VBoxContainer/Close
@onready var sort_button: Button = $Panel/VBoxContainer/Header/SortButton

const CARD_LAYOUT_SCENE := preload("res://scenes/roguelike/card layout.tscn")

var current_deck: Array = []
var sort_mode: int = 0  # 0=name, 1=hook, 2=line, 3=sinker

const SORT_NAMES := ["Name", "HOOK", "LINE", "Sinker"]


func _ready() -> void:
	visible = false
	close_button.pressed.connect(_on_close)
	sort_button.pressed.connect(_on_sort)
	
	# Connect hover sounds
	close_button.mouse_entered.connect(_on_button_hover)
	sort_button.mouse_entered.connect(_on_button_hover)
	
	modulate.a = 0


func _on_button_hover() -> void:
	AudioManager.play_ui_select()


func show_deck(deck: Array) -> void:
	current_deck = deck
	AudioManager.play_card_shuffle()
	_update_display()
	visible = true
	_animate_open()


func _update_display() -> void:
	card_count_label.text = "%d cards" % current_deck.size()
	sort_button.text = "Sort: %s" % SORT_NAMES[sort_mode]
	
	# Clear grid
	for child in card_grid.get_children():
		child.queue_free()
	
	# Sort deck
	var sorted_deck := current_deck.duplicate()
	match sort_mode:
		0: sorted_deck.sort_custom(_sort_by_name)
		1: sorted_deck.sort_custom(_sort_by_hook)
		2: sorted_deck.sort_custom(_sort_by_line)
		3: sorted_deck.sort_custom(_sort_by_sinker)
	
	# Create card displays using proper card layout
	for i in sorted_deck.size():
		var card: CardData = sorted_deck[i]
		var card_panel := _create_card_panel(card, i)
		card_grid.add_child(card_panel)


func _create_card_panel(card: CardData, index: int) -> Control:
	# Create a container for the card
	var container := Control.new()
	container.custom_minimum_size = Vector2(280, 400)
	
	# Animate in with delay
	container.modulate.a = 0
	container.scale = Vector2(0.8, 0.8)
	container.pivot_offset = Vector2(140, 200)
	
	var anim_tween := create_tween()
	anim_tween.set_ease(Tween.EASE_OUT)
	anim_tween.set_trans(Tween.TRANS_BACK)
	anim_tween.tween_property(container, "modulate:a", 1.0, 0.2).set_delay(index * 0.03)
	anim_tween.parallel().tween_property(container, "scale", Vector2.ONE, 0.25).set_delay(index * 0.03)
	
	# Create SubViewport to properly render Node2D card at FULL SCALE
	var viewport := SubViewport.new()
	viewport.size = Vector2i(280, 400)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	
	# Create the card display using the scene at FULL SCALE (1x, never smaller)
	var card_display: Node2D = CARD_LAYOUT_SCENE.instantiate()
	card_display.position = Vector2(140, 200)  # Center of viewport
	viewport.add_child(card_display)
	
	# Wrap viewport in container
	var viewport_container := SubViewportContainer.new()
	viewport_container.custom_minimum_size = Vector2(280, 400)
	viewport_container.stretch = true
	viewport_container.add_child(viewport)
	container.add_child(viewport_container)
	
	# Setup the card with data
	_setup_card_display(card_display, card)
	
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


func _sort_by_name(a: CardData, b: CardData) -> bool:
	return a.card_name < b.card_name


func _sort_by_hook(a: CardData, b: CardData) -> bool:
	return a.hook > b.hook


func _sort_by_line(a: CardData, b: CardData) -> bool:
	return a.line > b.line


func _sort_by_sinker(a: CardData, b: CardData) -> bool:
	var a_sinker := a.sinker if a.sinker != "None" else ""
	var b_sinker := b.sinker if b.sinker != "None" else ""
	return a_sinker < b_sinker


func _on_sort() -> void:
	AudioManager.play_card_flip()
	sort_mode = (sort_mode + 1) % 4
	_update_display()


func _animate_open() -> void:
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "modulate:a", 1.0, 0.3)


func _on_close() -> void:
	AudioManager.play_ui_confirm()
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	await tween.finished
	visible = false
	closed.emit()


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		_on_close()
