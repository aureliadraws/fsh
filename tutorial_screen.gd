extends Control
## Tutorial System - Shows tips on first run or when requested

signal tutorial_completed
signal step_shown(step_id: String)

# Updated node paths for notebook layout
@onready var title_label: Label = $Title
@onready var content_label: Label = $RightPageContainer/Content
@onready var image_rect: TextureRect = $LeftPageContainer/ImageRect
@onready var progress_label: Label = $RightPageContainer/Progress
@onready var back_button: Button = $RightPageContainer/Buttons/Back
@onready var next_button: Button = $RightPageContainer/Buttons/Next
@onready var skip_button: Button = $RightPageContainer/Buttons/Skip
@onready var highlight: ColorRect = $Highlight
@onready var close_button: Button = $CloseButton

const SAVE_KEY := "tutorial_completed"

# Tutorial steps - Updated for current game mechanics
const STEPS := [
	{
		"id": "welcome",
		"title": "Welcome, Fisher!",
		"content": "Welcome to Sunken Empire!\n\nYou are a salvager exploring the flooded ruins of Britain. Catch fish, build your deck, and survive the depths.",
	},
	{
		"id": "map",
		"title": "Navigating the Map",
		"content": "Navigate the map by clicking on available nodes. You can see the Legend on the bottom left of the screen.",
	},
	{
		"id": "combat_basics",
		"title": "Combat Basics",
		"content": "In combat, you play cards to defeat fish.\n\nEach card has three stats:\n- HOOK - Damage dealt\n- LINE - Card durability (health)\n- SINKER - Special ability\n\nCards cost BAIT to play. You can right click on a card in play to SCRAP it for an amount of BAIT equalling the SCRAPPED CARD'S HOOK (with a minimum of 1 bait earned per card.)",
	},
	{
		"id": "card_placement",
		"title": "Playing Cards",
		"content": "Click a card in your hand to select it, then click on the board below the fish to place it.\n\nCards attack fish directly across from them. If no fish is directly opposite, they'll attack the nearest fish.",
	},
	{
		"id": "drawing",
		"title": "Drawing Cards",
		"content": "You can draw ONE card per turn from either:\n- Salvage Deck - Your collected cards\n- Chum Deck - Infinite weak chum cards\n\nClick on a deck to draw. The deck dims when you've drawn this turn.",
	},
	{
		"id": "catching",
		"title": "Catching Fish",
		"content": "You can catch a fish by using the 'HOOK' action, which is available every 3 turns. You can only HOOK cards with a LINE equalling or under your HOOK STRENGTH, which starting off with, is 2.\n\n You can also hook a card automatically by bringing its' LINE to 0, but be careful - giving the seekers a destroyed fish won't do much for them OR you.\n\n When you catch a fish, a catching minigame will start, with difficulty depending on the rarity of the fish.\n\n Press SPACE when the line is in a green zone to catch the fish.",
	},
	{
		"id": "boat_damage",
		"title": "Protecting Your Boat",
		"content": "Fish attack your cards directly opposite them. If no card is directly opposite, they attack the nearest card.\n\nIf a fish deals more damage to you card than it has LINE, the OVERSPILL damage goes directly to your BOAT!\n\nIf fish outnumber your cards by 2 or more, they can also attack your boat directly.\n\nKeep cards on the board to protect your boat.",
	},
	{
		"id": "tips",
		"title": "Final Tips",
		"content": "- Press ESC to pause and view your deck\n- Draw cards every turn to build your board\n- Scrap weak cards for BAIT when needed\n- Watch fish LINE - low health fish are valued less\n- The Hook action catches low-LINE fish instantly!\n\nGood luck!",
	}
]

var current_step: int = 0
var is_active: bool = false


func _ready() -> void:
	visible = false
	
	# Back button is now in tscn
	if back_button:
		back_button.pressed.connect(_on_back)
	
	next_button.pressed.connect(_on_next)
	skip_button.pressed.connect(_on_skip)
	if close_button:
		close_button.pressed.connect(_on_skip)
	highlight.visible = false
	modulate.a = 0


func _create_back_button() -> void:
	# Back button now in tscn, no need to create
	pass


## Check if tutorial has been completed before
func should_show_tutorial() -> bool:
	# Handle case where SaveManager might not be autoloaded yet
	if not Engine.has_singleton("SaveManager") and not has_node("/root/SaveManager"):
		# Try to check file directly
		if FileAccess.file_exists("user://roguelike_save.json"):
			var file := FileAccess.open("user://roguelike_save.json", FileAccess.READ)
			if file:
				var json := file.get_as_text()
				file.close()
				var parsed = JSON.parse_string(json)
				if parsed is Dictionary:
					return not parsed.get(SAVE_KEY, false)
		return true  # No save file = show tutorial
	
	var save_data: Dictionary = SaveManager.load_game()
	return not save_data.get(SAVE_KEY, false)


## Start the tutorial
func start_tutorial() -> void:
	current_step = 0
	is_active = true
	visible = true
	_show_current_step()
	_animate_in()


## Show a specific tip (can be called anytime)
func show_tip(step_id: String) -> void:
	for i in STEPS.size():
		if STEPS[i].id == step_id:
			current_step = i
			_show_current_step()
			visible = true
			_animate_in()
			return


func _show_current_step() -> void:
	var step: Dictionary = STEPS[current_step]
	
	title_label.text = step.title
	content_label.text = step.content
	progress_label.text = "%d / %d" % [current_step + 1, STEPS.size()]
	
	# Update back button visibility
	if back_button:
		back_button.visible = current_step > 0
		back_button.disabled = current_step == 0
	
	# Update next button text
	if current_step >= STEPS.size() - 1:
		next_button.text = "Finish"
	else:
		next_button.text = "Next"
	
	# Animate content
	content_label.modulate.a = 0
	content_label.position.y = 20
	
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(content_label, "modulate:a", 1.0, 0.3)
	tween.parallel().tween_property(content_label, "position:y", 0.0, 0.3)
	
	step_shown.emit(step.id)


func _animate_in() -> void:
	# Animate the whole screen since there's no separate panel node
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "modulate:a", 1.0, 0.3)


func _animate_out() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	await tween.finished
	visible = false


func _on_back() -> void:
	if current_step > 0:
		current_step -= 1
		_show_current_step()


func _on_next() -> void:
	current_step += 1
	
	if current_step >= STEPS.size():
		_finish_tutorial()
	else:
		_show_current_step()


func _on_skip() -> void:
	_finish_tutorial()


func _finish_tutorial() -> void:
	is_active = false
	
	# Save completion - handle missing SaveManager
	if Engine.has_singleton("SaveManager") or has_node("/root/SaveManager"):
		var save_data: Dictionary = SaveManager.load_game()
		save_data[SAVE_KEY] = true
		SaveManager.save_game(save_data)
	else:
		# Save directly to file
		var save_data := {"tutorial_completed": true}
		if FileAccess.file_exists("user://roguelike_save.json"):
			var file := FileAccess.open("user://roguelike_save.json", FileAccess.READ)
			if file:
				var json := file.get_as_text()
				file.close()
				var parsed = JSON.parse_string(json)
				if parsed is Dictionary:
					save_data = parsed
					save_data[SAVE_KEY] = true
		
		var file := FileAccess.open("user://roguelike_save.json", FileAccess.WRITE)
		if file:
			file.store_string(JSON.stringify(save_data))
			file.close()
	
	await _animate_out()
	tutorial_completed.emit()


## Highlight a specific area of the screen
func highlight_area(rect: Rect2) -> void:
	highlight.visible = true
	highlight.position = rect.position
	highlight.size = rect.size
	
	# Pulse animation
	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(highlight, "modulate:a", 0.3, 0.5)
	tween.tween_property(highlight, "modulate:a", 0.7, 0.5)


func hide_highlight() -> void:
	highlight.visible = false
