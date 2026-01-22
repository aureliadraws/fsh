extends Control
## Settlement Screen - Repair your boat at various nationality settlements
## If you've stolen from a nationality, their settlements will refuse to help

signal rest_completed(choice: String)

# Updated node paths for notebook layout
@onready var title_label: Label = $Title
@onready var description_label: Label = $RightPageContainer/Description
@onready var dialogue_label: Label = $RightPageContainer/Dialogue
@onready var boat_hp_label: Label = $RightPageContainer/BoatHP
@onready var heal_boat_button: Button = $RightPageContainer/Options/HealBoat
@onready var restore_card_button: Button = $RightPageContainer/Options/RestoreCard
@onready var skip_button: Button = $RightPageContainer/Skip
@onready var card_list: VBoxContainer = $RightPageContainer/CardScroll/CardList
@onready var close_button: Button = $CloseButton
@onready var effect_banner: TextureRect = $EffectBanner
@onready var effect_text: Label = $EffectText

# Effect banner positions
const EFFECT_SHOWN_X: float = 1223.0
const EFFECT_HIDDEN_X: float = 1438.0

# Nationalities
enum Nationality { NIGERIAN, BRITISH, INDONESIAN, INDIAN, JAMAICAN }

const NATIONALITY_NAMES := {
	Nationality.NIGERIAN: "Nigerian",
	Nationality.BRITISH: "British",
	Nationality.INDONESIAN: "Indonesian",
	Nationality.INDIAN: "Indian",
	Nationality.JAMAICAN: "Jamaican"
}

# Settlement names per nationality
const SETTLEMENT_NAMES := {
	Nationality.NIGERIAN: ["Eko Outpost", "Lagos Trading Post", "Badagry Harbor", "Calabar Dock"],
	Nationality.BRITISH: ["Port Edward", "Victoria Landing", "Crown's Rest", "Queenspoint"],
	Nationality.INDONESIAN: ["Pelabuhan Baru", "Kampung Nelayan", "Jawa Wharf", "Pulau Kecil Dock"],
	Nationality.INDIAN: ["Kerala Landing", "Madras Pier", "Goa Harbour", "Bengal Trading Post"],
	Nationality.JAMAICAN: ["Port Royal Rest", "Kingston Cove", "Maroon Harbor", "Ochi Docks"]
}

# Welcome dialogue per nationality
const WELCOME_DIALOGUE := {
	Nationality.NIGERIAN: [
		"\"Welcome, traveler! Come in, come in. You look like you've been through a lot. Let us help you.\"",
		"\"Hello! Another soul on the water. We're always happy to help those passing through.\"",
		"\"Welcome to our village. If you need repairs, our craftsmen are happy to assist - no charge.\""
	],
	Nationality.BRITISH: [
		"\"...What do you want? We don't have anything to spare. Just keep moving.\"",
		"\"Another scavenger? No, we don't serve outsiders. Find help somewhere else.\"",
		"\"This settlement is for our people only. You're not welcome here.\""
	],
	Nationality.INDONESIAN: [
		"\"Hello, friend! Welcome to our dock. We can help repair your boat for a reasonable price.\"",
		"\"Welcome! Our village is small, but our craftsmen do good work. How can we help?\"",
		"\"Good to see a friendly face. If your boat needs repairs, we can help you out.\""
	],
	Nationality.INDIAN: [
		"\"Welcome to our trading post! We offer repairs at fair prices. How can we assist you?\"",
		"\"Hello there! You look like you could use some help. Our workers are skilled and affordable.\"",
		"\"Greetings, traveler. We're happy to help repair your vessel for a small fee.\""
	],
	Nationality.JAMAICAN: [
		"\"Hey, welcome! Looking a bit rough there. We can fix up your boat if you need.\"",
		"\"What's up! Good to see another fisher. Need any repairs? We've got you covered.\"",
		"\"Welcome to the dock! Our crew can patch up just about anything. What do you need?\""
	]
}

# Refusal dialogue when you've stolen from their people
const REFUSAL_DIALOGUE := {
	Nationality.NIGERIAN: "The elder's face falls. \"We've heard what you did to one of our fishermen. I'm sorry, but we can't help you. Please leave.\"",
	Nationality.BRITISH: "\"We don't serve outsiders. Especially not now. Leave us alone.\"",
	Nationality.INDONESIAN: "The dockmaster shakes his head. \"Word reached us about what you did. We can't help someone who treats others that way. Please go.\"",
	Nationality.INDIAN: "\"We heard about your actions on the water. I'm afraid we can't do business with you. You should leave.\"",
	Nationality.JAMAICAN: "\"Look, we heard what happened. That's not cool. We can't help you - you need to sort yourself out first.\""
}

# British always refuse service - they're hostile survivors
const BRITISH_ALWAYS_REFUSE := true

var boat_hp: int = 3
var max_boat_hp: int = 3
var damaged_cards: Array = []
var current_nationality: Nationality
var player_cowries: int = 0
var repair_cost: int = 15
var stolen_from_nationalities: Array = []
var is_refused: bool = false


func _ready() -> void:
	visible = false
	heal_boat_button.pressed.connect(_on_heal_boat)
	restore_card_button.pressed.connect(_on_restore_card)
	skip_button.pressed.connect(_on_skip)
	
	# Connect hover sounds
	heal_boat_button.mouse_entered.connect(_on_button_hover)
	restore_card_button.mouse_entered.connect(_on_button_hover)
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
	if has_node("/root/AudioManager"):
		AudioManager.play_ui_select()


func show_rest(current_boat_hp: int, max_hp: int, cards_with_damage: Array, cowries: int = 0, stolen_nations: Array = []) -> void:
	boat_hp = current_boat_hp
	max_boat_hp = max_hp
	damaged_cards = cards_with_damage
	player_cowries = cowries
	stolen_from_nationalities = stolen_nations
	
	# Pick a random nationality for this settlement
	current_nationality = Nationality.values()[randi() % Nationality.size()]
	
	# Check if we've stolen from this nationality
	is_refused = current_nationality in stolen_from_nationalities
	
	_update_display()
	visible = true


func _update_display() -> void:
	# Settlement name
	var names: Array = SETTLEMENT_NAMES[current_nationality]
	var settlement_name: String = names[randi() % names.size()]
	title_label.text = settlement_name
	
	# British always refuse service
	var british_refuses := current_nationality == Nationality.BRITISH
	
	# Hide damaged cards list - feature removed
	if card_list:
		for child in card_list.get_children():
			child.queue_free()
		card_list.visible = false
	
	# Hide restore card button - feature removed
	if restore_card_button:
		restore_card_button.visible = false
	
	if is_refused or british_refuses:
		# They refuse to help us
		description_label.text = NATIONALITY_NAMES[current_nationality] + " Settlement"
		if dialogue_label:
			dialogue_label.text = REFUSAL_DIALOGUE[current_nationality]
			dialogue_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
		
		heal_boat_button.visible = false
		
		if british_refuses and not is_refused:
			boat_hp_label.text = "They refuse to help outsiders."
		else:
			boat_hp_label.text = "They will not help you."
		
		skip_button.text = "Leave"
	else:
		# Normal service
		description_label.text = NATIONALITY_NAMES[current_nationality] + " Settlement"
		
		# Random welcome dialogue
		var dialogues: Array = WELCOME_DIALOGUE[current_nationality]
		if dialogue_label:
			dialogue_label.text = dialogues[randi() % dialogues.size()]
			dialogue_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.7))
		
		# Nigerians offer free service
		var is_free := current_nationality == Nationality.NIGERIAN
		var cost := 0 if is_free else repair_cost
		
		if is_free:
			boat_hp_label.text = "Boat HP: %d / %d | Service: FREE" % [boat_hp, max_boat_hp]
		else:
			boat_hp_label.text = "Boat HP: %d / %d | Cowries: %d" % [boat_hp, max_boat_hp, player_cowries]
		
		heal_boat_button.visible = true
		
		# Heal boat option
		var can_afford := is_free or player_cowries >= cost
		if boat_hp < max_boat_hp:
			heal_boat_button.disabled = not can_afford
			if is_free:
				heal_boat_button.text = "Repair Boat (+1 HP) - FREE"
			else:
				heal_boat_button.text = "Repair Boat (+1 HP) - %d Cowries" % cost
			if not can_afford:
				heal_boat_button.tooltip_text = "Not enough cowries"
		else:
			heal_boat_button.disabled = true
			heal_boat_button.text = "Boat at full health"
		
		skip_button.text = "Leave"


func _on_heal_boat() -> void:
	if has_node("/root/AudioManager"):
		AudioManager.play_ui_confirm()
	visible = false
	rest_completed.emit("heal_boat")


func _on_restore_card() -> void:
	if has_node("/root/AudioManager"):
		AudioManager.play_ui_confirm()
	visible = false
	rest_completed.emit("restore_cards")


func _on_skip() -> void:
	if has_node("/root/AudioManager"):
		AudioManager.play_ui_confirm()
	visible = false
	rest_completed.emit("skip")


## Get the repair cost (for the game manager to deduct cowries)
func get_repair_cost() -> int:
	# Nigerians offer free service
	if current_nationality == Nationality.NIGERIAN:
		return 0
	return repair_cost


## Check if current settlement offers free service
func is_service_free() -> bool:
	return current_nationality == Nationality.NIGERIAN


## Check if current settlement refuses service
func is_service_refused() -> bool:
	return current_nationality == Nationality.BRITISH or is_refused


## Get current settlement nationality (for tracking)
func get_settlement_nationality() -> Nationality:
	return current_nationality
