extends Node2D
## Pixel-based water with wave simulation

@export var water_color_deep: Color = Color(0.08, 0.12, 0.18, 1.0)
@export var water_color_surface: Color = Color(0.12, 0.18, 0.25, 1.0)
@export var wave_color: Color = Color(0.2, 0.28, 0.35, 1.0)
@export var foam_color: Color = Color(0.4, 0.45, 0.5, 1.0)

@export var water_width: int = 1920
@export var water_height: int = 680

@export var wave_height: float = 12.0
@export var wave_speed: float = 1.0
@export var wave_frequency: float = 0.02
@export var secondary_wave_frequency: float = 0.035
@export var secondary_wave_height: float = 6.0

@export var pixel_size: int = 4

var time: float = 0.0
var wave_heights: PackedFloat32Array


func _ready() -> void:
	var num_columns := water_width / pixel_size
	wave_heights.resize(num_columns)


func _process(delta: float) -> void:
	time += delta
	_calculate_waves()
	queue_redraw()


func _calculate_waves() -> void:
	var num_columns := wave_heights.size()
	for i in num_columns:
		var x := i * pixel_size
		var wave1 := sin((x * wave_frequency) + (time * wave_speed)) * wave_height
		var wave2 := sin((x * secondary_wave_frequency) + (time * wave_speed * 0.7)) * secondary_wave_height
		var wave3 := sin((x * wave_frequency * 2.5) + (time * wave_speed * 1.3)) * (wave_height * 0.3)
		wave_heights[i] = wave1 + wave2 + wave3


func _draw() -> void:
	var num_columns := wave_heights.size()
	
	# Draw water body
	for i in num_columns:
		var x := i * pixel_size
		var surface_y := wave_heights[i]
		
		# Deep water column
		draw_rect(
			Rect2(x, surface_y + 20, pixel_size, water_height),
			water_color_deep
		)
		
		# Surface layer
		draw_rect(
			Rect2(x, surface_y, pixel_size, 20),
			water_color_surface
		)
		
		# Wave highlight (top pixels)
		draw_rect(
			Rect2(x, surface_y, pixel_size, pixel_size),
			wave_color
		)
		
		# Foam on wave peaks
		if i > 0 and wave_heights[i] < wave_heights[i - 1] and i < num_columns - 1 and wave_heights[i] < wave_heights[i + 1]:
			draw_rect(
				Rect2(x, surface_y - pixel_size, pixel_size, pixel_size),
				foam_color
			)


## Get wave height at specific x position (for boat interaction)
func get_wave_height_at(x_pos: float) -> float:
	var index := int(x_pos / pixel_size)
	index = clamp(index, 0, wave_heights.size() - 1)
	return wave_heights[index]
