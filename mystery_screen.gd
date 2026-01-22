extends Control
## Mystery Events - Random encounters on the waters
## Includes: Other fishers, Friendly fish, Loregivers, Shipbuilders, Abandoned settlements

signal event_completed(result: Dictionary)

@onready var title_label: Label = $EncounterName
@onready var description_label: Label = $RightPageContainer/Description
@onready var choices_container: VBoxContainer = $RightPageContainer/Choices
@onready var result_label: Label = $RightPageContainer/Result
@onready var continue_button: Button = $RightPageContainer/Continue
@onready var cowries_label: Label = $CowriesLabel
@onready var effect_banner: TextureRect = $EffectBanner
@onready var effect_text: Label = $EffectText
@onready var close_button: Button = $CloseButton
@onready var image_placeholder: TextureRect = $LeftPageContainer/ImagePlaceholder

const CARD_LAYOUT_SCENE := preload("res://scenes/roguelike/card layout.tscn")

const EFFECT_SHOWN_X: float = 1223.0
const EFFECT_HIDDEN_X: float = 1438.0

var offered_trade_card: Dictionary = {}

enum Nationality { NIGERIAN, BRITISH, INDONESIAN, INDIAN, JAMAICAN }

const NATIONALITY_NAMES := {
	Nationality.NIGERIAN: "Nigerian",
	Nationality.BRITISH: "British",
	Nationality.INDONESIAN: "Indonesian",
	Nationality.INDIAN: "Indian",
	Nationality.JAMAICAN: "Jamaican"
}

# Greeting lines per nationality
const FISHER_GREETINGS := {
	Nationality.NIGERIAN: [
		"\"Good morning! I'm Adebayo. These waters have been kind today - plenty of fish running.\"",
		"\"Hello there! Name's Chidi. Always nice to see another boat out here.\"",
		"\"Welcome, friend. I'm Emeka. The currents brought us together, it seems.\""
	],
	Nationality.BRITISH: [
		"\"...Another one come to pick over the bones, have you? I'm Reginald. What do you want?\"",
		"\"Stay back. I've nothing left worth taking. Thomas is my name, not that it matters anymore.\"",
		"\"You're not one of them, are you? The ones who... nevermind. I'm William. State your business.\""
	],
	Nationality.INDONESIAN: [
		"\"Hello! I am Budi, from Java originally. These waters remind me of home, in some ways.\"",
		"\"Ah, good to meet you! I'm Wayan. My family has been fishing for generations.\"",
		"\"Greetings, friend. I'm Ketut. Looking for good fishing spots? I might know a few.\""
	],
	Nationality.INDIAN: [
		"\"Hello there! I'm Arjun, originally from Kerala. The fishing here is quite different from back home.\"",
		"\"Welcome! Rajan here. It's good to see a friendly face on these waters.\"",
		"\"Greetings! I'm Suresh. My grandfather used to tell stories about these trade routes.\""
	],
	Nationality.JAMAICAN: [
		"\"Hey there! I'm Desmond. Long way from home, but the sea is the sea, you know?\"",
		"\"What's happening! Winston here. These waters are different, but fish are fish.\"",
		"\"Good to meet you! Call me Marcus. Always happy to see another fisher out here.\""
	]
}

# Steal success/fail lines per nationality
const STEAL_SUCCESS_LINES := {
	Nationality.NIGERIAN: "Adebayo sees the threat in your eyes and backs away, leaving his supplies. \"This isn't worth dying over. Take it and go.\"",
	Nationality.BRITISH: "The haggard Englishman doesn't even fight back. He just stares with hollow eyes as you take his things. \"Add it to the list of everything else I've lost.\"",
	Nationality.INDONESIAN: "Budi raises his hands slowly, face grim. \"I have a family waiting for me. Take what you want.\"",
	Nationality.INDIAN: "Arjun steps back, calculating the odds. \"Fine. It's just things. But I won't forget your face.\"",
	Nationality.JAMAICAN: "Desmond's jaw tightens, but he doesn't resist. \"You got it this time. But word travels fast on these waters.\""
}

const STEAL_FAIL_LINES := {
	Nationality.NIGERIAN: "Adebayo is quicker than he looks. He shoves you back firmly. \"Don't try that again. I've dealt with worse than you.\"",
	Nationality.BRITISH: "Despite his weathered appearance, the old Navy training kicks in. He disarms your advance easily. \"I've lost everything except my pride. You won't take that.\"",
	Nationality.INDONESIAN: "Budi moves with unexpected speed, deflecting your attempt. \"I didn't survive this long by being careless. Leave now.\"",
	Nationality.INDIAN: "Arjun sidesteps smoothly, years of experience evident. \"A poor choice. I suggest you reconsider your approach to life.\"",
	Nationality.JAMAICAN: "Desmond reads your move before you make it and blocks you cold. \"Nice try. Maybe fish instead of stealing - it's more honest work.\""
}

# Trade dialogue
const TRADE_LINES := {
	Nationality.NIGERIAN: "\"Trading? Sure, I'm always open to a fair deal. What have you got?\"",
	Nationality.BRITISH: "\"Trade? I suppose I need supplies as much as anyone. Show me what you have.\"",
	Nationality.INDONESIAN: "\"Ah, trading! Yes, let's see what we can work out. Fair exchange benefits everyone.\"",
	Nationality.INDIAN: "\"Happy to trade. It's how my family has done business for generations. What are you offering?\"",
	Nationality.JAMAICAN: "\"Trading sounds good to me. Let's see what you've got and we'll figure something out.\""
}

# Fish together dialogue
const FISH_TOGETHER_LINES := {
	Nationality.NIGERIAN: "\"Fish together? I'd like that. Two boats cover more water. We'll split whatever we catch, fair?\"",
	Nationality.BRITISH: "\"Fish together? ...Fine. I could use the company, truth be told. We split everything evenly.\"",
	Nationality.INDONESIAN: "\"That sounds wonderful! Fishing is always better with company. We share the catch, of course.\"",
	Nationality.INDIAN: "\"Great idea! More hands make lighter work. We'll divide everything equally at the end.\"",
	Nationality.JAMAICAN: "\"Yeah, let's do it! Always more fun with someone else out here. We split everything down the middle.\""
}

# Loregiver lines - survivor of Britain's fall
const LOREGIVER_LINES := [
	"\"I was there when the Empire was given the Atom Fire. We prayed like it was a gift from Arkhitekta - but we all knew, it was not a gift. It was a trade. None of us saw it, but when we heard the chorus of priests, then the smell of fire... We knew what the cost had been for our World-ending weapon.\"",
	"\"We built the temple of Arkhitekta deep into the ground. Our God gave us Foundation and strength. He let us win wars. He was so embedded into our city, that when he died, the whole city crumbled alongside him. Your nation has the right idea. God and god-children have no business dealing with us mortals.\"",
	"\"It's calm seas today, and it hasn't rained in a while. It must be that the Moon is happy. I hear she found herself a Champion - only a little girl. Spirited her body all the way up - now she lives alone with the Moon's pet. You can see her crying through a telescope, I hear.\"",
	"\"You're a Nigerian fisher, aren't you? They say the Sun was Nigerian, when he was a man. That's why his blaze burns so brightly above your homeland. It's an awful deal he took, and an awful thing he did to his poor lover. I can barely glance at the Moon these nights - does she know what happened to us?\"",
	"\"They say, if you sail far enough north of Britain, you'll reach the end of the world. Just water, spilling down into the belly of the Goddess of the Abyss. Be careful, traveller. You would fall until you died of thirst and hunger, and your soul would be lost in the abyss.\"",
	"\"I met Arkhitekta once when he was just a man. He was a university fellow - like I was once. He was quite normal - ambitious to a fault, though. I remember he showed me his pet rabbits one night. He loved them and named each one - the one I remember most was Alba, some sort of experiment. It's ironic considering... well, I'm sure you know what roams Russia these days.\"",
	"\"My wife, before she passed, was convinced the clocks stopped for three days during the Armistice. She said only she was able to walk around freely, and that she knew it was because of the negotiations. I'm not sure of it all.\"",
	"\"I used to tell my children the story of the God of Speech. It was a beautiful thing, like a slug or sea creature, spreading across nations and connecting to our minds. When it was killed, well... No one could understand eachother enough to find out why.\"",
	"\"My son was born during the Eclipse, you hear? He never cast a shadow. We called him our little God-grandchild, because he was born between the union of the Sky's god-children. He passed in the fire.\"",
	"\"I don't give much creedence to Gods these days, but I do believe in the Goddess of the Abyss. Maybe, some night soon, I will turn that pitch obsidian and join her in the stars. You'll look out for me, you hear?\"",
	"\"I hope you meet a God-child one day. They age differently. They grow older, but not forward. They remember your future better than your past.\"",
]

var used_lore_lines: Array = []

# Friendly fish lines
const FRIENDLY_FISH_LINES := [
	"A strange, luminescent fish surfaces beside your boat. Its eyes seem almost... intelligent.",
	"A beautiful cowriesen fish leaps from the water and lands on your deck, looking up at you expectantly.",
	"An unusual fish with iridescent scales circles your boat. It seems to want something from you.",
	"A friendly-looking fish nudges against your hull. It chirps at you in an almost questioning tone."
]

const FRIENDLY_FISH_REQUESTS := [
	"It seems to be asking for food. Perhaps some of your catch?",
	"The fish gestures toward your supplies with its fin. Does it want something?",
	"It keeps looking between you and your catch hold. Is it hungry?",
]

# Shipbuilder lines
const SHIPBUILDER_INTRO := [
	"A weathered craftsman in a sturdy boat approaches. His hands are calloused from years of work.",
	"An old shipwright hails you from his workshop-boat, tools hanging from every surface.",
	"A master builder examines your vessel with a critical eye. \"She could use some work, friend.\""
]

const SHIPBUILDER_OFFER := "\"For a fair price in cowries, I can reinforce your hull. The armor won't heal, but it might save your life.\""

# Abandoned settlement descriptions
const SETTLEMENT_DESCRIPTIONS := [
	"You spot the ruins of a coastal village. The buildings are overgrown, but some supplies might remain.",
	"An abandoned fishing outpost appears through the mist. Crates and nets litter the docks.",
	"The skeletal remains of a settlement dot the shoreline. Whatever drove the people away, it was sudden."
]

const SETTLEMENT_WARNING := "Your boat would be unattended while you explore. There's a risk of losing supplies..."

# Event types
enum EventType { COMBAT, FISHER, FRIENDLY_FISH, LOREGIVER, SHIPBUILDER, SETTLEMENT }

var current_event_type: EventType
var current_nationality: Nationality
var current_fisher_name: String = ""
var pending_result: Dictionary = {}
var player_deck: Array = []
var player_catch: Array = []
var player_cowries: int = 0

# Track which nationalities have been stolen from THIS RUN
var stolen_from_nationalities: Array = []


func _ready() -> void:
	visible = false
	continue_button.pressed.connect(_on_continue)
	continue_button.visible = false
	result_label.visible = false
	result_label.text = ""
	if close_button:
		close_button.pressed.connect(_on_continue)
	
	# Effect banner starts at shown position (left)
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
	
	# Animate: slide right (out), then back left (in)
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	# Slide out to the right
	tween.tween_property(effect_banner, "position:x", EFFECT_HIDDEN_X, 0.3)
	tween.parallel().tween_property(effect_text, "position:x", EFFECT_HIDDEN_X + 36, 0.3)
	# Hold briefly
	tween.tween_interval(1.5)
	# Slide back in to the left
	tween.tween_property(effect_banner, "position:x", EFFECT_SHOWN_X, 0.3)
	tween.parallel().tween_property(effect_text, "position:x", EFFECT_SHOWN_X + 36, 0.3)


func show_event(deck: Array, catch_hold: Array = [], cowries: int = 0, stolen_nations: Array = []) -> void:
	player_deck = deck
	player_catch = catch_hold
	player_cowries = cowries
	stolen_from_nationalities = stolen_nations
	pending_result = {"stolen_from": null}
	
	# Reset UI state - hide result and continue button until choices are made
	result_label.visible = false
	result_label.text = ""
	continue_button.visible = false
	
	# Update cowries display
	if cowries_label:
		cowries_label.text = "Cowries: %d" % player_cowries
	
	# Clear any existing choice buttons
	for child in choices_container.get_children():
		child.queue_free()
	
	# Random chance for each event type
	var roll := randf()
	if roll < 0.15:
		# 15% chance of extra combat
		current_event_type = EventType.COMBAT
		_show_combat_event()
	elif roll < 0.45:
		# 30% chance of meeting other fishers
		current_event_type = EventType.FISHER
		_show_fisher_event()
	elif roll < 0.60:
		# 15% chance of friendly fish
		current_event_type = EventType.FRIENDLY_FISH
		_show_friendly_fish_event()
	elif roll < 0.75:
		# 15% chance of loregiver
		current_event_type = EventType.LOREGIVER
		_show_loregiver_event()
	elif roll < 0.88:
		# 13% chance of shipbuilder
		current_event_type = EventType.SHIPBUILDER
		_show_shipbuilder_event()
	else:
		# 12% chance of abandoned settlement
		current_event_type = EventType.SETTLEMENT
		_show_settlement_event()
	
	visible = true


func _show_choices_buttons(choices: Array) -> void:
	for child in choices_container.get_children():
		child.queue_free()
	
	for choice in choices:
		var btn := Button.new()
		btn.text = choice.text
		btn.pressed.connect(choice.callback)
		if choice.has("disabled") and choice.disabled:
			btn.disabled = true
		if choice.has("tooltip"):
			btn.tooltip_text = choice.tooltip
		choices_container.add_child(btn)


# ==================== COMBAT EVENT ====================

func _show_combat_event() -> void:
	title_label.text = "AMBUSH!"
	description_label.text = "A school of aggressive fish has found you! There's no avoiding this fight."
	
	_show_choices_buttons([
		{"text": "Prepare for battle!", "callback": _on_combat_chosen}
	])


func _on_combat_chosen() -> void:
	pending_result = {"trigger_combat": true}
	result_label.text = "You ready your gear as the fish circle your boat..."
	_show_continue()


# ==================== FISHER ENCOUNTER ====================

func _show_fisher_event() -> void:
	# Pick random nationality
	current_nationality = Nationality.values()[randi() % Nationality.size()]
	var greetings: Array = FISHER_GREETINGS[current_nationality]
	var greeting: String = greetings[randi() % greetings.size()]
	
	title_label.text = NATIONALITY_NAMES[current_nationality] + " Fisher"
	description_label.text = greeting
	
	# British are hostile survivors - limited options
	if current_nationality == Nationality.BRITISH:
		_show_choices_buttons([
			{"text": "Rob them (they're weak)", "callback": _on_steal_chosen, "tooltip": "They've already lost everything..."},
			{"text": "Offer to trade", "callback": _on_trade_british, "tooltip": "Maybe they'll warm up"},
			{"text": "Leave them be", "callback": _on_leave_fisher}
		])
	else:
		var choices := [
			{"text": "Steal (Intimidate)", "callback": _on_steal_chosen, "tooltip": "Risk conflict to take their supplies"},
			{"text": "Trade", "callback": _on_trade_chosen, "tooltip": "Exchange fish or cowries for temporary cards"},
			{"text": "Fish Together", "callback": _on_fish_together_chosen, "tooltip": "Gain a buff but halve next battle's rewards"},
			{"text": "Wave and leave", "callback": _on_leave_fisher}
		]
		
		# Nigerians offer help freely - add free gift option
		if current_nationality == Nationality.NIGERIAN:
			choices.insert(0, {"text": "Ask for help (free)", "callback": _on_nigerian_help, "tooltip": "They're known for their generosity"})
		
		_show_choices_buttons(choices)


func _on_steal_chosen() -> void:
	for child in choices_container.get_children():
		child.queue_free()
	
	# 60% success rate
	var success := randf() < 0.6
	
	if success:
		result_label.text = STEAL_SUCCESS_LINES[current_nationality]
		pending_result = {
			"cowries": randi_range(15, 30),
			"salvage": 1,
			"stolen_from": current_nationality
		}
	else:
		result_label.text = STEAL_FAIL_LINES[current_nationality]
		pending_result = {"damage": 1}
	
	_show_continue()


func _on_trade_chosen() -> void:
	for child in choices_container.get_children():
		child.queue_free()
	
	# Update description with trade dialogue
	description_label.text = TRADE_LINES[current_nationality]
	
	# Generate the card being offered (show it before they choose)
	offered_trade_card = _generate_temp_card()
	
	# Give temp card, costs either fish or cowries
	var has_fish := not player_catch.is_empty()
	var has_cowries := player_cowries >= 20
	
	# Show the card being offered using proper card layout at FULL SCALE
	var card_preview := _create_trade_card_preview(offered_trade_card)
	if card_preview:
		choices_container.add_child(card_preview)
	
	var trade_choices := []
	
	if has_fish:
		trade_choices.append({
			"text": "Trade a fish for this card",
			"callback": _on_trade_fish
		})
	
	if has_cowries:
		trade_choices.append({
			"text": "Pay 20 cowries for this card",
			"callback": _on_trade_cowries
		})
	
	if trade_choices.is_empty():
		# Player can't afford anything
		description_label.text += "\n\nYou don't have enough fish or cowries to trade."
	
	trade_choices.append({
		"text": "Never mind",
		"callback": _on_leave_fisher
	})
	
	_show_choices_buttons(trade_choices)


func _on_trade_fish() -> void:
	for child in choices_container.get_children():
		child.queue_free()
	
	pending_result = {
		"lose_fish": true,
		"temp_card": offered_trade_card  # Use the card that was shown
	}
	result_label.text = "A fair trade! You receive: " + offered_trade_card.get("name", "equipment")
	_show_continue()


func _on_trade_cowries() -> void:
	for child in choices_container.get_children():
		child.queue_free()
	
	pending_result = {
		"cowries": -20,
		"temp_card": offered_trade_card  # Use the card that was shown
	}
	result_label.text = "Cowries exchanged! You receive: " + offered_trade_card.get("name", "equipment")
	_show_continue()


func _on_fish_together_chosen() -> void:
	for child in choices_container.get_children():
		child.queue_free()
	
	result_label.text = FISH_TOGETHER_LINES[current_nationality] + "\n\nYou spend time fishing together, learning their techniques."
	pending_result = {
		"buff": {
			"name": "Fisher's Wisdom",
			"effect": "hook_bonus",
			"value": 1,
			"duration": "next_battle",
			"description": "+1 HOOK damage next battle"
		},
		"halve_rewards": true
	}
	_show_continue()


func _on_leave_fisher() -> void:
	for child in choices_container.get_children():
		child.queue_free()
	
	result_label.text = "You wave goodbye and continue on your way."
	pending_result = {}
	_show_continue()


func _on_nigerian_help() -> void:
	for child in choices_container.get_children():
		child.queue_free()
	
	var help_responses := [
		"\"Of course! Here, take some of my spare supplies. We look out for each other on these waters.\"",
		"\"You need help? Say no more. My grandmother would haunt me if I turned away someone in need.\"",
		"\"Happy to help a fellow fisher. Here - I caught more than I need today anyway.\""
	]
	
	# Generate the card they'll give
	var help_card := _generate_temp_card()
	var cowries_gift := randi_range(10, 20)
	
	result_label.text = help_responses[randi() % help_responses.size()] + "\n\nYou receive: " + help_card.get("name", "equipment") + " and " + str(cowries_gift) + " cowries!"
	pending_result = {
		"cowries": cowries_gift,
		"temp_card": help_card
	}
	_show_continue()


func _on_trade_british() -> void:
	for child in choices_container.get_children():
		child.queue_free()
	
	# 50% chance they warm up, 50% they refuse
	if randf() < 0.5:
		var warm_responses := [
			"His expression softens slightly. \"...Sorry. I've been out here alone too long. Yes, let's trade.\"",
			"He hesitates, then sighs. \"I suppose not everyone is an enemy. What do you have?\"",
			"\"You're... actually being decent. That's rare these days. Alright, show me what you've got.\""
		]
		description_label.text = warm_responses[randi() % warm_responses.size()]
		
		# Generate and show the card being offered
		offered_trade_card = _generate_temp_card()
		var card_preview := _create_trade_card_preview(offered_trade_card)
		if card_preview:
			choices_container.add_child(card_preview)
		
		var trade_choices := []
		var has_fish := not player_catch.is_empty()
		var has_cowries := player_cowries >= 20
		
		if has_fish:
			trade_choices.append({"text": "Trade a fish for this card", "callback": _on_trade_fish})
		if has_cowries:
			trade_choices.append({"text": "Pay 20 cowries for this card", "callback": _on_trade_cowries})
		
		if trade_choices.is_empty():
			description_label.text += "\n\nYou don't have enough fish or cowries to trade."
		
		trade_choices.append({"text": "Never mind", "callback": _on_leave_fisher})
		
		_show_choices_buttons(trade_choices)
	else:
		var refuse_responses := [
			"He shakes his head bitterly. \"No. I don't need anything from anyone. Just leave me alone.\"",
			"\"Trade? So you can profit off our misery like everyone else? No. Go away.\"",
			"His eyes harden. \"I've learned not to trust anyone. Find someone else to trade with.\""
		]
		result_label.text = refuse_responses[randi() % refuse_responses.size()]
		pending_result = {}
		_show_continue()


func _generate_temp_card() -> Dictionary:
	var cards := [
		{"name": "Borrowed Net", "hook": 2, "line": 2, "sinker": "None", "temp": true},
		{"name": "Trader's Hook", "hook": 3, "line": 1, "sinker": "None", "temp": true},
		{"name": "Foreign Tackle", "hook": 1, "line": 3, "sinker": "None", "temp": true},
	]
	return cards[randi() % cards.size()]


## Create a card preview using the card layout at FULL SCALE (1x minimum)
func _create_trade_card_preview(card_dict: Dictionary) -> Control:
	if not CARD_LAYOUT_SCENE:
		return null
	
	# Create container centered
	var container := CenterContainer.new()
	container.custom_minimum_size = Vector2(280, 400)
	
	# Create SubViewport to properly render Node2D card at FULL SCALE
	var viewport := SubViewport.new()
	viewport.size = Vector2i(280, 390)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	
	# Create the card display at FULL SCALE (1x, never smaller)
	var card_display: Node2D = CARD_LAYOUT_SCENE.instantiate()
	card_display.position = Vector2(140, 195)  # Center of viewport
	viewport.add_child(card_display)
	
	# Wrap viewport in container
	var viewport_container := SubViewportContainer.new()
	viewport_container.custom_minimum_size = Vector2(280, 390)
	viewport_container.stretch = true
	viewport_container.add_child(viewport)
	container.add_child(viewport_container)
	
	# Setup the card with data from dictionary
	_setup_trade_card(card_display, card_dict)
	
	return container


func _setup_trade_card(card_display: Node, card_dict: Dictionary) -> void:
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
	
	var sinker_name: String = card_dict.get("sinker", "None")
	var has_sinker: bool = sinker_name != "None"
	
	# Set name (use FishName2 since no bait on temp cards)
	if fish_name_label:
		fish_name_label.visible = false
	if fish_name_label_2:
		fish_name_label_2.visible = true
		fish_name_label_2.text = card_dict.get("name", "Unknown")
	
	# Set stats
	if hook_label:
		hook_label.text = str(card_dict.get("hook", 1))
	if line_label:
		line_label.text = str(card_dict.get("line", 1))
	if bait_label:
		bait_label.visible = false
	
	# Set sinker
	if sinker_label:
		sinker_label.visible = has_sinker
		if has_sinker:
			sinker_label.text = sinker_name
	if sinker_desc:
		sinker_desc.visible = has_sinker
		if has_sinker and CardDatabase:
			var sinker_power: int = card_dict.get("sinker_power", 0)
			sinker_desc.text = CardDatabase.get_sinker_description_dynamic(sinker_name, sinker_power)


# ==================== FRIENDLY FISH ====================

func _show_friendly_fish_event() -> void:
	title_label.text = "Friendly Fish"
	description_label.text = FRIENDLY_FISH_LINES[randi() % FRIENDLY_FISH_LINES.size()] + "\n\n" + FRIENDLY_FISH_REQUESTS[randi() % FRIENDLY_FISH_REQUESTS.size()]
	
	var has_fish := not player_catch.is_empty()
	
	var choices := []
	
	if has_fish:
		choices.append({
			"text": "Give it a fish",
			"callback": _on_give_fish,
			"tooltip": "The fish might reward your kindness"
		})
	
	choices.append({
		"text": "Try to catch it",
		"callback": _on_catch_friendly,
		"tooltip": "It looks valuable..."
	})
	
	choices.append({
		"text": "Shoo it away",
		"callback": _on_shoo_fish
	})
	
	_show_choices_buttons(choices)


func _on_give_fish() -> void:
	for child in choices_container.get_children():
		child.queue_free()
	
	# Good rewards for kindness
	var roll := randf()
	if roll < 0.5:
		result_label.text = "The fish seems delighted! It dives down and returns with something shiny - cowries from a shipwreck!"
		pending_result = {"lose_fish": true, "cowries": randi_range(25, 50)}
	else:
		result_label.text = "The fish chirps happily and nuzzles your hand. You feel blessed somehow. Your next catch will be of higher quality!"
		pending_result = {"lose_fish": true, "buff": {
			"name": "Fish's Blessing",
			"effect": "quality_bonus",
			"value": 1,
			"duration": "next_battle",
			"description": "+1 quality star on next catch"
		}}
	
	_show_continue()


func _on_catch_friendly() -> void:
	for child in choices_container.get_children():
		child.queue_free()
	
	# 50% chance it escapes, 50% you catch it but feel bad
	if randf() < 0.5:
		result_label.text = "The fish easily evades your grasp and swims away, looking hurt. You feel a pang of guilt."
		pending_result = {}
	else:
		result_label.text = "You manage to catch the fish, but it looks at you with such sadness... The catch feels hollow."
		pending_result = {"add_fish": {
			"name": "cowriesen Fish",
			"rarity": "rare",
			"quality_name": "Fresh",
			"cowrie_value": 40,
			"stars": 4
		}}
	
	_show_continue()


func _on_shoo_fish() -> void:
	for child in choices_container.get_children():
		child.queue_free()
	
	result_label.text = "The fish looks disappointed but swims away peacefully."
	pending_result = {}
	_show_continue()


# ==================== # ==================== LOREGIVER EVENT ====================

func _show_loregiver_event() -> void:
	title_label.text = "The Sailor"
	used_lore_lines.clear()

	var lore := _get_unique_lore_line()
	description_label.text = "An ancient fisherman drifts alongside you. His eyes have seen much.\n\n" + lore

	_show_choices_buttons([
		{"text": "Thank him for sharing", "callback": _on_thank_loregiver},
		{"text": "Ask to hear more", "callback": _on_more_lore}
	])

func _on_more_lore() -> void:
	for child in choices_container.get_children():
		child.queue_free()

	var lore := _get_unique_lore_line()

	if lore == "":
		result_label.text = "\"That's all I remember. Or all I'm willing to say.\""
		pending_result = {}
	else:
		result_label.text = "\"You want to know more? Well...\"\n\n" + lore
		pending_result = {
			"buff": {
				"name": "Ancient Wisdom",
				"effect": "dodge_bonus",
				"value": 1,
				"duration": "next_battle",
				"description": "10% chance to avoid damage next battle"
			}
		}

	_show_continue()

func _on_thank_loregiver() -> void:
	for child in choices_container.get_children():
		child.queue_free()

	result_label.text = "\"May the currents guide you, young one.\" He tips his hat and drifts away."
	pending_result = {}
	_show_continue()

func _get_unique_lore_line() -> String:
	var available: Array[String] = []

	for line in LOREGIVER_LINES:
		if line not in used_lore_lines:
			available.append(line)

	if available.is_empty():
		return ""

	var chosen: String = available[randi() % available.size()]
	used_lore_lines.append(chosen)
	return chosen

# ==================== SHIPBUILDER ====================

func _show_shipbuilder_event() -> void:
	title_label.text = "Shipbuilder"
	description_label.text = SHIPBUILDER_INTRO[randi() % SHIPBUILDER_INTRO.size()] + "\n\n" + SHIPBUILDER_OFFER
	
	var can_afford := player_cowries >= 30
	
	_show_choices_buttons([
		{
			"text": "Pay 30 cowries for hull armor",
			"callback": _on_buy_armor,
			"disabled": not can_afford,
			"tooltip": "Adds 2 armor (damage absorbed before HP, cannot be healed)"
		},
		{"text": "Decline politely", "callback": _on_decline_builder}
	])


func _on_buy_armor() -> void:
	for child in choices_container.get_children():
		child.queue_free()
	
	result_label.text = "The shipbuilder works quickly, reinforcing your hull with sturdy planks.\n\n\"She'll take a beating now. But remember - what's broken stays broken. Can't heal iron plates.\""
	pending_result = {"cowries": -30, "armor": 2}
	_show_continue()


func _on_decline_builder() -> void:
	for child in choices_container.get_children():
		child.queue_free()
	
	result_label.text = "\"Your choice, friend. The sea is unforgiving - remember my offer if you survive.\""
	pending_result = {}
	_show_continue()


# ==================== ABANDONED SETTLEMENT ====================

func _show_settlement_event() -> void:
	title_label.text = "Abandoned Settlement"
	description_label.text = SETTLEMENT_DESCRIPTIONS[randi() % SETTLEMENT_DESCRIPTIONS.size()] + "\n\n" + SETTLEMENT_WARNING
	
	_show_choices_buttons([
		{
			"text": "Explore (risky)",
			"callback": _on_explore_settlement,
			"tooltip": "Chance of loot, but your boat might be raided"
		},
		{"text": "Continue sailing", "callback": _on_skip_settlement}
	])


func _on_explore_settlement() -> void:
	for child in choices_container.get_children():
		child.queue_free()
	
	# 60% good outcome, 40% bad
	if randf() < 0.6:
		result_label.text = "You find useful supplies among the ruins! Cowries, salvage, and some preserved equipment.\n\n[Note: In the full game, you would find actual items here.]"
		pending_result = {"cowries": randi_range(20, 40), "salvage": randi_range(1, 2)}
	else:
		var loss_type := randi() % 3
		match loss_type:
			0:
				result_label.text = "While you were exploring, someone raided your boat! You've lost some cowries."
				pending_result = {"cowries": -randi_range(10, 25)}
			1:
				result_label.text = "The settlement was trapped! You barely escape, but your boat takes damage."
				pending_result = {"damage": 1}
			2:
				result_label.text = "Scavengers made off with some of your catch while you were distracted!"
				pending_result = {"lose_fish": true}
	
	_show_continue()


func _on_skip_settlement() -> void:
	for child in choices_container.get_children():
		child.queue_free()
	
	result_label.text = "Discretion is the better part of valor. You sail on."
	pending_result = {}
	_show_continue()


# ==================== COMMON ====================

func _show_continue() -> void:
	result_label.visible = true  # Show result when continue button appears
	continue_button.visible = true


func _on_continue() -> void:
	visible = false
	event_completed.emit(pending_result)


## Check if player has stolen from a nationality (for settlement interactions)
func has_stolen_from(nationality: Nationality) -> bool:
	return nationality in stolen_from_nationalities
