extends Control
## Game Over Screen - Shows defeat stats, applies 60% penalty, returns to New Eko

signal continue_pressed
signal return_home

# Updated node paths for notebook layout
@onready var title_label: Label = $Title
@onready var message_label: Label = $LeftPageContainer/Message
@onready var stats_container: VBoxContainer = $LeftPageContainer/Stats
@onready var penalty_label: Label = $RightPageContainer/Penalty
@onready var continue_button: Button = $RightPageContainer/ButtonContainer/Continue
@onready var home_button: Button = $RightPageContainer/ButtonContainer/HomeButton

var run_stats: Dictionary = {}
var is_victory: bool = false


func _ready() -> void:
	visible = false
	modulate.a = 0
	
	# Defer signal connections to ensure nodes are ready
	call_deferred("_connect_buttons")


func _connect_buttons() -> void:
	if continue_button:
		if not continue_button.pressed.is_connected(_on_continue):
			continue_button.pressed.connect(_on_continue)
		if not continue_button.mouse_entered.is_connected(_on_button_hover):
			continue_button.mouse_entered.connect(_on_button_hover)
	else:
		push_warning("GameOverScreen: Continue button not found!")
	
	if home_button:
		if not home_button.pressed.is_connected(_on_return_home):
			home_button.pressed.connect(_on_return_home)
		if not home_button.mouse_entered.is_connected(_on_button_hover):
			home_button.mouse_entered.connect(_on_button_hover)
	else:
		push_warning("GameOverScreen: Home button not found!")


func _on_button_hover() -> void:
	_play_ui_sound("select")


func show_game_over(stats: Dictionary) -> void:
	run_stats = stats
	is_victory = false
	
	# Calculate 60% penalty
	var cowries_gained: int = stats.get("cowries", stats.get("cowries", 0))
	var cowries_penalty: int = int(cowries_gained * 0.6)
	var final_cowries: int = cowries_gained - cowries_penalty
	
	# Update display
	if title_label:
		title_label.text = "DEFEATED"
		title_label.add_theme_color_override("font_color", Color.RED)
	
	if message_label:
		message_label.text = _get_death_message()
	
	# Show stats
	if stats_container:
		for child in stats_container.get_children():
			child.queue_free()
		
		_add_stat("Nodes Cleared", str(stats.get("nodes_cleared", 0)))
		_add_stat("Fish Caught", str(stats.get("fish_caught", 0)))
		_add_stat("Cowries Earned This Run", str(cowries_gained))
	
	# Penalty info
	if penalty_label:
		penalty_label.text = "PENALTY: Lost %d cowries (-60%%)\nLost all new salvage cards\nKept: %d cowries" % [cowries_penalty, final_cowries]
		penalty_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
	
	# Store final values
	run_stats["final_cowries"] = final_cowries
	run_stats["cowries_penalty"] = cowries_penalty
	
	# Apply penalty to GameState
	if has_node("/root/GameState"):
		GameState.on_run_defeat()
	
	# Update button visibility
	if continue_button:
		continue_button.text = "Try Again"
	if home_button:
		home_button.visible = true
		home_button.text = "Return to New Eko"
	
	visible = true
	_play_appear_animation()


func show_victory(stats: Dictionary) -> void:
	run_stats = stats
	is_victory = true
	
	# Victory bonus
	var area: int = stats.get("current_area", stats.get("current_level", 1))
	var bonus_cowries: int = 50 + (area * 25)
	var total_cowries: int = stats.get("cowries", stats.get("cowries", 0)) + bonus_cowries
	
	# Update display
	if title_label:
		title_label.text = "VICTORY!"
		title_label.add_theme_color_override("font_color", Color.GOLD)
	
	if message_label:
		message_label.text = "The boss has been defeated! Choose your next destination."
	
	# Show stats
	if stats_container:
		for child in stats_container.get_children():
			child.queue_free()
		
		_add_stat("Nodes Cleared", str(stats.get("nodes_cleared", 0)))
		_add_stat("Fish Caught", str(stats.get("fish_caught", 0)))
		_add_stat("Cowries Earned", str(stats.get("cowries", stats.get("cowries", 0))))
		_add_stat("Victory Bonus", "+%d cowries" % bonus_cowries)
		_add_stat("Total Cowries", str(total_cowries))
	
	# Show area selection
	if penalty_label:
		penalty_label.text = "Where will you sail next?"
		penalty_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	
	run_stats["final_cowries"] = total_cowries
	run_stats["bonus_cowries"] = bonus_cowries
	
	# Apply victory to GameState
	if has_node("/root/GameState"):
		GameState.on_boss_victory()
	
	# Update buttons for area selection
	if continue_button:
		continue_button.visible = true
		if area < 5:
			continue_button.text = "Next: %s" % _get_area_name(area + 1)
		else:
			continue_button.text = "New Game+"
	if home_button:
		home_button.visible = true
		home_button.text = "Return to New Eko"
	
	# Add area selection buttons
	_create_area_selection_buttons(area)
	
	visible = true
	_play_appear_animation()


func _get_area_name(area: int) -> String:
	match area:
		1: return "Shallow Waters"
		2: return "The Reef"
		3: return "Deep Currents"
		4: return "The Abyss"
		5: return "Leviathan's Domain"
		_: return "Unknown"


func _create_area_selection_buttons(current_area: int) -> void:
	# Create container for area buttons in stats area
	if not stats_container:
		return
	
	var separator := HSeparator.new()
	stats_container.add_child(separator)
	
	var label := Label.new()
	label.text = "Choose Area:"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_container.add_child(label)
	
	# Add button for each unlocked area
	var highest := GameState.highest_area_unlocked if GameState else current_area
	
	for i in range(1, mini(highest + 2, 6)):  # Can go to next area or any previous
		var btn := Button.new()
		var area_name := _get_area_name(i)
		if i == current_area + 1:
			btn.text = ">> %s (NEW)" % area_name
			btn.add_theme_color_override("font_color", Color.GOLD)
		elif i == current_area:
			btn.text = "%s (Current)" % area_name
		else:
			btn.text = "%s" % area_name
		btn.pressed.connect(_on_area_selected.bind(i))
		stats_container.add_child(btn)


func _on_area_selected(area: int) -> void:
	if GameState:
		GameState.current_area = area
		GameState.save_persistent_data()
	continue_pressed.emit()


func _add_stat(label_text: String, value: String) -> void:
	if not stats_container:
		return
	
	var hbox := HBoxContainer.new()
	stats_container.add_child(hbox)
	
	var label := Label.new()
	label.text = label_text + ":"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(label)
	
	var value_label := Label.new()
	value_label.text = value
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(value_label)


func _get_death_message() -> String:
	var messages := [
		"The depths claimed another soul...",
		"Your boat sinks beneath the waves.",
		"The fish were too fierce this time.",
		"A watery grave awaits the unprepared.",
		"The Arkhitekta's waters show no mercy.",
		"You'll need better equipment next time.",
		"The sea is unforgiving today.",
	]
	return messages[randi() % messages.size()]


func _play_appear_animation() -> void:
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	
	# Fade in background
	tween.tween_property(self, "modulate:a", 1.0, 0.5)
	
	# Scale panel from small
	var panel := get_node_or_null("Panel")
	if panel:
		panel.scale = Vector2(0.5, 0.5)
		panel.pivot_offset = panel.size / 2
		tween.parallel().tween_property(panel, "scale", Vector2.ONE, 0.6)
	
	# Slide in stats one by one
	await tween.finished
	
	if stats_container:
		for i in stats_container.get_child_count():
			var child := stats_container.get_child(i)
			child.modulate.a = 0
			child.position.x = -50
			
			var stat_tween := create_tween()
			stat_tween.set_ease(Tween.EASE_OUT)
			stat_tween.tween_property(child, "modulate:a", 1.0, 0.3)
			stat_tween.parallel().tween_property(child, "position:x", 0.0, 0.3)
			
			await get_tree().create_timer(0.1).timeout


func _on_continue() -> void:
	_play_ui_sound("confirm")
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	await tween.finished
	
	visible = false
	continue_pressed.emit()


func _on_return_home() -> void:
	_play_ui_sound("confirm")
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	await tween.finished
	
	visible = false
	# Return to New Eko base
	get_tree().change_scene_to_file("res://scenes/menus/base.tscn")


func get_final_cowries() -> int:
	return run_stats.get("final_cowries", run_stats.get("final_cowries", 0))

## Safely play UI sounds - checks if AudioManager exists
func _play_ui_sound(sound_type: String) -> void:
	if Engine.has_singleton("AudioManager"):
		var audio = Engine.get_singleton("AudioManager")
		match sound_type:
			"select":
				if audio.has_method("play_ui_select"):
					audio.play_ui_select()
			"confirm":
				if audio.has_method("play_ui_confirm"):
					audio.play_ui_confirm()
	elif has_node("/root/AudioManager"):
		var audio = get_node("/root/AudioManager")
		match sound_type:
			"select":
				if audio.has_method("play_ui_select"):
					audio.play_ui_select()
			"confirm":
				if audio.has_method("play_ui_confirm"):
					audio.play_ui_confirm()
