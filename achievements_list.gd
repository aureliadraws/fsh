extends Control
## Achievements List - Shows all achievements and their status

signal closed

@onready var counter_label: Label = $Panel/VBoxContainer/Header/Counter
@onready var achievements_container: VBoxContainer = $Panel/VBoxContainer/ScrollContainer/AchievementsContainer
@onready var close_button: Button = $Panel/VBoxContainer/CloseButton

# Font reference for dynamic labels
var font: Font = preload("res://menu/font/BoldPixels.otf")


func _ready() -> void:
	visible = false
	modulate.a = 0
	
	close_button.pressed.connect(_on_close_pressed)
	close_button.mouse_entered.connect(_on_button_hover)


func _on_button_hover() -> void:
	if has_node("/root/AudioManager"):
		var audio = get_node("/root/AudioManager")
		if audio.has_method("play_ui_select"):
			audio.play_ui_select()


func show_achievements() -> void:
	_populate_achievements()
	visible = true
	
	# Fade in
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3)


func _populate_achievements() -> void:
	# Clear existing entries
	for child in achievements_container.get_children():
		child.queue_free()
	
	# Get achievements from manager
	if not has_node("/root/AchievementManager"):
		_add_placeholder_text("Achievement system not available")
		counter_label.text = "0 / 0"
		return
	
	var manager = get_node("/root/AchievementManager")
	var all_achievements: Array = manager.get_all_achievements()
	var counts: Dictionary = manager.get_achievement_count()
	
	counter_label.text = "%d / %d" % [counts.get("unlocked", 0), counts.get("total", 0)]
	
	if all_achievements.is_empty():
		_add_placeholder_text("No achievements available")
		return
	
	# Create entry for each achievement
	for achievement in all_achievements:
		_create_achievement_entry(achievement)


func _create_achievement_entry(achievement: Dictionary) -> void:
	var is_unlocked: bool = achievement.get("unlocked", false)
	var is_hidden: bool = achievement.get("hidden", false)
	
	# Container for this achievement
	var entry := PanelContainer.new()
	entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Style based on unlock status
	var style := StyleBoxFlat.new()
	if is_unlocked:
		style.bg_color = Color(0.15, 0.3, 0.15, 0.8)  # Green tint
	else:
		style.bg_color = Color(0.1, 0.1, 0.1, 0.8)  # Dark gray
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 15
	style.content_margin_right = 15
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	entry.add_theme_stylebox_override("panel", style)
	
	# Content VBox
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	entry.add_child(vbox)
	
	# Header HBox (name + status icon)
	var header := HBoxContainer.new()
	vbox.add_child(header)
	
	# Achievement name
	var name_label := Label.new()
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if font:
		name_label.add_theme_font_override("font", font)
	name_label.add_theme_font_size_override("font_size", 28)
	
	if is_hidden and not is_unlocked:
		name_label.text = "???"
		name_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	else:
		name_label.text = achievement.get("name", "Unknown")
		if is_unlocked:
			name_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))  # Golden
		else:
			name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))  # White-ish
	
	header.add_child(name_label)
	
	# Status indicator
	var status_label := Label.new()
	if font:
		status_label.add_theme_font_override("font", font)
	status_label.add_theme_font_size_override("font_size", 24)
	if is_unlocked:
		status_label.text = "[OK]"
		status_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	else:
		status_label.text = "[  ]"
		status_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	header.add_child(status_label)
	
	# Description
	var desc_label := Label.new()
	if font:
		desc_label.add_theme_font_override("font", font)
	desc_label.add_theme_font_size_override("font_size", 20)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	if is_hidden and not is_unlocked:
		desc_label.text = "Complete the secret requirement to unlock."
		desc_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	else:
		desc_label.text = achievement.get("description", "").replace("\n", " ")
		if is_unlocked:
			desc_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))  # White
		else:
			desc_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))  # Light gray
	
	vbox.add_child(desc_label)
	
	achievements_container.add_child(entry)


func _add_placeholder_text(message: String) -> void:
	var label := Label.new()
	label.text = message
	if font:
		label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 24)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))  # White
	achievements_container.add_child(label)


func _on_close_pressed() -> void:
	if has_node("/root/AudioManager"):
		var audio = get_node("/root/AudioManager")
		if audio.has_method("play_ui_confirm"):
			audio.play_ui_confirm()
	
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	await tween.finished
	
	visible = false
	closed.emit()
