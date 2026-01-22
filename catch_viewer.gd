extends Control
## Catch Viewer - Shows fish inventory and deck cards
## Fish display: Large fish images with quantity badge, click for quality breakdown

signal closed

@onready var tab_container: TabContainer = $Panel/TabContainer
@onready var fish_grid: GridContainer = $Panel/TabContainer/Catch/ScrollContainer/FishGrid
@onready var deck_scroll: ScrollContainer = $Panel/TabContainer/Deck/ScrollContainer
@onready var deck_list: GridContainer = $Panel/TabContainer/Deck/ScrollContainer/DeckList
@onready var cowrie_label: Label = $Panel/Header/GoldLabel
@onready var close_button: Button = $Panel/CloseButton
@onready var quality_popup: Panel = $QualityPopup

var catch_hold: Array = []
var player_deck: Array = []
var current_cowries: int = 0

# Quality names in order from best to worst
const QUALITY_NAMES: Array[String] = ["Pristine", "Fresh", "Mediocre", "Poor", "Ruined"]
const QUALITY_COLORS: Dictionary = {
	"Pristine": Color(0.9, 0.8, 0.2),  # Gold
	"Fresh": Color(0.3, 0.8, 0.3),     # Green
	"Mediocre": Color(0.7, 0.7, 0.7),  # Gray
	"Poor": Color(0.8, 0.5, 0.3),      # Orange
	"Ruined": Color(0.8, 0.3, 0.3),    # Red
}

const FISH_DISPLAY_SIZE := Vector2(140, 140)

var CARD_SCENE: PackedScene


func _ready() -> void:
	visible = false
	close_button.pressed.connect(_on_close)
	close_button.mouse_entered.connect(_on_button_hover)
	
	# Setup quality popup
	if quality_popup:
		quality_popup.visible = false
	
	# Load card scene for deck display
	for path in ["res://scenes/roguelike/card layout.tscn", "res://scenes/menus/card layout.tscn"]:
		if ResourceLoader.exists(path):
			CARD_SCENE = load(path)
			break


func _on_button_hover() -> void:
	if has_node("/root/AudioManager"):
		AudioManager.play_ui_select()


## Show the catch viewer
func show_catch(catch: Array, deck: Array, cowries: int) -> void:
	catch_hold = catch
	player_deck = deck
	current_cowries = cowries
	
	AudioManager.play_open_inventory()
	_update_display()
	visible = true


## Update from GameState
func show_from_game_state() -> void:
	if has_node("/root/GameState"):
		catch_hold = GameState.get_catch_hold()
		current_cowries = GameState.cowries
	
	AudioManager.play_open_inventory()
	_update_display()
	visible = true


func _update_display() -> void:
	if cowrie_label:
		cowrie_label.text = "Cowries: %d" % current_cowries
	
	# Update fish grid - grouped by fish type (not quality)
	if fish_grid:
		for child in fish_grid.get_children():
			child.queue_free()
		
		# Set grid columns
		fish_grid.columns = 4
		fish_grid.add_theme_constant_override("h_separation", 20)
		fish_grid.add_theme_constant_override("v_separation", 20)
	
	if catch_hold.is_empty():
		if fish_grid:
			var empty_lbl := Label.new()
			empty_lbl.text = "No fish caught yet"
			empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			empty_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
			fish_grid.add_child(empty_lbl)
	else:
		# Group fish by name only (collect all qualities)
		var fish_groups: Dictionary = {}  # Key: fish_name -> Array of {quality_name, count}
		
		for fish_entry in catch_hold:
			var fish_data: FishData = fish_entry.get("fish") as FishData
			if fish_data == null:
				continue
			
			var fish_name: String = fish_data.fish_name
			var quality_dict = fish_entry.get("quality", {})
			var quality_name: String = quality_dict.get("quality_name", "Fresh") if quality_dict is Dictionary else "Fresh"
			
			if not fish_groups.has(fish_name):
				fish_groups[fish_name] = {
					"fish_data": fish_data,
					"qualities": {},
					"total_count": 0
				}
			
			fish_groups[fish_name].total_count += 1
			if fish_groups[fish_name].qualities.has(quality_name):
				fish_groups[fish_name].qualities[quality_name] += 1
			else:
				fish_groups[fish_name].qualities[quality_name] = 1
		
		# Display each fish type as a large image with quantity
		if fish_grid:
			for fish_name in fish_groups.keys():
				var group = fish_groups[fish_name]
				var fish_display := _create_fish_display(group.fish_data, group.total_count, group.qualities)
				fish_grid.add_child(fish_display)
	
	# Update deck list using actual card layouts
	if deck_list:
		for child in deck_list.get_children():
			child.queue_free()
	
	if player_deck.is_empty():
		if deck_list:
			var empty_lbl := Label.new()
			empty_lbl.text = "Deck is empty"
			empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			empty_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
			deck_list.add_child(empty_lbl)
	else:
		for card in player_deck:
			if card is CardData:
				var card_display := _create_card_display(card)
				if card_display and deck_list:
					deck_list.add_child(card_display)


func _create_fish_display(fish_data: FishData, total_count: int, qualities: Dictionary) -> Control:
	# Container for the fish display
	var container := Control.new()
	container.custom_minimum_size = FISH_DISPLAY_SIZE
	
	# Fish image (large, no box)
	var fish_name: String = fish_data.fish_name
	var image_path: String = FishDatabase.get_fish_image_path(fish_name)
	
	var texture_rect := TextureRect.new()
	texture_rect.custom_minimum_size = FISH_DISPLAY_SIZE
	texture_rect.size = FISH_DISPLAY_SIZE
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	
	if ResourceLoader.exists(image_path):
		texture_rect.texture = load(image_path)
	elif fish_data.texture:
		texture_rect.texture = fish_data.texture
	else:
		# Fallback - create colored placeholder
		var placeholder := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		placeholder.fill(Color(0.3, 0.5, 0.7))
		texture_rect.texture = ImageTexture.create_from_image(placeholder)
	
	container.add_child(texture_rect)
	
	# Quantity badge in bottom-right corner
	if total_count > 0:
		var badge := Label.new()
		badge.text = "x%d" % total_count
		badge.add_theme_font_size_override("font_size", 20)
		badge.add_theme_color_override("font_color", Color.WHITE)
		badge.add_theme_color_override("font_outline_color", Color.BLACK)
		badge.add_theme_constant_override("outline_size", 3)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		badge.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		badge.position = Vector2(FISH_DISPLAY_SIZE.x - 50, FISH_DISPLAY_SIZE.y - 30)
		badge.size = Vector2(45, 25)
		container.add_child(badge)
	
	# Fish name below image
	var name_label := Label.new()
	name_label.text = fish_name
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	name_label.add_theme_constant_override("outline_size", 2)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.position = Vector2(0, FISH_DISPLAY_SIZE.y - 5)
	name_label.size = Vector2(FISH_DISPLAY_SIZE.x, 20)
	container.add_child(name_label)
	
	# Make clickable for quality popup
	var click_area := Button.new()
	click_area.flat = true
	click_area.position = Vector2.ZERO
	click_area.size = FISH_DISPLAY_SIZE
	click_area.mouse_filter = Control.MOUSE_FILTER_STOP
	click_area.pressed.connect(_show_quality_popup.bind(fish_data, qualities, container))
	click_area.mouse_entered.connect(_on_fish_hover.bind(container))
	click_area.mouse_exited.connect(_on_fish_unhover.bind(container))
	container.add_child(click_area)
	
	return container


func _on_fish_hover(container: Control) -> void:
	# Slight scale up on hover
	var tween := create_tween()
	tween.tween_property(container, "scale", Vector2(1.05, 1.05), 0.1)
	AudioManager.play_ui_select()


func _on_fish_unhover(container: Control) -> void:
	var tween := create_tween()
	tween.tween_property(container, "scale", Vector2.ONE, 0.1)


func _show_quality_popup(fish_data: FishData, qualities: Dictionary, source_control: Control) -> void:
	AudioManager.play_ui_confirm()
	
	# Create or update popup
	if quality_popup == null:
		quality_popup = Panel.new()
		quality_popup.name = "QualityPopup"
		add_child(quality_popup)
	
	# Clear existing content
	for child in quality_popup.get_children():
		child.queue_free()
	
	# Style the popup
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.2, 0.95)
	style.border_color = Color(0.4, 0.4, 0.5)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(15)
	quality_popup.add_theme_stylebox_override("panel", style)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	quality_popup.add_child(vbox)
	
	# Title
	var title := Label.new()
	title.text = fish_data.fish_name + " Quality"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	# Separator
	var sep := HSeparator.new()
	vbox.add_child(sep)
	
	# Quality breakdown
	var total_value: int = 0
	for quality_name in QUALITY_NAMES:
		if qualities.has(quality_name):
			var count: int = qualities[quality_name]
			var quality_info := fish_data.calculate_quality(_quality_to_line(quality_name), 0)
			var value_each: int = quality_info.cowrie_value
			var subtotal: int = value_each * count
			total_value += subtotal
			
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			
			var quality_label := Label.new()
			quality_label.text = "%dx %s" % [count, quality_name]
			quality_label.add_theme_font_size_override("font_size", 14)
			quality_label.add_theme_color_override("font_color", QUALITY_COLORS.get(quality_name, Color.WHITE))
			quality_label.custom_minimum_size.x = 120
			row.add_child(quality_label)
			
			var value_label := Label.new()
			value_label.text = "(%d each = %d)" % [value_each, subtotal]
			value_label.add_theme_font_size_override("font_size", 12)
			value_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
			row.add_child(value_label)
			
			vbox.add_child(row)
	
	# Total
	var sep2 := HSeparator.new()
	vbox.add_child(sep2)
	
	var total_label := Label.new()
	total_label.text = "Total: %d" % total_value
	total_label.add_theme_font_size_override("font_size", 16)
	total_label.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6))
	total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(total_label)
	
	# Close hint
	var hint := Label.new()
	hint.text = "(click anywhere to close)"
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hint)
	
	# Position popup near the clicked fish
	quality_popup.size = Vector2(250, 0)  # Auto height
	await get_tree().process_frame
	
	var popup_pos := source_control.global_position + Vector2(FISH_DISPLAY_SIZE.x + 10, 0)
	# Keep on screen
	if popup_pos.x + quality_popup.size.x > get_viewport_rect().size.x - 20:
		popup_pos.x = source_control.global_position.x - quality_popup.size.x - 10
	if popup_pos.y + quality_popup.size.y > get_viewport_rect().size.y - 20:
		popup_pos.y = get_viewport_rect().size.y - quality_popup.size.y - 20
	
	quality_popup.global_position = popup_pos
	quality_popup.visible = true


func _quality_to_line(quality_name: String) -> int:
	# Approximate LINE value for quality
	match quality_name:
		"Pristine": return 3
		"Fresh": return 2
		"Mediocre": return 1
		"Poor": return 0
		"Ruined": return -1
		_: return 1


func _input(event: InputEvent) -> void:
	if visible and quality_popup and quality_popup.visible:
		if event is InputEventMouseButton and event.pressed:
			quality_popup.visible = false
			get_viewport().set_input_as_handled()
			return
	
	if visible and event.is_action_pressed("ui_cancel"):
		_on_close()
		get_viewport().set_input_as_handled()


func _create_card_display(card_data: CardData) -> Control:
	if not CARD_SCENE:
		# Fallback to simple panel
		return _create_card_panel_fallback(card_data)
	
	# Create container for the card - larger size for better visibility
	var container := VBoxContainer.new()
	container.custom_minimum_size = Vector2(220, 310)  # Larger cards
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	
	# Create a CenterContainer to hold the card
	var card_holder := CenterContainer.new()
	card_holder.custom_minimum_size = Vector2(220, 300)
	container.add_child(card_holder)
	
	# Create SubViewport to properly render Node2D card at scaled size
	var viewport := SubViewport.new()
	viewport.size = Vector2i(220, 300)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	
	# Create the card display using the scene - scaled to fit nicely
	var card_display: Node2D = CARD_SCENE.instantiate()
	# Scale to 0.8 for larger display
	card_display.scale = Vector2(0.8, 0.8)
	# Card origin is at center, so position it at viewport center
	card_display.position = Vector2(110, 150)  # Center of 220x300 viewport
	viewport.add_child(card_display)
	
	# Wrap viewport in container
	var viewport_container := SubViewportContainer.new()
	viewport_container.custom_minimum_size = Vector2(220, 300)
	viewport_container.stretch = true
	viewport_container.add_child(viewport)
	card_holder.add_child(viewport_container)
	
	# Setup the card with data
	_setup_card_display(card_display, card_data)
	
	return container


func _setup_card_display(card_display: Node, card_data: CardData) -> void:
	if card_display.has_method("setup"):
		card_display.setup(card_data)
		return
	
	# Manual setup
	_setup_card_manually(card_display, card_data)


func _setup_card_manually(card: Node, card_data: CardData) -> void:
	var fish_name_node = card.get_node_or_null("FishName")
	var fish_name_node_2 = card.get_node_or_null("FishName2")
	var hook_node = card.get_node_or_null("Hook")
	var line_node = card.get_node_or_null("Line")
	var bait_node = card.get_node_or_null("Bait")
	var sinker_node = card.get_node_or_null("Sinker")
	var sinker_desc_node = card.get_node_or_null("SinkerDesc")
	
	var has_bait: bool = card_data.bait_cost > 0
	var has_sinker: bool = card_data.sinker != "None" and card_data.sinker != ""
	
	# Set name - use FishName if has bait, FishName2 otherwise
	if fish_name_node:
		fish_name_node.visible = has_bait
		if has_bait:
			fish_name_node.text = card_data.card_name
	if fish_name_node_2:
		fish_name_node_2.visible = not has_bait
		if not has_bait:
			fish_name_node_2.text = card_data.card_name
	
	if hook_node:
		hook_node.text = str(card_data.hook)
	if line_node:
		line_node.text = str(card_data.line)
	if bait_node:
		bait_node.text = str(card_data.bait_cost)
		bait_node.visible = has_bait
	if sinker_node:
		sinker_node.text = card_data.sinker if has_sinker else ""
		sinker_node.visible = has_sinker
	if sinker_desc_node:
		sinker_desc_node.visible = has_sinker
		if has_sinker and CardDatabase:
			sinker_desc_node.text = CardDatabase.get_sinker_description_dynamic(card_data.sinker, card_data.sinker_power)


func _create_card_panel_fallback(card: CardData) -> Panel:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(120, 160)
	
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)
	
	# Name
	var name_lbl := Label.new()
	name_lbl.text = card.card_name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 12)
	vbox.add_child(name_lbl)
	
	# Stats
	var stats_lbl := Label.new()
	stats_lbl.text = "H:%d L:%d" % [card.hook, card.line]
	if card.bait_cost > 0:
		stats_lbl.text += " B:%d" % card.bait_cost
	stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_lbl.add_theme_font_size_override("font_size", 11)
	vbox.add_child(stats_lbl)
	
	# Sinker
	if card.sinker != "None" and card.sinker != "":
		var sinker_lbl := Label.new()
		sinker_lbl.text = "[%s]" % card.sinker
		sinker_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sinker_lbl.add_theme_font_size_override("font_size", 10)
		sinker_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
		vbox.add_child(sinker_lbl)
	
	return panel


func _get_rarity_color(rarity: String) -> Color:
	match rarity:
		"common": return Color(0.5, 0.5, 0.5)
		"uncommon": return Color(0.3, 0.6, 0.3)
		"rare": return Color(0.3, 0.3, 0.7)
		"elite": return Color(0.7, 0.5, 0.2)
		_: return Color(0.4, 0.4, 0.4)


func _on_close() -> void:
	if quality_popup:
		quality_popup.visible = false
	AudioManager.play_close_inventory()
	visible = false
	closed.emit()
