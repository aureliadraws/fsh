extends CanvasLayer
## ColorblindOverlay - Adds colorblind filter to the entire game
## Add this as an autoload or instantiate in your main scene

var filter_rect: ColorRect
var back_buffer: BackBufferCopy  # Added BackBufferCopy reference
var shader_material: ShaderMaterial
var shader_loaded: bool = false

const COLORBLIND_MODES := {
	"none": 0,
	"protanopia": 1,
	"deuteranopia": 2,
	"tritanopia": 3,
	"grayscale": 4
}


func _ready() -> void:
	# FIX 1: Increase layer to 128 (Godot's standard max) to cover almost all other UI
	layer = 128
	
	# FIX 2: Create a BackBufferCopy to capture the screen.
	# This fixes the "blank color" issue by ensuring the shader has a valid screen texture to read.
	back_buffer = BackBufferCopy.new()
	back_buffer.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	back_buffer.rect = Rect2(0, 0, 2000, 2000) # Ensure it covers the screen area
	add_child(back_buffer)
	
	# Create the filter ColorRect
	filter_rect = ColorRect.new()
	filter_rect.name = "ColorblindFilter"
	filter_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Set size to cover entire viewport
	filter_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# IMPORTANT: Start invisible until shader is confirmed working
	filter_rect.visible = false
	
	# Try to load shader from multiple possible locations
	var shader_paths := [
		"res://assets/colorblind.gdshader",
		"res://scenes/colorblind.gdshader",
		"res://shaders/colorblind.gdshader"
	]
	
	var shader: Shader = null
	for path in shader_paths:
		if ResourceLoader.exists(path):
			shader = load(path)
			if shader:
				print("[ColorblindOverlay] Shader loaded from: ", path)
				break
	
	if shader:
		shader_material = ShaderMaterial.new()
		shader_material.shader = shader
		filter_rect.material = shader_material
		shader_loaded = true
	else:
		push_warning("[ColorblindOverlay] Colorblind shader not found - feature disabled")
		shader_loaded = false
	
	# Add filter_rect AFTER the back_buffer so it can read the captured screen
	add_child(filter_rect)
	
	# Apply initial settings only if shader loaded
	if shader_loaded:
		call_deferred("_update_colorblind_mode")
	
	# Listen for settings changes
	if has_node("/root/SettingsManager"):
		SettingsManager.settings_changed.connect(_on_settings_changed)


func _on_settings_changed(category: String) -> void:
	if category == "accessibility":
		_update_colorblind_mode()


func _update_colorblind_mode() -> void:
	if not shader_loaded:
		return
	
	var mode_name := "none"
	
	if has_node("/root/SettingsManager"):
		mode_name = SettingsManager.accessibility_settings.get("colorblind_mode", "none")
	
	var mode_value: int = COLORBLIND_MODES.get(mode_name, 0)
	
	print("[ColorblindOverlay] Setting mode: ", mode_name, " (", mode_value, ")")
	
	if shader_material:
		shader_material.set_shader_parameter("colorblind_mode", mode_value)
		shader_material.set_shader_parameter("intensity", 1.0)
	
	# Show/hide filter based on mode
	if filter_rect:
		filter_rect.visible = (mode_value != 0)
		# Toggle back buffer too to save performance when not in use
		if back_buffer:
			back_buffer.visible = (mode_value != 0)
		print("[ColorblindOverlay] Filter visible: ", filter_rect.visible)


## Manually set colorblind mode (for testing)
func set_mode(mode_name: String) -> void:
	if not shader_loaded:
		return
	
	var mode_value: int = COLORBLIND_MODES.get(mode_name, 0)
	
	print("[ColorblindOverlay] Manual set mode: ", mode_name, " (", mode_value, ")")
	
	if shader_material:
		shader_material.set_shader_parameter("colorblind_mode", mode_value)
	
	if filter_rect:
		filter_rect.visible = (mode_value != 0)
		if back_buffer:
			back_buffer.visible = (mode_value != 0)
