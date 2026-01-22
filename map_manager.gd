extends Node
## Map Manager - handles map data and generation
## FIXED: Added get_map_state() and load_map_state() for save/load functionality

signal node_selected(node: MapNodeData)
signal map_completed
signal player_moved(to_node: MapNodeData)

var nodes: Array = []
var current_node_id: int = -1  # -1 means at start, not on map yet


func generate_new_map() -> void:
	nodes = MapGenerator.generate_map()
	current_node_id = -1


func get_map_node(node_id: int) -> MapNodeData:
	if node_id < 0 or node_id >= nodes.size():
		return null
	return nodes[node_id]


func get_current_node() -> MapNodeData:
	return get_map_node(current_node_id)


func get_available_nodes() -> Array:
	var available: Array = []
	for node in nodes:
		if node.available and not node.completed:
			available.append(node)
	return available


func get_nodes_in_row(row: int) -> Array:
	var row_nodes: Array = []
	for node in nodes:
		if node.row == row:
			row_nodes.append(node)
	# Sort by column
	row_nodes.sort_custom(func(a, b): return a.column < b.column)
	return row_nodes


func get_num_rows() -> int:
	var max_row: int = 0
	for node in nodes:
		max_row = maxi(max_row, node.row)
	return max_row + 1


func can_travel_to(node_id: int) -> bool:
	var node := get_map_node(node_id)
	if node == null:
		return false
	return node.available and not node.completed


func travel_to(node_id: int) -> bool:
	if not can_travel_to(node_id):
		return false
	
	var node := get_map_node(node_id)
	current_node_id = node_id
	
	player_moved.emit(node)
	node_selected.emit(node)
	return true


func complete_current_node() -> void:
	if current_node_id < 0:
		return
	
	var node := get_map_node(current_node_id)
	if node == null:
		return
	
	node.completed = true
	
	# Check for boss completion
	if node.type == MapNodeData.NodeType.BOSS:
		map_completed.emit()
		return
	
	# Mark connected nodes as available
	for connected_id in node.connections:
		var connected := get_map_node(connected_id)
		if connected:
			connected.available = true
	
	# Clear availability of other nodes in same row (can't go back)
	for n in nodes:
		if n.row == node.row and n.node_id != node.node_id:
			n.available = false


func get_connections_from(node_id: int) -> Array:
	var node := get_map_node(node_id)
	if node == null:
		return []
	
	var connected: Array = []
	for cid in node.connections:
		var c := get_map_node(cid)
		if c:
			connected.append(c)
	return connected


## FIXED: Get the current map state for saving
func get_map_state() -> Dictionary:
	return {
		"nodes": SaveManager.serialize_map_nodes(nodes),
		"current_node_id": current_node_id,
	}


## FIXED: Load map state from saved data
func load_map_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	
	# Restore nodes
	var saved_nodes: Array = state.get("nodes", [])
	if not saved_nodes.is_empty():
		nodes = SaveManager.deserialize_map_nodes(saved_nodes)
	
	# Restore current position
	current_node_id = int(state.get("current_node_id", -1))
