extends CanvasLayer
## ColorblindOverlay - Adds colorblind filter to the entire game
## Add this as an autoload or instantiate in your main scene

var filter_rect: ColorRect
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
	# Set to render on top of everything
	layer = 100
	
	# Create the filter ColorRect
	filter_rect = ColorRect.new()
	filter_rect.name = "ColorblindFilter"
	filter_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Set size to cover entire viewport
	filter_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	filter_rect.offset_left = 0
	filter_rect.offset_top = 0
	filter_rect.offset_right = 0
	filter_rect.offset_bottom = 0
	
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
		# No shader found - colorblind mode will be disabled
		push_warning("[ColorblindOverlay] Colorblind shader not found - feature disabled")
		shader_loaded = false
	
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
	# Don't do anything if shader didn't load
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
		print("[ColorblindOverlay] Filter visible: ", filter_rect.visible)


## Manually set colorblind mode (for testing)
func set_mode(mode_name: String) -> void:
	# Don't do anything if shader didn't load
	if not shader_loaded:
		return
	
	var mode_value: int = COLORBLIND_MODES.get(mode_name, 0)
	
	print("[ColorblindOverlay] Manual set mode: ", mode_name, " (", mode_value, ")")
	
	if shader_material:
		shader_material.set_shader_parameter("colorblind_mode", mode_value)
	
	if filter_rect:
		filter_rect.visible = (mode_value != 0)
