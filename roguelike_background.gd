extends Node2D
## Roguelike background - main controller

@onready var boat: RigidBody2D = $Boat
@onready var water_back: Node2D = $WaterBack
@onready var water_front: Node2D = $WaterFront

## Water settings
@export var water_level: float = 500.0

## Wave settings - volatile
@export var wave_speed: float = 1.2
@export var wave_height: float = 25.0
@export var wave_frequency: float = 0.012
@export var secondary_wave_height: float = 15.0
@export var secondary_frequency: float = 0.028
@export var tertiary_wave_height: float = 8.0
@export var tertiary_frequency: float = 0.045

## Boat settings
@export var boat_width: float = 200.0
@export var buoyancy_points: int = 7
@export var buoyancy_strength: float = 18.0
@export var wave_push_strength: float = 40.0
@export var boat_target_x: float = 960.0
@export var centering_force: float = 80.0

## Pixel size
@export var pixel_size: int = 4

var time: float = 0.0
var wave_heights: PackedFloat32Array
var num_columns: int


func _ready() -> void:
	num_columns = int(1920.0 / pixel_size) + 1
	wave_heights.resize(num_columns)


func _process(delta: float) -> void:
	time += delta
	_calculate_waves()
	water_back.queue_redraw()
	water_front.queue_redraw()


func _physics_process(_delta: float) -> void:
	_apply_buoyancy()


func _calculate_waves() -> void:
	for i in num_columns:
		var x := i * pixel_size
		var wave1 := sin((x * wave_frequency) + (time * wave_speed)) * wave_height
		var wave2 := sin((x * secondary_frequency) + (time * wave_speed * 1.3)) * secondary_wave_height
		var wave3 := sin((x * tertiary_frequency) + (time * wave_speed * 2.1)) * tertiary_wave_height
		var wave4 := sin((x * 0.008) + (time * wave_speed * 0.5)) * (wave_height * 0.5)
		wave_heights[i] = water_level + wave1 + wave2 + wave3 + wave4


func get_wave_height_at(x_pos: float) -> float:
	var index := int(x_pos / pixel_size)
	index = clampi(index, 0, num_columns - 1)
	return wave_heights[index]


func get_wave_slope_at(x_pos: float) -> float:
	var index := int(x_pos / pixel_size)
	index = clampi(index, 1, num_columns - 2)
	return (wave_heights[index + 1] - wave_heights[index - 1]) / (pixel_size * 2.0)


func _apply_buoyancy() -> void:
	var half_width := boat_width / 2.0
	var point_spacing := boat_width / (buoyancy_points - 1)
	
	# Keep boat near center of screen
	var drift: float = boat_target_x - boat.global_position.x
	boat.apply_central_force(Vector2(drift * centering_force * 0.5, 0))
	
	# Dampen horizontal velocity to prevent oscillation
	boat.apply_central_force(Vector2(-boat.linear_velocity.x * 3.0, 0))
	
	for i in buoyancy_points:
		var local_x := -half_width + (i * point_spacing)
		var rotated_offset := Vector2(local_x, 0).rotated(boat.rotation)
		var world_point := boat.global_position + rotated_offset
		
		var wave_y := get_wave_height_at(world_point.x)
		var wave_slope := get_wave_slope_at(world_point.x)
		var depth := world_point.y - wave_y
		
		if depth > 0:
			# Buoyancy
			var buoyancy := depth * buoyancy_strength
			boat.apply_force(Vector2(0, -buoyancy), rotated_offset)
			
			# Wave push
			var push := wave_slope * wave_push_strength * depth
			boat.apply_force(Vector2(push, 0), rotated_offset)
			
			# Drag
			var drag := boat.linear_velocity * -0.5 * (depth / 25.0)
			boat.apply_force(drag / buoyancy_points, rotated_offset)
		
		# Slope torque above water
		elif depth > -15:
			boat.apply_torque(wave_slope * wave_push_strength * local_x * 0.15)
