extends Control
## Battle Board UI - Enhanced with hover effects, smart hand animations, and attack visuals

@onready var battle_manager = $BattleManager
@onready var catch_minigame: Control = $CatchMinigame
@onready var opponents_hbox: HBoxContainer = $CardsInPlay/CardsVBoxContainer/Opponents
@onready var home_cards_hbox: HBoxContainer = $CardsInPlay/CardsVBoxContainer/HomeCards
@onready var hand_hbox: HBoxContainer = $CardHandContainer/"Card Hand"

# --- NEW NODE REFERENCES ---
# We use get_node_or_null or find_child to locate your new buttons/labels
@onready var salvage_node = $Options/OptionsVBoxContainer/Decks/Salvage
@onready var chum_node = $Options/OptionsVBoxContainer/Decks/Chum
@onready var area_label: Label = $Label

# Search for the new buttons by name, falling back to path if needed
@onready var hook_button: TextureButton = find_child("HookButton", true, false)
@onready var end_turn_button: TextureButton = find_child("EndTurnButton", true, false)

# Search for the new HUD labels
@onready var turn_number_label: Label = find_child("TurnNumber", true, false)
@onready var health_number_label: Label = find_child("HealthNumber", true, false)
@onready var bait_number_label: Label = find_child("BaitNumber", true, false)
@onready var line_strength_label: Label = find_child("LineStrength", true, false)

var _hook_label_base_y: float = 0.0
var _end_turn_label_base_y: float = 0.0

# Button sub-labels (assigned in _ready)
var hook_button_label: Label
var end_turn_button_label: Label

# Textures for button states
var btn_tex_normal: Texture2D
var btn_tex_hover: Texture2D
var btn_tex_click: Texture2D

var CARD_SCENE: PackedScene
var fish_cards: Array = []
var board_cards: Array = []
var hand_cards: Array = []
var fish_slot_map: Dictionary = {}
var board_slot_map: Dictionary = {}
var selected_hand_index: int = -1
var hook_mode: bool = false

# Incoming fish indicators
var incoming_fish_indicators: Dictionary = {}  # slot -> indicator node
var incoming_fish_font: Font

const CARD_W := 254.0
const CARD_H := 348.0
const HAND_HOVER_LIFT := 50.0
const HAND_BASE_Y := 80.0  # Higher up from bottom
const CARD_SPACING_HAND := -120.0  # More overlap for realistic hand
const CARD_SPACING_BOARD := 20.0
const HAND_MAX_ROTATION := 12.0  # Max rotation in degrees for outer cards

# Colors
const COL_KELP_GREEN := Color(0.30, 0.55, 0.34) # Aquatic Kelp Green
const COL_DISABLED := Color(0.5, 0.5, 0.5)
const COL_NORMAL := Color.WHITE

var combat_text_layer: CanvasLayer
var idle_tween_map: Dictionary = {}
var hover_tween_map: Dictionary = {}
var _previous_hand_size: int = 0
var _hovered_hand_index: int = -1

# Card placement preview
var _placement_preview_slot: int = -1
var _placement_ghost: Node = null

# Input tracking
var _last_mouse_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	# Load Resources (Keep your existing resource loading code here if needed)
	for path in ["res://scenes/roguelike/card layout.tscn", "res://scenes/menus/card layout.tscn"]:
		if ResourceLoader.exists(path):
			CARD_SCENE = load(path)
			break
	
	if ResourceLoader.exists("res://menu/font/BoldPixels.otf"):
		incoming_fish_font = load("res://menu/font/BoldPixels.otf")
		
	# Load Button Textures
	if ResourceLoader.exists("res://assets/ui/UI_NoteBook_Button01a.png"):
		btn_tex_normal = load("res://assets/ui/UI_NoteBook_Button01a.png")
	if ResourceLoader.exists("res://assets/ui/UI_NoteBook_Button01b.png"):
		btn_tex_hover = load("res://assets/ui/UI_NoteBook_Button01b.png")
	if ResourceLoader.exists("res://assets/ui/UI_NoteBook_Button01c.png"):
		btn_tex_click = load("res://assets/ui/UI_NoteBook_Button01c.png")

	# Clear Containers
	if opponents_hbox: for child in opponents_hbox.get_children(): child.queue_free()
	if home_cards_hbox: for child in home_cards_hbox.get_children(): child.queue_free()
	if hand_hbox: for child in hand_hbox.get_children(): child.queue_free()
		
	if opponents_hbox: opponents_hbox.add_theme_constant_override("separation", 20)
	if home_cards_hbox: home_cards_hbox.add_theme_constant_override("separation", 20)
	if hand_hbox: hand_hbox.add_theme_constant_override("separation", 15)
	
	_setup_deck_click(salvage_node, true)
	_setup_deck_click(chum_node, false)
	
	if home_cards_hbox:
		home_cards_hbox.mouse_filter = Control.MOUSE_FILTER_STOP
		home_cards_hbox.gui_input.connect(_on_home_area_click)

	# --- NEW BUTTON SETUP ---
	
	# Hook Button
	if hook_button:
		hook_button_label = hook_button.get_node_or_null("HookLabel")
		if hook_button_label:
			# 1. Remember the original Y position from the .tscn (17.0)
			_hook_label_base_y = hook_button_label.position.y
			# 2. Make label ignore mouse so the button underneath catches the click
			hook_button_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			
			_setup_custom_button(hook_button, hook_button_label, _on_hook_pressed, _hook_label_base_y)

	# End Turn Button
	if end_turn_button:
		end_turn_button_label = end_turn_button.get_node_or_null("EndTurnLabel")
		if end_turn_button_label:
			# 1. Remember the original Y position from the .tscn (17.0)
			_end_turn_label_base_y = end_turn_button_label.position.y
			# 2. Make label ignore mouse so the button underneath catches the click
			end_turn_button_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			
			_setup_custom_button(end_turn_button, end_turn_button_label, _on_end_turn_pressed, _end_turn_label_base_y)

	# --- HUD LABELS SETUP (Paths from your .tscn) ---
	turn_number_label = get_node_or_null("MatchInfo/TurnIcon/TurnNumber")
	health_number_label = get_node_or_null("MatchInfo/HealthIcon/HealthNumber")
	bait_number_label = get_node_or_null("MatchInfo/BaitIcon/BaitNumber")
	line_strength_label = get_node_or_null("Options/OptionsVBoxContainer/HookButton/LineStrength")

	# Final Setup
	_setup_combat_text_layer()
	_setup_minigame_layering()
	call_deferred("_connect_signals")
	set_process(true)
	set_process_input(true)

# --- CUSTOM BUTTON LOGIC ---
func _setup_custom_button(btn: TextureButton, lbl: Label, callback: Callable, base_y: float) -> void:
	if not btn: return
	
	# CRITICAL: Mouse Filter must be Ignore so the button underneath gets the signal
	if lbl: lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Set textures
	if btn_tex_normal: btn.texture_normal = btn_tex_normal
	if btn_tex_hover: btn.texture_hover = btn_tex_hover
	if btn_tex_click: btn.texture_pressed = btn_tex_click
	
	# Connect interaction
	if not btn.pressed.is_connected(callback):
		btn.pressed.connect(callback)
	
	# Connect hover/click animations using the stored base_y
	btn.mouse_entered.connect(func(): _animate_button_text(btn, lbl, 5, base_y))
	btn.mouse_exited.connect(func(): _animate_button_text(btn, lbl, 0, base_y))
	btn.button_down.connect(func(): _animate_button_text(btn, lbl, 10, base_y))
	btn.button_up.connect(func(): _animate_button_text(btn, lbl, 5 if btn.is_hovered() else 0, base_y))

func _animate_button_text(btn: TextureButton, lbl: Label, offset: int, base_y: float) -> void:
	if not lbl or not btn: return
	
	# If disabled, stick to original position
	if btn.disabled:
		lbl.position.y = base_y
		return

	# Apply offset to the ORIGINAL position
	lbl.position.y = base_y + offset

# Process for reliable hand card hover detection
func _process(_delta: float) -> void:
	# Safety check - don't process if we're being freed
	if not is_inside_tree():
		return
	
	# Only update hover when mouse has moved to avoid unnecessary computation
	var current_mouse_pos := get_global_mouse_position()
	if current_mouse_pos.distance_squared_to(_last_mouse_pos) > 1.0:
		_last_mouse_pos = current_mouse_pos
		_update_hand_hover()
		_update_placement_preview(current_mouse_pos)

# Input for reliable hand card click detection
func _input(event: InputEvent) -> void:
	# Safety check
	if not is_inside_tree():
		return
	if event is InputEventMouseButton and event.pressed:
		# First try hand card clicks
		if _handle_hand_click(event):
			return
		# Then try board slot clicks (when a hand card is selected)
		if selected_hand_index >= 0 and event.button_index == MOUSE_BUTTON_LEFT:
			_handle_board_slot_click(event)

func _setup_combat_text_layer() -> void:
	combat_text_layer = CanvasLayer.new()
	combat_text_layer.layer = 10
	add_child(combat_text_layer)
	var container := Control.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	combat_text_layer.add_child(container)

func _setup_minigame_layering() -> void:
	if catch_minigame:
		move_child(catch_minigame, get_child_count() - 1)
		catch_minigame.visible = false
		catch_minigame.z_index = 100

func _setup_deck_click(deck_node: Node, is_salvage: bool) -> void:
	if not deck_node: return
	if deck_node is Node2D:
		deck_node.position = Vector2(127, 200) if is_salvage else Vector2(127 + 254 + 30, 200)
	
	# Hide all front-facing elements, show only back
	var front = deck_node.get_node_or_null("Front")
	var back = deck_node.get_node_or_null("Back")
	var back_gold = deck_node.get_node_or_null("Back/BackGold")
	var card_shadow = deck_node.get_node_or_null("CardShadow")
	var fish_image_bg = deck_node.get_node_or_null("FishImageBackground")
	var fish_image = deck_node.get_node_or_null("FishImage")
	var fish_shadow = deck_node.get_node_or_null("FishShadow")
	var fish_name = deck_node.get_node_or_null("FishName")
	var fish_name_2 = deck_node.get_node_or_null("FishName2")
	var bait = deck_node.get_node_or_null("Bait")
	var hook = deck_node.get_node_or_null("Hook")
	var line = deck_node.get_node_or_null("Line")
	var sinker = deck_node.get_node_or_null("Sinker")
	var sinker_desc = deck_node.get_node_or_null("SinkerDesc")
	
	# Hide front elements
	if front: front.visible = false
	if fish_image_bg: fish_image_bg.visible = false
	if fish_image: fish_image.visible = false
	if fish_shadow: fish_shadow.visible = false
	if fish_name: fish_name.visible = false
	if fish_name_2: fish_name_2.visible = false
	if bait: bait.visible = false
	if hook: hook.visible = false
	if line: line.visible = false
	if sinker: sinker.visible = false
	if sinker_desc: sinker_desc.visible = false
	
	# Show back and shadow
	if back: back.visible = true
	if card_shadow: card_shadow.visible = true
	
	# Set the correct back texture based on deck type
	var back_texture_path: String
	var back_gold_texture_path: String
	if is_salvage:
		back_texture_path = "res://assets/cards/cardbacksalvage.png"
		back_gold_texture_path = "res://assets/cards/cardbacksalvagegold.png"
	else:
		back_texture_path = "res://assets/cards/cardbackchum.png"
		back_gold_texture_path = "res://assets/cards/cardbackchumgold.png"
	
	if back and ResourceLoader.exists(back_texture_path):
		back.texture = load(back_texture_path)
	if back_gold and ResourceLoader.exists(back_gold_texture_path):
		back_gold.texture = load(back_gold_texture_path)
	
	# Create stacked deck visual - add extra card backs behind
	_create_deck_stack(deck_node, is_salvage, back_texture_path)
	
	# Setup click handling on the back
	if back and back is Control:
		back.mouse_filter = Control.MOUSE_FILTER_STOP
		if not back.gui_input.is_connected(_deck_clicked):
			back.gui_input.connect(func(e): _deck_clicked(e, is_salvage))
		if not back.mouse_entered.is_connected(_on_deck_hover):
			back.mouse_entered.connect(func(): _on_deck_hover(deck_node, true))
		if not back.mouse_exited.is_connected(_on_deck_hover):
			back.mouse_exited.connect(func(): _on_deck_hover(deck_node, false))

# Store references to deck stack nodes for animation
var salvage_deck_stack: Array = []
var chum_deck_stack: Array = []
var _deck_hover_tween: Dictionary = {}  # Track deck hover tweens
var _hovered_deck: Node = null  # Track which deck is hovered

func _create_deck_stack(deck_node: Node, is_salvage: bool, back_texture_path: String) -> void:
	if not deck_node or not ResourceLoader.exists(back_texture_path):
		return
	
	var back_texture = load(back_texture_path)
	var stack_array = salvage_deck_stack if is_salvage else chum_deck_stack
	
	# Clear existing stack
	for card in stack_array:
		if is_instance_valid(card):
			card.queue_free()
	stack_array.clear()
	
	# Create 3 cards behind the main deck card to show depth
	for i in range(3):
		var stack_card := TextureRect.new()
		stack_card.texture = back_texture
		stack_card.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		# Position slightly offset to create stacked effect
		var offset := (3 - i) * 4  # Cards further back are offset more
		stack_card.position = Vector2(-123 + offset, -170 + offset)
		stack_card.scale = Vector2(6, 6)
		stack_card.modulate = Color(0.85 - i * 0.1, 0.85 - i * 0.1, 0.85 - i * 0.1)  # Slightly darker for depth
		stack_card.z_index = -3 + i  # Behind the main card
		stack_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		deck_node.add_child(stack_card)
		deck_node.move_child(stack_card, 0)  # Move to back
		stack_array.append(stack_card)
	
	if is_salvage:
		salvage_deck_stack = stack_array
	else:
		chum_deck_stack = stack_array

func _on_deck_hover(deck_node: Node, is_hovering: bool) -> void:
	if not deck_node or not deck_node is Node2D:
		return
	
	# Kill existing tween for this deck
	if _deck_hover_tween.has(deck_node):
		var old_tween = _deck_hover_tween[deck_node]
		if old_tween and old_tween.is_valid():
			old_tween.kill()
		_deck_hover_tween.erase(deck_node)
	
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	
	if is_hovering:
		_hovered_deck = deck_node
		# Lift and scale up slightly
		tween.tween_property(deck_node, "position:y", 200.0 - 25.0, 0.15)
		tween.parallel().tween_property(deck_node, "scale", Vector2(1.08, 1.08), 0.15)
	else:
		_hovered_deck = null
		# Return to normal
		tween.tween_property(deck_node, "position:y", 200.0, 0.15)
		tween.parallel().tween_property(deck_node, "scale", Vector2.ONE, 0.15)
	
	_deck_hover_tween[deck_node] = tween

func _deck_clicked(event: InputEvent, is_salvage: bool) -> void:
	if not battle_manager: return
	if not battle_manager.get_script():
		push_error("BattleBoardUI: battle_manager has no script!")
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if battle_manager.has_method("can_draw"):
			if not battle_manager.can_draw():
				return  # Already drew this turn
		# Play card shuffle sound when clicking deck
		AudioManager.play_card_shuffle()
		# Start the animated draw sequence
		_animate_deck_draw(is_salvage)

# Track if we're currently animating a draw
var _is_drawing: bool = false

func _animate_deck_draw(is_salvage: bool) -> void:
	if _is_drawing:
		return
	_is_drawing = true
	
	var deck_node = salvage_node if is_salvage else chum_node
	if not deck_node:
		_is_drawing = false
		return
	
	# Kill any hover tween since we're taking over
	if _deck_hover_tween.has(deck_node):
		var old_tween = _deck_hover_tween[deck_node]
		if old_tween and old_tween.is_valid():
			old_tween.kill()
		_deck_hover_tween.erase(deck_node)
	_hovered_deck = null
	
	# Create a temporary card for the flip animation
	var temp_card: Node = _make_card()
	if not temp_card:
		_is_drawing = false
		return
	
	# Add to the UI layer so it appears above everything
	add_child(temp_card)
	
	# Get deck's current position (may be lifted from hover)
	var deck_global_pos: Vector2 = deck_node.global_position if deck_node is Node2D else Vector2(200, 600)
	temp_card.global_position = deck_global_pos
	temp_card.z_index = 50
	
	# Match deck's current scale if it was hovered
	if deck_node is Node2D:
		temp_card.scale = deck_node.scale
	
	# Setup card to show back initially
	var front = temp_card.get_node_or_null("Front")
	var back = temp_card.get_node_or_null("Back")
	var fish_image_bg = temp_card.get_node_or_null("FishImageBackground")
	var fish_image = temp_card.get_node_or_null("FishImage")
	var fish_shadow = temp_card.get_node_or_null("FishShadow")
	var fish_name = temp_card.get_node_or_null("FishName")
	var fish_name_2 = temp_card.get_node_or_null("FishName2")
	var bait_lbl = temp_card.get_node_or_null("Bait")
	var hook_lbl = temp_card.get_node_or_null("Hook")
	var line_lbl = temp_card.get_node_or_null("Line")
	var sinker_lbl = temp_card.get_node_or_null("Sinker")
	var sinker_desc = temp_card.get_node_or_null("SinkerDesc")
	var card_shadow = temp_card.get_node_or_null("CardShadow")
	
	# Hide all front elements initially
	if front: front.visible = false
	if fish_image_bg: fish_image_bg.visible = false
	if fish_image: fish_image.visible = false
	if fish_shadow: fish_shadow.visible = false
	if fish_name: fish_name.visible = false
	if fish_name_2: fish_name_2.visible = false
	if bait_lbl: bait_lbl.visible = false
	if hook_lbl: hook_lbl.visible = false
	if line_lbl: line_lbl.visible = false
	if sinker_lbl: sinker_lbl.visible = false
	if sinker_desc: sinker_desc.visible = false
	if card_shadow: card_shadow.visible = false  # Hide shadow during flip
	
	# Show back with correct texture
	if back:
		back.visible = true
		var back_texture_path: String
		var back_gold_texture_path: String
		if is_salvage:
			back_texture_path = "res://assets/cards/cardbacksalvage.png"
			back_gold_texture_path = "res://assets/cards/cardbacksalvagegold.png"
		else:
			back_texture_path = "res://assets/cards/cardbackchum.png"
			back_gold_texture_path = "res://assets/cards/cardbackchumgold.png"
		
		# Force load and set textures immediately
		if ResourceLoader.exists(back_texture_path):
			var tex = load(back_texture_path)
			back.texture = tex
		
		var back_gold = temp_card.get_node_or_null("Back/BackGold")
		if back_gold:
			if ResourceLoader.exists(back_gold_texture_path):
				back_gold.texture = load(back_gold_texture_path)
			else:
				back_gold.visible = false
	
	# Animate: lift up, flip (scale X to 0), then reveal front
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	
	# Phase 1: Lift up and move slightly
	tween.tween_property(temp_card, "position:y", deck_global_pos.y - 80, 0.2)
	tween.parallel().tween_property(temp_card, "scale", Vector2(1.1, 1.1), 0.2)
	
	# Phase 2: Flip - scale X to 0
	tween.tween_property(temp_card, "scale:x", 0.0, 0.15).set_trans(Tween.TRANS_SINE)
	
	# At midpoint, play flip sound and draw the card
	tween.tween_callback(func():
		AudioManager.play_card_flip()
		# Actually draw from deck
		if is_salvage:
			if battle_manager.has_method("draw_from_salvage"):
				battle_manager.draw_from_salvage()
		else:
			if battle_manager.has_method("draw_from_chum"):
				battle_manager.draw_from_chum()
		
		# Now setup the card to show what was drawn
		if battle_manager.hand.size() > 0:
			var drawn_card: CardData = battle_manager.hand[battle_manager.hand.size() - 1]
			if drawn_card:
				var has_bait: bool = drawn_card.bait_cost > 0
				var has_sinker: bool = drawn_card.sinker != "None" and drawn_card.sinker != ""
				
				# Update front texture based on bait/sinker
				_update_front_texture(temp_card, has_bait, has_sinker)
				
				# Show front elements
				if front: front.visible = true
				if back: back.visible = false
				# IMPORTANT: Show FishImageBackground and effect
				if fish_image_bg: fish_image_bg.visible = true
				var fish_image_bg_effect = temp_card.get_node_or_null("FishImageBackground/FishImageBackgroundEffect")
				if fish_image_bg_effect: fish_image_bg_effect.visible = true
				if fish_image: 
					fish_image.visible = true
					if drawn_card.texture:
						fish_image.texture = drawn_card.texture
				if fish_shadow:
					fish_shadow.visible = true
					if drawn_card.texture:
						fish_shadow.texture = drawn_card.texture
				
				# Set name with auto-scaling
				var card_name_text: String = drawn_card.card_name if drawn_card.card_name else "Card"
				if has_bait:
					if fish_name:
						fish_name.visible = true
						fish_name.text = card_name_text
						_auto_scale_label(fish_name, 150.0, 31, 16)
					if fish_name_2: fish_name_2.visible = false
				else:
					if fish_name: fish_name.visible = false
					if fish_name_2:
						fish_name_2.visible = true
						fish_name_2.text = card_name_text
						_auto_scale_label(fish_name_2, 180.0, 31, 16)
				
				# Set stats
				if bait_lbl:
					bait_lbl.visible = has_bait
					if has_bait: bait_lbl.text = str(drawn_card.bait_cost)
				if hook_lbl:
					hook_lbl.visible = true
					hook_lbl.text = str(drawn_card.hook)
				if line_lbl:
					line_lbl.visible = true
					line_lbl.text = str(drawn_card.line)
				
				# Handle sinker
				if sinker_lbl:
					sinker_lbl.visible = has_sinker
					if has_sinker: sinker_lbl.text = drawn_card.sinker
				if sinker_desc:
					sinker_desc.visible = has_sinker
					if has_sinker:
						sinker_desc.text = CardDatabase.get_sinker_description_dynamic(drawn_card.sinker, drawn_card.sinker_power)
	)
	
	# Phase 3: Flip back - scale X to 1
	tween.tween_property(temp_card, "scale:x", 1.0, 0.15).set_trans(Tween.TRANS_SINE)
	
	# Phase 4: Hold for a moment so player can see the card
	tween.tween_interval(0.4)
	
	# Phase 5: Move to hand and fade out
	var hand_target_y: float = 900.0  # Approximate hand position
	tween.tween_property(temp_card, "position:y", hand_target_y, 0.25).set_trans(Tween.TRANS_CUBIC)
	tween.parallel().tween_property(temp_card, "scale", Vector2(0.7, 0.7), 0.25)
	tween.parallel().tween_property(temp_card, "modulate:a", 0.0, 0.2)
	
	# Cleanup
	tween.tween_callback(func():
		temp_card.queue_free()
		_is_drawing = false
		# Reset deck to normal position
		if deck_node and deck_node is Node2D:
			deck_node.position.y = 200.0
			deck_node.scale = Vector2.ONE
	)


func _on_draw_state_changed(can_draw: bool) -> void:
	_update_deck_visuals(can_draw)
	
	if end_turn_button:
		if can_draw:
			end_turn_button.disabled = true
			if end_turn_button_label:
				end_turn_button_label.modulate = COL_DISABLED
				# Reset pos to base_y
				end_turn_button_label.position.y = _end_turn_label_base_y
		else:
			end_turn_button.disabled = false
			if end_turn_button_label:
				end_turn_button_label.modulate = COL_NORMAL

func _update_deck_visuals(can_draw: bool) -> void:
	# Update deck visuals when player can't draw anymore this turn
	if salvage_node:
		salvage_node.modulate.a = 1.0  # Keep full opacity
		var salvage_back = salvage_node.get_node_or_null("Back")
		if salvage_back:
			# Darken and show X when can't draw
			if can_draw:
				salvage_back.modulate = Color.WHITE
			else:
				salvage_back.modulate = Color(0.5, 0.5, 0.5)
	
	if chum_node:
		chum_node.modulate.a = 1.0  # Keep full opacity
		var chum_back = chum_node.get_node_or_null("Back")
		if chum_back:
			if can_draw:
				chum_back.modulate = Color.WHITE
			else:
				chum_back.modulate = Color(0.5, 0.5, 0.5)

func _connect_signals() -> void:
	if not battle_manager: 
		push_error("BattleBoardUI: No battle_manager found!")
		return
	_safe_connect(battle_manager, "battle_started", _on_battle_started)
	_safe_connect(battle_manager, "turn_started", _on_turn_started)
	_safe_connect(battle_manager, "turn_ended", _on_turn_ended)
	_safe_connect(battle_manager, "board_updated", _on_board_updated)
	_safe_connect(battle_manager, "hand_updated", _on_hand_updated)
	_safe_connect(battle_manager, "bait_changed", _on_bait_changed)
	_safe_connect(battle_manager, "hook_available", _update_hook_button)
	_safe_connect(battle_manager, "hook_used", _on_hook_used)
	_safe_connect(battle_manager, "hook_cooldown_tick", _on_hook_cooldown_tick)
	_safe_connect(battle_manager, "catch_qte_triggered", _on_catch_qte)
	_safe_connect(battle_manager, "battle_won", _on_battle_won)
	_safe_connect(battle_manager, "battle_lost", _on_battle_lost)
	_safe_connect(battle_manager, "card_damaged", _on_card_damaged)
	_safe_connect(battle_manager, "card_destroyed", _on_card_destroyed)
	_safe_connect(battle_manager, "fish_damaged", _on_fish_damaged)
	_safe_connect(battle_manager, "fish_destroyed", _on_fish_destroyed)
	_safe_connect(battle_manager, "fish_fled", _on_fish_fled)
	_safe_connect(battle_manager, "boat_damaged", _on_boat_damaged)
	_safe_connect(battle_manager, "draw_state_changed", _on_draw_state_changed)
	_safe_connect(battle_manager, "player_attack_started", _on_player_attack_started)
	_safe_connect(battle_manager, "fish_attack_started", _on_fish_attack_started)
	_safe_connect(battle_manager, "all_attacks_finished", _on_all_attacks_finished)
	_safe_connect(battle_manager, "fish_incoming", _on_fish_incoming)
	_safe_connect(battle_manager, "fish_spawned", _on_fish_spawned)
	if catch_minigame: _safe_connect(catch_minigame, "catch_completed", _on_catch_completed)
	
	# If battle already started before we connected signals, refresh now
	if battle_manager.has_method("is_battle_active") and battle_manager.is_battle_active():
		_on_battle_started()

func _safe_connect(obj: Object, signal_name: String, method: Callable) -> void:
	if obj.has_signal(signal_name) and not obj.is_connected(signal_name, method):
		obj.connect(signal_name, method)

func _on_hook_cooldown_tick(_turns: int) -> void: _update_hook_button()

# --- MODIFIED: Font scaling logic ---
func set_area_name(n: String) -> void:
	if area_label:
		area_label.text = n
		# Shrink font to fit width. Max 82 (default), Min 20.
		# Assumes Label is properly Anchored/Sized in editor.
		_auto_scale_label(area_label, area_label.size.x, 82, 20)

func _on_battle_started() -> void:
	selected_hand_index = -1
	hook_mode = false
	_hovered_hand_index = -1
	_previous_hand_size = 0
	_update_hook_button()
	_update_hud()
	
	# Clear all existing cards from previous battle
	_clear_all_cards()
	
	# Clear incoming fish indicators
	_clear_incoming_fish_indicators()
	
	# Check for any initial pending fish and show indicators
	_refresh_incoming_fish_indicators()
	
	# Refresh all card displays
	_refresh_fish()
	_refresh_board()
	_refresh_hand_full()

func _clear_all_cards() -> void:
	# Clear fish cards
	for card in fish_cards:
		if is_instance_valid(card):
			_stop_idle_animation(card)
			card.queue_free()
	fish_cards.clear()
	fish_slot_map.clear()
	
	# Clear board cards
	for card in board_cards:
		if is_instance_valid(card):
			_stop_idle_animation(card)
			card.queue_free()
	board_cards.clear()
	board_slot_map.clear()
	
	# Clear hand cards
	for card in hand_cards:
		if is_instance_valid(card):
			_stop_idle_animation(card)
			_stop_hover_animation(card)
			card.queue_free()
	hand_cards.clear()

func _on_turn_started(t: int) -> void:
	_update_hook_button()
	_update_hud()
	_show_turn_banner(t)
	
	# Update button states based on drawing ability
	if battle_manager.has_method("can_draw"):
		_on_draw_state_changed(battle_manager.can_draw())
	else:
		_reenable_end_turn_button()

func _on_turn_ended() -> void:
	pass # Removed log

func _on_board_updated() -> void:
	_refresh_fish()
	_refresh_board()
func _on_hand_updated() -> void: _smart_refresh_hand()

func _on_bait_changed(_new_bait: int) -> void:
	_update_hud() # Bait number needs update
	# Update hand card playability (gray out cards that need more bait)
	_update_hand_playability()

func _on_hook_used() -> void:
	hook_mode = false
	_update_hook_button()

func _on_catch_qte(_slot: int, fish_data, _line: int) -> void:
	if catch_minigame and fish_data:
		_fade_cards_for_minigame(true)
		catch_minigame.visible = true
		var difficulty := float(fish_data.line) / 5.0 if fish_data.line else 0.5
		var fish_rarity: String = fish_data.rarity if fish_data.rarity else "common"
		catch_minigame.start_catch(fish_data.fish_name if fish_data.fish_name else "Fish", difficulty, "Fighter", fish_rarity)

func _on_catch_completed(success: bool, quality: int) -> void:
	_fade_cards_for_minigame(false)
	if catch_minigame: catch_minigame.visible = false
	if battle_manager: battle_manager.resolve_catch(success, quality)
	if success:
		# Position caught text above center to avoid overlap with victory
		var catch_pos := get_viewport_rect().size / 2 - Vector2(0, 100)
		_spawn_floating_text(catch_pos, "CAUGHT!", Color.GREEN, 48)
	else:
		_spawn_floating_text(get_viewport_rect().size / 2, "ESCAPED!", Color.RED, 48)

func _fade_cards_for_minigame(fade_out: bool) -> void:
	var target_alpha := 0.3 if fade_out else 1.0
	for card in fish_cards + board_cards + hand_cards:
		if is_instance_valid(card):
			var tween := create_tween()
			tween.tween_property(card, "modulate:a", target_alpha, 0.3)

func _on_battle_won(_c: Array) -> void:
	if hook_button: hook_button.disabled = true
	if end_turn_button: end_turn_button.disabled = true
	# Clear all incoming fish indicators
	_clear_incoming_fish_indicators()
	# Delay victory text slightly and position below center
	if not is_inside_tree():
		return
	await get_tree().create_timer(0.5).timeout
	if not is_inside_tree():
		return
	var victory_pos := get_viewport_rect().size / 2 + Vector2(0, 50)
	_spawn_floating_text(victory_pos, "VICTORY!", Color.GOLD, 64)

func _on_battle_lost() -> void:
	if hook_button: hook_button.disabled = true
	if end_turn_button: end_turn_button.disabled = true
	# Clear all incoming fish indicators
	_clear_incoming_fish_indicators()
	_spawn_floating_text(get_viewport_rect().size / 2, "DEFEAT!", Color.RED, 64)

func _on_card_damaged(slot: int, damage: int) -> void:
	var card = board_slot_map.get(slot)
	if card and is_instance_valid(card):
		_stop_idle_animation(card)
		AnimHelper.take_damage(card)
		_spawn_floating_text_at_node(card, "-%d" % damage, Color.RED)
		
		# Update the card's Line label to show new health
		_update_card_health_display(slot)
		
		# Restart idle after damage animation
		_start_idle_animation_delayed(card, 0.4)

func _update_card_health_display(slot: int) -> void:
	var card = board_slot_map.get(slot)
	if not card or not is_instance_valid(card):
		return
	
	# Get the card instance from battle_manager
	if not battle_manager:
		return
	var card_inst = battle_manager.player_cards[slot] if slot < battle_manager.NUM_SLOTS else null
	if not card_inst:
		return
	
	# Update the Line label - use max(0, value) to avoid showing negative numbers
	var line_label = card.get_node_or_null("Line")
	if line_label:
		var display_value: int = maxi(0, card_inst.current_line)
		line_label.text = str(display_value)
		
		# Flash the label red briefly - but safely handle scene tree changes
		var original_color = line_label.get_theme_color("font_color") if line_label.has_theme_color("font_color") else Color.WHITE
		line_label.add_theme_color_override("font_color", Color.RED)
		
		# Safety: store reference and check tree before await
		if not is_inside_tree():
			return
		await get_tree().create_timer(0.3).timeout
		
		# Safety checks after await
		if is_instance_valid(line_label) and is_inside_tree():
			line_label.add_theme_color_override("font_color", original_color)

func _on_card_destroyed(slot: int) -> void:
	var card = board_slot_map.get(slot)
	if card and is_instance_valid(card):
		_stop_idle_animation(card)
		# Remove from map immediately to prevent further access
		board_slot_map.erase(slot)
		if card in board_cards:
			board_cards.erase(card)
		# Use dissolve effect - pass callback to refresh board after
		_animate_card_dissolve(card, func(): _refresh_board())

func _on_fish_damaged(slot: int, damage: int) -> void:
	var card = fish_slot_map.get(slot)
	if card and is_instance_valid(card):
		_stop_idle_animation(card)
		AnimHelper.take_damage(card)
		_spawn_floating_text_at_node(card, "-%d" % damage, Color.ORANGE)
		
		# Update the fish's Line label to show new health
		_update_fish_health_display(slot)
		
		# Restart idle after damage animation
		_start_idle_animation_delayed(card, 0.4)

func _update_fish_health_display(slot: int) -> void:
	var card = fish_slot_map.get(slot)
	if not card or not is_instance_valid(card):
		return
	
	# Get the fish instance from battle_manager
	if not battle_manager:
		return
	var fish_inst = battle_manager.fish_slots[slot] if slot < battle_manager.NUM_SLOTS else null
	if not fish_inst:
		return
	
	# Update the Line label - use max(0, value) to avoid showing negative numbers
	var line_label = card.get_node_or_null("Line")
	if line_label:
		var display_value: int = maxi(0, fish_inst.current_line)
		line_label.text = str(display_value)
		
		# Flash the label red briefly - but safely handle scene tree changes
		var original_color = line_label.get_theme_color("font_color") if line_label.has_theme_color("font_color") else Color.WHITE
		line_label.add_theme_color_override("font_color", Color.RED)
		
		# Safety: check tree before await
		if not is_inside_tree():
			return
		await get_tree().create_timer(0.3).timeout
		
		# Safety checks after await
		if is_instance_valid(line_label) and is_inside_tree():
			line_label.add_theme_color_override("font_color", original_color)

func _on_fish_destroyed(slot: int) -> void:
	var card = fish_slot_map.get(slot)
	if card and is_instance_valid(card):
		_stop_idle_animation(card)
		# Remove from map immediately to prevent further access
		fish_slot_map.erase(slot)
		if card in fish_cards:
			fish_cards.erase(card)
		var tween := AnimHelper.die(card)
		if tween:
			tween.finished.connect(func():
				if is_instance_valid(card):
					card.queue_free()
			)
		else:
			card.queue_free()

func _on_fish_fled(slot: int) -> void:
	var card = fish_slot_map.get(slot)
	if card and is_instance_valid(card):
		_stop_idle_animation(card)
		# Remove from map immediately to prevent further access
		fish_slot_map.erase(slot)
		if card in fish_cards:
			fish_cards.erase(card)
		var tween := create_tween()
		tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
		tween.tween_property(card, "position:x", card.position.x + 500, 0.4)
		tween.parallel().tween_property(card, "modulate:a", 0.0, 0.4)
		tween.finished.connect(func():
			if is_instance_valid(card):
				card.queue_free()
		)


# ============ INCOMING FISH INDICATORS ============

func _on_fish_incoming(slot: int, fish_data) -> void:
	# FIXED: Handle null fish_data as signal to clear indicator
	if fish_data == null:
		_remove_incoming_fish_indicator(slot)
		return
	
	# Only create indicator if one doesn't already exist for this slot
	if not incoming_fish_indicators.has(slot):
		_create_incoming_fish_indicator(slot, fish_data)


func _on_fish_spawned(slot: int) -> void:
	# Clear the incoming indicator for this slot since fish is now on field
	_remove_incoming_fish_indicator(slot)
	# Refresh fish display
	_refresh_fish()


func _refresh_incoming_fish_indicators() -> void:
	if not battle_manager:
		_clear_incoming_fish_indicators()
		return
	
	# Clear ALL existing indicators first
	_clear_incoming_fish_indicators()
	
	# Only create indicators if battle is active
	if not battle_manager.is_battle_active():
		return
	
	# Get pending fish from battle manager
	var pending: Array = battle_manager.get_pending_fish()
	for fish_entry in pending:
		var slot: int = fish_entry.get("slot", -1)
		var fish: FishData = fish_entry.get("fish", null)
		if slot >= 0 and fish != null:
			_create_incoming_fish_indicator(slot, fish)


func _create_incoming_fish_indicator(slot: int, fish_data: FishData) -> void:
	if not opponents_hbox or fish_data == null:
		return
	
	# Don't create duplicate indicators
	if incoming_fish_indicators.has(slot):
		return
	
	# Find the CardsInPlay parent node to add indicator above the hbox
	var cards_in_play: Control = opponents_hbox.get_parent().get_parent() if opponents_hbox.get_parent() else null
	if cards_in_play == null:
		cards_in_play = self  # Fallback to self
	
	# Find where existing fish are and where this new fish will appear
	var existing_fish_slots: Array[int] = []
	if battle_manager:
		for i in battle_manager.NUM_SLOTS:
			if battle_manager.fish_slots[i] != null:
				existing_fish_slots.append(i)
	
	# Determine if incoming fish is to the left or right of existing fish
	var is_on_right := true
	if not existing_fish_slots.is_empty():
		var avg_slot: float = 0.0
		for s in existing_fish_slots:
			avg_slot += s
		avg_slot /= existing_fish_slots.size()
		is_on_right = slot > avg_slot
	
	# Get the global position of opponents_hbox to position indicator relative to screen
	var hbox_global_pos: Vector2 = opponents_hbox.global_position
	var hbox_size: Vector2 = opponents_hbox.size
	
	# Calculate position - place indicator ABOVE the fish area
	var card_spacing := CARD_W + CARD_SPACING_BOARD
	var container_width: float = hbox_size.x if hbox_size.x > 0 else 1100.0
	
	# Get positions of existing fish to find where to place indicator
	var indicator_x: float
	if existing_fish_slots.is_empty():
		# No fish yet, center it
		indicator_x = hbox_global_pos.x + container_width / 2.0
	else:
		# Position based on existing fish layout - place above where the new fish will appear
		var total_fish := existing_fish_slots.size()
		var total_width: float = total_fish * CARD_W + (total_fish - 1) * CARD_SPACING_BOARD
		var start_x: float = hbox_global_pos.x + (container_width - total_width) / 2.0 + CARD_W / 2.0
		
		if is_on_right:
			# Place above where the new fish will spawn (to the right)
			indicator_x = start_x + total_fish * card_spacing
		else:
			# Place above where the new fish will spawn (to the left)
			indicator_x = start_x - card_spacing
	
	# Position indicator 100 pixels above the fish area (closer for visibility)
	var indicator_y: float = hbox_global_pos.y - 100
	
	# Create the indicator container as a direct child of the battle board (not hbox)
	var indicator := Control.new()
	indicator.name = "IncomingFishIndicator_%d" % slot
	indicator.set_anchors_preset(Control.PRESET_TOP_LEFT)
	indicator.z_index = 100  # Higher z-index to ensure visibility
	add_child(indicator)  # Add to battle board directly
	
	# Create a panel for background visibility
	var panel := PanelContainer.new()
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.1, 0.15, 0.9)
	panel_style.border_color = Color(1.0, 0.6, 0.2, 0.8)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	panel_style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", panel_style)
	indicator.add_child(panel)
	
	# Create VBox for the content
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)
	
	# "INCOMING" text at top
	var incoming_label := Label.new()
	incoming_label.text = "!! INCOMING !!"
	incoming_label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if incoming_fish_font:
		incoming_label.add_theme_font_override("font", incoming_fish_font)
	incoming_label.add_theme_font_size_override("font_size", 16)
	incoming_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))  # Orange
	incoming_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(incoming_label)
	
	# Fish name
	var name_label := Label.new()
	name_label.text = fish_data.fish_name if fish_data.fish_name else "Fish"
	name_label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if incoming_fish_font:
		name_label.add_theme_font_override("font", incoming_fish_font)
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))  # Gold
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)
	
	# Arrow pointing down to where fish will spawn
	var arrow_label := Label.new()
	arrow_label.text = "V V V"  # Text arrows
	arrow_label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if incoming_fish_font:
		arrow_label.add_theme_font_override("font", incoming_fish_font)
	arrow_label.add_theme_font_size_override("font_size", 20)
	arrow_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))  # Gold
	arrow_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(arrow_label)
	
	# Wait one frame to get proper size, then center the indicator
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if is_instance_valid(panel) and is_inside_tree():
		var panel_size: Vector2 = panel.size
		indicator.global_position = Vector2(indicator_x - panel_size.x / 2.0, indicator_y)
	
	# Store fish data for tooltip
	indicator.set_meta("fish_data", fish_data)
	indicator.set_meta("is_on_right", is_on_right)
	
	# Make it interactive for hover preview
	indicator.mouse_filter = Control.MOUSE_FILTER_STOP
	indicator.mouse_entered.connect(_on_incoming_fish_hover.bind(slot, true))
	indicator.mouse_exited.connect(_on_incoming_fish_hover.bind(slot, false))
	
	# Add shine animation effect
	_add_incoming_fish_shine(indicator, arrow_label, name_label, incoming_label)
	
	# Store reference
	incoming_fish_indicators[slot] = indicator


func _add_incoming_fish_shine(indicator: Control, arrow_label: Label, name_label: Label, incoming_label: Label = null) -> void:
	# Safety check immediately
	if not is_instance_valid(arrow_label) or not is_instance_valid(name_label):
		return

	var tween := indicator.create_tween()
	tween.set_loops()  
	
	indicator.set_meta("shine_tween", tween)
	
	tween.tween_callback(func():
		if not is_instance_valid(arrow_label) or not is_instance_valid(name_label):
			# Self-destruct if targets are gone
			if tween and tween.is_valid(): tween.kill()
			return
		var bright := Color(1.0, 0.95, 0.5)
		arrow_label.add_theme_color_override("font_color", bright)
	)
	
	tween.tween_interval(0.3)
	
	tween.tween_callback(func():
		pass 
	)
	
	tween.tween_interval(0.3)


func _remove_incoming_fish_indicator(slot: int) -> void:
	if incoming_fish_indicators.has(slot):
		var indicator = incoming_fish_indicators[slot]
		if is_instance_valid(indicator):
			# Kill the shine tween first to prevent infinite loop error
			var tween = indicator.get_meta("shine_tween", null)
			if tween is Tween and tween.is_valid():
				tween.kill()
			indicator.queue_free()
		incoming_fish_indicators.erase(slot)


func _clear_incoming_fish_indicators() -> void:
	for slot in incoming_fish_indicators.keys():
		var indicator = incoming_fish_indicators[slot]
		if is_instance_valid(indicator):
			# Kill the shine tween first to prevent infinite loop error
			var tween = indicator.get_meta("shine_tween", null)
			if tween is Tween and tween.is_valid():
				tween.kill()
			indicator.queue_free()
	incoming_fish_indicators.clear()


var _incoming_fish_preview: Control = null

func _on_incoming_fish_hover(slot: int, is_hovering: bool) -> void:
	if is_hovering:
		_show_incoming_fish_preview(slot)
	else:
		_hide_incoming_fish_preview()


func _show_incoming_fish_preview(slot: int) -> void:
	if not incoming_fish_indicators.has(slot):
		return
	
	var indicator = incoming_fish_indicators[slot]
	if not is_instance_valid(indicator):
		return
	
	var fish_data = indicator.get_meta("fish_data", null)
	if fish_data == null:
		return
	
	# Create a card preview
	if _incoming_fish_preview and is_instance_valid(_incoming_fish_preview):
		_incoming_fish_preview.queue_free()
	
	_incoming_fish_preview = _make_card()
	if _incoming_fish_preview == null:
		return
	
	# Setup the card with fish data
	_setup_as_fish_preview(_incoming_fish_preview, fish_data)
	
	# Position it near the indicator
	var indicator_pos: Vector2 = indicator.global_position
	_incoming_fish_preview.global_position = indicator_pos + Vector2(CARD_W / 2 + 20, CARD_H / 2)
	_incoming_fish_preview.scale = Vector2(0.8, 0.8)  # Slightly smaller preview
	_incoming_fish_preview.z_index = 200
	_incoming_fish_preview.modulate = Color(1.0, 1.0, 1.0, 0.95)
	
	add_child(_incoming_fish_preview)


func _hide_incoming_fish_preview() -> void:
	if _incoming_fish_preview and is_instance_valid(_incoming_fish_preview):
		_incoming_fish_preview.queue_free()
		_incoming_fish_preview = null


func _setup_as_fish_preview(card: Node, fish_data: FishData) -> void:
	if fish_data == null: return
	
	var front = card.get_node_or_null("Front")
	var back = card.get_node_or_null("Back")
	var fish_name_label = card.get_node_or_null("FishName")
	var fish_name_label_2 = card.get_node_or_null("FishName2")
	var bait_label_node = card.get_node_or_null("Bait")
	var hook_label = card.get_node_or_null("Hook")
	var line_label = card.get_node_or_null("Line")
	var sinker_label = card.get_node_or_null("Sinker")
	var sinker_desc = card.get_node_or_null("SinkerDesc")
	var fish_image = card.get_node_or_null("FishImage")
	var fish_shadow = card.get_node_or_null("FishShadow")
	
	if front: front.visible = true
	if back: back.visible = false
	
	var has_sinker: bool = fish_data.sinker != "None" and fish_data.sinker != ""
	_update_front_texture(card, false, has_sinker)
	
	if bait_label_node: bait_label_node.visible = false
	
	if fish_name_label: fish_name_label.visible = false
	if fish_name_label_2:
		fish_name_label_2.visible = true
		fish_name_label_2.text = fish_data.fish_name if fish_data.fish_name else "Fish"
	
	if hook_label: hook_label.text = str(fish_data.hook)
	if line_label: line_label.text = str(fish_data.line)
	
	if sinker_label:
		sinker_label.visible = has_sinker
		if has_sinker: sinker_label.text = fish_data.sinker
	if sinker_desc:
		sinker_desc.visible = has_sinker
		if has_sinker:
			sinker_desc.text = FishDatabase.get_sinker_description_dynamic(fish_data.sinker, fish_data.sinker_power)
	
	if fish_data.texture:
		if fish_image: fish_image.texture = fish_data.texture
		if fish_shadow: fish_shadow.texture = fish_data.texture


func _on_boat_damaged(new_hp: int) -> void:
	_update_hud() # Health changed
	if health_number_label:
		AnimHelper.shake(health_number_label, 5, 0.3)
		AnimHelper.damage_flash(health_number_label, 0.3)

# --- MODIFIED UI UPDATE FUNCTIONS ---

func _update_hook_button() -> void:
	if not hook_button or not battle_manager: return
	
	if battle_manager.can_hook():
		hook_button.disabled = false
		if hook_button_label:
			hook_button_label.text = "SELECT FISH" if hook_mode else "HOOK"
			hook_button_label.add_theme_color_override("font_color", COL_KELP_GREEN)
	else:
		hook_button.disabled = true
		var cd = battle_manager.get_hook_cooldown()
		if hook_button_label:
			hook_button_label.text = "HOOK (%d)" % cd if cd > 0 else "HOOK"
			hook_button_label.add_theme_color_override("font_color", COL_DISABLED)
			# Reset position if disabled
			hook_button_label.position.y = _hook_label_base_y

func _update_hud() -> void:
	if not battle_manager: return
	
	if turn_number_label: 
		turn_number_label.text = str(battle_manager.turn_number)
	
	if health_number_label: 
		health_number_label.text = "%d/%d" % [battle_manager.boat_hp, battle_manager.max_boat_hp]
		
	if bait_number_label: 
		bait_number_label.text = str(battle_manager.bait)
		
	if line_strength_label: 
		# Format as <=Number (no space)
		var rod_str = battle_manager.get_rod_strength()
		line_strength_label.text = "≤%d" % rod_str

func _show_turn_banner(turn: int) -> void:
	var banner := Label.new()
	banner.text = "TURN %d" % turn
	if incoming_fish_font:
		banner.add_theme_font_override("font", incoming_fish_font)
	banner.add_theme_font_size_override("font_size", 64)
	banner.add_theme_color_override("font_color", Color.WHITE)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.set_anchors_preset(Control.PRESET_CENTER)
	banner.pivot_offset = Vector2(150, 40)
	banner.modulate.a = 0
	banner.scale = Vector2(0.5, 0.5)
	add_child(banner)
	var tween := create_tween()
	tween.tween_property(banner, "modulate:a", 1.0, 0.2)
	tween.parallel().tween_property(banner, "scale", Vector2(1.2, 1.2), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(banner, "scale", Vector2.ONE, 0.1)
	tween.tween_interval(0.5)
	tween.tween_property(banner, "modulate:a", 0.0, 0.3)
	tween.finished.connect(func(): banner.queue_free())

func _spawn_floating_text(pos: Vector2, text: String, color: Color, size: int = 16) -> void:
	# Ensure combat text layer exists
	if not combat_text_layer: _setup_combat_text_layer()
		
	var label := Label.new()
	label.text = text
	if incoming_fish_font:
		label.add_theme_font_override("font", incoming_fish_font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = pos - Vector2(100, 20)
	label.custom_minimum_size = Vector2(200, 40)
	label.z_index = 100
	
	# Add to the container inside combat text layer
	combat_text_layer.get_child(0).add_child(label)
	
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "position:y", pos.y - 80, 0.8)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.8).set_delay(0.3)
	tween.finished.connect(func(): label.queue_free())

func _spawn_floating_text_at_node(node: Node, text: String, color: Color) -> void:
	var pos := Vector2.ZERO
	if node is Control: pos = node.global_position + node.size / 2
	elif node is Node2D: pos = node.global_position
	else: pos = get_viewport_rect().size / 2
	_spawn_floating_text(pos, text, color)

# ============ ATTACK ANIMATIONS ============

# Called when a player card starts attacking
func _on_player_attack_started(slot: int, has_target: bool) -> void:
	var attacker: Node = board_slot_map.get(slot)
	var target: Node = fish_slot_map.get(slot)
	if not attacker or not is_instance_valid(attacker):
		return
	
	if has_target and target and is_instance_valid(target):
		# Animate attack towards the fish (upward)
		_animate_attack_to_target_node(attacker, target)
	else:
		# No target - just do a small lunge
		_animate_attack_lunge(attacker, Vector2.UP, 30.0)


# Called when a fish starts attacking
func _on_fish_attack_started(slot: int, has_target: bool) -> void:
	var attacker: Node = fish_slot_map.get(slot)
	if not attacker or not is_instance_valid(attacker):
		return
	
	if has_target:
		# Find the actual target - check for opposite slot first, then nearest
		var target: Node = null
		var target_slot: int = -1
		
		# Check if there's a card directly opposite
		if board_slot_map.has(slot) and is_instance_valid(board_slot_map.get(slot)):
			target = board_slot_map.get(slot)
			target_slot = slot
		else:
			# Find nearest player card to this fish
			for check_slot in board_slot_map.keys():
				var card = board_slot_map.get(check_slot)
				if card and is_instance_valid(card):
					if target_slot < 0 or absi(check_slot - slot) < absi(target_slot - slot):
						target = card
						target_slot = check_slot
		
		if target and is_instance_valid(target):
			# Animate attack towards the player card
			_animate_attack_to_target_node(attacker, target)
		else:
			# No valid target found, attack boat instead
			_animate_attack_to_boat(attacker)
	else:
		# Attack the boat - lunge further down
		_animate_attack_to_boat(attacker)


# Called when all attacks are done - refresh the board
func _on_all_attacks_finished() -> void:
	# Only refresh if battle is still active (not won/lost)
	if battle_manager and battle_manager.battle_active:
		# Small delay before refresh to let death animations complete
		if not is_inside_tree():
			return
		await get_tree().create_timer(0.3).timeout
		if not is_inside_tree() or not battle_manager:
			return
		_refresh_fish()
		_refresh_board()
	# Note: end turn button is re-enabled by _on_turn_started when next turn begins


func animate_card_attack(attacker_slot: int, is_player_card: bool) -> void:
	var attacker: Node = board_slot_map.get(attacker_slot) if is_player_card else fish_slot_map.get(attacker_slot)
	var target: Node = fish_slot_map.get(attacker_slot) if is_player_card else board_slot_map.get(attacker_slot)
	if not attacker or not is_instance_valid(attacker): return
	if not target or not is_instance_valid(target):
		if not is_player_card: _animate_attack_lunge(attacker, Vector2.DOWN, 50.0)
		return
	await _animate_attack_to_target(attacker, target)


func _animate_attack_to_target_node(attacker: Node, target: Node) -> void:
	if not is_instance_valid(attacker) or not is_instance_valid(target):
		return
	
	_stop_idle_animation(attacker)
	var original_pos: Vector2 = attacker.position
	var original_z: int = attacker.z_index
	
	# Get target position (account for both Node2D and Control types)
	var target_pos: Vector2
	if target is Node2D:
		target_pos = target.position
	elif target is Control:
		target_pos = target.global_position
	else:
		target_pos = original_pos + Vector2(0, -100)
	
	# Calculate attack position - move past the target
	var direction: Vector2 = (target_pos - original_pos).normalized()
	var distance: float = original_pos.distance_to(target_pos)
	var attack_pos: Vector2 = original_pos + direction * (distance + 50)  # Move past the target
	
	attacker.z_index = 50
	
	var tween := create_tween()
	# Wind up
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(attacker, "position", original_pos - direction * 25, 0.08)
	# Lunge forward past target
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	tween.tween_property(attacker, "position", attack_pos, 0.12)
	tween.parallel().tween_property(attacker, "scale", Vector2(1.2, 1.2), 0.08)
	# Play impact sound when hitting target
	tween.tween_callback(func(): AudioManager.play_card_impact())
	# Hold briefly at attack position
	tween.tween_interval(0.05)
	# Return to original position
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(attacker, "position", original_pos, 0.2)
	tween.parallel().tween_property(attacker, "scale", Vector2.ONE, 0.15)
	
	tween.finished.connect(func():
		if is_instance_valid(attacker):
			attacker.z_index = original_z
			_start_idle_animation(attacker)
	)


func _animate_attack_to_boat(attacker: Node) -> void:
	if not is_instance_valid(attacker):
		return
	
	_stop_idle_animation(attacker)
	var original_pos: Vector2 = attacker.position
	var original_z: int = attacker.z_index
	
	# Attack goes far down towards the boat
	var attack_pos: Vector2 = original_pos + Vector2(0, 250)
	
	attacker.z_index = 50
	
	var tween := create_tween()
	# Wind up
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(attacker, "position", original_pos + Vector2(0, -30), 0.1)
	# Lunge down towards boat
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	tween.tween_property(attacker, "position", attack_pos, 0.15)
	tween.parallel().tween_property(attacker, "scale", Vector2(1.25, 1.25), 0.1)
	tween.parallel().tween_property(attacker, "rotation_degrees", 10.0, 0.15)
	# Play impact sound when hitting boat
	tween.tween_callback(func(): AudioManager.play_card_impact())
	# Hold at attack position
	tween.tween_interval(0.08)
	# Return to original position
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(attacker, "position", original_pos, 0.25)
	tween.parallel().tween_property(attacker, "scale", Vector2.ONE, 0.2)
	tween.parallel().tween_property(attacker, "rotation_degrees", 0.0, 0.2)
	
	tween.finished.connect(func():
		if is_instance_valid(attacker):
			attacker.z_index = original_z
			_start_idle_animation(attacker)
	)


func _animate_attack_to_target(attacker: Node, target: Node) -> void:
	if not is_instance_valid(attacker) or not is_instance_valid(target): return
	_stop_idle_animation(attacker)
	var original_pos: Vector2 = attacker.position
	var original_z: int = attacker.z_index
	var target_pos: Vector2 = target.position if target is Node2D else target.global_position
	var direction: Vector2 = (target_pos - original_pos).normalized()
	var attack_pos: Vector2 = original_pos + direction * (original_pos.distance_to(target_pos) * 0.7)
	attacker.z_index = 50
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(attacker, "position", original_pos - direction * 20, 0.1)
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	tween.tween_property(attacker, "position", attack_pos, 0.15)
	tween.tween_property(attacker, "scale", Vector2(1.15, 1.15), 0.05)
	tween.tween_interval(0.08)
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(attacker, "position", original_pos, 0.25)
	tween.parallel().tween_property(attacker, "scale", Vector2.ONE, 0.15)
	await tween.finished
	attacker.z_index = original_z
	_start_idle_animation(attacker)

func _animate_attack_lunge(attacker: Node, direction: Vector2, distance: float) -> void:
	if not is_instance_valid(attacker): return
	_stop_idle_animation(attacker)
	var original_pos: Vector2 = attacker.position
	var attack_pos: Vector2 = original_pos + direction.normalized() * distance
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	tween.tween_property(attacker, "position", attack_pos, 0.15)
	tween.tween_property(attacker, "scale", Vector2(1.1, 1.1), 0.05)
	tween.tween_interval(0.05)
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(attacker, "position", original_pos, 0.2)
	tween.parallel().tween_property(attacker, "scale", Vector2.ONE, 0.1)
	tween.finished.connect(func(): if is_instance_valid(attacker): _start_idle_animation(attacker))

# ============ SMART HAND REFRESH ============
func _smart_refresh_hand() -> void:
	if not battle_manager or not hand_hbox:
		_refresh_hand_full()
		return
	var hand_array: Array = battle_manager.hand
	var new_size: int = hand_array.size()
	var old_size: int = _previous_hand_size
	if old_size == 0 or abs(new_size - old_size) > 1:
		_refresh_hand_full()
		_previous_hand_size = new_size
		return
	if new_size > old_size: _refresh_hand_with_new_card()
	elif new_size < old_size: _refresh_hand_with_removal()
	else: _refresh_hand_full()
	_previous_hand_size = new_size

func _refresh_hand_full() -> void:
	for card in hand_cards:
		if is_instance_valid(card):
			_stop_idle_animation(card)
			_stop_hover_animation(card)
			card.queue_free()
	hand_cards.clear()
	_hovered_hand_index = -1
	_last_hovered_index = -1
	if not battle_manager or not hand_hbox: return
	var hand_array: Array = battle_manager.hand
	var positions := _calculate_hand_positions(hand_array.size())
	var total_cards := hand_array.size()
	for i in hand_array.size():
		var card_data: CardData = hand_array[i]
		if card_data == null: continue
		var card: Node = _make_card()
		if card == null: continue
		_setup_as_hand(card, card_data, i)
		hand_hbox.add_child(card)
		if card is Node2D and i < positions.size():
			card.position = positions[i]
			card.rotation_degrees = _calculate_hand_rotation(i, total_cards)
			card.z_index = _calculate_hand_z_index(i, total_cards)
		hand_cards.append(card)
		_animate_card_draw(card, i * 0.08)
		if i == selected_hand_index: _animate_card_selected(card, true)
		_start_idle_animation_delayed(card, 0.4 + i * 0.08)

func _refresh_hand_with_new_card() -> void:
	if not battle_manager or not hand_hbox: return
	var hand_array: Array = battle_manager.hand
	var new_positions := _calculate_hand_positions(hand_array.size())
	var new_card_index := hand_array.size() - 1
	var total_cards := hand_array.size()
	
	# Update existing cards' rotation and z-index, slide to new positions
	for i in hand_cards.size():
		var card: Node = hand_cards[i]
		if is_instance_valid(card) and card is Node2D and i < new_positions.size():
			_stop_idle_animation(card)
			var new_rotation := _calculate_hand_rotation(i, total_cards)
			var new_z := _calculate_hand_z_index(i, total_cards)
			card.z_index = new_z
			var tween := create_tween()
			tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
			tween.tween_property(card, "position", new_positions[i], 0.25)
			tween.parallel().tween_property(card, "rotation_degrees", new_rotation, 0.25)
			_start_idle_animation_delayed(card, 0.3)
	
	# Add new card with pop-in animation
	if new_card_index >= 0 and new_card_index < hand_array.size():
		var card_data: CardData = hand_array[new_card_index]
		if card_data:
			var card: Node = _make_card()
			if card:
				_setup_as_hand(card, card_data, new_card_index)
				hand_hbox.add_child(card)
				if card is Node2D and new_card_index < new_positions.size():
					var target_rotation := _calculate_hand_rotation(new_card_index, total_cards)
					var target_z := _calculate_hand_z_index(new_card_index, total_cards)
					card.position = Vector2(new_positions[new_card_index].x, new_positions[new_card_index].y + 150)
					card.modulate.a = 0
					card.scale = Vector2(0.5, 0.5)
					card.rotation_degrees = target_rotation * 2  # Start more rotated
					card.z_index = target_z
					var tween := create_tween()
					tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
					tween.tween_property(card, "position", new_positions[new_card_index], 0.35)
					tween.parallel().tween_property(card, "modulate:a", 1.0, 0.2)
					tween.parallel().tween_property(card, "scale", Vector2.ONE, 0.35)
					tween.parallel().tween_property(card, "rotation_degrees", target_rotation, 0.35)
				hand_cards.append(card)
				_start_idle_animation_delayed(card, 0.4)

func _refresh_hand_with_removal() -> void:
	if not battle_manager or not hand_hbox: return
	var hand_array: Array = battle_manager.hand
	var new_positions := _calculate_hand_positions(hand_array.size())
	var total_cards := hand_array.size()
	for card in hand_cards:
		if is_instance_valid(card):
			_stop_idle_animation(card)
			_stop_hover_animation(card)
			card.queue_free()
	hand_cards.clear()
	_hovered_hand_index = -1
	_last_hovered_index = -1
	for i in hand_array.size():
		var card_data: CardData = hand_array[i]
		if card_data == null: continue
		var card: Node = _make_card()
		if card == null: continue
		_setup_as_hand(card, card_data, i)
		hand_hbox.add_child(card)
		if card is Node2D and i < new_positions.size():
			var target_pos: Vector2 = new_positions[i]
			var target_rotation := _calculate_hand_rotation(i, total_cards)
			var target_z := _calculate_hand_z_index(i, total_cards)
			card.position = Vector2(target_pos.x + 50, target_pos.y)
			card.modulate.a = 0.5
			card.rotation_degrees = target_rotation
			card.z_index = target_z
			var tween := create_tween()
			tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
			tween.tween_property(card, "position", target_pos, 0.2).set_delay(i * 0.03)
			tween.parallel().tween_property(card, "modulate:a", 1.0, 0.15).set_delay(i * 0.03)
		hand_cards.append(card)
		if i == selected_hand_index: _animate_card_selected(card, true)
		_start_idle_animation_delayed(card, 0.3 + i * 0.03)

func _calculate_hand_positions(card_count: int) -> Array:
	var positions: Array = []
	if card_count == 0: return positions
	
	# Cards overlap - use negative spacing
	var card_spacing := CARD_W + CARD_SPACING_HAND  # e.g. 254 + (-80) = 174px between card centers
	var total_width: float = card_count * CARD_W + (card_count - 1) * CARD_SPACING_HAND
	var container_width: float = hand_hbox.size.x if hand_hbox and hand_hbox.size.x > 0 else 1200.0
	var start_x: float = (container_width - total_width) / 2.0 + CARD_W / 2.0
	
	for i in card_count:
		positions.append(Vector2(start_x + i * card_spacing, HAND_BASE_Y))
	return positions

# Calculate rotation for a card based on its position in hand (fanned effect)
func _calculate_hand_rotation(index: int, total_cards: int) -> float:
	if total_cards <= 1:
		return 0.0
	# Center card has 0 rotation, outer cards have more
	var center := (total_cards - 1) / 2.0
	var offset := index - center
	var max_offset := center if center > 0 else 1.0
	return (offset / max_offset) * HAND_MAX_ROTATION

# Calculate z-index for hand cards - rightmost cards on top (like holding cards)
func _calculate_hand_z_index(index: int, total_cards: int) -> int:
	# Each card is stacked on top of the previous one (left to right)
	return index + 1

# Update hand card playability (gray out cards that can't be afforded)
func _update_hand_playability() -> void:
	if not battle_manager:
		return
	var current_bait: int = battle_manager.get_bait()
	var hand_array: Array = battle_manager.hand
	
	for i in range(mini(hand_cards.size(), hand_array.size())):
		var card = hand_cards[i]
		var card_data: CardData = hand_array[i]
		if not is_instance_valid(card) or card_data == null:
			continue
		
		var can_afford: bool = current_bait >= card_data.bait_cost
		if can_afford:
			card.modulate = Color.WHITE
		else:
			card.modulate = Color(0.5, 0.5, 0.5)

# ============ HOVER ANIMATIONS ============
var _last_hovered_index: int = -1

func _update_hand_hover() -> void:
	# Safety check
	if not is_inside_tree() or not hand_hbox:
		return
		
	if hand_cards.is_empty():
		if _last_hovered_index >= 0:
			_last_hovered_index = -1
			_hovered_hand_index = -1
		return
	
	var mouse_pos := get_global_mouse_position()
	var hovered_index := -1
	var highest_z := -1000
	
	# Check all hand cards - the one with highest z-index under mouse wins
	for i in range(hand_cards.size()):
		var card = hand_cards[i]
		if not is_instance_valid(card) or not card is Node2D:
			continue
		
		# Skip selected card from hover
		if i == selected_hand_index:
			continue
		
		# Cast to Node2D for proper type inference
		var card_2d: Node2D = card as Node2D
		
		# Get card bounds in global space (accounting for rotation and scale)
		var card_global_pos: Vector2 = card_2d.global_position
		var card_scale: Vector2 = card_2d.scale
		var card_rotation: float = card_2d.rotation
		
		# Transform mouse position into card's local space
		var local_mouse: Vector2 = mouse_pos - card_global_pos
		local_mouse = local_mouse.rotated(-card_rotation)
		local_mouse /= card_scale
		
		# Check if mouse is within card bounds (centered origin)
		var half_w := CARD_W / 2.0
		var half_h := CARD_H / 2.0
		
		if local_mouse.x >= -half_w and local_mouse.x <= half_w and \
		   local_mouse.y >= -half_h and local_mouse.y <= half_h:
			# This card is under the mouse - check z-index
			var card_z: int = card_2d.z_index
			if card_z > highest_z:
				highest_z = card_z
				hovered_index = i
	
	# Update hover state if changed
	if hovered_index != _last_hovered_index:
		# Unhover old card
		if _last_hovered_index >= 0 and _last_hovered_index < hand_cards.size():
			var old_card = hand_cards[_last_hovered_index]
			if is_instance_valid(old_card) and _last_hovered_index != selected_hand_index:
				_animate_card_hover(old_card, false, _last_hovered_index)
		
		# Hover new card
		if hovered_index >= 0 and hovered_index < hand_cards.size():
			var new_card = hand_cards[hovered_index]
			if is_instance_valid(new_card):
				_animate_card_hover(new_card, true, hovered_index)
		
		_last_hovered_index = hovered_index
		_hovered_hand_index = hovered_index

func _on_hand_card_hover(_index: int, _is_hovering: bool) -> void:
	# Now handled by _update_hand_hover in _process
	pass

func _animate_card_hover(card: Node, is_hovered: bool, index: int = -1) -> void:
	if not is_instance_valid(card) or not card is Node2D: return
	_stop_hover_animation(card)
	_stop_idle_animation(card)
	
	var total_cards := hand_cards.size()
	var base_rotation := _calculate_hand_rotation(index, total_cards) if index >= 0 else 0.0
	var base_z := _calculate_hand_z_index(index, total_cards) if index >= 0 else 0
	
	# When hovered: lift up, scale up, straighten rotation, bring to front
	var target_y := HAND_BASE_Y - HAND_HOVER_LIFT if is_hovered else HAND_BASE_Y
	var target_scale := Vector2(1.12, 1.12) if is_hovered else Vector2.ONE
	var target_rotation := 0.0 if is_hovered else base_rotation
	var target_z := 100 if is_hovered else base_z  # Very high z when hovered
	
	card.z_index = target_z
	
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(card, "position:y", target_y, 0.15)
	tween.parallel().tween_property(card, "scale", target_scale, 0.15)
	tween.parallel().tween_property(card, "rotation_degrees", target_rotation, 0.15)
	hover_tween_map[card] = tween
	
	if not is_hovered:
		tween.finished.connect(func(): 
			if is_instance_valid(card): 
				_start_idle_animation(card)
		)

func _stop_hover_animation(card: Node) -> void:
	if hover_tween_map.has(card):
		var tween: Tween = hover_tween_map[card]
		if tween and tween.is_valid(): tween.kill()
		hover_tween_map.erase(card)

# ============ BOARD REFRESH ============
func _refresh_fish() -> void:
	if not battle_manager or not opponents_hbox: return
	
	# Get current fish state
	var active_fish: Array = []
	var active_slots: Dictionary = {}  # Track which slots should exist
	for i in battle_manager.NUM_SLOTS:
		var fish = battle_manager.fish_slots[i]
		if fish != null:
			active_fish.append({"fish": fish, "slot": i})
			active_slots[i] = true
	
	# Calculate new positions
	var card_spacing := CARD_W + CARD_SPACING_BOARD
	var total_width: float = active_fish.size() * CARD_W + (active_fish.size() - 1) * CARD_SPACING_BOARD
	var container_width: float = opponents_hbox.size.x if opponents_hbox.size.x > 0 else 1100.0
	var start_x: float = (container_width - total_width) / 2.0 + CARD_W / 2.0
	
	# Build a map of slot -> target position
	var slot_positions: Dictionary = {}
	var card_index := 0
	for data in active_fish:
		var slot: int = data["slot"]
		slot_positions[slot] = Vector2(start_x + card_index * card_spacing, CARD_H / 2.0)
		card_index += 1
	
	# Remove fish that no longer exist in battle_manager
	var slots_to_remove: Array = []
	for slot in fish_slot_map.keys():
		if not active_slots.has(slot):
			slots_to_remove.append(slot)
	
	for slot in slots_to_remove:
		var card = fish_slot_map[slot]
		if is_instance_valid(card):
			_stop_idle_animation(card)
			card.queue_free()
		fish_slot_map.erase(slot)
		if card in fish_cards:
			fish_cards.erase(card)
	
	# Check which fish need to be added
	var new_slots: Array = []
	for data in active_fish:
		var slot: int = data["slot"]
		if not fish_slot_map.has(slot):
			new_slots.append(data)
	
	# Slide existing fish to their new positions
	for slot in fish_slot_map.keys():
		if slot_positions.has(slot):
			var card = fish_slot_map[slot]
			if is_instance_valid(card) and card is Node2D:
				var target_pos: Vector2 = slot_positions[slot]
				if card.position.distance_to(target_pos) > 5.0:
					_stop_idle_animation(card)
					var tween := create_tween()
					tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
					tween.tween_property(card, "position", target_pos, 0.25)
					tween.finished.connect(func(): 
						if is_instance_valid(card): _start_idle_animation(card)
					)
	
	# Add new fish with entrance animation
	for data in new_slots:
		var fish = data["fish"]
		var slot: int = data["slot"]
		var card: Node = _make_card()
		if card == null: continue
		_setup_as_fish(card, fish, slot)
		opponents_hbox.add_child(card)
		if card is Node2D and slot_positions.has(slot):
			card.position = slot_positions[slot]
		fish_cards.append(card)
		fish_slot_map[slot] = card
		_animate_card_entrance(card, 0.0)
		_start_idle_animation_delayed(card, 0.3)

func _refresh_board() -> void:
	if not battle_manager or not home_cards_hbox: return
	
	# Get current board state
	var active_cards: Array = []
	var active_slots: Dictionary = {}  # Track which slots should exist
	for i in battle_manager.NUM_SLOTS:
		var card_inst = battle_manager.player_cards[i]
		if card_inst != null:
			active_cards.append({"inst": card_inst, "slot": i})
			active_slots[i] = true
	
	# Calculate new positions
	var card_spacing := CARD_W + CARD_SPACING_BOARD
	var total_width: float = active_cards.size() * CARD_W + (active_cards.size() - 1) * CARD_SPACING_BOARD
	var container_width: float = home_cards_hbox.size.x if home_cards_hbox.size.x > 0 else 1100.0
	var start_x: float = (container_width - total_width) / 2.0 + CARD_W / 2.0
	
	# Build a map of slot -> target position
	var slot_positions: Dictionary = {}
	var card_index := 0
	for data in active_cards:
		var slot: int = data["slot"]
		slot_positions[slot] = Vector2(start_x + card_index * card_spacing, CARD_H / 2.0)
		card_index += 1
	
	# Remove cards that no longer exist in battle_manager
	var slots_to_remove: Array = []
	for slot in board_slot_map.keys():
		if not active_slots.has(slot):
			slots_to_remove.append(slot)
	
	for slot in slots_to_remove:
		var card = board_slot_map[slot]
		# Only free if valid and not already queued for deletion (might be dissolving)
		if is_instance_valid(card) and not card.is_queued_for_deletion():
			_stop_idle_animation(card)
			card.queue_free()
		board_slot_map.erase(slot)
		if card in board_cards:
			board_cards.erase(card)
	
	# Check which cards need to be added OR UPDATED
	var new_slots: Array = []
	var update_slots: Array = []
	for data in active_cards:
		var slot: int = data["slot"]
		if not board_slot_map.has(slot):
			new_slots.append(data)
		else:
			# Check if card data has changed (swap occurred)
			var existing_card = board_slot_map[slot]
			if is_instance_valid(existing_card):
				var stored_card_name = existing_card.get_meta("card_name", "")
				if stored_card_name != data["inst"].data.card_name:
					# Card data changed - need to update visual
					update_slots.append(data)
	
	# Update cards whose data changed (swap occurred)
	for data in update_slots:
		var card_inst = data["inst"]
		var slot: int = data["slot"]
		var old_card = board_slot_map[slot]
		
		# Remove old card
		if is_instance_valid(old_card):
			_stop_idle_animation(old_card)
			old_card.queue_free()
			if old_card in board_cards:
				board_cards.erase(old_card)
		
		# Create new card with updated data
		var card: Node = _make_card()
		if card == null: continue
		_setup_as_board(card, card_inst, slot)
		card.set_meta("card_name", card_inst.data.card_name)  # Store for change detection
		home_cards_hbox.add_child(card)
		if card is Node2D and slot_positions.has(slot):
			card.position = slot_positions[slot]
		board_cards.append(card)
		board_slot_map[slot] = card
		_animate_card_entrance(card, 0.0)
		_start_idle_animation_delayed(card, 0.3)
	
	# Slide existing cards to their new positions
	for slot in board_slot_map.keys():
		if slot_positions.has(slot):
			var card = board_slot_map[slot]
			if is_instance_valid(card) and card is Node2D:
				var target_pos: Vector2 = slot_positions[slot]
				if card.position.distance_to(target_pos) > 5.0:
					_stop_idle_animation(card)
					var tween := create_tween()
					tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
					tween.tween_property(card, "position", target_pos, 0.25)
					tween.finished.connect(func(): 
						if is_instance_valid(card): _start_idle_animation(card)
					)
	
	# Add new cards with entrance animation
	for data in new_slots:
		var card_inst = data["inst"]
		var slot: int = data["slot"]
		var card: Node = _make_card()
		if card == null: continue
		_setup_as_board(card, card_inst, slot)
		card.set_meta("card_name", card_inst.data.card_name)  # Store for change detection
		home_cards_hbox.add_child(card)
		if card is Node2D and slot_positions.has(slot):
			card.position = slot_positions[slot]
		board_cards.append(card)
		board_slot_map[slot] = card
		_animate_card_entrance(card, 0.0)
		_start_idle_animation_delayed(card, 0.3)

# ============ CARD ANIMATIONS ============
func _animate_card_entrance(card: Node, delay: float) -> void:
	if card is Node2D:
		# Subtle fade-in with slight scale - no rotation
		card.scale = Vector2(0.95, 0.95)
		card.modulate.a = 0
		var tween := create_tween()
		tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(card, "scale", Vector2.ONE, 0.25).set_delay(delay)
		tween.parallel().tween_property(card, "modulate:a", 1.0, 0.2).set_delay(delay)

func _animate_card_draw(card: Node, delay: float) -> void:
	if card is Node2D:
		var original_y: float = card.position.y
		# Subtle slide up with fade
		card.position.y += 40
		card.modulate.a = 0
		var tween := create_tween()
		tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(card, "position:y", original_y, 0.25).set_delay(delay)
		tween.parallel().tween_property(card, "modulate:a", 1.0, 0.2).set_delay(delay)

func _animate_card_selected(card: Node, selected: bool) -> void:
	if not is_instance_valid(card): return
	_stop_hover_animation(card)
	_stop_idle_animation(card)
	var target_y := HAND_BASE_Y - HAND_HOVER_LIFT - 30 if selected else HAND_BASE_Y
	var target_scale := Vector2(1.15, 1.15) if selected else Vector2.ONE
	if card is Node2D: 
		card.z_index = 60 if selected else 0
		if selected:
			card.rotation_degrees = 0  # No rotation when selected
	var tween := create_tween()
	var trans := Tween.TRANS_ELASTIC if selected else Tween.TRANS_CUBIC
	tween.set_ease(Tween.EASE_OUT).set_trans(trans)
	tween.tween_property(card, "scale", target_scale, 0.3)
	tween.parallel().tween_property(card, "position:y", target_y, 0.2)
	if selected:
		tween.parallel().tween_property(card, "rotation_degrees", 0.0, 0.2)
	card.modulate = Color(1.2, 1.2, 0.8) if selected else Color.WHITE
	if not selected:
		tween.finished.connect(func(): if is_instance_valid(card): _start_idle_animation(card))

func _start_idle_animation(card: Node) -> void:
	if not is_instance_valid(card): 
		return
		
	_stop_idle_animation(card)
	
	# GUARD: Ensure we don't create a loop on an unsupported type
	if not (card is Node2D or card is Control):
		return

	# GUARD: Ensure the card has a position property we can animate
	if not "position" in card:
		return

	# CRITICAL FIX: Bind the tween to the CARD, not 'self'.
	# This ensures if the card is freed (died), the tween dies with it.
	var tween := card.create_tween()
	tween.set_loops()
	
	var float_amount := randf_range(3.0, 6.0)
	var float_duration := randf_range(2.0, 3.0)
	
	var base_y: float = card.position.y
	
	tween.tween_property(card, "position:y", base_y - float_amount, float_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(card, "position:y", base_y + float_amount, float_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	idle_tween_map[card] = tween

func _start_idle_animation_delayed(card: Node, delay: float) -> void:
	if not is_inside_tree():
		return
	await get_tree().create_timer(delay).timeout
	if is_instance_valid(card) and is_inside_tree(): 
		_start_idle_animation(card)

func _stop_idle_animation(card: Node) -> void:
	if idle_tween_map.has(card):
		var tween: Tween = idle_tween_map[card]
		if tween and tween.is_valid(): tween.kill()
		idle_tween_map.erase(card)

# Dissolve shader code - uses screen-space calculation for proper effect
const DISSOLVE_SHADER_CODE := """
shader_type canvas_item;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float edge_width : hint_range(0.0, 0.2) = 0.05;
uniform vec4 burn_color : source_color = vec4(1.0, 0.4, 0.1, 1.0);
uniform sampler2D noise_tex : repeat_enable;

void fragment() {
	vec4 tex_color = COLOR;
	float noise = texture(noise_tex, UV * 2.0).r;
	
	// Calculate dissolve threshold
	float threshold = progress * 1.4;  // Slightly overshoot to ensure full dissolve
	float edge = edge_width;
	
	// If noise is below threshold, dissolve (make transparent)
	if (noise < threshold - edge) {
		COLOR.a = 0.0;
	}
	// Edge glow effect
	else if (noise < threshold) {
		float edge_factor = 1.0 - (threshold - noise) / edge;
		COLOR.rgb = mix(burn_color.rgb, tex_color.rgb, edge_factor * 0.3);
		COLOR.a = tex_color.a * edge_factor;
	}
	// Normal rendering
	else {
		COLOR = tex_color;
	}
}
"""

var _dissolve_shader: Shader = null
var _noise_texture: NoiseTexture2D = null

func _get_dissolve_shader() -> Shader:
	if _dissolve_shader == null:
		_dissolve_shader = Shader.new()
		_dissolve_shader.code = DISSOLVE_SHADER_CODE
	return _dissolve_shader

func _get_noise_texture() -> NoiseTexture2D:
	if _noise_texture == null:
		_noise_texture = NoiseTexture2D.new()
		var noise := FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_CELLULAR
		noise.frequency = 0.08
		_noise_texture.noise = noise
		_noise_texture.width = 128
		_noise_texture.height = 128
		_noise_texture.seamless = true
		_noise_texture.generate_mipmaps = false  # Faster generation
	return _noise_texture

func _animate_card_dissolve(card: Node, on_complete: Callable = Callable()) -> void:
	if not is_instance_valid(card):
		if on_complete.is_valid():
			on_complete.call()
		return
	
	# Safety check - if card is already being freed, just call complete
	if card.is_queued_for_deletion():
		if on_complete.is_valid():
			on_complete.call()
		return
	
	# Store original position to keep card stationary
	var original_pos: Vector2 = card.position if card is Node2D else Vector2.ZERO
	var original_z: int = card.z_index if card is Node2D else 0
	
	# Raise z-index so dissolve appears above other cards
	if card is Node2D:
		card.z_index = 50
	
	# Get shader and texture - with safety fallback
	var shader := _get_dissolve_shader()
	var noise_tex := _get_noise_texture()
	
	# If shader or texture failed to create, use simple fade fallback
	if shader == null or noise_tex == null:
		var tween := create_tween()
		tween.tween_property(card, "modulate:a", 0.0, 0.4)
		tween.finished.connect(func():
			if is_instance_valid(card) and not card.is_queued_for_deletion():
				card.queue_free()
			if on_complete.is_valid():
				on_complete.call()
		)
		return
	
	# Create and configure the dissolve material
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("noise_tex", noise_tex)
	mat.set_shader_parameter("burn_color", Color(1.0, 0.5, 0.1, 1.0))
	mat.set_shader_parameter("progress", 0.0)
	mat.set_shader_parameter("edge_width", 0.08)
	
	# Collect all TextureRect/ColorRect nodes that need the dissolve effect
	# Skip nodes that already have custom shaders (like FishImageBackgroundEffect)
	var dissolve_nodes: Array[Node] = []
	var fade_nodes: Array[Node] = []  # Nodes with existing shaders - just fade these
	
	var front = card.get_node_or_null("Front")
	var front_gold = card.get_node_or_null("Front/FrontGold")
	var fish_image = card.get_node_or_null("FishImage")
	var fish_shadow = card.get_node_or_null("FishShadow")
	var fish_image_bg = card.get_node_or_null("FishImageBackground")
	var fish_image_bg_effect = card.get_node_or_null("FishImageBackground/FishImageBackgroundEffect")
	var card_shadow = card.get_node_or_null("CardShadow")
	
	# Add visual nodes - check if they already have custom materials/shaders
	if front and (front is TextureRect or front is ColorRect):
		dissolve_nodes.append(front)
	if front_gold and (front_gold is TextureRect or front_gold is ColorRect):
		dissolve_nodes.append(front_gold)
	if fish_image and (fish_image is TextureRect or fish_image is ColorRect):
		# Fish image might have a shader already
		if fish_image.material == null:
			dissolve_nodes.append(fish_image)
		else:
			fade_nodes.append(fish_image)
	if fish_shadow and (fish_shadow is TextureRect or fish_shadow is ColorRect):
		if fish_shadow.material == null:
			dissolve_nodes.append(fish_shadow)
		else:
			fade_nodes.append(fish_shadow)
	if fish_image_bg and (fish_image_bg is TextureRect or fish_image_bg is ColorRect):
		dissolve_nodes.append(fish_image_bg)
	# FishImageBackgroundEffect has a custom shader - just fade it
	if fish_image_bg_effect and (fish_image_bg_effect is TextureRect or fish_image_bg_effect is ColorRect):
		fade_nodes.append(fish_image_bg_effect)
	if card_shadow and (card_shadow is TextureRect or card_shadow is ColorRect):
		dissolve_nodes.append(card_shadow)
	
	# Also get all labels
	var labels: Array[Node] = []
	for label_name in ["FishName", "FishName2", "Bait", "Hook", "Line", "Sinker", "SinkerDesc"]:
		var lbl = card.get_node_or_null(label_name)
		if lbl and lbl is Label:
			labels.append(lbl)
	
	if dissolve_nodes.is_empty() and fade_nodes.is_empty():
		# Fallback: simple fade out if no visual nodes found
		var tween := create_tween()
		tween.tween_property(card, "modulate:a", 0.0, 0.4)
		tween.parallel().tween_property(card, "position:y", original_pos.y - 30, 0.4)
		tween.finished.connect(func():
			if is_instance_valid(card) and not card.is_queued_for_deletion():
				card.queue_free()
			if on_complete.is_valid():
				on_complete.call()
		)
		return
	
	# Apply dissolve material only to nodes without existing shaders
	# Wrap in try to catch any material assignment issues
	for node in dissolve_nodes:
		if is_instance_valid(node):
			var dup_mat = mat.duplicate()
			if dup_mat:
				node.material = dup_mat
	
	# Animate the dissolve
	var tween := create_tween()
	if not tween:
		# Tween creation failed - just free the card
		if is_instance_valid(card) and not card.is_queued_for_deletion():
			card.queue_free()
		if on_complete.is_valid():
			on_complete.call()
		return
	
	tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	
	# Keep position fixed while dissolving
	if card is Node2D:
		tween.tween_property(card, "position", original_pos, 0.0)
	
	# Animate progress from 0 to 1 - with safety checks in callback
	tween.tween_method(func(val: float):
		# Early exit if card is being deleted
		if not is_instance_valid(card) or card.is_queued_for_deletion():
			return
		for node in dissolve_nodes:
			if is_instance_valid(node) and not node.is_queued_for_deletion() and node.material:
				node.material.set_shader_parameter("progress", val)
		# Fade nodes with existing shaders (don't replace their material)
		for node in fade_nodes:
			if is_instance_valid(node) and not node.is_queued_for_deletion():
				node.modulate.a = 1.0 - val
		# Also fade labels
		for lbl in labels:
			if is_instance_valid(lbl) and not lbl.is_queued_for_deletion():
				lbl.modulate.a = 1.0 - val
	, 0.0, 1.0, 0.6)
	
	# Slight upward float while dissolving
	tween.parallel().tween_property(card, "position:y", original_pos.y - 20, 0.6)
	
	# Cleanup after animation and call callback
	tween.finished.connect(func():
		if is_instance_valid(card) and not card.is_queued_for_deletion():
			card.queue_free()
		if on_complete.is_valid():
			on_complete.call()
	)

func _make_card() -> Node:
	if CARD_SCENE: return CARD_SCENE.instantiate()
	return Node2D.new()

# ============ INPUT HANDLING ============
func _on_home_area_click(event: InputEvent) -> void:
	# This is now handled by _handle_board_slot_click in _input
	# Keep this for backwards compatibility but it may not trigger
	if not battle_manager: return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if selected_hand_index >= 0:
			# Find a slot to play to
			var slot := _calculate_slot_from_position(get_global_mouse_position())
			if slot >= 0 and battle_manager.play_card(selected_hand_index, slot):
				selected_hand_index = -1
				_hovered_hand_index = -1
				_last_hovered_index = -1

# ============ CARD SETUP ============

# Helper to get the correct front texture path based on bait and sinker
func _get_front_texture_path(has_bait: bool, has_sinker: bool, is_gold: bool = false) -> String:
	var base_path := "res://assets/cards/"
	if has_bait and has_sinker:
		return base_path + ("cardbaitsinkergold.png" if is_gold else "cardbaitsinker.png")
	elif has_bait and not has_sinker:
		return base_path + ("cardbaitnosinkergold.png" if is_gold else "cardbaitnosinker.png")
	elif not has_bait and has_sinker:
		return base_path + ("cardnobaitsinkergold.png" if is_gold else "cardnobaitsinker.png")
	else:  # no bait and no sinker
		return base_path + ("cardnobaitnosinkergold.png" if is_gold else "cardnobaitnosinker.png")

# Helper to update front textures on a card
func _update_front_texture(card: Node, has_bait: bool, has_sinker: bool) -> void:
	var front = card.get_node_or_null("Front")
	var front_gold = card.get_node_or_null("Front/FrontGold")
	
	if front:
		var front_path := _get_front_texture_path(has_bait, has_sinker, false)
		if ResourceLoader.exists(front_path):
			front.texture = load(front_path)
	
	if front_gold:
		var front_gold_path := _get_front_texture_path(has_bait, has_sinker, true)
		if ResourceLoader.exists(front_gold_path):
			front_gold.texture = load(front_gold_path)

# Helper to auto-scale label text if it's too wide
func _auto_scale_label(label: Label, max_width: float, default_font_size: int = 31, min_font_size: int = 16) -> void:
	if not label: return
	
	# Reset to default size first
	label.add_theme_font_size_override("font_size", default_font_size)
	
	# Get the font and measure text width
	var font = label.get_theme_font("font")
	var current_size = default_font_size
	
	# Keep position anchored
	var original_pos = label.position
	
	while current_size > min_font_size:
		var text_width = font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_CENTER, -1, current_size).x
		if text_width <= max_width:
			break
		current_size -= 2
	
	label.add_theme_font_size_override("font_size", current_size)
	label.position = original_pos

func _setup_as_fish(card: Node, fish_inst, slot: int) -> void:
	if fish_inst == null or fish_inst.data == null: return
	
	var front = card.get_node_or_null("Front")
	var back = card.get_node_or_null("Back")
	var fish_name_label = card.get_node_or_null("FishName")      # Used when has bait
	var fish_name_label_2 = card.get_node_or_null("FishName2")   # Used when no bait (wider)
	var bait_label = card.get_node_or_null("Bait")
	var hook_label = card.get_node_or_null("Hook")
	var line_label = card.get_node_or_null("Line")
	var sinker_label = card.get_node_or_null("Sinker")
	var sinker_desc = card.get_node_or_null("SinkerDesc")
	var fish_image = card.get_node_or_null("FishImage")
	var fish_shadow = card.get_node_or_null("FishShadow")
	var fish_image_bg = card.get_node_or_null("FishImageBackground")
	var fish_image_bg_effect = card.get_node_or_null("FishImageBackground/FishImageBackgroundEffect")
	
	# Show front, hide back
	if front: front.visible = true
	if back: back.visible = false
	
	# IMPORTANT: Show FishImageBackground and effect for all face-up cards
	if fish_image_bg: fish_image_bg.visible = true
	if fish_image_bg_effect: fish_image_bg_effect.visible = true
	
	# Fish don't have bait cost
	var has_bait := false
	var has_sinker: bool = fish_inst.data.sinker != "None" and fish_inst.data.sinker != ""
	
	# Update front texture based on bait/sinker
	_update_front_texture(card, has_bait, has_sinker)
	
	# Hide bait label for fish
	if bait_label: bait_label.visible = false
	
	# Fish have no bait, so use FishName2 (wider label)
	if fish_name_label: fish_name_label.visible = false
	if fish_name_label_2:
		fish_name_label_2.visible = true
		fish_name_label_2.text = fish_inst.data.fish_name if fish_inst.data.fish_name else "Fish"
		_auto_scale_label(fish_name_label_2, 180.0, 31, 16)  # FishName2 is wider (~186px)
	
	# Set Hook and Line values
	if hook_label: hook_label.text = str(fish_inst.data.hook)
	if line_label: line_label.text = str(fish_inst.current_line)
	
	# Handle sinker
	if sinker_label:
		sinker_label.visible = has_sinker
		if has_sinker:
			sinker_label.text = fish_inst.data.sinker
	if sinker_desc:
		sinker_desc.visible = has_sinker
		if has_sinker:
			sinker_desc.text = fish_inst.data.get_sinker_description() if fish_inst.data.has_method("get_sinker_description") else ""
	
	# Load fish image if available
	if fish_inst.data.texture:
		if fish_image: fish_image.texture = fish_inst.data.texture
		if fish_shadow: fish_shadow.texture = fish_inst.data.texture
	
	if not front: return
	
	# Add battle-specific visuals
	
	# Check if fish is hookable (current LINE <= rod strength)
	var is_hookable: bool = battle_manager and fish_inst.current_line <= battle_manager.get_rod_strength()
	
	# Hookable highlight (subtle yellow tint when hookable)
	if is_hookable:
		card.modulate = Color(1.1, 1.1, 0.7)
		# Add hookable indicator icon in top left corner
		_add_hookable_indicator(card)
	
	# Add glow effect when in hook mode and fish is hookable
	if hook_mode and is_hookable:
		_add_hookable_glow(card)
	
	# Click handling
	front.mouse_filter = Control.MOUSE_FILTER_STOP
	front.gui_input.connect(func(e): _fish_clicked(e, slot))


## Add hookable indicator icon (bait icon in top left corner that pops in and floats)
func _add_hookable_indicator(card: Node) -> void:
	# Remove existing indicator if present
	var existing = card.get_node_or_null("HookableIndicator")
	if existing:
		existing.queue_free()
	
	# Try to load the bait icon
	var bait_texture: Texture2D = null
	if ResourceLoader.exists("res://assets/gear/bait1.png"):
		bait_texture = load("res://assets/gear/bait1.png")
	
	if bait_texture == null:
		return  # No icon available
	
	# Create the indicator sprite
	var indicator := Sprite2D.new()
	indicator.name = "HookableIndicator"
	indicator.texture = bait_texture
	indicator.z_index = 10  # Above most card elements
	
	# Position in top left corner, slightly offset outward
	indicator.position = Vector2(-CARD_W / 2 - 10, -CARD_H / 2 - 10)
	
	# Start small and invisible for pop-in animation
	indicator.scale = Vector2(0.1, 0.1)
	indicator.modulate = Color(1.2, 1.1, 0.5, 0)  # Yellow tint, invisible
	
	card.add_child(indicator)
	
	# Pop-in animation
	var pop_tween := card.create_tween()
	pop_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	pop_tween.tween_property(indicator, "scale", Vector2(1.0, 1.0), 0.3)
	pop_tween.parallel().tween_property(indicator, "modulate:a", 1.0, 0.2)
	
	# Start floating animation after pop-in
	pop_tween.tween_callback(func():
		if is_instance_valid(indicator):
			_start_indicator_float(indicator)
	)


## Floating animation for hookable indicator
func _start_indicator_float(indicator: Sprite2D) -> void:
	if not is_instance_valid(indicator):
		return
	
	var base_y: float = indicator.position.y
	var float_tween := indicator.create_tween()
	float_tween.set_loops()
	float_tween.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	float_tween.tween_property(indicator, "position:y", base_y - 8, 0.6)
	float_tween.tween_property(indicator, "position:y", base_y + 3, 0.6)

func _setup_as_board(card: Node, card_inst, slot: int) -> void:
	if card_inst == null or card_inst.data == null: return
	
	var front = card.get_node_or_null("Front")
	var back = card.get_node_or_null("Back")
	var fish_name_label = card.get_node_or_null("FishName")      # Used when has bait
	var fish_name_label_2 = card.get_node_or_null("FishName2")   # Used when no bait (wider)
	var bait_label = card.get_node_or_null("Bait")
	var hook_label = card.get_node_or_null("Hook")
	var line_label = card.get_node_or_null("Line")
	var sinker_label = card.get_node_or_null("Sinker")
	var sinker_desc = card.get_node_or_null("SinkerDesc")
	var fish_image = card.get_node_or_null("FishImage")
	var fish_shadow = card.get_node_or_null("FishShadow")
	var fish_image_bg = card.get_node_or_null("FishImageBackground")
	var fish_image_bg_effect = card.get_node_or_null("FishImageBackground/FishImageBackgroundEffect")
	
	# Show front, hide back
	if front: front.visible = true
	if back: back.visible = false
	
	# IMPORTANT: Show FishImageBackground and effect for all face-up cards
	if fish_image_bg: fish_image_bg.visible = true
	if fish_image_bg_effect: fish_image_bg_effect.visible = true
	
	# Handle bait cost and name label
	var has_bait: bool = card_inst.data.bait_cost > 0
	var has_sinker: bool = card_inst.data.sinker != "None" and card_inst.data.sinker != ""
	
	# Update front texture based on bait/sinker
	_update_front_texture(card, has_bait, has_sinker)
	
	if bait_label:
		bait_label.visible = has_bait
		if has_bait:
			bait_label.text = str(card_inst.data.bait_cost)
	
	# Use FishName if has bait, FishName2 if no bait
	var card_name_text: String = card_inst.data.card_name if card_inst.data.card_name else "Card"
	if has_bait:
		if fish_name_label:
			fish_name_label.visible = true
			fish_name_label.text = card_name_text
			_auto_scale_label(fish_name_label, 150.0, 31, 16)  # FishName is narrower (~155px)
		if fish_name_label_2:
			fish_name_label_2.visible = false
	else:
		if fish_name_label:
			fish_name_label.visible = false
		if fish_name_label_2:
			fish_name_label_2.visible = true
			fish_name_label_2.text = card_name_text
			_auto_scale_label(fish_name_label_2, 180.0, 31, 16)  # FishName2 is wider (~186px)
	
	# Set Hook and Line values
	if hook_label: hook_label.text = str(card_inst.data.hook)
	if line_label: line_label.text = str(card_inst.current_line)
	
	# Handle sinker
	if sinker_label:
		sinker_label.visible = has_sinker
		if has_sinker:
			sinker_label.text = card_inst.data.sinker
	if sinker_desc:
		sinker_desc.visible = has_sinker
		if has_sinker:
			sinker_desc.text = CardDatabase.get_sinker_description_dynamic(card_inst.data.sinker, card_inst.data.sinker_power)
	
	# Load card image if available
	if card_inst.data.texture:
		if fish_image: fish_image.texture = card_inst.data.texture
		if fish_shadow: fish_shadow.texture = card_inst.data.texture
	
	if not front: return
	
	# Add battle-specific visuals
	
	# Highlight card if it can catch a fish this turn (card's HOOK >= any fish's current LINE)
	if battle_manager:
		var can_catch_fish := false
		for i in battle_manager.NUM_SLOTS:
			var fish = battle_manager.fish_slots[i]
			if fish != null and fish.data != null:
				if card_inst.data.hook >= fish.current_line:
					can_catch_fish = true
					break
		
		if can_catch_fish:
			# Subtle green glow for cards that can kill a fish
			card.modulate = Color(0.9, 1.15, 0.9)
	
	# Click handling
	front.mouse_filter = Control.MOUSE_FILTER_STOP
	front.gui_input.connect(func(e): _board_clicked(e, slot))

func _setup_as_hand(card: Node, card_data: CardData, index: int) -> void:
	if card_data == null: return
	
	var front = card.get_node_or_null("Front")
	var back = card.get_node_or_null("Back")
	var fish_name_label = card.get_node_or_null("FishName")      # Used when has bait
	var fish_name_label_2 = card.get_node_or_null("FishName2")   # Used when no bait (wider)
	var bait_label = card.get_node_or_null("Bait")
	var hook_label = card.get_node_or_null("Hook")
	var line_label = card.get_node_or_null("Line")
	var sinker_label = card.get_node_or_null("Sinker")
	var sinker_desc = card.get_node_or_null("SinkerDesc")
	var fish_image = card.get_node_or_null("FishImage")
	var fish_shadow = card.get_node_or_null("FishShadow")
	var fish_image_bg = card.get_node_or_null("FishImageBackground")
	var fish_image_bg_effect = card.get_node_or_null("FishImageBackground/FishImageBackgroundEffect")
	
	# Show front, hide back
	if front: front.visible = true
	if back: back.visible = false
	
	# IMPORTANT: Show FishImageBackground and effect for all face-up cards
	if fish_image_bg: fish_image_bg.visible = true
	if fish_image_bg_effect: fish_image_bg_effect.visible = true
	
	# Handle bait cost and name label
	var has_bait: bool = card_data.bait_cost > 0
	var has_sinker: bool = card_data.sinker != "None" and card_data.sinker != ""
	
	# Update front texture based on bait/sinker
	_update_front_texture(card, has_bait, has_sinker)
	
	if bait_label:
		bait_label.visible = has_bait
		if has_bait:
			bait_label.text = str(card_data.bait_cost)
	
	# Use FishName if has bait, FishName2 if no bait
	var card_name_text: String = card_data.card_name if card_data.card_name else "Card"
	if has_bait:
		if fish_name_label:
			fish_name_label.visible = true
			fish_name_label.text = card_name_text
			_auto_scale_label(fish_name_label, 150.0, 31, 16)  # FishName is narrower (~155px)
		if fish_name_label_2:
			fish_name_label_2.visible = false
	else:
		if fish_name_label:
			fish_name_label.visible = false
		if fish_name_label_2:
			fish_name_label_2.visible = true
			fish_name_label_2.text = card_name_text
			_auto_scale_label(fish_name_label_2, 180.0, 31, 16)  # FishName2 is wider (~186px)
	
	# Set Hook and Line values
	if hook_label: hook_label.text = str(card_data.hook)
	if line_label: line_label.text = str(card_data.line)
	
	# Handle sinker
	if sinker_label:
		sinker_label.visible = has_sinker
		if has_sinker:
			sinker_label.text = card_data.sinker
	if sinker_desc:
		sinker_desc.visible = has_sinker
		if has_sinker:
			sinker_desc.text = CardDatabase.get_sinker_description_dynamic(card_data.sinker, card_data.sinker_power)
	
	# Load card image if available
	if card_data.texture:
		if fish_image: fish_image.texture = card_data.texture
		if fish_shadow: fish_shadow.texture = card_data.texture
	
	if not front: return
	
	# Battle-specific: dim if can't afford
	var can_afford: bool = battle_manager.get_bait() >= card_data.bait_cost if battle_manager else true
	if not can_afford: card.modulate = Color(0.5, 0.5, 0.5)
	
	# IMPORTANT: Disable mouse on ALL child controls to prevent interference
	_disable_mouse_on_children(card)
	
	# Store the index in card metadata for stable reference
	card.set_meta("hand_index", index)

func _disable_mouse_on_children(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_disable_mouse_on_children(child)

func _load_texture(path: String) -> Texture2D:
	if path == "" or path == null:
		return null
	if ResourceLoader.exists(path):
		return load(path)
	return null

func _add_card_border(front: Node, color: Color) -> void:
	var existing := front.get_node_or_null("TeamBorder")
	if existing:
		existing.border_color = color
		return
	var border := ReferenceRect.new()
	border.name = "TeamBorder"
	border.border_color = color
	border.border_width = 3.0
	border.editor_only = false
	border.set_anchors_preset(Control.PRESET_FULL_RECT)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	front.add_child(border)

func _add_hookable_glow(card: Node) -> void:
	var front = card.get_node_or_null("Front")
	if not front: return
	var glow := ColorRect.new()
	glow.name = "HookableGlow"
	glow.color = Color(1, 1, 0, 0.3)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow.offset_left = -10
	glow.offset_top = -10
	glow.offset_right = 10
	glow.offset_bottom = 10
	front.add_child(glow)
	front.move_child(glow, 0)
	var tween := glow.create_tween()
	tween.set_loops()
	tween.tween_property(glow, "color:a", 0.5, 0.5).set_trans(Tween.TRANS_SINE)
	tween.tween_property(glow, "color:a", 0.2, 0.5).set_trans(Tween.TRANS_SINE)

func _fish_clicked(event: InputEvent, slot: int) -> void:
	if not event is InputEventMouseButton or not event.pressed: return
	if not battle_manager: return
	if event.button_index == MOUSE_BUTTON_LEFT and hook_mode:
		if battle_manager.try_hook_fish(slot):
			AudioManager.play_hook_selected()  # Bite sound when hooking fish
			hook_mode = false
			_update_hook_button()

func _board_clicked(event: InputEvent, slot: int) -> void:
	if not event is InputEventMouseButton or not event.pressed: return
	if not battle_manager: return
	if event.button_index == MOUSE_BUTTON_LEFT and selected_hand_index >= 0:
		if battle_manager.play_card(selected_hand_index, slot):
			AudioManager.play_card_deal()
			selected_hand_index = -1
			_hovered_hand_index = -1
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		if battle_manager.scrap_card_from_board(slot):
			AudioManager.play_card_flip()

func _handle_hand_click(event: InputEventMouseButton) -> bool:
	if hand_cards.is_empty():
		return false
	
	var mouse_pos := get_global_mouse_position()
	var clicked_index := -1
	var highest_z := -1000
	
	# Find which card was clicked using same logic as hover
	for i in range(hand_cards.size()):
		var card = hand_cards[i]
		if not is_instance_valid(card) or not card is Node2D:
			continue
		
		# Cast to Node2D for proper type inference
		var card_2d: Node2D = card as Node2D
		
		var card_global_pos: Vector2 = card_2d.global_position
		var card_scale: Vector2 = card_2d.scale
		var card_rotation: float = card_2d.rotation
		
		var local_mouse: Vector2 = mouse_pos - card_global_pos
		local_mouse = local_mouse.rotated(-card_rotation)
		local_mouse /= card_scale
		
		var half_w := CARD_W / 2.0
		var half_h := CARD_H / 2.0
		
		if local_mouse.x >= -half_w and local_mouse.x <= half_w and \
		   local_mouse.y >= -half_h and local_mouse.y <= half_h:
			var card_z: int = card_2d.z_index
			if card_z > highest_z:
				highest_z = card_z
				clicked_index = i
	
	if clicked_index >= 0:
		_hand_clicked(event, clicked_index)
		get_viewport().set_input_as_handled()
		return true
	
	return false

func _hand_clicked(event: InputEvent, index: int) -> void:
	if not event is InputEventMouseButton or not event.pressed: return
	if not battle_manager: return
	if event.button_index == MOUSE_BUTTON_LEFT:
		var old_selected := selected_hand_index
		selected_hand_index = -1 if selected_hand_index == index else index
		hook_mode = false
		
		# Play card select sound
		if selected_hand_index >= 0:
			AudioManager.play_card_move()
		else:
			AudioManager.play_ui_select()
		
		# Clear placement preview when selection changes
		_clear_placement_preview()
		
		if old_selected >= 0 and old_selected < hand_cards.size():
			_animate_card_selected(hand_cards[old_selected], false)
		if selected_hand_index >= 0 and selected_hand_index < hand_cards.size():
			_animate_card_selected(hand_cards[selected_hand_index], true)
		_update_hook_button()

func _handle_board_slot_click(event: InputEventMouseButton) -> void:
	if not battle_manager or not home_cards_hbox:
		return
	if selected_hand_index < 0:
		return
	
	var mouse_pos := get_global_mouse_position()
	
	# Check if click is in the board card area - detect which slot
	# First check existing board cards
	for slot in board_slot_map.keys():
		var card = board_slot_map[slot]
		if not is_instance_valid(card) or not card is Node2D:
			continue
		
		var card_2d: Node2D = card as Node2D
		var card_global_pos: Vector2 = card_2d.global_position
		var card_scale: Vector2 = card_2d.scale
		
		var local_mouse: Vector2 = mouse_pos - card_global_pos
		local_mouse /= card_scale
		
		var half_w := CARD_W / 2.0
		var half_h := CARD_H / 2.0
		
		if local_mouse.x >= -half_w and local_mouse.x <= half_w and \
		   local_mouse.y >= -half_h and local_mouse.y <= half_h:
			# Clicked on this board card - play to this slot (swap)
			_clear_placement_preview()
			if battle_manager.play_card(selected_hand_index, slot):
				AudioManager.play_card_deal()
				selected_hand_index = -1
				_hovered_hand_index = -1
				_last_hovered_index = -1
			get_viewport().set_input_as_handled()
			return
	
	# Check if click is in the home_cards_hbox area (for empty slots)
	var hbox_rect := home_cards_hbox.get_global_rect()
	hbox_rect.position.y -= 50
	hbox_rect.size.y += 100
	if hbox_rect.has_point(mouse_pos):
		# Find the slot based on position
		var slot := _calculate_slot_from_position(mouse_pos)
		if slot >= 0 and slot < battle_manager.NUM_SLOTS:
			_clear_placement_preview()
			if battle_manager.play_card(selected_hand_index, slot):
				AudioManager.play_card_deal()
				selected_hand_index = -1
				_hovered_hand_index = -1
				_last_hovered_index = -1
			get_viewport().set_input_as_handled()

func _calculate_slot_from_position(mouse_pos: Vector2) -> int:
	if not battle_manager or not home_cards_hbox:
		return -1
	
	# Get current board card positions
	var card_positions: Array = []  # Array of {slot: int, x: float}
	for slot in board_slot_map.keys():
		var card = board_slot_map[slot]
		if is_instance_valid(card) and card is Node2D:
			card_positions.append({"slot": slot, "x": card.global_position.x})
	
	# Sort by x position
	card_positions.sort_custom(func(a, b): return a.x < b.x)
	
	# If no cards on board, return leftmost empty slot (usually 0)
	if card_positions.is_empty():
		for i in battle_manager.NUM_SLOTS:
			if battle_manager.player_cards[i] == null:
				return i
		return 0
	
	var mouse_x := mouse_pos.x
	
	# Check if mouse is to the left of all cards
	if mouse_x < card_positions[0].x - CARD_W / 4:
		# Find empty slot to the left of the leftmost card
		var leftmost_slot: int = card_positions[0].slot
		for i in range(leftmost_slot - 1, -1, -1):
			if battle_manager.player_cards[i] == null:
				return i
		# No empty slot to the left, find any empty slot
		for i in battle_manager.NUM_SLOTS:
			if battle_manager.player_cards[i] == null:
				return i
		return leftmost_slot  # Swap with leftmost if no empty
	
	# Check if mouse is to the right of all cards
	if mouse_x > card_positions[-1].x + CARD_W / 4:
		# Find empty slot to the right of the rightmost card
		var rightmost_slot: int = card_positions[-1].slot
		for i in range(rightmost_slot + 1, battle_manager.NUM_SLOTS):
			if battle_manager.player_cards[i] == null:
				return i
		# No empty slot to the right, find any empty slot
		for i in range(battle_manager.NUM_SLOTS - 1, -1, -1):
			if battle_manager.player_cards[i] == null:
				return i
		return rightmost_slot  # Swap with rightmost if no empty
	
	# Mouse is in between cards - find which gap it's closest to
	for i in range(card_positions.size() - 1):
		var left_card: Dictionary = card_positions[i]
		var right_card: Dictionary = card_positions[i + 1]
		var left_x: float = left_card.x
		var right_x: float = right_card.x
		var midpoint: float = (left_x + right_x) / 2.0
		
		if mouse_x < midpoint:
			# Click is in the left half of this gap - place after left card
			for slot in range(left_card.slot + 1, right_card.slot):
				if battle_manager.player_cards[slot] == null:
					return slot
			# No empty slot in gap, return the left card's slot (swap)
			return left_card.slot
		elif mouse_x < right_x - CARD_W / 4:
			# Click is in the right half of this gap - place before right card
			for slot in range(right_card.slot - 1, left_card.slot, -1):
				if battle_manager.player_cards[slot] == null:
					return slot
			# No empty slot in gap, return the right card's slot (swap)
			return right_card.slot
	
	# Clicked on a card - find which one and return its slot (swap)
	var closest_slot := -1
	var closest_dist := INF
	
	for card_info in card_positions:
		var dist := absf(mouse_x - card_info.x)
		if dist < closest_dist:
			closest_dist = dist
			closest_slot = card_info.slot
	
	return closest_slot

func _update_placement_preview(mouse_pos: Vector2) -> void:
	# Only show preview when a hand card is selected
	if selected_hand_index < 0 or not battle_manager or not home_cards_hbox:
		_clear_placement_preview()
		return
	
	# Check if mouse is in the board area
	var hbox_rect := home_cards_hbox.get_global_rect()
	# Expand the rect a bit to make it easier to target
	hbox_rect.position.y -= 50
	hbox_rect.size.y += 100
	
	if not hbox_rect.has_point(mouse_pos):
		_clear_placement_preview()
		return
	
	# Calculate which slot we'd place to
	var target_slot := _calculate_slot_from_position(mouse_pos)
	if target_slot < 0:
		_clear_placement_preview()
		return
	
	# Show preview at target slot
	if target_slot != _placement_preview_slot:
		_placement_preview_slot = target_slot
		_show_placement_preview(target_slot)

func _show_placement_preview(target_slot: int) -> void:
	# Animate existing board cards to make room or show swap
	if not battle_manager:
		return
	
	var existing_card = battle_manager.player_cards[target_slot]
	
	if existing_card != null:
		# Will swap - highlight the card that will be swapped
		var card_ui = board_slot_map.get(target_slot)
		if card_ui and is_instance_valid(card_ui):
			# Pulse the card to show it will be swapped
			card_ui.modulate = Color(1.3, 1.3, 0.7)  # Yellow tint
	else:
		# Will insert - calculate and animate cards shifting
		_animate_cards_for_insertion(target_slot)

func _animate_cards_for_insertion(insert_slot: int) -> void:
	# For now, just highlight where the card will go
	# Future: animate cards sliding apart
	pass

func _clear_placement_preview() -> void:
	if _placement_preview_slot >= 0:
		# Reset any highlighted cards
		var card_ui = board_slot_map.get(_placement_preview_slot)
		if card_ui and is_instance_valid(card_ui):
			card_ui.modulate = Color.WHITE
		_placement_preview_slot = -1
	
	if _placement_ghost and is_instance_valid(_placement_ghost):
		_placement_ghost.queue_free()
		_placement_ghost = null

func _on_hook_pressed() -> void:
	if not battle_manager: return
	if battle_manager.can_hook():
		hook_mode = not hook_mode
		selected_hand_index = -1
		_hovered_hand_index = -1
		_update_hook_button()
		_smart_refresh_hand()
		if hook_mode:
			AudioManager.play_hook_mode()  # Hook mode activated sound
			_refresh_fish()
		else:
			AudioManager.play_ui_select()  # Cancelled hook mode

func _on_end_turn_pressed() -> void:
	if not battle_manager: return
	AudioManager.play_ui_confirm()
	selected_hand_index = -1
	_hovered_hand_index = -1
	hook_mode = false
	_update_hook_button()
	
	if end_turn_button:
		end_turn_button.disabled = true
	if hook_button:
		hook_button.disabled = true
		
	battle_manager.end_turn()

func _reenable_end_turn_button() -> void:
	if end_turn_button:
		end_turn_button.disabled = false
		if end_turn_button_label:
			end_turn_button_label.modulate = COL_NORMAL
	_update_hook_button()
