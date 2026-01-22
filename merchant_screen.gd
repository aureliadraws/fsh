extends Control
## Merchant Screen - Buy cards (common/uncommon tier)
## Merchant offers medium-quality cards at medium prices

signal merchant_completed(result: Dictionary)

# Updated node paths for notebook layout
@onready var cowrie_label: Label = $CowriesLabel
@onready var shop_list: GridContainer = $LeftPageContainer/ShopScroll/ShopList
@onready var deck_list: VBoxContainer = $RightPageContainer/DeckScroll/DeckList
@onready var message_label: Label = $RightPageContainer/Message
@onready var done_button: Button = $RightPageContainer/Done
@onready var close_button: Button = $CloseButton
@onready var effect_banner: TextureRect = $EffectBanner
@onready var effect_text: Label = $EffectText

const CARD_LAYOUT_SCENE := preload("res://scenes/roguelike/card layout.tscn")
const SELL_VALUE := 8  # Cowries per card sold

# Effect banner positions
const EFFECT_SHOWN_X: float = 1223.0
const EFFECT_HIDDEN_X: float = 1438.0

# Price ranges by rarity
const PRICES := {
	"common": {"min": 15, "max": 25},
	"uncommon": {"min": 30, "max": 50}
}

var cowries: int = 0
var shop_inventory: Array = []  # Array of {card: CardData, price: int}
var player_deck: Array = []
var cards_bought: Array = []
var cards_sold: Array = []


func _ready() -> void:
	visible = false
	done_button.pressed.connect(_on_done)
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


func show_merchant(current_cowries: int, deck: Array) -> void:
	cowries = current_cowries
	player_deck = deck.duplicate()
	cards_bought.clear()
	cards_sold.clear()
	if message_label:
		message_label.text = ""
	
	# Generate merchant inventory (2 common, 2 uncommon cards + 2 buffs)
	shop_inventory.clear()
	
	var common_pool := CardDatabase.get_cards_by_rarity("common")
	var uncommon_pool := CardDatabase.get_cards_by_rarity("uncommon")
	
	common_pool.shuffle()
	uncommon_pool.shuffle()
	
	# Add 2 common cards
	for i in mini(2, common_pool.size()):
		var card_data: Dictionary = common_pool[i]
		var card = CardDatabase.create_card_data(card_data.name)
		if card:
			var price: int = randi_range(PRICES.common.min, PRICES.common.max)
			shop_inventory.append({"card": card, "price": price, "rarity": "common", "type": "card"})
	
	# Add 2 uncommon cards
	for i in mini(2, uncommon_pool.size()):
		var card_data: Dictionary = uncommon_pool[i]
		var card = CardDatabase.create_card_data(card_data.name)
		if card:
			var price: int = randi_range(PRICES.uncommon.min, PRICES.uncommon.max)
			shop_inventory.append({"card": card, "price": price, "rarity": "uncommon", "type": "card"})
	
	# Add 2 random buffs from GameState.AVAILABLE_BUFFS
	if GameState and GameState.AVAILABLE_BUFFS.size() > 0:
		var available_buffs := GameState.AVAILABLE_BUFFS.duplicate()
		available_buffs.shuffle()
		for i in mini(2, available_buffs.size()):
			var buff: Dictionary = available_buffs[i]
			# Use buff's built-in price with small random variance (+/- 10%)
			var base_price: int = buff.get("price", 100)
			var variance: int = int(base_price * 0.1)
			var price: int = base_price + randi_range(-variance, variance)
			shop_inventory.append({
				"buff": buff, 
				"price": price, 
				"rarity": "buff", 
				"type": "buff"
			})
	
	_update_display()
	visible = true


func _update_display() -> void:
	if cowrie_label:
		cowrie_label.text = "Cowries: %d" % cowries
	
	# Shop items
	if shop_list:
		for child in shop_list.get_children():
			child.queue_free()
	
	for i in shop_inventory.size():
		var item: Dictionary = shop_inventory[i]
		var price: int = item.price
		var rarity: String = item.get("rarity", "common")
		var item_type: String = item.get("type", "card")
		
		var vbox := VBoxContainer.new()
		vbox.custom_minimum_size = Vector2(280, 420)
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 10)
		if shop_list:
			shop_list.add_child(vbox)
		
		if item_type == "buff":
			# Display buff item
			var buff: Dictionary = item.get("buff", {})
			var buff_price: int = buff.get("price", 100)
			
			# Determine tier based on price
			var tier_text: String = "BUFF"
			var tier_color: Color = Color(0.8, 0.6, 1.0)
			if buff_price >= 300:
				tier_text = "RARE BUFF"
				tier_color = Color(1.0, 0.8, 0.2)  # Gold
			elif buff_price >= 180:
				tier_text = "STRONG BUFF"
				tier_color = Color(0.4, 0.8, 1.0)  # Cyan
			elif buff_price >= 100:
				tier_text = "BUFF"
				tier_color = Color(0.6, 1.0, 0.6)  # Green
			else:
				tier_text = "MINOR BUFF"
				tier_color = Color(0.8, 0.8, 0.8)  # Gray
			
			# Buff header
			var rarity_lbl := Label.new()
			rarity_lbl.text = tier_text
			rarity_lbl.add_theme_color_override("font_color", tier_color)
			rarity_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			rarity_lbl.add_theme_font_size_override("font_size", 32)
			vbox.add_child(rarity_lbl)
			
			# Buff panel
			var buff_panel := PanelContainer.new()
			buff_panel.custom_minimum_size = Vector2(260, 320)
			var style := StyleBoxFlat.new()
			style.bg_color = Color(0.2, 0.15, 0.3, 0.9)
			style.corner_radius_top_left = 10
			style.corner_radius_top_right = 10
			style.corner_radius_bottom_left = 10
			style.corner_radius_bottom_right = 10
			style.border_width_left = 3
			style.border_width_right = 3
			style.border_width_top = 3
			style.border_width_bottom = 3
			style.border_color = Color(0.6, 0.4, 0.8)
			buff_panel.add_theme_stylebox_override("panel", style)
			vbox.add_child(buff_panel)
			
			var buff_vbox := VBoxContainer.new()
			buff_vbox.add_theme_constant_override("separation", 20)
			buff_panel.add_child(buff_vbox)
			
			# Buff name
			var name_lbl := Label.new()
			name_lbl.text = buff.get("name", "Unknown Buff")
			name_lbl.add_theme_font_size_override("font_size", 32)
			name_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
			name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			buff_vbox.add_child(name_lbl)
			
			# Buff description
			var desc_lbl := Label.new()
			desc_lbl.text = buff.get("desc", "No description")
			desc_lbl.add_theme_font_size_override("font_size", 28)
			desc_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
			desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			buff_vbox.add_child(desc_lbl)
			
			# Effect type indicator
			var effect_lbl := Label.new()
			effect_lbl.text = "[Permanent]"
			effect_lbl.add_theme_font_size_override("font_size", 24)
			effect_lbl.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
			effect_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			buff_vbox.add_child(effect_lbl)
			
			# Buy button
			var buy_btn := Button.new()
			buy_btn.text = "BUY - %d" % price
			buy_btn.custom_minimum_size = Vector2(200, 50)
			buy_btn.add_theme_font_size_override("font_size", 28)
			buy_btn.disabled = cowries < price
			buy_btn.pressed.connect(_on_buy_buff.bind(i))
			buy_btn.mouse_entered.connect(_on_button_hover)
			vbox.add_child(buy_btn)
		else:
			# Display card item (existing code)
			var card: CardData = item.get("card")
			if card == null:
				continue
			
			# Rarity indicator
			var rarity_lbl := Label.new()
			if rarity == "uncommon":
				rarity_lbl.text = "UNCOMMON"
				rarity_lbl.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
			else:
				rarity_lbl.text = "COMMON"
				rarity_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
			rarity_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			rarity_lbl.add_theme_font_size_override("font_size", 32)
			vbox.add_child(rarity_lbl)
			
			# Create a CenterContainer to hold the card
			var card_holder := CenterContainer.new()
			card_holder.custom_minimum_size = Vector2(280, 380)
			vbox.add_child(card_holder)
			
			# Create SubViewport to properly render Node2D card
			var viewport := SubViewport.new()
			viewport.size = Vector2i(280, 380)
			viewport.transparent_bg = true
			viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			
			# Create the card display using the scene at FULL SCALE
			var card_display: Node2D = CARD_LAYOUT_SCENE.instantiate()
			# Card origin is at center, so position it at viewport center
			card_display.position = Vector2(140, 190)  # Center of 280x380 viewport
			viewport.add_child(card_display)
			
			# Wrap viewport in container
			var viewport_container := SubViewportContainer.new()
			viewport_container.custom_minimum_size = Vector2(280, 380)
			viewport_container.stretch = true
			viewport_container.add_child(viewport)
			card_holder.add_child(viewport_container)
			
			# Setup the card with data
			if card_display.has_method("setup"):
				card_display.setup(card)
			# Ensure proper colors for shop display
			_setup_shop_card_manually(card_display, card)
			
			# Buy button
			var buy_btn := Button.new()
			buy_btn.text = "BUY - %d" % price
			buy_btn.custom_minimum_size = Vector2(200, 50)
			buy_btn.add_theme_font_size_override("font_size", 28)
			buy_btn.disabled = cowries < price
			buy_btn.pressed.connect(_on_buy_card.bind(i))
			buy_btn.mouse_entered.connect(_on_button_hover)
			vbox.add_child(buy_btn)
	
	# Player deck (for selling)
	if deck_list:
		for child in deck_list.get_children():
			child.queue_free()
	
	for i in player_deck.size():
		var card: CardData = player_deck[i]
		if card == null:
			continue
		var hbox := HBoxContainer.new()
		if deck_list:
			deck_list.add_child(hbox)
		
		var lbl := Label.new()
		lbl.text = "%s (H:%d L:%d)" % [card.card_name, card.hook, card.line]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(lbl)
		
		var sell_btn := Button.new()
		sell_btn.text = "Sell (%d)" % SELL_VALUE
		sell_btn.pressed.connect(_on_sell_card.bind(i))
		sell_btn.mouse_entered.connect(_on_button_hover)
		hbox.add_child(sell_btn)


func _on_buy_card(index: int) -> void:
	if index < 0 or index >= shop_inventory.size():
		return
	
	var item: Dictionary = shop_inventory[index]
	var price: int = item.price
	
	if cowries < price:
		AudioManager.play_ui_select()
		if message_label:
			message_label.text = "Not enough cowries! Need %d, have %d" % [price, cowries]
		return
	
	AudioManager.play_card_deal()
	cowries -= price
	
	var card: CardData = item.get("card")
	if card == null:
		return
	cards_bought.append(card)
	player_deck.append(card)
	
	# Notify GameState
	if has_node("/root/GameState"):
		GameState.add_run_salvage_card(card)
	
	# Remove from shop
	shop_inventory.remove_at(index)
	
	if message_label:
		message_label.text = "Bought %s! Cowries remaining: %d" % [card.card_name, cowries]
	
	_show_effect_notification("Bought: %s" % card.card_name)
	
	# Force update display to refresh cowrie label
	_update_display()


func _on_buy_buff(index: int) -> void:
	if index < 0 or index >= shop_inventory.size():
		return
	
	var item: Dictionary = shop_inventory[index]
	var price: int = item.price
	
	if cowries < price:
		AudioManager.play_ui_select()
		if message_label:
			message_label.text = "Not enough cowries! Need %d, have %d" % [price, cowries]
		return
	
	AudioManager.play_ui_confirm()
	cowries -= price
	
	var buff: Dictionary = item.get("buff", {})
	if buff.is_empty():
		return
	
	# Add buff to GameState permanent_buffs
	if has_node("/root/GameState"):
		GameState.permanent_buffs.append(buff)
		GameState.buff_applied.emit(buff.get("name", "Unknown"))
		GameState.save_persistent_data()
	
	# Remove from shop
	shop_inventory.remove_at(index)
	
	var buff_name: String = buff.get("name", "Unknown")
	if message_label:
		message_label.text = "Acquired %s! Cowries remaining: %d" % [buff_name, cowries]
	
	_show_effect_notification("Buff: %s" % buff_name)
	
	# Force update display
	_update_display()


func _on_sell_card(deck_index: int) -> void:
	if player_deck.size() <= 3:
		AudioManager.play_ui_select()
		if message_label:
			message_label.text = "Can't sell - need at least 3 cards!"
		return
	
	if deck_index < 0 or deck_index >= player_deck.size():
		return
	
	AudioManager.play_card_flip()
	var card: CardData = player_deck[deck_index]
	if card == null:
		return
	cards_sold.append(card)
	player_deck.remove_at(deck_index)
	cowries += SELL_VALUE
	
	if message_label:
		message_label.text = "Sold %s for %d cowries!" % [card.card_name, SELL_VALUE]
	_update_display()


func _on_done() -> void:
	AudioManager.play_ui_confirm()
	visible = false
	merchant_completed.emit({
		"cowries": cowries,
		"bought": cards_bought,
		"sold": cards_sold,
		"deck": player_deck
	})


## Ensure shop card has proper colors (dark blue for all stats)
func _setup_shop_card_manually(card_display: Node, card: CardData) -> void:
	# The dark blue color used in the card layout
	const CARD_TEXT_COLOR := Color(0, 0.043137256, 0.18039216, 1)
	
	# Get the label nodes
	var line_label = card_display.get_node_or_null("Line")
	var hook_label = card_display.get_node_or_null("Hook")
	var bait_label = card_display.get_node_or_null("Bait")
	var fish_name_label = card_display.get_node_or_null("FishName")
	var fish_name_label_2 = card_display.get_node_or_null("FishName2")
	var sinker_label = card_display.get_node_or_null("Sinker")
	var sinker_desc_label = card_display.get_node_or_null("SinkerDesc")
	var fish_image_bg = card_display.get_node_or_null("FishImageBackground")
	var fish_image_bg_effect = card_display.get_node_or_null("FishImageBackground/FishImageBackgroundEffect")
	var front = card_display.get_node_or_null("Front")
	var front_gold = card_display.get_node_or_null("Front/FrontGold")
	
	# Ensure FishImageBackground is visible
	if fish_image_bg: fish_image_bg.visible = true
	if fish_image_bg_effect: fish_image_bg_effect.visible = true
	
	# Update front texture based on bait/sinker
	var has_bait: bool = card.bait_cost > 0
	var has_sinker: bool = card.sinker != "" and card.sinker != "None"
	_update_card_front_texture(front, front_gold, has_bait, has_sinker)
	
	# Reset color overrides to ensure dark blue is used
	if line_label:
		line_label.remove_theme_color_override("font_color")
		line_label.add_theme_color_override("font_color", CARD_TEXT_COLOR)
	if hook_label:
		hook_label.remove_theme_color_override("font_color")
		hook_label.add_theme_color_override("font_color", CARD_TEXT_COLOR)
	if bait_label:
		bait_label.remove_theme_color_override("font_color")
		bait_label.add_theme_color_override("font_color", CARD_TEXT_COLOR)
	if fish_name_label:
		fish_name_label.remove_theme_color_override("font_color")
		fish_name_label.add_theme_color_override("font_color", CARD_TEXT_COLOR)
	if fish_name_label_2:
		fish_name_label_2.remove_theme_color_override("font_color")
		fish_name_label_2.add_theme_color_override("font_color", CARD_TEXT_COLOR)
	if sinker_label:
		sinker_label.remove_theme_color_override("font_color")
		sinker_label.add_theme_color_override("font_color", CARD_TEXT_COLOR)
	if sinker_desc_label:
		sinker_desc_label.remove_theme_color_override("font_color")
		sinker_desc_label.add_theme_color_override("font_color", CARD_TEXT_COLOR)


func _update_card_front_texture(front: TextureRect, front_gold: TextureRect, has_bait: bool, has_sinker: bool) -> void:
	var base_path := "res://assets/cards/"
	var front_path: String
	var gold_path: String
	
	if has_bait and has_sinker:
		front_path = base_path + "cardbaitsinker.png"
		gold_path = base_path + "cardbaitsinkergold.png"
	elif has_bait and not has_sinker:
		front_path = base_path + "cardbaitnosinker.png"
		gold_path = base_path + "cardbaitnosinkergold.png"
	elif not has_bait and has_sinker:
		front_path = base_path + "cardnobaitsinker.png"
		gold_path = base_path + "cardnobaitsinkergold.png"
	else:
		front_path = base_path + "cardnobaitnosinker.png"
		gold_path = base_path + "cardnobaitnosinkergold.png"
	
	if front and ResourceLoader.exists(front_path):
		front.texture = load(front_path)
	if front_gold and ResourceLoader.exists(gold_path):
		front_gold.texture = load(gold_path)
