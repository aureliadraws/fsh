extends Camera2D
class_name CameraController
## Camera controller with screen shake functionality integrated with SettingsManager

signal shake_completed

## Shake properties
@export var shake_decay: float = 0.8
@export var shake_power: float = 2.0
@export var max_shake_offset: float = 100.0
@export var max_shake_rotation: float = 0.1

## State
var trauma: float = 0.0
var shake_enabled: bool = true
var shake_intensity: float = 1.0


func _ready() -> void:
	# Get initial settings
	_update_shake_settings()
	
	# Listen for settings changes
	if has_node("/root/SettingsManager"):
		SettingsManager.settings_changed.connect(_on_settings_changed)


func _on_settings_changed(category: String) -> void:
	if category == "gameplay":
		_update_shake_settings()


func _update_shake_settings() -> void:
	if has_node("/root/SettingsManager"):
		shake_enabled = SettingsManager.gameplay_settings.get("screen_shake", true)
		shake_intensity = SettingsManager.gameplay_settings.get("screen_shake_intensity", 1.0)
	
	# Reset shake if disabled
	if not shake_enabled:
		trauma = 0.0
		offset = Vector2.ZERO
		rotation = 0.0


func _process(delta: float) -> void:
	if trauma > 0:
		trauma = maxf(trauma - shake_decay * delta, 0)
		_apply_shake()
		
		if trauma <= 0:
			shake_completed.emit()


func _apply_shake() -> void:
	if not shake_enabled:
		return
	
	var amount := pow(trauma, shake_power) * shake_intensity
	var offset_amount := max_shake_offset * shake_intensity
	var rotation_amount := max_shake_rotation * shake_intensity
	
	offset.x = randf_range(-offset_amount, offset_amount) * amount
	offset.y = randf_range(-offset_amount, offset_amount) * amount
	rotation = randf_range(-rotation_amount, rotation_amount) * amount


## Add trauma to trigger screen shake
## Amount should be between 0.0 and 1.0
func add_trauma(amount: float) -> void:
	# Check if screen shake is enabled
	if not shake_enabled:
		return
	
	if has_node("/root/SettingsManager"):
		if not SettingsManager.gameplay_settings.get("screen_shake", true):
			return
	
	trauma = minf(trauma + amount, 1.0)


## Convenience method for light shake
func shake_light() -> void:
	add_trauma(0.2)


## Convenience method for medium shake
func shake_medium() -> void:
	add_trauma(0.4)


## Convenience method for heavy shake
func shake_heavy() -> void:
	add_trauma(0.7)


## Convenience method for impact shake
func shake_impact() -> void:
	add_trauma(1.0)


## Reset all shake effects
func reset_shake() -> void:
	trauma = 0.0
	offset = Vector2.ZERO
	rotation = 0.0
