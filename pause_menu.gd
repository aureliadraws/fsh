extends Control
## Pause Menu - Pause game, access options, quit run

signal resumed
signal quit_to_menu
signal save_requested
signal options_requested

@onready var resume_button: Button = $Panel/VBoxContainer/Resume
@onready var deck_button: Button = $Panel/VBoxContainer/ViewDeck
@onready var save_button: Button = $Panel/VBoxContainer/Save
@onready var options_button: Button = $Panel/VBoxContainer/Options
@onready var quit_button: Button = $Panel/VBoxContainer/QuitRun
@onready var deck_viewer: Control = $DeckViewer

var is_paused: bool = false
var current_deck: Array = []


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resume_button.pressed.connect(_on_resume)
	deck_button.pressed.connect(_on_view_deck)
	save_button.pressed.connect(_on_save)
	options_button.pressed.connect(_on_options)
	quit_button.pressed.connect(_on_quit)
	
	# Connect hover sounds
	resume_button.mouse_entered.connect(_on_button_hover)
	deck_button.mouse_entered.connect(_on_button_hover)
	save_button.mouse_entered.connect(_on_button_hover)
	options_button.mouse_entered.connect(_on_button_hover)
	quit_button.mouse_entered.connect(_on_button_hover)
	
	deck_viewer.closed.connect(_on_deck_closed)
	
	process_mode = Node.PROCESS_MODE_ALWAYS
	modulate.a = 0


func _on_button_hover() -> void:
	AudioManager.play_ui_select()


func _input(event: InputEvent) -> void:
	# ESC is now handled by roguelike_game.gd using options3 menu
	# This pause_menu should only respond when explicitly shown
	pass


func show_pause(deck: Array = []) -> void:
	if deck.size() > 0:
		current_deck = deck
	
	is_paused = true
	get_tree().paused = true
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	_animate_open()


func _animate_open() -> void:
	var panel := $Panel
	panel.scale = Vector2(0.9, 0.9)
	panel.pivot_offset = panel.size / 2
	
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "modulate:a", 1.0, 0.2)
	tween.parallel().tween_property(panel, "scale", Vector2.ONE, 0.3)


func _animate_close() -> void:
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	await tween.finished
	visible = false


func _on_resume() -> void:
	AudioManager.play_ui_confirm()
	await _animate_close()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	is_paused = false
	get_tree().paused = false
	resumed.emit()


func _on_view_deck() -> void:
	AudioManager.play_ui_confirm()
	deck_viewer.show_deck(current_deck)


func _on_deck_closed() -> void:
	pass  # Stay in pause menu


func _on_save() -> void:
	AudioManager.play_ui_confirm()
	save_requested.emit()
	
	# Show feedback
	save_button.text = "Saved!"
	save_button.disabled = true
	
	await get_tree().create_timer(1.0).timeout
	
	save_button.text = "Save Game"
	save_button.disabled = false


func _on_options() -> void:
	AudioManager.play_ui_confirm()
	# Options are now in Options3 menu - emit signal to open it
	options_requested.emit()


func _on_quit() -> void:
	AudioManager.play_ui_confirm()
	await _animate_close()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	is_paused = false
	get_tree().paused = false
	quit_to_menu.emit()
