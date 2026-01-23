extends CanvasLayer
## Custom cursor that follows mouse and swaps sprites based on size setting

# Store references to your 3 size nodes
@onready var cursors: Dictionary = {
	"Small": $Small,
	"Medium": $Medium,
	"Large": $Large
}

# The currently active cursor node (CharacterBody2D)
var current_cursor: Node2D = null
var is_clicking: bool = false
static var _custom_cursor_active: bool = false

func _ready() -> void:
	# Prevent multiple cursors from showing
	if _custom_cursor_active:
		queue_free()
		return
	_custom_cursor_active = true
	
	# Hide the system cursor
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	
	# Ensure highest layer so it's always on top
	layer = 128
	
	# Initialize cursor state
	_update_cursor_from_settings()
	
	# Connect to settings changes
	if has_node("/root/SettingsManager"):
		SettingsManager.settings_changed.connect(_on_settings_changed)

func _process(_delta: float) -> void:
	# Move ONLY the active cursor to follow mouse
	if current_cursor:
		current_cursor.position = get_viewport().get_mouse_position()
	
	# Check hover state
	if not is_clicking:
		_update_cursor_state()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			is_clicking = true
			_play_anim("click")
		else:
			is_clicking = false
			_update_cursor_state()

func _on_settings_changed(category: String) -> void:
	if category == "accessibility":
		_update_cursor_from_settings()

func _update_cursor_from_settings() -> void:
	var size_setting = "Medium" # Default
	
	if has_node("/root/SettingsManager"):
		var val = SettingsManager.accessibility_settings.get("cursor_size", "Medium")
		
		# Handle both new String values ("Small") and old float values (1.0, 1.5)
		if val is String:
			size_setting = val
		elif val is float or val is int:
			# Fallback mapping if old settings file exists
			if val <= 1.0: size_setting = "Small"
			elif val <= 1.5: size_setting = "Medium"
			else: size_setting = "Large"
	
	# Hide all cursors, show only the selected one
	var found_valid = false
	for key in cursors:
		var node = cursors[key]
		if node:
			if key == size_setting:
				node.visible = true
				current_cursor = node
				found_valid = true
			else:
				node.visible = false
	
	# Fallback if something went wrong
	if not found_valid and cursors["Medium"]:
		cursors["Medium"].visible = true
		current_cursor = cursors["Medium"]
		
	# Ensure the new cursor has the correct animation state
	_update_cursor_state()

func _update_cursor_state() -> void:
	var viewport := get_viewport()
	var hovered := viewport.gui_get_hovered_control()
	
	var anim_name := "default"
	
	if hovered:
		var ctrl_class := hovered.get_class()
		if ctrl_class == "LineEdit" or ctrl_class == "TextEdit" or ctrl_class == "RichTextLabel":
			anim_name = "text" # Ensure your sprites have a "text" animation
		elif hovered.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND or hovered is Button or hovered is TextureButton:
			anim_name = "pointer" # Ensure your sprites have a "pointer" animation
			
	_play_anim(anim_name)

func _play_anim(anim_name: String) -> void:
	if current_cursor:
		var sprite = current_cursor.get_node_or_null("AnimatedSprite2D")
		if sprite:
			# Only play if it exists to avoid errors
			if sprite.sprite_frames.has_animation(anim_name):
				sprite.play(anim_name)
			else:
				sprite.play("default")
