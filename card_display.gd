extends Node2D
class_name CardDisplay
## Visual card display - populates the card layout with CardData or FishData
## Updated to work with the new flat node hierarchy in card_layout.tscn

signal card_clicked(card_data: CardData)
signal card_right_clicked(card_data: CardData)

# Node references - direct children of CardDisplay
var card_shadow: TextureRect
var back: TextureRect
var back_cowries: TextureRect
var fish_image_background: TextureRect
var fish_image_background_effect: ColorRect
var front: TextureRect
var front_cowries: TextureRect
var front_gold: TextureRect
var fish_shadow: TextureRect
var fish_image: TextureRect
var fish_name_label: Label
var fish_name_label_2: Label
var bait_label: Label
var hook_label: Label
var line_label: Label
var sinker_label: Label
var sinker_desc_label: Label

# Card textures for different configurations
var tex_card_bait_sinker: Texture2D
var tex_card_bait_sinker_cowries: Texture2D
var tex_card_bait_nosinker: Texture2D
var tex_card_bait_nosinker_cowries: Texture2D
var tex_card_nobait_sinker: Texture2D
var tex_card_nobait_sinker_cowries: Texture2D
var tex_card_nobait_nosinker: Texture2D
var tex_card_nobait_nosinker_cowries: Texture2D

# Gold textures for different configurations
var tex_card_bait_sinker_gold: Texture2D
var tex_card_bait_nosinker_gold: Texture2D
var tex_card_nobait_sinker_gold: Texture2D
var tex_card_nobait_nosinker_gold: Texture2D

# Back textures
var tex_back_chum: Texture2D
var tex_back_chum_cowries: Texture2D
var tex_back_salvage: Texture2D
var tex_back_salvage_cowries: Texture2D

var card_data: CardData
var fish_data: FishData
var current_line: int = 0  # For battle display
var is_face_up: bool = true
var is_selectable: bool = true
var is_selected: bool = false
var nodes_cached: bool = false
var is_fish_card: bool = false  # Track if this is a fish or salvage card

# Placeholder texture for missing images
var placeholder_texture: Texture2D

# Original font sizes for scaling
var sinker_original_font_size: int = 24
var sinker_desc_original_font_size: int = 16
var fish_name_original_font_size: int = 31


func _ready() -> void:
	# Create placeholder texture
	var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.3, 0.3, 0.4, 1.0))
	placeholder_texture = ImageTexture.create_from_image(img)
	
	_load_card_textures()
	_cache_nodes()


func _load_card_textures() -> void:
	# Front card textures - different combinations of bait and sinker
	tex_card_bait_sinker = _try_load_texture("res://assets/cards/cardbaitsinker.png")
	tex_card_bait_sinker_cowries = _try_load_texture("res://assets/cards/cardbaitsinkercowries.png")
	tex_card_bait_nosinker = _try_load_texture("res://assets/cards/cardbaitnosinker.png")
	tex_card_bait_nosinker_cowries = _try_load_texture("res://assets/cards/cardbaitnosinkercowries.png")
	tex_card_nobait_sinker = _try_load_texture("res://assets/cards/cardnobaitsinker.png")
	tex_card_nobait_sinker_cowries = _try_load_texture("res://assets/cards/cardnobaitsinkercowries.png")
	tex_card_nobait_nosinker = _try_load_texture("res://assets/cards/cardnobaitnosinker.png")
	tex_card_nobait_nosinker_cowries = _try_load_texture("res://assets/cards/cardnobaitnosinkercowries.png")
	
	# Gold card textures
	tex_card_bait_sinker_gold = _try_load_texture("res://assets/cards/cardbaitsinkergold.png")
	tex_card_bait_nosinker_gold = _try_load_texture("res://assets/cards/cardbaitnosinkergold.png")
	tex_card_nobait_sinker_gold = _try_load_texture("res://assets/cards/cardnobaitsinkergold.png")
	tex_card_nobait_nosinker_gold = _try_load_texture("res://assets/cards/cardnobaitnosinkergold.png")
	
	# Back card textures
	tex_back_chum = _try_load_texture("res://assets/cards/cardbackchum.png")
	tex_back_chum_cowries = _try_load_texture("res://assets/cards/cardbackchumcowries.png")
	tex_back_salvage = _try_load_texture("res://assets/cards/cardbacksalvage.png")
	tex_back_salvage_cowries = _try_load_texture("res://assets/cards/cardbacksalvagecowries.png")


func _try_load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	return null


func _cache_nodes() -> void:
	# Cache nodes if not already cached, or if the cached nodes are no longer valid
	if nodes_cached:
		# Verify nodes are still valid
		if front == null or not is_instance_valid(front):
			nodes_cached = false
		else:
			return
	
	# All nodes are direct children of CardDisplay in the new layout
	card_shadow = get_node_or_null("CardShadow")
	back = get_node_or_null("Back")
	back_cowries = get_node_or_null("Back/Backcowries")
	fish_image_background = get_node_or_null("FishImageBackground")
	fish_image_background_effect = get_node_or_null("FishImageBackground/FishImageBackgroundEffect")
	front = get_node_or_null("Front")
	front_cowries = get_node_or_null("Front/Frontcowries")
	front_gold = get_node_or_null("Front/FrontGold")
	fish_shadow = get_node_or_null("FishShadow")
	fish_image = get_node_or_null("FishImage")
	fish_name_label = get_node_or_null("FishName")
	fish_name_label_2 = get_node_or_null("FishName2")
	bait_label = get_node_or_null("Bait")
	hook_label = get_node_or_null("Hook")
	line_label = get_node_or_null("Line")
	sinker_label = get_node_or_null("Sinker")
	sinker_desc_label = get_node_or_null("SinkerDesc")
	
	# Store original font sizes for scaling
	if sinker_label:
		sinker_original_font_size = sinker_label.get_theme_font_size("font_size")
	if sinker_desc_label:
		sinker_desc_original_font_size = sinker_desc_label.get_theme_font_size("font_size")
	if fish_name_label:
		fish_name_original_font_size = fish_name_label.get_theme_font_size("font_size")
	
	nodes_cached = true


## Helper to get the correct front texture path based on bait and sinker
func _get_front_texture(has_bait: bool, has_sinker: bool, is_gold: bool = false) -> Texture2D:
	if is_gold:
		if has_bait and has_sinker:
			return tex_card_bait_sinker_gold
		elif has_bait and not has_sinker:
			return tex_card_bait_nosinker_gold
		elif not has_bait and has_sinker:
			return tex_card_nobait_sinker_gold
		else:
			return tex_card_nobait_nosinker_gold
	else:
		if has_bait and has_sinker:
			return tex_card_bait_sinker
		elif has_bait and not has_sinker:
			return tex_card_bait_nosinker
		elif not has_bait and has_sinker:
			return tex_card_nobait_sinker
		else:
			return tex_card_nobait_nosinker


## Helper to update front textures on the card including gold overlay
func _update_front_textures(has_bait: bool, has_sinker: bool) -> void:
	if front:
		var front_tex := _get_front_texture(has_bait, has_sinker, false)
		if front_tex:
			front.texture = front_tex
	
	if front_gold:
		var gold_tex := _get_front_texture(has_bait, has_sinker, true)
		if gold_tex:
			front_gold.texture = gold_tex


## Set up the card display from CardData (Salvage/Player cards)
func setup(data: CardData, battle_line: int = -1) -> void:
	card_data = data
	fish_data = null
	is_fish_card = false
	current_line = battle_line if battle_line >= 0 else data.line
	
	# Ensure textures are loaded (in case setup is called before _ready)
	if tex_card_bait_sinker == null:
		_load_card_textures()
	
	_cache_nodes()
	_update_display()


## Set up the card display from FishData (Fish/Enemy cards)
func setup_fish(data: FishData, battle_line: int = -1) -> void:
	fish_data = data
	card_data = null
	is_fish_card = true
	current_line = battle_line if battle_line >= 0 else data.line
	
	# Ensure textures are loaded (in case setup is called before _ready)
	if tex_card_bait_sinker == null:
		_load_card_textures()
	
	_cache_nodes()
	_update_display()


## Set up from dictionary (for hand display)
func setup_from_dict(data: Dictionary) -> void:
	var cd := CardData.new()
	cd.card_name = data.get("name", "Unknown")
	cd.hook = int(data.get("hook", 0))
	cd.line = int(data.get("line", 0))
	cd.sinker = str(data.get("sinker", "None"))
	cd.sinker_power = int(data.get("sinker_power", 0))
	cd.bait_cost = int(data.get("bait_cost", 0))
	cd.card_type = data.get("card_type", "Salvage")
	setup(cd)


## Update the visual display
func _update_display() -> void:
	_cache_nodes()
	
	var card_name: String
	var hook_value: int
	var line_value: int
	var max_line: int
	var sinker_name: String
	var sinker_power: int
	var bait_cost: int
	var card_type: String
	var image_path: String = ""
	
	# Get values from either card_data or fish_data
	if card_data != null:
		card_name = card_data.card_name
		hook_value = card_data.hook
		line_value = current_line
		max_line = card_data.line
		sinker_name = card_data.sinker
		sinker_power = card_data.sinker_power
		bait_cost = card_data.bait_cost
		card_type = card_data.card_type
		
		# Try to get image from card database
		var db_data: Dictionary = CardDatabase.get_card(card_name)
		if not db_data.is_empty() and db_data.has("image_path"):
			image_path = db_data.image_path
	elif fish_data != null:
		card_name = fish_data.fish_name
		hook_value = fish_data.hook
		line_value = current_line
		max_line = fish_data.line
		sinker_name = fish_data.sinker
		sinker_power = fish_data.sinker_power
		bait_cost = 0  # Fish don't have bait cost
		card_type = "Chum"  # Fish use chum back
		
		# Try to get image from fish database
		var db_data: Dictionary = FishDatabase.get_fish(card_name)
		if not db_data.is_empty() and db_data.has("image_path"):
			image_path = db_data.image_path
	else:
		return
	
	var has_bait: bool = bait_cost > 0
	var has_sinker: bool = sinker_name != "None" and sinker_name != ""
	
	# Update Front texture based on bait/sinker
	_update_front_texture(has_bait, has_sinker)
	
	# Update Back texture based on card type
	_update_back_texture(card_type)
	
	# Update fish image
	_update_fish_image(image_path)
	
	# Update name labels - use FishName if has bait, FishName2 if no bait
	_update_name_labels(card_name, has_bait)
	
	# Update bait cost
	if bait_label:
		if has_bait:
			bait_label.visible = true
			bait_label.text = str(bait_cost)
		else:
			bait_label.visible = false
	
	# Update Hook
	if hook_label:
		hook_label.text = str(hook_value)
	
	# Update Line - show only current health, not max
	if line_label:
		line_label.text = str(line_value)
		# Color code low health, default to dark blue
		var default_color := Color(0, 0.043137256, 0.18039216, 1)  # Dark blue from card layout
		if line_value < max_line:
			if line_value <= 1:
				line_label.add_theme_color_override("font_color", Color.RED)
			elif line_value <= max_line / 2:
				line_label.add_theme_color_override("font_color", Color.YELLOW)
			else:
				line_label.add_theme_color_override("font_color", default_color)
		else:
			line_label.add_theme_color_override("font_color", default_color)
	
	# Update Sinker label with auto-scaling
	_update_sinker_label(sinker_name, has_sinker)
	
	# Update Sinker description with auto-scaling
	_update_sinker_desc(sinker_name, sinker_power, has_sinker)
	
	# Face up/down visibility
	_update_face_visibility()


func _update_front_texture(has_bait: bool, has_sinker: bool) -> void:
	if not front:
		return
	
	var main_tex: Texture2D = null
	var cowries_tex: Texture2D = null
	var gold_tex: Texture2D = null
	
	if has_bait and has_sinker:
		main_tex = tex_card_bait_sinker
		cowries_tex = tex_card_bait_sinker_cowries
		gold_tex = tex_card_bait_sinker_gold
	elif has_bait and not has_sinker:
		main_tex = tex_card_bait_nosinker
		cowries_tex = tex_card_bait_nosinker_cowries
		gold_tex = tex_card_bait_nosinker_gold
	elif not has_bait and has_sinker:
		main_tex = tex_card_nobait_sinker
		cowries_tex = tex_card_nobait_sinker_cowries
		gold_tex = tex_card_nobait_sinker_gold
	else:  # no bait, no sinker
		main_tex = tex_card_nobait_nosinker
		cowries_tex = tex_card_nobait_nosinker_cowries
		gold_tex = tex_card_nobait_nosinker_gold
	
	if main_tex:
		front.texture = main_tex
	if front_cowries and cowries_tex:
		front_cowries.texture = cowries_tex
	if front_gold and gold_tex:
		front_gold.texture = gold_tex


func _update_back_texture(card_type: String) -> void:
	if not back:
		return
	
	var is_chum: bool = card_type == "Chum" or is_fish_card
	
	if is_chum:
		if tex_back_chum:
			back.texture = tex_back_chum
		if back_cowries and tex_back_chum_cowries:
			back_cowries.texture = tex_back_chum_cowries
	else:  # Salvage
		if tex_back_salvage:
			back.texture = tex_back_salvage
		if back_cowries and tex_back_salvage_cowries:
			back_cowries.texture = tex_back_salvage_cowries


func _update_fish_image(image_path: String) -> void:
	if not fish_image:
		return
	
	var tex: Texture2D = null
	if not image_path.is_empty():
		tex = _try_load_texture(image_path)
	
	if tex:
		fish_image.texture = tex
		fish_image.visible = true
		if fish_shadow:
			fish_shadow.texture = tex
			fish_shadow.visible = true
	else:
		# No image available - hide the image area instead of showing placeholder
		fish_image.texture = null
		fish_image.visible = false
		if fish_shadow:
			fish_shadow.texture = null
			fish_shadow.visible = false


func _update_name_labels(card_name: String, has_bait: bool) -> void:
	# FishName is used when there's bait cost, FishName2 when there's none
	if fish_name_label and fish_name_label_2:
		if has_bait:
			fish_name_label.visible = true
			fish_name_label_2.visible = false
			_set_label_with_auto_scale(fish_name_label, card_name, fish_name_original_font_size)
		else:
			fish_name_label.visible = false
			fish_name_label_2.visible = true
			_set_label_with_auto_scale(fish_name_label_2, card_name, fish_name_original_font_size)
	elif fish_name_label:
		_set_label_with_auto_scale(fish_name_label, card_name, fish_name_original_font_size)
	elif fish_name_label_2:
		_set_label_with_auto_scale(fish_name_label_2, card_name, fish_name_original_font_size)


func _update_sinker_label(sinker_name: String, has_sinker: bool) -> void:
	if not sinker_label:
		return
	
	if has_sinker:
		sinker_label.visible = true
		# Replace underscores with spaces for display
		var display_name := sinker_name.replace("_", " ")
		_set_label_with_auto_scale(sinker_label, display_name, sinker_original_font_size)
	else:
		sinker_label.visible = false


func _update_sinker_desc(sinker_name: String, sinker_power: int, has_sinker: bool) -> void:
	if not sinker_desc_label:
		return
	
	if has_sinker:
		sinker_desc_label.visible = true
		var desc: String = ""
		
		# Use dynamic description that includes actual power values
		if is_fish_card:
			desc = FishDatabase.get_sinker_description_dynamic(sinker_name, sinker_power)
		else:
			desc = CardDatabase.get_sinker_description_dynamic(sinker_name, sinker_power)
		
		if desc.is_empty():
			desc = sinker_name
		
		_set_label_with_auto_scale(sinker_desc_label, desc, sinker_desc_original_font_size)
	else:
		sinker_desc_label.visible = false


## Set label text with auto-scaling if text is too big
## For sinker descriptions, enables word wrap first, then shrinks if still too big
func _set_label_with_auto_scale(label: Label, text: String, original_size: int) -> void:
	label.text = text
	
	# Reset to original size first
	label.add_theme_font_size_override("font_size", original_size)
	
	# Enable autowrap for multiline support
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	# Check if text overflows the label bounds
	var font: Font = label.get_theme_font("font")
	var current_size: int = original_size
	var min_size: int = max(8, original_size / 3)  # Don't go below 1/3 original or 8pt
	
	var label_width: float = label.size.x
	if label_width <= 0:
		# Estimate from offset if size not available
		label_width = abs(label.offset_right - label.offset_left)
	
	var label_height: float = label.size.y
	if label_height <= 0:
		label_height = abs(label.offset_bottom - label.offset_top)
	
	# Calculate if text fits with wrapping
	# Scale down if wrapped text exceeds height
	while current_size > min_size:
		var line_height: float = font.get_height(current_size)
		var text_width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, current_size).x
		
		# Estimate number of lines needed
		var lines_needed: int = ceili(text_width / label_width) if label_width > 0 else 1
		var total_height: float = lines_needed * line_height
		
		if total_height <= label_height:
			break
		
		current_size -= 1
		label.add_theme_font_size_override("font_size", current_size)


func _update_face_visibility() -> void:
	# Back elements - visible when face down
	if back:
		back.visible = not is_face_up
	
	# Front elements - visible when face up
	if front:
		front.visible = is_face_up
	
	# FishImageBackground should be visible when face up
	if fish_image_background:
		fish_image_background.visible = is_face_up
	
	# FishImageBackgroundEffect should also be visible when face up
	if fish_image_background_effect:
		fish_image_background_effect.visible = is_face_up
	
	# Other front elements - visible when face up, preserve individual visibility rules
	var front_elements := [fish_image, fish_shadow, 
						   fish_name_label, fish_name_label_2, bait_label, hook_label, 
						   line_label, sinker_label, sinker_desc_label]
	
	for element in front_elements:
		if element:
			# Only set visibility if face up - don't override hidden elements
			if is_face_up:
				pass  # Let individual visibility rules apply
			else:
				element.visible = false
	
	# Card shadow should always be visible (not affected by face up/down)
	if card_shadow:
		card_shadow.visible = true


## Flip the card face up or down
func set_face_up(face_up: bool) -> void:
	is_face_up = face_up
	_update_face_visibility()


## Update line during battle (for damage display)
func update_battle_line(new_line: int) -> void:
	current_line = new_line
	
	var max_line: int = 0
	if card_data:
		max_line = card_data.line
	elif fish_data:
		max_line = fish_data.line
	
	if not line_label:
		return
	
	# Only show current health, not max
	line_label.text = str(current_line)
	
	# Color code low health, default to dark blue
	var default_color := Color(0, 0.043137256, 0.18039216, 1)  # Dark blue from card layout
	if current_line < max_line:
		if current_line <= 1:
			line_label.add_theme_color_override("font_color", Color.RED)
		elif current_line <= max_line / 2:
			line_label.add_theme_color_override("font_color", Color.YELLOW)
		else:
			line_label.add_theme_color_override("font_color", default_color)
	else:
		line_label.add_theme_color_override("font_color", default_color)


## Set selected visual state
func set_selected(selected: bool) -> void:
	is_selected = selected
	if selected:
		modulate = Color(1.2, 1.2, 0.8)  # Slight yellow highlight
		scale = Vector2(1.05, 1.05)
	else:
		modulate = Color.WHITE
		scale = Vector2.ONE


## Set whether card can be interacted with
func set_selectable(selectable: bool) -> void:
	is_selectable = selectable
	if not selectable:
		modulate = Color(0.6, 0.6, 0.6)  # Greyed out
	else:
		modulate = Color.WHITE


## Get the card size for layout purposes
func get_card_size() -> Vector2:
	if front:
		return front.size * front.scale
	return Vector2(246, 342)  # Default card size (41 * 6, 57 * 6)
