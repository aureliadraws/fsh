extends CanvasLayer
## Handles smooth transitions between screens

signal transition_midpoint  # Emitted at peak of transition (screen fully covered)
signal transition_finished

@onready var color_rect: ColorRect = $ColorRect
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var is_transitioning: bool = false

# Transition styles
enum Style { FADE, WIPE_LEFT, WIPE_RIGHT, WIPE_UP, WIPE_DOWN, CIRCLE, DISSOLVE }


func _ready() -> void:
	layer = 100
	color_rect.color = Color.BLACK
	color_rect.modulate.a = 0
	
	# Setup shader for special effects
	_setup_transitions()


func _setup_transitions() -> void:
	# Ensure rect covers screen
	color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)


## Simple fade to black and back
func fade_to_black(duration: float = 0.5) -> void:
	if is_transitioning:
		return
	
	is_transitioning = true
	
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(color_rect, "modulate:a", 1.0, duration)
	
	await tween.finished
	transition_midpoint.emit()


func fade_from_black(duration: float = 0.5) -> void:
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(color_rect, "modulate:a", 0.0, duration)
	
	await tween.finished
	is_transitioning = false
	transition_finished.emit()


## Full transition with callback at midpoint
func transition(callback: Callable, fade_out: float = 0.4, fade_in: float = 0.4) -> void:
	await fade_to_black(fade_out)
	callback.call()
	await fade_from_black(fade_in)


## Wipe transition
func wipe(direction: Vector2, duration: float = 0.6) -> void:
	if is_transitioning:
		return
	
	is_transitioning = true
	
	# Use a clip rect or shader for wipe effect
	# For simplicity, using position-based wipe
	var screen_size := get_viewport().get_visible_rect().size
	
	color_rect.modulate.a = 1.0
	
	# Start offscreen
	if direction.x > 0:
		color_rect.position.x = -screen_size.x
	elif direction.x < 0:
		color_rect.position.x = screen_size.x
	elif direction.y > 0:
		color_rect.position.y = -screen_size.y
	else:
		color_rect.position.y = screen_size.y
	
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(color_rect, "position", Vector2.ZERO, duration / 2)
	
	await tween.finished
	transition_midpoint.emit()


func wipe_out(direction: Vector2, duration: float = 0.6) -> void:
	var screen_size := get_viewport().get_visible_rect().size
	var target := Vector2.ZERO
	
	if direction.x > 0:
		target.x = screen_size.x
	elif direction.x < 0:
		target.x = -screen_size.x
	elif direction.y > 0:
		target.y = screen_size.y
	else:
		target.y = -screen_size.y
	
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(color_rect, "position", target, duration / 2)
	
	await tween.finished
	color_rect.position = Vector2.ZERO
	color_rect.modulate.a = 0
	is_transitioning = false
	transition_finished.emit()


## Flash effect (for damage, etc)
func flash(color: Color = Color.WHITE, duration: float = 0.1) -> void:
	color_rect.color = color
	color_rect.modulate.a = 0.7
	
	var tween := create_tween()
	tween.tween_property(color_rect, "modulate:a", 0.0, duration)
	
	await tween.finished
	color_rect.color = Color.BLACK


## Shake effect (call on target node)
## Fixed to prevent infinite loops if node processing is disabled
static func shake(node: Node2D, intensity: float = 10.0, duration: float = 0.3) -> void:
	# Safety check: ensure node exists
	if not is_instance_valid(node):
		return

	var original_pos := node.position
	
	# Use system time instead of delta accumulation
	# This prevents infinite loops if the node is paused or timescale is 0
	var start_time := Time.get_ticks_msec()
	var duration_ms := duration * 1000.0
	
	while (Time.get_ticks_msec() - start_time) < duration_ms:
		# Always check if node was freed during the wait
		if not is_instance_valid(node) or not node.is_inside_tree():
			return
			
		var elapsed_ms = Time.get_ticks_msec() - start_time
		var progress := clampf(elapsed_ms / duration_ms, 0.0, 1.0)
		var current_intensity := intensity * (1.0 - progress)
		
		node.position = original_pos + Vector2(
			randf_range(-current_intensity, current_intensity),
			randf_range(-current_intensity, current_intensity)
		)
		
		# Wait for next frame
		await node.get_tree().process_frame
	
	# Restore position
	if is_instance_valid(node):
		node.position = original_pos
