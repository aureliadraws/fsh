extends Control
## QTE Ring Catch Minigame - Press SPACE when the cursor is in green zones
## Thick ring with line cursor, semi-transparent background behind
## FIXED: Added timeout failsafe and force_close method to prevent stuck UI

signal catch_completed(success: bool, quality: int)  # quality: 0=failed, 1=rough, 2=good, 3=perfect

@onready var fish_name_label: Label = $FishName
@onready var instruction_label: Label = $Instructions

## Ring settings
const RING_RADIUS: float = 150.0  # Larger ring
const RING_THICKNESS: float = 35.0  # Thicker ring
const CURSOR_WIDTH: float = 4.0  # Line width for cursor
var num_green_zones: int = 3  # Changed to var for easy mode
const GREEN_ZONE_SIZE: float = 0.12  # Portion of ring (0.12 = ~43 degrees)
const EASY_GREEN_ZONE_SIZE: float = 0.20  # Larger zones for easy mode

## Timing settings
var time_limit: float = 3.5  # Maximum seconds before fish escapes (var for easy mode)
var initial_speed: float = 6.0  # Radians per second (fast start) (var for easy mode)
var min_speed: float = 2.0  # Slowest speed (easier at end) (var for easy mode)
const SPEED_DECAY: float = 0.5  # How much speed reduces per second

## State
var is_active: bool = false
var cursor_angle: float = 0.0  # Current cursor position in radians
var cursor_speed: float = 6.0  # Current rotation speed
var green_zones: Array = []  # Array of {start: float, end: float} in radians
var zones_cleared: int = 0
var time_remaining: float = 3.5
var successful_hits: int = 0
var total_attempts: int = 0
var last_hit_precision: float = 0.0  # How centered the hit was

## FIXED: Safety timeout to prevent stuck UI
var _safety_timeout: float = 15.0  # Maximum time minigame can be active
var _time_since_start: float = 0.0

## Colors - Full opacity for ring
const COLOR_RING_BG: Color = Color(0.15, 0.2, 0.3, 1.0)  # Full opacity dark blue-gray
const COLOR_RING_BORDER: Color = Color(0.3, 0.35, 0.45, 1.0)  # Slightly lighter border
const COLOR_GREEN_ZONE: Color = Color(0.2, 0.85, 0.3, 1.0)  # Full opacity green
const COLOR_GREEN_ZONE_HIT: Color = Color(0.4, 0.6, 0.45, 0.7)  # Dimmed cleared zone
const COLOR_CURSOR: Color = Color(1.0, 0.95, 0.4, 1.0)  # Bright yellow
const COLOR_CURSOR_IN_ZONE: Color = Color(0.4, 1.0, 0.5, 1.0)  # Bright green when in zone
const COLOR_TIMER_GOOD: Color = Color(0.3, 0.9, 0.3, 1.0)
const COLOR_TIMER_WARNING: Color = Color(0.95, 0.75, 0.2, 1.0)
const COLOR_TIMER_DANGER: Color = Color(0.95, 0.3, 0.2, 1.0)

## Ring center position (calculated in _ready)
var ring_center: Vector2 = Vector2.ZERO


func _ready() -> void:
	visible = false
	set_process(false)
	mouse_filter = Control.MOUSE_FILTER_STOP


func start_catch(fish_name: String, difficulty: float = 1.0, _behavior: String = "Fighter", fish_rarity: String = "common") -> void:
	if fish_name_label:
		fish_name_label.text = fish_name
	
	# Determine base green zones from fish rarity:
	# common = 1 zone, uncommon = 2 zones, rare = 3 zones, elite/boss = 4 zones
	var rarity_zones: int = 1
	match fish_rarity.to_lower():
		"common":
			rarity_zones = 1
		"uncommon":
			rarity_zones = 2
		"rare":
			rarity_zones = 3
		"elite", "boss":
			rarity_zones = 4
		_:
			rarity_zones = 1
	
	# Get settings from SettingsManager
	if has_node("/root/SettingsManager"):
		var timing_multiplier := SettingsManager.get_qte_timing_multiplier()
		var speed_multiplier := SettingsManager.get_qte_speed_multiplier()
		var settings_zones := SettingsManager.get_qte_zone_count()
		
		# Use rarity-based zones, but respect easy mode if it reduces zones
		if settings_zones < rarity_zones:
			num_green_zones = settings_zones
		else:
			num_green_zones = rarity_zones
		
		# Apply easy mode adjustments
		time_limit = 3.5 * timing_multiplier
		initial_speed = 6.0 * speed_multiplier
		min_speed = 2.0 * speed_multiplier
	else:
		# Fallback: use rarity-based zones
		num_green_zones = rarity_zones
		time_limit = 3.5
		initial_speed = 6.0
		min_speed = 2.0
	
	# Adjust difficulty
	cursor_speed = initial_speed + (difficulty * 1.0)  # Faster for harder fish
	
	# Reset state
	cursor_angle = 0.0
	zones_cleared = 0
	time_remaining = time_limit
	successful_hits = 0
	total_attempts = 0
	last_hit_precision = 0.0
	is_active = true
	_time_since_start = 0.0  # FIXED: Reset safety timer
	
	# Generate green zones
	_generate_green_zones()
	
	# Calculate ring center
	ring_center = size / 2.0
	
	# Setup UI
	visible = true
	set_process(true)
	
	# Start reeling sound
	if has_node("/root/AudioManager"):
		AudioManager.start_reeling()
	
	if instruction_label:
		instruction_label.text = "Press SPACE in green zones!"
		instruction_label.modulate = Color.WHITE


func _generate_green_zones() -> void:
	green_zones.clear()
	
	# Determine zone size based on easy mode
	var zone_size := GREEN_ZONE_SIZE
	if has_node("/root/SettingsManager") and SettingsManager.accessibility_settings.easy_hook_mode:
		zone_size = EASY_GREEN_ZONE_SIZE
	
	# Generate zones spread around the ring
	if num_green_zones == 1:
		# Easy mode: Single large zone at the top
		var center := 0.0  # Top of ring
		var half_size: float = (zone_size * TAU) / 2.0
		green_zones.append({
			"start": center - half_size,
			"end": center + half_size,
			"cleared": false,
			"center": center
		})
	else:
		# Normal mode: Multiple zones evenly spaced
		var angle_step := TAU / num_green_zones
		
		for i in range(num_green_zones):
			# Add some randomness to position
			var random_offset: float = randf_range(-0.4, 0.4)
			var center: float = (i * angle_step) + random_offset
			
			# Normalize to 0-TAU range
			while center < 0:
				center += TAU
			while center >= TAU:
				center -= TAU
			
			var half_size: float = (zone_size * TAU) / 2.0
			green_zones.append({
				"start": center - half_size,
				"end": center + half_size,
				"cleared": false,
				"center": center
			})


func _process(delta: float) -> void:
	if not is_active:
		return
	
	# FIXED: Safety timeout check
	_time_since_start += delta
	if _time_since_start >= _safety_timeout:
		push_warning("Catch minigame safety timeout reached - forcing close")
		force_close()
		return
	
	# Move cursor around the ring
	cursor_angle += cursor_speed * delta
	if cursor_angle >= TAU:
		cursor_angle -= TAU
	
	# Slow down over time (makes it easier to hit later zones)
	cursor_speed = maxf(cursor_speed - (SPEED_DECAY * delta), min_speed)
	
	# Update timer
	time_remaining -= delta
	if time_remaining <= 0:
		_end_catch(false, "TIME'S UP!")
		return
	
	# Update instruction based on state
	if instruction_label:
		var in_any_zone := _is_cursor_in_active_zone()
		if in_any_zone:
			instruction_label.text = "NOW! Press SPACE!"
			instruction_label.modulate = COLOR_GREEN_ZONE
		else:
			instruction_label.text = "Wait for green zone..."
			instruction_label.modulate = Color.WHITE
	
	# Request redraw
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not visible or not is_active:
		return
	
	if event.is_action_pressed("ui_accept"):
		_handle_space_press()
		get_viewport().set_input_as_handled()


func _handle_space_press() -> void:
	total_attempts += 1
	
	# Check if cursor is in any active green zone
	var hit_zone_index := _get_active_zone_at_cursor()
	
	if hit_zone_index >= 0:
		# Hit! Clear this zone
		green_zones[hit_zone_index].cleared = true
		zones_cleared += 1
		successful_hits += 1
		
		# Calculate precision (how centered the hit was)
		var zone = green_zones[hit_zone_index]
		var zone_center: float = zone.center
		var dist_from_center := _angle_distance(cursor_angle, zone_center)
		var zone_half_size: float = (GREEN_ZONE_SIZE * TAU) / 2.0
		last_hit_precision = 1.0 - (dist_from_center / zone_half_size)
		
		if has_node("/root/AudioManager"):
			AudioManager.play_ui_confirm()
		
		# Check if all zones cleared
		if zones_cleared >= num_green_zones:
			var quality := _calculate_quality()
			_end_catch(true, "CAUGHT!", quality)
			return
		
		# Update instruction
		if instruction_label:
			instruction_label.text = "Hit! %d more to go!" % (num_green_zones - zones_cleared)
			instruction_label.modulate = Color.GREEN
	else:
		# Miss - penalize time
		time_remaining -= 0.3
		if has_node("/root/AudioManager"):
			AudioManager.play_ui_select()  # Feedback sound
		
		if instruction_label:
			instruction_label.text = "Missed! Wait for green!"
			instruction_label.modulate = Color.RED


func _is_cursor_in_active_zone() -> bool:
	return _get_active_zone_at_cursor() >= 0


func _get_active_zone_at_cursor() -> int:
	for i in range(green_zones.size()):
		var zone = green_zones[i]
		if zone.cleared:
			continue
		if _is_angle_in_zone(cursor_angle, zone.start, zone.end):
			return i
	return -1


func _is_angle_in_zone(angle: float, zone_start: float, zone_end: float) -> bool:
	# Normalize angle
	while angle < 0:
		angle += TAU
	while angle >= TAU:
		angle -= TAU
	
	# Handle wraparound zones
	if zone_start < 0:
		# Zone wraps from end to beginning
		return angle >= (zone_start + TAU) or angle <= zone_end
	elif zone_end > TAU:
		# Zone wraps from end to beginning
		return angle >= zone_start or angle <= (zone_end - TAU)
	else:
		return angle >= zone_start and angle <= zone_end


func _angle_distance(a: float, b: float) -> float:
	var diff := absf(a - b)
	if diff > PI:
		diff = TAU - diff
	return diff


func _calculate_quality() -> int:
	# Quality based on:
	# - Time remaining (how fast)
	# - Hit precision (how centered hits were)
	# - Number of misses
	
	var time_score: float = time_remaining / time_limit  # 0-1
	var miss_penalty: float = float(total_attempts - successful_hits) * 0.15
	var final_score: float = time_score - miss_penalty + (last_hit_precision * 0.2)
	
	if final_score >= 0.7:
		return 3  # Perfect
	elif final_score >= 0.4:
		return 2  # Good
	else:
		return 1  # Rough


func _end_catch(success: bool, message: String, quality: int = 0) -> void:
	is_active = false
	set_process(false)
	if instruction_label:
		instruction_label.text = message
		instruction_label.modulate = Color.GREEN if success else Color.RED
	
	# Stop reeling sound
	if has_node("/root/AudioManager"):
		AudioManager.stop_reeling()
		if success:
			AudioManager.play_ui_confirm()
		else:
			AudioManager.play_line_break()
	
	# FIXED: Use safer delay with error handling
	_finalize_catch_delayed(success, quality)


## FIXED: Safer delay approach for finalizing catch
func _finalize_catch_delayed(success: bool, quality: int) -> void:
	# Create a timer for the delay
	var timer := get_tree().create_timer(1.0)
	timer.timeout.connect(func(): _finalize_catch(success, quality))


## FIXED: Finalize the catch and emit signal
func _finalize_catch(success: bool, quality: int) -> void:
	visible = false
	catch_completed.emit(success, quality)


## FIXED: Force close method for emergency situations
func force_close() -> void:
	is_active = false
	set_process(false)
	visible = false
	
	# Stop any sounds
	if has_node("/root/AudioManager"):
		AudioManager.stop_reeling()
	
	# Emit failure
	catch_completed.emit(false, 0)


func _draw() -> void:
	if not is_active:
		return
	
	# Draw semi-transparent background FIRST (behind everything)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.5))
	
	# Draw ring border (slightly larger, behind main ring)
	_draw_ring_arc(0, TAU, COLOR_RING_BORDER, RING_RADIUS + 3, RING_THICKNESS + 6)
	
	# Draw main ring background
	_draw_ring_arc(0, TAU, COLOR_RING_BG, RING_RADIUS, RING_THICKNESS)
	
	# Draw green zones
	for zone in green_zones:
		var color: Color = COLOR_GREEN_ZONE_HIT if zone.cleared else COLOR_GREEN_ZONE
		_draw_ring_arc(zone.start, zone.end, color, RING_RADIUS, RING_THICKNESS)
	
	# Draw timer arc (inside the ring)
	var timer_ratio: float = time_remaining / time_limit
	var timer_color: Color
	if timer_ratio > 0.5:
		timer_color = COLOR_TIMER_GOOD
	elif timer_ratio > 0.25:
		timer_color = COLOR_TIMER_WARNING
	else:
		timer_color = COLOR_TIMER_DANGER
	_draw_timer_arc(timer_ratio, timer_color)
	
	# Draw cursor as a LINE from inner to outer edge
	var cursor_color: Color = COLOR_CURSOR_IN_ZONE if _is_cursor_in_active_zone() else COLOR_CURSOR
	_draw_cursor_line(cursor_color)
	
	# Draw zone counter in center
	_draw_zone_counter()


func _draw_ring_arc(start_angle: float, end_angle: float, color: Color, radius: float = RING_RADIUS, thickness: float = RING_THICKNESS) -> void:
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	
	var outer_radius: float = radius
	var inner_radius: float = radius - thickness
	
	# Normalize angles
	while start_angle < 0:
		start_angle += TAU
	while end_angle < start_angle:
		end_angle += TAU
	
	var segments: int = maxi(int((end_angle - start_angle) * 20), 3)
	var angle_step: float = (end_angle - start_angle) / segments
	
	# Build outer arc
	for i in range(segments + 1):
		var angle: float = start_angle + (i * angle_step)
		var outer_point: Vector2 = ring_center + Vector2(cos(angle), sin(angle)) * outer_radius
		points.append(outer_point)
		colors.append(color)
	
	# Build inner arc (reverse order)
	for i in range(segments, -1, -1):
		var angle: float = start_angle + (i * angle_step)
		var inner_point: Vector2 = ring_center + Vector2(cos(angle), sin(angle)) * inner_radius
		points.append(inner_point)
		colors.append(color)
	
	if points.size() >= 3:
		draw_polygon(points, colors)


func _draw_timer_arc(ratio: float, color: Color) -> void:
	var timer_radius: float = RING_RADIUS - RING_THICKNESS - 12
	var timer_thickness: float = 8.0
	
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	
	var outer_radius: float = timer_radius
	var inner_radius: float = timer_radius - timer_thickness
	
	var end_angle: float = -PI / 2.0 + (TAU * ratio)
	var start_angle: float = -PI / 2.0
	
	var segments: int = maxi(int(ratio * 30), 3)
	var angle_step: float = (end_angle - start_angle) / segments
	
	for i in range(segments + 1):
		var angle: float = start_angle + (i * angle_step)
		var outer_point: Vector2 = ring_center + Vector2(cos(angle), sin(angle)) * outer_radius
		points.append(outer_point)
		colors.append(color)
	
	for i in range(segments, -1, -1):
		var angle: float = start_angle + (i * angle_step)
		var inner_point: Vector2 = ring_center + Vector2(cos(angle), sin(angle)) * inner_radius
		points.append(inner_point)
		colors.append(color)
	
	if points.size() >= 3:
		draw_polygon(points, colors)


func _draw_cursor_line(color: Color) -> void:
	# Draw cursor as a thick line from inner to outer edge of ring
	var inner_radius: float = RING_RADIUS - RING_THICKNESS - 5
	var outer_radius: float = RING_RADIUS + 5
	
	var inner_point: Vector2 = ring_center + Vector2(cos(cursor_angle), sin(cursor_angle)) * inner_radius
	var outer_point: Vector2 = ring_center + Vector2(cos(cursor_angle), sin(cursor_angle)) * outer_radius
	
	# Draw the main line
	draw_line(inner_point, outer_point, color, CURSOR_WIDTH)
	
	# Draw small circles at ends for polish
	draw_circle(inner_point, CURSOR_WIDTH, color)
	draw_circle(outer_point, CURSOR_WIDTH, color)


func _draw_zone_counter() -> void:
	# Draw remaining zones as circles in the center
	var center_y: float = ring_center.y + 40
	var spacing: float = 30.0
	var start_x: float = ring_center.x - (spacing * (num_green_zones - 1) / 2.0)
	
	for i in range(num_green_zones):
		var pos := Vector2(start_x + (i * spacing), center_y)
		var cleared: bool = i < zones_cleared
		var color: Color = COLOR_GREEN_ZONE_HIT if cleared else COLOR_GREEN_ZONE
		draw_circle(pos, 10.0, color)
		if cleared:
			# Draw checkmark
			draw_line(pos + Vector2(-5, 0), pos + Vector2(-1, 5), Color.WHITE, 2.5)
			draw_line(pos + Vector2(-1, 5), pos + Vector2(6, -5), Color.WHITE, 2.5)


func _gui_input(event: InputEvent) -> void:
	# Block all input when visible
	if visible:
		accept_event()
