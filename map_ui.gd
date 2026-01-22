extends Control
## Map UI - handles map display and interaction
## FIXED: Added get_map_state() and load_map_state() for save/load functionality

signal node_clicked(node: MapNodeData)

@onready var map_manager: Node = $MapManager
@onready var map_container: Control = $MapContainer
@onready var lines_container: Control = $MapContainer/Lines
@onready var nodes_container: Control = $MapContainer/Nodes
@onready var area_label: Label = $AreaLabel

const NODE_SIZE := Vector2(60, 60)
const ROW_SPACING: float = 100.0
const COL_SPACING: float = 150.0

var screen_center := Vector2(960, 540)

var current_scroll := Vector2.ZERO
var target_scroll := Vector2.ZERO
const SCROLL_SPEED := 8.0

const COLOR_AVAILABLE := Color(0.3, 0.7, 0.3, 1.0)
const COLOR_COMPLETED := Color(0.4, 0.4, 0.4, 1.0)
const COLOR_LOCKED := Color(0.2, 0.2, 0.25, 1.0)
const COLOR_CURRENT := Color(0.8, 0.7, 0.2, 1.0)

const TYPE_COLORS := {
	MapNodeData.NodeType.COMBAT: Color(0.7, 0.3, 0.3),
	MapNodeData.NodeType.ELITE: Color(0.8, 0.2, 0.4),
	MapNodeData.NodeType.SALVAGE: Color(0.4, 0.5, 0.7),
	MapNodeData.NodeType.REST: Color(0.3, 0.6, 0.4),
	MapNodeData.NodeType.MYSTERY: Color(0.6, 0.4, 0.7),
	MapNodeData.NodeType.MERCHANT: Color(0.7, 0.6, 0.3),
	MapNodeData.NodeType.BOSS: Color(0.9, 0.3, 0.3),
	MapNodeData.NodeType.WORKSTATION: Color(0.5, 0.4, 0.6),
}

var node_buttons: Dictionary = {}
var node_positions: Dictionary = {}
var bold_pixels_font: Font = null


func _ready() -> void:
	map_manager.player_moved.connect(_on_player_moved)
	map_manager.map_completed.connect(_on_map_completed)
	
	# Load BoldPixels font
	if ResourceLoader.exists("res://menu/font/BoldPixels.otf"):
		bold_pixels_font = load("res://menu/font/BoldPixels.otf")
	
	screen_center = get_viewport_rect().size / 2
	generate_new_map()


func _process(delta: float) -> void:
	if current_scroll.distance_to(target_scroll) > 1.0:
		current_scroll = current_scroll.lerp(target_scroll, SCROLL_SPEED * delta)
		map_container.position = current_scroll


func generate_new_map() -> void:
	map_manager.generate_new_map()
	_build_map_display()
	_scroll_to_current_node(true)


func _build_map_display() -> void:
	for child in lines_container.get_children():
		child.queue_free()
	for child in nodes_container.get_children():
		child.queue_free()
	node_buttons.clear()
	node_positions.clear()
	
	var num_rows: int = map_manager.get_num_rows()
	var base_y := screen_center.y + 200
	
	for row in num_rows:
		var row_nodes: Array = map_manager.get_nodes_in_row(row)
		var num_cols: int = row_nodes.size()
		
		for i in row_nodes.size():
			var node: MapNodeData = row_nodes[i]
			var x_offset: float = (i - (num_cols - 1) / 2.0) * COL_SPACING
			var y_offset: float = -row * ROW_SPACING
			
			node_positions[node.node_id] = Vector2(screen_center.x + x_offset, base_y + y_offset)
	
	for node in map_manager.nodes:
		var start_pos: Vector2 = node_positions[node.node_id]
		for conn_id in node.connections:
			var end_pos: Vector2 = node_positions[conn_id]
			_draw_connection_line(start_pos, end_pos, node, map_manager.get_map_node(conn_id))
	
	for node in map_manager.nodes:
		var pos: Vector2 = node_positions[node.node_id]
		_create_node_button(node, pos)
	
	_update_node_states()


func _draw_connection_line(start: Vector2, end: Vector2, from_node: MapNodeData, to_node: MapNodeData) -> void:
	# Determine line color based on node states
	var line_color: Color
	if from_node.completed and to_node.available:
		line_color = COLOR_AVAILABLE
	elif from_node.completed:
		line_color = COLOR_COMPLETED
	else:
		line_color = COLOR_LOCKED
	line_color.a = 1.0  # Full opacity
	
	# Create dashed line using multiple Line2D segments
	var direction := (end - start).normalized()
	var total_length := start.distance_to(end)
	var dash_length := 12.0
	var gap_length := 8.0
	var current_dist := 0.0
	
	while current_dist < total_length:
		var dash_start := start + direction * current_dist
		var dash_end_dist := minf(current_dist + dash_length, total_length)
		var dash_end := start + direction * dash_end_dist
		
		var line := Line2D.new()
		line.add_point(dash_start)
		line.add_point(dash_end)
		line.width = 3.0
		line.default_color = line_color
		lines_container.add_child(line)
		
		current_dist += dash_length + gap_length


func _create_node_button(node: MapNodeData, pos: Vector2) -> void:
	var button := Button.new()
	button.custom_minimum_size = NODE_SIZE
	button.position = pos - NODE_SIZE / 2
	
	button.text = node.get_type_icon()
	if bold_pixels_font:
		button.add_theme_font_override("font", bold_pixels_font)
	button.add_theme_font_size_override("font_size", 16)
	
	button.pressed.connect(_on_node_button_pressed.bind(node.node_id))
	button.mouse_entered.connect(_on_node_button_hover.bind(node.node_id))
	
	button.tooltip_text = node.get_type_name()
	
	nodes_container.add_child(button)
	node_buttons[node.node_id] = button


func _on_node_button_hover(node_id: int) -> void:
	var node: MapNodeData = map_manager.get_map_node(node_id)
	if node.available and not node.completed:
		AudioManager.play_ui_select()


func _update_node_states() -> void:
	for node_id in node_buttons:
		var button: Button = node_buttons[node_id]
		var node: MapNodeData = map_manager.get_map_node(node_id)
		
		var base_color: Color = TYPE_COLORS.get(node.type, Color.WHITE)
		
		if node_id == map_manager.current_node_id:
			button.modulate = COLOR_CURRENT
			button.modulate.a = 1.0  # Full opacity
			button.disabled = true
		elif node.completed:
			button.modulate = COLOR_COMPLETED
			button.modulate.a = 1.0  # Full opacity
			button.disabled = true
		elif node.available:
			button.modulate = base_color
			button.modulate.a = 1.0  # Full opacity
			button.disabled = false
		else:
			button.modulate = COLOR_LOCKED
			button.modulate.a = 1.0  # Full opacity
			button.disabled = true
	
	_rebuild_lines()


func _rebuild_lines() -> void:
	for child in lines_container.get_children():
		child.queue_free()
	
	for node in map_manager.nodes:
		if not node_positions.has(node.node_id):
			continue
		var start_pos: Vector2 = node_positions[node.node_id]
		for conn_id in node.connections:
			if not node_positions.has(conn_id):
				continue
			var end_pos: Vector2 = node_positions[conn_id]
			_draw_connection_line(start_pos, end_pos, node, map_manager.get_map_node(conn_id))


func _scroll_to_current_node(instant: bool = false) -> void:
	var current_node: MapNodeData = map_manager.get_current_node()
	if current_node == null:
		return
	
	if not node_positions.has(current_node.node_id):
		return
	
	var node_pos: Vector2 = node_positions[current_node.node_id]
	target_scroll = screen_center - node_pos
	target_scroll.x = clampf(target_scroll.x, -200, 200)
	target_scroll.y = minf(target_scroll.y, 0)
	
	if instant:
		current_scroll = target_scroll
		map_container.position = current_scroll


func _on_node_button_pressed(node_id: int) -> void:
	if map_manager.can_travel_to(node_id):
		AudioManager.play_ui_confirm()
		map_manager.travel_to(node_id)


func _on_player_moved(node: MapNodeData) -> void:
	_update_node_states()
	_scroll_to_current_node()
	node_clicked.emit(node)


func _on_map_completed() -> void:
	area_label.text = "AREA COMPLETE!"


func on_node_completed() -> void:
	map_manager.complete_current_node()
	_update_node_states()


func get_current_node() -> MapNodeData:
	return map_manager.get_current_node()


## FIXED: Get map state for saving
func get_map_state() -> Dictionary:
	return map_manager.get_map_state()


## FIXED: Load map state from saved data and rebuild display
func load_map_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	
	map_manager.load_map_state(state)
	_build_map_display()
	_scroll_to_current_node(true)
