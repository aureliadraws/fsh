extends Node2D
## Water drawn behind the boat

@export var water_color_deep: Color = Color(0.04, 0.08, 0.14, 1.0)
@export var water_color_mid: Color = Color(0.08, 0.14, 0.22, 1.0)
@export var water_color_surface: Color = Color(0.12, 0.2, 0.28, 1.0)
@export var foam_color: Color = Color(0.5, 0.55, 0.6, 1.0)
@export var splash_color: Color = Color(0.6, 0.65, 0.7, 0.9)

var main


func _ready() -> void:
	main = get_parent()


func _draw() -> void:
	if not main:
		return
	
	var pixel_size: int = main.pixel_size
	var num_columns: int = main.num_columns
	
	# Draw water body
	for i in num_columns:
		var x: int = i * pixel_size
		var surface_y: float = main.wave_heights[i]
		
		# Deep
		draw_rect(Rect2(x, surface_y + 50, pixel_size, 600), water_color_deep)
		
		# Mid
		draw_rect(Rect2(x, surface_y + 16, pixel_size, 34), water_color_mid)
		
		# Surface
		draw_rect(Rect2(x, surface_y, pixel_size, 16), water_color_surface)
		
		# Foam on peaks and steep areas
		if i > 0 and i < num_columns - 1:
			var prev: float = main.wave_heights[i - 1]
			var curr: float = main.wave_heights[i]
			var next: float = main.wave_heights[i + 1]
			
			var is_peak: bool = curr < prev and curr < next
			var is_steep: bool = absf(curr - prev) > 4.0 or absf(curr - next) > 4.0
			
			if is_peak:
				draw_rect(Rect2(x - pixel_size, surface_y - pixel_size * 2, pixel_size * 3, pixel_size * 3), foam_color)
			elif is_steep:
				draw_rect(Rect2(x, surface_y - pixel_size, pixel_size, pixel_size * 2), foam_color)
	
	# Boat foam and splash
	_draw_boat_foam(pixel_size)


func _draw_boat_foam(pixel_size: int) -> void:
	var boat = main.boat
	var boat_pos: Vector2 = boat.global_position
	var half_width: float = main.boat_width / 2.0
	
	# Contact points
	var offsets: Array[float] = [-1.0, -0.5, 0.0, 0.5, 1.0]
	var points: Array[Vector2] = []
	for i in offsets.size():
		var local_x: float = half_width * offsets[i]
		var rotated: Vector2 = Vector2(local_x, 0).rotated(boat.rotation)
		var world_pos: Vector2 = boat_pos + rotated
		var wave_y: float = main.get_wave_height_at(world_pos.x)
		points.append(Vector2(world_pos.x, wave_y))
	
	# Draw foam at each point
	for i in points.size():
		var point: Vector2 = points[i]
		var size: int = pixel_size * 2
		if absf(boat.linear_velocity.y) > 20.0:
			size = pixel_size * 3
		draw_rect(Rect2(point.x - size, point.y - pixel_size * 2, size * 2, pixel_size * 4), foam_color)
	
	# Splash when moving
	var speed: float = boat.linear_velocity.length()
	if speed > 30.0 or absf(boat.angular_velocity) > 0.3:
		var splash_count: int = int(speed / 15.0)
		splash_count = clampi(splash_count, 2, 10)
		
		for j in splash_count:
			var splash_x: float = boat_pos.x + randf_range(-half_width * 1.2, half_width * 1.2)
			var wave_y: float = main.get_wave_height_at(splash_x)
			var splash_height: float = randf_range(2.0, 5.0) * pixel_size
			draw_rect(Rect2(splash_x, wave_y - splash_height, pixel_size, splash_height), splash_color)
